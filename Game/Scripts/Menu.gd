extends Button

func _pressed():
		$"../../../../Settings".visible = true
		$"../../..".visible = false
		$"../../../../GoblinArmy".visible = false
		$"../../../../KnightUnitRed".visible = false
		$"../../../../KnightUnitBlue".visible = false
