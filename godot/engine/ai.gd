## Stellar Horizons bot factions and the multi-faction turn coordinator (GDScript port of ai.js).
## Each bot plays every phase with simple heuristics shaped by its faction: what it explores (field weights), what it
## builds (robotic vs crewed, telescopes, armed ships), what it researches (priority chains), policies, diplomacy, bases.
class_name SHAI
extends RefCounted

var E: SHRules
var D: Dictionary
var W: Dictionary
var SYS: Dictionary

# ---------------- faction personalities ----------------
# fw: exploration field weights; re/cv: appetite for robotic explorers / crew vehicles; kinds: robotic explorer mix;
# lab: bases run research labs (true) or mines (false); bases: base-building drive; tech: research priorities (in order);
# pol: policy preferences; dip: improve relations; aggr: appetite for embargoes/wars; polw: weights for random policy choices; trade: use markers
const PROF := {
	"na": {"aggr": .25, "polw": {"hum": 3, "rob": 2, "dip": 1, "eco": 1, "mil": .5}, "fw": {"Eng": 1.35, "Bio": 1.35, "Phy": 1}, "re": 1.2, "cv": 1, "kinds": {"Orbiter": 1.2, "Rover": 1.1, "Flyby": .8, "Telescope": .6}, "lab": true, "bases": .7, "init": 0,
		"tech": ["icd", "acd", "qc", "aqc", "ai", "ars", "pm", "ff", "fr", "cp", "als", "aec", "ag", "hab", "mine", "lcv", "frig", "ops", "tr", "ldsf", "psh"], "pol": ["rob", "eco", "hum", "set", "dip"], "dip": .2, "trade": .3},
	"ru": {"aggr": .3, "polw": {"hum": 5, "dip": 1, "eco": 1, "mil": 1, "rob": .3}, "fw": {"Bio": 1.6, "Eng": 1, "Phy": .8}, "re": .5, "cv": 1.6, "kinds": {"Orbiter": 1, "Flyby": 1.1, "Rover": .7, "Telescope": .3}, "lab": true, "bases": 1.1, "init": 0, "crewWorlds": ["mar", "eur", "tit"],
		"tech": ["orb", "hab", "cp", "als", "aec", "ccls", "acv", "ops", "iops", "aops", "ism", "ag", "hab", "mine", "lcv", "frig", "ldsf", "psh", "ars", "ish"], "pol": ["hum", "set", "eco", "dip"], "dip": .2, "trade": .3},
	"eu": {"aggr": .05, "polw": {"rob": 3, "dip": 3, "eco": 1, "hum": .5, "mil": .1}, "fw": {"Phy": 1.55, "Eng": 1.1, "Bio": .9}, "re": 1.5, "cv": .8, "kinds": {"Telescope": 1.8, "Orbiter": 1.2, "Flyby": 1, "Rover": .8}, "lab": true, "bases": .6, "init": 0, "teles": 2,
		"tech": ["icd", "acd", "qc", "aqc", "ai", "pm", "ff", "fr", "ars", "tr", "itr", "cp", "als", "nano", "mec", "atr"], "pol": ["rob", "dip", "eco", "hum"], "dip": .6, "trade": .6},
	"jp": {"aggr": .03, "polw": {"rob": 4, "eco": 2, "dip": 1.5, "hum": .3, "mil": .1}, "fw": {"Eng": 1.65, "Phy": 1, "Bio": .8}, "re": 1.7, "cv": .4, "kinds": {"Orbiter": 1.3, "Flyby": 1.1, "Rover": 1, "Telescope": .8}, "lab": true, "bases": .4, "init": 0,
		"tech": ["icd", "acd", "qc", "aqc", "nano", "ai", "pm", "ff", "fr", "pam", "ars", "tr"], "pol": ["rob", "eco", "dip"], "dip": .2, "trade": .3},
	"cn_mil": {"aggr": .5, "polw": {"mil": 4, "hum": 3, "eco": 1.5, "rob": 1, "dip": .5}, "fw": {"Eng": 1.3, "Phy": 1.1, "Bio": 1}, "re": 1, "cv": 1.2, "kinds": {"Orbiter": 1, "Rover": 1, "Flyby": .9, "Telescope": .5}, "lab": false, "bases": .8, "init": 2, "armed": true,
		"tech": ["msl", "amsl", "isw", "asw", "fd", "cc", "lcv", "frig", "dest", "icd", "acd", "cp", "hab", "mine", "ars", "pm", "ff", "bd"], "pol": ["mil", "hum", "eco", "set"], "dip": 0, "trade": .2},
	"cn_rob": {"aggr": .1, "polw": {"rob": 3, "hum": 2.5, "eco": 1.5, "dip": 1, "mil": .7}, "fw": {"Eng": 1.4, "Bio": 1.2, "Phy": 1}, "re": 1.2, "cv": 1.1, "kinds": {"Orbiter": 1.1, "Rover": 1.1, "Flyby": .9, "Telescope": .6}, "lab": false, "bases": .9, "init": 0,
		"tech": ["icd", "acd", "hab", "lcv", "frig", "cp", "als", "mine", "ish", "qc", "aqc", "ops", "iops", "pm", "ff", "ars", "tr"], "pol": ["rob", "hum", "set", "eco"], "dip": .2, "trade": .3},
	"as": {"aggr": .02, "polw": {"hum": 5, "eco": 1.5, "dip": 1, "rob": .4, "mil": .1}, "fw": {"Bio": 1.45, "Eng": 1.1, "Phy": .8}, "re": .7, "cv": 1.5, "kinds": {"Orbiter": 1, "Rover": 1, "Flyby": .8, "Telescope": .3}, "lab": false, "bases": 1.6, "init": 0,
		"tech": ["orb", "lcv", "hab", "mine", "astro", "frig", "ish", "ref", "ash", "ag", "ops", "iops", "cp", "als", "lcv", "frig", "tr", "itr", "psh", "ars"], "pol": ["set", "hum", "eco"], "dip": .2, "trade": .5},
	"sa": {"aggr": .1, "polw": {"hum": 3, "dip": 3, "eco": 1, "rob": 1.5, "mil": .3}, "fw": {"Bio": 1.15, "Eng": 1.15, "Phy": 1.15}, "re": 1.1, "cv": 1.1, "kinds": {"Orbiter": 1.1, "Rover": 1.1, "Flyby": 1, "Telescope": .5}, "lab": false, "bases": 1.4, "init": 0,
		"tech": ["orb", "lcv", "hab", "mine", "astro", "cp", "icd", "acd", "ish", "tr", "itr", "atr", "als", "pm", "ff", "ars", "qc"], "pol": ["dip", "set", "eco", "hum"], "dip": 1, "trade": 1},
}
const GOAL_WT := {"mine": 3.5, "common": 2, "dated": 1.6}
const RANGE_LADDER := ["astro", "als", "ldsf", "ccls", "dse", "sch"]
const PROD_CV := {"na": 3, "ru": 3, "sa": 3, "as": 3, "cn": 3, "eu": 4, "jp": 4}  # size of the first space-mining (production) CV
const MIL_ENG := ["msl", "amsl", "fd", "cc", "bd"]
const MIL_PHY := ["isw", "asw", "ef"]
## while true the first faction is driven like a bot too (whole games with no human, e.g. tests)
var driving := false
var _rx_mirror := RegEx.create_from_string("(?i)moves from|transfer box|launch|recalled|reserve|skips exploring|founds|cargo flight|loads |^Initiative: |^Diplomacy decision|^Mission focus")
var _rx_lost := RegEx.create_from_string("(?i)pirate|destroyed|lost")
var _rx_dip := RegEx.create_from_string("^Diplomacy with |^Diplomacy decision")

