## The Song as something the player plays: its bars as data, a synth that
## sounds them, and a scorer that turns a performance into one quality.
##
## GDD §16a "Challenge and mastery: the Song as a skill": hold, slide and
## release along a string; "accuracy is shown in the world, never as a
## number". GDD §10 "Music": Tulu's three notes (G4 A4 C5) are the first
## three notes of the Song, so they are the first three events of bar one in
## data/song.json. Everything a bar is — its notes, the flag a lesson sets,
## the journey line, the four strings' tuning, the bands of Sarang's answer
## — is data there. The quality computed here drives effects and is never
## printed; nothing in this file formats a number for the screen.
##
## PLACEHOLDER sound: soft sine-and-triangle plucks from an
## AudioStreamGenerator. Replaced by the recorded veena of GDD §10.
class_name Song
extends RefCounted

const PATH := "res://data/song.json"
const MIX_RATE := 22050.0
## Latency against dropouts: the generator keeps this much sound queued.
const BUFFER_SECONDS := 0.08
const MAX_VOICES := 4
## Scoring, in seconds and semitones: inside the slack a note is perfect,
## past slack plus window it counts for nothing, in between it fades.
const MATCH_WINDOW := 0.7
const TIMING_SLACK := 0.08
const TIMING_WINDOW := 0.5
const PITCH_SLACK := 0.5
const PITCH_WINDOW := 2.5
const HOLD_SLACK := 0.15
const HOLD_WINDOW := 0.6
const WEIGHT_TIMING := 0.45
const WEIGHT_PITCH := 0.4
const WEIGHT_HOLD := 0.15
## The pluck's envelope, in seconds, and how fast a slide reaches its pitch.
const ATTACK := 0.004
const DECAY := 0.5
const SUSTAIN := 0.3
const RELEASE := 0.09
const GLIDE := 0.02
const GAIN := 0.42
const DEFAULT_ROOT_HZ := 392.0

static var _data: Dictionary = {}
static var _loaded := false

var _playback: AudioStreamGeneratorPlayback = null
var _voices: Dictionary = {}
var _quality := 0.0


## One sounding string.
class Voice:
	var pitch := 0.0
	var target := 0.0
	var phase := 0.0
	var env := 0.0
	var held := true
	var peaked := false


# -- data ---------------------------------------------------------------------


## The whole table, read once. A missing or malformed file is an error and an
## empty table, never a crash.
static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = Strings.read_json_file(PATH)
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("Song: %s did not load" % PATH)
	return _data


## The open pitch of each string, lowest first, in semitones from the root.
static func tuning() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for value in data().get("tuning", []):
		out.append(float(value))
	if out.is_empty():
		out.append(0.0)
	return out


## The bars in the order they are taught.
static func lesson() -> PackedStringArray:
	var out := PackedStringArray()
	for value in data().get("lesson", []):
		out.append(str(value))
	return out


static func bar(bar_id: String) -> Dictionary:
	var bars: Variant = data().get("bars", {})
	if bars is Dictionary and bars.get(bar_id) is Dictionary:
		return bars[bar_id]
	return {}


## The bar's note events as {time, pitch, hold} in seconds and semitones,
## in time order.
static func notes(bar_id: String) -> Array:
	var out: Array = []
	for raw in bar(bar_id).get("notes", []):
		if raw is Dictionary:
			(
				out
				. append(
					{
						"time": float(raw.get("time", 0.0)),
						"pitch": float(raw.get("pitch", 0.0)),
						"hold": float(raw.get("hold", 0.5)),
					}
				)
			)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	return out


## Seconds from the bar's first onset to the end of its last hold.
static func bar_length(bar_id: String) -> float:
	var length := 0.0
	for note in notes(bar_id):
		length = maxf(length, note["time"] + note["hold"])
	return length


## The answer band a quality falls in: {text_id, top}. `top` is true for the
## fullest band, so the world knows when to answer with everything it has.
static func answer(quality: float) -> Dictionary:
	var bands: Array = data().get("answers", [])
	for index in bands.size():
		var band: Variant = bands[index]
		if band is Dictionary and quality < float(band.get("below", 1.01)):
			return {"text_id": str(band.get("text_id", "")), "top": index == bands.size() - 1}
	return {"text_id": "", "top": false}


static func hz(pitch: float) -> float:
	return float(data().get("root_hz", DEFAULT_ROOT_HZ)) * pow(2.0, pitch / 12.0)


## The string a pitch is played from: the highest open string at or below
## it (a note between strings is a bend up from the one below).
static func string_for(pitch: float) -> int:
	var strings := tuning()
	var best := 0
	for index in strings.size():
		if strings[index] <= pitch + 0.001:
			best = index
	return best


# -- synth --------------------------------------------------------------------


## The stream an AudioStreamPlayer plays; bind() its playback once playing.
func make_stream() -> AudioStreamGenerator:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_SECONDS
	return stream


func bind(playback: AudioStreamGeneratorPlayback) -> void:
	_playback = playback


## Starts a string sounding at [param pitch] under [param voice_id]; a
## second note_on on the same id plucks it again.
func note_on(voice_id: int, pitch: float) -> void:
	var voice := Voice.new()
	voice.pitch = pitch
	voice.target = pitch
	if _voices.size() >= MAX_VOICES and not _voices.has(voice_id):
		_voices.erase(_voices.keys()[0])
	_voices[voice_id] = voice


