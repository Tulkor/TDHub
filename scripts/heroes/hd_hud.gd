class_name HdHud
extends CanvasLayer
## Oberfläche von Bollwerk im Arcade-Stil (UiTheme): Leiste oben (Welle, Feste, Kills, Früher rufen),
## Bossleiste, Heldenleiste unten (Leben, Mana, EP, Fähigkeiten mit Abklingzeit, Ausweichen),
## Lebensbalken/Aufladebalken/CC-Stufe über den Einheiten, schwebende Zahlen, Startfenster,
## Spielmenü und Endbildschirm. Liest HdGame, Aktionen rufen dessen Befehle.

var game  ## HdGame
var root: Control
var _world: Control              ## Balken und Zahlen über der Welt
var _wave: Label
var _wave_bar: ProgressBar
var _lives: Label
var _kills: Label
var _early: Button
var _pause_button: Button
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_info: Label
var _name: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _mana_bar: ProgressBar
var _mana_label: Label
var _xp_bar: ProgressBar
var _slots: Array = []           ## {panel, key, name, cd, shade}
var _status: Label
var _hint: Label
var _banner: Label
var _banner_t := 0.0
var _overlay: Control
var _floaters: Array = []        ## {pos, text, color, t}
var _tick := 0.0
var econ: HdShopUi               ## Gold, Inventar, Shop, Straßenleiste


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_world = Control.new()
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.draw.connect(_draw_world)
	root.add_child(_world)
	_build_top()
	_build_boss()
	_build_hero()
	econ = HdShopUi.new(game)
	root.add_child(econ)
	_hint = _label("", root, 12, UiTheme.MUTED)
	_hint.position = Vector2(16, 62)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 120
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	UiTheme.title(_banner, 34)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	game.changed.connect(refresh)
	game.message.connect(show_banner)
	game.floated.connect(_on_float)
	game.ended.connect(_show_end)
	_set_play_visible(false)


func _panel(parent: Node, pad := 10.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel(pad))
	parent.add_child(p)
	return p


func _label(text: String, parent: Node, size := 15, color := Color.TRANSPARENT, bold := false) -> Label:
	var l := UiUtil.label(text, parent, size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	return l


func _bar(parent: Node, fill: Color, h := 12.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size.y = h
	b.add_theme_stylebox_override("background", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 0, 2, 0))
	b.add_theme_stylebox_override("fill", UiTheme.box(fill, Color.TRANSPARENT, 0, 0, 0))
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- Aufbau

func _build_top() -> void:
	var p := _panel(root, 8)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	p.offset_left = 12
	p.offset_right = -12
	p.offset_top = 10
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	p.add_child(h)
	var t := Label.new()
	t.text = "Bollwerk"
	UiTheme.title(t, 20)
	h.add_child(t)
	var wv := VBoxContainer.new()
	wv.custom_minimum_size.x = 260
	h.add_child(wv)
	_wave = _label("", wv, 15, UiTheme.TEXT, true)
	_wave_bar = _bar(wv, UiTheme.CYAN, 8)
	_lives = _label("", h, 17, UiTheme.HAVE, true)
	_kills = _label("", h, 15, UiTheme.TEXT)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	_early = UiUtil.button("Früher rufen", h, func(): game.call_early())
	_pause_button = UiUtil.button("Pause", h, func():
		game.paused = not game.paused
		refresh())
	UiUtil.button("Menü", h, toggle_menu)


func _build_boss() -> void:
	_boss_panel = _panel(root, 8)
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.position.y = 84
	_boss_panel.custom_minimum_size.x = 520
	_boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	_boss_panel.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	_boss_name = _label("", row, 15, UiTheme.GOLD, true)
	_boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_info = _label("", row, 13, UiTheme.MUTED)
	_boss_bar = _bar(v, UiTheme.MISSING, 14)
	_boss_panel.visible = false


func _build_hero() -> void:
	var p := _panel(root, 10)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -14
	p.offset_top = -14
	p.custom_minimum_size.x = 640
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	_name = _label("", row, 15, UiTheme.TEXT, true)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status = _label("", row, 13, UiTheme.CYAN, true)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	v.add_child(hp_row)
	_hp_bar = _bar(hp_row, UiTheme.HAVE, 16)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_label = _label("", hp_row, 13, UiTheme.TEXT)
	_hp_label.custom_minimum_size.x = 110
	var mp_row := HBoxContainer.new()
	mp_row.add_theme_constant_override("separation", 8)
	v.add_child(mp_row)
	_mana_bar = _bar(mp_row, UiTheme.CYAN, 10)
	_mana_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mana_label = _label("", mp_row, 12, UiTheme.DIM)
	_mana_label.custom_minimum_size.x = 110
	_xp_bar = _bar(v, UiTheme.PURPLE_LIGHT, 5)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	v.add_child(slots)
	for i in 5:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 0, 2, 6))
		card.custom_minimum_size = Vector2(116, 62)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		slots.add_child(card)
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.55)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		card.add_child(cv)
		var key := _label("", cv, 13, UiTheme.GOLD, true)
		var nm := _label("", cv, 12, UiTheme.TEXT)
		nm.clip_text = true
		var cdl := _label("", cv, 12, UiTheme.MUTED)
		card.add_child(shade)
		_slots.append({"panel": card, "key": key, "name": nm, "cd": cdl, "shade": shade})


