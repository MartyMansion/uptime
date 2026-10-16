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
const OFF_WORK := 810    # 1:30 PM: earliest Dan can head home (or after WORK_TICKETS_TO_LEAVE tickets)
const WORK_TICKETS_TO_LEAVE := 2
const WORK_TICKET_BLOCKS := 5   # at the office a ticket is ~2.5 h of in-game time (Marty: the workday dragged)
const WORK_TICKET_MAX := 3
const PERF_DRIFT := 3
const HOME_TICKET_MAX := 2      # the 3rd is "staying late": costs family time
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
	"work_ticket": {"name": "Work a ticket (terminal)", "blocks": 2, "energy": -12, "stress": 5, "perf": 3, "phases": ["work", "home_pm", "weekend"]},
	"coffee_break": {"name": "Coffee break with the team", "blocks": 1, "energy": 8, "stress": -4, "phases": ["work"]},
	"head_home": {"name": "Head home", "blocks": 1, "energy": 0, "phases": ["work"]},
	"buy_beer": {"name": "Grab a six-pack ($12)", "blocks": 0, "energy": 0, "money": -12, "phases": ["drive"]},
	"buy_pouches": {"name": "Grab a tin of nic pouches ($7)", "blocks": 0, "energy": 0, "money": -7, "phases": ["drive"]},
	"buy_patch": {"name": "Nicotine patches instead ($15)", "blocks": 0, "energy": 0, "money": -15, "phases": ["drive"]},
	"call_doctor": {"name": "Call Dr. Patel about the Rx", "blocks": 1, "energy": -2, "stress": -4, "once": true, "phases": ["work"]},
	"pickup_girls": {"name": "Back in the car (town map)", "blocks": 1, "energy": -3, "phases": ["drive"]},
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
	"water_plant": {"name": "Water the porch tomato (June helps)", "blocks": 0, "energy": -1, "stress": -2, "once": true, "phases": ["home_am", "home_pm", "weekend"]},
	"sleep": {"name": "Go to sleep", "blocks": 0, "energy": 0, "phases": HOME},
	# Garage homelab (data-center path). Main runs the interactive assembly, then calls this.
	# UI-only verbs (Main opens a screen / changes room; never run through do_action).
	"pc": {"name": "Use the PC (desktop)", "blocks": 0, "energy": 0, "ui": true, "phases": ["home_am", "home_pm", "weekend"]},
	"go_garage": {"name": "Go to the garage", "blocks": 0, "energy": 0, "ui": true, "phases": ["home_am", "home_pm", "weekend"]},
	"go_inside": {"name": "Back inside", "blocks": 0, "energy": 0, "ui": true, "phases": ["home_am", "home_pm", "weekend"]},
	"farm_check": {"name": "Check the farm (FarmStat)", "blocks": 0, "energy": 0, "ui": true, "phases": ["home_am", "home_pm", "weekend"]},
	"build_farm": {"name": "Build the next delivered box", "blocks": 1, "energy": -6, "stress": -2, "phases": ["home_am", "home_pm", "weekend"]},
}

