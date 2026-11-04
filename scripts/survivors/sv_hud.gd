class_name SvHud
extends CanvasLayer
## Oberfläche von Tower Survivors im Arcade-Stil (UiTheme): Leiste oben (Welle, Zeit, Gold, Tempo),
## Turm-Werte links, Laden rechts (Waffen + Upgrades), Montageplätze unten, dazu Startfenster,
## Bonus-Wahl, Spielmenü und Endbildschirm. Liest SvGame, Aktionen rufen dessen Befehle.

const SHOP_W := 360.0

var game  ## SvGame
var root: Control
var _wave: Label
var _wave_bar: ProgressBar
var _gold: Label
var _kills: Label
var _dps: Label
var _speed_buttons: Array = []
var _pause_button: Button
var _hp_bar: ProgressBar
var _hp_label: Label
var _stats: Label
var _perk_list: Label
var _offer_cards: Array = []     ## {panel, rarity, name, info, button}
var _reroll: Button
var _upgrade_rows: Array = []    ## {id, level, button}
var _slot_cards: Array = []      ## {panel, name, info, sell}
var _banner: Label
var _banner_t := 0.0
var _overlay: Control            ## Setup, Bonus, Menü, Ende (eins zur Zeit)
var _overlay_kind := ""
var _tick := 0.0


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_build_top()
	_build_left()
	_build_shop()
	_build_slots()
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 90
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	UiTheme.title(_banner, 34)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	game.changed.connect(refresh)
	game.message.connect(show_banner)
	game.perk_offered.connect(_show_perks)
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
	t.text = "Tower Survivors"
	UiTheme.title(t, 20)
	h.add_child(t)
	var wv := VBoxContainer.new()
	wv.custom_minimum_size.x = 260
	h.add_child(wv)
	_wave = _label("", wv, 15, UiTheme.TEXT, true)
	_wave_bar = _bar(wv, UiTheme.CYAN, 8)
	_gold = _label("", h, 18, UiTheme.COIN, true)
	_kills = _label("", h, 15, UiTheme.TEXT)
	_dps = _label("", h, 15, UiTheme.MUTED)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	_pause_button = UiUtil.button("Pause", h, func():
		game.paused = not game.paused
		refresh())
	for s in [1, 2, 3]:
		var b := UiUtil.button("%d×" % s, h, func(): _set_speed(s))
		b.toggle_mode = true
		_speed_buttons.append(b)
	UiUtil.button("Menü", h, toggle_menu)