func _init(engine: SHRules) -> void:
	E = engine
	D = E.D
	W = D.W
	SYS = D.SYS

static func t(v) -> bool: return SHRules.t(v)
static func gi(d, k, def = 0) -> Variant: return SHRules.gi(d, k, def)
static func n(x) -> String: return SHRules.n(x)
func rnd() -> float: return E.rnd.call()

func prof(G) -> Dictionary: return PROF["cn_" + String(G.variant if G.variant != null else "mil")] if G.f == "cn" else PROF[G.f]
func fieldOf(w) -> String: return W[w].f if t(W[w].f) else "Phy"
func fw(G, w) -> float:
	var pr := prof(G)
	var f := fieldOf(w)
	var a: float = gi(pr.fw, f, 1)
	var b := 1.25 if gi(pr, "crewWorlds", []).has(w) else 1.0
	var c := 1.7 if (f == "Phy" and rangeStage(G)) else (1.4 if (f == "Eng" and needCvTech(G)) else 1.0)
	return a * b * c
func pick(a: Array) -> Variant:
	var i := int(floor(rnd() * a.size()))
	return a[i] if i < a.size() else null
func wv(G, w) -> int: return G.w[w].v if G.w.has(w) else 0
func isGas(w) -> bool: return W[w].tags.has("gas")
func tele(w) -> bool: return W[w].tags.has("tele")
func sun(w) -> bool: return W[w].tags.has("sunobs")
## how many of my ships already go for / sit at a system (spread the fleet out)
func crowd(G, sy, kind) -> int: return G.ships.filter(func(s): return s.kind == kind and E.sysOf(s.loc) == sy).size()

# ---------------- bases: where may a bot build? ----------------
# avoid worlds that already host a base (anyone's, NPFs included) unless this bot runs labs and the base there mines;
# never a second base in Earth orbit
func baseSpotOk(G, w) -> bool:
	if w == null or not W.has(w) or not t(W[w].base): return false
	var there := E.allBases(G).filter(func(b): return b.w == w)
	var npf = G.w[w].npf
	if w == "ear": return not there.size()
	if not there.size() and not t(npf): return true
	if SHRules._some(there, func(b): return b.f == G.f): return false
	return prof(G).lab and SHRules._every(there, func(b): return t(b.fac.mine) and not t(b.fac.lab))
func wantBase(G) -> bool: return E.nBase(G) < E.lims(G)[2] + (1 if prof(G).bases >= 1.4 else 0)

# ---------------- mission goals ----------------
# Priority 1: the personal mission, 2: the common mission (and dated missions open to all), 3: the faction's own leanings.
func goals(G) -> Array:
	var sig := ":".join([n(G.y), String(G.phase), String(G.estep) if G.estep != null else "", n(G.mis.mine) if G.mis.mine != null else "", n(G.mis.common) if G.mis.common != null else ""])
	var c = G.get("_aiGoals")
	if c != null and c.sig == sig and c.n == G.ships.size(): return c.v
	var out := []
	var add := func(id, tier: String):
		if id == null: return
		var m = D.MIS[id] if id < D.MIS.size() else null
		if m == null or not G.w.has(m.w) or wv(G, m.w) < 1: return
		out.append({"id": id, "w": m.w, "cv": t(m.cv), "tier": tier, "wt": GOAL_WT[tier], "vp": m.vp})
	add.call(G.mis.mine, "mine")
	add.call(G.mis.common, "common")
	for w in G.w.keys():
		if gi(G.w[w], "dmis", null) != null: add.call(G.w[w].dmis, "dated")
	G["_aiGoals"] = {"sig": sig, "n": G.ships.size(), "v": out}
	return out
## can a crew vehicle (of any size) be sent there with the current technology and range? returns the blocking reason or null
func cvWhy(G, w): return E.cvAllowed(G, {"sz": 2}, "orbit:" + w)
func kindFits(kind, w) -> bool:
	if kind == "Telescope" or kind == "Probe": return false
	if kind == "Rover": return not (isGas(w) or sun(w))
	return true
## how much more a world is worth to this kind of explorer because of an open mission there
func missionMult(G, w, kind) -> float:
	if kind == "Telescope": return 1.0
	var m := 1.0
	for g in goals(G):
		if g.w == w and (not g.cv or kind == "CV") and g.wt > m: m = g.wt
	return m
## goals that still lack an explorer able to complete them: [{g, need: 'CV' | 'RE'}] in priority order
func unmet(G) -> Array:
	var cvs := SHRules._some(G.ships, func(x): return x.cls == "CV" and x.ev > 0)
	var out := []
	for g in goals(G):
		var keep: bool
		if g.cv: keep = not cvs
		elif SHRules._some(G.ships, func(x): return x.cls == "RE" and kindFits(x.kind, g.w)): keep = false
		else: keep = not (cvs and cvWhy(G, g.w) == null)
		if keep: out.append({"g": g, "need": "CV" if g.cv else "RE"})
	return out
## technologies this faction's crewed goals are waiting for (with unmet prerequisites), weight by goal priority
func _wantAdd(G, want: Dictionary, k: String, wt: float) -> void:
	var tt = D.TECHK.get(k)
	if tt == null or t(G.tech.get(k)): return
	want[k] = max(gi(want, k, 0), wt)
	for r in tt.r: _wantAdd(G, want, r, wt)