func _set_play_visible(on: bool) -> void:
	for c in root.get_children():
		if c != _overlay and c != _banner:
			c.visible = on
	if on:
		_boss_panel.visible = false


# ---------------------------------------------------------------- Anzeige

func on_started() -> void:
	_close_overlay()
	_set_play_visible(true)
	refresh()


func _process(dt: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= dt
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	for i in range(_floaters.size() - 1, -1, -1):
		_floaters[i].t += dt
		if _floaters[i].t > 1.0:
			_floaters.remove_at(i)
	_tick -= dt
	if _tick <= 0.0 and game.state != "setup":
		_tick = 0.1
		refresh()
	_world.queue_redraw()


func show_banner(text: String) -> void:
	_banner.text = text
	_banner_t = 2.2
	_banner.modulate.a = 1.0


func _on_float(pos: Vector3, text: String, c: Color) -> void:
	if _floaters.size() > 60:
		_floaters.pop_front()
	_floaters.append({"pos": pos, "text": text, "color": c, "t": 0.0})


func refresh() -> void:
	if game.state == "setup":
		return
	var count := int(game.cfg.waves.count)
	_wave.text = tr("Welle %d / %d") % [game.wave, count]
	if game.wave < count:
		_wave_bar.max_value = float(game.cfg.waves.time)
		_wave_bar.value = float(game.cfg.waves.time) - game.wave_time
	else:
		_wave_bar.max_value = 1.0
		_wave_bar.value = 1.0
	_lives.text = tr("Feste %d / %d") % [game.lives, game.max_lives]
	_kills.text = tr("Kills %d") % game.kills
	_early.disabled = not game.can_call_early()
	_pause_button.text = tr("Weiter") if game.paused else tr("Pause")
	var h: HdHero = game.hero
	_name.text = tr("%s · Stufe %d") % [tr(str(h.def.name)), h.level]
	_hp_bar.max_value = h.max_hp
	_hp_bar.value = h.hp
	_hp_label.text = "%d / %d" % [roundi(h.hp), roundi(h.max_hp)]
	_mana_bar.max_value = h.max_mana
	_mana_bar.value = h.mana
	_mana_label.text = "%d / %d" % [roundi(h.mana), roundi(h.max_mana)]
	_xp_bar.max_value = h.xp_needed(h.level)
	_xp_bar.value = h.xp
	var st: Array = []
	if h.dead:
		st.append(tr("Wiederbelebung in %d s") % ceili(h.respawn_t))
	st.append_array(h.status_lines())
	if h.cc.stunned(game.play_time):
		st.append(tr("Betäubt"))
	_status.text = "  ".join(st)
	for i in 5:
		_fill_slot(i)
	_hint.text = tr("WASD laufen · Maus zielen · Linksklick angreifen · Leertaste ausweichen · B Shop · Y Kamera · P Pause") if game.control == "wasd" \
		else tr("Rechtsklick laufen/angreifen · Q W E R zielen, Linksklick wirken · Leertaste ausweichen · B Shop · Y Kamera · P Pause")
	econ.refresh()
	var boss: HdEnemy = null
	for e in game.enemies:
		if not e.dead and e.rank == "boss":
			boss = e
	_boss_panel.visible = boss != null and game.state == "play"
	if boss:
		_boss_name.text = tr(str(boss.def.name))
		_boss_bar.max_value = boss.max_hp
		_boss_bar.value = boss.hp
		if boss.cc.immune(game.play_time):
			_boss_info.text = tr("CC-immun %d s") % ceili(boss.cc.immune_until - game.play_time)
		else:
			_boss_info.text = tr("CC-Wirkung %d %%") % roundi(boss.cc.next_factor(game.play_time) * 100.0)


func _fill_slot(i: int) -> void:
	var s: Dictionary = _slots[i]
	var h: HdHero = game.hero
	var cdv := 0.0
	var total := 1.0
	var ready := true
	if i < 4:
		var a := h.ability(i)
		s.key.text = game.key_name(i)
		s.name.text = tr(str(a.name))
		cdv = h.cd[i]
		total = float(a.cooldown)
		if not h.unlocked(i):
			s.cd.text = tr("ab Stufe %d") % int(a.get("unlock", 1))
			ready = false
		elif cdv > 0.0:
			s.cd.text = "%.1f s" % cdv
			ready = false
		elif h.mana < h.ability_cost(i):
			s.cd.text = tr("%d Mana") % roundi(h.ability_cost(i))
			ready = false
		else:
			s.cd.text = tr("%d Mana") % roundi(h.ability_cost(i))
		s.panel.tooltip_text = "%s\n%s" % [tr(str(a.name)), tr(str(a.get("desc", "")))]
	else:
		s.key.text = tr("Leertaste")
		s.name.text = tr("Ausweichen")
		cdv = h.dodge_cd
		total = float(h.def.dodge.cooldown)
		ready = cdv <= 0.0
		s.cd.text = "%.1f s" % cdv if cdv > 0.0 else tr("bereit")
	var selected: bool = i == game.preview_slot
	s.panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2, 6) if selected
		else UiTheme.box(UiTheme.PANEL_2, UiTheme.GOLD if (i < 4 and h.slot_glow(i)) else UiTheme.BORDER, 0, 2, 6))
	s.shade.visible = not ready
	if cdv > 0.0:
		s.shade.anchor_top = 1.0 - clampf(cdv / maxf(total, 0.01), 0.0, 1.0)
	else:
		s.shade.anchor_top = 0.0
	s.shade.offset_top = 0


