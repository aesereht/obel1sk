extends "res://stages/level/LevelStage.gd"


func build(data:Array):
	.build(data)
	$Canvas / BattlePopup.find_node("ActionWeaponMoveUp").visible = true
	$Canvas / BattlePopup.find_node("ActionWeaponMoveDown").visible = true

	$Canvas / BattlePopup.find_node("ActionWeaponMoveLeft").visible = true
	$Canvas / BattlePopup.find_node("ActionWeaponMoveRight").visible = true
