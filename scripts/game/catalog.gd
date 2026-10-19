class_name Catalog
## Every cosmetic in the game. `need` = [kind, value]:
##   "best" / "total" -> score goal, "world" -> world number reached, "level" -> player level,
##   "shop" -> product id, "coins" -> coin price.

## Rarity tiers (ordered). Skins are listed by rarity; "fx" = particle effect around the critter.
const RARITIES := ["common", "rare", "epic", "legendary", "mythic"]
const RARITY_COLORS := {"common": Color8(150, 160, 186), "rare": Color8(70, 150, 255), "epic": Color8(176, 90, 255),
	"legendary": Color8(255, 170, 30), "mythic": Color8(255, 70, 150)}

## need: "best"/"total" score, "world" = reach that world number, "coins" price, "shop" product.
## color: trail/burst tint. fx: [kind, Color] drawn by OrbitPlayer.
const SKINS := [
	{"id": "poppy", "name": "POPPY", "rarity": "common", "need": ["best", 0], "color": Color8(255, 212, 60)},
	{"id": "minty", "name": "MINTY", "rarity": "common", "need": ["best", 15], "color": Color8(110, 230, 160)},
	{"id": "berry", "name": "BERRY", "rarity": "common", "need": ["best", 40], "color": Color8(255, 128, 178)},
	{"id": "cookie", "name": "COOKIE", "rarity": "common", "need": ["coins", 600], "color": Color8(230, 172, 108)},
	{"id": "melony", "name": "MELONY", "rarity": "common", "need": ["coins", 900], "color": Color8(124, 204, 96)},
	{"id": "frosty", "name": "FROSTY", "rarity": "rare", "need": ["world", 3], "color": Color8(172, 226, 255)},
	{"id": "ember", "name": "EMBER", "rarity": "rare", "need": ["world", 4], "color": Color8(255, 122, 58)},
	{"id": "volt", "name": "VOLT", "rarity": "rare", "need": ["world", 5], "color": Color8(255, 214, 40), "fx": ["bolt", Color8(255, 240, 120)]},
	{"id": "pixel", "name": "PIXEL", "rarity": "rare", "need": ["total", 2500], "color": Color8(240, 96, 140)},
	{"id": "bubbly", "name": "BUBBLY", "rarity": "rare", "need": ["coins", 1500], "color": Color8(255, 172, 232)},
	{"id": "robo", "name": "ROBO", "rarity": "rare", "need": ["coins", 2200], "color": Color8(190, 202, 220)},
	{"id": "panda", "name": "PANDA", "rarity": "rare", "need": ["shop", "star_pack"], "color": Color8(246, 246, 252)},
	{"id": "ghosty", "name": "GHOSTY", "rarity": "epic", "need": ["world", 6], "color": Color8(196, 160, 255), "fx": ["wisp", Color8(190, 150, 255)]},
	{"id": "alien", "name": "ALIEN", "rarity": "epic", "need": ["world", 7], "color": Color8(110, 220, 110), "fx": ["sparkle", Color8(170, 255, 140)]},
	{"id": "crystal", "name": "CRYSTAL", "rarity": "epic", "need": ["world", 8], "color": Color8(150, 220, 255), "fx": ["sparkle", Color8(200, 245, 255)]},
	{"id": "cosmo", "name": "COSMO", "rarity": "epic", "need": ["best", 250], "color": Color8(150, 112, 236), "fx": ["stars", Color8(255, 226, 90)]},
	{"id": "ninja", "name": "NINJA", "rarity": "epic", "need": ["coins", 4000], "color": Color8(232, 52, 64), "fx": ["sparkle", Color8(255, 90, 100)]},
	{"id": "drake", "name": "DRAKE", "rarity": "epic", "need": ["coins", 5500], "color": Color8(112, 204, 92), "fx": ["embers", Color8(170, 255, 110)]},
	{"id": "neon", "name": "NEON", "rarity": "epic", "need": ["shop", "star_pack"], "color": Color8(64, 232, 226), "fx": ["sparkle", Color8(255, 90, 210)]},
	{"id": "magma", "name": "MAGMA", "rarity": "legendary", "need": ["world", 9], "color": Color8(255, 120, 40), "fx": ["embers", Color8(255, 170, 50)]},
	{"id": "royal", "name": "ROYAL", "rarity": "legendary", "need": ["world", 10], "color": Color8(176, 100, 232), "fx": ["aura", Color8(255, 214, 70)]},
	{"id": "skully", "name": "SKULLY", "rarity": "legendary", "need": ["coins", 9000], "color": Color8(238, 232, 216), "fx": ["aura", Color8(200, 190, 255)]},
	{"id": "prism", "name": "PRISM", "rarity": "legendary", "need": ["coins", 15000], "color": Color8(255, 255, 255), "fx": ["rainbow", Color.WHITE]},
	{"id": "goldie", "name": "GOLDIE", "rarity": "legendary", "need": ["shop", "star_pack"], "color": Color8(255, 204, 44), "fx": ["aura", Color8(255, 230, 110)]},
	{"id": "nova", "name": "NOVA", "rarity": "mythic", "need": ["best", 500], "color": Color8(255, 214, 60), "fx": ["nova", Color8(255, 220, 90)]},
	{"id": "omega", "name": "OMEGA", "rarity": "mythic", "need": ["best", 1000], "color": Color8(170, 110, 255), "fx": ["omega", Color.WHITE]},
]
## Old saves stored the skin as an index into this original order.
const LEGACY_SKINS := ["poppy", "minty", "berry", "frosty", "ember", "cosmo", "goldie", "neon", "panda", "cookie", "bubbly", "robo", "drake"]

