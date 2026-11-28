extends Node3D
## Vorschau aller Treffer- und Schuss-Effekte als Bildfolge (Raster, Spielkamera schräg von oben).
## Start: tools/fx/vorschau.sh [--zeiten=0.05,0.12,0.25] [--aus=ordner] [--nur=red_hit,...] [--tower=ruby,topaz]
## Mit --tower werden die Effekte so gezeigt, wie die Tower sie bekommen (Treffer, Schuss, ggf. Nova).

var opts := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var env := WorldEnvironment.new()
	Display.quality = int(opts.get("grafik", Display.HIGH))
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("10101c")
	add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("1b1b2e")
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	var cam := Camera3D.new()
	add_child(cam)
	var fx := FxPlayer.new()
	FxPlayer.lights_enabled = not opts.has("ohne-licht")
	add_child(fx)
	fx.set_process(false)
	var cols := int(opts.get("spalten", "6"))
	var gap := 1.6
	var items := []
	if opts.has("effekttower"):
		for id in str(opts.effekttower).split(","):
			items.append({"effect_tower": id})
	elif opts.has("schuesse"):
		for id in str(opts.schuesse).split(","):
			items.append({"shot": id})
	elif opts.has("tower"):
		for id in str(opts.tower).split(","):
			var parts := id.split(":")
			items.append({"tower": parts[0], "tier": int(parts[1]) if parts.size() > 1 else 0})
	else:
		var ids: Array = FxData.hit_ids()
		if opts.has("nur"):
			ids = Array(str(opts.nur).split(","))
		for id in ids:
			items.append({"hit": id})
		if not opts.has("nur"):
			for id in FxData.shot_ids(["line", "projectile", "nova"]):
				items.append({"shot": id})
	var rows := ceili(items.size() / float(cols))
	var w := (cols - 1) * gap
	var h := (rows - 1) * gap
	cam.fov = 40
	cam.position = Vector3(w / 2.0, 7.0 + rows * 0.8, h / 2.0 + 4.5 + rows * 0.55)
	cam.look_at(Vector3(w / 2.0 - 0.35, 0.7, h / 2.0 - 0.65))
	var markers := []
	for i in items.size():
		var p := Vector3((i % cols) * gap, 0.2, (i / cols) * gap)
		var it: Dictionary = items[i]
		var cube := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.4
		cube.mesh = bm
		cube.position = p
		add_child(cube)
		if it.has("effect_tower"):
			cube.hide()
			var permanent := preload("res://scripts/game/tower_element_fx.gd").make(it.effect_tower)
			permanent.position = p
			add_child(permanent)
		var lbl := Label3D.new()
		lbl.text = str(it.get("hit", it.get("shot", it.get("tower", it.get("effect_tower", "")))))
		lbl.font_size = 30
		lbl.pixel_size = 0.004
		lbl.position = p + Vector3(0, -0.15, 0.55)
		lbl.rotation.x = -PI / 2.0
		add_child(lbl)
		markers.append([it, p])
	await get_tree().process_frame
	for m in markers:
		var it: Dictionary = m[0]
		var p: Vector3 = m[1]
		var from := p + Vector3(-1.2, 0.7, -1.0)
		if it.has("effect_tower"):
			continue
		elif it.has("hit"):
			fx.play_hit({"id": it.hit}, p)
		elif it.has("shot"):
			var e := FxData.shot(it.shot)
			if str(e.get("kind", "")) == "nova":
				fx.play_nova({"id": it.shot}, p - Vector3(0, 0.2, 0), 0.6)
			else:
				fx.play_shot({"id": it.shot}, from, p)
		else:
			var f := FxData.for_tower(it.tower, it.tier)
			var delay := 0.0
			if f.has("shot"):
				fx.play_shot(f.shot, from, p)
				var se := FxData.shot(str(f.shot.id))
				if str(se.get("kind", "")) == "projectile":
					delay = float(se.get("length", 0.0))
			if f.has("hit"):
				fx.play_hit(f.hit, p, 1.0, delay)
			if f.has("nova"):
				fx.play_nova(f.nova, p - Vector3(0, 0.2, 0), 0.6)
			print("TOWER %s: %s" % [it.tower, f])
	var out: String = opts.get("aus", "/mnt/project-files/screens/fx")
	DirAccess.make_dir_recursive_absolute(out)
	var t := 0.0
	var step := 1.0 / 60.0
	for z in str(opts.get("zeiten", "0.05,0.12,0.25,0.4")).split(","):
		var target := float(z)
		while t + step <= target:
			fx._process(step)
			t += step
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s_%03d.png" % [out, opts.get("name", "fx"), int(round(target * 1000))]
		img.save_png(path)
		print("BILD ", path)
	get_tree().quit()
