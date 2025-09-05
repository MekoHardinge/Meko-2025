extends Button

func _on_button_down():
	$LevelTitle.position.y -= 5

func _on_button_up():
	$LevelTitle.position.y += 5

func _on_pressed():
	get_tree().change_scene_to_file("res://levelSelect.tscn")
