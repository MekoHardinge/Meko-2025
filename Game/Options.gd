extends Button
func _on_button_down():
	$OptionsTitle.position.y -= 5
func _on_button_up():
	$OptionsTitle.position.y += 5
func _on_pressed():
	$".".visible = false
	$"../MainMenu".visible = false
	$"../Resume".visible = false
	$"../Quit".visible = false
	$"../MenuTilemap/OptionsSprite".visible = true
