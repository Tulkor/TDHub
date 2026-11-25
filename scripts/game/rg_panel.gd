class_name RgPanel
extends PanelContainer
## Seitenleiste von Randgruppen TD: Rasse und Holz, die 7 Tower der Rasse zum Bauen (Tasten 1–7, wie die
## Baumenüs der Baumeister im Original), der Knopf für das nächste Level und die letzten Meldungen.

var game  # rg_game.gd
var _race: Label
var _lumber: Label
var _towers: VBoxContainer
var _towers_key := ""
var _next: Button
var _log: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(12.0, 0.94))
	custom_minimum_size.x = 280
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	_race = UiUtil.label("", head, 15)
	UiTheme.heading(_race)
	_race.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.label("Holz", head, 14).add_theme_color_override("font_color", UiTheme.MUTED)
	_lumber = UiUtil.label("", head, 16)
	_lumber.add_theme_color_override("font_color", UiTheme.HAVE)
	_lumber.tooltip_text = tr("Holz gibt es einmal vor Level 25. Der Endtower kostet 1 Holz.")
	_lumber.mouse_filter = Control.MOUSE_FILTER_PASS

	_towers = VBoxContainer.new()
	_towers.add_theme_constant_override("separation", 4)
	v.add_child(_towers)

	_next = UiUtil.button("", v, func(): game.submit({"type": "start_level"}))
	_next.focus_mode = Control.FOCUS_NONE
	_next.custom_minimum_size.y = 40
	_next.tooltip_text = tr("Pause überspringen (Taste N)")
	UiTheme.accent_button(_next, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_log = UiUtil.wrap_label("", v, 256)
	_log.add_theme_font_size_override("font_size", 14)
	_log.add_theme_color_override("font_color", UiTheme.MUTED)
	refresh()


func refresh() -> void:
	if _race == null:
		return
	var st: Dictionary = game.rp(game.local_player)
	_race.text = tr(str(game.race(str(st.race)).get("name", "")))
	_lumber.text = str(int(st.lumber))
	_refresh_towers()
	_log.text = "\n".join(st.log)
	var waiting: bool = game.phase == game.Phase.BUILD and game.setup_done
	_next.visible = waiting
	if waiting:
		_next.text = tr("Level %d starten · %d s") % [game.wave_index + 1, ceili(maxf(game.level_pause, 0.0))]
		# Koop: wer schon bereit ist, wartet auf die anderen
		if game.players.size() > 1:
			var here: Array = range(game.players.size()).filter(func(i): return not game.players[i].away)
			var ready: int = here.filter(func(i): return game.rp(i).ready).size()
			_next.text += " · %d/%d %s" % [ready, here.size(), tr("bereit")]
			_next.disabled = bool(st.ready)
	elif not game.setup_done:
		var missing: Array = [] if game.players.size() < 2 else range(game.players.size()).filter(func(i): return not game.players[i].away and not game.rp(i).chosen)
		if not missing.is_empty():
			_log.text = tr("Warte auf die Rassenwahl von: %s") % ", ".join(missing.map(func(i): return game.players[i].name))


## Ein Knopf je Tower der Rasse; neu gebaut nur, wenn sich Preis-Lage oder Auswahl ändern.
func _refresh_towers() -> void:
	var list: Array = game.race_towers(game.local_player)
	var reasons: Array = list.map(func(id): return game.build_reason(id))
	var key: String = str(list) + str(reasons) + str(game.placing)
	if key == _towers_key:
		return
	_towers_key = key
	for c in _towers.get_children():
		_towers.remove_child(c)
		c.queue_free()
	for i in list.size():
		var id: String = list[i]
		var r: Dictionary = Database.towers[id].rg
		var text := "%d  %s · %d G" % [i + 1, Database.tower_label(id, 0), int(r.cost)]
		if int(r.get("lumber", 0)) > 0:
			text += " + %d %s" % [int(r.lumber), tr("Holz")]
		var b := UiUtil.button(text, _towers, func(): game.start_placement(id))
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # lange Namen (englisch) umbrechen statt abschneiden
		b.custom_minimum_size = Vector2(256, 30)
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = reasons[i] != "" and game.placing != id
		var tier: Dictionary = Database.tower_tier(id, 0)
		var dmg: Array = tier.get("damage", [0, 0])
		b.tooltip_text = "%s\n%s %d–%d · %s %s s · %s %s" % [Database.tower_label(id, 0), tr("Schaden"), int(dmg[0]), int(dmg[1]),
				tr("Abklingzeit"), str(tier.get("cooldown", 1.0)), tr("Reichweite"), str(tier.get("range", 0))]
		for ab in tier.get("abilities", []):
			b.tooltip_text += "\n" + Abilities.describe(ab)
		if reasons[i] != "":
			b.tooltip_text += "\n" + str(reasons[i])
		if game.placing == id:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_color_override("font_color", UiTheme.BG)
			b.add_theme_color_override("font_hover_color", UiTheme.BG)
