class_name ThemeData
## Visual + spawn theme per deck (DESIGN.md §6.1).

const DECKS := [
	{"name": "Intake", "floor": Color(0.22, 0.23, 0.26), "wall": Color(0.33, 0.35, 0.39),
		"trim": Color(0.95, 0.55, 0.15), "fog": Color(0.05, 0.06, 0.09), "light": Color(1.0, 0.82, 0.6),
		"ambient": Color(0.35, 0.38, 0.45), "rooms": 11, "size": 34},
	{"name": "Cisterns", "floor": Color(0.16, 0.22, 0.22), "wall": Color(0.24, 0.32, 0.33),
		"trim": Color(0.2, 0.9, 0.8), "fog": Color(0.03, 0.07, 0.08), "light": Color(0.6, 0.95, 1.0),
		"ambient": Color(0.28, 0.4, 0.42), "rooms": 13, "size": 38},
	{"name": "Foundry", "floor": Color(0.24, 0.18, 0.15), "wall": Color(0.36, 0.27, 0.22),
		"trim": Color(1.0, 0.35, 0.1), "fog": Color(0.09, 0.04, 0.03), "light": Color(1.0, 0.6, 0.35),
		"ambient": Color(0.45, 0.32, 0.28), "rooms": 14, "size": 40},
	{"name": "Archive", "floor": Color(0.18, 0.17, 0.24), "wall": Color(0.28, 0.27, 0.37),
		"trim": Color(0.65, 0.4, 1.0), "fog": Color(0.05, 0.04, 0.09), "light": Color(0.8, 0.75, 1.0),
		"ambient": Color(0.36, 0.34, 0.48), "rooms": 16, "size": 42},
	{"name": "Spire", "floor": Color(0.13, 0.13, 0.15), "wall": Color(0.22, 0.22, 0.26),
		"trim": Color(1.0, 0.2, 0.35), "fog": Color(0.07, 0.02, 0.04), "light": Color(1.0, 0.7, 0.75),
		"ambient": Color(0.38, 0.3, 0.34), "rooms": 12, "size": 38},
]

const BAND_COLORS := [Color(1.0, 0.62, 0.1), Color(0.15, 0.95, 0.85), Color(0.7, 0.35, 1.0)]
const BAND_NAMES := ["LOW", "MID", "HIGH"]

static func deck(i: int) -> Dictionary:
	return DECKS[clampi(i, 0, DECKS.size() - 1)]
