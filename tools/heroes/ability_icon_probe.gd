extends Control
## Native Vorschau der tatsächlichen SVGs, Lederflächen und Metallmaterialien.
const Icons = preload("res://scripts/heroes/hd_ability_icons.gd")

func _ready() -> void:
	UiTheme.use_skin(UiTheme.BOLLWERK)
	get_window().mode=Window.MODE_WINDOWED
	get_window().size=Vector2i(1500,1040)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=UiTheme.get_theme()
	var selected: Array=["torvik","unrat","vesna","zix","grauhirte","sorek"]
	var output_name := "bollwerk-ability-icons"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--helden="):selected=Array(arg.trim_prefix("--helden=").split(","))
		if arg.begins_with("--name="):output_name=arg.trim_prefix("--name=").validate_filename()
	for frame in 3:await get_tree().process_frame
	var area := get_viewport().get_visible_rect().size
	var bg := ColorRect.new()
	bg.color=Color("070d16")
	bg.size=area
	add_child(bg)
	var title := Label.new()
	title.text="Bollwerk · Metallbeschläge auf Leder"
	title.position=Vector2(28,18)
	HdUiStyle.title(title,26)
	add_child(title)
	var data: Dictionary=Database.load_json("res://data/heroes_helden.json")
	var column := (area.x-220)/4.0
	var row_height := minf(150,(area.y-90)/float(selected.size()))
	for row in selected.size():
		var hero: Dictionary=data.heroes.filter(func(h):return h.id==selected[row])[0]
		var at := Vector2(22,72+row*row_height)
		var name_label := Label.new()
		name_label.text=str(hero.name)
		name_label.position=at+Vector2(0,35)
		name_label.add_theme_color_override("font_color",HdUiStyle.GOLD)
		name_label.add_theme_font_size_override("font_size",16)
		name_label.size=Vector2(180,60)
		name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		add_child(name_label)
		for slot in 4:
			var ability: Dictionary=hero.abilities[slot] if hero.id!="zix" else (hero.abilities[0] if slot==3 else data.gadgets[hero.default_kit[slot]])
			var id: String=str(ability.id) if hero.id!="zix" or slot==3 else "gadget_"+str(hero.default_kit[slot])
			var x := 205+column*slot
			var size_icon := minf(105,row_height-30)
			var card := PanelContainer.new()
			card.position=Vector2(x+(column-size_icon)*.5,at.y+23)
			card.size=Vector2.ONE*size_icon
			card.add_theme_stylebox_override("panel",HdUiStyle.skill_frame())
			add_child(card)
			var icon := TextureRect.new()
			icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture=Icons.texture(id)
			icon.material=HdUiStyle.icon_metal_material()
			icon.modulate=HdUiStyle.GOLD
			card.add_child(icon)
			var caption := Label.new()
			caption.text=str(ability.name)
			caption.position=Vector2(x,at.y)
			caption.size=Vector2(column,22)
			caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_size_override("font_size",13)
			add_child(caption)
	preload("res://scripts/heroes/hd_ui_metal.gd").install(self)
	for frame in 12:await get_tree().process_frame
	var output := "res://export/screens/"+output_name+".png"
	get_viewport().get_texture().get_image().save_png(output)
	print("BILD ",ProjectSettings.globalize_path(output))
	get_tree().quit()
