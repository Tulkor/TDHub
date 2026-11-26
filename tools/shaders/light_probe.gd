extends Node
## Actual GPU readback of shared attenuation/cones, including signed spotlight direction.

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 128)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(viewport.size)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
#include "res://assets/shaders/light_profiles.gdshaderinc"
void fragment() {
 int row=int(UV.y*4.0);
 float x=UV.x*2.0;
 int type=min(row,2);
 vec3 axis=row==3?normalize(vec3(0.65,-1.0,0.0)):vec3(0.0,-1.0,0.0);
 float result=surface_light_profile(type,vec2(x,0.0),0.5,1.0,0.015,1.0,axis,15.0,30.0,1.0);
 COLOR=vec4(vec3(result),1.0);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	viewport.add_child(rect)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	var checks := [
		[img.get_pixel(0,16).r > 0.98, "soft center"],
		[absf(img.get_pixel(63,16).r - 0.5) < 0.03, "50 percent distance"],
		[img.get_pixel(132,16).r < 0.01, "zero distance cutoff"],
		[img.get_pixel(100,48).r > 0.98, "hard interior"],
		[img.get_pixel(132,48).r < 0.01, "hard outside"],
		[img.get_pixel(16,80).r > 0.9, "spot inner cone"],
		[img.get_pixel(90,80).r < 0.01, "spot outer cone"],
		[img.get_pixel(90,112).r > 0.03, "tilted spot direction"],
		[img.get_pixel(0,112).r < 0.01, "tilted spot rejects opposite angle"],
	]
	var failures := 0
	for check in checks:
		if not check[0]:
			push_error("Light GPU: " + str(check[1]))
			failures += 1
	img.save_png("res://.godot/light-profiles-readback.png")
	print("GPU light profiles: ",checks.size()-failures,"/",checks.size()," checks OK")
	get_tree().quit(1 if failures else 0)
