extends Node
## Core simulation for the "One Week" slice. Pure data + rules, no visuals,
## so it can be driven by the house scene or by headless tests.
##
## Day flow (phases): home_am -> (leave) -> work -> (head home) -> drive
## (gas station stop) -> (pick up girls) -> home_pm -> sleep.
##
## Substance thread (design: subtle, non-preachy, shown through people and
## LifeOS, not lectures). Hidden values: drinks_week, gum_damage, rx_extra.

signal state_changed
signal lifeos_message(text: String)
signal day_ended(summary: Dictionary)
signal week_ended(review: String)
signal day_started
signal action_performed(id: String, result: String)

const DAY_NAMES := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DAY_START := 390   # 6:30 AM, in minutes
const DAY_END := 1500    # 1:00 AM next day
const BLOCK := 30        # one time block = 30 min
const FUMES := 20
const OFF_WORK := 960    # 4:00 PM: earliest Dan can head home
const RX_DURATION := 360 # focus lasts 6h, then the crash
const TRAVEL := ["leave_for_work", "head_home", "pickup_girls"]
const ANY := ["home_am", "work", "drive", "home_pm", "weekend"]
const HOME := ["home_pm", "weekend"]

const PHASE_NAMES := {"home_am": "Home (morning)", "work": "At work — TriCounty Managed Services",
	"drive": "Drive home — Gas-N-Sip", "home_pm": "Home (evening)", "weekend": "Home (weekend)"}

# action id -> definition. blocks = 30-min blocks. energy = delta.
const ACTIONS := {
	"feed_girls": {"name": "Make breakfast with the girls", "blocks": 1, "energy": -5, "fed": 35, "connected": 5, "once": true, "phases": ["home_am"]},
	"cereal": {"name": "Cereal and screens", "blocks": 1, "energy": 0, "fed": 20, "connected": -5, "once": true, "phases": ["home_am"]},
	"leave_for_work": {"name": "Drop girls at school, drive to work", "blocks": 2, "energy": -3, "phases": ["home_am"]},
	"work_ticket": {"name": "Work a ticket", "blocks": 2, "energy": -10, "stress": 5, "perf": 4, "phases": ["work", "home_pm", "weekend"]},
	"coffee_break": {"name": "Coffee break with the team", "blocks": 1, "energy": 8, "stress": -4, "phases": ["work"]},
	"head_home": {"name": "Head home", "blocks": 1, "energy": 0, "phases": ["work"]},
	"buy_beer": {"name": "Grab a six-pack ($12)", "blocks": 0, "energy": 0, "money": -12, "phases": ["drive"]},
	"buy_pouches": {"name": "Grab a tin of nic pouches ($7)", "blocks": 0, "energy": 0, "money": -7, "phases": ["drive"]},
	"buy_patch": {"name": "Nicotine patches instead ($15)", "blocks": 0, "energy": 0, "money": -15, "phases": ["drive"]},
	"call_doctor": {"name": "Call Dr. Patel about the Rx", "blocks": 1, "energy": -2, "stress": -4, "once": true, "phases": ["work"]},
	"pickup_girls": {"name": "Just drive on and pick up the girls", "blocks": 1, "energy": -3, "phases": ["drive"]},
	"play_girls": {"name": "Play with Lily & June", "blocks": 1, "energy": -5, "stress": -5, "connected": 12, "phases": HOME},
	"bedtime_story": {"name": "Bedtime story", "blocks": 1, "energy": -5, "connected": 20, "after": 1170, "before": 1260, "once": true, "phases": HOME},
	"gaming": {"name": "Play video games", "blocks": 2, "energy": 5, "stress": -20, "phases": HOME},
	"drink": {"name": "Have a beer", "blocks": 0, "energy": -2, "stress": -10, "phases": HOME},
	"pouch": {"name": "Nic pouch", "blocks": 0, "energy": 0, "stress": -6, "phases": ANY},
	"rx_dose": {"name": "Take Rx (prescribed: 1/day)", "blocks": 0, "energy": 15, "phases": ["home_am", "work", "home_pm", "weekend"]},
	"text_jess": {"name": "Text Jess (thoughtful)", "blocks": 0, "energy": -2, "closeness": 6, "max_per_day": 3, "diminish": 3, "phases": ANY},
	# Cozy evening/weekend verbs (playtester pass 2)
	"family_dinner": {"name": "Family dinner (everyone at the table)", "blocks": 1, "energy": -4, "stress": -4, "fed": 30, "connected": 6, "closeness": 4, "after": 1020, "before": 1230, "once": true, "phases": HOME},
	"homework": {"name": "Homework & drawing at the table", "blocks": 1, "energy": -4, "connected": 8, "before": 1200, "once": true, "phases": HOME},
	"walk_park": {"name": "Walk to the park with the girls", "blocks": 2, "energy": -2, "stress": -14, "connected": 10, "after": 960, "before": 1170, "once": true, "phases": HOME},
	"walk_block": {"name": "Walk around the block (alone)", "blocks": 1, "energy": 4, "stress": -12, "phases": HOME},
	"tea_jess": {"name": "Tea on the couch with Jess", "blocks": 1, "energy": 3, "stress": -10, "closeness": 8, "after": 1080, "once": true, "phases": HOME},
	"breathe": {"name": "Deep breath (box breathing)", "blocks": 0, "energy": 0, "stress": -4, "max_per_day": 2, "phases": ANY},
	"pancakes": {"name": "Saturday-style pancakes", "blocks": 2, "energy": -4, "stress": -6, "fed": 40, "connected": 10, "before": 720, "once": true, "phases": ["weekend"]},
	"chores": {"name": "Chores together (with a playlist)", "blocks": 2, "energy": -8, "stress": -4, "connected": 4, "closeness": 6, "once": true, "phases": ["weekend"]},
	"concert": {"name": "Lily's school concert", "blocks": 2, "energy": -3, "connected": 18, "closeness": 4, "after": 1050, "before": 1110, "once": true, "event": "concert", "phases": ["home_pm"]},
	"side_hustle": {"name": "Side hustle: Marisol's bakery script", "blocks": 2, "energy": -8, "stress": 4, "after": 1200, "phases": HOME},
	"sleep": {"name": "Go to sleep", "blocks": 0, "energy": 0, "phases": HOME},
}