func _build_left() -> void:
	var p := _panel(root, 12)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	p.position = Vector2(12, 78)
	p.custom_minimum_size = Vector2(270, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	UiTheme.caption("Turm", v)
	_hp_bar = _bar(v, UiTheme.HAVE, 18)
	_hp_label = _label("", v, 14, UiTheme.TEXT, true)
	_stats = _label("", v, 13, UiTheme.DIM)
	UiTheme.caption("Boni", v)
	_perk_list = _label("", v, 13, UiTheme.PURPLE_LIGHT)
	_perk_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_perk_list.custom_minimum_size.x = 246
	var hint := _label("Q/E drehen · Mausrad zoomt · Leertaste Pause · R neu würfeln", v, 11, UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 246


func _build_shop() -> void:
	var p := _panel(root, 12)
	p.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	p.offset_left = -SHOP_W - 12
	p.offset_right = -12
	p.offset_top = 78
	p.offset_bottom = -12
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var cap := UiTheme.caption("Waffen", head)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll = UiUtil.button("", head, func(): game.reroll())
	_reroll.tooltip_text = tr("Neue Auswahl im Laden (R). Jede Welle gibt es eine neue kostenlos.")
	for i in int(game.cfg.shop.offers):
		var card := PanelContainer.new()
		v.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		card.add_child(cv)
		var top := HBoxContainer.new()
		cv.add_child(top)
		var nm := _label("", top, 15, UiTheme.TEXT, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rar := _label("", top, 11)
		var info := _label("", cv, 12, UiTheme.DIM)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size.x = SHOP_W - 60
		var b := Button.new()
		b.pressed.connect(func(): game.buy_offer(i))
		cv.add_child(b)
		_offer_cards.append({"panel": card, "rarity": rar, "name": nm, "info": info, "button": b})
	UiTheme.caption("Upgrades", v)
	for u in game.cfg.upgrades:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var lv := VBoxContainer.new()
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.add_theme_constant_override("separation", 0)
		row.add_child(lv)
		var nm := _label("", lv, 14, UiTheme.TEXT, true)
		var d := _label(str(u.desc), lv, 11, UiTheme.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 190
		var id := str(u.id)
		var b := Button.new()
		b.custom_minimum_size.x = 96
		b.pressed.connect(func(): game.buy_upgrade(id))
		row.add_child(b)
		_upgrade_rows.append({"id": id, "name": nm, "button": b})


func _build_slots() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	h.grow_horizontal = Control.GROW_DIRECTION_BOTH
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	h.position.y -= 14
	h.offset_left -= SHOP_W * 0.5
	h.offset_right -= SHOP_W * 0.5
	root.add_child(h)
	for i in game.platform.SLOTS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(176, 104)
		h.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var nm := _label("", v, 14, UiTheme.TEXT, true)
		nm.clip_text = true
		var info := _label("", v, 12, UiTheme.DIM)
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sp)
		var sell := Button.new()
		sell.add_theme_font_size_override("font_size", 12)
		sell.pressed.connect(func(): game.sell(i))
		v.add_child(sell)
		_slot_cards.append({"panel": card, "name": nm, "info": info, "sell": sell})


func _set_play_visible(on: bool) -> void:
	for c in root.get_children():
		if c != _overlay and c != _banner:
			c.visible = on


# ---------------------------------------------------------------- Anzeige

func on_started() -> void:
	_close_overlay()
	_set_play_visible(true)
	_set_speed(1)
	refresh()


func _set_speed(s: int) -> void:
	Engine.time_scale = float(s)
	for k in _speed_buttons.size():
		var b: Button = _speed_buttons[k]
		b.set_pressed_no_signal(k + 1 == s)
		if k + 1 == s:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_color_override("font_color", UiTheme.BG)
			b.add_theme_color_override("font_pressed_color", UiTheme.BG)
		else:
			for k2 in ["normal", "pressed"]:
				b.remove_theme_stylebox_override(k2)
			b.remove_theme_color_override("font_color")
			b.remove_theme_color_override("font_pressed_color")


func _process(dt: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= dt / maxf(Engine.time_scale, 0.01)
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	_tick -= dt
	if _tick <= 0.0 and game.state != "setup":
		_tick = 0.2
		refresh()


func show_banner(text: String) -> void:
	_banner.text = text
	_banner_t = 2.2
	_banner.modulate.a = 1.0


func refresh() -> void:
	if game.state == "setup":
		return
	if _overlay_kind == "perk" and game.state != "perk":
		_close_overlay()
	var wv: Dictionary = game.cfg.waves
	var dur := float(wv.duration)
	_wave.text = tr("WELLE %d / %d   noch %ds") % [game.wave, int(wv.count), maxi(0, ceili(dur - game.wave_time))]
	_wave_bar.max_value = dur
	_wave_bar.value = minf(game.wave_time, dur)
	_gold.text = tr("%d Gold  +%.0f/s") % [int(game.gold), game.income()]
	_kills.text = tr("Kills %d") % game.kills
	_dps.text = tr("DPS %d") % roundi(game.total_dps())
	_pause_button.text = tr("Weiter") if game.paused else tr("Pause")
	var mh: float = game.max_hp()
	_hp_bar.max_value = mh
	_hp_bar.value = game.hp
	_hp_label.text = tr("Leben %d / %d") % [roundi(game.hp), roundi(mh)]
	_stats.text = "\n".join([
		tr("Rüstung %d (−%d %% Schaden)") % [roundi(game.armor()), roundi(100.0 * game.armor() * 0.05 / (1.0 + game.armor() * 0.05))],
		tr("Reparatur %.1f / s") % game.regen(),
		tr("Dornen %d %%") % roundi(game.thorns() * 100.0),
		tr("Schaden +%d %%   Tempo +%d %%") % [roundi(game.mod("damage") * 100.0), roundi(game.mod("rate") * 100.0)],
		tr("Reichweite +%d %%") % roundi(game.mod("range") * 100.0),
	])
	var pk: Array = []
	for id in game.perks:
		pk.append(tr(str(game.perk_defs[id].name)))
	_perk_list.text = ", ".join(pk) if not pk.is_empty() else tr("alle 5 Wellen einer aus drei")
	_reroll.text = tr("Neu würfeln %d") % game.reroll_price()
	_reroll.disabled = game.gold < game.reroll_price() or game.state != "play"
	for i in _offer_cards.size():
		_fill_offer(i)
	for r in _upgrade_rows:
		var u: Dictionary = game.upgrade_defs[r.id]
		var lv: int = game.upgrade_level(r.id)
		r.name.text = "%s  %d/%d" % [tr(str(u.name)), lv, int(u.max)]
		var cost: int = game.upgrade_price(r.id)
		var b: Button = r.button
		b.text = tr("max") if cost < 0 else "%d" % cost
		b.disabled = cost < 0 or game.gold < cost or game.state != "play"
	for i in _slot_cards.size():
		_fill_slot(i)


func _fill_offer(i: int) -> void:
	var c: Dictionary = _offer_cards[i]
	var id: String = game.offers[i] if i < game.offers.size() else ""
	var b: Button = c.button
	if id == "":
		c.panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 0, 2, 8))
		c.name.text = tr("gekauft")
		c.name.add_theme_color_override("font_color", UiTheme.MUTED)
		c.rarity.text = ""
		c.info.text = ""
		b.visible = false
		return
	var w: Dictionary = game.weapon_defs[id]
	var rc: Color = game.rarity_color(str(w.rarity))
	c.panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, rc, 0, 2, 8))
	c.name.text = tr(str(w.name))
	c.name.add_theme_color_override("font_color", UiTheme.TEXT)
	c.rarity.text = tr(str(game.cfg.rarities[str(w.rarity)].name)).to_upper()
	c.rarity.add_theme_color_override("font_color", rc)
	var tname := tr(str(game.cfg.damage_types[str(w.type)].name))
	c.info.text = "%s · %s\n%s" % [tname, _numbers(w), tr(str(w.desc))]
	c.info.add_theme_color_override("font_color", UiTheme.DIM)
	b.visible = true
	var cost: int = game.price(id)
	var slot: int = game.target_slot(id)
	var owned = game.weapons[slot] if slot >= 0 else null
	if slot < 0:
		b.text = tr("Kein freier Platz")
	elif owned != null:
		b.text = tr("Stufe %d · %d Gold") % [owned.level + 1, cost]
	else:
		b.text = tr("Kaufen · %d Gold") % cost
	b.disabled = slot < 0 or game.gold < cost or game.state != "play"


