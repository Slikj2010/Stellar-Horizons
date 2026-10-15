# Stellar Horizons rules notes (from SH_rules_Final_110819.pdf via WebFetch, + user corrections)

## Dice/rounding
d10 (0=10), percentile 1-100. Success = roll <= value. Round only final result, .5 up.

## Resources & cash
ORE, FUEL, SUP. Earth: buy any resource $1B each; sell 2 of one type for $1B. Bases stockpile unlimited. Ships can't spend, only carry (cargo).
Cash usable anywhere.

## Tech markers / points
Marker pool per field (values; we use 1,1,1,2,2,2,3,3,3,5). At start of tech step (3.1.7) markers -> bank points.
Develop: reverse initiative, one tech per round, repeat until pass. Cost = chart cost -3 per OTHER faction who has it (min 5); in solo the non-player factions keep their starting technologies, so these count (e.g. Crew Vehicles). China: -4 per faction instead. NA: -2 if first (no other faction has it).
Prereqs: all connected techs to left. After tech step: convert politics markers (each -> $1B or 2 tech pts of a type (3 with Unified space diplomacy)), discard rest; then HALVE banked tech points.
Connected benefits don't stack (use stated total).

## Politics markers
+2 each econ phase (+1 per alliance, + policy). Uses: +10% initiative each (max = current initiative slot#); 1 → $1B or 1 → 2 tech points of any field, at any time (Turn tab); 2 = redraw unearned mission; 4 = buy victory marker; diplomacy attempts.

## Missions
Personal mission (draw 1) + 1 common mission. Dated missions (turn track: 2040 Comet CV 3 & Mars CV 3, 2060 Eris 5, 2070 Sedna 5, 2080 Mercury CV 4 & Ceres CV 3, 2100 Callisto CV 3, 2110 Titan CV 4, 2120 Venus CV 4 & Chariklo CV 4, 2130 Pluto CV 5) are placed on their world in their year, open to every faction: the first to deplete it (with a crew vehicle when marked CV) completes it; they are not replaced. Mission tokens show at their worlds (gold = yours, blue = common, red = dated) and in the world's Selected panel; the Faction tab lists your missions and kept missions. Complete by depleting named world (some need CV depletion; telescopes never). Completion: +1 politics marker (on top of depletion's), draw replacement. Kept missions: VP = printed value at end; +$1B per kept mission each production step. Max kept = decade number (2030=1, 2040=2 ... ). If can't keep: +1 politics +1 VM, and YOU choose which mission to give up (regular ones return to the pool, dated ones leave the game). Mission on world at 0 -> removed/replaced.

## Trade markers
"Buy $1B: 2 ORE" / "Sell 1 SUP: $2B". Removed after trade; new ones assigned each econ phase to bases without one (random type & side).

## Victory markers: 1 VP each.

## Foreign relations (2.5)
Track: Alliance, Collaboration, Free Trade, Neutral, Embargo, War. All start Neutral. Effects: budget modifier + max resources tradeable at that faction's (NPF) base (e.g. $1B/6R). Alliance: +1 politics marker/econ.
Embargo: may blockade bases, intercept LVs w/ resources, search/attack CVs. War: attack ships & bases. Never offensive in Earth/Earth orbit.

## Ships
LV-1..4 (LV-3/4 need techs). Built from ORE+FUEL: LV-n = 1 ORE + n FUEL. Expended after move unless Reusable LVs: kept if engine roll > 25 (recover max once/turn). LV can carry resources = size, from its location to any of your bases or base->Earth, instantaneous, engine roll.
REs: Probe (carried, single-use, value 9), Telescope (Earth orbit only, half world value, no missions), Flyby, Orbiter, Rover (not gas giants).
CVs: destroyed when damage = size. Counters: size, exploration value, cargo, production ability, combat value, drones, cost (ORE/SUP/FUEL). Mobile lab: roll 2 keep 1. Spectrometer (RE): draw 2 world cards on depletion keep 1.
CV range: without Orbital Rendezvous, CVs stay on Earth or in Earth orbit (not even the Earth flyby box); Orbital rendezvous -> Moon, NEA and beyond (within range). Range = max helio distance from Earth or a base with Supply Station/Spaceport able to unreserve that CV size.
Reserve: choose at start of turn; recalled; out of range; surrender. Reserved can't explore/produce/trade/build bases/initiate combat; can move. Build reserved: -1 SUP -1 FUEL.
Unreserve: $2B on Earth or 1 SUP+1 FUEL at base. CV-2 small Supply Station, CV-3 large Supply Station, CV-4/5 small Spaceport, larger large Spaceport.
Re-entry: CV-5+ can't land on re-entry worlds (Earth). Severe atmosphere (Venus, gas giants): CV needs Pressure shells; rover on Venus +20% malfunction unless Pressure shells; no rovers on gas giants. Severe radiation (Sun, Jupiter): CV needs Active radiation shielding; RE +10% malfunction unless ARS.
Search for life happens after the world card decision, so a placed card's life bonus (e.g. Water Ice +4%, Subterranean Water +5%) counts.
Severe radiation covers the whole Mercury section (Mercury, Sun Observation, its flyby box and transfer boxes 1-6). Sun Observation (explore 5, Physics): treated as an orbit; no CVs or rovers; no bases or world cards. Orbiters, flybys and telescopes can explore it. An orbiter at Mercury explores the Sun with no -1 penalty (other worlds of a system keep the -1).