# Calendar: day index -> event. Shown in the HUD; some unlock actions.
const CALENDAR := {
	0: {"id": "", "text": "Monday. The fridge calendar says nothing. Suspicious."},
	1: {"id": "picture", "text": "Picture day! (Hair: attempted)"},
	2: {"id": "", "text": "Taco Wednesday (household law)"},
	3: {"id": "concert", "text": "Lily's concert, 5:30 PM (recorder solo)"},
	4: {"id": "pizza", "text": "Office pizza Friday"},
	5: {"id": "weekend", "text": "Saturday. No work. (Theoretically.)"},
	6: {"id": "oncall", "text": "Sunday. You're on call. The pager is asleep. Don't wake it."},
}
const TICKETS := [
	"\"Printer is printing. Is this normal? URGENT\" (It was normal. She sent a thank-you GIF.)",
	"\"Can you make the internet faster? —Sent from my iPad\" (You moved him closer to the router. He called you a wizard.)",
	"\"Need admin rights to install FreeScreenSaverz_REAL.exe for productivity\" (Declined. You found her a safe fish one. She loves the fish.)",
	"\"What's the Wi-Fi password?\" (You taped it to the conference room wall. Solved forever. Probably.)",
	"\"Outlook is Not Responding. Neither am I.\" —Karen in Accounts Payable (Fixed both. She left a muffin.)",
	"\"The server room is making a noise. A different noise.\" (A tired fan. Fixed. The servers hum happily.)",
	"\"Reply-all thread re: WHO TOOK MY YOGURT (47 replies)\" (The yogurt was found. Everyone is relieved.)",
	"\"Our chatbot told a customer we offer free kittens. Do we?\" (We do not. You fixed it. A little sad, honestly.)",
	"\"My second monitor is upside down. I didn't do anything.\" (A toddler visited. You flip it. Crisis averted.)",
	"\"Is the cloud down?\" (The cloud is fine. Her Wi-Fi was off. You both agree to never speak of it.)",
	"\"Mouse not working\" (Battery. It's always the battery. Sometimes it's DNS. This time it's the battery.)",
	"\"Can you recover a file I deleted in 2019?\" (You can. You become briefly, quietly legendary.)",
	"\"Teams says I'm 'Away'. I am right here. Please tell Teams.\" (You tell Teams. Teams does not listen. Nobody can reach Teams.)",
	"\"The fax machine is sending faxes to itself.\" (It's lonely. You unplug it gently, like a vet.)",
	"\"Password expired. New one can't match the last 12. I'm out of pets.\" (You suggest a passphrase. She names it after her mortgage.)",
	"\"Printer says PC LOAD LETTER\" (Paper. It wanted paper. It always just wanted paper.)",
	"\"Laptop is very hot and making a sound like a tiny jet\" (Two hundred Chrome tabs. You close them with respect.)",
	"\"Accidentally replied-all to the whole company with 'love you too'\" (You can't unsend it. You can offer emotional support.)",
	"\"Calendar invite for a meeting about reducing meetings\" (Not a ticket. You accept anyway. Solidarity.)",
	"\"Our smart fridge is asking for a firmware update and also for help\" (Updated. Fridge seems happier.)",
	"\"The CEO's nephew 'fixed' the network\" (He bought a router at a gas station. You fix the fix. Everyone lives.)",
	"\"Webcam shows me as a potato\" (A filter. He kind of liked it. You leave him the option.)",
	"\"Server rack beeping in Morse code\" (It's a failing disk, not a hostage. You swap it. RAID holds. Exhale.)",
	"\"Keyboard typing the wrong letters\" (Language switched to Dvorak. Nobody knows how. Nobody ever will.)",
	"\"Can AI do my timesheet?\" (No. But you made her a template and she cried a little. Good tears.)",
]
const JESS_TEXTS := [
	"Jess: On hold with insurance for 52 min. The hold music has a bridge now. I'm emotionally invested.",
	"Jess: Can you grab milk on the way? June wants to 'review' the oat one again.",
	"Jess: Hospital gave us pizza instead of a raise again. Saved you a slice of late-stage capitalism. ❤",
	"Jess: Lily asked if your job is real. I said 'legally, yes.' She said you seem 'very important to printers.'",
	"Jess: Friendly reminder the shared calendar exists 💛 June has picture day Tuesday.",
	"Jess: June just asked if you're 'the computer guy' at home too. I said 'only when it's broken.' So, always.",
	"Jess: a patient's kid drew me a horse. It looks like a sofa. I love it. Bringing it home for the fridge.",
	"Jess: day is long. you're my favorite person. that's it, that's the text.",
	"Jess: the dishwasher made The Noise again. I have chosen not to hear it. Please also not hear it.",
]
const LIFEOS_TIPS := [
	"LifeOS: Tip: Sleep restores Energy. Premium Sleep™ is $4.99/mo. Regular sleep is still free. For now.",
	"LifeOS: Tip: Your daughters can't be optimized. Our engineers say this is a feature.",
	"LifeOS: Tip: It's always DNS. Except when it's the cable. Check the cable.",
	"LifeOS: Tip: A 'quick call' has never once been quick. LifeOS has the data. LifeOS is sorry.",
	"LifeOS: Feeling overwhelmed by notifications? Here is a notification about that.",
	"LifeOS: Reminder: your Screen Time was 9h. 7h of that was work. LifeOS is choosing not to judge. LifeOS is an app with feelings now.",
	"LifeOS: Your step count today: 4,112. Of those, 3,900 were to the printer.",
	"LifeOS: Hydration check! Coffee counts as water, legally, in no jurisdictions.",
	"LifeOS: You've been 'just a sec' for 22 minutes. The girls have noticed. LifeOS has noticed. The cat has noticed.",
	"LifeOS: Inbox Zero achieved! Just kidding. LifeOS would never do that to you.",
	"LifeOS: Weather today: 61°F and partly 'you should go outside'.",
	"LifeOS: Fun fact: Nobody on their deathbed wished they'd closed more tickets. Except Gary, maybe. Gary's fine though.",
	"LifeOS: Your calendar has a meeting called 'Sync re: Sync'. LifeOS cannot help you. LifeOS is so sorry.",
	"LifeOS: Tip: The 4 AM Club recommends cold plunges. LifeOS recommends warm blankets. LifeOS is winning.",
	"LifeOS: 3 new notifications about notifications. Tap to unsubscribe from unsubscribing.",
	"LifeOS: Lily searched 'how old do you have to be to fix computers'. LifeOS thought you should know.",
	"LifeOS: Your burnout score is 'crispy'. Suggested action: a walk. Not a sponsored walk. Just a walk.",
	"LifeOS: Achievement unlocked: Remembered to Eat Lunch. (Pending. Achievement locked.)",
]
# Jess noticing drinking, keyed by cumulative drinks this week. Quiet, not a fight.
const JESS_NOTICES := {
	4: "Jess: hey, the recycling's been pretty full this week. you doing okay? long week?",
	8: "Jess: you seemed far away tonight. I'm not upset. I just miss you a little.",
	12: "Jess: can we talk this weekend? nothing scary. I just want to check in on us. ❤",
}
# Gum damage thresholds -> subtle health notes.
const GUM_NOTES := {
	6: "LifeOS: Brookfield Family Dental: \"It's been a while! We'd love to see you for a cleaning.\"",
	14: "LifeOS: You've searched \"gum sore one side normal\" 3 times. Maybe worth asking Dr. Lin? LifeOS cares about your teeth.",
	24: "Brookfield Family Dental: \"Dr. Lin noticed something at your last visit and would like a closer look. Nothing to panic about, but please do come in.\"",
}

