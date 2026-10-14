extends Node
## Core simulation for the "One Week" slice. Pure data + rules, no visuals,
## so it can be driven by the house scene or by headless tests.

signal state_changed
signal lifeos_message(text: String)
signal day_ended(summary: Dictionary)
signal week_ended(review: String)

const DAY_NAMES := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DAY_START := 390   # 6:30 AM, in minutes
const DAY_END := 1500    # 1:00 AM next day
const BLOCK := 30        # one time block = 30 min
const FUMES := 20

# action id -> definition. blocks = 30-min blocks. energy = delta.
const ACTIONS := {
	"work_ticket": {"name": "Work a ticket", "blocks": 2, "energy": -10, "stress": 5, "perf": 8},
	"text_jess": {"name": "Text Jess (thoughtful)", "blocks": 0, "energy": -2, "closeness": 6, "max_per_day": 3},
	"feed_girls": {"name": "Make breakfast with the girls", "blocks": 1, "energy": -5, "fed": 35, "connected": 5, "before": 600},
	"cereal": {"name": "Cereal and screens", "blocks": 1, "energy": 0, "fed": 20, "connected": -5},
	"play_girls": {"name": "Play with Lily & June", "blocks": 1, "energy": -5, "stress": -5, "connected": 12, "after": 960},
	"bedtime_story": {"name": "Bedtime story", "blocks": 1, "energy": -5, "connected": 20, "after": 1170, "before": 1260, "once": true},
	"gaming": {"name": "Play video games", "blocks": 2, "energy": 5, "stress": -20},
	"sleep": {"name": "Go to sleep", "blocks": 0, "energy": 0},
}

const TICKETS := [
	"\"Printer is printing. Is this normal? URGENT\"",
	"\"Can you make the internet faster? —Sent from my iPad, CEO\"",
	"\"Need admin rights to install FreeScreenSaverz_REAL.exe for productivity\"",
	"\"What's the Wi-Fi password?\" (5th ticket today, same person, same conference room)",
	"\"Outlook is Not Responding. Neither am I. —Karen in Accounts Payable\"",
	"\"The server room is making a noise. A different noise.\"",
	"\"Reply-all storm re: WHO TOOK MY YOGURT (47 replies)\"",
	"\"Our AI chatbot told a customer we offer free kittens. Do we?\"",
]
const JESS_TEXTS := [
	"Jess: Insurance put me on hold for 52 min. The hold music has a bridge now.",
	"Jess: Can you grab milk? The real kind. Not the oat thing June 'reviewed'.",
	"Jess: Hospital gave us pizza instead of a raise again. Saving you a slice of disappointment.",
	"Jess: Lily asked if your job is real. I said 'legally, yes'.",
	"Jess: Did anyone open the shared calendar. Anyone. Ever.",
]
const LIFEOS_TIPS := [
	"LifeOS: Tip: Sleep restores Energy. Premium Sleep™ is available for $4.99/mo.",
	"LifeOS: Tip: Your daughters cannot be optimized. We tried.",
	"LifeOS: Tip: It's always DNS. Even when it isn't. Especially then.",
	"LifeOS: Tip: A 'quick call' has never once been quick.",
	"LifeOS: Feeling overwhelmed by notifications? Unlock Focus Mode+ for $6.99/mo.",
]

var day: int = 0
var minutes: int = DAY_START
var energy: int = 100
var stress: int = 20
var performance: int = 50
var closeness: int = 50
var girls_fed: int = 30
var girls_connected: int = 50
var week_over := false
var today := {}          # per-day counters
var week_stats := {"bedtimes": 0, "tickets": 0, "texts": 0, "gaming_blocks": 0}
var rng := RandomNumberGenerator.new()

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
	week_over = false
	week_stats = {"bedtimes": 0, "tickets": 0, "texts": 0, "gaming_blocks": 0}
	_start_day()

func _start_day() -> void:
	minutes = DAY_START
	today = {"tickets": 0, "text_jess": 0, "bedtime_story": 0, "kid_actions": 0, "gaming": 0, "log": []}
	state_changed.emit()

func day_name() -> String:
	return DAY_NAMES[day]

func clock_text() -> String:
	var m := minutes % 1440
	var h := m / 60
	var mm := m % 60
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, suffix]

func is_on_fumes() -> bool:
	return energy < FUMES