## Bases & facilities (2.7)
Stations (Earth orbit, gas giants) / surface bases. One base per faction per location. Built in base construction step (3.6.2) only Earth orbit or worlds with base cost. Destroyed by 1 hit after facilities gone.
Facilities: one of each type per base (settlements unlimited), small then large (upgrade later turn). A base may build any number of different things in one turn (e.g. a small lab and a settlement right after it is founded), but only one tier of each building per turn, and one settlement per turn.
- A base is founded from where its crew vehicle is: in orbit or on the surface (one base per world; Earth and gas giants are orbit only). An orbital base (including the gas giants) cannot build mines until the Space Elevator technology, and a world with a severe atmosphere (Venus, gas giants) also needs Pressure Shell to build a mine; every other facility is unrestricted. Earth can never have mines. A CV can explore on a world where it has a base (orbit or surface).
- Mining Station small: enables resource production (world prod >0). large: +1.
- Refinery (upgrade of large Mining): small +3, large +5.
- Research Lab small: required for tech production; large +3.
- Supply Station small: builds LV-1/2, unreserves CV-2, repairs 1/CV/turn. large: LV-3/4, CV-3, repairs 2.
- Spaceport (upgrade of large Supply): small builds REs & CV-2, unreserve CV-4/5, repair 3; large: all CVs, unlimited repair.
- Defense Network: base defense with combat value 3 (small, 1 drone) or 7 (large, 3 drones); blockade needs fleet combat >= that value.
- Settlements: +1 increments; trade/production; victory.
Facility COSTS: NOT in rules text -> look in Vassal images (player aid).
Damage: CV marker -1 explore & combat. Damaged settlements don't count; damaged mines/labs -1 per damage; repair 1 ORE/marker ($1B on Earth).

## Sequence of play (each year)
Economic phase (every decade from 2040): 3.1.1 politics markers (+2) & events (1 event; 2 from 2100) -> 3.1.2 initiative -> 3.1.3 diplomacy (drift: d10 vs initiative track order NA1 Ru2 Eu3 Cn4? As5? Jp6 SA7 ... 8+ none; attempts cost 1,2,3.. markers, succeed on d10<=6) -> 3.1.4 production -> 3.1.5 resource transport (Trade routes tech) -> 3.1.6 NPF bases/asteroids/pirates/trade markers -> 3.1.7 tech -> 3.1.8 settlement growth -> 3.1.9 policy (1 free policy; max 1 Unified, 10 total).
Then each turn: 3.2 build & service -> 3.3 movement -> 3.4 combat -> 3.5 exploration -> 3.6 trade & base construction -> end check -> advance year.

### 3.1.4 Production
Earth: decade table (2030 band = 2030-2059, 2060 = 2060-2089, 2090=2090-2119, 2120+). + policies, relations, blockades, $1B per kept mission. -$1B per active pirate (to pirate cache).
Maintenance: support limits (RE, CV, Base). CVs and bases above limit cumulative $4B,$10B,$18B,$28B (1st..4th). Non-probe REs above: $2B,$5B,$9B,$14B. Never more than 4 above. Each unused slot +$1B.
Base production: Mining Station -> resources = world card production value + tile intrinsic bonus (+1 lg mine, +3 sm refinery, +5 lg refinery); must be >0. Earth orbit no resources. Research Lab -> tech = world card research value (Earth orbit = 3 any field) +3 large lab, +1 signs of life, +2 life. One output type per base per phase. -1 per better-initiative player producing same type same world; -1 per pirate in system flyby box.

### 3.1.6 Random placement
NPF base: percentile vs tile event ranges (e.g. Mars 20-26%); only if system decade <= current & world has no NPF base.
Asteroids & pirates (from 2050): separate rolls, placed in matching Flyby box. Extra rolls from 2100. Pirates before 2120 weak side. Each pirate +$5B to pirate cache.
Trade markers to every base lacking one (random type/side).

### 3.1.8 Settlement growth
Per base: total settlements; each full 10 -> +1; remainder r: d10 <= r -> +1 (Unified space settlement: 2 dice keep best). Blockaded: lose instead.

## 3.2 Build & service (start of each turn)
Costs from location stockpile; on Earth pay cash. Earth = large Spaceport (no ship > CV-4 without Space elevator). LV-1/2 small Supply St; LV-3/4 large Supply; REs & CV-2 small Spaceport; larger CVs large Spaceport.
Repair 1 ORE/marker. Scrap undamaged CV: refund half each resource type.

## 3.3 Movement
a) drop: every ship in numbered transfer box moves down 1; box 1 -> Flyby box (no roll).
b) moves (reverse initiative). Segments: world<->its orbit; orbit<->orbit same system; orbit<->Flyby box. Chain allowed; multiple moves per turn. Must stop when landing, stacking with base, loading/unloading.
REs first move on an LV. Telescope Earth->Earth orbit only. Flyby only transfer boxes & flyby boxes. Orbiters/Rovers never move once in orbit/landed.
Helio transfer: time = |system number diff| x modifier (blocks of 10 rounded separately); placed in that box number of destination system. RE on LV: transfer time -1 per LV size above 1.
CVs leaving Earth must be carried by LV of size >= CV size.
Engine failure: every move; launch roll covers LV+payload. Base 5% (UHLV 4%? tech chart), CVs subtract size, no roll <1%. Failure destroys ship(s)+cargo. Compensation: RE lost 1 Eng marker; LV with cargo lost 1; CV-2 3; CV-3 5.
Interception: pirates (1 per flyby box) always try to intercept fleets w/ CVs leaving their flyby box unless fleet has CV with combat value.

## 3.4 Combat (see fetch; combat table 11.0 not retrieved)
The combat phase is skipped in any year with no possible combat: no pirate on the board, and no faction embargoing or at war with a faction on the board (an NPF with a base there, or a faction in play).
Search: 4 or less succeeds; +1 per CV after first both sides. LV/RE-only fleets destroyed by any successful search.
Pirate interception (3.4.8): roll d10: pay that $ (to cache) and pass / surrender / fight / pay double to remove.
Destroy pirate: half pirate cache, 1 politics, 1 VM.
NPF raid table (war): d10 -> (res captured, damage): 1:(1,4) 2:(2,3) 3:(3,2) 4:(4,2) 5:(5,2) 6:(6,1) 7:(6,1) 8:(6,1) 9:(6,0) 10:(0,0 base destroyed). No CV lost -> 1 VM.
Blockade: $2B per blockade in production; blockaded base production halved, settlements decline, no trade.
Post-combat VMs for enemy CVs: CV2/3 1, CV4/5 2, CV6 3, CV7+ 4. Own CV lost: Eng markers CV2/3 1, CV4/5 2.

