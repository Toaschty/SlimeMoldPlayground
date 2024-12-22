class_name NumberEdit
extends LineEdit

@export var integer_only : bool

@onready var prev_text : String = text

# Loose focus on outside click
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var local_position = make_input_local(event)
		
		if !Rect2(Vector2.ZERO, size).has_point(local_position.position):
			release_focus()

# Number only text input
func _on_text_changed(new_text: String) -> void:
	if new_text.is_empty():
		prev_text = ""
		return
	
	if (integer_only and !new_text.is_valid_int()) or (!integer_only and !new_text.is_valid_float()):
		var cursor_pos = get_caret_column()
		text = prev_text
		set_caret_column(cursor_pos - 1)
		return
	
	prev_text = new_text
