extends Area2D

var hitMonsters := []

func _process(delta: float) -> void:
	if GameWorld.paused:
		return
	
	for m in hitMonsters:
		m.hit(0, m.fullStunAt * 0.8)


func addToHitMonsters(m):
	if not hitMonsters.has(m):
		hitMonsters.append(m)
		if not m.is_connected("died", self, "removeFromHitMonsters"):
			m.connect("died", self, "removeFromHitMonsters", [m])

func removeFromHitMonsters(m):
	if hitMonsters.has(m):
		hitMonsters.erase(m)
		m.disconnect("died", self, "removeFromHitMonsters")

func _on_DeathCandleArea_area_entered(area: Area2D) -> void:
	if area.is_in_group("monster"):
		addToHitMonsters(area)


func _on_DeathCandleArea_area_exited(area: Area2D) -> void:
	if area.is_in_group("monster"):
		removeFromHitMonsters(area)
