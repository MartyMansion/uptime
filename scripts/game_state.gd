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
const ANY := ["home_am", "work", "drive", "home_pm"]

const PHASE_NAMES := {"home_am": "Home (morning)", "work": "At work — TriCounty Managed Services",
	"drive": "Drive home — Gas-N-Sip", "home_pm": "Home (evening)"}

# action id -> definition. blocks = 30-min blocks. energy = delta.
const ACTIONS := {
	"feed_girls": {"name": "Make breakfast with the girls", "blocks": 1, "energy": -5, "fed": 35, "connected": 5, "once": true, "phases": ["home_am"]},
	"cereal": {"name": "Cereal and screens", "blocks": 1, "energy": 0, "fed": 20, "connected": -5, "once": true, "phases": ["home_am"]},
	"leave_for_work": {"name": "Drop girls at school, drive to work", "blocks": 2, "energy": -3, "phases": ["home_am"]},
	"work_ticket": {"name": "Work a ticket", "blocks": 2, "energy": -10, "stress": 5, "perf": 8, "phases": ["work", "home_pm"]},
	"coffee_break": {"name": "Coffee break with the team", "blocks": 1, "energy": 8, "stress": -4, "phases": ["work"]},
	"head_home": {"name": "Head home", "blocks": 1, "energy": 0, "phases": ["work"]},
	"buy_beer": {"name": "Grab a six-pack ($12)", "blocks": 0, "energy": 0, "money": -12, "phases": ["drive"]},
	"buy_pouches": {"name": "Grab a tin of nic pouches ($7)", "blocks": 0, "energy": 0, "money": -7, "phases": ["drive"]},
	"pickup_girls": {"name": "Just drive on and pick up the girls", "blocks": 1, "energy": -3, "phases": ["drive"]},
	"play_girls": {"name": "Play with Lily & June", "blocks": 1, "energy": -5, "stress": -5, "connected": 12, "phases": ["home_pm"]},
	"bedtime_story": {"name": "Bedtime story", "blocks": 1, "energy": -5, "connected": 20, "after": 1170, "before": 1260, "once": true, "phases": ["home_pm"]},
	"gaming": {"name": "Play video games", "blocks": 2, "energy": 5, "stress": -20, "phases": ["home_pm"]},
	"drink": {"name": "Have a beer", "blocks": 0, "energy": -2, "stress": -10, "phases": ["home_pm"]},
	"pouch": {"name": "Nic pouch", "blocks": 0, "energy": 0, "stress": -6, "phases": ANY},
	"rx_dose": {"name": "Take Rx (prescribed: 1/day)", "blocks": 0, "energy": 15, "phases": ["home_am", "work", "home_pm"]},
	"text_jess": {"name": "Text Jess (thoughtful)", "blocks": 0, "energy": -2, "closeness": 6, "max_per_day": 3, "phases": ANY},
	"sleep": {"name": "Go to sleep", "blocks": 0, "energy": 0, "phases": ["home_pm"]},
}