var day: int = 0
var minutes: int = DAY_START
var phase := "home_am"
var energy: int = 100
var stress: int = 20
var performance: int = 50
var closeness: int = 50
var girls_fed: int = 30
var girls_connected: int = 50
var money: int = 200
var week_over := false
var today := {}          # per-day counters
var week_stats := {}
var rng := RandomNumberGenerator.new()
# Substance state (mostly hidden from the HUD on purpose).
var beers: int = 0
var pouches: int = 0
var drinks_week: int = 0
var gum_damage: int = 0       # hidden; builds slowly, never shown as a number
var rx_pills: int = 30        # month supply
var rx_extra_total: int = 0
var rx_until: int = -1        # minute the current dose wears off
var rx_last_dose: int = -1
var notices_seen := {}
var patch_days: int = 0            # patches blunt pouch cravings
var rx_plan := false               # talked to the doctor: gentler crash
var pending_choice := ""          # Main turns this into a choice cutscene after the action
var hustle: int = 0                 # side hustle sessions (AI script for Marisol's bakery)
var achievements: Array[String] = []
var honesty: int = 50              # hidden; moved by choices in cutscenes
var fridge_drawings: int = 0       # cozy loop: grows with time spent with the girls
var moments_seen := {}              # relationship moments already played
var clean := {"drink": 0, "pouch": 0, "rx_extra": 0}   # consecutive clean days after using
var used_ever := {"drink": false, "pouch": false, "rx_extra": false}
var week_moments: Array[String] = []
signal moment(id: String)

func _ready() -> void:
	new_game()