## 3.5 Exploration (each ship once/turn)
RE value = world value + RE value + tech + world card mods. Each full 10 = 1 marker; remainder d10<=r +1 marker.
Orbiter in central world orbit can explore other worlds in system at -1.
Flyby: from flyby box & transfer boxes (-box number). After exploring from Flyby box (incl. via probe) must immediately helio transfer to a system with HIGHER transfer number (Alpha Centauri flyby -> destroyed).
Probes: from carrier's world/orbit; flyby carrier deploys from flyby box -> any world on that orbit. Probe use = carrier's exploration that turn; probe destroyed; carrier no malfunction roll. Probes no spectrometer benefit.
Telescope: Earth orbit, any world except Alpha Centauri, half world value, no missions.
CV: world + CV value + tech + card mods; not Sun observation, gas giants, Deep Space Astronomy. CV in Earth orbit may explore Earth orbit. Mobile lab roll 2 keep 1.
Depletion: RE: each 3-value marker = depletion, max 1 per exploration (errata: >=3). CV: sum >=3. World -1. Then: mission, world card draw, life search, +1 politics marker. Value 0 can't be explored.
Life: d100 <= life value. First = Signs of Life (2 Bio markers, 1 VM, 1 politics); second (needs Signs of life tech) = Life (4 Bio, 2 VM, 2 politics). Signs +1 tech production, life +2.
Malfunction (RE): 30% base after each exploration (not probes). Loss = 1 Eng marker. Recall (CV) 50% -> reserved, +1 Bio marker.
CV production (Space mining): at worlds with world cards, not where you have base; produce 1 + (d10 (-1 Space refining) <= world prod value: +1) + (mod roll 0/1: +1). Then recall roll. Asteroid harvest: CV in flyby box w/ asteroid; harvest table; +1 VM.

## 3.6 Trade & bases
Trade at own base: buy w/ cash or sell resources per marker; qty cap = settlement trade value (faction sheet column) for own bases. Other faction bases need fleet there & Neutral+ relations; NPF qty limit = relation value (e.g. 6R).
Base build: SUP only, from ONE unreserved CV with exploration value, at location; cost = tile base cost (tech reduce, min 1). New base may also build a facility same turn.
Terraforming (tech): points bought with SUP; each extra point same base same turn +1 SUP. Errata: SUP not Physics. Terraforming 4 SUP/pt, Atmosphere processing 3 SUP/pt (v1.0 chart).
End check: from 2145 roll d100 <= (year-2144)%: game ends; auto end after 2169.

## 4.0 Campaign setup
Start at Movement Phase of 2030 (first: drop ships). Starting fleets & cash:
NA $20B: CV-Orion Mars transfer 1-box; RE-Sagan Kuiper Belt transfer 8-box; RE-Feynman Venus orbit; RE-Lowell (telescope) Earth orbit.
Russia $30B: CV-Kliper Earth; RE-Kozlov Mars orbit; RE-Glushko Jupiter 4-box; RE-Zasyadko Saturn 6-box; LV-2 Earth.
Europe $30B: RE-Da Vinci Jupiter 2-box; RE-Hawking Mercury orbit; RE-Darwin Saturn 5-box carrying RE-Curie; RE-Kepler Earth orbit.
Japan $28B: RE-Tanaka Jupiter 3-box carrying RE-Ito; RE-Kimura Saturn 5-box; RE-Yukawa Mercury 2-box; RE-Hayashi Earth orbit.
China $27B: CV-Shenzhou Moon orbit; RE-Fei Xin Jupiter 3-box; RE-Xu Ganqi Saturn 2-box; RE-Gan De Mercury 2-box.
Asia $25B: CV-Prayas Earth orbit; RE-Rama Venus orbit; RE-Chakrabarti Jupiter 4-box; RE-Singh Saturn 5-box.
S. America $26B: RE-Caldeira Jupiter 3-box; RE-Gleiser Saturn 4-box; RE-Sabato Pluto(Kuiper) 6-box; RE-Humboldt Mars (surface).
Each draws 1 mission; 1 common mission. All relations Neutral. Initiative track order.
Solo: score normally, then -3 VP per turn past 2045 (errata: penalty starts 2146 -> -3 per year past 2145). Rating: <100 Disaster, 100-150 Defeat, 151-175 Draw, 176-200 Minor, 201-225 Major, 226-250 Brilliant, 251+ Spectacular.

## VP at end
VMs 1 each; Interstellar colonizer techs 1/2/3 -> 15/30/50; most settlements on terraformed world: full 25, half 10; missions value; Alpha Centauri CV 15 / RE 5 / both 20;
Settlements: Earth orbit 1; Moon, NEA, Mars 1.25; Mercury, Venus, Main Belt 1.5; Jupiter, Saturn 1.75; beyond 2; terraformed +0.5 full / +0.25 half;
Infrastructure 1 VP per non-settlement facility level (large refinery = 4); -3 VP per undeveloped tech; 1 VP/20 unspent tech pts; 1 VP/5 politics markers; fleet 0.5 VP per size (RE 0.5, CV-2 1, CV-3 1.5...).

## 5.0 Events (d100 each econ phase; 2 from 2100) — *only if all agree
1-12 Publicity Campaign: worst initiative +2 exploration to a non-depleted world.
13-17 Increased Space Budget: fewest earned missions +$5B.
18-21 Miner Strikes: halve base resource production; damage all mines/refineries.
22-25 Research Strikes: halve base research; damage all labs.
26-29 Dockyard Strikes: destroy 2 saved resources at each base; damage all supply stations/spaceports.
30-35 Natural Disaster: random world; bases there damage each non-settlement facility, lose half resources.
36-40 Space Race: lowest (settlements + mission values) draws 5 politics (ties 3 each unless all).
41-45 Private Freight Company: fewest settlements transfer 5 resources as if Trade Routes.
46-59 Immigration: fewest settlements +2 settlements at a base.
60-65 Thawing Relations: all relations 1 toward Neutral.
66-78 Survey Error: random world, draw world card, apply if eligible.
79-83 Pirate Swarm: extra pirate roll. 84-90 Bountiful Harvest: extra asteroid roll.
91-93 Massive Comet: comet exploration +3. 94 Extraterrestrial Signals: Alpha Centauri & Deep Space Astronomy +4.
95 Solar Storm: each CV not at base/Earth 1 damage; each RE not at base/Earth destroyed on d10 1-2.
96* Ruins on Mars (Mars value 10). 97* First Contact. 98* AI. 99* Incoming. 100* Invasion. (* skip in solo prototype or treat as none)

