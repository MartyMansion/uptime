class_name TicketSim
extends RefCounted
## Fake TriCounty network + one troubleshooting ticket with a randomized root cause.
## Pure logic (no UI) so tests and the playtest bot can drive it headless.
##   var t := TicketSim.new(rng); t.run("ping tc-web01") -> output text; t.solved

const HOSTS := {
	"tc-dc01": {"ip": "10.10.0.10", "role": "domain controller + DNS"},
	"tc-files01": {"ip": "10.10.0.20", "role": "file server (smbd)"},
	"tc-web01": {"ip": "10.10.0.30", "role": "intranet web (nginx)"},
	"tc-print01": {"ip": "10.10.0.40", "role": "print server (cups)"},
	"tc-app01": {"ip": "10.10.0.50", "role": "payroll app (payrolld)"},
	"tc-sw01": {"ip": "10.10.0.2", "role": "core switch"},
}
const USERS := ["karen", "phil", "marisol", "denise", "raj", "tom"]
const TYPES := ["port", "service", "dns", "disk", "cert", "printer", "vlan", "lockout"]

var rng: RandomNumberGenerator
var kind := ""
var title := ""
var from := ""
var body := ""
var host := ""          # host where the fix lives
var svc := ""
var port := 0
var user := ""
var sw_port := 0
var good_vlan := 20
var bad_vlan := 99
var typo := ""
var cur_host := "dan-laptop"
var solved := false
var diagnosed := false
var commands := 0
var wrong := 0
var hints_used := 0
var steps: Array[String] = []     # optimal command path
var reply := ""                   # user's reply after the fix
var log_lines: Array[String] = []

func _init(r: RandomNumberGenerator = null, force_kind := "") -> void:
	rng = r if r != null else RandomNumberGenerator.new()
	if r == null: rng.randomize()
	kind = force_kind if force_kind != "" else TYPES[rng.randi() % TYPES.size()]
	user = USERS[rng.randi() % USERS.size()]
	_setup()

