extends Button

func _on_button_down():
	$BackButtonText.position.y -= 5

func _on_button_up():
	$BackButtonText.position.y += 5

func _on_pressed():
	$"../../Buttons".visible = true
	$"../../Credits".visible = false
	$"../../HowToPlay".visible = false