## User corrections this session
- Flyby searches any world in system from transfer box with -box number. (rule: then must transfer to HIGHER system or... user: new engine check each helio transfer)
- Orbiters/Rovers: arrive in flyby box, one final move into orbit/landing (engine check). Earth-system launches arrive instantly, single check.
- Unit cost = ORE + SUP + FUEL bought at $1B each on Earth; LV separate (1 ORE + n FUEL).
- LV destroyed on engine roll <=25 (reusable tech keeps it if >25); launch fails <=5 (<=4 UHLV).

## Facility costs (Facility_Table.png) — cumulative upgrade costs
Small Research St 1 ORE+1 SUP; Large +2 ORE +2 SUP (+3 tech).
Small Mining 1 ORE+1 SUP; Large Mining +2/+2 (+1 res); Small Refinery +3 ORE +3 SUP (+3); Large Refinery +4/+4 (+5).
Small Supply St 1 ORE+1 FUEL (LV2/CV2); Large +2 ORE+2 FUEL (LV4/CV3); Small Spaceport +3 ORE+3 FUEL (CV2 build / CV5 service); Large Spaceport +4 ORE +4 FUEL (all).
Small Defense Network 3 ORE (combat value 3, 1 combat drone); Large +6 ORE (combat value 7, 3 drones).
Settlement: 2 ORE + 2 SUP + 1 FUEL each.

## Combat table 11.0: total = combat values + d10 + 1 per enemy unit beyond first (+tech mods)
Damage: DirectFire total -> dmg: <=4:0, 5-7:1, 8-10:2, 11-13:3, 14-15:4, 16-17:5, 18-19:6, 20-21:7, 22-23:8, 24:9, 25:10, then +1 per point (26:11 ... 39:24, 40+:25).
Strike: <=6:0, 7-8:1, 9-10:2, 11-12:3, 13-15:4, 16-18:5, 19-21:6, 22-24:7, 25-27:8, 28-29:9, 30-31:10, then +1 per 2 (32-33:11 ... 58-59:24, 60+:25).

## Asteroid harvest d10: 1-3 SUP 3/4/5; 4-6 FUEL 3/4/5; 7-10 ORE 3/4/5/6. +1 VM.

## Policies (free, 1 per decade; max 10, max 1 Unified). Chains: Space Settlement (base support +1) -> Vigorous (+2) -> Unified (extra die settlement growth).
Space Diplomacy (+1 politics marker) -> Vigorous (+2) -> Unified (politics markers worth 3 tech pts).
Military (embargoes, +20% initiative) -> Vigorous (wars, +40%) -> Unified (+2 combat TP, +50% initiative).
Human (CV support +1) -> Vigorous (+2) -> Unified (+3). Robotic (RE support +1) -> Vigorous (+2) -> Unified (robotic exploration +1).
Space Economics (+$2B Earth production) -> Vigorous (+$4B) -> Unified (+$8B). SA starts with Space Diplomacy.

## Tech tree (Vassal track; costs: user-corrected). Format key: name cost effect [prereqs]
BIO: sol Signs of Life 10 (+2 Bio earth prod; needs someone found SoL) ; exl Existing Life 15 [sol] (+3 Bio +2 Phy earth prod)
 terra Terraforming 25 [ish] (terraform pt 4 SUP); gen Genetic Engineering 30 [terra] (buy Bio pts $1B / sell 2 for $1B)
 ag SRAG 10 (recall 45); hab Space Habitation 15 [ag] (base cost -1); mine Space Mining 15 [hab] (CV gear production); ish Improved Space Hab 25 [mine] (base -2); ref Space Refining 25 [ish] (-1 CV prod roll); ash Adv Space Hab 30 [ref] (base -3); atm Atmosphere Processing 35 [ash, gen] (terraform pt 3 SUP)
 ops Space Ops 20 [ag] (40); iops Improved Space Ops 25 [ops] (35); aops Adv Space Ops 25 [iops] (30); ism Improved Space Medicine 30 [aops] (25); asm Adv Space Medicine 30 [ism] (20); ich Interstellar Colonizer Habitation 50 [asm, ash] (victory)
 suit Improved Space Suits 10 (CV expl +1); cp Mech Counterpressure 25 [suit] (+2); als Adv Life Support 30 [cp, ops, astro] (CV range 2); aec Adv Exploration Concepts 30 [als] (+3); ccls Closed Cycle LS 40 [aec, aops, ldsf] (range 4); acv Advanced Crew Vehicles 40 [ccls] (+5); sch Safe Crew Hibernation 40 [acv, asm, dse] (range unlimited)
PHY: orb Orbital Rendezvous 10 (Moon & NEA); astro Adv Astrodynamics 15 [orb] (range 1); tr Trade Routes 15 [astro] (transfer 5 res); ldsf LDSF 30 [tr, als, ars] (range 3); psh Pressure Shell 30 [ldsf] (ignore severe atm); dse Deep Space Exploration 40 [psh, ccls, itr] (range 5)
 ars Active Radiation Shielding 20 [astro, isw] (ignore radiation); itr Improved Trade Routes 30 [ldsf] (10); atr Adv Trade Routes 30 [itr] (15)
 isw Improved Space Weapons 10 [ion] (+1 attack); asw Adv Space Weapons 20 [ars] (+3); mec Matter-Energy Conversion 30 [asw] (buy/sell Phy pts); ef Energy Focusing 30 [mec] (+5 attack); ice Interstellar Colonizer Engine 50 [ef, atr, aam] (victory)
 ion Ion 10 (x0.9); pm Plasma 15 [ion] (0.8); ff FFE 20 [pm, isw] (0.7); fr Fusion 25 [ff] (0.6); pam PAM 30 [fr, asw] (0.5); aam Adv Anti-Matter 30 [pam, mec] (0.4); hap Hyper-advanced 35 [aam] (0.2)
