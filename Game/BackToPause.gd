extends Button

func _on_button_down():
	$BackToPauseTitle.position.y -= 5

func _on_button_up():
	$BackToPauseTitle.position.y += 5

func _on_pressed():
	$"..".visible = false
	$"../../../Options".visible = true
	$"../../../MainMenu".visible = true
	$"../../../Resume".visible = true
	$"../../../Quit".visible = true