# Calendar: day index -> event. Shown in the HUD; some unlock actions.
const CALENDAR := {
	0: {"id": "", "text": "Monday. The fridge calendar says nothing. Suspicious."},
	1: {"id": "picture", "text": "Picture day! (Hair: attempted)"},
	2: {"id": "", "text": "Taco Wednesday (household law). Jess has pickup today."},
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
	"Jess: Hospital gave us pizza instead of a raise again. Saved you a slice. It is the one with the burnt corner. It is yours. ❤",
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
var terminal_ticket := false       # set while a terminal ticket resolves (no triage popup)
var pending_choice := ""          # Main turns this into a choice cutscene after the action
var hustle: int = 0                 # side hustle sessions (AI script for Marisol's bakery)
var achievements: Array[String] = []
var girl_time := {"lily": 0, "june": 0}   # per-girl attention this week (hidden)
var girl_quiet := {"lily": 0, "june": 0}  # consecutive days with no one-on-one
var plant: int = 0                 # porch tomato growth (cozy loop)
var skills := {}                   # category -> xp
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
	girls_fed = 55
	girls_connected = 50
	money = 200
	beers = 0
	pouches = 0
	drinks_week = 0
	gum_damage = 0
	rx_pills = 30
	rx_extra_total = 0
	notices_seen = {}
	incidents_week = 0
	pending_incident = ""
	fridge_drawings = 0
	honesty = 50
	skills = {}
	for c in SKILL_NAMES: skills[c] = 0
	plant = 0
	girl_time = {"lily": 0, "june": 0}
	girl_quiet = {"lily": 0, "june": 0}
	hustle = 0
	achievements = []
	patch_days = 0
	rx_plan = false
	moments_seen = {}
	clean = {"drink": 0, "pouch": 0, "rx_extra": 0}
	used_ever = {"drink": false, "pouch": false, "rx_extra": false}
	week_moments = []
	farm = {}
	orders = []
	boxes = []
	farm_income_total = 0
	farm_outages = 0
	farm_days = 0
	farm_history = []
	week_over = false
	week_stats = {"bedtimes": 0, "tickets": 0, "texts": 0, "gaming_blocks": 0, "drinks": 0, "pouches": 0, "rx_extra": 0}
	_start_day()

var _morning_snap := {}   # pre-morning state; saves always store this so loading replays the morning exactly once

func _snapshot() -> Dictionary:
	var d := {"version": 2}
	for v in SAVE_VARS:
		var x = get(v)
		d[v] = x.duplicate(true) if (x is Dictionary or x is Array) else x
	return d

func _start_day() -> void:
	_morning_snap = _snapshot()
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
	girls_picked = false
	at_place = "home"
	_deliver()
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
	if ACTIONS.get(id, {}).get("ui", false):
		return "(That's a place, not a verb. Walk there.)"
	if id == "build_farm" and notices_seen.has("choice_garage_curfew") and minutes >= 1260:
		return "Garage curfew (9 PM). The servers are asleep. Cron says so. Jess says so."
	if id == "build_farm" and boxes.is_empty():
		return "No boxes in the garage. (PCEggo has a sale. PCEggo always has a sale.)"
	if week_over:
		return "The week is over. LifeOS is putting your review together."
	if not ACTIONS.has(id):
		return "Unknown action."
	var a: Dictionary = ACTIONS[id]
	if not (phase in a["phases"]):
		return "Not right now."
	var cost_min: int = action_blocks(id) * BLOCK
	# Allow a partial last block (choices can leave the clock off the 30-min grid);
	# the action just runs into 1 AM and the day ends.
	# Getting home is never blocked by the clock (persona bug: stranded at the desk at 1 AM).
	if not (id in TRAVEL) and minutes + cost_min > DAY_END and (minutes + cost_min - DAY_END >= BLOCK or minutes >= DAY_END):
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
	if id in ["buy_beer", "buy_pouches", "buy_patch"] and at_place not in ["gas", "pharmacy"]:
		return "Not here. The Gas-N-Sip is on the map."
	if id == "buy_patch" and at_place not in ["gas", "pharmacy"]:
		return "Not here."
	match id:
		"head_home":
			if not can_leave_work():
				return "Gary is doing a lap. Your coat is very visible. Close %d more ticket%s (or wait till 1:30)." % [WORK_TICKETS_TO_LEAVE - int(today.get("tickets", 0)), "" if WORK_TICKETS_TO_LEAVE - int(today.get("tickets", 0)) == 1 else "s"]
		"work_ticket":
			if phase != "work" and int(today.get("home_tickets", 0)) >= HOME_TICKET_MAX:
				return "LifeOS: The laptop lid is closed. It's family time. (Max %d tickets from home a day.)" % HOME_TICKET_MAX
			if phase == "work" and int(today.get("tickets", 0)) >= WORK_TICKET_MAX:
				return "Three tickets is a full day. The rest will be there tomorrow. Go home."
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

## Walking away from a half-worked ticket still costs the time you spent poking at it.
## (Persona bug: walk-away was free, so the clock could freeze at the desk / tickets could be rerolled.)
func charge_walkaway(cmds: int) -> int:
	if cmds < 3:
		return 0
	var blocks := 1 if cmds < 12 else 2
	minutes = mini(minutes + blocks * BLOCK, DAY_END)
	energy = clampi(energy - 2 * blocks, 0, 100)
	girls_fed = clampi(girls_fed - blocks * (1 if phase in ["work", "drive"] else 2), 0, 100)
	state_changed.emit()
	return blocks * BLOCK

# ------------------------------------------------------------ town map (Marty: Stardew-style travel)
var girls_picked := false
var at_place := "home"
const PICKUP_OPEN := 840    # 2:00 PM after-care opens (pass 2: was 2:30; closes the dead hour)
const PICKUP_CLOSE := 1110  # 6:30 PM after-care closes (miss it and Jess has to leave work)
## id: [name, map x, map y (0..1), travel minutes, open, close, blurb]
const PLACES := {
	"home": ["Home", 0.125, 0.72, 15, 0, 1440, "Home. The porch tomato awaits."],
	"school": ["School (Brookfield Elementary)", 0.344, 0.33, 15, PICKUP_OPEN, PICKUP_CLOSE, "After-care pickup."],
	"gas": ["Gas-N-Sip", 0.578, 0.62, 10, 0, 1440, "Beer, pouches, patches, regret-free jerky."],
	"park": ["Riverside Park", 0.353, 0.77, 20, 360, 1260, "Ducks. A pond. A bench with your name on it (it says 'Reserved')."],
	"pharmacy": ["Pharmacy (Route 9)", 0.094, 0.33, 15, 540, 1140, "Refills and patches. The pharmacist knows your birthday."],
	"dental": ["Dental (Brookfield Family Dental)", 0.844, 0.78, 20, 480, 1020, "Dr. Lin. A cleaning. A gentle lecture."],
	"diner": ["Lou's Diner", 0.5, 0.39, 15, 420, 1260, "Pie. Coffee. Booths that have seen things."],
	"coffee": ["Coffee (Bean There)", 0.797, 0.222, 10, 360, 1140, "Drip coffee, a scone, ten quiet minutes. +energy, -stress ($4)."],
	"office": ["Office (TriCounty)", 0.906, 0.39, 25, 420, 1080, "Work."],
}

func jess_has_girls() -> bool:
	return day == 2   # Taco Wednesday: Jess's half day, she does pickup

## Destinations shown on the map right now: [id, label, minutes, why_locked ("" = available)].
func map_options() -> Array:
	var out: Array = []
	for id in PLACES:
		var p: Array = PLACES[id]
		var why := ""
		var mins: int = p[3]
		if phase == "home_am":
			if id == "office":
				mins = 120   # drop-off at school on the way
				why = can_do("leave_for_work")
			else:
				why = "School morning. Office first (drop-off on the way)."
		elif phase == "drive":
			if id == at_place: why = "You're here."
			elif id == "office": why = "Already badged out. Don't look back."
			elif id == "home" and not girls_picked and not jess_has_girls():
				why = "Pick up the girls first (after-care, %s–%s)." % [_fmt(PICKUP_OPEN), _fmt(PICKUP_CLOSE)]
			elif id == "school" and (girls_picked or jess_has_girls()):
				why = "Girls are in the car." if girls_picked else "Jess has pickup today."
			elif id != "home" and (minutes < int(p[4]) or minutes + mins > int(p[5])):
				why = "Open %s–%s." % [_fmt(int(p[4])), _fmt(int(p[5]))]
			elif id in ["dental"] and today.get("dental", 0) > 0: why = "Teeth: done for today."
			elif minutes + mins > DAY_END: why = "Too late."
			if id == "school" and why == "" and minutes < PICKUP_OPEN: why = "After-care opens %s." % _fmt(PICKUP_OPEN)
		else:
			why = "Not right now."
		out.append([id, p[0], mins, why])
	return out

## Travel to a map destination. Returns a result line ("" + reason if refused).
func travel(dest: String) -> String:
	var opt: Array = []
	for o in map_options():
		if o[0] == dest: opt = o
	if opt.is_empty(): return "Nowhere by that name. (The map is small. Brookfield is small.)"
	if opt[3] != "": return opt[3]
	if dest == "office": return do_action("leave_for_work")
	if dest == "home": return do_action("pickup_girls")
	minutes = mini(minutes + int(opt[2]), DAY_END)
	girls_fed = clampi(girls_fed - (1 if opt[2] >= 15 else 0), 0, 100)
	at_place = dest
	var line := ""
	match dest:
		"school":
			girls_fed = clampi(girls_fed + SNACK_FED, 0, 100)   # after-care snack
			girls_picked = true
			girls_connected = clampi(girls_connected + 3, 0, 100)
			line = "After-care pickup. June reports three 'incidents' and a new best friend. Lily has opinions about the radio."
		"gas":
			line = "Gas-N-Sip. The fluorescent lights hum a song about choices." + (" The girls want slushies." if girls_picked else "")
		"park":
			stress = clampi(stress - 8, 0, 100)
			if girls_picked:
				girls_connected = clampi(girls_connected + 8, 0, 100)
				line = "Riverside Park. June names a duck 'Gary'. Lily pretends not to have fun, then has fun."
			else:
				line = "Riverside Park. You sit by the pond. A duck judges you, but gently."
		"pharmacy":
			if not today.get("pharmacy", false) and money >= 10:
				today["pharmacy"] = true
				money -= 10
				rx_pills += 10
				line = "Route 9 Pharmacy: refill picked up ($10). The pharmacist reminds you: 'as prescribed, hon.'"
			else:
				line = "Route 9 Pharmacy. You browse the seasonal aisle. It's already Christmas here."
		"coffee":
			if money >= 4:
				money -= 4
				energy = clampi(energy + 8, 0, 100)
				stress = clampi(stress - 4, 0, 100)
				line = "Bean There Coffee: drip, a scone, and ten minutes where nobody needs anything. Barista: 'Rough one?' You: 'Ticket-shaped.' ($4)"
			else:
				line = "Bean There Coffee: free water and a sympathetic nod."
		"dental":
			today["dental"] = 1
			stress = clampi(stress - 4, 0, 100)
			line = "Brookfield Family Dental: Dr. Lin squeezes you in. 'Your gums tell me things, Dan.' They're gentle about it."
		"diner":
			if money >= 18:
				money -= 18
				energy = clampi(energy + 6, 0, 100)
				if girls_picked:
					girls_fed = clampi(girls_fed + 30, 0, 100)
					closeness = clampi(closeness + 2, 0, 100)
					line = "Lou's Diner: pancakes for dinner. June orders 'the biggest one'. Everyone is fed ($18)."
				else:
					line = "Lou's Diner: pie and coffee at the counter ($18). Lou calls you 'chief'."
			else:
				line = "Lou's Diner: you check your wallet, then order water. Lou slides you a free roll. Lou is good people."
	var warn := _check_pickup_window()
	if warn != "": lifeos_message.emit(warn)
	if not girls_picked and not jess_has_girls() and phase == "drive" and minutes >= PICKUP_CLOSE - 45 and not today.get("pickup_warned", false):
		today["pickup_warned"] = true
		lifeos_message.emit("LifeOS: After-care closes at %s. The girls are doing the 'last kids at pickup' face." % _fmt(PICKUP_CLOSE))
	state_changed.emit()
	if minutes >= DAY_END: end_day()
	return line

const FED_WARN := 35
const SNACK_FED := 15
## Nobody fed the girls by 7:30 PM: Jess makes grilled cheese. Fed recovers, Jess notices.
func _jess_dinner_fallback() -> String:
	if phase in ["home_pm", "weekend"] and minutes >= 1170 and girls_fed < 30 and not today.get("jess_dinner", false):
		today["jess_dinner"] = true
		girls_fed = clampi(girls_fed + 25, 0, 100)
		closeness = clampi(closeness - 3, 0, 100)
		week_stats["jess_dinners"] = int(week_stats.get("jess_dinners", 0)) + 1
		return "LifeOS: Jess made grilled cheese while you were… elsewhere. Girls: Fed +25. Jess: -3 (she noticed; she's not mad, she's tired)."
	return ""

# ------------------------------------------------------------ performance has teeth (pass 2)
const PERF_CHECKIN := 40
const PERF_PIP := 25
const BONUS_PERF := 75
const BONUS_AMT := 60
func on_pip() -> bool:
	return int(week_stats.get("pip", 0)) == 1

## Called at the end of each workday (after the overnight perf changes).
func _performance_consequences() -> void:
	if performance < PERF_CHECKIN and not notices_seen.has("gary_checkin"):
		notices_seen["gary_checkin"] = true
		stress = clampi(stress + 6, 0, 100)
		lifeos_message.emit("Gary (Teams): \"Got 10 min tomorrow? Just a check-in. Bring nothing. Not even a laptop.\" LifeOS: Job Performance is under %d. Two clean tickets a day keeps Gary's calendar empty." % PERF_CHECKIN)
	if performance < PERF_PIP and not on_pip():
		week_stats["pip"] = 1
		stress = clampi(stress + 10, 0, 100)
		lifeos_message.emit("Gary, gently: \"HR says I have to call this a Performance Improvement Plan. I'm calling it a 'Plan'. Autopilot's suspended until you're back over %d. We'll get there.\" Stress +10." % PERF_CHECKIN)
	elif on_pip() and performance >= PERF_CHECKIN:
		week_stats["pip"] = 2
		lifeos_message.emit("Gary: \"Plan's closed. You're good. I printed it out so I could shred it in front of you.\" Autopilot restored.")
	if day == 4:
		if performance >= BONUS_PERF:
			money += BONUS_AMT
			week_stats["bonus"] = BONUS_AMT
			lifeos_message.emit("Payroll: Spot bonus +$%d. Gary's note says 'for keeping the lights on.' He drew a lightbulb. It's not good. It's sweet." % BONUS_AMT)
		else:
			week_stats["bonus"] = 0
			lifeos_message.emit("Payroll: No spot bonus this week (needs Job Performance %d+). Gary: \"Next week. I believe in you. I believe in most people.\"" % BONUS_PERF)

## Missed the pickup window: Jess leaves work to get them; the family meters take the hit.
func _check_pickup_window() -> String:
	if is_weekend() or girls_picked or jess_has_girls() or minutes <= PICKUP_CLOSE or phase not in ["work", "drive"]:
		return ""
	girls_picked = true
	girls_connected = clampi(girls_connected - 15, 0, 100)
	closeness = clampi(closeness - 8, 0, 100)
	stress = clampi(stress + 8, 0, 100)
	week_stats["missed_pickups"] = int(week_stats.get("missed_pickups", 0)) + 1
	return "LifeOS: After-care called. Twice. Jess left work to get the girls. June waited by the window. Girls: -15, Jess: -8."

## Time cost in blocks; office tickets are long, home ones (on-call laptop) are short.
func action_blocks(id: String) -> int:
	if id == "work_ticket" and phase == "work":
		return WORK_TICKET_BLOCKS
	return int(ACTIONS[id]["blocks"])

func can_leave_work() -> bool:
	return int(today.get("tickets", 0)) >= WORK_TICKETS_TO_LEAVE or minutes >= OFF_WORK

## Performs an action. Returns a result line for the UI.
func do_action(id: String) -> String:
	var why := can_do(id)
	if why != "":
		return why
	if id == "build_farm":
		return build_box()
	pending_choice = ""
	if id == "sleep":
		end_day()
		return ["Lights out.", "Lights out. June asks for water. Lights out again.", "Lights out. The house ticks. Somebody snores. It might be you."][day % 3]
	var a: Dictionary = ACTIONS[id]
	var blocks: int = action_blocks(id)
	var e: int = int(a["energy"])
	var perf: int = int(a.get("perf", 0))
	if id == "work_ticket" and rx_active():
		e = -5          # focus: tickets feel easy...
		perf += 3
	if id == "work_ticket" and phase != "work":
		perf = mini(perf, 1)   # on-call laptop at home: keeps the lights on, doesn't impress Gary
		today["home_tickets"] = int(today.get("home_tickets", 0)) + 1
	minutes = mini(minutes + blocks * BLOCK, DAY_END)
	energy = clampi(energy + e, 0, 100)
	stress = clampi(stress + int(a.get("stress", 0)), 0, 100)
	performance = clampi(performance + perf, 0, 100)
	closeness = clampi(closeness + int(a.get("closeness", 0)), 0, 100)
	girls_fed = clampi(girls_fed + int(a.get("fed", 0)), 0, 100)
	girls_connected = clampi(girls_connected + int(a.get("connected", 0)), 0, 100)
	money += int(a.get("money", 0))
	girls_fed = clampi(girls_fed - blocks * (1 if phase in ["work", "drive"] else 2), 0, 100)  # at school they get lunch
	today[id] = int(today.get(id, 0)) + 1
	var line: String = a["name"]
	var lifeos := ""
	var before_min: int = minutes - blocks * BLOCK
	match id:
		"leave_for_work":
			girls_fed = clampi(girls_fed + 20, 0, 100)   # packed lunches (Jess made them; you remembered them)
			phase = "work"
			line = ["School drop-off: both shoes found! You badge in at %s.", "Drop-off: June hugs the crossing guard. Lily pretends not to know you. You badge in at %s.",
				"Drop-off: picture day hair held for 11 whole minutes. You badge in at %s.", "Drop-off: Lily practices her recorder in the car. Your ears badge in at %s.",
				"Drop-off: June gives you a rock 'for work'. It's on your desk now. You badge in at %s."][day % 5] % clock_text()
		"head_home":
			phase = "drive"
			at_place = "road"
			line = "You badge out. After-care closes at 6:30. The girls know exactly what time it is." if not jess_has_girls() else "You badge out. Jess has the girls today. The town is, briefly, yours."
		"buy_beer":
			beers += 6
			line = "Six-pack in the passenger seat."
		"buy_pouches":
			pouches += 15
			line = "Tin of pouches. The cashier already knows your usual."
		"pickup_girls":
			if not girls_picked and not jess_has_girls() and minutes < PICKUP_OPEN:
				minutes = PICKUP_OPEN   # the car line: everyone waits, nobody talks about it
			if not girls_picked:
				girls_fed = clampi(girls_fed + SNACK_FED, 0, 100)   # after-care snack
			girls_picked = true
			at_place = "home"
			phase = "home_pm"
			line = "After-care pickup. Lily: \"Why does the car smell like the gas station?\"" if today.get("buy_beer", 0) + today.get("buy_pouches", 0) > 0 else "After-care pickup. June reports three 'incidents', and a new best friend."
		"work_ticket":
			today["tickets"] += 1
			week_stats["tickets"] += 1
			line = "Closed ticket: " + TICKETS[rng.randi() % TICKETS.size()]
			if phase == "work" and today["tickets"] > WORK_TICKETS_TO_LEAVE:
				# Staying late: the 3rd ticket costs family time.
				closeness = clampi(closeness - 5, 0, 100)
				girls_connected = clampi(girls_connected - 6, 0, 100)
				lifeos = "LifeOS: Stayed late. June asked after-care if Daddy 'lives at work now'. The after-care lady didn't have a good answer. Jess: -5, Girls: -6."
			if phase == "work" and rng.randf() < 0.2 and not terminal_ticket:
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
		"water_plant":
			plant += 1
			girl_time["june"] += 1
			today["girl_june"] = true
			line = ["June waters the tomato and also your shoes. The tomato appreciates it. The shoes do not.",
				"The tomato has a leaf now. June has named it 'Server'. You are deeply moved.",
				"Two leaves! June reads it a story. Lily says plants can't hear. June reads louder.",
				"A flower! June calls Jess outside to see. Jess comes. That's the whole thing. It was nice.",
				"A tiny green tomato. June wants to eat it now. You explain patience. She explains hunger."][mini(plant, 5) - 1]
			if plant >= 6:
				line = "The tomato is red. June picks it, cuts it into 4 pieces with great ceremony, and everyone eats one. Best tomato of your life."
				if not notices_seen.has("tomato"):
					notices_seen["tomato"] = true
					_moment("June's tomato, split four ways.")
		"buy_patch":
			patch_days += 5
			line = "Patches. The cashier raises an eyebrow, then gives you a tiny nod. Gas-N-Sip solidarity."
		"play_girls":
			line = ["Floor is lava. June wins, rules unclear. Lily referees and is bribed with a cracker.",
				"Tea party. You are served invisible tea and told it's too hot. You blow on it. June approves.",
				"Hide and seek. June hides in the same spot every time. You never find her. Never.",
				"Lily teaches you a card game she invented. You lose. The rules change twice. You lose faster.",
				"Pillow fort. Load-bearing couch cushions. Lily is the architect. June is the wrecking ball."][(day * 3 + int(today.get("play_girls", 1))) % 5]
		"feed_girls":
			line = ["Scrambled eggs. June asks for 'the crunchy ones'. You burnt them on purpose. Teamwork.",
				"Toast cut into triangles, per contract. Lily reviews it: four stars, 'too squared'.",
				"Oatmeal with a face made of raisins. June eats the face first. Every time.",
				"Pancake shapes: a heart, a dog, and an accident June calls 'Gary'.",
				"Banana and peanut-butter toast. Everyone is fed. Nobody cried. A five-nines breakfast."][day % 5]
		"call_doctor":
			rx_plan = true
			honesty = clampi(honesty + 10, 0, 100)
			closeness = clampi(closeness + 5, 0, 100)   # you told Jess too
			line = "You call Dr. Patel and tell her about the extra doses. She doesn't gasp. She adjusts the plan. Hold music: pan flute, but supportive. Afterwards you tell Jess. She just squeezes your hand."
		"coffee_break":
			line = ["Coffee with the team. Karen shows everyone her new puppy. You feel a little more human.", "Coffee with the team. Karen's puppy has learned 'sit'. Gary has not.", "Coffee with the team. Gary tells a joke from a 2009 email forward. You laugh. You're a team player."][day % 3]
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
			line = "One more match. Stress down. Time: gone. Worth it, probably."
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
			line = ["Pouch in. A brief, quiet calm. Upper lip, left side, same spot as always.", "Pouch in. Your lip has a reserved parking spot.", "Pouch in. Calm arrives on schedule. It's the only thing that does."][int(today.get("pouch", 1)) % 3]
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
				line = ["Another one, just to get through the afternoon. The bottle says 1 daily.",
					"A second one. The bottle's instructions are short. You read them anyway. Then you don't.",
					"Extra dose. The focus comes back. So does the little voice that counts the pills."][0 if rx_extra_total <= 1 else 1 + (rx_extra_total % 2)]
				if rx_extra_total >= 3 and not notices_seen.has("rx_refill"):
					notices_seen["rx_refill"] = true
					lifeos = "LifeOS: Pharmacy reminder: at this pace your refill runs out %d days early. Maybe a good thing to mention to your doctor." % rx_extra_total
			else:
				line = ["Rx taken. The 47 browser tabs close themselves, emotionally. Focus: on.", "Rx taken. Your brain closes the tabs. One stays open. It's always the one about the dishwasher."][day % 2]
			rx_last_dose = minutes
			rx_until = minutes + RX_DURATION
			today["crashed"] = false
	# Per-girl attention: Lily (9) likes reading/homework/concerts, June (6) likes play/park/chaos.
	var who := {"homework": ["lily"], "concert": ["lily"], "play_girls": ["june"], "walk_park": ["june", "lily"],
		"bedtime_story": ["lily", "june"], "pancakes": ["june", "lily"], "feed_girls": ["june", "lily"]}
	if who.has(id):
		for g in who[id]:
			girl_time[g] += 1
			today["girl_" + g] = true
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
	if pending_choice == "" and phase == "home_pm" and day < 5 and minutes >= 1140 and minutes <= 1320 and incidents_week < 2 and not today.get("paged", false) and rng.randf() < 0.07:
		today["paged"] = true
		pending_choice = "incident_page"
	if lifeos == "" and girls_fed < FED_WARN and not today.get("fed_warned", false) and phase in ["home_am", "home_pm", "weekend", "drive"]:
		today["fed_warned"] = true
		lifeos = "LifeOS: ⚠ Girls: Fed %d%% — they're hungry. June is eating dry cereal from the box and calling it 'dinner crunch'. Fix: Family dinner (kitchen, after 5 PM), Lou's Diner on the map, or breakfast (cereal/pancakes) in the morning." % girls_fed
	var jd := _jess_dinner_fallback()
	if jd != "": lifeos_message.emit(jd)
	_check_relationships()
	if lifeos == "" and id == "work_ticket" and is_on_fumes() and not rx_plan and rx_last_dose >= 0 and not rx_active() and rx_pills > 0:
		lifeos = "LifeOS: Energy low. Maybe a snack or a short walk? (LifeOS is not a doctor. LifeOS is an app that worries.)"
	today["log"].append(line)
	action_performed.emit(id, line)
	if lifeos == "":
		lifeos = _check_pickup_window()
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
	"repair": ["honesty", 65, "Jess: I noticed you're trying. Not perfect. Trying. I see it."],
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
			if k == "repair": closeness = clampi(closeness + 8, 0, 100)   # repair is visible (therapist pass)
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
			return "LifeOS: Ticket closed! 1 down, ∞ to go. Somewhere a printer is printing. You did that."
		"pickup_girls":
			return "LifeOS: Commute logged. Brayden Kole's 4 AM Club played for 22 min. The girls drowned it out singing. Good."
	return LIFEOS_TIPS[rng.randi() % LIFEOS_TIPS.size()]

func end_day() -> Dictionary:
	if week_over:
		return {}
	var slept_min: int = clampi(DAY_END + 330 - minutes, 0, 600)  # until 6:30 AM next day
	# Job performance drifts down each workday: the inbox refills whether or not you're there.
	# (Rebalance: perf was ~99 for nearly every playstyle.)
	if day < 5:
		performance = clampi(performance - PERF_DRIFT, 0, 100)
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
	for g in girl_quiet:
		girl_quiet[g] = 0 if today.get("girl_" + g, false) else girl_quiet[g] + 1
		if girl_quiet[g] == 2:
			girls_connected = clampi(girls_connected - 4, 0, 100)
			lifeos_message.emit({"lily": "LifeOS: Lily left a book on your pillow, open to the part where the dragon shows up. Subtle as a P1.",
				"june": "LifeOS: June left a drawing on your keyboard: you, her, and a big question mark. She's six. She's not subtle."}[g])
	_check_achievements()
	if day < 5:
		performance = clampi(performance - (20 if today["tickets"] == 0 else 15), 0, 100)  # the queue refills overnight
		_performance_consequences()
	if phase == "work" or phase == "drive":
		girls_connected = clampi(girls_connected - 15, 0, 100)  # never made it home
	summary["farm"] = _farm_night()
	girls_fed = clampi(girls_fed - 10, 0, 100)   # overnight (was -15; pass 2)
	stress = clampi(stress + (5 if slept_min * quality < 360 else -10), 0, 100)
	energy = clampi(energy + restore, 0, 100)
	var q := "" if notes.is_empty() else " (" + "; ".join(notes) + ")"
	summary["sleep_text"] = "Sleep: %dh %02dm, quality %d%%%s. Today: %s. Tomorrow's a new day." % [slept_min / 60, slept_min % 60, int(quality * 100), q, "Solid work" if today["tickets"] > 1 else "A quiet one"]
	summary["energy_after"] = energy
	var ms: Array = today["moments"]
	summary["moment"] = ms[rng.randi() % ms.size()] if not ms.is_empty() else ("You made it. That counts." if today["kid_actions"] > 0 else "A blur. Tomorrow, maybe the park.")
	week_moments.append(summary["moment"])
	summary["drawings"] = fridge_drawings
	summary["lily"] = today.get("girl_lily", false)
	summary["june"] = today.get("girl_june", false)
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
		+ ("Gary's 'Plan' ...... %s\n" % ("Open. Autopilot suspended." if on_pip() else "Closed. Shredded with ceremony.") if int(week_stats.get("pip", 0)) > 0 else "") \
		+ ("Spot bonus ........ %s\n" % ("+$%d" % int(week_stats["bonus"]) if int(week_stats["bonus"]) > 0 else "None this week") if week_stats.has("bonus") else "") \
		+ ("Incidents ......... %d (SLA breaches: %d)\n" % [int(week_stats.get("incidents", 0)), int(week_stats.get("sla_breaches", 0))] if int(week_stats.get("incidents", 0)) > 0 else "") \
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
	if notices_seen.has("choice_talk_honest"):
		return "turning"
	if subs >= 15:
		return "foggy"
	# Burnout outranks a small clean streak (pass 2: Crispy was unreachable).
	if stress >= 70 or (on_pip() and stress >= 40) or (performance < PERF_PIP and stress >= 35):
		return "crispy"
	if subs > 0 and (clean["drink"] >= 2 or clean["pouch"] >= 2 or clean["rx_extra"] >= 2):
		return "turning"
	var cozy := closeness >= 70 and girls_connected >= 70 and stress <= 50
	# A thriving family week outranks a server week, unless the farm is a real little business.
	if homelab_earned() and (not cozy or farm_income_total >= HOMELAB_BUSINESS):
		return "homelab"
	if cozy:
		return "cozy"
	if performance >= 85 and not on_pip() and int(week_stats.get("sla_breaches", 0)) == 0 and (closeness < 40 or girls_connected < 40):
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
			return ("(You're on Gary's 'Plan'. He brought donuts to the meeting. That made it worse.) " if on_pip() else "") + "ENDING — Crispy: LifeOS rates your burnout 'golden brown.' Jess hands you the TV remote and the good blanket and says 'nope' to everything else. Rest is next week's ticket #1."
		"homelab":
			return "ENDING — Mercer Data Center (Est. This Week): %d servers hum in the garage, net $%d. Jess calls it 'the other kid'. June named the rack 'Server' too. Lily hung a status page on the fridge: DADDY: OPERATIONAL. Five nines is next." % [farm_online(), farm_income_total]
		"foggy":
			return "ENDING — Foggy: The week happened mostly around you. Nobody's angry. They just miss you, a little, at the table. The Gas-N-Sip sign is on, as always. So is the porch light."
	return "ENDING — A Real Week: Not a perfect week. A real one. Uptime 99.2%, SLA 100%, pancakes 100%."

func _fmt(m: int) -> String:
	var h := (m % 1440) / 60
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m % 60, "AM" if h < 12 else "PM"]