func _setup() -> void:
	match kind:
		"port":
			host = ["tc-web01", "tc-app01"][rng.randi() % 2]
			port = 443 if host == "tc-web01" else [8443, 9090][rng.randi() % 2]
			svc = "nginx" if host == "tc-web01" else "payrolld"
			title = "%s is \"down\" (it's up, just unreachable)" % host
			from = user.capitalize()
			body = "Hi Dan! The %s page just spins forever. It worked this morning. I didn't touch anything. (I touched nothing. Promise.)" % ("intranet" if host == "tc-web01" else "payroll")
			steps = ["ping %s" % host, "ssh %s" % host, "firewall list", "firewall allow %d" % port]
			reply = "%s: IT WORKS. You're a wizard. I'm telling Gary. (Gary already knows. Gary says 'nice'.)" % from
		"service":
			host = ["tc-files01", "tc-print01", "tc-app01"][rng.randi() % 3]
			svc = {"tc-files01": "smbd", "tc-print01": "cups", "tc-app01": "payrolld"}[host]
			title = "Can't reach %s" % {"smbd": "the S: drive", "cups": "any printer", "payrolld": "payroll"}[svc]
			from = user.capitalize()
			body = "The %s isn't there anymore. Did it get deleted? Is it the cloud? Please say it's not the cloud." % {"smbd": "S: drive", "cups": "printer list", "payrolld": "payroll app"}[svc]
			steps = ["ssh %s" % host, "systemctl status %s" % svc, "systemctl restart %s" % svc]
			reply = "%s: It's back!! It wasn't the cloud. I'm so relieved I bought donuts." % from
		"dns":
			host = "tc-dc01"
			var names := ["intranet", "payroll", "timesheets", "wiki"]
			var n: String = names[rng.randi() % names.size()]
			typo = n.substr(0, 2) + n[3] + n[2] + n.substr(4)   # swap two letters
			svc = n
			title = "%s.tricounty.local \"doesn't exist\"" % n
			from = user.capitalize()
			body = "The %s link says 'server not found'. Did we get hacked? Do I need to change my password again? (Please no.)" % n
			steps = ["nslookup %s" % n, "ssh tc-dc01", "dns records", "dns fix %s" % n]
			reply = "%s: Fixed! What was it? ...A typo? Someone typed '%s'? Honestly, relatable." % [from, typo]
		"disk":
			host = ["tc-files01", "tc-app01", "tc-web01"][rng.randi() % 3]
			title = "%s is saying 'No space left on device'" % host
			from = "Monitoring (automated)"
			body = "ALERT: %s / at 100%%. This is an automated message. The automation is also worried." % host
			steps = ["ssh %s" % host, "df -h", "du -sh /var/log", "logrotate --force"]
			reply = "Monitoring: %s / at 41%%. ALERT CLEARED. The automation sends its regards." % host
		"cert":
			host = "tc-web01"
			title = "Intranet says 'Your connection is not private'"
			from = user.capitalize()
			body = "There's a big red warning on the intranet. Should I be scared? I clicked 'back to safety' four times. Am I safe?"
			steps = ["ssh tc-web01", "certcheck", "certbot renew"]
			reply = "%s: The scary page is gone! Thank you for keeping us safe from... whatever that was." % from
		"printer":
			host = "tc-print01"
			svc = ["ACCT-LASER", "FRONTDESK-INK", "BIGBOY-3000"][rng.randi() % 3]
			title = "%s won't print (again)" % svc
			from = user.capitalize()
			body = "I've hit print 14 times. Nothing. Should I hit it more? I'm going to hit it more."
			steps = ["ssh tc-print01", "lpstat", "cancel -a %s" % svc]
			reply = "%s: It printed!! All 14 copies. ...I'll recycle 13. Thank you!!" % from
		"vlan":
			host = "tc-sw01"
			sw_port = 3 + rng.randi() % 20
			title = "New PC at desk %d has no internet" % sw_port
			from = user.capitalize()
			body = "My new computer says 'No Internet' but the cable is plugged in. Firmly. I checked. I checked firmly."
			steps = ["ipconfig desk-%d" % sw_port, "ssh tc-sw01", "show port %d" % sw_port, "set port %d vlan %d" % [sw_port, good_vlan]]
			reply = "%s: I'm online! I can see the internet! It's mostly emails but still!" % from
		"lockout":
			host = "tc-dc01"
			title = "%s can't log in" % user.capitalize()
			from = user.capitalize()
			body = "It says my account is locked. I typed my password very carefully. Seven times. Very carefully."
			steps = ["ssh tc-dc01", "aduser %s" % user, "unlock %s" % user]
			reply = "%s: I'm in! And I wrote my new password on a... no. I memorized it. Like an adult." % from
	log_lines = ["LifeOS TermOS 2.1 — 'Have you tried being kind to your sysadmin?'", "TICKET: %s" % title, "FROM: %s" % from, body, "Type 'help' for commands, or click a suggestion below."]

func optimal() -> int:
	return steps.size()

func next_step() -> String:
	# The first optimal step not yet satisfied, given where we are.
	for st in steps:
		if st.begins_with("ssh "):
			if cur_host != st.substr(4): return st
		elif not (st in _done):
			return st
	return steps[-1]

var _done: Array[String] = []

func hint() -> String:
	hints_used += 1
	var n := next_step()
	var why := {
		"ping": "Is the box even alive?", "ssh": "Log in to the box where the problem lives.", "nslookup": "Does the name resolve?",
		"firewall": "Something is in the way. Check the firewall.", "systemctl": "Is the service running?", "df": "How full are the disks?",
		"du": "What's eating the space?", "logrotate": "Rotate the logs. Gently.", "certcheck": "When does the certificate expire?",
		"certbot": "Renew it.", "lpstat": "What's in the print queue?", "cancel": "Clear the stuck jobs.", "ipconfig": "What IP did the PC get?",
		"show": "Which VLAN is that switch port on?", "set": "Put the port on the office VLAN (20).", "aduser": "Look up the account.",
		"unlock": "Unlock it.", "dns": "Look at the DNS records.",
	}
	var verb := n.split(" ")[0]
	return "HINT: %s Try: %s" % [why.get(verb, "Keep going."), n]

var clicked_cmds := 0   # commands run by clicking a suggestion (typed/Tab-completed ones earn the shell bonus)