ENG: cv Crew Vehicles 10 (CV-2, LV-3); lcv Large CV 25 [cv] (CV-3); frig Frigates 30 [lcv, uhlv, pm] (CV-4, engine 3%); dest Destroyers 30 [frig, ff] (CV-5); cru Cruisers 30 [dest, fr] (CV-6); bat Battleships 30 [cru, pam] (CV-7+); ichull Interstellar Colonizer Hull 50 [bat, sht, ai] (victory)
 reuse Reusable LV 10; uhlv Ultra-Heavy LV 20 [reuse, cv] (engine 4%, LV-4); elev Space Elevator 30 [dest]; sht Space Heavy Transport 40 [elev, cru, nano] (CV cargo x2, LV cargo x2)
 icd 15 (27%); acd 20 [icd] (24%); qc 25 [acd] (21%, robotic +1); aqc 30 [qc] (18%, +2); nano 30 [aqc] (buy/sell Eng pts); ai 40 [nano] (15%, +3)
 msl Space Missiles 10; amsl Adv Space Missiles 10 [msl] (+1 TP); fd Fighter Drones 15 [amsl]; cc Command & Control 15 [fd, qc] (+2 TP); bd Bomber Drones 20 [cc]
Starting techs (flags): NA suit,orb,astro,ion,cv,reuse,msl; RU suit,orb,ion,cv,msl; EU ion; JP none; CN orb,cv; AS cv; SA none (+Space Diplomacy policy).

## Board (Vassal Main Map = 9 sections A..I; zones.json has polygons in image px)
A Mercury+Venus, B Earth+Moon+NEA, C Mars(+Comet, Phobos-Deimos)+Main Belt(+Ceres,Hygeia-Pallas,Vesta), D Jupiter(+Io,Europa,Ganymede,Callisto,Trojans), E Saturn(+Mimas-E-T,Dione-Rhea,Titan,Hyperion-Iapetus), F Uranus(+Chariklo,Oberon-Titania,Umbriel-A-M), G Neptune(+Triton, Galatea-L-P [no zone]), H Kuiper Belt(+Haumea-Makemake,Pluto-Charon)+Scattered Disk(+Sedna,Eris), I Deep Space Astronomy + Alpha Centauri.
System transfer numbers: Mercury -2, Venus -1, Earth 0, Mars +1, Main Belt +3, Jupiter +5, Saturn +7, Uranus +9, Neptune +11, Kuiper +12, Scattered +15, Alpha Centauri +45.
System decade (flyby box, for NPF/asteroid/pirate placement): Earth 2040, Mars 2050, Belt 2070, Venus 2100, Mercury 2100, Jupiter 2100, Saturn 2110, Uranus 2120, Neptune 2130, Kuiper 2140, Scattered/AlphaC none.
NPF/asteroid/pirate d100 ranges: Mercury 1-4, Venus 5-7, NEA 8-11, Moon 12-19, Mars 20-26, Phobos-Deimos 27-30, Main Belt 31-33, Ceres 34-35, Hygeia-Pallas 36-37, Vesta 38-39, Callisto 40-43, Ganymede 44-48, Europa 49-53, Io 54-57, Jupiter 58-59, Trojans 60-61, Hyperion-Iapetus 62-63, Titan 64-67, Dione-Rhea 68-69, Mimas-E-T 70-71, Saturn 72-73, Chariklo 74-75, Oberon-Titania 76-77, Umbriel-A-M 78-79, Uranus 80-81, Triton 82-84, Galatea-L-P 85-86, Neptune 87-88, Pluto-Charon 89-93, Kuiper Belt 94-97, Haumea-Makemake 98-100.

## World tile data (descriptor | field life% | intrinsic | base cost | start explore)
Mercury: rocky planet, trace atm, severe radiation | Eng 2 | +4 ORE | 6 | 6
Venus: rocky volcanic planet, severe atm, high grav | Phy 1 | +3 FUEL +2 ORE | 6 | 6
Earth orbit: CV only, Bio research(card 3) | base 2 | explore 3
Moon: rocky moon, no atm, low grav | Eng 2 | +1 ORE | 3 | 4
NEA: rocky asteroids, no atm, minimal | Eng 3 | +2 ORE | 3 | 4
Mars: icy-rocky planet, thin atm, low | Bio 12 | +1 ORE +2 SUP | 4 | 6
Phobos-Deimos: rocky moons, no atm, minimal | Eng 2 | +2 ORE | 4 | 4
Comet: Phy 4, minimal, NO BASES | explore 4
Main Belt: rocky asteroids, no atm, minimal | Eng 3 | +3 ORE | 1? (verify; old data 7) | 5
Ceres: icy dwarf planet, no atm, minimal | Bio 5 | +1 SUP +2 ORE | 7 | 5
Hygeia-Pallas: rocky asteroids | Eng 3 | +2 ORE | 7 | 4
Vesta: rocky asteroid | Eng 3 | +2 ORE | 7 | 4
Jupiter: gas giant, severe atm, severe rad, high grav | Phy 1 | +5 FUEL | 9 | 5
Callisto: icy rocky moon, trace, low | Bio 6 | +1 ORE +2 SUP | 8 | 5
Ganymede: icy rocky moon, trace, low | Phy 5 (errata) | +1 ORE +2 SUP | 8 | 6
Europa: icy rocky moon, trace, severe rad, low | Bio 14 | +3 SUP | 8 | 7
Io: rocky volcanic moon, trace, severe rad, low | Phy 4 | +3 FUEL +2 ORE | 8 | 7
Trojans & Greeks: icy rocky asteroids, no atm, minimal | Eng 4 | +2 ORE +1 SUP | 9 | 5
Saturn: gas giant, severe atm, high | Phy 2 | +4 FUEL | 9 | 5
Mimas-E-T: icy rocky moons, no atm, low | Bio 9 | +2 ORE +2 SUP | 7 | 7
Dione-Rhea: icy rocky moons, no atm, low | Eng 5 | +2 ORE | 9 | 6
Titan: icy rocky volcanic moon, thick atm, low | Bio 9 | +3 FUEL +2 ORE | 9 | 8
Hyperion-Iapetus: icy rocky moons, no atm, low | Eng 4 | +2 ORE | 9 | 5
Uranus: gas giant | Phy 2 | +4 FUEL | 8 | 5
Chariklo: icy minor planet, no atm, minimal | Phy 4 | +2 ORE | 9 | 5
Oberon-Titania: icy rocky moons, no atm, minimal | Eng 5 | +2 ORE | 9 | 5
Umbriel-A-M: icy rocky moons, no atm, low | Eng 4 | +2 ORE | 9 | 5
Neptune: gas giant | Phy 2 | +4 FUEL | 8 | 7
Triton: icy volcanic moon, trace, low | Phy 7 (errata) | +2 FUEL +2 ORE | 9 | 7
Galatea-L-P: rocky moons, no atm, minimal | Eng 3 | +2 ORE | 9 | 6
Kuiper Belt: icy worlds, no atm, minimal | Phy 6 | +2 ORE | 8 | 7
Pluto-Charon: icy dwarf planet & moon, trace, low | Phy 5 | +2 ORE | 9 | 8
Haumea-Makemake: icy rocky dwarf planets, no atm, low | Phy 6 | +2 ORE | 9 | 7
Sedna: icy minor planet, no atm, minimal | Phy 5 | +2 ORE | 9 | 8
Eris-Dysnomia: icy dwarf planet & moon, trace, low | Phy 5 | +2 ORE | 9 | 9
Deep Space Astronomy: telescopes only, Phy 5, half value
Alpha Centauri: each exploration d10 1-4 Phy(3%) 5-7 Eng(5%) 8-10 Bio(10%); no telescopes; explore 9