## Returns "" if allowed, otherwise a reason (LifeOS-flavored).
func can_do(id: String) -> String:
	if week_over:
		return "The week is over. LifeOS is compiling your review."
	if not ACTIONS.has(id):
		return "Unknown action."
	var a: Dictionary = ACTIONS[id]
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
		return "Jess is on hold with insurance. She'll see it later."
	var e: int = int(a["energy"])
	if e < 0 and energy + e < 0:
		return "You don't have it in you right now."
	if id in ["play_girls", "bedtime_story"] and is_on_fumes() and id == "play_girls":
		return "You don't have it in you right now. (Running on Fumes)"
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
	minutes += int(a["blocks"]) * BLOCK
	energy = clampi(energy + int(a["energy"]), 0, 100)
	stress = clampi(stress + int(a.get("stress", 0)), 0, 100)
	performance = clampi(performance + int(a.get("perf", 0)), 0, 100)
	closeness = clampi(closeness + int(a.get("closeness", 0)), 0, 100)
	girls_fed = clampi(girls_fed + int(a.get("fed", 0)), 0, 100)
	girls_connected = clampi(girls_connected + int(a.get("connected", 0)), 0, 100)
	# Hunger drifts with time.
	girls_fed = clampi(girls_fed - int(a["blocks"]) * 2, 0, 100)
	today[id] = int(today.get(id, 0)) + 1
	var line: String = a["name"]
	match id:
		"work_ticket":
			today["tickets"] += 1
			week_stats["tickets"] += 1
			line = "Closed ticket: " + TICKETS[rng.randi() % TICKETS.size()]
		"text_jess":
			week_stats["texts"] += 1
			line = JESS_TEXTS[rng.randi() % JESS_TEXTS.size()] + "\nYou: (a thoughtful reply)"
		"bedtime_story":
			week_stats["bedtimes"] += 1
			line = "June negotiated two more books and released the cat."
		"gaming":
			week_stats["gaming_blocks"] += 2
			today["gaming"] += 1
			line = "One more match. Stress down. Time: gone."
	if id in ["feed_girls", "play_girls", "bedtime_story", "cereal"]:
		today["kid_actions"] += 1
	today["log"].append(line)
	# LifeOS chimes in sometimes.
	if rng.randf() < 0.35:
		lifeos_message.emit(_lifeos_comment(id))
	state_changed.emit()
	if minutes >= DAY_END:
		end_day()
	return line

func _lifeos_comment(id: String) -> String:
	match id:
		"gaming":
			return "LifeOS: You chose leisure. Your competitors did not. Great hustle anyway!"
		"bedtime_story":
			return "LifeOS: You chose bedtime over your side project. Bold."
		"work_ticket":
			return "LifeOS: Ticket closed! Gary will not notice. Productivity: Exceptional."
	return LIFEOS_TIPS[rng.randi() % LIFEOS_TIPS.size()]

func end_day() -> Dictionary:
	if week_over:
		return {}
	var slept_min: int = clampi(DAY_END + 330 - minutes, 0, 600)  # until 6:30 AM next day
	# 7h ~ full, 5h ~ 60.
	var restore: int = int(round(slept_min / 60.0 * 14.0))
	var summary := {
		"day": day_name(),
		"bed_time": clock_text(),
		"sleep_hours": slept_min / 60.0,
		"tickets": today["tickets"],
		"texts": today["text_jess"],
		"bedtime": today["bedtime_story"] > 0,
		"kid_actions": today["kid_actions"],
		"energy_before": energy,
	}
	# Overnight drift.
	if today["text_jess"] == 0:
		closeness = clampi(closeness - 8, 0, 100)
	if today["bedtime_story"] == 0:
		girls_connected = clampi(girls_connected - 10, 0, 100)
	if today["tickets"] == 0 and day < 5:
		performance = clampi(performance - 10, 0, 100)
	girls_fed = clampi(girls_fed - 20, 0, 100)
	stress = clampi(stress + (5 if slept_min < 360 else -10), 0, 100)
	energy = clampi(energy + restore, 0, 100)
	summary["sleep_text"] = "Sleep: %dh %02dm. Productivity: %s. Liver: Concerned." % [slept_min / 60, slept_min % 60, "Exceptional" if today["tickets"] > 1 else "Pending"]
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
	var fatherhood := "Exceeds Expectations (June disputes this)" if week_stats["bedtimes"] >= 5 else "Meets Expectations (June disputes this)" if week_stats["bedtimes"] >= 3 else "Needs Improvement (Lily drew a comic without you)"
	var marriage := "Synced" if closeness >= 60 else "\"We should talk\" received x2 (Needs Sync)"
	var career := "Exceeds Expectations (no one noticed)" if performance >= 70 else "Meets Expectations" if performance >= 40 else "Gary would like a quick call"
	return "LIFEOS QUARTERLY-WEEKLY PERFORMANCE REVIEW: Week 1\n" \
		+ "Fatherhood ........ %s\n" % fatherhood \
		+ "Bedtimes attended . %d/7\n" % week_stats["bedtimes"] \
		+ "Marriage .......... %s\n" % marriage \
		+ "Career ............ %s (%d tickets)\n" % [career, week_stats["tickets"]] \
		+ "Side Hustle ....... Pre-revenue, post-sleep\n" \
		+ "Self-Care ......... %s\n" % ("Not Applicable" if stress > 50 else "Detected. Suspicious.") \
		+ "Manager comment: \"Great energy! Let's circle back on everything.\"\n\n" \
		+ "ENDING (stub): Everybody wins. Nobody wins the way they planned."

func _fmt(m: int) -> String:
	var h := (m % 1440) / 60
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m % 60, "AM" if h < 12 else "PM"]
