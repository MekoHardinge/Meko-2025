extends Node2D

func _process(delta):
	var goblin_unit = $GoblinArmy
	var player_unit1 = $KnightUnitRed
	var player_unit2 = $KnightUnitBlue

	# Win condition
	if goblin_unit.get_child_count() == 0:
		$WinLoseScreen.visible = true
		$WinLoseScreen/Win.visible = true
		$GoblinArmy.visible = false
		$KnightUnitRed.visible = false
		$KnightUnitBlue.visible = false
		print("You won!")
		set_process(false)
		return

	# Lose condition
	if player_unit1.get_child_count() == 0 and player_unit2.get_child_count() == 0:
		print("You lost!")
		$GoblinArmy.visible = false
		$KnightUnitRed.visible = false
		$KnightUnitBlue.visible = false
		$WinLoseScreen.visible = true
		$WinLoseScreen/Lose.visible = true
		set_process(false)
		return
