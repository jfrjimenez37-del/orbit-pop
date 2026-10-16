class_name Catalog
## Every cosmetic in the game. `need` = [kind, value]:
##   "best" / "total" -> score goal, "shop" -> product id, "coins" -> coin price.

const SKINS := [
	{"id": "poppy", "name": "POPPY", "need": ["best", 0]},
	{"id": "minty", "name": "MINTY", "need": ["best", 10]},
	{"id": "berry", "name": "BERRY", "need": ["best", 25]},
	{"id": "frosty", "name": "FROSTY", "need": ["total", 250]},
	{"id": "ember", "name": "EMBER", "need": ["best", 50]},
	{"id": "cosmo", "name": "COSMO", "need": ["best", 80]},
	{"id": "goldie", "name": "GOLDIE", "need": ["shop", "star_pack"]},
	{"id": "neon", "name": "NEON", "need": ["shop", "star_pack"]},
	{"id": "panda", "name": "PANDA", "need": ["shop", "star_pack"]},
	{"id": "cookie", "name": "COOKIE", "need": ["coins", 300]},
	{"id": "bubbly", "name": "BUBBLY", "need": ["coins", 500]},
	{"id": "robo", "name": "ROBO", "need": ["coins", 800]},
	{"id": "drake", "name": "DRAKE", "need": ["coins", 1200]},
]

const TRAILS := [
	{"id": "classic", "name": "CLASSIC", "need": ["best", 0]},
	{"id": "sparkle", "name": "SPARKLE", "need": ["coins", 200]},
	{"id": "rainbow", "name": "RAINBOW", "need": ["shop", "trail_pack"]},
	{"id": "hearts", "name": "HEARTS", "need": ["shop", "trail_pack"]},
	{"id": "stars", "name": "STARS", "need": ["shop", "trail_pack"]},
]

## In-run worlds (free, see Stages): top/bottom sky colors, planet sprite, cloud tint, starfield
const WORLDS := [
	{"id": "sky", "name": "SKY", "need": ["best", 0], "top": Color8(70, 152, 255), "bottom": Color8(176, 230, 255), "planet": "planet", "cloud": Color(1, 1, 1), "stars": false},
	{"id": "lagoon", "name": "LAGOON", "need": ["best", 0], "top": Color8(40, 178, 196), "bottom": Color8(170, 250, 230), "planet": "planet", "cloud": Color(0.92, 1, 1), "stars": false},
	{"id": "sunset", "name": "SUNSET", "need": ["best", 0], "top": Color8(255, 118, 112), "bottom": Color8(255, 216, 146), "planet": "planet_violet", "cloud": Color(1, 0.9, 0.94), "stars": false},
	{"id": "candy", "name": "CANDY", "need": ["best", 0], "top": Color8(255, 150, 204), "bottom": Color8(255, 224, 242), "planet": "planet_mint", "cloud": Color(1, 1, 1), "stars": false},
	{"id": "night", "name": "NIGHT", "need": ["best", 0], "top": Color8(34, 44, 116), "bottom": Color8(96, 96, 186), "planet": "planet_gold", "cloud": Color(0.7, 0.74, 0.95, 0.75), "stars": true},
	{"id": "twin", "name": "TWIN", "need": ["best", 0], "top": Color8(112, 70, 190), "bottom": Color8(255, 160, 205), "planet": "planet_mint", "planet2": "planet", "cloud": Color(1, 0.9, 1, 0.9), "stars": true},
	{"id": "trio", "name": "TRIO", "need": ["best", 0], "top": Color8(255, 150, 90), "bottom": Color8(255, 236, 170), "planet": "planet_violet", "planets": ["planet_violet", "planet_mint", "planet"], "cloud": Color(1, 0.95, 0.9), "stars": false},
	{"id": "giants", "name": "GIANTS", "need": ["best", 0], "top": Color8(60, 120, 220), "bottom": Color8(190, 240, 255), "planet": "planet_gold", "planets": ["planet_gold", "planet_mint", "planet_violet"], "cloud": Color(1, 1, 1), "stars": false},
	{"id": "warped", "name": "WARPED", "need": ["best", 0], "top": Color8(26, 20, 70), "bottom": Color8(170, 70, 160), "planet": "planet", "planets": ["planet", "planet_gold", "planet_mint"], "cloud": Color(0.8, 0.7, 1.0, 0.7), "stars": true},
	{"id": "binary", "name": "BINARY", "need": ["best", 0], "top": Color8(16, 92, 120), "bottom": Color8(120, 222, 204), "planet": "planet_gold", "planet2": "planet_violet", "cloud": Color(0.85, 1, 1, 0.85), "stars": true},
]

const CATEGORIES := {"skins": SKINS, "trails": TRAILS, "worlds": WORLDS}  # worlds: not sold


static func items(cat: String) -> Array:
	return CATEGORIES[cat]


static func find(cat: String, id: String) -> int:
	var list: Array = CATEGORIES[cat]
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return 0
