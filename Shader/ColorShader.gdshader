shader_type canvas_item;

uniform vec4 color : source_color;

void fragment() {
	if (COLOR.r > 0.0)
		COLOR = vec4(color.rgb, COLOR.r);
	else
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
}