## Clickable suggestions, live: the actual next correct command for THIS ticket (right host/args),
## plus 1-2 plausible alternatives a senior admin might also try, and 'help'.
## Without Rx focus the correct one moves around, so it's a small read-the-room choice, not a free answer.
func suggestions(focus := false) -> Array[String]:
	var n := next_step()
	var alts: Array[String] = []
	var h := host if host != "" else "tc-dc01"
	var pool: Array[String] = []
	if not cur_host.begins_with("tc-"):
		pool = ["ping %s" % h, "traceroute %s" % h, "nslookup %s" % h, "whoami"]
	else:
		pool = ["tail log", "df -h", "ss -tlnp", "systemctl status %s" % (svc if svc != "" else "sshd"), "firewall list", "hostname"]
	for p in pool:
		if p != n and not (p in _done) and alts.size() < 2:
			alts.append(p)
	var out: Array[String] = []
	if focus:
		out.append(n); out.append_array(alts)
	else:
		out.append_array(alts)
		out.insert((commands * 7 + log_lines.size()) % (alts.size() + 1), n)
	out.append("help")
	return out

## Typed (or Tab-completed) most of it yourself? Small bonus: XP + keeps a "great" grade.
func typed_bonus() -> bool:
	return commands >= 2 and clicked_cmds * 2 <= commands

## Runs one command, returns its output. Counts toward efficiency.
func run(cmd: String) -> String:
	cmd = cmd.strip_edges()
	if cmd == "":
		return ""
	commands += 1
	var typed := cmd
	var pre := ""
	# Real-world muscle memory (pass 2): sudo/dig/host/journalctl map onto TermOS verbs.
	if cmd.begins_with("sudo "):
		cmd = cmd.substr(5).strip_edges()
		pre = "[sudo] password for dan: ******** (first try. A good sign.)\n"
	var a := cmd.split(" ", false)
	if a.is_empty():
		log_lines.append("%s$ %s" % [cur_host, typed]); log_lines.append("usage: sudo <command>"); return "usage: sudo <command>"
	var v: String = a[0].to_lower()
	if v in ["dig", "host"] and a.size() > 1:
		var n := a[-1]
		if n.begins_with("+"): n = a[1]
		cmd = "nslookup " + n
	elif v == "journalctl":
		cmd = "tail log"
	if cmd != typed.trim_prefix("sudo ").strip_edges():
		a = cmd.split(" ", false); v = a[0]
	var arg: String = a[1] if a.size() > 1 else ""
	if v == "clear":
		log_lines.clear()
		return ""
	var out: String = _real(v, a)
	if out == "":
		out = _exec(v, arg, a, cmd)
	out = pre + out
	log_lines.append("%s$ %s" % [cur_host, typed])
	log_lines.append(out)
	return out

