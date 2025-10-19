extends Button


func _on_button_down():
	$CreditsTitle.position.y -= 5


func _on_button_up():
	$CreditsTitle.position.y += 5



func _on_pressed():
	$"..".visible = false
	$"../../Credits".visible = true