# ---------------------------------------------------------------- Balken über der Welt

func _draw_world() -> void:
	if game.state == "setup" or game.camera == null:
		return
	var cam: Camera3D = game.camera
	var font := UiTheme.font(true)
	var now: float = game.play_time
	for e in game.enemies:
		if e.dead:
			continue
		var top: Vector3 = e.position + Vector3(0, e.height() + 0.35, 0)
		if cam.is_position_behind(top):
			continue
		var p := cam.unproject_position(top)
		var w := 46.0 if e.rank == "normal" else (64.0 if e.rank == "elite" else 96.0)
		var r := Rect2(p.x - w * 0.5, p.y - 8, w, 6)
		_world.draw_rect(r.grow(1), Color(0, 0, 0, 0.75))
		_world.draw_rect(Rect2(r.position, Vector2(w * clampf(e.hp / e.max_hp, 0, 1), 6)), UiTheme.MISSING if e.hit_flash <= 0.0 else UiTheme.TEXT)
		if e.rank == "elite":
			_world.draw_rect(r.grow(2), UiTheme.COIN, false, 1.0)
		# Aufladebalken
		if e.casting() and str(e.cast.phase) == "windup":
			var cr := Rect2(r.position + Vector2(0, 9), Vector2(w, 4))
			_world.draw_rect(cr, Color(0, 0, 0, 0.75))
			_world.draw_rect(Rect2(cr.position, Vector2(w * clampf(float(e.cast.t) / maxf(float(e.cast.windup), 0.01), 0, 1), 4)), UiTheme.GOLD)
		# Betäubung und CC-Stufe (Punkte = wie oft schon betäubt, Abnahme der nächsten Dauer)
		var lvl: int = e.cc.level(now)
		if e.cc.stunned(now):
			_world.draw_string(font, Vector2(r.position.x, r.position.y - 4), "✱", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CYAN)
		if e.cc.immune(now):
			_world.draw_string(font, Vector2(r.position.x + w - 40, r.position.y - 4), tr("IMMUN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.COIN)
		elif lvl > 0:
			for k in lvl:
				_world.draw_rect(Rect2(r.position.x + w - 6 - k * 7, r.position.y - 8, 5, 5), UiTheme.CYAN)
	for b in game.buildings:
		if not b.alive():
			continue
		var bp := cam.unproject_position(b.position + Vector3(0, b.height() + 1.2, 0))
		var br := Rect2(bp.x - 40, bp.y, 80, 6)
		_world.draw_rect(br.grow(1), Color(0, 0, 0, 0.75))
		_world.draw_rect(Rect2(br.position, Vector2(80 * b.hp / b.max_hp, 6)), UiTheme.CYAN)
	var h: HdHero = game.hero
	if h.alive():
		var hp_ := cam.unproject_position(h.position + Vector3(0, 2.5, 0))
		var hr := Rect2(hp_.x - 30, hp_.y, 60, 6)
		_world.draw_rect(hr.grow(1), Color(0, 0, 0, 0.75))
		_world.draw_rect(Rect2(hr.position, Vector2(60 * h.hp / h.max_hp, 6)), UiTheme.HAVE)
	for f in _floaters:
		var at: Vector3 = f.pos + Vector3(0, f.t * 1.2, 0)
		if cam.is_position_behind(at):
			continue
		var fp := cam.unproject_position(at)
		var c: Color = f.color
		c.a = clampf(1.4 - f.t * 1.4, 0, 1)
		_world.draw_string(font, fp - Vector2(20, 0), str(f.text), HORIZONTAL_ALIGNMENT_CENTER, 40 if str(f.text).length() < 5 else -1, 14, c)


# ---------------------------------------------------------------- Fenster

func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _open_overlay(width := 520.0) -> VBoxContainer:
	_close_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_overlay = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := _panel(center, 22)
	p.custom_minimum_size.x = width
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	return v


func _choice_row(parent: Node, options: Array, chosen: int, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var buttons: Array = []
	var pick := [chosen]
	var paint := func():
		for k in buttons.size():
			var b: Button = buttons[k]
			if k == pick[0]:
				b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
				b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
				b.add_theme_color_override("font_color", UiTheme.BG)
				b.add_theme_color_override("font_hover_color", UiTheme.BG)
			else:
				for s in ["normal", "hover"]:
					b.remove_theme_stylebox_override(s)
				b.remove_theme_color_override("font_color")
				b.remove_theme_color_override("font_hover_color")
	for k in options.size():
		var b := UiUtil.button(str(options[k]), row, func():
			pick[0] = k
			on_pick.call(k)
			paint.call())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(b)
	paint.call()


func show_setup() -> void:
	_set_play_visible(false)
	var v := _open_overlay(640)
	var t := Label.new()
	t.text = "Bollwerk"
	UiTheme.title(t, 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := _label("Halte die Feste Morgenwacht: Gegner kommen in 10 Wellen über die Straßen, Vorwerk und Innentor bremsen sie. Mit Gold kaufst du Items und schmiedest Rezepte, Holz gibt dauerhafte Werte. Farbige Flächen am Boden kündigen Gegnerfähigkeiten an, die Füllung zeigt, wann sie auslösen. Ausweichen schlägt Rüstung.", v, 14, UiTheme.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.caption("Held", v)
	var names: Array = []
	for id in game.hero_list:
		names.append(tr(str(game.hero_defs[id].name)))
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 8)
	_choice_row(v, names, game.hero_list.find(game.hero_id), func(k):
		game.set_hero(str(game.hero_list[k]))
		game.save_settings()
		_fill_hero_info(info_box))
	v.add_child(info_box)
	_fill_hero_info(info_box)
	UiTheme.caption("Schwierigkeit", v)
	var diffs: Array = []
	for x in game.cfg.difficulties:
		diffs.append(tr(str(x.name)))
	var chosen := [clampi(Session.difficulty, 0, diffs.size() - 1)]
	_choice_row(v, diffs, chosen[0], func(k): chosen[0] = k)
	UiTheme.caption("Steuerung", v)
	_choice_row(v, [tr("WASD + Maus"), tr("Maus (wie WC3)")], 0 if game.control == "wasd" else 1, func(k):
		game.control = "wasd" if k == 0 else "maus"
		game.save_settings())
	UiTheme.caption("Straßen", v)
	_choice_row(v, [tr("2 (wie bei 1–3 Spielern)"), tr("alle 4")], 1 if game.road_choice == 4 else 0, func(k):
		game.road_choice = 4 if k == 1 else 0
		game.save_settings())
	_warn_options(v)
	var go := UiUtil.button("Start", v, func(): game.start(chosen[0]))
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)
	go.custom_minimum_size.y = 46
	UiUtil.button("Zurück zum Menü", v, func(): game.leave())


## Karte des gewählten Helden im Startfenster; bei Zix darunter der Baukasten.
func _fill_hero_info(box: VBoxContainer) -> void:
	for c in box.get_children():
		c.queue_free()
	var hd: Dictionary = game.hero.def
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.PURPLE, 0, 2, 12))
	box.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)
	_label("%s · %s · %s" % [tr(str(hd.name)), tr(str(hd.title)), tr(str(hd.get("role", "")))], cv, 16, UiTheme.PURPLE_LIGHT, true)
	var lines: Array = []
	if hd.has("passive"):
		lines.append(tr("Passiv %s: %s") % [tr(str(hd.passive.name)), tr(str(hd.passive.desc))])
	if hd.has("kit_desc"):
		lines.append(tr(str(hd.kit_desc)))
	for slot in 4:
		if game.hero.has_method("kit") and slot < 3:
			continue
		var a: Dictionary = game.hero.ability(slot)
		lines.append("%s: %s" % [tr(str(a.name)), tr(str(a.desc))])
	var info := _label("\n".join(lines), cv, 12, UiTheme.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 580
	if game.hero.has_method("kit"):
		_kit_picker(box)


## Zix: 3 von 10 Gebäuden wählen. Ein Klick nimmt ein Gebäude dazu bzw. heraus; bei 3 gewählten
## ersetzt ein neues das zuletzt gewählte.
func _kit_picker(parent: Node) -> void:
	UiTheme.caption("Baukasten (3 wählen)", parent)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	var ids: Array = game.gadget_defs.keys()
	var buttons: Array = []
	var desc := _label("", parent, 12, UiTheme.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 580
	var paint := func():
		var keys: Array = []
		for k in ids.size():
			var b: Button = buttons[k]
			var on: bool = game.zix_kit.has(ids[k])
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN) if on else UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER))
			b.add_theme_color_override("font_color", UiTheme.BG if on else UiTheme.TEXT)
		for i in game.zix_kit.size():
			var g: Dictionary = game.gadget_defs[game.zix_kit[i]]
			keys.append("%s %s: %s" % [game.key_name(i), tr(str(g.name)), tr(str(g.desc))])
		desc.text = "\n".join(keys)
	for k in ids.size():
		var id: String = ids[k]
		var g: Dictionary = game.gadget_defs[id]
		var b := UiUtil.button(str(g.name), grid, func():
			var kit: Array = game.zix_kit.duplicate()
			if kit.has(id):
				if kit.size() > 1:
					kit.erase(id)
			elif kit.size() >= 3:
				kit[2] = id
			else:
				kit.append(id)
			if kit.size() == 3:
				game.set_zix_kit(kit)
			else:
				game.zix_kit = kit
			paint.call())
		b.tooltip_text = "%s\n%s\n%s %s" % [tr(str(g.role)), tr(str(g.desc)), tr("Überspannung:"), tr(str(g.over))]
		b.custom_minimum_size = Vector2(108, 34)
		b.add_theme_font_size_override("font_size", 12)
		buttons.append(b)
	paint.call()