# ------------------------------------------------------------------ Dan's skills
const SKILL_NAMES := {"networking": "Networking & ports", "dns": "DNS", "storage": "Storage", "services": "Services",
	"accounts": "Accounts & auth", "certs": "Certificates", "printers": "Printers"}
const KIND_SKILL := {"port": "networking", "vlan": "networking", "dns": "dns", "disk": "storage", "service": "services",
	"lockout": "accounts", "cert": "certs", "printer": "printers"}
const SKILL_LEVELS := [0, 40, 100, 180, 300]     # xp needed for Lv 1..5 (index = level-1)
const PROFICIENT := 3                            # autopilot unlocks at this level
const XP_FOR := {"typed": 6, "great": 30, "good": 20, "slow": 12, "autopilot": 4, "incident": 45}

func skill_of(kind: String) -> String:
	return KIND_SKILL.get(kind, "networking")

func skill_level(cat: String) -> int:
	var xp: int = int(skills.get(cat, 0))
	var lv := 1
	for i in SKILL_LEVELS.size():
		if xp >= SKILL_LEVELS[i]: lv = i + 1
	return lv

## [xp into this level, xp needed for next] (next = 0 at max level)
func skill_progress(cat: String) -> Array:
	var lv := skill_level(cat)
	var xp: int = int(skills.get(cat, 0))
	if lv >= SKILL_LEVELS.size(): return [xp - SKILL_LEVELS[-1], 0]
	return [xp - SKILL_LEVELS[lv - 1], SKILL_LEVELS[lv] - SKILL_LEVELS[lv - 1]]