func new_game(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	day = 0
	energy = 100
	stress = 20
	performance = 50
	closeness = 50
	girls_fed = 30
	girls_connected = 50
	money = 200
	beers = 0
	pouches = 0
	drinks_week = 0
	gum_damage = 0
	rx_pills = 30
	rx_extra_total = 0
	notices_seen = {}
	fridge_drawings = 0
	honesty = 50
	hustle = 0
	achievements = []
	patch_days = 0
	rx_plan = false
	moments_seen = {}
	clean = {"drink": 0, "pouch": 0, "rx_extra": 0}
	used_ever = {"drink": false, "pouch": false, "rx_extra": false}
	week_moments = []
	week_over = false
	week_stats = {"bedtimes": 0, "tickets": 0, "texts": 0, "gaming_blocks": 0, "drinks": 0, "pouches": 0, "rx_extra": 0}
	_start_day()

func _start_day() -> void:
	minutes = DAY_START
	pending_choice = ""
	phase = "weekend" if day >= 5 else "home_am"
	if day > 0 and day < 5:
		stress = clampi(stress + 10, 0, 100)   # the inbox refilled overnight
	# Mild cravings the day after using: the cost of quitting is real but small.
	if day > 0 and clean.get("pouch", 0) <= 1 and used_ever.get("pouch", false):
		if patch_days > 0:
			patch_days -= 1
		else:
			stress = clampi(stress + 4, 0, 100)
	if day > 0 and clean.get("drink", 0) <= 1 and used_ever.get("drink", false):
		stress = clampi(stress + 3, 0, 100)
	rx_until = -1
	rx_last_dose = -1
	today = {"tickets": 0, "text_jess": 0, "bedtime_story": 0, "kid_actions": 0, "gaming": 0,
		"drink": 0, "pouch": 0, "rx_dose": 0, "crashed": false, "log": [], "moments": []}
	state_changed.emit()
	day_started.emit()

func is_weekend() -> bool:
	return day >= 5

func calendar_text() -> String:
	return CALENDAR[day]["text"]

func day_name() -> String:
	return DAY_NAMES[day]

func phase_name() -> String:
	return PHASE_NAMES[phase]

func clock_text() -> String:
	return _fmt(minutes)

func is_on_fumes() -> bool:
	return energy < FUMES

func rx_active() -> bool:
	return rx_until > minutes

## Actions available in the current phase (for UI menus in work/drive phases).
func phase_actions() -> Array[String]:
	var out: Array[String] = []
	for id in ACTIONS:
		if phase in ACTIONS[id]["phases"]:
			out.append(id)
	return out

## Returns "" if allowed, otherwise a reason (LifeOS-flavored).
func can_do(id: String) -> String:
	if week_over:
		return "The week is over. LifeOS is putting your review together."
	if not ACTIONS.has(id):
		return "Unknown action."
	var a: Dictionary = ACTIONS[id]
	if not (phase in a["phases"]):
		return "Not right now."
	var cost_min: int = int(a["blocks"]) * BLOCK
	if minutes + cost_min > DAY_END:
		return "Not enough day left. It's %s." % clock_text()
	if a.has("before") and minutes >= int(a["before"]):
		return "Too late for that today."
	if a.has("after") and minutes < int(a["after"]):
		return "Not yet. (Available after %s.)" % _fmt(int(a["after"]))
	if a.get("once", false) and int(today.get(id, 0)) > 0:
		return "Already done today."
	if a.has("max_per_day") and int(today.get(id, 0)) >= int(a["max_per_day"]):
		return "You're breathed out for now. Lungs: at capacity." if id == "breathe" else "Jess is busy. She'll text back later."
	if a.has("event") and CALENDAR[day]["id"] != a["event"]:
		return "Not on the calendar today."
	if a.has("money") and money + int(a["money"]) < 0:
		return "Card declined. The pump says nothing. The pump doesn't have to."
	match id:
		"head_home":
			if minutes < OFF_WORK:
				return "Gary is doing a lap. Your coat is very visible. Maybe after 4."
		"drink":
			if beers <= 0:
				return "Fridge: oat milk, juice boxes, one lemon with a lot of potential."
		"pouch":
			if pouches <= 0:
				return "Tin's empty."
		"rx_dose":
			if rx_pills <= 0:
				return "Pharmacy: \"Too early to refill.\""
		"tea_jess":
			if phase == "weekend" and minutes < 600:
				return "Jess is still asleep. Let her have this."
		"play_girls", "walk_park", "chores":
			if is_on_fumes():
				return "You're running on fumes. Maybe rest a bit first."
	var e: int = int(a["energy"])
	# Getting places never depends on energy: a tired dad still drives home.
	if e < 0 and energy + e < 0 and not (id in TRAVEL):
		return "You're too tired for that right now."
	return ""

## Performs an action. Returns a result line for the UI.
func do_action(id: String) -> String:
	var why := can_do(id)
	if why != "":
		return why
	pending_choice = ""
	if id == "sleep":
		end_day()
		return "Lights out."
	var a: Dictionary = ACTIONS[id]
	var blocks: int = int(a["blocks"])
	var e: int = int(a["energy"])
	var perf: int = int(a.get("perf", 0))
	if id == "work_ticket" and rx_active():
		e = -5          # focus: tickets feel easy...
		perf += 3
	minutes += blocks * BLOCK
	energy = clampi(energy + e, 0, 100)
	stress = clampi(stress + int(a.get("stress", 0)), 0, 100)
	performance = clampi(performance + perf, 0, 100)
	closeness = clampi(closeness + int(a.get("closeness", 0)), 0, 100)
	girls_fed = clampi(girls_fed + int(a.get("fed", 0)), 0, 100)
	girls_connected = clampi(girls_connected + int(a.get("connected", 0)), 0, 100)
	money += int(a.get("money", 0))
	girls_fed = clampi(girls_fed - blocks * 2, 0, 100)
	today[id] = int(today.get(id, 0)) + 1
	var line: String = a["name"]
	var lifeos := ""
	var before_min: int = minutes - blocks * BLOCK
	match id:
		"leave_for_work":
			phase = "work"
			line = ["School drop-off: both shoes found! You badge in at %s.", "Drop-off: June hugs the crossing guard. Lily pretends not to know you. You badge in at %s.",
				"Drop-off: picture day hair held for 11 whole minutes. You badge in at %s.", "Drop-off: Lily practices her recorder in the car. Your ears badge in at %s.",
				"Drop-off: June gives you a rock 'for work'. It's on your desk now. You badge in at %s."][day % 5] % clock_text()
		"head_home":
			phase = "drive"
			line = "The Gas-N-Sip on Route 9 glows in the dusk. The girls are waiting at after-care."
		"buy_beer":
			beers += 6
			line = "Six-pack in the passenger seat."
		"buy_pouches":
			pouches += 15
			line = "Tin of pouches. The cashier already knows your usual."
		"pickup_girls":
			phase = "home_pm"
			line = "After-care pickup. Lily: \"Why does the car smell like the gas station?\"" if today.get("buy_beer", 0) + today.get("buy_pouches", 0) > 0 else "After-care pickup. June reports three 'incidents', and a new best friend."
		"work_ticket":
			today["tickets"] += 1
			week_stats["tickets"] += 1
			line = "Closed ticket: " + TICKETS[rng.randi() % TICKETS.size()]
			if phase == "work" and rng.randf() < 0.2:
				pending_choice = "triage"
			if rx_active():
				line += "\n(Everything is very clear. Almost too clear.)"
		"side_hustle":
			hustle += 1
			match hustle:
				1: line = "You start a little script that turns Marisol's bakery orders into a schedule. It works on the first try. Suspicious."
				2: line = "The script now texts Marisol when the croissants are low. She sends you a voice memo that's just happy yelling."
				3:
					money += 50
					line = "Marisol pays you $50 and a box of day-olds. First side-hustle money. LifeOS updates your title to 'Founder'. Jess updates it back to 'Dan'."
					_moment("First $50 from Marisol's bakery.")
				_:
					line = "You tidy the bakery script. Marisol tells two other shop owners. Pre-revenue is now, technically, revenue."
		"buy_patch":
			patch_days += 5
			line = "Patches. The cashier raises an eyebrow, then gives you a tiny nod. Gas-N-Sip solidarity."
		"call_doctor":
			rx_plan = true
			honesty = clampi(honesty + 10, 0, 100)
			line = "You call Dr. Patel and tell her about the extra doses. She doesn't gasp. She adjusts the plan. Hold music: pan flute, but supportive."
		"coffee_break":
			line = "Coffee with the team. Karen shows everyone her new puppy. You feel a little more human."
		"breathe":
			line = ["In for four, hold for four, out for four. The inbox is still there, but further away.",
				"Box breathing. The box is fine. You're fine. Mostly fine.",
				"One more breath. LifeOS tries to join in and buffers."][mini(int(today["breathe"]), 3) - 1]
		"family_dinner":
			line = ["Tacos. June builds hers inside out. Everyone talks at once. It's perfect.",
				"Spaghetti night. Lily explains her whole day, including the parts that haven't happened yet.",
				"Breakfast-for-dinner. A cardinal sin of nutrition. A triumph of morale."][day % 3]
			_moment("Dinner where everyone talked at once.")
			pending_choice = "dinner"
		"homework":
			fridge_drawings += 1
			line = ["Lily does fractions. June draws you as a robot with a coffee for a heart. It goes on the fridge.",
				"Spelling words. June draws the whole family. You are the tallest and also, for some reason, a server.",
				"Lily's science worksheet asks 'what does a computer need?' She writes 'my dad'. Fridge-worthy.",
				"June draws Mommy with a stethoscope and you with a printer. Accurate. Fridge.",
				"Lily draws LifeOS as a little ghost in a phone. Unsettlingly good. Fridge."][day % 5] + " (Drawings: %d)" % fridge_drawings
			_moment("A new drawing for the fridge.")
		"walk_park":
			line = "The park. June conquers the big slide. Lily finds a stick that is 'definitely a wand.' Nobody checks a phone."
			if rng.randf() < 0.5:
				fridge_drawings += 1
				line += " (Lily draws the park later. Fridge: %d)" % fridge_drawings
			_moment("The big slide was conquered.")
		"walk_block":
			line = ["A lap around the block. Mrs. Okafor waves from her porch. The sky does a nice orange thing.",
				"Walk. Cold air. Your brain defrags a little.",
				"Around the block. A dog you don't know is very happy to see you. Mutual."][rng.randi() % 3]
		"tea_jess":
			week_stats["tea"] = int(week_stats.get("tea", 0)) + 1
			line = "Tea on the couch. Jess puts her feet on you like you're furniture. Highest honor in the house."
			_moment("Tea with Jess, feet on your lap.")
		"pancakes":
			line = "Pancakes. June wants hers shaped like a server rack. You do your best. It's a rectangle."
			_moment("Server-rack pancakes.")
		"chores":
			line = "Chores with a playlist. Jess sings the wrong lyrics on purpose. The garage is 4% cleaner."
		"concert":
			line = "Lily's recorder solo. It is loud and brave and mostly in tune. You cry a normal amount."
			fridge_drawings += 1
			_moment("Lily's recorder solo. You were there.")
		"text_jess":
			week_stats["texts"] += 1
			if int(today["text_jess"]) > 1:   # the 3rd "thinking of you" means less than the 1st
				closeness = clampi(closeness - int(a["diminish"]) * (int(today["text_jess"]) - 1), 0, 100)
			line = JESS_TEXTS[rng.randi() % JESS_TEXTS.size()]
			if is_on_fumes():
				closeness = clampi(closeness - 4, 0, 100)   # only +2 net: running on fumes makes for short texts
				line += "\nYou: k 👍  (You meant so much more. Your thumbs did not have it in them.)"
			else:
				line += "\nYou: (a thoughtful reply)"
		"bedtime_story":
			week_stats["bedtimes"] += 1
			if day == 2 and not notices_seen.has("bad_page"):
				notices_seen["bad_page"] = true
				pending_choice = "page"
			line = "June negotiated two more books. Worth it."
			if today["drink"] >= 3:
				line += "\nLily: \"You did the dragon voice twice.\""
			else:
				_moment("The dragon voice. Nailed it.")
			if rng.randf() < 0.35:
				fridge_drawings += 1
		"gaming":
			week_stats["gaming_blocks"] += 2
			today["gaming"] += 1
			if minutes >= 1320 and minutes <= DAY_END - 30:
				pending_choice = "one_more"
			line = "One more match. Stress down. Time: gone. Into the void. Worth it, probably."
		"drink":
			beers -= 1
			used_ever["drink"] = true
			drinks_week += 1
			week_stats["drinks"] += 1
			closeness = clampi(closeness - (1 if today["drink"] == 1 else 3), 0, 100)
			line = ["A cold one. The day gets a little softer around the edges.",
				"Another one. The couch feels nice.",
				"Third one. The dishes can wait till tomorrow. Probably."][mini(today["drink"], 3) - 1]
			for t in JESS_NOTICES:
				if drinks_week >= t and not notices_seen.has("jess%d" % t):
					notices_seen["jess%d" % t] = true
					closeness = clampi(closeness - 4, 0, 100)
					lifeos = JESS_NOTICES[t]
		"pouch":
			pouches -= 1
			used_ever["pouch"] = true
			gum_damage += 1
			week_stats["pouches"] += 1
			line = "Pouch in. A brief, quiet calm. Upper lip, left side, same spot as always."
			for t in GUM_NOTES:
				if gum_damage >= t and not notices_seen.has("gum%d" % t):
					notices_seen["gum%d" % t] = true
					lifeos = GUM_NOTES[t]
		"rx_dose":
			rx_pills -= 1
			if rx_last_dose >= 0:
				rx_extra_total += 1
				used_ever["rx_extra"] = true
				week_stats["rx_extra"] += 1
				line = "Another one, just to get through the afternoon. The bottle says 1 daily."
				if rx_extra_total >= 3 and not notices_seen.has("rx_refill"):
					notices_seen["rx_refill"] = true
					lifeos = "LifeOS: Pharmacy reminder: at this pace your refill runs out %d days early. Maybe a good thing to mention to your doctor." % rx_extra_total
			else:
				line = "Rx taken. The 47 browser tabs close themselves, emotionally. Focus: on."
			rx_last_dose = minutes
			rx_until = minutes + RX_DURATION
			today["crashed"] = false
	if id in ["feed_girls", "play_girls", "bedtime_story", "cereal"]:
		today["kid_actions"] += 1
	_check_crash()
	if lifeos == "" and phase in HOME and before_min < 1170 and minutes >= 1170 and today["bedtime_story"] == 0:
		lifeos = "LifeOS: It's 7:30. Lily is sitting on her bed holding a book very obviously. (Bedtime story: Girls' room)"
	if lifeos == "" and id in ["walk_block", "breathe", "tea_jess", "walk_park"] and int(today.get("pouch", 0)) == 0 and stress < 25 and not notices_seen.has("calm"):
		notices_seen["calm"] = true
		lifeos = "LifeOS: Stress is down and nothing was purchased. LifeOS's business model is concerned. LifeOS is happy for you."
	if lifeos == "" and CALENDAR[day]["id"] == "oncall" and before_min < 900 and minutes >= 900:
		stress = clampi(stress + 6, 0, 100)
		lifeos = "PAGER: [P2] Backup job failed (it's fine, it re-ran). LifeOS: The pager woke up. You put it back to sleep from the couch in 4 minutes. Legend."
	_check_relationships()
	if lifeos == "" and id == "work_ticket" and is_on_fumes() and not rx_plan and rx_last_dose >= 0 and not rx_active() and rx_pills > 0:
		lifeos = "LifeOS: Energy low. Maybe a snack or a short walk? (LifeOS is not a doctor. LifeOS is an app that worries.)"
	today["log"].append(line)
	action_performed.emit(id, line)
	if lifeos != "":
		lifeos_message.emit(lifeos)
	elif rng.randf() < 0.3:
		lifeos_message.emit(_lifeos_comment(id))
	state_changed.emit()
	if minutes >= DAY_END:
		end_day()
	return line

func _moment(t: String) -> void:
	today["moments"].append(t)

## One-time relationship moments at closeness/connection thresholds (Stardew heart events).
const REL_MOMENTS := {
	"jess70": ["closeness", 70, "Jess: found our old wedding playlist. it's mostly ska. who let us do that. ❤"],
	"jess85": ["closeness", 85, "Jess: you've been really here this week. I notice. thank you."],
	"girls75": ["girls_connected", 75, "LifeOS: June has declared you 'Best Daddy (Tie)'. The other contestant is the cat."],
	"girls90": ["girls_connected", 90, "LifeOS: Lily made you a certificate: 'Dad. Level 99.' It's laminated with tape."],
}
func _check_relationships() -> void:
	for k in REL_MOMENTS:
		var m: Array = REL_MOMENTS[k]
		if not moments_seen.has(k) and int(get(m[0])) >= int(m[1]):
			moments_seen[k] = true
			_moment(str(m[2]).split(": ", true, 1)[1] if ": " in str(m[2]) else str(m[2]))
			moment.emit(k)   # Main plays the heart-event cutscene

const ACHIEVEMENTS := {
	"dragon": ["Dragon Voice (Certified)", "3 bedtime stories in a week"],
	"gallery": ["Curator", "10 drawings on the fridge"],
	"founder": ["Pre-Revenue No More", "Got paid by Marisol"],
	"tea": ["Tea Time", "Tea with Jess on 3 days"],
	"clean": ["Quiet Win", "A 4-day clean streak"],
}
func _check_achievements() -> void:
	var got := {
		"dragon": week_stats["bedtimes"] >= 3,
		"gallery": fridge_drawings >= 10,
		"founder": hustle >= 3,
		"tea": int(week_stats.get("tea", 0)) >= 3,
		"clean": clean.values().any(func(v): return v >= 4),
	}
	for k in got:
		if got[k] and not (k in achievements):
			achievements.append(k)
			lifeos_message.emit("LifeOS: Achievement unlocked: %s (%s). LifeOS made you a little badge. It's just an emoji. 🏅" % ACHIEVEMENTS[k])

## Clean-day streaks: quitting is rewarded through people, not badges.
const CLEAN_LINES := {
	"drink": {2: ["Jess: you're funny when you're tired and sober. like weird-funny. I like it.", "closeness", 6],
		4: ["Jess: slept through the night next to you. no 3 AM fridge light. 💛", "closeness", 8]},
	"pouch": {2: ["LifeOS: Cravings detected and survived. LifeOS cannot sell you anything for this. Respect.", "stress", -6],
		4: ["Brookfield Family Dental: \"Dr. Lin says your gums are already calmer. Keep it up!\"", "stress", -8]},
	"rx_extra": {2: ["LifeOS: Two days on the prescribed dose. Your afternoon is slower and your nights are longer. Fair trade.", "energy", 10],
		4: ["LifeOS: Refill date is back on schedule. The pharmacist smiled. Pharmacists don't smile.", "energy", 10]},
}
func _update_clean_streaks() -> void:
	var used := {"drink": int(today["drink"]) > 0, "pouch": int(today["pouch"]) > 0, "rx_extra": int(today["rx_dose"]) > 1}
	for k in clean:
		if used[k]:
			clean[k] = 0
		elif used_ever[k]:
			clean[k] += 1
			var tab: Dictionary = CLEAN_LINES[k]
			if tab.has(clean[k]) and not notices_seen.has("clean_%s_%d" % [k, clean[k]]):
				notices_seen["clean_%s_%d" % [k, clean[k]]] = true
				var r: Array = tab[clean[k]]
				set(r[1], clampi(int(get(r[1])) + int(r[2]), 0, 100))
				lifeos_message.emit(r[0])

func _check_crash() -> void:
	if rx_last_dose >= 0 and not rx_active() and not today["crashed"]:
		today["crashed"] = true
		var drop := 10 if rx_plan else 20
		energy = clampi(energy - drop, 0, 100)
		stress = clampi(stress + 8, 0, 100)
		lifeos_message.emit("LifeOS: Focus session ended. Looks like lunch got skipped. Energy: -%d. Maybe eat something?" % drop)

func _lifeos_comment(id: String) -> String:
	match id:
		"gaming":
			return "LifeOS: Leisure detected. Your competitors are also playing video games. Everyone's fine."
		"bedtime_story":
			return "LifeOS: Bedtime story logged. This is the good stuff, Dan."
		"work_ticket":
			return "LifeOS: Ticket closed! 1 down, ∞ to go. Somebody's day just got easier, though."
		"pickup_girls":
			return "LifeOS: Commute logged. Brayden Kole's 4 AM Club played for 22 min. The girls drowned it out singing. Good."
	return LIFEOS_TIPS[rng.randi() % LIFEOS_TIPS.size()]

func end_day() -> Dictionary:
	if week_over:
		return {}
	var slept_min: int = clampi(DAY_END + 330 - minutes, 0, 600)  # until 6:30 AM next day
	# Sleep quality: 7h ~ full, 5h ~ 60. Alcohol and late Rx doses make it shallower.
	var quality := 1.0
	var notes: Array[String] = []
	if today["drink"] > 0:
		quality -= 0.12 * today["drink"]
		notes.append("woke at 3:12 AM, very awake")
	if rx_last_dose >= 0 and minutes - rx_last_dose < 600:
		quality -= 0.25
		notes.append("lay awake watching the ceiling fan")
	quality = maxf(quality, 0.35)
	var restore: int = int(round(slept_min / 60.0 * 14.0 * quality))
	var summary := {
		"day": day_name(),
		"bed_time": clock_text(),
		"sleep_hours": slept_min / 60.0,
		"sleep_quality": int(quality * 100),
		"tickets": today["tickets"],
		"texts": today["text_jess"],
		"bedtime": today["bedtime_story"] > 0,
		"kid_actions": today["kid_actions"],
		"energy_before": energy,
	}
	closeness = clampi(closeness - 3, 0, 100)   # life drifts a little every day
	if today["text_jess"] == 0:
		closeness = clampi(closeness - 8, 0, 100)
	if today["bedtime_story"] == 0:
		girls_connected = clampi(girls_connected - 10, 0, 100)
	_update_clean_streaks()
	_check_achievements()
	if day < 5:
		performance = clampi(performance - (20 if today["tickets"] == 0 else 15), 0, 100)  # the queue refills overnight
	if phase == "work" or phase == "drive":
		girls_connected = clampi(girls_connected - 15, 0, 100)  # never made it home
	girls_fed = clampi(girls_fed - 20, 0, 100)
	stress = clampi(stress + (5 if slept_min * quality < 360 else -10), 0, 100)
	energy = clampi(energy + restore, 0, 100)
	var q := "" if notes.is_empty() else " (" + "; ".join(notes) + ")"
	summary["sleep_text"] = "Sleep: %dh %02dm, quality %d%%%s. Today: %s. Tomorrow's a new day." % [slept_min / 60, slept_min % 60, int(quality * 100), q, "Solid work" if today["tickets"] > 1 else "A quiet one"]
	summary["energy_after"] = energy
	var ms: Array = today["moments"]
	summary["moment"] = ms[rng.randi() % ms.size()] if not ms.is_empty() else ("You made it. That counts." if today["kid_actions"] > 0 else "A blur. Tomorrow, maybe the park.")
	week_moments.append(summary["moment"])
	summary["drawings"] = fridge_drawings
	day_ended.emit(summary)
	day += 1
	if day >= 7:
		week_over = true
		day = 6
		week_ended.emit(weekly_review())
	else:
		_start_day()
	return summary

func weekly_review() -> String:
	var fatherhood := "Wonderful (June gives it two thumbs up)" if week_stats["bedtimes"] >= 5 else "Pretty great (June wants more dragon voices)" if week_stats["bedtimes"] >= 3 else "Missed you (Lily saved you a drawing)"
	var marriage := "In sync" if closeness >= 60 else "A little out of sync. Worth some time together."
	var career := "Exceeds Expectations (Karen sent a muffin)" if performance >= 70 else "Meets Expectations" if performance >= 40 else "Gary would like to check in. He seems nice about it."
	var s := "LIFEOS QUARTERLY-WEEKLY PERFORMANCE REVIEW: Week 1\n" \
		+ "Fatherhood ........ %s\n" % fatherhood \
		+ "Bedtimes attended . %d/7\n" % week_stats["bedtimes"] \
		+ "Marriage .......... %s\n" % marriage \
		+ "Career ............ %s (%d tickets)\n" % [career, week_stats["tickets"]] \
		+ "Side Hustle ....... Pre-revenue, post-sleep. Dreams are allowed.\n" \
		+ "Self-Care ......... %s\n" % ("Running low. Be gentle with yourself." if stress > 50 else "Detected! LifeOS is so proud.")
	# Subtle lines: only appear if relevant, never as a score.
	if week_stats["drinks"] > 0:
		s += "Hydration ......... %s\n" % ("More beer than water this week" if week_stats["drinks"] >= 8 else "Could use more water")
	if gum_damage >= 14:
		s += "Oral Health ....... Dr. Lin would like to see you soon\n"
	elif week_stats["pouches"] > 0:
		s += "Oral Health ....... Worth a cleaning soon\n"
	if week_stats["rx_extra"] > 0:
		s += "Focus ............. Big highs, rough crashes. Maybe chat with your doctor\n"
	if hustle > 0:
		s = s.replace("Side Hustle ....... Pre-revenue, post-sleep. Dreams are allowed.\n", "Side Hustle ....... %s\n" % ("$%d from Marisol's bakery. Founder (per LifeOS). Dan (per Jess)." % (50 if hustle >= 3 else 0) if hustle >= 3 else "%d late nights on the bakery script. Almost there." % hustle))
	if not achievements.is_empty():
		var names: Array[String] = []
		for a in achievements: names.append(ACHIEVEMENTS[a][0])
		s += "Achievements ...... " + ", ".join(names) + "\n"
	if notices_seen.has("choice_talk_honest"):
		s += "Honesty ........... You told Jess the truth. That's the hard part, apparently.\n"
	s += "Fridge gallery .... %d drawing%s\n" % [fridge_drawings, "" if fridge_drawings == 1 else "s"]
	if not week_moments.is_empty():
		var best: Array[String] = []
		for m in week_moments:
			if not (m in best) and not m.begins_with("A blur") and not m.begins_with("You made it"):
				best.append(m)
		if not best.is_empty():
			s += "Moments ........... " + "; ".join(best.slice(0, 3)) + "\n"
	for k in clean:
		if used_ever[k] and clean[k] >= 2:
			s += "Streaks ........... %d clean day%s (%s). Someone noticed.\n" % [clean[k], "" if clean[k] == 1 else "s", {"drink": "no beer", "pouch": "no pouches", "rx_extra": "Rx as prescribed"}[k]]
	return s + "Manager comment: \"Great energy! Let's circle back on everything. Also, genuinely, get some rest.\"\n\n" \
		+ ending_text()

## Week-end tone: which week did Dan actually have? (Picks the strongest signal.)
func ending_id() -> String:
	var subs: int = week_stats["drinks"] + week_stats["pouches"] / 3 + week_stats["rx_extra"] * 2
	if notices_seen.has("choice_talk_honest") or (subs > 0 and subs < 15 and (clean["drink"] >= 2 or clean["pouch"] >= 2 or clean["rx_extra"] >= 2)):
		return "turning"
	if subs >= 15:
		return "foggy"
	if stress >= 75:
		return "crispy"
	if closeness >= 70 and girls_connected >= 70 and stress <= 50:
		return "cozy"
	if performance >= 80 and (closeness < 40 or girls_connected < 40):
		return "uptime"
	return "real"

func ending_text() -> String:
	match ending_id():
		"turning":
			return "ENDING — The Turning Point: Uptime this week: not great. Honesty: up. Jess said 'together' like she meant it. The recycling bin has never been emptier."
		"cozy":
			return "ENDING — Pancake Sunday: Uptime 99.2%. SLA: 100%. Nobody in this house noticed the missing 0.8%. The fridge is running out of magnets."
		"uptime":
			return "ENDING — Five Nines: The servers had a perfect week. Lily drew the servers. They were the only thing in the picture. Gary sent a thumbs-up emoji. Next week can be different."
		"crispy":
			return "ENDING — Crispy: LifeOS rates your burnout 'golden brown.' Jess hands you the TV remote and the good blanket and says 'nope' to everything else. Rest is next week's ticket #1."
		"foggy":
			return "ENDING — Foggy: The week happened mostly around you. Nobody's angry. They just miss you, a little, at the table. The Gas-N-Sip sign is on, as always. So is the porch light."
	return "ENDING — A Real Week: Not a perfect week. A real one. Uptime 99.2%, SLA 100%, pancakes 100%."

func _fmt(m: int) -> String:
	var h := (m % 1440) / 60
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m % 60, "AM" if h < 12 else "PM"]