## Common real commands with plausible, ticket-aware output ("" = not one of these).
func _real(v: String, a: Array) -> String:
	var on_fix := cur_host == host
	match v:
		"uptime":
			if on_fix and kind == "service": return " %s up 213 days,  load average: 0.02, 0.01, 0.00  (suspiciously calm: %s isn't running)" % ["14:02:11", svc]
			if on_fix and kind == "disk": return " 14:02:11 up 88 days,  load average: 4.81, 4.66, 4.12  (iowait. the disk is gasping.)"
			return " 14:02:11 up 213 days,  1 user,  load average: 0.42, 0.37, 0.31"
		"top", "htop":
			var rows := "  PID USER     %CPU %MEM COMMAND\n  412 root      0.3  1.2 sshd\n  733 root      0.1  0.4 cron"
			if on_fix and kind == "service": rows += "\n  (no %s process. It's not slow, it's gone.)" % svc
			elif on_fix and kind == "disk": rows += "\n  901 root     88.0  2.1 rsync  (stuck writing to a full disk)"
			elif on_fix and kind == "printer": rows += "\n  622 lp       97.0  4.0 cups-driver  (panicking politely)"
			else: rows += "\n  555 www-data  1.2  6.3 %s" % (svc if svc != "" else "nginx")
			return rows + "\n(q to quit. You don't need to: it's a screenshot of top. Budget.)"
		"curl":
			var tgt := ""
			for x in a.slice(1): if not str(x).begins_with("-"): tgt = str(x)
			if tgt == "": return "curl: try 'curl -I https://tc-web01'"
			var hn := tgt.replace("https://", "").replace("http://", "").split("/")[0].split(":")[0]
			if kind == "dns" and hn.trim_suffix(".tricounty.local") == svc: return "curl: (6) Could not resolve host: %s  (DNS. It's always DNS.)" % hn
			if kind == "cert" and hn == host: return "curl: (60) SSL certificate problem: certificate has expired"
			if kind == "port" and hn == host: return "curl: (7) Failed to connect to %s port %d: Connection refused" % [hn, port]
			if kind == "service" and hn == host: return "curl: (52) Empty reply from server  (%s is down)" % svc
			if HOSTS.has(hn) or hn.ends_with(".tricounty.local"): return "HTTP/1.1 200 OK\nServer: nginx\nX-Powered-By: hope"
			return "curl: (6) Could not resolve host: %s" % hn
		"cat":
			if a.size() < 2: return "cat: reads files. Try: cat /etc/hosts, cat /var/log/syslog"
			var f := str(a[1])
			if f == "/etc/hosts":
				var t := "127.0.0.1 localhost"
				for h in HOSTS: t += "\n%s %s" % [HOSTS[h]["ip"], h]
				return t
			if f.begins_with("/var/log"): return _exec("tail", "log", ["tail", "log"], "tail log")
			if f == "/etc/motd": return "Welcome to TriCounty. Please don't reboot anything on Fridays."
			return "cat: %s: No such file or directory" % f
		"ls":
			var files := {"tc-web01": "/etc/nginx  /var/www  /var/log/nginx", "tc-files01": "/srv/share  /var/log/samba  backup.tar.gz.part",
				"tc-dc01": "/etc/bind  /var/log/auth.log  zones.bak", "tc-print01": "/etc/cups  /var/spool/cups (very full)",
				"tc-app01": "/opt/payrolld  /var/log/payrolld  README-DO-NOT-DELETE", "tc-sw01": "running-config  startup-config"}
			return files.get(cur_host, "Desktop  Downloads  tickets.txt  june_drawing_server_hero.png")
		"history":
			var hist: Array[String] = []
			var i := 1
			for l in log_lines:
				if "$ " in l and not l.begins_with("HINT"):
					hist.append("%4d  %s" % [i, l.split("$ ", true, 1)[1]]); i += 1
			return "\n".join(hist.slice(maxi(0, hist.size() - 8))) if not hist.is_empty() else "(empty. A fresh start.)"
		"man":
			if a.size() < 2: return "What manual page do you want? (Try: man nslookup)"
			var w: Dictionary = {"ping": "send ICMP echo", "ssh": "log in to a remote host", "nslookup": "query DNS", "dig": "query DNS (fancier)",
				"firewall": "list/allow ports", "systemctl": "status|restart services", "df": "disk free", "du": "disk usage", "logrotate": "rotate logs",
				"certcheck": "check cert expiry", "certbot": "renew certs", "lpstat": "print queue", "cancel": "cancel print jobs",
				"show": "switch port info", "set": "set switch port VLAN", "aduser": "look up an account", "unlock": "unlock an account", "curl": "talk HTTP"}
			return "%s(1) — %s. Section 'BUGS': yes." % [a[1], w.get(str(a[1]), "no manual entry. Ask Raj.")]
		"free":
			return "        total   used   free\nMem:     16G    %s    %s" % (["15.8G", "0.2G"] if on_fix and kind == "service" else ["6.1G", "9.9G"])
		"ps":
			return _real("top", a).split("\n(q")[0]
		"who":
			return "dan      pts/0   (you)\nphil     pts/1   (idle 3 weeks — the 'temp change' guy)"
	return ""

func _on(h: String) -> bool:
	return cur_host == h

func _need(h: String) -> String:
	return "bash: not here. You're on %s. (Try: ssh %s)" % [cur_host, h]

func _mark(c: String) -> void:
	if not (c in _done): _done.append(c)
	diagnosed = true