func autopilot_unlocked(cat: String) -> bool:
	# On a PIP, autopilot is allowed once per day (the newbie needed it most exactly then).
	return skill_level(cat) >= PROFICIENT and (not on_pip() or not today.get("pip_autopilot", false))

## Hints per ticket: 2 + level/2 (1 when running on fumes).
func max_hints(cat: String) -> int:
	return 1 if is_on_fumes() else 2 + skill_level(cat) / 2

## Autopilot quality grows with skill: Lv3 "autopilot", Lv5 "good".
func autopilot_grade(cat: String) -> String:
	return "good" if skill_level(cat) >= 5 else "autopilot"

func add_xp(cat: String, grade: String) -> String:
	var before := skill_level(cat)
	skills[cat] = int(skills.get(cat, 0)) + int(XP_FOR.get(grade, 10))
	var after := skill_level(cat)
	if after > before:
		var msg := "LifeOS: %s Lv %d! %s" % [SKILL_NAMES[cat], after, "Autopilot unlocked for this category. Use responsibly. (You won't.)" if after == PROFICIENT else "Your future self is slightly less tired."]
		lifeos_message.emit(msg)
		return msg
	return ""

# ------------------------------------------------------------------ terminal tickets
## Applies a finished terminal ticket. grade: great / good / slow / autopilot.
## Baseline work_ticket = 60 min, -10 energy, +4 perf, +5 stress; the grade bends it.
const TICKET_GRADES := {
	"great": {"min": -30, "energy": 3, "perf": 2, "stress": -6, "tag": "Clean fix. Root cause found, nothing broken, nobody had to reboot anything twice."},
	"good": {"min": 0, "energy": 1, "perf": 1, "stress": -2, "tag": "Solid fix. A little wandering, but you got there."},
	"slow": {"min": 30, "energy": -3, "perf": -1, "stress": 2, "tag": "Fixed, eventually. The scenic route. The user waited, kindly."},
	"autopilot": {"min": 0, "energy": 0, "perf": -2, "stress": 3, "tag": "Autopilot: you ran the runbook without reading it. It worked. You learned nothing. Gary noticed nothing."},
}
const TYPED_BONUS_XP := 6   # keep in sync with XP_FOR["typed"]
func resolve_ticket(grade: String, title: String, reply: String, kind := "", typed := false) -> String:
	if can_do("work_ticket") != "":
		return can_do("work_ticket")
	var d0 := day
	terminal_ticket = true
	var line := do_action("work_ticket")
	terminal_ticket = false
	if day != d0 or week_over:
		return line
	var g: Dictionary = TICKET_GRADES.get(grade, TICKET_GRADES["good"])
	minutes = clampi(minutes + int(g["min"]), DAY_START, DAY_END)
	energy = clampi(energy + int(g["energy"]), 0, 100)
	performance = clampi(performance + int(g["perf"]), 0, 100)
	stress = clampi(stress + int(g["stress"]), 0, 100)
	week_stats["ticket_" + grade] = int(week_stats.get("ticket_" + grade, 0)) + 1
	if kind != "":
		add_xp(skill_of(kind), "autopilot" if grade == "autopilot" else grade)
		if typed and grade != "autopilot":
			add_xp(skill_of(kind), "typed")
	var out := "Closed ticket: %s\n%s%s\n%s" % [title, g["tag"], ("  (+%d XP: typed it yourself)" % TYPED_BONUS_XP) if typed and kind != "" and grade != "autopilot" else "", reply]
	today["log"][-1] = out
	state_changed.emit()
	if minutes >= DAY_END:
		end_day()
	return out