func techWants(G) -> Dictionary:
	var want := {}
	for g in goals(G):
		if not (g.cv or g.tier != "dated"): continue
		if not g.cv: continue
		var why = cvWhy(G, g.w)
		if why == null: continue
		if why.contains("Orbital Rendezvous"): _wantAdd(G, want, "orb", g.wt)
		elif why.contains("Radiation Shielding"): _wantAdd(G, want, "ars", g.wt)
		elif why.contains("crew range"):
			var k = SHRules._find(RANGE_LADDER, func(x): return not t(G.tech.get(x)))
			if k != null: _wantAdd(G, want, k, g.wt)
	return want

# ---------------- crew vehicles: early-game discipline ----------------
func cvFocus(G) -> bool: return prof(G).cv >= 1  # crew-focused or versatile factions
func rangeStage(G) -> bool: return cvFocus(G) and not (E.has(G, "orb") and E.has(G, "astro"))
func prodTech(G) -> String: return "frig" if PROD_CV[G.f] >= 4 else "lcv"
## after the range techs: crew-focused factions still need the Crew Vehicle techs
func needCvTech(G) -> bool: return cvFocus(G) and not rangeStage(G) and not t(G.tech.get(prodTech(G)))
## worlds a crew vehicle could work right now (open value, reachable with this technology and range)
func cvSites(G) -> int:
	return G.w.keys().filter(func(w): return W.has(w) and not tele(w) and not sun(w) and not W[w].tags.has("alpha") and wv(G, w) >= (1 if w == "ear" else 2) and cvWhy(G, w) == null).size()
## how many crew vehicles this bot wants in total: one per workable site (plus one hauler once it has bases), capped by its limit
func cvTarget(G, lcv: int) -> int: return mini(lcv, maxi(1, cvSites(G)) + (1 if G.bases.size() else 0))

# ---------------- war readiness, hostility and policies ----------------
func armedCV(s) -> bool: return s.cls == "CV" and not t(s.res) and s.cb - s.dmg > 0
func cvTier(s) -> int: return 1 if s.sz <= 3 else (2 if s.sz <= 5 else (3 if s.sz == 6 else 4))
func readiness(F) -> float:
	var cvs = F.ships.filter(func(s): return armedCV(s))
	if not cvs.size(): return 0.0
	var pts: float = 2 * SHRules._sum(cvs, func(s): return cvTier(s)) + MIL_ENG.filter(func(k): return t(F.tech.get(k))).size() + .5 * MIL_PHY.filter(func(k): return t(F.tech.get(k))).size() + .4 * E.polLv(F, "mil")
	return minf(1.5, pts / 14.0)
func hasNpfBase(G, k) -> bool: return SHRules._some(G.w.values(), func(x): return SHRules.eq(x.npf, k))
## a bot may pick a fight only when a Military policy allows it (embargo: Military; war: Vigorous Military)
func canLower(G, k) -> bool:
	var nv: int = G.rel[k] + 1
	return nv <= 5 and (nv < 4 or E.polLv(G, "mil") >= (1 if nv == 4 else 2))
## diplomacy turn of a bot, decided at the moment it resolves (so it sees what factions ahead of it just did)
func diplomacyDecide(G) -> void:
	var pr := prof(G)
	var world = G.world
	var tag: String = n(G.y) + ":dip"
	if gi(G, "aiDip", null) == tag: return
	G.aiDip = tag
	G.dipl = {}
	var inPlay := func(k): return world != null and world.facs.has(k)
	var me := readiness(G)
	var budget: int = mini(6, G.polm)
	var maxN := 3 if budget >= 6 else (2 if budget >= 3 else (1 if budget >= 1 else 0))
	if not maxN:
		E.glog(G, "Diplomacy decision: no politics markers to spend.")
		G.aiHostile = {}
		return
	var notes := []
	var cnt := 0
	# 1. reactions
	var hostile_in: Dictionary = gi(G, "aiHostile", {})
	for k in hostile_in.keys():
		if not inPlay.call(k) or G.rel[k] < 4 or cnt >= maxN: continue
		var them := readiness(world.facs[k])
		var weaker: bool = me < them - .1
		var roll := 1 + int(floor(rnd() * 100))
		var chance := 100 if weaker else (50 if G.rel[k] >= 5 else 25)
		var go := roll <= chance
		notes.append(D.FAC[k].n + " lowered relations to " + D.REL[G.rel[k]] + " (readiness " + ("%.2f" % me) + " vs " + ("%.2f" % them) + (", weaker" if weaker else "") + "): rolls " + n(roll) + " (" + n(chance) + "% to answer) " + ("→ counters with diplomacy" if go else "→ lets it stand"))
		if go and E.setDiplomacy(G, k, 1) == null: cnt += 1
	G.aiHostile = {}
	# 3. lowering relations (decided before the random improvements so the cost works out); costs one attempt
	var hostile = null
	if pr.aggr > 0 and E.polLv(G, "mil") >= 1 and cnt < maxN:
		var cands: Array = G.rel.keys().filter(func(k): return G.rel[k] < 5 and canLower(G, k) and G.dipl.get(k) == null and (true if inPlay.call(k) else hasNpfBase(G, k)) and not (gi(G.dipl, k, 0) > 0))
		var reach := func(k): return SHRules._some(G.w.keys(), func(w): return SHRules.eq(G.w[w].npf, k) and cvWhy(G, w) == null)  # an NPF base its crews can actually get to
		var opts := []
		for k in cands:
			var npf: bool = not inPlay.call(k)
			var them: float = .25 if npf else readiness(world.facs[k])
			if me <= 0: continue  # no combat-ready CV: never
			if npf and not reach.call(k): continue
			if not npf and me < them + .25: continue  # never start a war it is not clearly winning
			var c: float = pr.aggr * 100 * (2.2 if npf else .35) * (.4 + minf(1, me - (0.0 if npf else them)))  # factions in play can answer back, NPFs cannot
			if G.rel[k] == 4: c *= .5  # from embargo to war is costlier still
			opts.append({"k": k, "c": c, "npf": npf})
		if SHRules._some(opts, func(o): return o.npf): opts = opts.filter(func(o): return o.npf)  # raiding NPF bases is the usual target
		if opts.size():
			var o = opts[int(floor(rnd() * opts.size()))]
			var roll := 1 + int(floor(rnd() * 100))
			var go: bool = roll <= o.c
			notes.append("Hostility check vs " + D.FAC[o.k].n + (" (NPF)" if o.npf else "") + ": readiness " + ("%.2f" % me) + ", rolls " + n(roll) + " (" + n(SHRules.rnd_i(o.c)) + "% to " + ("declare war" if G.rel[o.k] == 4 else "embargo") + ") " + ("→ tries to lower relations" if go else "→ keeps the peace"))
			if go and E.setDiplomacy(G, o.k, -1) == null:
				hostile = o.k
				cnt += 1
	# 2. improvements with whoever is left
	var targets: Array = G.rel.keys().filter(func(k): return G.rel[k] > 0 and k != hostile and G.dipl.get(k) == null)
	var want: int = maxi(1 - cnt, 0) + int(floor(rnd() * (maxN - cnt + 1)))
	var made := 0
	var a := 0
	while a < mini(want, maxN - cnt) and targets.size():
		var k = pick(targets)
		if E.setDiplomacy(G, k, 1) == null:
			made += 1
			targets.remove_at(targets.find(k))
		a += 1
	if not made and not cnt: notes.append("no attempts could be paid for" if targets.size() else "relations with everyone are already at Alliance")
	var att := ", ".join(G.dipl.keys().map(func(k): return ("+" if G.dipl[k] > 0 else "−") + D.FAC[k].n))
	E.glog(G, "Diplomacy decision: " + ((n(G.dipl.size()) + " attempt(s) for " + n(E.dipCost(G)) + " politics marker(s): " + att + ".") if att != "" else "no attempts.") + ((" " + "; ".join(notes) + ".") if notes.size() else ""))