## Trails by rarity. style: how OrbitPlayer draws it (see _draw_trail), cols: palette.
const TRAILS := [
	{"id": "classic", "name": "CLASSIC", "rarity": "common", "need": ["best", 0], "style": "squares", "cols": []},
	{"id": "dots", "name": "DOTS", "rarity": "common", "need": ["level", 3], "style": "dots", "cols": [Color8(255, 255, 255), Color8(140, 230, 255)]},
	{"id": "dash", "name": "DASH", "rarity": "common", "need": ["coins", 300], "style": "dash", "cols": [Color8(255, 230, 90), Color8(255, 255, 255)]},
	{"id": "sparkle", "name": "SPARKLE", "rarity": "rare", "need": ["coins", 800], "style": "sparkle", "cols": [Color8(255, 255, 255), Color8(255, 240, 140)]},
	{"id": "bubbles", "name": "BUBBLES", "rarity": "rare", "need": ["world", 3], "style": "rings", "cols": [Color8(170, 230, 255), Color8(255, 255, 255)]},
	{"id": "leaves", "name": "LEAVES", "rarity": "rare", "need": ["level", 5], "style": "leaves", "cols": [Color8(120, 220, 90), Color8(70, 170, 70)]},
	{"id": "pixel", "name": "PIXEL", "rarity": "rare", "need": ["coins", 1500], "style": "checker", "cols": [Color8(255, 110, 160), Color8(255, 255, 255)]},
	{"id": "hearts", "name": "HEARTS", "rarity": "rare", "need": ["shop", "trail_pack"], "style": "hearts", "cols": [Color8(255, 100, 150), Color8(255, 170, 200)]},
	{"id": "smoke", "name": "SMOKE", "rarity": "rare", "need": ["level", 10], "style": "smoke", "cols": [Color8(220, 220, 236), Color8(170, 170, 196)]},
	{"id": "fire", "name": "FIRE", "rarity": "epic", "need": ["world", 5], "style": "fire", "cols": [Color8(255, 230, 80), Color8(255, 140, 40), Color8(230, 60, 40)]},
	{"id": "ice", "name": "ICE", "rarity": "epic", "need": ["world", 6], "style": "crystals", "cols": [Color8(200, 245, 255), Color8(120, 200, 255)]},
	{"id": "bolt", "name": "BOLT", "rarity": "epic", "need": ["level", 15], "style": "bolt", "cols": [Color8(255, 240, 110), Color8(255, 255, 255)]},
	{"id": "notes", "name": "NOTES", "rarity": "epic", "need": ["coins", 3000], "style": "notes", "cols": [Color8(200, 140, 255), Color8(255, 140, 220)]},
	{"id": "stars", "name": "STARS", "rarity": "epic", "need": ["shop", "trail_pack"], "style": "stars", "cols": [Color8(255, 220, 60), Color8(255, 250, 200)]},
	{"id": "neon", "name": "NEON", "rarity": "epic", "need": ["level", 20], "style": "neon", "cols": [Color8(60, 240, 255), Color8(255, 70, 220)]},
	{"id": "rainbow", "name": "RAINBOW", "rarity": "legendary", "need": ["shop", "trail_pack"], "style": "rainbow", "cols": []},
	{"id": "galaxy", "name": "GALAXY", "rarity": "legendary", "need": ["world", 8], "style": "galaxy", "cols": [Color8(150, 100, 255), Color8(80, 120, 255), Color8(255, 255, 255)]},
	{"id": "comet", "name": "COMET", "rarity": "legendary", "need": ["level", 30], "style": "comet", "cols": [Color8(255, 255, 255), Color8(140, 210, 255), Color8(80, 120, 255)]},
	{"id": "gold", "name": "GOLD", "rarity": "legendary", "need": ["coins", 8000], "style": "coins", "cols": [Color8(255, 206, 50), Color8(255, 250, 200)]},
	{"id": "aurora", "name": "AURORA", "rarity": "mythic", "need": ["level", 50], "style": "aurora", "cols": []},
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


static func skin_index(id) -> int:
	if id is String:
		return find("skins", id)
	var i := int(id)
	return find("skins", LEGACY_SKINS[i]) if i >= 0 and i < LEGACY_SKINS.size() else 0


static func find(cat: String, id: String) -> int:
	var list: Array = CATEGORIES[cat]
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return 0
