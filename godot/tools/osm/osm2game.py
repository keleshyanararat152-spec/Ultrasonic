# OpenStreetMap (.osm XML) -> the game's Yerevan data (assets/yerevan/*.json), in game units (0.1 m), north up
# (game y grows to the south). Origin: the middle of Republic Square, shifted by OFFSET so all is positive.
# Data © OpenStreetMap contributors, ODbL (https://www.openstreetmap.org/copyright).
# usage: python3 osm2game.py out.json in.osm [more.osm ...]   (several downloads of neighbouring areas are merged)
import sys, json, math, xml.etree.ElementTree as ET

LAT0, LON0 = 40.17765, 44.51265          # Republic Square
OFFSET = (6000.0, 14000.0)
KX = math.cos(math.radians(LAT0)) * 111320.0 * 10.0
KY = 110540.0 * 10.0
ROADS = {"motorway": 18, "trunk": 16, "primary": 14, "secondary": 12, "tertiary": 10, "unclassified": 7, "residential": 7,
	"living_street": 6, "service": 5, "trunk_link": 8, "primary_link": 8, "secondary_link": 7, "tertiary_link": 7}
WALKS = {"pedestrian": 8, "footway": 3, "steps": 3, "path": 2, "cycleway": 2.5, "corridor": 2}
DEFAULT_LEVELS = {"apartments": 5, "residential": 4, "house": 2, "retail": 2, "commercial": 3, "office": 5, "garages": 1, "garage": 1,
	"roof": 1, "construction": 4, "school": 3, "government": 4, "public": 4, "hotel": 8, "church": 2, "kiosk": 1, "shed": 1, "yes": 3}

def pt(n):
	return [round((float(n.get("lon")) - LON0) * KX + OFFSET[0], 1), round(-(float(n.get("lat")) - LAT0) * KY + OFFSET[1], 1)]

def tags(e):
	return {t.get("k"): t.get("v") for t in e.findall("tag")}

def num(s, default=None):
	try: return float(str(s).replace("m", "").replace(",", ".").split(";")[0].strip())
	except Exception: return default

def area2(p):   # signed area of a closed ring (flat list), for orientation
	a = 0.0
	for i in range(0, len(p) - 2, 2): a += p[i] * p[i + 3] - p[i + 2] * p[i + 1]
	return a / 2