# ------------------------------------------------------------------ incidents
var pending_incident := ""          # set by the after-hours page choice; Main opens it
var incidents_week := 0

## Applies a finished incident. Returns the postmortem text.
func resolve_incident(inc_id: String, used_min: int, breached: bool, after_hours: bool, autopilot := false, commands := 0, hints := 0, budget := 90, optimal := 0) -> String:
	var inc: Dictionary = TicketSim.INCIDENTS[inc_id]
	incidents_week += 1
	week_stats["incidents"] = int(week_stats.get("incidents", 0)) + 1
	var blocks := maxi(1, int(ceil(used_min / float(BLOCK))))
	minutes = mini(minutes + blocks * BLOCK, DAY_END)
	energy = clampi(energy - 6 * blocks, 0, 100)
	var perf := 3 if autopilot else (-3 if breached else 8)
	if breached: week_stats["sla_breaches"] = int(week_stats.get("sla_breaches", 0)) + 1
	performance = clampi(performance + perf, 0, 100)
	stress = clampi(stress + (14 if breached else 6), 0, 100)
	if after_hours:
		closeness = clampi(closeness - 4, 0, 100)
		girls_connected = clampi(girls_connected - 5, 0, 100)
	for k in inc["stages"]:
		add_xp(skill_of(k), "autopilot" if autopilot else "incident")
	today["tickets"] += 1
	week_stats["tickets"] += 1
	var lines: Array[String] = [
		"POSTMORTEM — %s" % inc["name"],
		"Time to resolve: %d min (SLA: %d)%s" % [used_min, budget, "  ⚠ SLA breached by %d min" % (used_min - budget) if breached else "  ✔ within SLA"],
		"Stages: %s" % " → ".join(inc["stages"].map(func(k): return SKILL_NAMES[skill_of(k)])),
		"Commands: %d   Hints: %d%s" % [commands, hints, "   (autopilot)" if autopilot else ""],
		"Blameless root cause: %s" % {"site_outage": "a 'temporary' firewall rule and a tired service.", "ransomware": "a convincing fake invoice. Karen has been hugged and enrolled in training.",
			"backup_restore": "the backup disk filled up in March. Nobody was watching the watcher.", "db_corruption": "the DB crashed mid-write on a full disk.",
			"ups_failure": "a UPS battery older than June.", "cert_outage": "auto-renew was set to 'later'. Later came."}[inc_id],
		("What cost time (fair feedback): fastest path was %d commands; you ran %d (+%d extra; real steps cost 4 min, typos 1) and read %d hint%s (cheap at low skill, 6 min for an expert). Next time: follow the runbook order, and check before you change." % [optimal, commands, maxi(0, commands - optimal), hints, "" if hints == 1 else "s"]) if breached and optimal > 0 else "Action items: add a monitor, add a calendar reminder, add a nap.",
		"Impact on home: %s" % ("you missed part of the evening. Jess saved you a plate and a look. The girls drew you a 'server hero' picture anyway." if after_hours else "none. You made it home on time-ish."),
		"Gary: %s" % ("\"Thank you. Truly. Go home.\"" if not breached else "\"We got there. That's what counts. Let's write the postmortem and never speak of it.\""),
	]
	if after_hours:
		_moment("Saved the servers, missed the dragon voice.")
	state_changed.emit()
	if minutes >= DAY_END:
		end_day()
	return "\n".join(lines)

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
	"phone_k": [{"closeness": 1}, "You: k 👍\nJess: 👍\n(A perfectly functional marriage protocol. Low bandwidth.)"],
	"phone_draft": [{"closeness": 2, "stress": 1}, "You type three paragraphs about how much you appreciate her. Delete. Send: ❤\nJess: ❤❤\n(She got all three paragraphs anyway.)"],
	"incident_handoff": [{"performance": -3, "stress": 2, "closeness": 2}, "You hand it to Raj. He owes you from the Great Printer Fire. You stay for the dragon voice. Raj handles it."],
	"garage_curfew": [{"closeness": 6, "stress": -2}, "You set a cron job called 'dad-curfew'. Jess reads it over your shoulder and laughs. The servers will sleep at nine."],
	"garage_onemore": [{"closeness": -4}, "\"One more box.\" Jess nods. She goes to bed. The box takes 40 minutes. The bed is cold-ish."],
	"garage_tour": [{"closeness": 4, "connected": 3}, "You give Jess the tour. She names the switch 'Gary'. June, in pajamas, names the rack 'Server'. Everyone is a stakeholder now."],
	"talk_honest": [{"closeness": 8, "honesty": 15, "stress": -6}, "\"Yeah. It's been more than I want it to be.\" Jess takes your hand. \"Okay. We'll figure it out. Together, like the IKEA bed.\""],
	"talk_deflect": [{"closeness": -4, "honesty": -10}, "\"Just a long week.\" Jess nods. She doesn't push. That's somehow worse."],
	"talk_joke": [{"closeness": -2, "honesty": -5}, "\"The recycling is just very enthusiastic.\" Jess smiles, but only with her mouth."],
}
func apply_choice(eid: String) -> String:
	if eid.begins_with("incident_take:"):
		pending_incident = eid.split(":")[1]
		return "You open the laptop at the kitchen table. Jess hands you a coffee and a look that says 'go save the internet'."
	if eid == "phone_thoughtful":
		return do_action("text_jess")
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
## Bots running in parallel set UPTIME_SAVE_TAG so each process has its own save slot.
var save_path: String = SAVE_PATH if OS.get_environment("UPTIME_SAVE_TAG") == "" else "user://uptime_save_%s.json" % OS.get_environment("UPTIME_SAVE_TAG")
const SAVE_VARS := ["day", "energy", "stress", "performance", "closeness", "girls_fed", "girls_connected", "money",
	"beers", "pouches", "drinks_week", "gum_damage", "rx_pills", "rx_extra_total", "notices_seen", "week_stats",
	"fridge_drawings", "honesty", "skills", "incidents_week", "plant", "girl_time", "girl_quiet", "hustle", "achievements", "patch_days", "rx_plan", "moments_seen", "clean", "used_ever", "week_moments",
	"farm", "orders", "boxes", "farm_income_total", "farm_outages", "farm_days", "farm_history"]

