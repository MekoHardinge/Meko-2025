extends Button

func _on_button_down():
	$QuitTitle.position.y -= 5


func _on_button_up():
	$QuitTitle.position.y += 5

func _on_pressed():
	get_tree().quit()