## policies: finish the starting track, then the two Space Settlement levels, then crew-focused factions go Human; everything
## else is a weighted random pick shaped by the faction's goals
func policyPick(G) -> void:
	var pr := prof(G)
	if G.get("aiStart") == null: G.aiStart = G.pol.keys().filter(func(k): return G.pol[k] > 0)
	var tryK := func(k): return E.polLv(G, k) < 3 and E.choosePolicy(G, k) == null
	for k in G.aiStart:
		if tryK.call(k): return
	if E.polLv(G, "set") < 2 and tryK.call("set"): return
	if pr.cv >= 1.4 and tryK.call("hum"): return
	var pool: Array = D.POL.map(func(p): return p.k).filter(func(k): return E.polLv(G, k) < 3)
	while pool.size():
		var tot := 0.0
		for k in pool: tot += pr.polw[k] if pr.polw.has(k) else .5
		var r := rnd() * tot
		var i := 0
		while i < pool.size() - 1:
			r -= pr.polw[pool[i]] if pr.polw.has(pool[i]) else .5
			if r <= 0: break
			i += 1
		var k = pool[i]
		pool.remove_at(i)
		if tryK.call(k): return

# ---------------- targets ----------------
func worldScore(G, w, kind) -> float:
	if not G.w.has(w) or wv(G, w) < 1 or tele(w): return 0.0
	if kind == "Rover" and (isGas(w) or sun(w)): return 0.0
	if kind == "CV" and (sun(w) or W[w].tags.has("alpha")): return 0.0
	return wv(G, w) * fw(G, w) * missionMult(G, w, kind)
func sysScore(G, sy, kind) -> float:
	var ws := SHRules.ssort(E.worldsIn(sy).map(func(w): return worldScore(G, w, kind)), func(a, b): return b - a)
	if not ws.size(): return 0.0
	if kind == "Flyby": return ws[0] + .5 * (ws[1] if ws.size() > 1 else 0.0) + .25 * (ws[2] if ws.size() > 2 else 0.0)
	return ws[0]
func baseLocType(w) -> String: return "orbit" if W[w].tags.has("station") else "surf"
## a crew vehicle that can found a base there right away (exploration value, enough supplies on board)
func canBaseAt(G, s, dest: String, sup) -> bool:
	var p := E.P(dest)
	return s.cls == "CV" and s.ev > 0 and p.w != null and p.t == baseLocType(p.w) and baseSpotOk(G, p.w) and wantBase(G) and sup >= E.baseCost(G, p.w)
## base spots this crew may reach and found with sup supplies: [{w, dest, cost}]
func baseSpots(G, s, sup) -> Array:
	if s.cls != "CV" or not (s.ev > 0) or not t(s.cap) or not wantBase(G): return []
	var out := []
	for w in G.w.keys():
		if baseSpotOk(G, w) and sup >= E.baseCost(G, w):
			var x := {"w": w, "dest": baseLocType(w) + ":" + w, "cost": E.baseCost(G, w)}
			if E.cvAllowed(G, s, x.dest) == null: out.append(x)
	return out
func planningBase(G, s) -> bool:
	if s.cls != "CV" or t(s.res) or not (s.ev > 0) or not t(s.cap) or not wantBase(G) or not t(s.cargo.SUP): return false
	var here = E.worldOf(s.loc)
	if here != null and canBaseAt(G, s, s.loc, s.cargo.SUP): return true
	# or a spot it can reach (in this system, or any system its crew range allows) whose base cost it carries
	return baseSpots(G, s, s.cargo.SUP).size() > 0
func destScore(G, s, dest: String, eta, sup = null) -> float:
	var p := E.P(dest)
	var kind = "CV" if s.cls == "CV" else s.kind
	if dest == "orbit:ear" and kind == "Telescope": return 50.0
	var v := 0.0
	if kind == "CV" and p.t == "fly": v = 4.0 if (t(G.fly[p.s].ast) and t(s.prod) and E.has(G, "mine") and s.cap * E.cargoMul(G) > E.sum(s.cargo)) else 0.0  # nothing to research in a flyby box
	elif kind == "CV" and p.t == "box" and p.s == E.sysOf(s.loc): v = 0.0
	elif p.t == "box" or p.t == "fly": v = sysScore(G, p.s, kind) / (1 + .5 * crowd(G, p.s, kind))
	elif p.w != null: v = worldScore(G, p.w, kind) / (1 + G.ships.filter(func(x): return not is_same(x, s) and x.kind == s.kind and E.worldOf(x.loc) == p.w).size())
	if kind == "CV" and p.w != null and G.w.has(p.w) and t(G.w[p.w].npf) and armedCV(s) and p.t != "box" and p.t != "fly" and G.rel[G.w[p.w].npf] >= 4: v += 9 if G.rel[G.w[p.w].npf] >= 5 else 6  # blockade / raid
	var su = s.cargo.SUP if sup == null else sup
	if canBaseAt(G, s, dest, su): v += 6 + 6 * prof(G).bases
	elif kind == "CV" and p.t == "box" and SHRules._some(baseSpots(G, s, su), func(x): return W[x.w].sys == p.s): v += 4 + 4 * prof(G).bases
	return v / (1 + .2 * (eta if eta != null else 0))
func best(arr: Array, f: Callable) -> Variant:
	var b = null
	var bv = -INF
	for x in arr:
		var v = f.call(x)
		if v > bv:
			bv = v
			b = x
	return b if bv > 0 else null

