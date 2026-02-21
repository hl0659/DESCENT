class_name SfxGenerator


static func _make_wav(duration: float, callback: Callable) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var sample_count: int = int(44100.0 * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t: float = float(i) / 44100.0
		var sample: float = callback.call(t, duration)
		var value: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	wav.data = data
	return wav


static func shotgun_fire() -> AudioStreamWAV:
	return _make_wav(0.18, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 22.0)
		var bass: float = sin(t * TAU * 65.0)
		var crack: float = sin(t * TAU * 180.0 + sin(t * TAU * 90.0) * 3.0)
		var noise: float = sin(t * 13417.3) * sin(t * 7919.1) * sin(t * 3571.7)
		return (bass * 0.4 + crack * 0.2 + noise * 0.4) * envelope * 0.9
	)


static func smg_fire() -> AudioStreamWAV:
	return _make_wav(0.06, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 50.0)
		var tone: float = sin(t * TAU * 320.0)
		var noise: float = sin(t * 17417.3) * sin(t * 11919.1)
		return (tone * 0.3 + noise * 0.7) * envelope * 0.8
	)


static func shotgun_reload() -> AudioStreamWAV:
	return _make_wav(0.15, func(t: float, _d: float) -> float:
		# Two clicks
		var click1: float = 0.0
		if t < 0.02:
			click1 = sin(t * TAU * 800.0) * exp(-t * 150.0)
		var click2: float = 0.0
		if t > 0.07 and t < 0.1:
			var t2: float = t - 0.07
			click2 = sin(t2 * TAU * 500.0) * exp(-t2 * 120.0)
		return (click1 + click2) * 0.7
	)


static func smg_reload() -> AudioStreamWAV:
	return _make_wav(0.25, func(t: float, _d: float) -> float:
		# Mechanical slide + click
		var slide: float = 0.0
		if t < 0.15:
			var freq: float = 200.0 + t * 2000.0
			slide = sin(t * TAU * freq) * exp(-t * 10.0) * 0.3
		var click: float = 0.0
		if t > 0.18 and t < 0.22:
			var t2: float = t - 0.18
			click = sin(t2 * TAU * 600.0) * exp(-t2 * 100.0) * 0.8
		return slide + click
	)


static func damage_taken() -> AudioStreamWAV:
	return _make_wav(0.15, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 18.0)
		var thud: float = sin(t * TAU * 50.0)
		var crunch: float = sin(t * 5417.0) * sin(t * 3119.0)
		return (thud * 0.6 + crunch * 0.4) * envelope * 0.7
	)


static func enemy_hit() -> AudioStreamWAV:
	return _make_wav(0.08, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 40.0)
		var impact: float = sin(t * TAU * 200.0)
		var squelch: float = sin(t * 9417.0) * sin(t * 6119.0)
		return (impact * 0.4 + squelch * 0.6) * envelope * 0.6
	)


static func jump() -> AudioStreamWAV:
	return _make_wav(0.1, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 30.0)
		# Short breathy whoosh — filtered noise with rising pitch
		var freq: float = 120.0 + t * 800.0
		var whoosh: float = sin(t * TAU * freq) * 0.3
		var air: float = sin(t * 8731.0) * sin(t * 5419.0) * 0.5
		var thump: float = sin(t * TAU * 55.0) * exp(-t * 60.0) * 0.4
		return (whoosh + air + thump) * envelope * 0.5
	)


static func land() -> AudioStreamWAV:
	return _make_wav(0.12, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 25.0)
		# Low thud with gritty texture
		var thud: float = sin(t * TAU * 45.0) * 0.6
		var crunch: float = sin(t * 6317.0) * sin(t * 4213.0) * 0.3
		var slap: float = sin(t * TAU * 160.0) * exp(-t * 50.0) * 0.3
		return (thud + crunch + slap) * envelope * 0.55
	)


static func revolver_fire() -> AudioStreamWAV:
	return _make_wav(0.35, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 10.0)
		# Deep boom — the loudest gun in the game
		var bass: float = sin(t * TAU * 38.0) * 0.5
		var low_mid: float = sin(t * TAU * 85.0 + sin(t * TAU * 42.0) * 2.0) * 0.3
		# Sharp crack on top
		var crack: float = sin(t * TAU * 240.0 + sin(t * TAU * 120.0) * 4.0) * exp(-t * 30.0)
		# Heavy noise tail
		var noise: float = sin(t * 11417.3) * sin(t * 6919.1) * sin(t * 4571.7) * exp(-t * 12.0)
		# Sub-bass thump
		var sub: float = sin(t * TAU * 22.0) * exp(-t * 15.0) * 0.4
		return (bass + low_mid + crack * 0.35 + noise * 0.45 + sub) * envelope * 0.95
	)


