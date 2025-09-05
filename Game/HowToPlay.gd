extends Button

func _on_button_down():
	$HowToPlayTitle.position.y -= 5

func _on_button_up():
	$HowToPlayTitle.position.y += 5

func _on_pressed():
	$"..".visible = false
	$"../../HowToPlay".visible = true