# ------------------------------------------------------------------ cutscene choices
## effect id -> [deltas, result line]. Applied by Main when a choice is picked.
const CHOICES := {
	"shoes_rca": [{"connected": 5, "minutes": 10}, "Root cause: couch. Mitigation: shoe basket. June signs off on the postmortem."],
	"shoes_mom": [{"closeness": 2}, "You escalate to Mommy. Jess resolves it in four seconds without looking up. Humbling. Romantic, a little."],
	"shoes_new": [{"money": -30, "connected": 3}, "You declare the old shoes deprecated. New shoes have lights. June will never sleep again."],
	"chaos_laugh": [{"connected": 6, "energy": -4, "stress": -3}, "You laugh. The girls laugh. Somehow this became the best part of the day."],
	"chaos_calm": [{"connected": 2, "stress": 2}, "Calm voice, clear rule, quick fix. Nobody cried. Not even you. Professional."],
	"chaos_art": [{"connected": 5, "closeness": 2}, "Jess walks in, sees it, and joins in. Somehow it's a family tradition now."],
	"radio_4am": [{"stress": 3}, "Brayden Kole explains 'micro-sleeps.' You feel personally attacked by a man who owns a gong."],
	"radio_oldies": [{"stress": -4}, "The oldies station plays the song from your wedding. The ska one. You drum on the wheel."],
	"radio_quiet": [{"stress": -3, "energy": 2}, "Silence. Just the turn signal, ticking like a very patient clock."],
	"dinner_listen": [{"connected": 5, "closeness": 3}, "You put your phone face-down. Lily tells a 9-minute story about a worm. It's honestly gripping."],
	"dinner_jess": [{"closeness": 6}, "You ask Jess about her day first. She blinks like you've patched a bug she reported in 2019."],
	"dinner_work": [{"closeness": -2, "performance": 2}, "You explain DNS to the table. June falls asleep in her taco. It was a good explanation, though."],
	"match_more": [{"stress": -4, "energy": -6, "minutes": 30}, "One more match. You lose. One more. You win. It's 30 minutes later and you are, somehow, at peace."],
	"match_bed": [{"energy": 3}, "You log off mid-lobby. Your teammates will survive. Probably. You go to bed like an adult."],
	"triage_fix": [{"performance": 3, "minutes": 10, "energy": -2}, "You fix it properly, root cause and all. Future you sends present you a thank-you note."],
	"triage_escalate": [{"stress": -3, "performance": -1}, "Escalated to Gary. Gary escalates it to 'the vendor'. The vendor is a man named Phil. Phil is on vacation."],
	"triage_reboot": [{"performance": 1}, "\"Have you tried turning it off and on again?\" They had not. It works. The oldest magic."],
	"page_story": [{"connected": 8, "performance": -4, "stress": 3}, "You finish the story first. The dragon wins. The server waits 6 minutes. Nobody remembers the outage. Lily will remember the dragon."],
	"page_take": [{"performance": 5, "connected": -3}, "You take the page. Lily says \"It's okay, Daddy.\" She means it. That's the hard part. Jess finishes the dragon voice. It's a different dragon."],
	"talk_honest": [{"closeness": 8, "honesty": 15, "stress": -6}, "\"Yeah. It's been more than I want it to be.\" Jess takes your hand. \"Okay. We'll figure it out. Together, like the IKEA bed.\""],
	"talk_deflect": [{"closeness": -4, "honesty": -10}, "\"Just a long week.\" Jess nods. She doesn't push. That's somehow worse."],
	"talk_joke": [{"closeness": -2, "honesty": -5}, "\"The recycling is just very enthusiastic.\" Jess smiles, but only with her mouth."],
}
func apply_choice(eid: String) -> String:
	if not CHOICES.has(eid):
		return ""
	var c: Array = CHOICES[eid]
	for k in c[0]:
		match k:
			"minutes": minutes = mini(minutes + int(c[0][k]), DAY_END)
			"money": money = maxi(money + int(c[0][k]), 0)
			"connected": girls_connected = clampi(girls_connected + int(c[0][k]), 0, 100)
			"performance": performance = clampi(performance + int(c[0][k]), 0, 100)
			_: set(k, clampi(int(get(k)) + int(c[0][k]), 0, 100))
	notices_seen["choice_" + eid] = true
	if eid == "talk_honest":
		clean["drink"] = maxi(clean["drink"], 1)   # saying it out loud is day one
	today["log"].append(c[1])
	state_changed.emit()
	return c[1]