## Barrierefreiheit: Farbe und Umriss der gegnerischen Warnflächen (gilt für neue Flächen).
func _warn_options(v: VBoxContainer) -> void:
	UiTheme.caption("Warnflächen", v)
	var cols: Array = []
	for pl in HdTelegraph.PALETTES:
		cols.append(tr(str(pl.name)))
	_choice_row(v, cols, HdTelegraph.palette, func(k):
		HdTelegraph.palette = k
		game.save_settings())
	var outs: Array = []
	for o in HdTelegraph.OUTLINES:
		outs.append(tr(str(o)))
	_choice_row(v, outs, HdTelegraph.outline, func(k):
		HdTelegraph.outline = k
		game.save_settings())


func toggle_menu() -> void:
	if game.state != "play":
		return
	if _overlay:
		_close_overlay()
		game.paused = false
		return
	game.paused = true
	var v := _open_overlay(460)
	var t := Label.new()
	t.text = tr("Pause")
	UiTheme.title(t, 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var go := UiUtil.button("Weiterspielen", v, func():
		_close_overlay()
		game.paused = false)
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)
	UiTheme.caption("Steuerung", v)
	_choice_row(v, [tr("WASD + Maus"), tr("Maus (wie WC3)")], 0 if game.control == "wasd" else 1, func(k):
		game.control = "wasd" if k == 0 else "maus"
		game.hero.order = {}
		game.save_settings()
		refresh())
	var qc := CheckBox.new()
	qc.text = tr("Schnellzauber im Maus-Modus (ohne Zielvorschau)")
	qc.button_pressed = game.quickcast
	qc.toggled.connect(func(on):
		game.quickcast = on
		game.save_settings())
	v.add_child(qc)
	_warn_options(v)
	if game.hero.has_method("kit"):
		if game.can_change_kit():
			_kit_picker(v)
		else:
			var note := _label(tr("Baukasten ändern: zwischen den Wellen, wenn kein Gegner mehr auf dem Feld ist."), v, 12, UiTheme.MUTED)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiUtil.button("Neu starten", v, func(): game.restart())
	UiUtil.button("Zurück zum Menü", v, func(): game.leave())
	refresh()


func _show_end(victory: bool) -> void:
	var v := _open_overlay(560)
	var t := Label.new()
	t.text = tr("Die Feste hält!") if victory else tr("Die Feste ist gefallen")
	UiTheme.title(t, 34)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h: HdHero = game.hero
	var lines: Array = [
		tr("Welle %d / %d") % [game.wave, int(game.cfg.waves.count)],
		tr("Feste %d / %d") % [game.lives, game.max_lives],
		tr("Kills %d") % game.kills,
		tr("%s Stufe %d: %d Schaden, %d mal ausgewichen, %d mal gefallen") % [tr(str(h.def.name)), h.level, roundi(h.damage_done), h.dodges, h.deaths],
		tr("Punkte %d") % game.score(),
		tr("Spielzeit %d:%02d") % [int(game.play_time) / 60, int(game.play_time) % 60],
	]
	var l := _label("\n".join(lines), v, 15, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not game.result_news.is_empty():
		_label(tr("Neuer Rekord!"), v, 15, UiTheme.COIN, true)
	var go := UiUtil.button("Nochmal", v, func(): game.restart())
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)
	UiUtil.button("Zurück zum Menü", v, func(): game.leave())