## Saves at the start of a day (the game autosaves every morning).
func save_game(path: String = "") -> bool:
	if path == "": path = save_path
	# Saves are "morning of" saves: mid-day F6 stores this morning, not the afternoon's meters
	# (which loading would otherwise replay a whole day on top of).
	var d := _morning_snap if not _morning_snap.is_empty() else _snapshot()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true

func has_save(path: String = "") -> bool:
	if path == "": path = save_path
	return FileAccess.file_exists(path)

## Loads a morning save. Returns false if missing/corrupt (game state untouched).
func load_game(path: String = "") -> bool:
	if path == "": path = save_path
	if not FileAccess.file_exists(path):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or int(d.get("version", 0)) != 2:
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

func delete_save(path: String = "") -> void:
	if path == "": path = save_path
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ------------------------------------------------------------ garage homelab (data-center win path, lite)
## Parody shops (original names). price $, watts drawn, "box": arrives as a box to build in the garage.
const SHOPS := {"pceggo": "PCEggo", "rackbay": "RackBay", "kevin": "Kilowatt Kevin's Power & Cooling"}
const CATALOG := {
	"server": {"name": "Refurb 1U server (2x Xeon, smells like 2016)", "shop": "pceggo", "price": 55, "watts": 180, "box": true},
	"drives": {"name": "4x used 2 TB drives (low hours, allegedly)", "shop": "pceggo", "price": 35, "watts": 20, "box": true},
	"nic": {"name": "10GbE NIC 2-pack (one works great)", "shop": "pceggo", "price": 20, "watts": 10, "box": true},
	"rack": {"name": "12U open-frame rack (some assembly, all regret)", "shop": "rackbay", "price": 45, "watts": 0, "box": true},
	"switch": {"name": "24-port managed switch (ex-bank, LOUD)", "shop": "rackbay", "price": 25, "watts": 40, "box": true},
	"ups": {"name": "1500VA UPS (new battery, old everything else)", "shop": "rackbay", "price": 60, "watts": 10, "box": true},
	"fans": {"name": "Box-fan cooling wall (4 fans + zip ties)", "shop": "kevin", "price": 25, "watts": 120, "box": true},
	"foam": {"name": "Acoustic foam panels (noise down, dignity down)", "shop": "kevin", "price": 18, "watts": 0, "box": true},
	"electrician": {"name": "Electrician visit: dedicated 20 A circuit", "shop": "kevin", "price": 95, "watts": 0, "box": false},
}
const POWER_RATE := 0.16          # $/kWh
# Tuned after the 12-persona pass: "any 2 servers" won 50-75% of farm runs. Now it needs a protected
# build (2+ online behind a UPS), a farm that paid for itself, at most 1 outage, and a family that
# didn't pay for it.
const HOMELAB_SERVERS := 2
const HOMELAB_NET := 35
const HOMELAB_MAX_OUTAGES := 1
const HOMELAB_BUSINESS := 140      # net $ for the farm to outrank a cozy week
const HOMELAB_CLOSENESS := 50
var farm := {}                    # item id -> installed count
var orders: Array = []            # [item id, delivery day]
var boxes: Array = []             # delivered, waiting in the garage
var farm_income_total: int = 0    # net (income - power), all time this week
var farm_outages: int = 0
var farm_days: int = 0
var farm_history: Array = []      # [day, net $, watts, outage cause ("", "power", "heat")]

