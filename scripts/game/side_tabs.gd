class_name SideTabs
extends PanelContainer
## Reiter über der rechten Spalte im Spiel: Alle, DPS, Gegner, Tower (Lukas 2026-11-03, Vorschlag 7).
## „Alle“ zeigt die drei Fenster untereinander wie bisher, sonst nur eines. Steht der Reiter auf DPS oder Gegner,
## springt er beim Wellenstart auf Gegner und nach der Welle zurück auf DPS. Die Wahl bleibt gespeichert
## (Session.side_tab). DpsMeter, EnemyPanel und TowerList fragen shows() und blenden sich danach aus.

const TABS := [["alle", "Alle"], ["dps", "DPS"], ["gegner", "Gegner"], ["tower", "Tower"]]

var hud  # hud.gd
var avoid: Control  ## rutscht darunter, solange es offen ist (Debug-Menü)
var tab := "alle"
var buttons := {}
var _running := false


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	offset_top = DpsMeter.TOP_Y
	offset_right = -16
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size.x = 280
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiTheme.panel(4.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	add_child(h)
	tab = Session.side_tab if TABS.any(func(t): return t[0] == Session.side_tab) else "alle"
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2, 4))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		b.set_pressed_no_signal(t[0] == tab)
		var id: String = t[0]
		b.pressed.connect(func(): select(id, true))
		h.add_child(b)
		buttons[id] = b
	tooltip_text = tr("Rechte Spalte: alle Fenster oder nur eines. H blendet beide Seitenleisten aus.")


func shows(id: String) -> bool:
	return tab == "alle" or tab == id


## manual: vom Spieler gewählt (wird gespeichert); sonst Wechsel durch Wellenstart/-ende.
func select(id: String, manual := false) -> void:
	tab = id
	if buttons.has(id):
		buttons[id].set_pressed_no_signal(true)
	if manual:
		Session.side_tab = id
		Session.save_last()


func _process(_delta: float) -> void:
	if avoid != null:
		offset_top = avoid.get_rect().end.y + 12 if avoid.visible else DpsMeter.TOP_Y
	var game = hud.get_parent() if hud != null else null
	if game == null or not game.has_method("is_wave_running"):
		return
	var running: bool = game.is_wave_running()
	if running != _running:
		_running = running
		if tab == "dps" or tab == "gegner":
			select("gegner" if running else "dps")