# ------------------------------------------------------------------ save/load
const SAVE_PATH := "user://uptime_save.json"
const SAVE_VARS := ["day", "energy", "stress", "performance", "closeness", "girls_fed", "girls_connected", "money",
	"beers", "pouches", "drinks_week", "gum_damage", "rx_pills", "rx_extra_total", "notices_seen", "week_stats",
	"fridge_drawings", "honesty", "hustle", "achievements", "patch_days", "rx_plan", "moments_seen", "clean", "used_ever", "week_moments"]

## Saves at the start of a day (the game autosaves every morning).
func save_game(path: String = SAVE_PATH) -> bool:
	var d := {"version": 1}
	for v in SAVE_VARS:
		d[v] = get(v)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true

func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)

## Loads a morning save. Returns false if missing/corrupt (game state untouched).
func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or int(d.get("version", 0)) != 1:
		return false
	for v in SAVE_VARS:
		if not d.has(v):
			return false
	for v in SAVE_VARS:
		var x = d[v]
		if typeof(get(v)) == TYPE_INT:
			x = int(x)
		elif v == "week_moments":
			var arr: Array[String] = []
			for m in x: arr.append(str(m))
			x = arr
		elif x is Dictionary:
			var dd := {}
			for k in x: dd[k] = int(x[k]) if (x[k] is float) else x[k]
			x = dd
		set(v, x)
	week_over = false
	_start_day()
	return true

func delete_save(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