## World cards (name: ORE FUEL SUP | research field value | types | exploration bonus)
Chasms 2 2 4 | Phy 3 | Rocky or Icy | +1 Crewed
Cratered Surface 1 1 1 | Eng 1 | Rocky or Icy | +2 Rover
Escarpments 3 2 1 | Eng 2 | Rocky or Icy | +3 Crewed
Frozen Methane 1 6 2 | Phy 4 | Any but Venus | +1 Spectrometer
Helium-3 1 6 1 | Phy 6 | Gas Giant | +6 Probe
Hematite 5 2 2 | Eng 4 | Rocky | +2 Orbiter/Flyby
Hydrogen 1 4 2 | Phy 2 | Gas Giant | +4 Probe
Impact Basin 2 2 2 | Eng 4 | Rocky | +2 Rover
Maria 3 2 1 | Eng 2 | Rocky | +4 Rover
Mixed Ice 3 5 4 | Bio 4 | Icy | +3 Spectrometer
Precious Metals 6 3 2 | Eng 6 | Rocky | +3 Spectrometer
Ridged Terrain 3 3 3 | Eng 3 | Rocky or Icy | +2 Crewed
Silicate Rocks 2 1 1 | Eng 2 | Rocky | +2 Spectrometer
Subterranean Water 2 4 6 | Bio 6 | Icy | +2 Spectrometer, +5% life search
Volcanoes 5 6 1 | Phy 7 | Volcanic | +2 All
Volatile Atmosphere 1 5 1 | Phy 4 | Severe Atmosphere | +5 Probe
Water Ice 2 5 5 | Bio 5 | Icy | +2 Orbiter, +4% life search
C-Class Asteroid 2 3 4 | Phy 4 | Minimal Gravity | +1 Orbiter/Flyby
M-Class Asteroid 5 1 1 | Eng 6 | Rocky with Minimal Gravity | +2 Orbiter/Flyby
S-Class Asteroid 3 2 2 | Eng 2 | Minimal Gravity | +2 Spectrometer
(Production at a base = card value of chosen type + tile intrinsic of that type.)

## Launch vehicle counters
LV counters are two-sided: each faction has 2 LV-1/LV-3 counters and 3 LV-2/LV-4 counters. North America instead has 1 LV-1/LV-3 and 1 LV-1/LV-4 (so only one LV-3, and four LV-4s). A counter in play shows one side only. North America's LV-1s use the LV-1/LV-4 counter first (when it isn't showing LV-4); when an LV-1 leaves play its LV-1/LV-3 counter is freed first.

