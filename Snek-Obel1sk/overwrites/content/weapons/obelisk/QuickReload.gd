extends Node2D


var min_bound := 0.0
var max_bound := 0.0

var bar_length := 0
var progress = 0.0
var startVol = 0.0

func init(minBound:float, maxBound:float):
	bar_length = $QuickReloadBar.texture.get_size().x - 6
	
	min_bound = minBound
	max_bound = maxBound
	
	$MinBound.position.x = position_on_slider(min_bound)
	$MaxBound.position.x = position_on_slider(max_bound)
	$MinBound.visible = min_bound != max_bound
	$MaxBound.visible = min_bound != max_bound
	$Line2D.visible = min_bound != max_bound
	
	$Line2D.clear_points()
	$Line2D.add_point(Vector2($MinBound.position.x, 0))
	$Line2D.add_point(Vector2($MaxBound.position.x, 0))
	
	show_progress(0.0)
	startVol = $Sound.volume_db
	
	Style.init(self)

func _process(delta: float) -> void:
	if progress >= get_progress_pos_min() and progress <= get_progress_pos_max() and visible:
		if not $Sound.playing:
			$Sound.volume_db = lerp($Sound.volume_db, startVol, 0.15)
			$Sound.play()
	else:
		$Sound.volume_db = lerp($Sound.volume_db, startVol - 6, 0.15)
		if $Sound.volume_db < startVol - 5.5:
			$Sound.stop()

func show_progress(progress: float):
	$SliderSprite.position.x = position_on_slider(progress, false)
	self.progress = progress

func position_on_slider(progress:float, _round:= true):
	var result = progress * bar_length
	result -= bar_length * 0.5
	if _round:
		result = round(result)
	return result

func set_visible(value:bool):
	if Data.of("obel1sk.adStyle") == 1:
		value = false
	
	if Data.of("obel1sk.maxQuickReloadWindow") <= 0.0 or Data.of("obel1sk.maxQuickReload") == Data.of("obel1sk.minQuickReload"):
		$MinBound.visible = false
		$MaxBound.visible = false
		$Line2D.visible = false
	else:
		$MinBound.visible = value
		$MaxBound.visible = value
		$Line2D.visible = value
	
	$SliderSprite.visible = value
	$QuickReloadBar.visible = value

func get_progress_pos_min() -> float:
	return ($MinBound.position.x + bar_length * 0.5) / bar_length
func get_progress_pos_max() -> float:
	return ($MaxBound.position.x + bar_length * 0.5) / bar_length