const TICKETS := [
	"\"Printer is printing. Is this normal? URGENT\" (It was normal. She sent a thank-you GIF.)",
	"\"Can you make the internet faster? —Sent from my iPad\" (You moved him closer to the router. He called you a wizard.)",
	"\"Can I install a screensaver with fish on it?\" (You found a safe one. The fish are very calm.)",
	"\"What's the Wi-Fi password?\" (You taped it to the conference room wall. Solved forever. Probably.)",
	"\"Outlook froze again, sorry to bug you!\" —Karen in Accounts Payable (She left a muffin on your desk.)",
	"\"The server room is making a noise. A different noise.\" (A tired fan. Fixed. The servers hum happily.)",
	"\"Reply-all thread re: WHO TOOK MY YOGURT (47 replies)\" (The yogurt was found. Everyone is relieved.)",
	"\"Our chatbot told a customer we offer free kittens. Do we?\" (We do not. You fixed it. A little sad, honestly.)",
]
const JESS_TEXTS := [
	"Jess: On hold with insurance for 52 min. The hold music has a bridge now. I'm learning the words.",
	"Jess: Can you grab milk on the way? June wants to 'review' the oat one again.",
	"Jess: Hospital had a pizza lunch for the billing team. Saved you a slice. Thinking of you.",
	"Jess: Lily asked what your job is. I said 'he helps people when their computers are sad.' She approves.",
	"Jess: Friendly reminder the shared calendar exists 💛 June has picture day Thursday.",
]
const LIFEOS_TIPS := [
	"LifeOS: Tip: Sleep restores Energy. LifeOS also recommends: blankets.",
	"LifeOS: Tip: Your daughters can't be optimized. Our engineers say this is a feature.",
	"LifeOS: Tip: It's always DNS. Except when it's the cable. Check the cable.",
	"LifeOS: Tip: Drink some water! LifeOS believes in you. LifeOS is also a little thirsty.",
	"LifeOS: Feeling overwhelmed by notifications? So is LifeOS. Let's both take a deep breath.",
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
	week_over = false
	week_stats = {"bedtimes": 0, "tickets": 0, "texts": 0, "gaming_blocks": 0, "drinks": 0, "pouches": 0, "rx_extra": 0}
	_start_day()

func _start_day() -> void:
	minutes = DAY_START
	phase = "home_am"
	rx_until = -1
	rx_last_dose = -1
	today = {"tickets": 0, "text_jess": 0, "bedtime_story": 0, "kid_actions": 0, "gaming": 0,
		"drink": 0, "pouch": 0, "rx_dose": 0, "crashed": false, "log": []}
	state_changed.emit()
	day_started.emit()

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
		return "Jess is busy at work. She'll text back later."
	if a.has("money") and money + int(a["money"]) < 0:
		return "Card declined. Money's a little tight this week."
	match id:
		"head_home":
			if minutes < OFF_WORK:
				return "Not quite quittin' time. Maybe after 4."
		"drink":
			if beers <= 0:
				return "Fridge: oat milk, juice boxes, one lemon."
		"pouch":
			if pouches <= 0:
				return "Tin's empty."
		"rx_dose":
			if rx_pills <= 0:
				return "Pharmacy: \"Too early to refill.\""
		"play_girls":
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
	if id == "sleep":
		end_day()
		return "Lights out."
	var a: Dictionary = ACTIONS[id]
	var blocks: int = int(a["blocks"])
	var e: int = int(a["energy"])
	var perf: int = int(a.get("perf", 0))
	if id == "work_ticket" and rx_active():
		e = -5          # focus: tickets feel easy...
		perf += 4
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
	match id:
		"leave_for_work":
			phase = "work"
			line = "School drop-off: both shoes found! You badge in at %s." % clock_text()
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
			if rx_active():
				line += "\n(Everything is very clear. Almost too clear.)"
		"coffee_break":
			line = "Coffee with the team. Karen shows everyone her new puppy. You feel a little more human."
		"text_jess":
			week_stats["texts"] += 1
			line = JESS_TEXTS[rng.randi() % JESS_TEXTS.size()] + "\nYou: (a thoughtful reply)"
		"bedtime_story":
			week_stats["bedtimes"] += 1
			line = "June negotiated two more books. Worth it."
			if today["drink"] >= 3:
				line += "\nLily: \"You did the dragon voice twice.\""
		"gaming":
			week_stats["gaming_blocks"] += 2
			today["gaming"] += 1
			line = "One more match. Stress down. Where did the time go?"
		"drink":
			beers -= 1
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
				week_stats["rx_extra"] += 1
				line = "Another one, just to get through the afternoon. The bottle says 1 daily."
				if rx_extra_total >= 3 and not notices_seen.has("rx_refill"):
					notices_seen["rx_refill"] = true
					lifeos = "LifeOS: Pharmacy reminder: at this pace your refill runs out %d days early. Maybe a good thing to mention to your doctor." % rx_extra_total
			else:
				line = "Rx taken. The browser tabs feel less loud. Focus: on."
			rx_last_dose = minutes
			rx_until = minutes + RX_DURATION
			today["crashed"] = false
	if id in ["feed_girls", "play_girls", "bedtime_story", "cereal"]:
		today["kid_actions"] += 1
	_check_crash()
	if lifeos == "" and id == "work_ticket" and is_on_fumes() and rx_last_dose >= 0 and not rx_active() and rx_pills > 0:
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

func _check_crash() -> void:
	if rx_last_dose >= 0 and not rx_active() and not today["crashed"]:
		today["crashed"] = true
		energy = clampi(energy - 20, 0, 100)
		stress = clampi(stress + 8, 0, 100)
		lifeos_message.emit("LifeOS: Focus session ended. Looks like lunch got skipped. Energy: -20. Maybe eat something?")

func _lifeos_comment(id: String) -> String:
	match id:
		"gaming":
			return "LifeOS: Leisure detected! Rest is productive too. LifeOS read that somewhere."
		"bedtime_story":
			return "LifeOS: Bedtime story logged. This is the good stuff, Dan."
		"work_ticket":
			return "LifeOS: Ticket closed! Somebody's day just got easier. Nice work."
		"pickup_girls":
			return "LifeOS: Commute logged. The girls sang the whole way. LifeOS rates it 5 stars."
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
	if today["text_jess"] == 0:
		closeness = clampi(closeness - 8, 0, 100)
	if today["bedtime_story"] == 0:
		girls_connected = clampi(girls_connected - 10, 0, 100)
	if today["tickets"] == 0 and day < 5:
		performance = clampi(performance - 10, 0, 100)
	if phase == "work" or phase == "drive":
		girls_connected = clampi(girls_connected - 15, 0, 100)  # never made it home
	girls_fed = clampi(girls_fed - 20, 0, 100)
	stress = clampi(stress + (5 if slept_min * quality < 360 else -10), 0, 100)
	energy = clampi(energy + restore, 0, 100)
	var q := "" if notes.is_empty() else " (" + "; ".join(notes) + ")"
	summary["sleep_text"] = "Sleep: %dh %02dm, quality %d%%%s. Today: %s. Tomorrow's a new day." % [slept_min / 60, slept_min % 60, int(quality * 100), q, "Solid work" if today["tickets"] > 1 else "A quiet one"]
	summary["energy_after"] = energy
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
		+ "Side Hustle ....... Still a dream. Dreams are allowed.\n" \
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
	return s + "Manager comment: \"Thanks for everything this week, Dan. Get some rest.\"\n\n" \
		+ "ENDING (stub): Not a perfect week. A real one. Pancakes on Sunday."

func _fmt(m: int) -> String:
	var h := (m % 1440) / 60
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m % 60, "AM" if h < 12 else "PM"]