## Kurzwerte einer Waffe auf Stufe 1: Schaden, Takt, Reichweite.
func _numbers(w: Dictionary) -> String:
	var s := tr("%d Schaden") % int(w.damage)
	if int(w.get("shots", 1)) > 1:
		s += " ×%d" % int(w.shots)
	return s + tr(" · alle %.2fs · %d m") % [float(w.cooldown), roundi(float(w.range))]


func _fill_slot(i: int) -> void:
	var c: Dictionary = _slot_cards[i]
	var p: PanelContainer = c.panel
	var sell: Button = c.sell
	if i >= game.slots_open:
		p.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.BG, 0.85), UiTheme.BORDER, 0, 2, 8))
		c.name.text = tr("GESPERRT")
		c.name.add_theme_color_override("font_color", UiTheme.MUTED)
		c.info.text = tr("Upgrade Montageplatz")
		sell.visible = false
		return
	var w = game.weapons[i]
	if w == null:
		p.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PANEL, 0.9), UiTheme.BORDER_2, 0, 2, 8))
		c.name.text = tr("FREI")
		c.name.add_theme_color_override("font_color", UiTheme.MUTED)
		c.info.text = tr("Waffe im Laden kaufen")
		sell.visible = false
		return
	var rc: Color = game.rarity_color(str(w.data.rarity))
	p.add_theme_stylebox_override("panel", UiTheme.panel(8, 0.95, rc))
	c.name.text = tr(str(w.data.name))
	c.name.add_theme_color_override("font_color", game.type_color(w.type()))
	var stars := "■".repeat(w.level) + "□".repeat(int(game.cfg.max_level) - w.level)
	c.info.text = "%s\n%s" % [stars, tr("DPS %d · %d Kills") % [roundi(w.dps()), w.kills]]
	sell.visible = true
	sell.text = tr("Verkaufen +%d") % roundi(float(game.paid[i]) * float(game.cfg.sell_factor))
	sell.disabled = game.state == "over"


