extends Button


func _on_button_down():
	$BackText.position.y -= 5

func _on_button_up():
	$BackText.position.y += 5

func _on_pressed():
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
