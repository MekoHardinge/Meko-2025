extends Button

func _on_button_down():
	$QuitText.position.y -= 5

func _on_button_up():
	$QuitText.position.y += 5

func _on_pressed():
	get_tree().quit()