func _exec(v: String, arg: String, a: PackedStringArray, cmd: String) -> String:
	match v:
		"help", "?":
			return "Commands: ping, ssh, exit, nslookup, traceroute, ss -tlnp, firewall list|allow <port>, systemctl status|restart <svc>, tail log, df -h, du -sh <dir>, logrotate --force, certcheck, certbot renew, lpstat, cancel -a <printer>, ipconfig <desk-N>, show port <n>, set port <n> vlan <v>, aduser <name>, unlock <name>, dns records|fix <name>, whoami, hostname"
		"whoami":
			return "dan (sysadmin, dad, 99.2% uptime)"
		"hostname":
			return cur_host
		"exit", "logout":
			cur_host = "dan-laptop"
			return "Connection closed. You're back on your laptop. It has 31 stickers."
		"ping":
			if not HOSTS.has(arg) and not arg.begins_with("desk-"):
				wrong += 1
				return "ping: %s: Name or service not known" % arg
			if arg.begins_with("desk-"):
				return "Request timed out. (x4) The PC is either off or very shy."
			if cmd == steps[0]: _mark(cmd)
			return "64 bytes from %s: icmp_seq=1 ttl=64 time=0.4 ms (x4). It's alive. It's just not answering on the port people want." % HOSTS[arg]["ip"] if kind == "port" and arg == host else "64 bytes from %s: time=0.3 ms (x4). Alive and well." % HOSTS[arg]["ip"]
		"traceroute":
			if not HOSTS.has(arg): wrong += 1; return "traceroute: unknown host %s" % arg
			return "1  tc-sw01 (10.10.0.2)  0.3 ms\n2  %s (%s)  0.5 ms\nTwo hops. Short trip. The network is fine; it's something on the box." % [arg, HOSTS[arg]["ip"]]
		"ssh":
			if not HOSTS.has(arg): wrong += 1; return "ssh: Could not resolve hostname %s" % arg
			cur_host = arg
			return "Welcome to %s (%s). Last login: yesterday, by you, at 11:48 PM. Interesting." % [arg, HOSTS[arg]["role"]]
		"nslookup":
			if kind == "dns" and arg.trim_suffix(".tricounty.local") == svc:
				_mark(cmd)
				return "** server can't find %s.tricounty.local: NXDOMAIN\n(The name doesn't resolve. Check the records on tc-dc01.)" % svc
			return "Name: %s.tricounty.local  Address: 10.10.0.30" % arg if arg != "" else "nslookup: what are we looking up?"
		"ss", "netstat":
			if kind == "port" and _on(host):
				return "LISTEN 0.0.0.0:%d  users:((\"%s\"))\nThe service IS listening. So why can't anyone reach it? (Hmm. Firewall?)" % [port, svc]
			if kind == "service" and _on(host):
				return "LISTEN 0.0.0.0:22 users:((\"sshd\"))\nOnly sshd. Something that should be listening… isn't."
			return "LISTEN 0.0.0.0:22 users:((\"sshd\")) — nothing unusual."
		"firewall":
			if a.size() >= 2 and a[1] == "list":
				if kind == "port" and _on(host):
					_mark("firewall list")
					return "ALLOW 22/tcp\nDENY  %d/tcp   # added by 'temp-change-phil' 3 weeks ago\n(Phil. It's always a temp change.)" % port
				if not _on(host) and kind == "port": return _need(host)
				return "ALLOW 22/tcp, 80/tcp, 443/tcp — all good."
			if a.size() >= 3 and a[1] == "allow":
				if kind == "port" and _on(host) and int(a[2]) == port:
					_mark(cmd); solved = true
					return "Rule updated: ALLOW %d/tcp. Somewhere, a page stops spinning." % port
				wrong += 1
				return "Rule added. Nothing changed. (Wrong port or wrong box?)"
			return "usage: firewall list | firewall allow <port>"
		"systemctl":
			if a.size() < 3: return "usage: systemctl status|restart <service>"
			var s: String = a[2]
			if kind == "service" and not _on(host): return _need(host)
			if a[1] == "status":
				if kind == "service" and s == svc:
					_mark(cmd)
					return "● %s.service — inactive (dead) since 2:14 AM\n   Main PID: exited, status=1/FAILURE (out of memory at 2 AM; it happens to the best of us)" % svc
				return "● %s.service — active (running). Happy little daemon." % s
			if a[1] == "restart":
				if kind == "service" and s == svc:
					_mark(cmd); solved = true
					return "Restarting %s… ● active (running). It's back. It doesn't remember what happened. Lucky." % svc
				wrong += 1
				return "Restarted %s. It was fine before. It's fine now. Nothing changed." % s
			return "systemctl: unknown verb"
		"tail":
			return {"disk": "kernel: No space left on device (x 9,812)", "service": "%s: out of memory, giving up at 02:14" % svc,
				"cert": "nginx: SSL certificate has expired", "port": "nginx: 0 requests in 20 min (quiet. too quiet.)",
				"lockout": "auth: 7 failed logins for %s" % user, "printer": "cups: job 1 stuck: paper jam? (no) driver panic (yes)"}.get(kind, "Nothing interesting. Just a heartbeat every 60s. Relatable.")
		"df":
			if kind == "disk" and not _on(host): return _need(host)
			if kind == "disk":
				_mark("df -h")
				return "Filesystem  Size  Used  Avail Use%%  Mounted\n/dev/sda1    50G   50G     0  100%%  /\n(Full. Completely. Like your calendar.)"
			return "/dev/sda1  50G  21G  29G  42%  /  — plenty of room."
		"du":
			if kind == "disk" and _on(host):
				_mark("du -sh /var/log")
				return "38G  /var/log\n(Someone left debug logging on in March. The logs have been writing their memoirs.)"
			return "1.2G  /var/log — normal."
		"logrotate":
			if kind == "disk" and _on(host):
				_mark(cmd); solved = true
				return "Rotated and compressed 38G of logs to 2G. Disk at 41%. The server exhales."
			wrong += 1
			return "Logs rotated. Disk was fine. Logs are now very tidy, though."
		"certcheck", "openssl":
			if kind == "cert" and not _on(host): return _need(host)
			if kind == "cert":
				_mark("certcheck")
				return "notAfter = yesterday 11:59 PM\nExpired. Someone (you) set the auto-renew reminder for 'later'."
			return "Certificate valid for 74 more days."
		"certbot":
			if kind == "cert" and _on(host):
				_mark(cmd); solved = true
				return "Certificate renewed (90 days). nginx reloaded. The big red warning is gone. Auto-renew: actually on now."
			wrong += 1
			return "No certificates need renewal. Certbot is pleased with you."
		"lpstat":
			if kind == "printer" and not _on(host): return _need(host)
			if kind == "printer":
				_mark("lpstat")
				return "%s-1   %s   STUCK (driver crashed)\n%s-2..15  queued behind it, patiently, like the DMV" % [svc, user, svc]
			return "All queues empty. The printers are at peace."
		"cancel":
			if kind == "printer" and _on(host) and cmd.to_upper().contains(svc):
				_mark(cmd); solved = true
				return "Cancelled 15 jobs on %s. Queue clear. The printer resumes printing, as is its nature." % svc
			wrong += 1
			return "No jobs cancelled. (Which printer? Try lpstat on tc-print01.)"
		"ipconfig", "ip":
			if kind == "vlan" and arg == "desk-%d" % sw_port:
				_mark(cmd)
				return "desk-%d: 169.254.12.7 (self-assigned)\nNo DHCP answer. The PC is plugged into a network that isn't ours. VLAN?" % sw_port
			return "10.10.20.%d — normal office address." % (30 + commands)
		"show":
			if kind == "vlan" and not _on("tc-sw01"): return _need("tc-sw01")
			if kind == "vlan" and a.size() >= 3 and int(a[2]) == sw_port:
				_mark(cmd)
				return "Gi0/%d  connected  VLAN %d (GUEST-OLD)\nOffice PCs live on VLAN %d. This port is on the old guest VLAN." % [sw_port, bad_vlan, good_vlan]
			return "Gi0/%s  connected  VLAN 20 (OFFICE)" % (a[2] if a.size() >= 3 else "?")
		"set":
			if kind == "vlan" and _on("tc-sw01") and a.size() >= 5 and int(a[2]) == sw_port and int(a[4]) == good_vlan:
				_mark(cmd); solved = true
				return "Gi0/%d → VLAN %d. Link up. DHCP: 10.10.20.%d. A desk somewhere cheers." % [sw_port, good_vlan, 100 + sw_port]
			wrong += 1
			return "Port updated. Nothing improved. (Right port? Office VLAN is %d.)" % good_vlan
		"aduser":
			if kind == "lockout" and not _on("tc-dc01"): return _need("tc-dc01")
			if kind == "lockout" and arg == user:
				_mark(cmd)
				return "%s: LOCKED (7 bad passwords since 8:02 AM). Password last changed: today. Ah." % user
			return "%s: active, not locked." % arg
		"unlock":
			if kind == "lockout" and _on("tc-dc01") and arg == user:
				_mark(cmd); solved = true
				return "%s unlocked. You also send a gentle note about password managers. With a smiley. Kind." % user
			wrong += 1
			return "Nothing to unlock for '%s'." % arg
		"dns":
			if kind == "dns" and not _on("tc-dc01"): return _need("tc-dc01")
			if a.size() >= 2 and a[1] == "records":
				if kind == "dns":
					_mark("dns records")
					return "A  %s.tricounty.local  10.10.0.30   ← hmm\nThat says '%s'. It should say '%s'." % [typo, typo, svc]
				return "All records look correct."
			if a.size() >= 3 and a[1] == "fix" and kind == "dns" and a[2] == svc:
				_mark(cmd); solved = true
				return "Record renamed %s → %s. TTL 300. Five minutes of patience and it's everywhere." % [typo, svc]
			wrong += 1
			return "usage: dns records | dns fix <name>"
	wrong += 1
	return "command not found: %s. (Type 'help', or click a suggestion.)" % v