# ---------------- asks ----------------
func answerAsks(G) -> void:
	var guard := 0
	while G.ask.size() and guard < 30:
		guard += 1
		var a: Dictionary = G.ask[0]
		var r = null
		if a.k == "pirate":
			var s = E._shipById(G, a.ship)
			r = E.answer(G, "fight" if (t(gi(prof(G), "armed", false)) and s != null and s.cb > s.dmg) else ("pay" if G.cash >= a.roll else "surrender"))
		elif a.k == "card": r = E.answer(G, a.opts[0])
		elif a.k == "flyby":
			var o = best(a.opts, func(o): return sysScore(G, o.sys, "Flyby") / (1 + .2 * o.eta))
			if o == null: o = a.opts[0]
			r = E.answer(G, o.sys)
		elif a.k == "publicity":
			var w = best(G.w.keys(), func(w): return (worldScore(G, w, "Orbiter") + 1) if SHRules._some(G.ships, func(s): return E.worldOf(s.loc) == w) else 0.0)
			if w == null: w = SHRules._find(G.w.keys(), func(k): return G.w[k].v > 0)
			r = E.answer(G, w)
		elif a.k == "mission": r = E.answer(G, SHRules.ssort(a.opts, func(x, y): return D.MIS[x].vp - D.MIS[y].vp)[0])
		elif a.k == "immigration": r = E.answer(G, G.bases[0].id if G.bases.size() else null)
		elif a.k == "intercept":
			var s = E._shipById(G, a.ship)
			var g = G.world.facs.get(a.by) if G.world != null else null
			r = E.answer(G, "fight" if (s != null and g != null and E.interceptAuto(G, s, {"g": g, "key": a.key}) == "fight") else "stop")
		elif a.k == "search": r = E.answer(G, "ok")
		elif a.k == "assign" or a.k == "battle" or a.k == "pbattle" or a.k == "basehit": r = E.answer(G, "auto")
		elif a.k == "surrender": r = E.answer(G, "exclude" if t(a.split) else ("deny" if (t(a.canDeny) and not a.info.pm and not t(a.info.seize)) else "accept"))
		else: G.ask.pop_front()
		if r is String and G.ask.size() and is_same(G.ask[0], a): G.ask.pop_front()
	if G.ask.size(): G.ask.clear()

# ---------------- phases ----------------
func econ(G) -> void:
	if G.estep == "initiative":
		# d10: 6+ spends politics markers on initiative; then a die the size of min(slot, markers held) says how many
		var slot: int = (G.world.meta.order.find(G.f) + 1) if G.world != null else 1
		var cap: int = mini(slot, G.polm)
		var dec := 1 + int(floor(rnd() * 10))
		if not cap: E.glog(G, "Initiative: no politics markers to spend.")
		elif dec <= 5:
			E.setInitBid(G, 0)
			E.glog(G, "Initiative: rolls " + n(dec) + " on d10 (6+ to spend) and spends no politics markers.")
		else:
			var k := 1 + int(floor(rnd() * cap))
			E.setInitBid(G, k)
			E.glog(G, "Initiative: rolls " + n(dec) + " on d10 (6+ to spend), then " + n(k) + " on d" + n(cap) + " (slot " + n(slot) + ", " + n(G.polm) + " markers held): spends " + n(k) + " politics marker" + ("s" if k > 1 else "") + ".")
	if G.estep == "diplomacy" and G.world == null: diplomacyDecide(G)  # in multi-faction games each bot decides as its turn resolves (advanceWorld)
	if G.estep == "production":
		for b in G.bases: b.out = E.bestOutput(G, b)
	if G.estep == "transport" and t(gi(G, "transferLeft", 0)) and G.bases.size() and G.cash > 12:
		var b = SHRules._find(G.bases, func(x): return x.w != "ear")
		if b == null: b = G.bases[0]
		E.transferRes(G, "earth", b.id, "SUP", mini(G.transferLeft, 3))
	if G.estep == "tech" and G.world == null:
		for k in 12:
			if techPick(G) == null or techTurnBot(G) != "dev": break
	if G.estep == "policy":
		for k in 4:
			if t(gi(G, "policyPicked", false)): break
			var before: Dictionary = G.pol.duplicate()
			policyPick(G)
			if G.pol == before: break
## research: the best affordable technology by this bot's priorities, or null
func techPick(G):
	var pr := prof(G)
	var open: Array = D.TECH.filter(func(tt): return E.techState(G, tt) == "open" and G.bank[tt.f] >= E.techCost(G, tt))
	if not open.size(): return null
	var want := techWants(G)
	var stage := rangeStage(G)
	var pt := prodTech(G)
	var cvf := cvFocus(G)
	var cands := open.filter(func(tt):
		if stage and tt.f == "Phy" and tt.k != "orb" and tt.k != "astro": return false  # save Physics points for the range techs
		if tt.k == "mine" and not t(G.tech.get(pt)): return false  # space mining waits for the production CV
		return true)
	return best(cands, func(tt):
		var i: int = pr.tech.find(tt.k)
		var v: float = (100 - i * 3 if i >= 0 else 20) - E.techCost(G, tt) * .3 + (0 if tt.r.size() else 1) + (25 * want[tt.k] if t(want.get(tt.k)) else 0)
		if stage and (tt.k == "orb" or tt.k == "astro"): v += 200
		elif cvf and not stage and (tt.k == "cv" or tt.k == "lcv" or (tt.k == "frig" and pt == "frig")): v += 60
		return v)
## one research turn: develop one technology, or pass (and turn leftover politics markers into points for its main field)
func techTurnBot(G) -> String:
	var tt = techPick(G)
	if tt != null and E.develop(G, tt.k) == null: return "dev"
	if G.world != null: E.techPass(G)
	var short := func(f, ks: Array) -> bool:
		var need := 0
		for k in ks: need += 0 if t(G.tech.get(k)) else D.TECHK[k].c
		return G.bank[f] < need
	var main: String
	if rangeStage(G) and short.call("Phy", ["orb", "astro"]): main = "Phy"
	elif needCvTech(G) and short.call("Eng", ["cv", "lcv"]): main = "Eng"
	else:
		var pairs := []
		for k in prof(G).fw.keys(): pairs.append([k, prof(G).fw[k]])
		main = SHRules.ssort(pairs, func(a, b): return b[1] - a[1])[0][0]
	while G.polm > 0: E.convertPolitics(G, main)
	return "pass"