## What buying one more of `id` would do right now (shop tooltips: tycoon/homelab pass).
func item_effect(id: String) -> String:
	var saved: Dictionary = farm.duplicate()
	for o in orders: farm[o[0]] = farm_has(o[0]) + 1
	for b in boxes: farm[b] = farm_has(b) + 1
	var on0 := farm_online(); var inc0 := farm_income_day() - farm_bill_day(); var h0 := farm_heat(); var n0 := farm_noise()
	var cap0 := _cap_with(farm_has("server") + 9)
	farm[id] = farm_has(id) + 1
	var on1 := farm_online(); var inc1 := farm_income_day() - farm_bill_day(); var h1 := farm_heat(); var n1 := farm_noise()
	var cap1 := _cap_with(farm_has("server") + 9)
	farm = saved
	var bits: Array[String] = []
	if on1 > on0: bits.append("+%d online" % (on1 - on0))
	if inc1 != inc0: bits.append("%+d $/day" % (inc1 - inc0))
	if cap1 > cap0: bits.append("unlocks server #%d" % (cap0 + 1))
	if id == "ups": bits.append("blips stop becoming outages")
	if h1 != h0: bits.append("heat %+d" % (h1 - h0))
	if n1 != n0: bits.append("noise %+d" % (n1 - n0))
	if id == "server" and on1 == on0: bits.append("won't run yet: " + ("needs a rack + switch" if farm_has("rack") == 0 or farm_has("switch") == 0 else "needs the electrician's circuit"))
	return ", ".join(bits) if not bits.is_empty() else "no effect yet"

func _cap_with(n_servers: int) -> int:
	var keep := farm_has("server")
	farm["server"] = n_servers
	var c := farm_online()
	farm["server"] = keep
	return c

func homelab_earned() -> bool:
	return farm_online() >= HOMELAB_SERVERS and farm_has("ups") > 0 and farm_income_total >= HOMELAB_NET and farm_outages <= HOMELAB_MAX_OUTAGES \
		and closeness >= HOMELAB_CLOSENESS and girls_connected >= 40

func farm_has(id: String) -> int:
	return int(farm.get(id, 0))

## Servers that can actually run: 1 on a shelf without a rack, 2 per household circuit
## without the electrician, and only 1 without a switch.
func farm_online() -> int:
	var n := farm_has("server")
	if farm_has("rack") == 0: n = mini(n, 1)
	if farm_has("electrician") == 0: n = mini(n, 2)
	if farm_has("switch") == 0: n = mini(n, 1)
	return n

