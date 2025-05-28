extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var label = $Label

const SPEED = 200.0
var selected = false

func _ready():
	add_to_group("unit")
	
func _process(delta):
	label.visible = selected