## Optional rule: scrapping explorers and launch vehicles
With "Scrap explorers and launch vehicles" on (Settings), robotic explorers and stocked launch vehicles scrap like crew vehicles: half their materials come back (to the base's stock, or onto the faction board on Earth). Telescopes (Earth orbit) and unlaunched explorers scrap on Earth; orbiters scrap at your base on the world they orbit; rovers at your base on their surface. Choosing Destroy anywhere else (or a damaged CV) just destroys the unit. A CV that founds a base can scrap itself there afterwards.

## Faction board resources (Earth)
Nothing is sold for cash. Resources that reach Earth (scrapping, unloading a ship on Earth, Trade Route transfers to Earth) sit on the faction board. Anything paid on Earth (units, LVs, unreserving, repairs, cargo, transfers from Earth) uses faction-board resources first, and the rest is bought at $1B each. Bases never use money, only their own resources.

## Optional scenario: Futuristic start (2060)
Start after the 2060 economic phase. You have all technologies in the first two columns of the tree (except Signs of Life / Existing Life), plus $40B and $3B for each technology you would have started a 2030 campaign with, on top of your normal starting cash (e.g. North America: $20B + $40B + 7 × $3B = $81B). Choose policies for the 3 missed economic phases (2040, 2050, 2060). Every world's initial exploration value is reduced by 1. Dated missions up to 2060 are in the pool.

## Non-player faction bases and enhanced trading

NPF bases appear like any faction base: a random unused base of that faction (e.g. Japan's Ginga) placed in the world's base row, with its trade marker beside it. Select it for its faction, your relations, your trade limit at each relation level, the trade marker and a Trade button (needs an unreserved crew vehicle fleet at that world in the trade & base phase).
Optional rule — Enhanced trading (Settings; follows the toggle in new games, loaded saves and the current game): instead of being removed after one trade, an NPF base's trade marker stays until every faction in play has traded there once (traders show as coloured dots under the marker and in its panel). Markers still on the board are replaced with new ones in the economic phase's NPF bases & trade markers step.

## Bots and initiative (multi-faction games)
New game: pick your faction and 0-6 bots (each bot's faction chosen; China as Military or Robotic variant). Factions nobody plays stay NPFs. Worlds, cards, life and flyby boxes are shared; each faction has its own fleet, bases, cash, technology and missions.
Each phase is played by every faction in initiative order (movement and technology in reverse); bots ahead of you act when the phase opens, the rest when you press Next. Economic phase gains an Initiative step (after politics): every faction declares (in the previous order) politics markers to spend (+10% each, max = its slot number); all roll d100 + markers + Military Policy (+20/40/50%); the order is reset from highest to lowest, ties to whoever was ahead before. The log shows the markers spent, every roll and the new order. NPF bases, asteroids, pirates and the end-of-game roll are rolled once for everyone. Technology discounts count the techs other factions in play actually have.
Bot personalities: North America versatile (robots first, Engineering/Biology worlds); Russia crewed vehicles and Biology worlds (Mars, Europa, Titan); Europe telescopes, robots, Physics, some trade; Japan robots and the Engineering computing line; China Military embargoes rivals, builds armed ships, hunts pirates / China Robotic peaceful and versatile, focused on building bases; Asia many cheap CVs, mining bases, Biology; South America & Africa versatile, bases stocked by cargo flights, diplomacy and trade. Bots avoid worlds that already hold a base unless they would run a lab next to someone's mine, and never add a second base in Earth orbit. The tech tree shows every faction's tech bank (Physics, Engineering, Biology) in turn order, highlighting whose turn it is and who has passed. Develop technologies (3.1.7) in multi-faction games is played in research turns: tech markers become points, then one at a time in reverse initiative order (1st place goes last) each faction develops ONE technology or passes; a faction that passes is out for the rest of the decade; the others repeat rounds until everyone has passed. You develop on the tech tree when it is your turn (Pass button there; Next also passes). Bots develop their top priority they can afford, and pass when nothing is affordable (converting leftover politics markers). Then politics markers are converted and banks halved. Relations are mutual between factions in play: a diplomacy success, drift or event that changes one side's relation changes the other's to match (e.g. Europe improves Russia to Free Trade, so Russia is at Free Trade with Europe too; if Russia then succeeds with Europe, both go to Collaboration). Bots fight only pirates. In the diplomacy step every bot makes 1 to 3 attempts to improve relations (at least 1 marker, never more than 6), each with a random target that is not already an Alliance. Bot initiative bids: d10, 6+ = spend politics markers; then roll d(min(slot number, markers held)) for how many; both rolls are logged.
Starting policies (policy tree flags): North America Space Economics; Russia Human Policy; Europe Space Diplomacy; Japan Robotic Policy; China Military Policy (or Robotic, by variant); Asia Space Economics; South America & Africa Space Diplomacy.
Data changes: Japan starts with Robotic Policy; China starts with Military Policy (or Robotic, by variant); China's trade limit at Neutral is 2.

### Bot priorities (missions first)
1. **Personal mission.** A bot treats its own mission world as its main goal: robotic explorers and crew vehicles value that world 3.5x as much (crew-only missions count only for crew vehicles), it builds the explorer the goal needs (a crew vehicle for a crew-only mission it can reach, otherwise a robotic explorer that fits the world; rovers cannot do gas giants or the Sun), and it researches what a crewed goal is blocked on (Orbital Rendezvous, Active Radiation Shielding, or the next crew-range technology), with prerequisites.
2. **Common mission** (2x), and dated missions on the board (1.6x; crew-only ones only when a crew vehicle can reach them).
3. **Faction leanings** as before: field weights (for example Russia leans Biology), crew vs robotic appetite, base building, research lists.
Each decade a bot logs its "Mission focus" and what it still needs. The human player sees these lines for the bots.

### Bot crew vehicles and early technology
- **Building CVs.** A bot builds crew vehicles only as fast as there are places they can work: about one per reachable world that still has value (Earth counts as one; the Moon and Near Earth Asteroids need Orbital Rendezvous; farther sectors need crew range), plus one hauler once it has bases, never more than its support limit. At most one CV per decade (two when its limit is 4+ and two sites are open). A reachable crew-only mission can justify one CV over the limit when it has spare cash; two over is never allowed.
- **Range first.** Crew-focused and versatile factions (CV appetite 1+: NA, Russia, China, South America, Asia) research Orbital Rendezvous and Advanced Astrodynamics before anything else in Physics, steer exploration toward Physics sites, and put spare politics markers into Physics points until both are done.
- **Then the CV technologies.** Crew Vehicles (CV-2) and Large Crew Vehicles (CV-3) are boosted next, with exploration leaning toward Engineering and spare markers going into Engineering points. Europe and Japan, whose first production CV is CV-4, count Frigates as the target for Space Mining.
- **Space Mining waits.** No bot considers Space Mining until it has the technology that unlocks its production CV (Large Crew Vehicles, or Frigates for Europe and Japan).

### Bot diplomacy, embargoes, wars and policies
- **Lowering relations needs policy** (rules for everyone): Embargo needs Military policy, War needs Vigorous Military. Relations are mutual, so the other side drops too. A faction may still try to improve relations in its own turn.
- **Bots avoid fights.** China (Military variant) no longer harasses by habit; every bot uses the same dice. A bot only considers lowering relations if it holds the required Military policy, has a combat-ready crew vehicle (no armed CV = never), and rolls d100 under its chance: appetite (China-Military .5, Russia .3, North America .25, China-Robotic and South America .1, Europe .05, Japan .03, Asia .02) x its readiness. NPFs with a base its crews can reach are the usual target (x2.2: raiding pays); a faction in play only if it is clearly stronger (readiness lead of .25+) and at x.35. Embargo to war is halved again.
- **Readiness** = combat-ready CVs by tier (CV2/3 = 1, CV4/5 = 2, CV6 = 3, CV7+ = 4, counted double) + Engineering military techs (Space Missiles ... Bomber Drones, 1 each) + Physics combat techs (.5 each) + .4 per Military policy level, over 14. Crew vehicles dominate; Japan, Asia and Europe are low-income and trade-minded, so they rarely choose war.
- **Answering.** Bots now decide their diplomacy as their own turn resolves, so they see what factions ahead of them in the order just did. If a faction lowered relations to Embargo or War, the bot answers by spending markers to improve them: always when it is the weaker side (lower readiness, or no armed CV), otherwise 25% for an embargo and 50% for a war. The log shows the dice.
- **At embargo/war with an NPF**, bots with combat-ready crew vehicles head for its base worlds and blockade (embargo) or raid (war, fleet with 3+ hull left); war-minded bots build combat CVs.
- **Policies.** Finish the starting track to Unified, then Space Settlement twice (Vigorous), then Asia and Russia go Human; every other pick is a weighted random draw shaped by the faction's goals (North America, China and South America lean Human, Europe and Japan lean Robotic and Diplomacy, China-Military leans Military).
- Faction-versus-faction combat follows rules 3.3.6 and 3.4.1-3.4.7 (see below). Bots attack only when their fleet is clearly stronger (1.25x for ships, 1.5x for a base); they blockade bases whenever relations allow.

## Faction combat (3.3.6, 3.4.1-3.4.7)
- **Fleet / eligibility**: a fleet is all of a faction's unreserved CVs at one location (a world with its orbit and surface, or a flyby box; never Earth). Embargo or worse allows attacks on ships and blockades; war allows orbital bombardment of bases. One search per location per turn. A faction that surrendered cannot be attacked again by the same faction that year.
- **Search**: both sides roll a d10; a search succeeds if either finds on 4 or less, +1 per CV after the first in each fleet. With Fighter Drones, -1 to your roll with a drone squadron (-2 with 5+, Defense Networks count). Bases make the search automatic (the rolls still give tactics points). Unescorted LVs/REs found are destroyed.
- **Surrender**: after a successful search the defender may offer to surrender its whole fleet (bots do when they cannot hurt the attacker, or are outgunned 2 to 1 and would lose 40%+ of their hull). Under embargo the attacker must accept. At war it may refuse a fleet's surrender. Either way a base's surrender must be accepted, but the ships with it can be excluded: they are fought first (as a separate battle) and the base's surrender is taken afterwards. Accepting destroys carried resources and a d10 of base stockpile, seizes half of what was destroyed (up to cargo room), reserves the CVs and takes 1 politics marker. Bots weigh the kills and damage a fight would bring against the reserve delay, a politics marker and seizable resources, and refuse a very one-sided surrender at war when there is nothing to take.
- **Tactics points**: each side earns the enemy's (drone-modified) search roll, +1 per full 7 points of enemy CV size, +1 Advanced Space Missiles / +2 Command & Control, +2 Unified Military policy. Only the side with more points spends the difference: 1 = direct fire instead of strike, 3 = call off the combat, 2 per +1 damage inflicted (or -1 taken), 1 per chosen target. You are asked when you attack and win the points; otherwise the game decides for you.
- **Damage**: total = combat values (+ Physics weapons tech) + a d10 + 1 per enemy unit after the first; read off the 11.0 table (direct fire, or strike which also needs Space Missiles). In direct fire unarmed units are screened. Strike: Fighter Drones cancel enemy damage 1:1; Bomber Drones add damage for the attacking side. Hits alternate, attacker first; strike: the inflicter picks, direct fire: the receiver picks (tactics points can pick any unit).
- **Bases** take hits on a facility, on the settlements, or on resources, chosen by the attacker (a bot hits Defense Network, Lab, Mining, Supply, then settlements, and leaves resources alone). A facility gets a damage marker per hit and is downgraded (large to small, Refinery/Spaceport to Mining/Supply Station) or removed when its damage equals its size. Settlements are stacked as one facility with defense 3 per settlement: each 3 damage removes one settlement, and a settlement carrying damage does not count for trade or production until repaired (1 ORE per marker). A hit on resources destroys 2 resources (any types, set with sliders); resources are only a valid target while a facility or settlement stands. A base with none of these is destroyed by a single hit. A human attacker assigns the hits of a battle in a dialog afterwards. A Defense Network fights with combat value 3 (small) or 7 (large) and counts its 1 or 3 drones toward the drone modifiers. Every 2 damage markers on a CV remove one of its usable drone squadrons.
- **After combat**: victory markers for each CV you destroy (CV-2/3: 1, CV-4/5: 2, CV-6: 3, CV-7+: 4); the owner learns the same number of Engineering markers (1 per lost base); every damage marker on a CV triggers a recall check.
- **Blockade** (embargo or worse, fleet combat value at least the Defense Network's): the base's tech/resource output is halved after modifiers, its settlements decline instead of growing, it cannot trade or get a trade marker, and the blockader receives $2B per base in production. It lapses at the blockader's next combat phase unless the fleet is still there.
- **Interception**: a bot-run hostile fleet that is not outgunned searches ships leaving its location (before the engine check; Earth excluded). REs/LVs alone are destroyed; a CV may stop, fight (as a successful search) or surrender, and if it survives the move proceeds.


## Combat screen

Before a fight the player confirms it ("Fight?"). The search comes first: a search screen shows both rolls and whether contact is made (a failed search ends back on the map). The combat dice are rolled first and shown on a combat screen with each side's units, d10, totals and the damage the table gives for strike and direct fire. The player then builds a plan with the tactics points: direct fire instead of strike (1), increase the damage dealt or decrease the damage received (2 per point), select a target instead of the opponent (1 each), or avoid the combat (3). Damage alternates between the sides; the inflicting player picks targets for a strike, the receiving player for direct fire, and a tactics-point pick goes to the winner. A human who picks targets assigns the hits to units in an assign screen, and can screen unarmed units in direct fire; bots pick automatically. Pirate fights work the same way: they start as a strike (the pirate carries missiles); 1 point switches to direct fire, 2 points buy +1 damage dealt or -1 damage taken, 3 call the combat off. A player who lost the tactics points still sees the roll, then the opponent decides how to fight. Bots decide automatically.

## 2.5D view
The map has a **2.5D** button next to the zoom buttons. It shows the same game from a tilted camera: planets spin as 3D spheres, counters hover over the board with a shadow, world cards and bases lie flat. It changes nothing about the rules. Left-drag pans, the wheel zooms, right-drag (or Shift-drag) rotates and tilts, two fingers pinch and twist, and the ⟲ ⟳ ⤒ ⤓ buttons rotate and tilt. Tap selects and dragging a counter to a highlighted zone moves it, exactly as on the flat map. The choice is remembered.