## run research turns while it is a bot's turn (driveHuman: also play the human faction, e.g. in tests;
## humanPasses: the human leaves the step, so finish every remaining turn)
func techLoop(H, opt := {}) -> void:
	var world = H.world
	if world == null: return
	for k in 500:
		var f = E.techTurn(world)
		if f == null: return
		if f == H.f and not t(opt.get("driveHuman")):
			if t(opt.get("humanPasses")):
				E.techPass(H)
				continue
			return
		var g = world.facs[f]
		answerAsks(g)
		techTurnBot(g)
func techStep(H) -> bool: return H.world != null and H.phase == "econ" and H.estep == "tech"
func build(G) -> void:
	var pr := prof(G)
	for s in G.ships.filter(func(x): return t(x.res)): E.unreserve(G, s)
	for s in G.ships.filter(func(x): return t(x.dmg)): E.repair(G, s)
	# money is scarce (Earth pays out once a decade): keep enough for launches and unreserving
	var reserve: int = 10 + 2 * E.nBase(G)
	var L := E.lims(G)
	var lre: int = L[0]
	var lcv: int = L[1]
	var idle := SHRules._some(G.ships, func(s): return s.loc == "earth" and not t(s.res) and s.cls == "CV")
	var gs := goals(G)
	var um := unmet(G)
	if gs.size():
		var focus := "; ".join(gs.map(func(g): return ("your mission" if g.tier == "mine" else ("common mission" if g.tier == "common" else "dated mission")) + " " + D.W[g.w].n + (" (crew vehicle)" if g.cv else "")))
		var needTxt := ""
		if um.size():
			var u0 = um[0]
			needTxt = " Needs " + ("a crew vehicle" if u0.need == "CV" else "a robotic explorer") + " for " + D.W[u0.g.w].n + ((" (cannot reach it yet: " + cvWhy(G, u0.g.w) + ")") if (u0.need == "CV" and cvWhy(G, u0.g.w) != null) else "") + "."
		E.glog(G, "Mission focus: " + focus + "." + needTxt)
	for round_i in 2:
		var opts := E.buildOptions(G, "earth").filter(func(o): return o.why == null and G.cash - E.earthCash(G, o.cost) >= reserve)
		# crew vehicles: at most one per workable site, at most `perDecade` this decade, never past the support limit unless a
		# reachable crewed mission needs one (then at most 1 over; 2 over is never allowed)
		var foc = SHRules._first(unmet(G))
		var focCV: bool = foc != null and foc.need == "CV" and cvWhy(G, foc.g.w) == null
		var nCv := E.nCV(G)
		var tgt := cvTarget(G, lcv)
		var perDecade := 2 if (lcv >= 4 and tgt - nCv >= 2) else 1
		if G.get("aiCv") == null or G.aiCv.d != int(G.y / 10): G.aiCv = {"d": int(G.y / 10), "n": 0}  # CVs built this decade (kept in the save)
		var cvBuilt: int = G.aiCv.n
		var over := 1 if (focCV and G.cash - reserve >= 25) else 0
		# a military-minded bot with no combat-ready crew vehicle builds one (it is what makes embargoes and raids possible at all)
		var needArmed: bool = (t(gi(pr, "armed", false)) or (pr.aggr >= .2 and E.polLv(G, "mil") >= 1)) and not SHRules._some(G.ships, func(s): return armedCV(s))
		var cvRoom: bool = cvBuilt < perDecade and (nCv < tgt or (focCV and nCv < lcv + over) or (needArmed and nCv < lcv)) and nCv < lcv + 1
		var reOpts := opts.filter(func(o): return not o.cv and E.nonProbeRE(G) < lre)
		var cvOpts := [] if (not cvRoom or (idle and SHRules._some(G.ships, func(x): return x.cls == "CV" and x.ev > 0 and t(x.cap)))) else opts.filter(func(o): return o.cv)
		var teles: int = G.ships.filter(func(s): return s.kind == "Telescope").size()
		# mission focus: build the explorer the first unmet mission goal needs (foc / focCV set above)
		var scoreRE := func(o) -> float:
			var k: float = gi(pr.kinds, o.kind, .5)
			if foc != null: k *= ((3.0 if kindFits(o.kind, foc.g.w) else .6) if foc.need == "RE" else (.5 if focCV else 1.0))
			if o.kind == "Telescope": k *= 1.6 if teles < int(gi(pr, "teles", 1)) else .25
			return k * (o.u.ev + (2 if t(o.u.spec) else 0)) / max(1, E.sum(o.cost)) * pr.re
		var canFound := SHRules._some(G.ships, func(x): return x.cls == "CV" and x.ev > 0 and t(x.cap))
		var warlike := SHRules._some(G.rel.keys(), func(k): return G.rel[k] >= 4 and not (G.world != null and G.world.facs.has(k)) and hasNpfBase(G, k))
		var scoreCV := func(o) -> float:
			var u = o.u
			var a := 5.0 if (focCV and u.ev > 0) else 1.0
			var b := 4.0 if (needArmed and u.cb > 0) else 1.0
			var c := 2.5 if (u.ev > 0 and t(u.cargo) and not canFound and wantBase(G)) else 1.0
			var d := 1.0 if (u.ev > 0 or (G.bases.size() and G.ships.filter(func(x): return x.cls == "CV" and not (x.ev > 0)).size() < G.bases.size())) else 0.0
			var v: float = u.ev + (u.cargo * pr.bases if u.ev > 0 else 0.0) + (u.cb * 1.5 if (t(gi(pr, "armed", false)) or warlike) else 0.0)
			return a * b * c * d * pr.cv * v / max(1, E.sum(o.cost))
		var cands := []
		for o in reOpts: cands.append([o, scoreRE.call(o)])
		for o in cvOpts: cands.append([o, scoreCV.call(o)])
		if not cands.size(): break
		cands = SHRules.ssort(cands, func(a, b): return b[1] - a[1])
		if E.buildUnit(G, cands[0][0].key, "earth") != null: break
		if cands[0][0].cv: G.aiCv.n += 1
