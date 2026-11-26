extends Node2D
## Getrennte Metalllagen für Konturen und Knopfschrift; Bilder und Balkenfüllungen bleiben unberührt.
var root: Control

static func install(parent: Control) -> void:
	var manager = load("res://scripts/heroes/hd_ui_metal.gd").new()
	manager.root=parent
	parent.add_child(manager)

func _ready() -> void:
	get_tree().node_added.connect(_added)
	get_tree().node_removed.connect(_removed)
	_scan(root)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_added):get_tree().node_added.disconnect(_added)
	if get_tree().node_removed.is_connected(_removed):get_tree().node_removed.disconnect(_removed)

func _added(node: Node) -> void:
	if not (node is Control or node is PopupMenu or node is PopupPanel):return
	if not root.is_ancestor_of(node) and not node is PopupPanel:return
	_register.call_deferred(node)

func _removed(node: Node) -> void:
	if node is MetalLayer and is_instance_valid(node.control) and node.control.is_inside_tree():_register.call_deferred(node.control)
	if node is MetalText and is_instance_valid(node.button) and node.button.is_inside_tree():_register.call_deferred(node.button)

func _scan(node: Node) -> void:
	_register(node)
	for child in node.get_children():_scan(child)

func _register(node) -> void:
	if not is_instance_valid(node):return
	if node is Label and not node is MetalText and root.is_ancestor_of(node):
		HdUiStyle.normalize_label(node)
	if node is Button and root.is_ancestor_of(node) and node.text!="" and not node.has_node("BollwerkMetalText"):
		var text_layer := MetalText.new(node)
		text_layer.name="BollwerkMetalText"
		node.add_child(text_layer)
	if node.has_meta("own_metal_frame") or node.has_node("BollwerkMetal"):return
	# Godot hängt Tooltip-Fenster direkt ans Viewport statt an den HUD-Root.
	var tooltip: bool = node is PopupPanel and node.get_theme_stylebox("panel") is HdUiStyle.IronFrame
	if not root.is_ancestor_of(node) and not tooltip:return
	if not (node is PanelContainer or node is Button or node is ProgressBar or node is InvSlot or node is LineEdit or node is ItemList or node is TabContainer or node is PopupMenu or node is PopupPanel):return
	if node is Button and not (node is CheckBox or node is CheckButton) and node.text!="":
		for state in ["normal","hover","pressed","hover_pressed","disabled"]:
			var old: StyleBox=node.get_theme_stylebox(state)
			if old is HdUiStyle.IronFrame and not old is HdUiStyle.MenuButtonFrame and not old is HdUiStyle.TabFrame and not old.diamond:
				var style := HdUiStyle.menu_button_style(state,old.content_margin_left)
				style.content_margin_right=old.content_margin_right
				style.content_margin_top=old.content_margin_top
				style.content_margin_bottom=old.content_margin_bottom
				node.add_theme_stylebox_override(state,style)
		if not node.has_node("BollwerkMetalText"):
			node.add_theme_color_override("font_pressed_color",HdUiStyle.COLORS.TEXT)
			node.add_theme_color_override("font_hover_pressed_color",HdUiStyle.COLORS.TEXT)
	if node is PanelContainer:
		var old: StyleBox=node.get_theme_stylebox("panel")
		if old is StyleBoxFlat and old.bg_color.b>old.bg_color.r:
			var style := HdUiStyle.frame(old.bg_color,old.border_color,old.content_margin_left,6)
			style.content_margin_right=old.content_margin_right
			style.content_margin_top=old.content_margin_top
			style.content_margin_bottom=old.content_margin_bottom
			node.add_theme_stylebox_override("panel",style)
	node.set_meta("bollwerk_metal",true)
	var layer := MetalLayer.new(node)
	layer.name="BollwerkMetal"
	layer.set_meta("bollwerk_metal_layer",true)
	node.add_child(layer)
	if node is OptionButton:_register(node.get_popup())