## Slides a sounding string toward [param pitch].
func set_pitch(voice_id: int, pitch: float) -> void:
	if _voices.has(voice_id):
		_voices[voice_id].target = pitch


func note_off(voice_id: int) -> void:
	if _voices.has(voice_id):
		_voices[voice_id].held = false


func all_off() -> void:
	for voice_id in _voices:
		_voices[voice_id].held = false


## Fills whatever room the playback has. Call every frame while a player is
## playing the stream; returns how many frames were written.
func render() -> int:
	if _playback == null:
		return 0
	var frames := mini(_playback.get_frames_available(), int(MIX_RATE * BUFFER_SECONDS))
	if frames <= 0:
		return 0
	var mono := PackedFloat32Array()
	mono.resize(frames)
	mono.fill(0.0)
	for voice_id in _voices.keys():
		if _mix_voice(_voices[voice_id], mono):
			_voices.erase(voice_id)
	var out := PackedVector2Array()
	out.resize(frames)
	for i in frames:
		var sample := clampf(mono[i] * GAIN, -1.0, 1.0)
		out[i] = Vector2(sample, sample)
	_playback.push_buffer(out)
	return frames


## Adds one voice's samples into [param mono]; true once it has died away.
func _mix_voice(voice: Voice, mono: PackedFloat32Array) -> bool:
	var root := float(data().get("root_hz", DEFAULT_ROOT_HZ))
	var attack_step := 1.0 / (ATTACK * MIX_RATE)
	var decay_k := 1.0 / (DECAY * MIX_RATE)
	var release_k := exp(-1.0 / (RELEASE * MIX_RATE))
	var glide_k := 1.0 / (GLIDE * MIX_RATE)
	for i in mono.size():
		voice.pitch += (voice.target - voice.pitch) * glide_k
		voice.phase = fposmod(voice.phase + root * pow(2.0, voice.pitch / 12.0) / MIX_RATE, 1.0)
		if not voice.held:
			voice.env *= release_k
		elif voice.peaked:
			voice.env += (SUSTAIN - voice.env) * decay_k
		else:
			voice.env = minf(1.0, voice.env + attack_step)
			voice.peaked = voice.env >= 1.0
		var tri := 2.0 * absf(2.0 * voice.phase - 1.0) - 1.0
		var sine := sin(TAU * voice.phase)
		var bright := sin(2.0 * TAU * voice.phase) * voice.env
		mono[i] += (0.6 * sine + 0.25 * tri + 0.15 * bright) * voice.env
	return not voice.held and voice.env < 0.0005


# -- scoring ------------------------------------------------------------------


## Scores [param played] ({time, pitch, hold} each) against the bar and
## remembers the result. Returns it, 0–1.
func score(bar_id: String, played: Array) -> float:
	_quality = score_against(notes(bar_id), played)
	return _quality


## The last performance's quality, 0–1. Drives effects; never shown.
func quality() -> float:
	return _quality


## Timing, pitch and hold error against [param targets]: 1.0 for a
## performance that lands every onset, pitch and hold, 0.0 for silence. Both
## sets are read relative to their own first onset, so a performance is
## judged on its rhythm, not on when the player found the nerve to begin.
static func score_against(targets: Array, played: Array) -> float:
	if targets.is_empty() or played.is_empty():
		return 0.0
	var wanted := _relative(targets)
	var got := _relative(played)
	var used: Dictionary = {}
	var total := 0.0
	for target in wanted:
		var best := -1
		var best_dt := INF
		for index in got.size():
			if used.has(index):
				continue
			var dt: float = absf(got[index]["time"] - target["time"])
			if dt < best_dt:
				best_dt = dt
				best = index
		if best < 0 or best_dt > MATCH_WINDOW:
			continue
		used[best] = true
		var note: Dictionary = got[best]
		var pitch_error: float = absf(note["pitch"] - target["pitch"])
		var hold_error: float = absf(note["hold"] - target["hold"])
		total += (
			WEIGHT_TIMING * _closeness(best_dt, TIMING_SLACK, TIMING_WINDOW)
			+ WEIGHT_PITCH * _closeness(pitch_error, PITCH_SLACK, PITCH_WINDOW)
			+ WEIGHT_HOLD * _closeness(hold_error, HOLD_SLACK, HOLD_WINDOW)
		)
	var extra := maxi(0, got.size() - wanted.size())
	var crowding := float(wanted.size()) / float(wanted.size() + extra)
	return clampf(total / wanted.size() * crowding, 0.0, 1.0)


## 1 inside the slack, 0 past slack plus window, linear between.
static func _closeness(error: float, slack: float, window: float) -> float:
	return 1.0 - clampf((error - slack) / window, 0.0, 1.0)


## Copies of the notes in time order with the first onset at zero.
static func _relative(notes_in: Array) -> Array:
	var out: Array = []
	for note in notes_in:
		if note is Dictionary:
			(
				out
				. append(
					{
						"time": float(note.get("time", 0.0)),
						"pitch": float(note.get("pitch", 0.0)),
						"hold": float(note.get("hold", 0.0)),
					}
				)
			)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	if not out.is_empty():
		var first: float = out[0]["time"]
		for note in out:
			note["time"] -= first
	return out