func farm_watts() -> int:
	var w := farm_online() * int(CATALOG["server"]["watts"])
	for id in ["drives", "nic", "switch", "ups", "fans"]:
		w += farm_has(id) * int(CATALOG[id]["watts"])
	return w if farm_has("server") > 0 else 0

func farm_heat() -> int:      # 0..10
	return clampi(farm_online() * 2 + farm_has("switch") - farm_has("fans") * 3, 0, 10)

func farm_noise() -> int:     # 0..10
	return clampi(farm_online() * 2 + farm_has("switch") * 2 + farm_has("fans") - farm_has("foam") * 3, 0, 10)

func farm_income_day() -> int:
	var on := farm_online()
	return on * 14 + mini(farm_has("drives"), on) * 4 + (2 if farm_has("nic") > 0 and on > 0 else 0)

func farm_bill_day() -> int:
	return int(round(farm_watts() * 24 / 1000.0 * POWER_RATE))

func farm_status() -> String:
	var pend := orders.map(func(o): return CATALOG[o[0]]["name"].split(" (")[0])
	return "Servers online: %d / %d   Uptime this week: %s\nIncome: $%d/day   Power: %d W (~$%d/day)   Net so far: $%d\nHeat: %d/10   Noise: %d/10   Outages: %d\nBoxes in the garage: %d   On the way: %s" % [
		farm_online(), farm_has("server"), ("%d%%" % int(100.0 * (farm_days - farm_outages) / maxf(1.0, farm_days))) if farm_days > 0 else "n/a",
		farm_income_day(), farm_watts(), farm_bill_day(), farm_income_total, farm_heat(), farm_noise(), farm_outages, boxes.size(), ", ".join(pend) if not pend.is_empty() else "nothing"]

## Checkout from the parody shops: money check, next-day delivery.
func checkout(cart: Array) -> String:
	if cart.is_empty(): return "Your cart is empty. Like the rack."
	var total := 0
	for id in cart: total += int(CATALOG[id]["price"])
	if total > money: return "Card declined: total $%d, you have $%d. (The bank's fraud team thinks you're having a crisis. Fair.)" % [total, money]
	money -= total
	for id in cart: orders.append([id, day + 1])
	if not notices_seen.has("first_order"):
		notices_seen["first_order"] = true
		lifeos_message.emit("LifeOS: Order confirmed. Jess has been cc'd on the receipt. LifeOS cc's Jess on everything over $50. You agreed to this in 2024.")
	state_changed.emit()
	return "Order placed: $%d. Arrives tomorrow morning. The garage is about to become a lifestyle." % total

func _deliver() -> void:
	var arrived: Array = []
	var keep: Array = []
	for o in orders:
		if int(o[1]) <= day:
			if CATALOG[o[0]]["box"]: boxes.append(o[0])
			else: farm[o[0]] = farm_has(o[0]) + 1     # the electrician just installs it
			arrived.append(o[0])
		else:
			keep.append(o)
	orders = keep
	if not arrived.is_empty():
		lifeos_message.emit("LifeOS: Delivery: %d box%s on the porch (moved to the garage). %s" % [arrived.size(), "" if arrived.size() == 1 else "es",
			"The electrician came and went. New circuit: live." if "electrician" in arrived else "Jess watched the truck. Jess has questions."])

## Installs the first delivered box (the interactive assembly lives in Main).
func build_box() -> String:
	if boxes.is_empty(): return can_do("build_farm")
	var id: String = boxes.pop_front()
	farm[id] = farm_has(id) + 1
	minutes = mini(minutes + BLOCK, DAY_END)
	energy = clampi(energy - 6, 0, 100)
	if minutes >= 1080 and phase != "weekend":
		closeness = clampi(closeness - 2, 0, 100)   # garage time is evening time
		if not notices_seen.has("garage_talk") and (farm_noise() >= 4 or int(week_stats.get("late_builds", 0)) >= 1):
			notices_seen["garage_talk"] = true
			pending_choice = "garage_talk"
		week_stats["late_builds"] = int(week_stats.get("late_builds", 0)) + 1
	today["built"] = int(today.get("built", 0)) + 1
	state_changed.emit()
	var line: String = {"server": "Racked, cabled, powered on. The fans spin up. Somewhere in the house, Jess sighs in the same key.", "rack": "The rack stands. It is slightly crooked. It is yours.",
		"switch": "Switch in. Twenty-four ports, twenty-two of them for later.", "ups": "UPS in. It beeps once, judgmentally, then settles.", "drives": "Drives in. The RAID rebuild estimate says 'soon'.",
		"nic": "10GbE in. Now the bottleneck is you.", "fans": "Box-fan wall zip-tied. It's ugly. It's 6 degrees cooler.", "foam": "Foam up. The garage now sounds like a recording studio for one sad server."}.get(id, "Built.")
	if id == "server" and farm_has("server") > farm_online():
		line += " (It won't come online yet: %s.)" % ("you need a rack" if farm_has("rack") == 0 else ("you need a switch" if farm_has("switch") == 0 else "the house circuit can't take a third server; call an electrician"))
	action_performed.emit("build_farm", line)
	return line

## Overnight: income, power bill, heat/noise costs, and possible home incidents.
func _farm_night() -> String:
	if farm_has("server") == 0: return ""
	farm_days += 1
	var income := farm_income_day()
	var bill := farm_bill_day()
	var note := ""
	var p_power := 0.12 if farm_has("ups") == 0 else 0.0
	var p_heat := 0.15 if farm_heat() >= 5 else 0.0
	var cause := ""
	if farm_online() > 0 and rng.randf() < p_power + p_heat:
		cause = "power" if rng.randf() * (p_power + p_heat) < p_power else "heat"
		farm_outages += 1
		income /= 2
		stress = clampi(stress + 6, 0, 100)
		closeness = clampi(closeness - 3, 0, 100)
		if cause == "power":
			note = ["The breaker tripped during the microwave popcorn. Movie night: dark. Servers: also dark.",
				"Power blip. No UPS. The RAID is 'rebuilding' and so is your relationship with sleep."][rng.randi() % 2]
		else:
			note = "Heat alarm at 2 AM. You stood in the garage in boxers with a box fan. Jess filmed it." if farm_has("fans") == 0 else "Heat alarm at 2 AM. The box fans lost."
		lifeos_message.emit("LifeOS: HOME INCIDENT: " + note)
	var noise := farm_noise()
	if noise >= 4:
		closeness = clampi(closeness - (noise - 3), 0, 100)
		if noise >= 6: girls_connected = clampi(girls_connected - 2, 0, 100)
	var net := income - bill
	money += net
	farm_income_total += net
	farm_history.append([day, net, farm_watts(), cause])
	if day == 6:   # Sunday night: the week's power bill
		var wk := 0
		for h in farm_history: wk += int(round(int(h[2]) * 24 / 1000.0 * POWER_RATE))
		if not notices_seen.has("power_bill_%d" % day):
			notices_seen["power_bill_%d" % day] = true
			lifeos_message.emit("LifeOS: Brookfield Power & Light: your garage used %d kWh this week ($%d). Jess has opened the bill. Jess has questions." % [int(farm_history.reduce(func(a, h): return a + int(h[2]) * 24 / 1000.0, 0)), wk])
	return "Garage farm: +$%d income, -$%d power%s%s" % [income, bill, (" · noise %d/10 (Jess noticed)" % noise) if noise >= 4 else "", (" · OUTAGE: " + note) if note != "" else ""]