def main(srcs, dst):
	nodes = {}; ways = {}; rels = {}
	for src in srcs:
		root = ET.parse(src).getroot()
		for n in root.findall("node"): nodes[n.get("id")] = n
		for w in root.findall("way"): ways[w.get("id")] = w
		for r in root.findall("relation"): rels[r.get("id")] = r
	def ring(w):
		ids = [nd.get("ref") for nd in w.findall("nd")]
		if any(i not in nodes for i in ids): return None
		return [c for i in ids for c in pt(nodes[i])]
	out = {"buildings": [], "roads": [], "walks": [], "areas": [], "trees": [], "fountains": [], "origin": [LAT0, LON0], "offset": OFFSET,
		"credit": "© OpenStreetMap contributors, ODbL"}
	def add_building(p, t):
		if p is None or len(p) < 8: return
		if p[:2] == p[-2:]: p = p[:-2]
		if area2(p + p[:2]) < 0:   # keep the ring counter-clockwise (in x, y)
			p = [c for i in range(len(p) // 2 - 1, -1, -1) for c in p[i * 2:i * 2 + 2]]
		kind = t.get("building") or t.get("building:part") or "yes"
		lv = num(t.get("building:levels"))
		h = num(t.get("height"))
		if h is None: h = (lv if lv is not None else DEFAULT_LEVELS.get(kind, 3)) * 3.3 + (0.6 if kind != "roof" else 0)
		if lv is None: lv = max(1, round(h / 3.3))
		minh = num(t.get("min_height"), None)
		if minh is None and t.get("building:min_level"): minh = num(t.get("building:min_level"), 0) * 3.3
		if kind == "roof" and minh is None: minh = max(0.0, h - 0.5); h = max(h, 3.5)
		b = {"p": p, "h": round(h, 1), "lv": int(lv), "t": kind}
		if minh: b["min"] = round(minh, 1)
		for k, key in [("n", "name"), ("c", "building:colour"), ("m", "building:material"), ("r", "roof:shape")]:
			if t.get(key): b[k] = t[key]
		if t.get("addr:street"): b["st"] = t["addr:street"] + " " + t.get("addr:housenumber", "")
		out["buildings"].append(b)
	SPECIAL = {"31624086": "rossia"}   # Rossia Mall (the old Rossia cinema)
	for w in ways.values():
		t = tags(w)
		if "building" in t or "building:part" in t:
			if w.get("id") in SPECIAL: t = dict(t); t["building"] = SPECIAL[w.get("id")]
			elif t.get("building") == "theatre" and (num(t.get("height"), 0) > 30 or num(t.get("building:levels"), 0) >= 9): t = dict(t); t["building"] = "opera"   # the Opera house
			add_building(ring(w), t); continue
		p = ring(w)
		if p is None: continue
		hw = t.get("highway")
		if hw in ROADS:
			wd = num(t.get("width")) or (num(t.get("lanes")) * 3.4 if t.get("lanes") else ROADS[hw])
			out["roads"].append({"p": p, "k": hw, "w": round(wd, 1), "n": t.get("name", ""), "one": t.get("oneway") == "yes"})
		elif hw in WALKS:
			if t.get("area") == "yes": out["areas"].append({"p": p, "k": "pedestrian", "n": t.get("name", "")})
			else:
				wk = {"p": p, "k": hw, "w": num(t.get("width")) or WALKS[hw]}
				if t.get("footway") == "crossing" or "crossing" in t: wk["cr"] = True   # a zebra across a street
				if t.get("footway") == "sidewalk": wk["sw"] = True
				out["walks"].append(wk)
		elif t.get("leisure") in ("park", "garden", "playground", "pitch", "swimming_pool") or t.get("landuse") in ("grass", "recreation_ground") or t.get("natural") in ("water", "scrub", "wood"):
			out["areas"].append({"p": p, "k": t.get("leisure") or t.get("landuse") or t.get("natural"), "n": t.get("name", "")})
		elif t.get("place") == "square" or t.get("area:highway") == "pedestrian":
			out["areas"].append({"p": p, "k": "pedestrian", "n": t.get("name", "")})
		elif t.get("amenity") == "fountain":
			out["fountains"].append({"p": p})
		elif t.get("natural") == "tree_row":
			for i in range(0, len(p), 2): out["trees"].append(p[i:i + 2])
	def join_outers(r):   # the outer ways of a multipolygon, joined end to end into closed rings
		segs = []
		for mb in r.findall("member"):
			if mb.get("type") == "way" and mb.get("role") == "outer" and mb.get("ref") in ways:
				ids = [nd.get("ref") for nd in ways[mb.get("ref")].findall("nd")]
				if all(i in nodes for i in ids) and len(ids) > 1: segs.append(ids)
		rings = []
		while segs:
			cur = segs.pop(0)
			changed = True
			while cur[0] != cur[-1] and changed:
				changed = False
				for k, sg in enumerate(segs):
					if sg[0] == cur[-1]: cur = cur + sg[1:]
					elif sg[-1] == cur[-1]: cur = cur + sg[::-1][1:]
					elif sg[-1] == cur[0]: cur = sg + cur[1:]
					elif sg[0] == cur[0]: cur = sg[::-1] + cur[1:]
					else: continue
					segs.pop(k); changed = True; break
			if cur[0] == cur[-1] and len(cur) > 3: rings.append([c for i in cur for c in pt(nodes[i])])
		return rings
	for r in rels.values():
		t = tags(r)
		name = t.get("name", "")
		if "building" not in t: continue
		if t.get("building") == "theatre" and num(t.get("building:levels"), 0) >= 9: t = dict(t); t["building"] = "opera"   # the Opera house
		rgs = join_outers(r)
		for rg in rgs: add_building(rg, t)
	for n in nodes.values():
		t = tags(n)
		if t.get("natural") == "tree": out["trees"].append(pt(n))
		if t.get("amenity") == "fountain": out["fountains"].append({"c": pt(n)})
	json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
	print("buildings", len(out["buildings"]), "roads", len(out["roads"]), "walks", len(out["walks"]), "areas", len(out["areas"]), "trees", len(out["trees"]), "fountains", len(out["fountains"]))

main(sys.argv[2:], sys.argv[1])
