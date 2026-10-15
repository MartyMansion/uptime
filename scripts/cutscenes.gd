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

const IDS := ["wake", "dropoff", "arrive_work", "drive_stop", "pickup", "jess_home", "bedtime", "day_end", "review", "moment", "chaos", "dinner", "one_more"]

static func build(id: String, gs: Node, ctx: Dictionary = {}) -> Array:
	var d: int = gs.day
	match id:
		"wake":
			var s: Array = [["loc", "house"], ["dim", false], ["place", "dan", "bed"], ["face", "dan", "down"],
				["place", "lily", "table_l"], ["place", "june", "table_r"], ["place", "jess", "kitchen_b"]]
			if d == 0:
				s += [["lifeos", "Good morning, Dan! You slept 4h 51m. That's 18% more than a Navy SEAL. LifeOS drew a little sun on your to-do list. Let's crush today! (Gently.)"],
					["move", "dan", "kitchen"],
					["say", "june", "Daddy. My shoes are gone. Forever. Someone took them."],
					["say", "dan", "Nobody took your shoes, bug. Shoes don't get stolen. They just quietly resign."],
					["say", "lily", "Mommy says they're in \"the last place you'd look.\""],
					["say", "dan", "That's every place, Lily. That's kind of how looking works."],
					["say", "lily", "Mommy says you'd say that. She was right."],
					["say", "", "INCIDENT: Shoes, a Postmortem. Severity: P1. Impact: one (1) child, barefoot."],
					["choice", [["Run a root cause analysis (check under the couch)", "shoes_rca"], ["Escalate to Mommy", "shoes_mom"], ["Declare the shoes deprecated (buy new ones, $30)", "shoes_new"]]],
					["say", "jess", "They're under the couch. My shift starts at 7, lunches are in the fridge. Love you. Have a good day."]]
			else:
				var mornings := [
					[["say", "june", "I had a dream the printer was printing."], ["say", "dan", "That's not a dream, bug. That's my job. Sometimes it's also a nightmare. Eat your toast."]],
					[["say", "lily", "Is your job real? Like, can you touch it?"], ["say", "dan", "You can touch the printer. It's very friendly. It has simply seen things."]],
					[["say", "june", "Two more minutes or I'm letting the cat in your bed."], ["say", "jess", "She's been negotiating since 5:40. She's going to be a lawyer."]],
					[["say", "lily", "I drew you. Episode 2: Daddy and the Computer and the Coffee."], ["say", "dan", "Why is my head a laptop?"], ["say", "lily", "Artistic choice. Also because you're smart."]],
					[["say", "june", "Daddy says the cloud is just someone else's computer."], ["say", "jess", "He's not wrong, sweetie. But maybe let's say it nicer at school."]],
					[["say", "jess", "No work today. Theoretically."], ["say", "lily", "Theoretically is a sad word."]],
				]
				s += [["move", "dan", "kitchen"]] + mornings[(d - 1) % mornings.size()]
				if gs.week_stats.get("drinks", 0) >= 6 and d >= 3:
					s += [["say", "", "Jess sets a glass of water in front of you and squeezes your shoulder. She doesn't say anything. She doesn't have to."]]
				if d >= 5:
					s += [["say", "jess", ["No alarms. No shifts. I'm making coffee and nobody is allowed to say 'sync'.", "Sunday. You're on call, so I'm on pancakes. Fair trade."][d - 5]]]
				else:
					s += [["say", "jess", "Off to the billing salt mines. Shared calendar. Open it. Once. For me. Love you."]]
			if d < 5:
				s += [["move", "jess", "door"], ["hide", "jess"]]
			return s
		"dropoff":
			var lines := [
				["say", "lily", "Is your job real? Like, can you touch it?"],
				["say", "june", "Daddy says the cloud is just someone else's computer."],
				["say", "lily", "Ms. Hollis says the parent group chat has 112 unread. She laughed when she said it."],
				["say", "june", "I'm going to say synergy today."],
				["say", "lily", "Bye, Daddy! Don't let the printer win."],
			]
			return [["loc", "school"], ["place", "dan", "car_r"], ["place", "lily", "car_l"], ["place", "june", "car_r"],
				["move", "june", "curb_r"], ["move", "lily", "curb_l"], lines[d % lines.size()],
				["say", "dan", "Love you. Be kind. Keep both shoes on."], ["move", "lily", "school_door"], ["hide", "lily"],
				["move", "june", "school_door"], ["hide", "june"]]
		"arrive_work":
			var gary := [
				"Morning, Dan! Payroll server is \"being weird\" again. No rush, but could you peek when you get a sec?",
				"Team, let's lean into the headwinds! ...I don't know what that means either. There are donuts.",
				"Leadership says we need AI. I'm not totally sure what for either. Can we figure it out together?",
				"The CEO put in a ticket to \"make the internet faster.\" I told him you're the best we've got.",
				"Pizza party Friday instead of raises!!! Corporate's words, not mine. I got you the pineapple one.",
				"Weekend on-call is you, right? Great energy! ...Sorry. I hate that I said that. I owe you one.",
				"Hey, sorry you're on call this weekend. I owe you one. Seriously.",
			]
			return [["loc", "office"], ["place", "dan", "entry"], ["place", "gary", "gary_desk"], ["move", "dan", "desk"],
				["move", "gary", "gary_talk"], ["face", "dan", "right"], ["say", "gary", gary[d % gary.size()]],
				["say", "dan", "(Sysadmin Brain: It's DNS.)  Sure thing, Gary."], ["move", "gary", "gary_desk"]]
		"drive_stop":
			var radio := [
				"...and that's why I get up at 4 AM. Anyway, it's not for everyone. Get some sleep, folks.",
				"Sleep is a subscription you can cancel! Link in bio. (A caller says 'please don't.' Good caller.)",
				"Grindset tip: your kids will understand when you're a unicorn. (Dan switches to the oldies station. The oldies station understands.)",
			]
			return [["loc", "gas_station"], ["place", "dan", "car"], ["face", "dan", "up"],
				["say", "4 AM Club (radio)", radio[d % radio.size()]],
				["choice", [["Leave the 4 AM Club on (for science)", "radio_4am"], ["Oldies station", "radio_oldies"], ["Radio off. Just the road.", "radio_quiet"]]],
				["say", "", "The Gas-N-Sip sign hums. After-care closes at 6. The girls will be watching the door for you."]]
		"pickup":
			var s := [["loc", "school"], ["place", "dan", "car_r"], ["place", "lily", "school_door"], ["place", "june", "school_door"],
				["move", "june", "curb_r"], ["move", "lily", "curb_l"]]
			if ctx.get("bought", false):
				s += [["say", "lily", "Why does the car smell like gas station?"], ["say", "dan", "Cars just smell like that sometimes, Lil."], ["say", "lily", "Hm."]]
			else:
				s += [["say", "june", "Three incidents today. None of them mine."], ["say", "lily", "One of them was hers. But she said sorry."]]
			return s
		"jess_home":
			var jess := [
				"I was on hold with insurance for 52 minutes. I can sing you the hold music now.",
				"Hospital gave us pizza instead of a raise again. I saved you a slice of disappointment. It's pepperoni disappointment, at least.",
				"Did anyone open the shared calendar? June has picture day! Brush her hair. Please.",
				"Press 9 to hear these options in a more disappointing order. That was my whole day. Hug me.",
				"My mom says hi and also her iPad is 'broken.' She loves you. She just loves you more when it's broken.",
				"I'm home. I'm horizontal. Talk to me in ten minutes.",
				"Weekend tip: nobody is allowed to say 'quick call' in this house.",
			]
			var s := [["loc", "house"], ["place", "dan", "living"], ["place", "lily", "girls"], ["place", "june", "girls_dan"],
				["place", "jess", "door"], ["move", "jess", "living_j"], ["face", "dan", "right"], ["face", "jess", "left"], ["say", "jess", jess[d % jess.size()]]]
			if gs.drinks_week >= 8 and not gs.notices_seen.has("real_talk"):
				gs.notices_seen["real_talk"] = true
				s += [["say", "jess", "Hey. Can I say a thing without it being a Whole Thing?"], ["say", "jess", "You've been having a few most nights. I'm not counting. I just... noticed I was counting."],
					["choice", [["Be honest: \"Yeah. It's been more than I want.\"", "talk_honest"], ["\"It's just been a long week.\"", "talk_deflect"], ["Joke: \"The recycling is just very enthusiastic.\"", "talk_joke"]]]]
			elif gs.closeness < 35:
				s += [["say", "", "She sits at the far end of the couch, tired. She still smiles when you look over."]]
			elif gs.today.get("text_jess", 0) > 0:
				s += [["say", "jess", "Thanks for texting today. It really helped."]]
			s += [["move", "jess", "couch_l"]]
			return s
		"bedtime":
			var s := [["place", "dan", "girls_dan"], ["place", "lily", "lily_bed"], ["place", "june", "june_bed"],
				["say", "june", "Two more books, please. Pleeease."], ["say", "dan", "One book."], ["say", "june", "Two books and I release the cat."],
				["say", "lily", "Nobody releases the cat. The cat has been through enough."]]
			if gs.today.get("drink", 0) >= 3:
				s += [["say", "lily", "You did the dragon voice twice. ...That's okay. I liked it."]]
			else:
				s += [["say", "lily", "Daddy? Will you do the dragon voice tomorrow too?"], ["say", "dan", "Every day, bug."]]
			return s
		"day_end":
			return [["loc", "house"], ["place", "dan", "living"], ["move", "dan", "bed"], ["dim", true],
				["lifeos", str(ctx.get("sleep_text", "Sleep: pending. Today: done. Good job."))]]
		"review":
			return [["loc", "house"], ["dim", false], ["place", "dan", "couch"], ["place", "jess", "couch_l"], ["place", "lily", "couch_r"], ["place", "june", "living"],
				["lifeos", "Compiling your Week 1 Quarterly-Weekly Performance Review. Please hold. Hold music: pan flute."],
				["say", "lily", "Is it a lot?"],
				["say", "june", "I'm the dentist now. Say ahh."],
				["say", "jess", "Come here, you. Pancakes. Nobody's on call."]]
		"chaos":
			# Evening chaos events (TASKS M2). Choices are about patience, never punishment.
			var ev: int = int(ctx.get("n", d)) % 3
			var evs := [
				[["say", "", "INCIDENT: June has applied crayon to the Blu-ray player. Severity: P2. She looks proud."],
					["say", "june", "I made it pretty. It was sad and black."],
					["choice", [["Laugh, then clean it together", "chaos_laugh"], ["Deep breath. Calm, firm: crayons live on paper", "chaos_calm"], ["Declare it modern art and frame the remote", "chaos_art"]]]],
				[["say", "", "INCIDENT: The Wi-Fi is down. Two children are experiencing it as a natural disaster."],
					["say", "lily", "Daddy, the internet died. Is this your fault? You're the internet person."],
					["choice", [["Fix it with the girls as 'IT interns'", "chaos_laugh"], ["Reboot the router, calmly, like a professional", "chaos_calm"], ["Leave it off. Announce a board game night", "chaos_art"]]]],
				[["say", "", "INCIDENT: The cat is on the counter, eating the butter, maintaining eye contact."],
					["say", "june", "He's not stealing. He's sharing with himself."],
					["choice", [["Laugh. Butter is a lost cause anyway", "chaos_laugh"], ["Calmly relocate the cat. Butter: retired", "chaos_calm"], ["Make the girls narrate it like a nature show", "chaos_art"]]]],
			]
			var steps: Array = evs[ev].duplicate(true)
			if gs.stress >= 75 or gs.is_on_fumes():
				# Stress effect: the warmest option is out of reach today. Not cruel, just tired.
				var ch: Array = steps[-1][1]
				ch[0] = ["(You can't find the laugh right now. You'll get it back.) Handle it calmly", "chaos_calm"]
				steps.insert(steps.size() - 1, ["say", "", "Your patience is at 4%. Charging cable not found."])
			return [["loc", "house"], ["place", "dan", "living"], ["place", "june", "living_j"], ["place", "lily", "girls"]] + steps
		"dinner":
			var topics := ["What was the best part of everyone's day?", "June wants to know if robots have birthdays.", "Lily asks why grown-ups are always tired."]
			return [["say", "jess", topics[d % topics.size()]],
				["choice", [["Phone down. Listen to the girls.", "dinner_listen"], ["Ask Jess about her day first.", "dinner_jess"], ["Explain DNS. They asked. (They didn't.)", "dinner_work"]]]]
		"one_more":
			return [["lifeos", "It's late. Your squad is queuing again. LifeOS has no opinion. (LifeOS has an opinion.)"],
				["choice", [["Log off. Go to bed like an adult.", "match_bed"], ["One more match.", "match_more"]]]]
		"moment":
			# Heart events (Stardew-style), played once when a relationship crosses a threshold.
			var lines := {
				"jess70": [["say", "jess", "Found our wedding playlist. It's 60% ska. Who let us make decisions?"], ["say", "dan", "We were young and the trombone was persuasive."], ["say", "jess", "Dance with me. Badly. Before the kids notice."]],
				"jess85": [["say", "jess", "Hey. You've been really here this week. Like, here here."], ["say", "dan", "LifeOS says I'm 'underperforming in Side Hustle.'"], ["say", "jess", "LifeOS can file a ticket."]],
				"girls75": [["say", "june", "You are Best Daddy. It's a tie with the cat."], ["say", "dan", "I'll take it. The cat's very accomplished."]],
				"girls90": [["say", "lily", "I made you a certificate. 'Dad. Level 99.'"], ["say", "dan", "Is it laminated?"], ["say", "lily", "With tape. That's how you know it's official."]],
			}
			var key: String = ctx.get("id", "girls75")
			return [["loc", "house"], ["place", "dan", "living"]] + lines.get(key, lines["girls75"])
	return []