## Grade: great / good / slow. Fewer commands and hints = better.
func grade() -> String:
	var extra := commands - optimal()
	# Clicking only the live suggestions caps at "good": fair, approachable, not free.
	if hints_used == 0 and extra <= 1 and clicked_cmds * 2 <= commands: return "great"
	if extra <= 5 and hints_used <= 2: return "good"
	return "slow"

## For the bot and autopilot: the full optimal path from the start.
func solution() -> Array[String]:
	return steps.duplicate()

# ------------------------------------------------------------------ incidents
## Multi-stage incidents (incident response / disaster recovery). Each stage is a
## TicketSim with a forced root cause and incident-flavoured text.
const INCIDENTS := {
	"site_outage": {"name": "SITE OUTAGE: tricounty.local is down", "stages": ["port", "service"],
		"runbook": "RUNBOOK IR-01: 1) confirm reachability  2) check the edge (firewall)  3) check the service  4) postmortem",
		"gary": ["Gary: Hey, the CEO's asking. No pressure. (There's some pressure.)", "Gary: Phones are lighting up. You've got this. I'm bringing you a coffee."]},
	"ransomware": {"name": "RANSOMWARE SCARE: files renamed *.locked on S:", "stages": ["lockout", "disk"],
		"runbook": "RUNBOOK IR-07: 1) contain: lock the compromised account  2) stop the spread  3) clean up + restore  4) postmortem. Breathe.",
		"gary": ["Gary: Karen clicked a 'FedEx invoice'. She feels terrible. Please be nice to Karen.", "Gary: Legal asked if we 'paid the hackers'. I said no. Did we? We didn't, right?"]},
	"backup_restore": {"name": "FAILED BACKUP RESTORE: last night's job didn't run", "stages": ["disk", "service"],
		"runbook": "RUNBOOK DR-02: 1) find why the job failed  2) free space  3) restart the backup agent  4) verify restore  5) postmortem",
		"gary": ["Gary: Accounting needs yesterday's spreadsheet. The one with the formulas. You know the one.", "Gary: I'm told 'backups are only real if you restore them'. I learned that today. Ha."]},
	"db_corruption": {"name": "DATABASE CORRUPTION: payroll DB won't start", "stages": ["service", "disk"],
		"runbook": "RUNBOOK DR-04: 1) check the service  2) check the disk it lives on  3) recover  4) postmortem",
		"gary": ["Gary: Payroll is Friday. It's not Friday. We're fine. Are we fine?", "Gary: I made a status page. It just says 'we're on it 👍'. Is that okay?"]},
	"ups_failure": {"name": "POWER/UPS FAILURE: server room rebooted itself", "stages": ["service", "vlan"],
		"runbook": "RUNBOOK DR-06: 1) bring services back in order  2) check the switch config survived  3) postmortem (and buy a UPS battery)",
		"gary": ["Gary: The lights flickered and then everything beeped. Is beeping bad?", "Gary: Facilities says the UPS battery is 'from 2014'. That's a decade. That's a whole decade, Dan."]},
	"cert_outage": {"name": "CERT EXPIRY OUTAGE: every browser says 'not secure'", "stages": ["cert", "dns"],
		"runbook": "RUNBOOK IR-03: 1) renew the cert  2) check DNS points where it should  3) postmortem (calendar reminder this time)",
		"gary": ["Gary: Customers think we got hacked. We didn't get hacked. I've said 'we didn't get hacked' nine times.", "Gary: Can we make the certificate not expire? Like, ever? ...No? Okay."]},
}