func move(G) -> void:
	for s in G.ships.duplicate():
		if not SHRules.has_obj(G.ships, s) or G.ask.size(): continue
		var m := E.moves(G, s)
		if not m.size(): continue
		var p := E.P(s.loc)
		if s.cls == "CV":
			_moveCV(G, s, m)
			continue
		# robotic explorers: launch toward the best target, orbiters/rovers make their final move from the flyby box
		if t(s.launched) and p.t != "fly": continue
		var o = best(m, func(x): return destScore(G, s, x.dest, x.get("eta")))
		if o != null: E.move(G, s, o.dest, {"probe": SHRules._first(G.probes.get(s.loc, []))})
	# supply bases by LV cargo flight with what their next building needs (base builders also stock up for settlements)
	if G.bases.size() and G.cash > 12:
		var pr := prof(G)
		var need := func(b):
			var first := "lab" if (pr.lab or b.w == "ear") else "mine"
			var want = null
			if not t(b.fac[first]): want = D.FACIL[first][0].c
			elif not t(b.fac.sup): want = D.FACIL.sup[0].c
			elif pr.bases >= 1: want = D.SETTLE_COST
			if want == null: return null
			var miss := {}
			for r in ["ORE", "SUP", "FUEL"]:
				var d: int = int(gi(want, r, 0)) - int(gi(b.stock, r, 0))
				if d > 0: miss[r] = d
			return miss if E.sum(miss) else null
		var b = SHRules._find(G.bases, func(x): return need.call(x) != null)
		if b != null:
			var lvs := E.launchLVs(G, "earth", 1)
			var miss = need.call(b)
			# the smallest launch vehicle that carries it all (South America & Africa carry one more)
			var lv = SHRules._find(lvs, func(o): return (o.n + (1 if G.f == "sa" else 0)) * E.cargoMul(G) >= E.sum(miss))
			if lv == null and lvs.size(): lv = lvs[lvs.size() - 1]
			if lv != null:
				var cap: int = (lv.n + (1 if G.f == "sa" else 0)) * E.cargoMul(G)
				var ld := {}
				var left := cap
				for r in ["ORE", "SUP", "FUEL"]:
					var k: int = mini(left, int(gi(miss, r, 0)))
					if k:
						ld[r] = k
						left -= k
				E.shipCargo(G, b.id, ld, lv.n)
func _moveCV(G, s, m: Array) -> void:
	# reserved (recalled) crews head home: Earth, or one of our bases with a supply station
	if t(s.res):
		var home = best(m, func(x):
			if x.dest == "earth": return 100
			if SHRules._some(G.bases, func(b): return E.baseLoc(b) == x.dest and t(b.fac.sup)): return 90
			if E.sysOf(x.dest) == "ear": return 40
			if E.P(x.dest).t == "box" and E.P(x.dest).s == "ear": return 30
			return 0)
		if home != null and s.loc != "earth": E.move(G, s, home.dest, {})
		return
	var here = E.worldOf(s.loc)
	var room: int = s.cap * E.cargoMul(G) - E.sum(s.cargo)
	# cargo-only crew vehicles haul supplies from Earth to our bases
	if not (s.ev > 0):
		if not t(s.cap): return
		var o = null
		if E.sum(s.cargo) and G.bases.size(): o = best(m, func(x): return (10.0 / (1 + int(gi(x, "eta", 0)))) if SHRules._some(G.bases, func(b): return E.baseLoc(b) == x.dest) else 0.0)
		elif not E.sum(s.cargo): o = SHRules._find(m, func(x): return x.dest == "earth")
		if o == null and s.loc == "earth" and G.bases.size(): o = best(m, func(x): return (5.0 / (1 + int(gi(x, "eta", 0)))) if SHRules._some(G.bases, func(b): return E.sysOf(E.baseLoc(b)) == E.sysOf(x.dest)) else 0.0)
		if o != null:
			var opt := {"load": {"SUP": mini(room, G.cash - 8)}} if (s.loc == "earth" and room > 0 and G.cash > 8) else {}
			if E.move(G, s, o.dest, opt) is String: E.move(G, s, o.dest, {})
		return
	# an explorer that should found a base but has no supplies goes down to Earth to load them
	var needSup: bool = t(s.cap) and s.ev > 0 and wantBase(G) and s.cargo.SUP < 3 and baseSpots(G, s, s.cap * E.cargoMul(G)).size() > 0
	if needSup and s.loc != "earth" and E.sysOf(s.loc) == "ear" and SHRules._some(m, func(x): return x.dest == "earth"):
		E.move(G, s, "earth", {})
		return
	# stay while there is still exploring worth doing here, or while a base could be founded here
	var canExploreHere: bool = here != null and wv(G, here) >= (1 if here == "ear" else 2) and s.ev > s.dmg and not isGas(here) and E.P(s.loc).t != "fly"
	if t(s.launched) and here != null and s.loc != "earth" and (canExploreHere or canBaseAt(G, s, s.loc, s.cargo.SUP)): return
	# go somewhere else worth it (not just hop between this world's orbit and surface), unless a base goes here
	var maxLoad: int = maxi(0, mini(room, G.cash - 8)) if (s.loc == "earth" and t(s.cap)) else 0
	# only pay for supplies when there is a base spot this crew can reach and afford with them
	var spots := baseSpots(G, s, s.cargo.SUP + maxLoad)
	var ld: int = mini(maxLoad, maxi(0, SHRules.mn(spots.map(func(x): return x.cost)) - s.cargo.SUP) + (1 if maxLoad > 3 else 0)) if spots.size() else 0
	var sup: int = s.cargo.SUP + ld
	var foundHere := func(x): return canBaseAt(G, s, x.dest, sup)
	var o = best(m.filter(func(x): return x.dest != "earth" and (E.worldOf(x.dest) != here or foundHere.call(x) or s.loc == "earth")), func(x): return destScore(G, s, x.dest, x.get("eta"), sup) + (.6 if (s.loc == "earth" and x.dest == "orbit:ear") else 0.0))
	if o == null or (destScore(G, s, o.dest, o.get("eta"), sup) < 1.5 and not foundHere.call(o)): return
	var opt := {"load": {"SUP": ld}} if ld > 0 else {}
	if E.move(G, s, o.dest, opt) is String and opt.has("load"): E.move(G, s, o.dest, {})
func combat(G) -> void:
	var opts := E.combatOptions(G)
	if t(gi(prof(G), "armed", false)):
		for o in opts.filter(func(x): return x.k == "pirate"): E.combatAct(G, o)
	# embargo: blockade an NPF base; war: raid it (raiding pays; the fleet needs a combat-ready crew vehicle with some hull left)
	for o in opts.filter(func(x): return x.k == "raid" or x.k == "blockade"):
		var fleet = G.ships.filter(func(s): return E.worldOf(s.loc) == o.w and armedCV(s))
		if o.k == "raid" and SHRules._sum(fleet, func(s): return s.sz - s.dmg) < 3: continue
		E.combatAct(G, o)
	# against another faction: blockade its bases, then fight where our fleet clearly has the upper hand
	for kind in ["fblock", "fleet", "bombard"]:
		for o in E.combatOptions(G).filter(func(x): return x.k == kind):
			if kind != "fblock":
				var p := E.fleetPower(G, o)
				if not (p.mine > 0 and (t(p.get("unarmed")) or p.mine >= (1.5 if kind == "bombard" else 1.25) * p.theirs)): continue
			E.combatAct(G, o)
