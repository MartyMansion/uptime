class_name Cutscenes
## Scripted cutscene data. Steps:
##  ["loc", name]            switch location (no default NPCs)
##  ["place", who, spot]     put an actor on a named spot (or Vector2)
##  ["face", who, dir]
##  ["move", who, spot]      walk there; waits until arrival
##  ["hide", who]
##  ["say", who, text]       dialogue box with portrait; waits for Enter ("" = narration)
##  ["lifeos", text]         LifeOS speaks in the dialogue box
##  ["dim", bool]            lights down / up
##  ["wait", seconds]
## Lines adapted from the design doc (§4.12, §5.4).

const IDS := ["wake", "dropoff", "arrive_work", "drive_stop", "pickup", "jess_home", "bedtime", "day_end", "review"]

static func build(id: String, gs: Node, ctx: Dictionary = {}) -> Array:
	var d: int = gs.day
	match id:
		"wake":
			var s: Array = [["loc", "house"], ["dim", false], ["place", "dan", "bed"], ["face", "dan", "down"],
				["place", "lily", "table_l"], ["place", "june", "table_r"], ["place", "jess", "kitchen_b"]]
			if d == 0:
				s += [["lifeos", "Good morning, Dan! You slept 4h 51m. That's 18% more than a Navy SEAL. Let's crush today!"],
					["move", "dan", "kitchen"],
					["say", "june", "Daddy. My shoes are gone. Forever. Someone took them."],
					["say", "dan", "Nobody took your shoes, bug. Nobody wants your shoes. They have glitter and trauma."],
					["say", "lily", "Mommy says they're in \"the last place you'd look.\""],
					["say", "dan", "That's every place, Lily. That's how looking works."],
					["say", "lily", "Mommy says you'd say that."],
					["say", "jess", "They're under the couch. Shift starts at 7. Lunches are in the fridge. I love you, go."]]
			else:
				var mornings := [
					[["say", "june", "I had a dream the printer was printing."], ["say", "dan", "That's not a dream, bug. That's my job."]],
					[["say", "lily", "Is your job real? Like, can you touch it?"], ["say", "dan", "You can touch the printer. Please don't."]],
					[["say", "june", "Two more minutes and I release the cat."], ["say", "jess", "She's been negotiating since 5:40."]],
					[["say", "lily", "I drew you. Episode 2: Daddy and the Computer and the Coffee."], ["say", "dan", "Why is my head a laptop?"], ["say", "lily", "Artistic choice."]],
					[["say", "june", "Daddy says the cloud is just someone else's computer."], ["say", "jess", "Please don't say that at school again."]],
					[["say", "jess", "No work today. Theoretically."], ["say", "lily", "Theoretically is a sad word."]],
				]
				s += [["move", "dan", "kitchen"]] + mornings[(d - 1) % mornings.size()]
				if gs.week_stats.get("drinks", 0) >= 6 and d >= 3:
					s += [["say", "", "Jess slides you a glass of water without a word. It's either kindness or a memo."]]
				s += [["say", "jess", "Off to the billing salt mines. Shared calendar. Open it. Once."]]
			s += [["move", "jess", "door"], ["hide", "jess"]]
			return s
		"dropoff":
			var lines := [
				["say", "lily", "Is your job real? Like, can you touch it?"],
				["say", "june", "Daddy says the cloud is just someone else's computer."],
				["say", "lily", "Ms. Hollis says the parent group chat has 112 unread. She said it like a threat."],
				["say", "june", "I'm going to say synergy today."],
				["say", "lily", "Bye. Don't let the printer win."],
			]
			return [["loc", "school"], ["place", "dan", "car_r"], ["place", "lily", "car_l"], ["place", "june", "car_r"],
				["move", "june", "curb_r"], ["move", "lily", "curb_l"], lines[d % lines.size()],
				["say", "dan", "Love you. Be kind. Find your shoes."], ["move", "lily", "school_door"], ["hide", "lily"],
				["move", "june", "school_door"], ["hide", "june"]]
		"arrive_work":
			var gary := [
				"Quick q! Payroll server is \"being weird.\" Can you hop on a quick call?",
				"Team, let's lean into the headwinds!",
				"Leadership says we need AI. Not sure what for. Can you set it up by Friday?",
				"Somebody put a ticket in: \"make the internet faster.\" It's from the CEO. Thoughts?",
				"Pizza party Friday for the team!!! You've earned one-eighth of it.",
				"Weekend on-call is you, right? Great energy!",
				"Weekend on-call is you, right? Great energy!",
			]
			return [["loc", "office"], ["place", "dan", "entry"], ["place", "gary", "gary_desk"], ["move", "dan", "desk"],
				["move", "gary", "gary_talk"], ["face", "dan", "right"], ["say", "gary", gary[d % gary.size()]],
				["say", "dan", "(Sysadmin Brain: It's DNS.)  Sure thing, Gary."], ["move", "gary", "gary_desk"]]
		"drive_stop":
			var radio := [
				"If you're not building at 4 AM, someone in a cheaper time zone is.",
				"Sleep is a subscription you can cancel. Link in bio.",
				"Grindset tip: your kids will understand when you're a unicorn.",
			]
			return [["loc", "gas_station"], ["place", "dan", "car"], ["face", "dan", "up"],
				["say", "4 AM Club (radio)", radio[d % radio.size()]],
				["say", "", "The Gas-N-Sip sign hums. After-care closes at 6. The cooler is right there. So is the car."]]
		"pickup":
			var s := [["loc", "school"], ["place", "dan", "car_r"], ["place", "lily", "school_door"], ["place", "june", "school_door"],
				["move", "june", "curb_r"], ["move", "lily", "curb_l"]]
			if ctx.get("bought", false):
				s += [["say", "lily", "Why does the car smell like gas station?"], ["say", "dan", "Because it's a car, Lily."], ["say", "lily", "Hm."]]
			else:
				s += [["say", "june", "Three incidents today. None of them mine."], ["say", "lily", "One of them was hers."]]
			return s
		"jess_home":
			var jess := [
				"I was on hold with insurance for 52 minutes. The hold music has a bridge now.",
				"Hospital gave us pizza instead of a raise again. I saved you a slice of disappointment.",
				"Did anyone open the shared calendar. Anyone. Ever.",
				"Press 9 to hear these options in a more disappointing order. That was my whole day.",
				"My mom forwarded an article called AI IS STEALING JOBS and then asked you to fix her iPad.",
				"I'm home. I'm horizontal. Talk to me in ten minutes.",
				"Weekend tip: nobody is allowed to say 'quick call' in this house.",
			]
			var s := [["loc", "house"], ["place", "dan", "living"], ["place", "lily", "girls"], ["place", "june", "girls_dan"],
				["place", "jess", "door"], ["move", "jess", "living_j"], ["face", "dan", "right"], ["face", "jess", "left"], ["say", "jess", jess[d % jess.size()]]]
			if gs.closeness < 35:
				s += [["say", "", "She sits on the far end of the couch. Not mad. Just far."]]
			elif gs.today.get("text_jess", 0) > 0:
				s += [["say", "jess", "Thanks for texting today. It helped. Don't tell LifeOS."]]
			s += [["move", "jess", "couch_l"]]
			return s
		"bedtime":
			var s := [["place", "dan", "girls_dan"], ["place", "lily", "lily_bed"], ["place", "june", "june_bed"],
				["say", "june", "Two more books and I release the cat."], ["say", "dan", "One book."], ["say", "june", "Two books and I release the cat AND Lily."],
				["say", "lily", "You can't release me."]]
			if gs.today.get("drink", 0) >= 3:
				s += [["say", "lily", "You did the dragon voice twice."]]
			else:
				s += [["say", "lily", "Daddy? Will you do the dragon voice tomorrow too?"], ["say", "dan", "Every day, bug."]]
			return s
		"day_end":
			return [["loc", "house"], ["place", "dan", "living"], ["move", "dan", "bed"], ["dim", true],
				["lifeos", str(ctx.get("sleep_text", "Sleep: pending. Productivity: Exceptional."))]]
		"review":
			return [["loc", "house"], ["dim", false], ["place", "dan", "couch"], ["place", "jess", "couch_l"], ["place", "lily", "couch_r"], ["place", "june", "living"],
				["lifeos", "Compiling your Week 1 Quarterly-Weekly Performance Review. Please hold. Hold music: pan flute."],
				["say", "lily", "Is it a lot?"],
				["say", "june", "I'm the dentist now. Open your mouth."],
				["say", "jess", "Come here, founder. Pancakes. Nobody's on call."]]
	return []
