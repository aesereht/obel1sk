extends Node2D

var played_end = false

var last_progress := 0.0
var defaultVolume = 0

func _ready() -> void:
	defaultVolume = $FillSFX.volume_db

func _process(delta: float) -> void:
	$FillSFX.stream_paused = GameWorld.paused

func set_progress(progress:float):
	var frame = clamp(floor((20) * progress), 0, 20)
	$Fill.frame = int(frame)
	
	$Border.playing = progress == 1.0
	$Border.visible = progress == 1.0
	
	if progress <= 0.05 or progress >= 1.0:
		$FillSFX.playing = false
	else:
		if not $FillSFX.playing:
			$FillSFX.play()
		
		
		var grow_speed = progress - last_progress # slight pitch shift if moving slower
		if grow_speed != 0:
			$FillSFX.pitch_scale = 1.0 + progress - clamp((1.0 / grow_speed) * 0.001, 0, 1)
		
		if progress == last_progress:
			$FillSFX.volume_db = defaultVolume - 10
		else:
			$FillSFX.volume_db = defaultVolume
	
	if progress >= 1.0 and not $EndSFX.playing and not played_end:
		$EndSFX.play()
		played_end = true
	if progress <0.5:
		played_end = false
	
	last_progress = progress