class MetalLayer extends Node2D:
	var control
	## Steine liegen auf einer eigenen Lage ohne Metallshader über dem Messing.
	var jewels := Node2D.new()
	var _style: StyleBox
	var _rect := Rect2()

	func _init(owner_control) -> void:
		control=owner_control
		material=HdUiStyle.metal_material()
		jewels.name="Jewels"
		add_child(jewels)
		jewels.draw.connect(func():
			if _style != null and _style.has_method("draw_jewels"):_style.draw_jewels(jewels.get_canvas_item(),_rect))
		if control is Window:
			control.size_changed.connect(queue_redraw)
			control.about_to_popup.connect(queue_redraw)
		else:
			control.resized.connect(queue_redraw)
			control.draw.connect(queue_redraw)
			control.theme_changed.connect(queue_redraw)
			control.mouse_entered.connect(queue_redraw)
			control.mouse_exited.connect(queue_redraw)
		if control is BaseButton:
			control.button_down.connect(queue_redraw)
			control.button_up.connect(queue_redraw)

	func _draw() -> void:
		if not is_instance_valid(control):return
		var style: StyleBox
		if control is PopupMenu or control is PopupPanel:style=HdUiStyle.panel()
		elif control is InvSlot:style=HdUiStyle.slot_frame(control)
		elif control is ProgressBar:style=control.get_theme_stylebox("background")
		elif control is Button:
			var state := "normal"
			if control.disabled:state="disabled"
			elif control.is_pressed():state="pressed"
			elif control.is_hovered():state="hover"
			style=control.get_theme_stylebox(state)
		elif control is LineEdit:style=control.get_theme_stylebox("normal")
		else:style=control.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			if style.border_color.a<=0:return
			style=HdUiStyle.frame(Color.TRANSPARENT,style.border_color,0,0)
		_style=style
		_rect=Rect2(Vector2.ZERO,Vector2(control.size))
		if style is HdUiStyle.IronFrame:style.draw_metal(get_canvas_item(),_rect)
		jewels.queue_redraw()


class MetalText extends Label:
	var button: Button

	func _init(owner_button: Button) -> void:
		button=owner_button
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		clip_text=true
		vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		material=HdUiStyle.text_metal_material()
		button.draw.connect(_sync)
		button.resized.connect(_sync)

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sync()

	func _sync() -> void:
		if not is_instance_valid(button):return
		text=tr(button.text)
		horizontal_alignment=button.alignment
		var font: Font=button.get_theme_font("font")
		var font_size: int=button.get_theme_font_size("font_size")
		if get_theme_font("font")!=font:add_theme_font_override("font",font)
		if get_theme_font_size("font_size")!=font_size:add_theme_font_size_override("font_size",font_size)
		var state := "disabled" if button.disabled else ("pressed" if button.is_pressed() else ("hover" if button.is_hovered() else "normal"))
		var style: StyleBox=button.get_theme_stylebox(state)
		var shift := 1.0 if button.is_pressed() and not button.toggle_mode else 0.0
		offset_left=style.get_content_margin(SIDE_LEFT)
		offset_right=-style.get_content_margin(SIDE_RIGHT)
		offset_top=style.get_content_margin(SIDE_TOP)+shift
		offset_bottom=-style.get_content_margin(SIDE_BOTTOM)+shift
		if button is OptionButton:
			var arrow: Texture2D=button.get_theme_icon("arrow")
			if arrow:offset_right-=arrow.get_width()+button.get_theme_constant("h_separation")
		var color: Color=HdUiStyle.COLORS.MUTED.darkened(.25) if button.disabled else (HdUiStyle.GOLD_HI if button.is_hovered() else HdUiStyle.GOLD)
		if button.has_meta("metal_text_color") and not button.is_hovered() and not button.disabled:color=button.get_meta("metal_text_color")
		if button.has_meta("bollwerk_primary") and not button.disabled:color=HdUiStyle.GOLD_HI
		if get_theme_color("font_color")!=color:add_theme_color_override("font_color",color)
		# Die native Beschriftung bleibt für Layout, Übersetzung und Bedienung erhalten.
		for name in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color","font_outline_color"]:
			if button.get_theme_color(name)!=Color.TRANSPARENT:button.add_theme_color_override(name,Color.TRANSPARENT)