# ---------------------------------------------------------------- Fenster

func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	_overlay_kind = ""


## Abgedunkelter Hintergrund mit einem Panel in der Mitte, gibt die VBox des Panels zurück.
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


func show_setup() -> void:
	_set_play_visible(false)
	var v := _open_overlay(560)
	var t := Label.new()
	t.text = "Tower Survivors"
	UiTheme.title(t, 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := _label("Ein Turm, sechs Montageplätze, Gegner von allen Seiten. Kauf Waffen und bau sie auf die Plattform, gleiche Waffe nochmal kaufen hebt ihre Stufe. Überlebe 30 Wellen.", v, 14, UiTheme.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.caption("Schwierigkeit", v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var chosen := [clampi(Session.difficulty, 0, game.cfg.difficulties.size() - 1)]
	var buttons: Array = []
	var paint := func():
		for k in buttons.size():
			var b: Button = buttons[k]
			if k == chosen[0]:
				b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
				b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
				b.add_theme_color_override("font_color", UiTheme.BG)
				b.add_theme_color_override("font_hover_color", UiTheme.BG)
			else:
				for s in ["normal", "hover"]:
					b.remove_theme_stylebox_override(s)
				b.remove_theme_color_override("font_color")
				b.remove_theme_color_override("font_hover_color")
	for k in game.cfg.difficulties.size():
		var b := UiUtil.button(str(game.cfg.difficulties[k].name), row, func():
			chosen[0] = k
			paint.call())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(b)
	paint.call()
	var go := UiUtil.button("Start", v, func(): game.start(chosen[0]))
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)
	go.custom_minimum_size.y = 46
	UiUtil.button("Zurück zum Menü", v, func(): game.leave())


func _show_perks(ids: Array) -> void:
	var v := _open_overlay(820)
	_overlay_kind = "perk"
	var t := Label.new()
	t.text = tr("Bonus nach Welle %d") % game.wave
	UiTheme.title(t, 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	for i in ids.size():
		var p: Dictionary = game.perk_defs[ids[i]]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.PURPLE, 0, 2, 12))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)
		_label(str(p.name), cv, 17, UiTheme.PURPLE_LIGHT, true)
		var d := _label(str(p.desc), cv, 13, UiTheme.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(200, 54)
		var b := UiUtil.button("Nehmen", cv, func():
			_close_overlay()
			game.choose_perk(i))
		UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.GOLD_DARK)


func toggle_menu() -> void:
	if game.state == "setup" or game.state == "over" or game.state == "perk":
		return
	if _overlay:
		_close_overlay()
		game.paused = false
		return
	game.paused = true
	var v := _open_overlay(420)
	var t := Label.new()
	t.text = tr("Pause")
	UiTheme.title(t, 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var go := UiUtil.button("Weiterspielen", v, func():
		_close_overlay()
		game.paused = false)
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)
	UiUtil.button("Neu starten", v, func(): game.restart())
	UiUtil.button("Zurück zum Menü", v, func(): game.leave())
	refresh()


func _show_end(victory: bool) -> void:
	var v := _open_overlay(560)
	var t := Label.new()
	t.text = tr("Überlebt!") if victory else tr("Turm zerstört")
	UiTheme.title(t, 34)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var lines: Array = [
		tr("Welle %d / %d") % [game.wave, int(game.cfg.waves.count)],
		tr("Kills %d") % game.kills,
		tr("Punkte %d") % game.score(),
		tr("Spielzeit %d:%02d") % [int(game.play_time) / 60, int(game.play_time) % 60],
	]
	_label("\n".join(lines), v, 16, UiTheme.TEXT)
	UiTheme.caption("Waffen", v)
	var ws: Array = game.weapons.filter(func(w): return w != null)
	ws.sort_custom(func(a, b): return a.damage_done > b.damage_done)
	for w in ws:
		_label(tr("%s Stufe %d: %d Schaden, %d Kills") % [tr(str(w.data.name)), w.level, roundi(w.damage_done), w.kills], v, 13, game.type_color(w.type()))
	if not game.result_news.is_empty():
		_label(tr("Neuer Rekord!"), v, 15, UiTheme.COIN, true)
	var go := UiUtil.button("Nochmal", v, func(): game.restart())
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)
	UiUtil.button("Zurück zum Menü", v, func(): game.leave())
