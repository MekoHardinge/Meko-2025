extends Button

func _on_button_up():
	$ResumeTitle.position.y += 5


func _on_button_down():
	$ResumeTitle.position.y -= 5


func _on_pressed():
	$"..".visible = false
	$"../../Camera2D".visible = true
	$"../../GoblinArmy".visible = true
	$"../../KnightUnitRed".visible = true
	$"../../KnightUnitBlue".visible = true
	print("Clicked")