func explore(G) -> void:
	var pr := prof(G)
	for s in G.ships.duplicate():
		if not SHRules.has_obj(G.ships, s) or G.ask.size(): continue
		var opts := E.exploreOptions(G, s)
		if not opts.size(): continue
		if planningBase(G, s):
			E.glog(G, s.name + " holds " + n(s.cargo.SUP) + " SUP for a base and skips exploring (no recall check).")
			continue
		var o = best(opts, func(o):
			if o.kind == "explore" or o.kind == "probe": return o.value * fw(G, o.w) * missionMult(G, o.w, "CV" if s.cls == "CV" else s.kind)
			if o.kind == "produce": return (1 if s.cap * E.cargoMul(G) - E.sum(s.cargo) > 0 else 0) * o.value * (1.4 if o.res == "SUP" else 1.0) * (1.5 if pr.bases > 1 else .6)
			if o.kind == "harvest": return 6
			return 1)
		if o != null: E.explore(G, s, o)
		answerAsks(G)
func trade(G) -> void:
	var pr := prof(G)
	for s in G.ships.duplicate():
		if s.cls != "CV": continue
		var c = E.canFoundBase(G, s)
		if c != null and baseSpotOk(G, c.w) and wantBase(G) and s.cargo.SUP >= c.cost: E.foundBase(G, s)
		var b = E.atOwnBase(G, s)
		if b != null and E.sum(s.cargo): E.unload(G, s, b)
	for b in G.bases:
		var ups := E.upgradeOptions(G, b).filter(func(o): return o.why == null)
		var order := ["lab" if (pr.lab or b.w == "ear") else "mine", "sup", "mine" if pr.lab else "lab", "def"]
		for c in order:
			var o = SHRules._find(ups, func(x): return x.c == c)
			if o != null and (c != "def" or t(gi(pr, "armed", false))) and b.stock != null and SHRules._every(["ORE", "SUP", "FUEL"], func(r): return int(gi(b.stock, r, 0)) >= int(gi(o.next.c, r, 0))): E.buildFacility(G, b, c)
		if pr.bases >= 1 or b.stock.SUP > 6: E.buildSettlement(G, b)
		if t(b.trade) and rnd() < .5 + pr.trade / 2.0: E.trade(G, {"base": b.id}, 4)
	if pr.trade >= .6:
		for k in G.w.keys():
			if t(G.w[k].npf) and t(G.w[k].npfTrade): E.trade(G, {"w": k}, 4)
func botPhase(G) -> void:
	if G.over: return
	answerAsks(G)
	if G.phase == "econ": econ(G)
	elif G.phase == "build": build(G)
	elif G.phase == "move": move(G)
	elif G.phase == "combat": combat(G)
	elif G.phase == "explore": explore(G)
	elif G.phase == "trade": trade(G)
	answerAsks(G)

# ---------------- coordinator: every phase, each faction acts in initiative order ----------------
# movement and technology go in reverse initiative order. Bots ahead of you act as the phase opens; the rest act
# when you press Next. Notable bot events are copied into your log.
func stepKey(G) -> String: return n(G.y) + ":" + G.phase + ":" + (G.estep if G.estep != null else "")
func orderFor(world) -> Array:
	var H = world.facs[world.meta.human]
	var o: Array = world.meta.order.duplicate()
	if H.phase == "move" or H.estep == "tech": o.reverse()
	return o
func _fresh(g, mark) -> Array:
	var fresh := []
	for l in g.log:
		if is_same(l, mark): break
		fresh.append(l)
	fresh.reverse()
	return fresh
func mirror(H, g, mark) -> void:
	if is_same(H, g): return
	for l in _fresh(g, mark):
		if l.c == "g" or l.c == "x" or _rx_mirror.search(l.t) != null: E.glog(H, D.FAC[g.f].pre + ": " + l.t, "bot")
func runBots(H, when: String) -> void:
	var world = H.world
	if world == null: return
	if techStep(H):
		techLoop(H, {"humanPasses": when != "before"})
		return
	var key := stepKey(H)
	var o := orderFor(world)
	var hi := o.find(H.f)
	var lst: Array
	if when == "before": lst = o.slice(0, hi)
	elif when == "after": lst = o.slice(hi + 1)
	else: lst = o.filter(func(f): return f != H.f)
	var done = gi(world.meta, "done", null)
	if not (done is Dictionary and done.get("key") == key): world.meta.done = {"key": key, "f": {}}
	for f in lst:
		if t(world.meta.done.f.get(f)): continue
		world.meta.done.f[f] = 1
		var g = world.facs.get(f)
		if g == null or g.over: continue
		var mark = g.log[0] if g.log.size() else null
		botPhase(g)
		mirror(H, g, mark)
func begin(H) -> void: runBots(H, "before")
func advanceWorld(H) -> bool:
	var world = H.world
	if world == null: return E.advance(H)
	if H.over or H.ask.size(): return false
	runBots(H, "after")
	if H.phase == "econ" and H.estep == "initiative": E.resolveInitiative(world)
	var order: Array = world.meta.order.duplicate()
	for f in order:
		var g = world.facs[f]
		if g.over: continue
		if not is_same(g, H): answerAsks(g)
		var mark = g.log[0] if g.log.size() else null
		if g.phase == "econ" and g.estep == "diplomacy" and (not is_same(g, H) or driving): diplomacyDecide(g)
		E.advance(g)
		if not is_same(g, H):
			answerAsks(g)
			for l in _fresh(g, mark):
				if (l.c == "x" and _rx_lost.search(l.t) != null) or _rx_dip.search(l.t) != null: E.glog(H, D.FAC[g.f].pre + ": " + l.t, "bot")
	if SHRules._some(world.facs.values(), func(g): return g.over):
		for g in world.facs.values():
			if not g.over: E.finish(g, "The campaign ends.")
	else: runBots(H, "before")
	return true
## a whole game with no human (tests): the first faction is driven like a bot too
func autoPlay(H, maxSteps := 50000) -> int:
	var k := 0
	driving = true
	while not H.over and k < maxSteps:
		k += 1
		if techStep(H): techLoop(H, {"driveHuman": true})
		runBots(H, "before")
		botPhase(H)
		answerAsks(H)
		runBots(H, "after")
		if not advanceWorld(H):
			answerAsks(H)
			if H.ask.size(): H.ask.clear()
	driving = false
	return k