static func make_stage(r: RandomNumberGenerator, inc_id: String, idx: int) -> TicketSim:
	var inc: Dictionary = INCIDENTS[inc_id]
	var t := TicketSim.new(r, inc["stages"][idx])
	t.title = "%s — stage %d/%d" % [inc["name"], idx + 1, inc["stages"].size()]
	t.from = "Gary (escalation)"
	t.body = inc["gary"][mini(idx, inc["gary"].size() - 1)]
	t.log_lines = ["⚠ TermOS INCIDENT MODE — " + inc["name"], inc["runbook"], "STAGE %d/%d: %s" % [idx + 1, inc["stages"].size(), t.body]]
	return t

# ------------------------------------------------------------ Tab completion
const VERBS := ["cat", "clear", "curl", "dig", "free", "history", "host", "htop", "journalctl", "ls", "man", "ps", "sudo", "top", "uptime", "who", "aduser", "cancel", "certbot", "certcheck", "df", "dns", "du", "exit", "firewall", "help", "hostname", "ip", "ipconfig",
	"logrotate", "lpstat", "netstat", "nslookup", "openssl", "ping", "set", "show", "ss", "ssh", "systemctl", "tail", "traceroute", "unlock", "whoami"]
const SUBS := {"firewall": ["list", "allow"], "systemctl": ["status", "restart"], "show": ["port"], "set": ["port"], "ss": ["-tlnp"],
	"df": ["-h"], "du": ["-sh"], "tail": ["log"], "certbot": ["renew"], "lpstat": ["-o"], "cancel": ["-a"], "ip": ["a"]}
