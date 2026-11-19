extends Node
## Einzelprüfung für Eisenliturgie und den Rückwechsel in bestehende Modi.


func _ready() -> void:
	var failures: Array[String] = []
	UiTheme.use_skin(UiTheme.BOLLWERK)
	if UiTheme.GOLD != HdUiStyle.GOLD or UiTheme.PANEL != HdUiStyle.COLORS.PANEL:
		failures.append("Bollwerk-Palette")
	if HdUiStyle.metal_material().shader!=Wc3Theme.GLOSS or HdUiStyle.metal_material().get_shader_parameter("palette_metal")!=1.0:
		failures.append("Getönter gemeinsamer Metallshader")
	if Wc3Theme.gloss_material().get_shader_parameter("palette_metal")!=0.0:
		failures.append("Unverändertes WC3-Messing")
	if Wc3Theme.gloss_material().get_shader_parameter("text_relief")!=0.0 or HdUiStyle.text_metal_material().get_shader_parameter("text_relief")!=1.0:
		failures.append("Getrennter Schriftrelief-Shader")
	if not UiTheme.panel() is HdUiStyle.IronFrame:
		failures.append("Doppelrahmen")
	if not UiTheme.get_theme().get_stylebox("normal", "Button") is HdUiStyle.IronFrame:
		failures.append("Knopfrahmen")
	var plus := Button.new()
	HdUiStyle.upgrade_button(plus)
	if not plus.get_theme_stylebox("normal").diamond:
		failures.append("Aufwertungsraute")
	plus.free()
	for skin in [UiTheme.ARCADE, UiTheme.DRUID, UiTheme.DECO, UiTheme.POSTER, UiTheme.HOLO]:
		UiTheme.use_skin(skin)
		if UiTheme.panel() is HdUiStyle.IronFrame:
			failures.append("Skin-Rückwechsel: " + skin)
	UiTheme.use_skin(UiTheme.ARCADE)
	if UiTheme.GOLD != UiTheme.ARCADE_COLORS.GOLD or UiTheme.SHADOW != UiTheme.ARCADE_COLORS.SHADOW:
		failures.append("Arcade-Farben nach Rückwechsel")
	print("EISENLITURGIE ", "OK" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