static func revolver_reload() -> AudioStreamWAV:
	return _make_wav(0.4, func(t: float, _d: float) -> float:
		# Cylinder open click
		var open_click: float = 0.0
		if t < 0.04:
			open_click = sin(t * TAU * 600.0) * exp(-t * 80.0) * 0.7
		# Cylinder spin (metallic whir)
		var spin: float = 0.0
		if t > 0.08 and t < 0.25:
			var t2: float = t - 0.08
			var freq: float = 300.0 + t2 * 1500.0
			spin = sin(t2 * TAU * freq) * exp(-t2 * 8.0) * 0.25
		# Cylinder close snap — heavy, satisfying
		var close: float = 0.0
		if t > 0.30 and t < 0.38:
			var t3: float = t - 0.30
			close = sin(t3 * TAU * 450.0) * exp(-t3 * 60.0) * 0.8
			close += sin(t3 * TAU * 150.0) * exp(-t3 * 40.0) * 0.4
		return open_click + spin + close
	)


static func enemy_death() -> AudioStreamWAV:
	return _make_wav(0.3, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 8.0)
		var bass: float = sin(t * TAU * 40.0)
		var mid: float = sin(t * TAU * 120.0) * exp(-t * 15.0)
		var noise: float = sin(t * 4417.0) * sin(t * 2719.0) * exp(-t * 20.0)
		return (bass * 0.5 + mid * 0.25 + noise * 0.25) * envelope * 0.7
	)


static func pneuma_pickup() -> AudioStreamWAV:
	# Bright chime, satisfying ping
	return _make_wav(0.15, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 20.0)
		var chime: float = sin(t * TAU * 880.0) * 0.4
		var harmonics: float = sin(t * TAU * 1320.0) * 0.25
		var ping: float = sin(t * TAU * 1760.0) * exp(-t * 40.0) * 0.3
		return (chime + harmonics + ping) * envelope * 0.65
	)


static func pneuma_denied() -> AudioStreamWAV:
	# Dull buzz/error tone
	return _make_wav(0.2, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 12.0)
		var buzz: float = sin(t * TAU * 90.0)
		var grit: float = sin(t * TAU * 90.0 * 3.0) * 0.3
		return (buzz * 0.6 + grit) * envelope * 0.5
	)


static func pneuma_low_loop() -> AudioStreamWAV:
	# Subtle heartbeat/breathing pulse — short loop
	var wav: AudioStreamWAV = _make_wav(0.8, func(t: float, _d: float) -> float:
		# Double-beat heartbeat pattern
		var beat1: float = sin(t * TAU * 45.0) * exp(-pow((t - 0.1), 2.0) * 800.0)
		var beat2: float = sin(t * TAU * 40.0) * exp(-pow((t - 0.28), 2.0) * 800.0)
		return (beat1 + beat2) * 0.35
	)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = int(44100.0 * 0.8)
	return wav


static func pneuma_empty() -> AudioStreamWAV:
	# Hollow empty sound on attempted action
	return _make_wav(0.25, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 10.0)
		var hollow: float = sin(t * TAU * 65.0) * 0.4
		var rattle: float = sin(t * 3417.0) * sin(t * 1719.0) * exp(-t * 25.0)
		return (hollow + rattle * 0.3) * envelope * 0.4
	)


static func dash_whoosh() -> AudioStreamWAV:
	# Whoosh + subtle resource spend
	return _make_wav(0.18, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 15.0)
		var freq: float = 200.0 + t * 1200.0
		var whoosh: float = sin(t * TAU * freq) * 0.3
		var air: float = sin(t * 9731.0) * sin(t * 6419.0) * 0.5
		var spend: float = sin(t * TAU * 300.0) * exp(-t * 40.0) * 0.2
		return (whoosh + air + spend) * envelope * 0.55
	)


static func double_jump_burst() -> AudioStreamWAV:
	# Air burst + subtle spend
	return _make_wav(0.12, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 28.0)
		var burst: float = sin(t * TAU * (200.0 + t * 600.0)) * 0.35
		var air: float = sin(t * 7731.0) * sin(t * 4419.0) * 0.45
		var pop: float = sin(t * TAU * 400.0) * exp(-t * 60.0) * 0.3
		return (burst + air + pop) * envelope * 0.5
	)


static func wave_spawn_horn() -> AudioStreamWAV:
	# Warning horn when a new enemy wave spawns
	return _make_wav(0.6, func(t: float, _d: float) -> float:
		var envelope: float = 0.0
		if t < 0.05:
			envelope = t / 0.05
		elif t < 0.4:
			envelope = 1.0
		else:
			envelope = 1.0 - (t - 0.4) / 0.2
		envelope = clampf(envelope, 0.0, 1.0)
		var base: float = sin(t * TAU * 180.0)
		var overtone: float = sin(t * TAU * 360.0) * 0.3
		var grit: float = sin(t * TAU * 540.0) * 0.15
		return (base + overtone + grit) * envelope * 0.6
	)


static func wall_break() -> AudioStreamWAV:
	return _make_wav(0.25, func(t: float, _d: float) -> float:
		var envelope: float = exp(-t * 8.0)
		var bass: float = sin(t * TAU * 40.0)
		var crack: float = sin(t * TAU * 200.0 + sin(t * TAU * 80.0) * 4.0) * exp(-t * 30.0)
		var debris: float = sin(t * 8417.0) * sin(t * 5119.0) * sin(t * 2371.0)
		return (bass * 0.3 + crack * 0.3 + debris * 0.4) * envelope * 0.8
	)
