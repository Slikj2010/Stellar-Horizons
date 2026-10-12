// Stellar Horizons game data, transcribed from the rulebook (2019), July 2020 clarifications,
// tech chart v1.0 and the Vassal 1.2 module. Works in the browser (window.SHD) and in Node (module.exports).
(function (root) {
const D = {};

// Heliocentric systems: key, name, transfer number, decade (NPF/asteroid/pirate placement), hub world key
D.SYS = {
  mer: { n: 'Mercury', t: -2, dec: 2100, hub: 'mer', rad: true },
  ven: { n: 'Venus', t: -1, dec: 2100, hub: 'ven' },
  ear: { n: 'Earth', t: 0, dec: 2040, hub: 'ear' },
  mar: { n: 'Mars', t: 1, dec: 2050, hub: 'mar' },
  bel: { n: 'Main Belt', t: 3, dec: 2070, hub: 'bel' },
  jup: { n: 'Jupiter', t: 5, dec: 2100, hub: 'jup' },
  sat: { n: 'Saturn', t: 7, dec: 2110, hub: 'sat' },
  ura: { n: 'Uranus', t: 9, dec: 2120, hub: 'ura' },
  nep: { n: 'Neptune', t: 11, dec: 2130, hub: 'nep' },
  kui: { n: 'Kuiper Belt', t: 12, dec: 2140, hub: 'kui' },
  sca: { n: 'Scattered Disk', t: 15, dec: 0, hub: null },
  alp: { n: 'Alpha Centauri', t: 45, dec: 0, hub: 'alp' },
};
D.SYS_ORDER = ['mer', 'ven', 'ear', 'mar', 'bel', 'jup', 'sat', 'ura', 'nep', 'kui', 'sca', 'alp'];

// Worlds. f field, v start exploration, life %, base cost (0 = no bases), intrinsic production, tags, range [lo,hi] for random placement
// tags: sunobs(Sun Observation: orbit only, no CVs/rovers) rocky icy volcanic gas minimal severeAtm rad venus reentry station(base is a space station) surf(has separate surface) nocv norover tele(only telescopes)
const W = (n, sys, f, v, life, base, prod, tags, rng) => ({ n, sys, f, v, life, base, prod, tags: tags.split(' ').filter(Boolean), rng });
D.W = {
  mer: W('Mercury', 'mer', 'Eng', 6, 2, 6, { ORE: 4 }, 'rocky rad surf', [1, 4]),
  // Sun Observation: treated as an orbit, no CV or rover exploration, severe radiation, no bases or cards
  sun: W('Sun Observation', 'mer', 'Phy', 5, 0, 0, {}, 'sunobs rad', null),
  ven: W('Venus', 'ven', 'Phy', 6, 1, 6, { FUEL: 3, ORE: 2 }, 'rocky volcanic severeAtm venus surf', [5, 7]),
  ear: W('Earth orbit', 'ear', 'Bio', 3, 0, 2, {}, 'station earth reentry', null),
  moo: W('Moon', 'ear', 'Eng', 4, 2, 3, { ORE: 1 }, 'rocky surf', [12, 19]),
  nea: W('Near Earth Asteroids', 'ear', 'Eng', 4, 3, 3, { ORE: 2 }, 'rocky minimal', [8, 11]),
  mar: W('Mars', 'mar', 'Bio', 6, 12, 4, { ORE: 1, SUP: 2 }, 'rocky icy surf', [20, 26]),
  pho: W('Phobos-Deimos', 'mar', 'Eng', 4, 2, 4, { ORE: 2 }, 'rocky minimal', [27, 30]),
  com: W('Comet', 'mar', 'Phy', 4, 4, 0, {}, 'icy minimal', null),
  bel: W('Main Belt', 'bel', 'Eng', 5, 3, 7, { ORE: 3 }, 'rocky minimal', [31, 33]),
  cer: W('Ceres', 'bel', 'Bio', 5, 5, 7, { SUP: 1, ORE: 2 }, 'icy minimal', [34, 35]),
  hyg: W('Hygeia-Pallas', 'bel', 'Eng', 4, 3, 7, { ORE: 2 }, 'rocky minimal', [36, 37]),
  ves: W('Vesta', 'bel', 'Eng', 4, 3, 7, { ORE: 2 }, 'rocky minimal', [38, 39]),
  jup: W('Jupiter', 'jup', 'Phy', 5, 1, 9, { FUEL: 5 }, 'gas severeAtm rad station surf', [58, 59]),
  io: W('Io', 'jup', 'Phy', 7, 4, 8, { FUEL: 3, ORE: 2 }, 'rocky volcanic rad', [54, 57]),
  eur: W('Europa', 'jup', 'Bio', 7, 14, 8, { SUP: 3 }, 'icy rocky rad', [49, 53]),
  gan: W('Ganymede', 'jup', 'Phy', 6, 5, 8, { ORE: 1, SUP: 2 }, 'icy rocky', [44, 48]),
  cal: W('Callisto', 'jup', 'Bio', 5, 6, 8, { ORE: 1, SUP: 2 }, 'icy rocky surf', [40, 43]),
  tro: W('Trojans & Greeks', 'jup', 'Eng', 5, 4, 9, { ORE: 2, SUP: 1 }, 'icy rocky minimal', [60, 61]),
  sat: W('Saturn', 'sat', 'Phy', 5, 2, 9, { FUEL: 4 }, 'gas severeAtm station', [72, 73]),
  mim: W('Mimas-Enceladus-Tethys', 'sat', 'Bio', 7, 9, 7, { ORE: 2, SUP: 2 }, 'icy rocky', [70, 71]),
  dio: W('Dione-Rhea', 'sat', 'Eng', 6, 5, 9, { ORE: 2 }, 'icy rocky', [68, 69]),
  tit: W('Titan', 'sat', 'Bio', 8, 9, 9, { FUEL: 3, ORE: 2 }, 'icy rocky volcanic', [64, 67]),
  hyp: W('Hyperion-Iapetus', 'sat', 'Eng', 5, 4, 9, { ORE: 2 }, 'icy rocky', [62, 63]),
  ura: W('Uranus', 'ura', 'Phy', 5, 2, 8, { FUEL: 4 }, 'gas severeAtm station surf', [80, 81]),
  cha: W('Chariklo', 'ura', 'Phy', 5, 4, 9, { ORE: 2 }, 'icy minimal', [74, 75]),
  obe: W('Oberon-Titania', 'ura', 'Eng', 5, 5, 9, { ORE: 2 }, 'icy rocky minimal', [76, 77]),
  umb: W('Umbriel-Ariel-Miranda', 'ura', 'Eng', 5, 4, 9, { ORE: 2 }, 'icy rocky', [78, 79]),
  nep: W('Neptune', 'nep', 'Phy', 7, 2, 8, { FUEL: 4 }, 'gas severeAtm station', [87, 88]),
  tri: W('Triton', 'nep', 'Phy', 7, 7, 9, { FUEL: 2, ORE: 2 }, 'icy volcanic', [82, 84]),
  gal: W('Galatea-Larissa-Proteus', 'nep', 'Eng', 6, 3, 9, { ORE: 2 }, 'rocky minimal', [85, 86]),
  kui: W('Kuiper Belt', 'kui', 'Phy', 7, 6, 8, { ORE: 2 }, 'icy minimal', [94, 97]),
  plu: W('Pluto-Charon', 'kui', 'Phy', 8, 5, 9, { ORE: 2 }, 'icy', [89, 93]),
  hau: W('Haumea-Makemake', 'kui', 'Phy', 7, 6, 9, { ORE: 2 }, 'icy rocky', [98, 100]),
  sed: W('Sedna', 'sca', 'Phy', 8, 5, 9, { ORE: 2 }, 'icy minimal', null),
  eri: W('Eris-Dysnomia', 'sca', 'Phy', 9, 5, 9, { ORE: 2 }, 'icy', null),
  dsa: W('Deep Space Astronomy', 'sca', 'Phy', 9, 5, 0, {}, 'tele', null),
  alp: W('Alpha Centauri', 'alp', 'Phy', 9, 0, 0, {}, 'alpha', null),
};
D.ALPHA = [[4, 'Phy', 3], [7, 'Eng', 5], [10, 'Bio', 10]]; // d10 <= x -> field, life%
// Settlement VP by system
D.SET_VP = { ear: 1, moo: 1.25, nea: 1.25, mar: 1.25, mer: 1.5, ven: 1.5, bel: 1.5, jup: 1.75, sat: 1.75 };

// World cards: prod ORE FUEL SUP, research [field,value], eligibility test, exploration bonus {who: n}, life bonus %
D.CARDS = [
  ['Chasms', 2, 2, 4, 'Phy', 3, 'rockyOrIcy', { crew: 1 }],
  ['Cratered Surface', 1, 1, 1, 'Eng', 1, 'rockyOrIcy', { rover: 2 }],
  ['Escarpments', 3, 2, 1, 'Eng', 2, 'rockyOrIcy', { crew: 3 }],
  ['Frozen Methane', 1, 6, 2, 'Phy', 4, 'notVenus', { spec: 1 }],
  ['Helium-3', 1, 6, 1, 'Phy', 6, 'gas', { probe: 6 }],
  ['Hematite', 5, 2, 2, 'Eng', 4, 'rocky', { orbiter: 2, flyby: 2 }],
  ['Hydrogen', 1, 4, 2, 'Phy', 2, 'gas', { probe: 4 }],
  ['Impact Basin', 2, 2, 2, 'Eng', 4, 'rocky', { rover: 2 }],
  ['Maria', 3, 2, 1, 'Eng', 2, 'rocky', { rover: 4 }],
  ['Mixed Ice', 3, 5, 4, 'Bio', 4, 'icy', { spec: 3 }],
  ['Precious Metals', 6, 3, 2, 'Eng', 6, 'rocky', { spec: 3 }],
  ['Ridged Terrain', 3, 3, 3, 'Eng', 3, 'rockyOrIcy', { crew: 2 }],
  ['Silicate Rocks', 2, 1, 1, 'Eng', 2, 'rocky', { spec: 2 }],
  ['Subterranean Water', 2, 4, 6, 'Bio', 6, 'icy', { spec: 2 }, 5],
  ['Volcanoes', 5, 6, 1, 'Phy', 7, 'volcanic', { all: 2 }],
  ['Volatile Atmosphere', 1, 5, 1, 'Phy', 4, 'severeAtm', { probe: 5 }],
  ['Water Ice', 2, 5, 5, 'Bio', 5, 'icy', { orbiter: 2 }, 4],
  ['C-Class Asteroid', 2, 3, 4, 'Phy', 4, 'minimal', { orbiter: 1, flyby: 1 }],
  ['M-Class Asteroid', 5, 1, 1, 'Eng', 6, 'rockyMinimal', { orbiter: 2, flyby: 2 }],
  ['S-Class Asteroid', 3, 2, 2, 'Eng', 2, 'minimal', { spec: 2 }],
].map(([n, ORE, FUEL, SUP, rf, rv, el, bonus, lifeB]) => ({ n, prod: { ORE, FUEL, SUP }, rf, rv, el, bonus, lifeB: lifeB || 0, img: n === 'Subterranean Water' ? 'Subterrain Water' : n === 'Volcanoes' ? 'Valcanoes' : n }));
D.cardOk = (card, w) => {
  const t = w.tags;
  if (t.includes('tele') || t.includes('alpha') || t.includes('earth') || t.includes('sunobs')) return false;
  switch (card.el) {
    case 'rockyOrIcy': return t.includes('rocky') || t.includes('icy');
    case 'notVenus': return !t.includes('venus');
    case 'gas': return t.includes('gas');
    case 'rocky': return t.includes('rocky');
    case 'icy': return t.includes('icy');
    case 'volcanic': return t.includes('volcanic');
    case 'severeAtm': return t.includes('severeAtm');
    case 'minimal': return t.includes('minimal');
    case 'rockyMinimal': return t.includes('rocky') && t.includes('minimal');
  }
  return false;
};

// Tech chart. k, field, name, cost, prereqs, short effect
const T = (k, f, n, c, r, d) => ({ k, f, n, c, r: r ? r.split(' ') : [], d });
D.TECH = [
  T('sol', 'Bio', 'Signs of Life', 10, '', 'Earth production +2 Biology'),
  T('exl', 'Bio', 'Existing Life', 15, 'sol', 'Earth production +3 Biology, +2 Physics'),
  T('ag', 'Bio', 'Short-Radius Artificial Gravity', 10, '', 'CV recall 45%'),
  T('hab', 'Bio', 'Space Habitation', 15, 'ag', 'Base construction cost -1'),
  T('mine', 'Bio', 'Space Mining', 15, 'hab', 'Production CVs can produce resources'),
  T('ish', 'Bio', 'Improved Space Habitation', 25, 'mine', 'Base construction cost -2'),
  T('terra', 'Bio', 'Terraforming', 25, 'ish', 'Terraforming point costs 4 SUP'),
  T('gen', 'Bio', 'Genetic Engineering', 30, 'terra', 'Buy Biology points $1B each, sell 2 for $1B'),
  T('ref', 'Bio', 'Space Refining', 25, 'ish', 'Subtract 1 from CV production roll'),
  T('ash', 'Bio', 'Advanced Space Habitation', 30, 'ref', 'Base construction cost -3'),
  T('atm', 'Bio', 'Atmosphere Processing', 35, 'ash gen', 'Terraforming point costs 3 SUP'),
  T('ops', 'Bio', 'Space Operations', 20, 'ag', 'CV recall 40%'),
  T('iops', 'Bio', 'Improved Space Operations', 25, 'ops', 'CV recall 35%'),
  T('aops', 'Bio', 'Advanced Space Operations', 25, 'iops', 'CV recall 30%'),
  T('ism', 'Bio', 'Improved Space Medicine', 30, 'aops', 'CV recall 25%'),
  T('asm', 'Bio', 'Advanced Space Medicine', 30, 'ism', 'CV recall 20%'),
  T('ich', 'Bio', 'Interstellar Colonizer Habitation', 50, 'asm ash', 'Victory condition'),
  T('suit', 'Bio', 'Improved Space Suits', 10, '', 'CV exploration +1'),
  T('cp', 'Bio', 'Mechanical Counterpressure Suits', 25, 'suit', 'CV exploration +2'),
  T('als', 'Bio', 'Advanced Life Support', 30, 'cp ops astro', 'CV range 2'),
  T('aec', 'Bio', 'Advanced Exploration Concepts', 30, 'als', 'CV exploration +3'),
  T('ccls', 'Bio', 'Closed Cycle Life Support', 40, 'aec aops ldsf', 'CV range 4'),
  T('acv', 'Bio', 'Advanced Crew Vehicles', 40, 'ccls', 'CV exploration +5'),
  T('sch', 'Bio', 'Safe Crew Hibernation', 40, 'acv asm dse', 'CV range unlimited'),
  T('orb', 'Phy', 'Orbital Rendezvous', 10, '', 'CVs can reach the Moon and Near Earth Asteroids'),
  T('astro', 'Phy', 'Advanced Astrodynamics', 15, 'orb', 'CV range 1'),
  T('tr', 'Phy', 'Trade Routes', 15, 'astro', 'Transfer up to 5 resources after production'),
  T('ldsf', 'Phy', 'Long Duration Space Flight', 30, 'tr als ars', 'CV range 3'),
  T('psh', 'Phy', 'Pressure Shell', 30, 'ldsf', 'Ignore severe atmospheres'),
  T('dse', 'Phy', 'Deep Space Exploration', 40, 'psh ccls itr', 'CV range 5'),
  T('ars', 'Phy', 'Active Radiation Shielding', 20, 'astro isw', 'Ignore severe radiation'),
  T('itr', 'Phy', 'Improved Trade Routes', 30, 'ldsf', 'Transfer up to 10 resources'),
  T('atr', 'Phy', 'Advanced Trade Routes', 30, 'itr', 'Transfer up to 15 resources'),
  T('isw', 'Phy', 'Improved Space Weapons', 10, 'ion', '+1 to attack roll'),
  T('asw', 'Phy', 'Advanced Space Weapons', 20, 'ars', '+3 to attack roll'),
  T('mec', 'Phy', 'Matter-Energy Conversion', 30, 'asw', 'Buy Physics points $1B each, sell 2 for $1B'),
  T('ef', 'Phy', 'Energy Focusing', 30, 'mec', '+5 to attack roll'),
  T('ice', 'Phy', 'Interstellar Colonizer Engine', 50, 'ef atr aam', 'Victory condition'),
  T('ion', 'Phy', 'Ion Engines', 10, '', 'Heliocentric transfers x0.9'),
  T('pm', 'Phy', 'Plasmadynamic Propulsion', 15, 'ion', 'Transfers x0.8'),
  T('ff', 'Phy', 'Fission-Fragment Engine', 20, 'pm isw', 'Transfers x0.7'),
  T('fr', 'Phy', 'Fusion Rockets', 25, 'ff', 'Transfers x0.6'),
  T('pam', 'Phy', 'Practical Anti-Matter', 30, 'fr asw', 'Transfers x0.5'),
  T('aam', 'Phy', 'Advanced Anti-Matter', 30, 'pam mec', 'Transfers x0.4'),
  T('hap', 'Phy', 'Hyper-advanced Propulsion', 35, 'aam', 'Transfers x0.2'),
  T('cv', 'Eng', 'Crew Vehicles', 10, '', 'Build CV-2 and LV-3'),
  T('lcv', 'Eng', 'Large Crew Vehicles', 25, 'cv', 'Build CV-3'),
  T('frig', 'Eng', 'Frigates', 30, 'lcv uhlv pm', 'Build CV-4; engine failure 3%'),
  T('dest', 'Eng', 'Destroyers', 30, 'frig ff', 'Build CV-5'),
  T('cru', 'Eng', 'Cruisers', 30, 'dest fr', 'Build CV-6'),
  T('bat', 'Eng', 'Battleships', 30, 'cru pam', 'Build CV-7 and larger'),
  T('ichull', 'Eng', 'Interstellar Colonizer Hull', 50, 'bat sht ai', 'Victory condition'),
  T('reuse', 'Eng', 'Reusable Launch Vehicles', 10, '', 'LVs survive on an engine roll above 25'),
  T('uhlv', 'Eng', 'Ultra-Heavy Launch Vehicles', 20, 'reuse cv', 'Engine failure 4%; build LV-4'),
  T('elev', 'Eng', 'Space Elevator', 30, 'dest', 'Ships in orbit count as on the surface'),
  T('sht', 'Eng', 'Space Heavy Transport', 40, 'elev cru nano', 'CV and LV cargo x2'),
  T('icd', 'Eng', 'Improved Component Design', 15, '', 'Malfunction 27%'),
  T('acd', 'Eng', 'Advanced Component Design', 20, 'icd', 'Malfunction 24%'),
  T('qc', 'Eng', 'Quantum Computing', 25, 'acd', 'Malfunction 21%; robotic exploration +1'),
  T('aqc', 'Eng', 'Advanced Quantum Computing', 30, 'qc', 'Malfunction 18%; robotic exploration +2'),
  T('nano', 'Eng', 'Nano-Technology', 30, 'aqc', 'Buy Engineering points $1B each, sell 2 for $1B'),
  T('ai', 'Eng', 'Artificial Intelligence', 40, 'nano', 'Malfunction 15%; robotic exploration +3'),
  T('msl', 'Eng', 'Space Missiles', 10, '', 'Ships with attack values can fire in strike combat'),
  T('amsl', 'Eng', 'Advanced Space Missiles', 10, 'msl', '+1 combat tactics points'),
  T('fd', 'Eng', 'Fighter Drones', 15, 'amsl', 'CVs and defense networks use fighter drones'),
  T('cc', 'Eng', 'Command & Control', 15, 'fd qc', '+2 combat tactics points'),
  T('bd', 'Eng', 'Bomber Drones', 20, 'cc', 'CVs and defense networks use bomber drones'),
];
// tech tree layout [row, column]: rows 0-3 Biology, 4-7 Physics, 8-11 Engineering (after the printed Technology Tree)
D.TECH_POS = {
  sol: [0, 0], exl: [0, 1], terra: [0, 5], gen: [0, 6],
  ag: [1, 0], hab: [1, 1], mine: [1, 2], ish: [1, 3], ref: [1, 4], ash: [1, 5], atm: [1, 6],
  ops: [2, 1], iops: [2, 2], aops: [2, 3], ism: [2, 4], asm: [2, 5], ich: [2, 6],
  suit: [3, 0], cp: [3, 1], als: [3, 2], aec: [3, 3], ccls: [3, 4], acv: [3, 5], sch: [3, 6],
  orb: [4, 0], astro: [4, 1], tr: [4, 2], ldsf: [4, 3], psh: [4, 4], dse: [4, 5],
  ars: [5, 2], itr: [5, 4], atr: [5, 5],
  isw: [6, 1], asw: [6, 3], mec: [6, 4], ef: [6, 5], ice: [6, 6],
  ion: [7, 0], pm: [7, 1], ff: [7, 2], fr: [7, 3], pam: [7, 4], aam: [7, 5], hap: [7, 6],
  cv: [8, 0], lcv: [8, 1], frig: [8, 2], dest: [8, 3], cru: [8, 4], bat: [8, 5],
  reuse: [9, 0], uhlv: [9, 1], elev: [9, 4], sht: [9, 5], ichull: [9, 6],
  icd: [10, 0], acd: [10, 1], qc: [10, 2], aqc: [10, 3], nano: [10, 4], ai: [10, 5],
  msl: [11, 0], amsl: [11, 1], fd: [11, 2], cc: [11, 3], bd: [11, 4],
};
// LV counters are two-sided: lvs.13 = LV-1/LV-3 counters, lvs.14 = LV-1/LV-4, lvs.24 = LV-2/LV-4
// optional scenarios offered when starting a new game
D.SCEN = {
  std: { n: 'Standard campaign (2030)', d: 'The full campaign from 2030.' },
  fut2060: { n: 'Futuristic start (2060)', d: 'Start after the 2060 economic phase. You have every technology in the first two columns of the tree (except Signs of Life and Existing Life), and an extra $40B plus $3B for each technology you would have started a 2030 campaign with. Choose policies for the three missed economic phases. Every world starts with its exploration value reduced by 1.' },
};
D.TECHK = Object.fromEntries(D.TECH.map(t => [t.k, t]));

// Policies: chain of 3 (basic, vigorous, unified)
D.POL = [
  { k: 'set', n: 'Space Settlement', d: ['Base support limit +1', 'Base support limit +2', 'Roll an extra die for settlement growth'] },
  { k: 'dip', n: 'Space Diplomacy', d: ['Draw 1 extra politics marker each economic phase', 'Draw 2 extra politics markers', 'Politics markers are worth 3 tech points'] },
  { k: 'mil', n: 'Military Policy', d: ['You can declare embargoes; +20% initiative', 'You can declare wars; +40% initiative', '+2 combat tactics points; +50% initiative'] },
  { k: 'hum', n: 'Human Policy', d: ['Crew vehicle support limit +1', 'Crew vehicle support limit +2', 'Crew vehicle support limit +3'] },
  { k: 'rob', n: 'Robotic Policy', d: ['Robotic explorer support limit +1', 'Robotic explorer support limit +2', 'Robotic exploration +1'] },
  { k: 'eco', n: 'Space Economics', d: ['+$2B Earth production', '+$4B Earth production', '+$8B Earth production'] },
];
D.POL_LV = ['', 'Vigorous ', 'Unified '];

// Factions. lim = support limits [RE, CV, Base]; pr = Earth production [funds, Phy, Eng, Bio] for 2030/2060/2090/2120+
// rel = foreign relations income/trade at Alliance, Collaboration, Free Trade, Neutral ([+$B, trade limit])
D.FAC = {
  na: { n: 'North America', pre: 'NA', c: '#5b8fd1', cash: 20, lim: [3, 1, 1], pr: [[30, 2, 3, 3], [33, 3, 4, 3], [37, 4, 4, 4], [40, 5, 6, 6]], rel: [[1, 6], [1, 4], [1, 4], [0, 2]], ab: 'Innovative: subtract 2 from the cost of a technology if you are the first to develop it.', st: ['suit', 'orb', 'astro', 'ion', 'cv', 'reuse', 'msl'], pol: ['eco'], lvs: { 13: 1, 14: 1, 24: 3 } },
  ru: { n: 'Russia', pre: 'Ru', c: '#d4553a', cash: 30, lim: [1, 2, 2], pr: [[28, 3, 2, 4], [31, 3, 3, 4], [34, 4, 4, 4], [36, 5, 5, 6]], rel: [[1, 6], [1, 4], [1, 4], [0, 2]], ab: 'Robust Crews: crew recall rate -5%.', st: ['suit', 'orb', 'ion', 'cv', 'msl'], pol: ['hum'], lvs: { 13: 2, 14: 0, 24: 3 } },
  eu: { n: 'Europe', pre: 'Eu', c: '#4d7fd6', cash: 30, lim: [2, 1, 1], pr: [[28, 5, 2, 2], [30, 5, 4, 3], [34, 7, 4, 4], [36, 8, 5, 5]], rel: [[2, 6], [1, 6], [1, 4], [0, 2]], ab: 'Astronomy: roll an extra die for space telescope exploration and keep the better.', st: ['ion'], pol: ['dip'], lvs: { 13: 2, 14: 0, 24: 3 } },
  jp: { n: 'Japan', pre: 'Jp', c: '#e0574a', cash: 28, lim: [1, 1, 1], pr: [[27, 3, 4, 2], [28, 4, 5, 2], [32, 5, 6, 4], [35, 6, 8, 5]], rel: [[2, 6], [1, 6], [1, 4], [0, 4]], ab: 'Robotic Excellence: robotic malfunction rate -2%.', st: [], pol: ['rob'], lvs: { 13: 2, 14: 0, 24: 3 } },
  cn: { n: 'China', pre: 'Ci', c: '#e2b33a', cash: 27, lim: [2, 2, 1], pr: [[29, 2, 3, 2], [32, 3, 4, 4], [36, 4, 5, 4], [40, 5, 7, 6]], rel: [[1, 6], [1, 4], [1, 4], [0, 2]], ab: 'Reverse Engineering: technology costs -4 (instead of -3) per other faction that has it.', st: ['orb', 'cv'], pol: ['mil'], variants: { mil: { n: 'Military', pol: ['mil'], d: 'Starts with Military Policy: embargoes rivals and builds armed ships.' }, rob: { n: 'Robotic', pol: ['rob'], d: 'Starts with Robotic Policy: peaceful and versatile, focused on building bases.' } }, lvs: { 13: 2, 14: 0, 24: 3 } },
  as: { n: 'Asia', pre: 'As', c: '#e38a32', cash: 25, lim: [2, 3, 2], pr: [[25, 1, 2, 1], [28, 2, 3, 3], [32, 3, 4, 3], [34, 4, 5, 4]], rel: [[2, 6], [2, 6], [1, 6], [0, 4]], ab: 'Strategic Resources: +1 resource production at bases.', st: ['cv'], pol: ['eco'], lvs: { 13: 2, 14: 0, 24: 3 } },
  sa: { n: 'South America & Africa', pre: 'SA', c: '#46a86a', cash: 26, lim: [2, 2, 2], pr: [[26, 2, 2, 1], [29, 3, 3, 3], [33, 4, 4, 4], [35, 6, 5, 5]], rel: [[2, 6], [2, 4], [1, 6], [0, 4]], ab: 'Equatorial Launch Sites: launch vehicles carry one extra resource from Earth.', st: [], pol: ['dip'], lvs: { 13: 2, 14: 0, 24: 3 } },
};
D.FAC_ORDER = ['na', 'ru', 'eu', 'cn', 'as', 'jp', 'sa']; // initiative track order (drift roll 1..7)
D.REL = ['Alliance', 'Collaboration', 'Free Trade', 'Neutral', 'Embargo', 'War'];
D.BASE_NAMES = {
  na: ['Spirit', 'Freedom', 'Prosperity', 'Redstone', 'Yosemite', 'Independence'],
  ru: ['Mir', 'Vostok', 'Tselina', 'Zastava', 'Russkaya', 'Glavnaya'],
  eu: ['Alpha', 'Legacy', 'Unify', 'Olympia', 'Terranova', 'Elysium'],
  jp: ['Hoshi', 'Kikai', 'Shin Tochi', 'Ginga', 'Sutakado', 'Tengoku'],
  cn: ['Tiangong', 'Honse Gongdian', 'Jihui', 'Kongjian', 'Xing', 'Xiwang'],
  as: ['Aatma', 'Taara', 'Asha', 'Ekata', 'Yaatra', 'Tee'],
  sa: ['Unidad', 'Progreso', 'Roho', 'Libertad', 'Esperanze', 'Tumaini'],
};
// Settlement table: [min settlements, trade limit, resource bonus, tech bonus]
D.SETT = [[1, 2, 0, 0], [3, 4, 1, 1], [5, 6, 1, 2], [8, 8, 2, 3], [12, 10, 2, 4], [20, 10, 3, 5], [30, 10, 4, 6], [40, 10, 5, 7], [60, 10, 6, 8]];

// Campaign starting fleets. loc: earth | eorbit | orbit:<world> | surf:<world> | box:<sys>:<n>
D.START = {
  na: [['CV', 'Orion', 'box:mar:1'], ['RE', 'Sagan', 'box:kui:6', 2], ['RE', 'Feynman', 'orbit:ven'], ['RE', 'Lowell', 'orbit:ear']],
  ru: [['CV', 'Kliper', 'earth'], ['RE', 'Kozlov', 'orbit:mar'], ['RE', 'Glushko', 'box:jup:4'], ['RE', 'Zasyadko', 'box:sat:6'], ['LV', 2, 'earth']],
  eu: [['RE', 'Da Vinci', 'box:jup:2'], ['RE', 'Hawking', 'orbit:mer'], ['RE', 'Darwin', 'box:sat:5', 0, 'Curie'], ['RE', 'Kepler', 'orbit:ear']],
  jp: [['RE', 'Tanaka', 'box:jup:3', 0, 'Ito'], ['RE', 'Kimura', 'box:sat:5'], ['RE', 'Yukawa', 'box:mer:2'], ['RE', 'Hayashi', 'orbit:ear']],
  cn: [['CV', 'Shenzhou', 'orbit:moo'], ['RE', 'Fei Xin', 'box:jup:3'], ['RE', 'Xu Gangqi', 'box:sat:2'], ['RE', 'Gan De', 'box:mer:2']],
  as: [['CV', 'Prayaas', 'orbit:ear'], ['RE', 'Rama', 'orbit:ven'], ['RE', 'Chakrabarti', 'box:jup:4'], ['RE', 'Singh', 'box:sat:5']],
  sa: [['RE', 'Caldeira', 'box:jup:3'], ['RE', 'Gleiser', 'box:sat:4'], ['RE', 'Sabato', 'box:kui:6'], ['RE', 'Humboldt', 'surf:mar']],
};
// "Sagan to Kuiper 8-box": boxes stop at 6, extra turns are carried as a hold count (Helio +6 marker style)

// Facilities: chain -> levels with incremental cost and name/marker
D.FACIL = {
  lab: [{ n: 'Small Research Lab', c: { ORE: 1, SUP: 1 }, m: 'lab_s' }, { n: 'Large Research Lab', c: { ORE: 2, SUP: 2 }, m: 'lab_l' }],
  mine: [{ n: 'Small Mining Station', c: { ORE: 1, SUP: 1 }, m: 'mine_s' }, { n: 'Large Mining Station', c: { ORE: 2, SUP: 2 }, m: 'mine_l' }, { n: 'Small Refinery', c: { ORE: 3, SUP: 3 }, m: 'ref_s' }, { n: 'Large Refinery', c: { ORE: 4, SUP: 4 }, m: 'ref_l' }],
  sup: [{ n: 'Small Supply Station', c: { ORE: 1, FUEL: 1 }, m: 'sup_s' }, { n: 'Large Supply Station', c: { ORE: 2, FUEL: 2 }, m: 'sup_l' }, { n: 'Small Spaceport', c: { ORE: 3, FUEL: 3 }, m: 'port_s' }, { n: 'Large Spaceport', c: { ORE: 4, FUEL: 4 }, m: 'port_l' }],
  def: [{ n: 'Small Defense Network', c: { ORE: 3 }, m: null, drones: 1 }, { n: 'Large Defense Network', c: { ORE: 6 }, m: null, drones: 3 }],
};
D.MINE_BONUS = [0, 0, 1, 3, 5];
D.SETTLE_COST = { ORE: 2, SUP: 2, FUEL: 1 };

// Missions: world key, VP, CV-only, year added (0 = start)
D.MIS = [
  ['cal', 3], ['cer', 3], ['eur', 4], ['gan', 3], ['hyg', 3], ['io', 4], ['jup', 4], ['mar', 2], ['mer', 2], ['mim', 4], ['nep', 4], ['pho', 2], ['plu', 4], ['sat', 4], ['tit', 4], ['tri', 4], ['ura', 4], ['ven', 2], ['ves', 3],
  ['cal', 3, 1, 2100], ['cer', 3, 1, 2080], ['cha', 4, 1, 2120], ['com', 3, 1, 2040], ['eri', 5, 0, 2060], ['mar', 3, 1, 2040], ['mer', 4, 1, 2080], ['plu', 5, 1, 2130], ['sed', 5, 0, 2070], ['tit', 4, 1, 2110], ['ven', 4, 1, 2120],
].map(([w, vp, cv, yr], i) => ({ id: i, w, vp, cv: !!cv, yr: yr || 0 }));

// Pirates: weak (before 2120) and strong side
D.PIRATE = { weak: { size: 2, cb: 1 }, strong: { size: 4, cb: 3 } };
// Asteroid harvest d10 -> [type, amount]
D.HARVEST = [null, ['SUP', 3], ['SUP', 4], ['SUP', 5], ['FUEL', 3], ['FUEL', 4], ['FUEL', 5], ['ORE', 3], ['ORE', 4], ['ORE', 5], ['ORE', 6]];
// Combat table: direct fire and strike thresholds -> damage
D.combatDamage = (total, strike) => {
  if (!strike) {
    const t = [[4, 0], [7, 1], [10, 2], [13, 3], [15, 4], [17, 5], [19, 6], [21, 7], [23, 8], [24, 9], [25, 10]];
    for (const [hi, d] of t) if (total <= hi) return d;
    return Math.min(25, total - 15);
  }
  const t = [[6, 0], [8, 1], [10, 2], [12, 3], [15, 4], [18, 5], [21, 6], [24, 7], [27, 8], [29, 9], [31, 10]];
  for (const [hi, d] of t) if (total <= hi) return d;
  return Math.min(25, 10 + Math.ceil((total - 31) / 2));
};
// NPF raid table d10 -> [resources captured, damage taken]
D.RAID = [null, [1, 4], [2, 3], [3, 2], [4, 2], [5, 2], [6, 1], [6, 1], [6, 1], [6, 0], [0, 0]];
// Events: [hi, key, name, text]
D.EVENTS = [
  [12, 'publicity', 'Publicity Campaign', 'Raise one non-depleted world\'s exploration value by 2.'],
  [17, 'budget', 'Increased Space Budget', 'The player with the fewest earned missions earns $5B extra.'],
  [21, 'miners', 'Miner Strikes', 'Base resource production is halved; every Mining Station and Refinery takes a damage marker.'],
  [25, 'research', 'Research Strikes', 'Base research is halved; every Research Lab takes a damage marker.'],
  [29, 'dockyard', 'Dockyard Strikes', 'Destroy 2 saved resources at every base; every Supply Station and Spaceport takes a damage marker.'],
  [35, 'disaster', 'Natural Disaster', 'A random world is struck: bases there damage every facility and lose half their resources.'],
  [40, 'race', 'Space Race', 'The player behind in settlements plus missions draws 5 politics markers.'],
  [45, 'freight', 'Private Freight Company', 'The player with the fewest settlements may transfer 5 resources this turn.'],
  [59, 'immigration', 'Immigration', 'The player with the fewest settlements adds 2 settlements to a base.'],
  [65, 'thaw', 'Thawing Relations', 'All foreign relations move one step toward Neutral.'],
  [78, 'survey', 'Survey Error', 'A random world draws a world card.'],
  [83, 'swarm', 'Pirate Swarm', 'Roll to place an extra pirate.'],
  [90, 'harvest', 'Bountiful Harvest', 'Roll to place an extra asteroid.'],
  [93, 'comet', 'Massive Comet', 'The comet\'s exploration value rises by 3.'],
  [94, 'signals', 'Extraterrestrial Signals', 'Alpha Centauri and Deep Space Astronomy each rise by 4.'],
  [95, 'storm', 'Solar Storm', 'Every CV away from a base or Earth takes 1 damage; REs away from a base are destroyed on a 1 or 2.'],
  [100, 'optional', 'Optional event', 'Ruins, First Contact, Artificial Intelligence, Incoming and Invasion need every player to agree; skipped in solo play.'],
];
// Terraforming points needed for a fully terraformed world (half = at least half)
D.TERRA = { ven: 18, mar: 24, gan: 18, cer: 22, cal: 20, eur: 20, tit: 18, mim: 18 };
D.TECH_POOL = [1, 1, 1, 2, 2, 2, 3, 3, 3, 5];
D.RATING = [[100, 'Disaster'], [150, 'Defeat'], [175, 'Draw'], [200, 'Minor Victory'], [225, 'Major Victory'], [250, 'Brilliant Victory'], [Infinity, 'Spectacular Victory']];

if (typeof module !== 'undefined') module.exports = D; else root.SHD = D;
})(this);