const SERVICES := ["nginx", "smbd", "cups", "payrolld", "sshd"]

## Candidates for the word being typed (bash-style: verbs first, then subcommands/hosts/users/services).
func complete_candidates(line: String) -> Array[String]:
	var words := line.split(" ", true)
	var cur_w: String = words[-1]
	var out: Array[String] = []
	var pool: Array = []
	if words.size() == 1:
		pool = VERBS
	else:
		var v: String = words[0]
		if words.size() == 2 and SUBS.has(v): pool += SUBS[v]
		if v == "sudo":
			return complete_candidates(" ".join(words.slice(1)))
		if v in ["ping", "ssh", "traceroute", "nslookup", "certcheck", "openssl", "dig", "host"]: pool += HOSTS.keys()
		if v in ["dig", "host", "nslookup"] and svc != "": pool.append(svc)
		if v == "curl":
			for h in HOSTS: pool.append("https://" + h)
		if v == "cat": pool += ["/etc/hosts", "/var/log/syslog", "/etc/motd"]
		if v == "man": pool += VERBS
		if v == "journalctl": pool += ["-xe", "-u"]
		if v in ["aduser", "unlock"]: pool += USERS
		if v == "systemctl" and words.size() == 3: pool += SERVICES
		if v == "firewall" and words.size() == 3 and port > 0: pool.append(str(port))
		if v in ["show", "set"] and words.size() == 3 and sw_port > 0: pool.append(str(sw_port))
		if v == "set" and words.size() == 4: pool += ["vlan"]
		if v == "set" and words.size() == 5: pool += [str(good_vlan)]
	for c in pool:
		if str(c).begins_with(cur_w) and not (str(c) in out): out.append(str(c))
	out.sort()
	return out

## Returns [new_line, listing]: completes unique matches (adds a space), extends to the common
## prefix, or (when there's nothing to add) returns the options to list on a double-Tab.
func complete(line: String) -> Array:
	var c := complete_candidates(line)
	if c.is_empty(): return [line, []]
	var head := line.substr(0, line.length() - line.split(" ", true)[-1].length())
	if c.size() == 1: return [head + c[0] + " ", []]
	var pre: String = c[0]
	for x in c:
		while not str(x).begins_with(pre): pre = pre.substr(0, pre.length() - 1)
	return [head + pre, c]
