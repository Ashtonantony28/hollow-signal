extends Node
## Procedural audio. Every sound effect and the ambient music loop is synthesised into an
## AudioStreamWAV at startup — no audio files ship with the game.

const RATE := 22050

var bank: Dictionary = {}
var _players2d: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_hi: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()

## Each recipe: [duration, generator callable name, params]
const RECIPES := {
	"rivet": {"dur": 0.16, "kind": "shot", "freq": 520.0, "noise": 0.55, "decay": 28.0},
	"hammer": {"dur": 0.4, "kind": "shot", "freq": 180.0, "noise": 0.75, "decay": 11.0},
	"needle": {"dur": 0.09, "kind": "shot", "freq": 760.0, "noise": 0.5, "decay": 40.0},
	"carbine": {"dur": 0.14, "kind": "shot", "freq": 380.0, "noise": 0.65, "decay": 26.0},
	"longwire": {"dur": 0.6, "kind": "zap", "freq": 240.0, "noise": 0.6, "decay": 6.0},
	"hailstorm": {"dur": 0.12, "kind": "shot", "freq": 300.0, "noise": 0.7, "decay": 30.0},
	"scatter": {"dur": 0.32, "kind": "shot", "freq": 140.0, "noise": 0.9, "decay": 13.0},
	"lance": {"dur": 0.45, "kind": "zap", "freq": 880.0, "noise": 0.15, "decay": 7.0},
	"lance_charge": {"dur": 0.8, "kind": "rise", "freq": 200.0, "noise": 0.05, "decay": 0.5},
	"launcher": {"dur": 0.3, "kind": "thump", "freq": 90.0, "noise": 0.4, "decay": 12.0},
	"explosion": {"dur": 0.9, "kind": "boom", "freq": 55.0, "noise": 1.0, "decay": 5.0},
	"hit": {"dur": 0.06, "kind": "tone", "freq": 1500.0, "noise": 0.1, "decay": 60.0},
	"hit_match": {"dur": 0.09, "kind": "tone", "freq": 2200.0, "noise": 0.05, "decay": 40.0},
	"shield_break": {"dur": 0.35, "kind": "shatter", "freq": 1800.0, "noise": 0.7, "decay": 10.0},
	"kill": {"dur": 0.18, "kind": "chirp", "freq": 900.0, "noise": 0.0, "decay": 14.0},
	"enemy_shot": {"dur": 0.22, "kind": "zap", "freq": 330.0, "noise": 0.4, "decay": 16.0},
	"telegraph": {"dur": 0.5, "kind": "rise", "freq": 600.0, "noise": 0.0, "decay": 0.5},
	"tick_bite": {"dur": 0.12, "kind": "shot", "freq": 260.0, "noise": 0.8, "decay": 30.0},
	"glob": {"dur": 0.4, "kind": "thump", "freq": 70.0, "noise": 0.5, "decay": 8.0},
	"hurt": {"dur": 0.2, "kind": "thump", "freq": 110.0, "noise": 0.6, "decay": 18.0},
	"pickup": {"dur": 0.2, "kind": "chirp", "freq": 660.0, "noise": 0.0, "decay": 10.0},
	"retune": {"dur": 0.14, "kind": "chirp", "freq": 440.0, "noise": 0.0, "decay": 16.0},
	"pulse": {"dur": 1.0, "kind": "sweep", "freq": 1200.0, "noise": 0.2, "decay": 3.5},
	"reload": {"dur": 0.25, "kind": "click", "freq": 1200.0, "noise": 0.6, "decay": 40.0},
	"empty": {"dur": 0.05, "kind": "click", "freq": 900.0, "noise": 0.3, "decay": 80.0},
	"step": {"dur": 0.07, "kind": "thump", "freq": 80.0, "noise": 0.7, "decay": 45.0},
	"jump": {"dur": 0.12, "kind": "thump", "freq": 140.0, "noise": 0.5, "decay": 30.0},
	"uplink_tick": {"dur": 0.15, "kind": "tone", "freq": 740.0, "noise": 0.0, "decay": 20.0},
	"objective": {"dur": 0.7, "kind": "arp", "freq": 440.0, "noise": 0.0, "decay": 3.0},
	"lift": {"dur": 1.2, "kind": "sweep", "freq": 200.0, "noise": 0.3, "decay": 1.5},
	"death": {"dur": 1.4, "kind": "boom", "freq": 40.0, "noise": 0.8, "decay": 2.5},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1337
	for key in RECIPES:
		bank[key] = make_sound(RECIPES[key])
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players2d.append(p)

## Builds a PCM16 mono stream from a recipe. Pure function of the recipe + internal seed.
func make_sound(r: Dictionary) -> AudioStreamWAV:
	var dur: float = r.dur
	var decay: float = r.decay
	var noise_amt: float = r.noise
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	var kind: String = r.kind
	var f0: float = r.freq
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		var env := exp(-t * decay)
		var f := f0
		match kind:
			"shot": f = f0 * (1.0 - 0.6 * u)
			"zap": f = f0 * (1.0 - 0.8 * u)
			"rise": f = f0 * (1.0 + 2.0 * u); env = minf(1.0, u * 4.0) * (1.0 - u)
			"thump": f = f0 * (1.0 - 0.5 * u)
			"boom": f = f0 * (1.0 - 0.4 * u)
			"chirp": f = f0 * (1.0 + 1.0 * u)
			"sweep": f = f0 * (1.0 - 0.85 * u)
			"shatter": f = f0 * (1.0 + 0.5 * sin(t * 90.0))
			"arp": f = f0 * [1.0, 1.25, 1.5, 2.0][mini(int(u * 4.0), 3)]
			"click": f = f0
		phase += TAU * f / RATE
		var tone := sin(phase)
		if kind in ["zap", "shot"]:
			tone = signf(tone) * 0.6 + tone * 0.4
		var noise := _rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.35 if kind != "boom" else 0.08)
		var s: float = (tone * (1.0 - noise_amt) + lp * noise_amt) * env
		s = clampf(s * 0.8, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

## Ambient generative drone: two detuned oscillators + slow filtered noise, seamless loop.
func make_drone(seconds: float, base: float, bright: float) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var lfo := 0.5 + 0.5 * sin(TAU * t / seconds)
		var s := sin(TAU * base * t) * 0.35
		s += sin(TAU * base * 1.5 * t + sin(TAU * t / seconds * 2.0)) * 0.18 * lfo
		s += sin(TAU * base * 2.0 * t) * 0.1 * bright
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.02)
		s += lp * 0.5
		data.encode_s16(i * 2, int(clampf(s * 0.5, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w

func start_music() -> void:
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.stream = make_drone(8.0, 55.0, 0.2)
		_music.volume_db = -14.0
		add_child(_music)
		_music_hi = AudioStreamPlayer.new()
		_music_hi.stream = make_drone(4.0, 110.0, 1.0)
		_music_hi.volume_db = -60.0
		add_child(_music_hi)
	if not _music.playing:
		_music.play()
		_music_hi.play()

## Intensity 0..1 fades in the brighter combat layer.
func set_intensity(v: float) -> void:
	if _music_hi:
		_music_hi.volume_db = lerpf(-40.0, -12.0, clampf(v, 0.0, 1.0))

func play(name: StringName, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not bank.has(name):
		return
	for p in _players2d:
		if not p.playing:
			p.stream = bank[name]
			p.volume_db = vol_db
			p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
			p.play()
			return

func play_at(name: StringName, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not bank.has(name):
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = bank[name]
	p.volume_db = vol_db
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
