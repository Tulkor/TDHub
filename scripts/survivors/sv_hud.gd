class_name SvHud
extends CanvasLayer
## Oberfläche von Tower Survivors im Hologramm-Stil (UiTheme.HOLO, Entwurf 1 „Cyan-Kommando“, Lukas 2026-11-04):
## Kopfleiste oben in der Mitte (Welle, Zeit, Gold, Kills, DPS) mit Tempo-Knöpfen, links Waffensysteme und
## Hülle, rechts Beschaffung und Aufrüsten, unten die Wellen-Zeitleiste. Auswahlkreis um Turm oder Waffe
## (SvHolo.SelRing). Dazu Startfenster, Bonus-Wahl, Spielmenü und Endbildschirm. Liest SvGame, Aktionen
## rufen dessen Befehle.

const COL_W := 300.0
const LINE := HoloTheme.LINE

var game  ## SvGame
var root: Control
var sel: SvHolo.SelRing
var _wave: Label
var _next: Label
var _gold: Label
var _income: Label
var _kills: Label
var _dps: Label
var _speed_buttons: Array = []
var _pause_button: Button
var _gauge: SvHolo.Gauge
var _stats: Label
var _graph: SvHolo.Graph
var _perk_list: Label
var _ruler: SvHolo.Ruler
var _offer_cards: Array = []     ## {panel, rarity, name, info, button}
var _reroll: Button
var _upgrade_rows: Array = []    ## {id, name, seg, level, button}
var _slot_cards: Array = []      ## {panel, name, info, seg, sell}
var _slot_count: Label
var _banner: Label
var _banner_t := 0.0
var _overlay: Control            ## Setup, Bonus, Menü, Ende (eins zur Zeit)
var _overlay_kind := ""
var _tick := 0.0
var _graph_t := 0.0


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	sel = SvHolo.SelRing.new()
	sel.game = game
	root.add_child(sel)
	_build_top()
	_build_left()
	_build_right()
	_build_bottom()
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = 132
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


func _panel(parent: Node, pad := 10.0, tab := false, ticks := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", HoloTheme.holo(pad, 1.0, LINE, tab, ticks))
	parent.add_child(p)
	return p


func _label(text: String, parent: Node, size := 15, color := Color.TRANSPARENT, bold := false) -> Label:
	var l := UiUtil.label(text, parent, size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	return l


## Kleine Schrift in Share Tech Mono (Zahlen, Kürzel).
func _mono(text: String, parent: Node, size := 12, color: Color = UiTheme.DIM) -> Label:
	var l := _label(text, parent, size, color)
	l.add_theme_font_override("font", HoloTheme.mono())
	return l


## Kopfzeile einer Tafel: Titel links, Kennung rechts (Share Tech Mono, Cyan).
func _head(parent: Node, title: String) -> Label:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var t := _mono(str(tr(title)).to_upper(), h, 12, LINE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _mono("", h, 12, LINE)


func _small_button(text: String, parent: Node, cb: Callable) -> Button:
	var b := UiUtil.button(text, parent, cb)
	b.add_theme_font_override("font", HoloTheme.mono())
	b.add_theme_font_size_override("font_size", 13)
	return b


# ---------------------------------------------------------------- Aufbau

func _build_top() -> void:
	var p := PanelContainer.new()
	var box := HoloTheme.holo(10)
	box.shape = "trap"
	box.content_margin_left = 34
	box.content_margin_right = 34
	box.content_margin_top = 4
	box.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", box)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.offset_left = -270
	p.offset_right = 270
	p.offset_top = 12
	root.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	var cell := func(cap: String) -> Label:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		h.add_child(v)
		_mono(str(tr(cap)).to_upper(), v, 11, LINE)
		var l := _label("", v, 26, UiTheme.TEXT, true)
		return l
	_wave = cell.call("Welle")
	_next = cell.call("Nächste")
	_gold = cell.call("Gold")
	_gold.add_theme_color_override("font_color", UiTheme.COIN)
	_kills = cell.call("Kills")
	_dps = cell.call("DPS")
	# Tempo und Menü darunter
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.offset_top = 84
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)
	_pause_button = _small_button("II", row, func():
		game.paused = not game.paused
		refresh())
	for s in [1, 2, 3]:
		var b := _small_button("%d×" % s, row, func(): _set_speed(s))
		b.toggle_mode = true
		_speed_buttons.append(b)
	_small_button(tr("Menü").to_upper(), row, toggle_menu)
	_income = _mono("", row, 12, UiTheme.COIN)


func _build_left() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.position = Vector2(16, 16)
	col.custom_minimum_size.x = COL_W
	root.add_child(col)
	# Waffensysteme: ein Eintrag je Montageplatz, Klick wählt die Waffe aus
	var p := _panel(col, 12, true, true)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	_slot_count = _head(v, "Waffensysteme")
	for i in game.platform.SLOTS:
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and game.weapons[i] != null:
				sel.select("slot", i)
				refresh())
		v.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 1)
		card.add_child(cv)
		var top := HBoxContainer.new()
		cv.add_child(top)
		var nm := _label("", top, 16, UiTheme.TEXT, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		var sell := _small_button("", top, func(): game.sell(i))
		sell.add_theme_font_size_override("font_size", 11)
		var bot := HBoxContainer.new()
		bot.add_theme_constant_override("separation", 8)
		cv.add_child(bot)
		var seg := SvHolo.Seg.new(int(game.cfg.max_level), Vector2(70, 6))
		seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bot.add_child(seg)
		var info := _mono("", bot, 12)
		_slot_cards.append({"panel": card, "name": nm, "info": info, "seg": seg, "sell": sell})
	# Hülle: Ringanzeige, Werte, Schadensverlauf, Boni
	var hp := _panel(col, 12)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	hp.add_child(hv)
	_head(hv, "Hülle / Integrität")
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 10)
	hv.add_child(hh)
	_gauge = SvHolo.Gauge.new(128)
	hh.add_child(_gauge)
	_stats = _mono("", hh, 12)
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mono(tr("SCHADENSVERLAUF"), hv, 10, Color(LINE, 0.8))
	_graph = SvHolo.Graph.new(Vector2(COL_W - 26, 36))
	hv.add_child(_graph)
	_perk_list = _mono("", hv, 12, UiTheme.PURPLE_LIGHT)
	_perk_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_perk_list.custom_minimum_size.x = COL_W - 26


func _build_right() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	col.offset_left = -COL_W - 16
	col.offset_right = -16
	col.offset_top = 16
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.custom_minimum_size.x = COL_W
	root.add_child(col)
	var p := _panel(col, 12, true)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	p.add_child(v)
	_head(v, "Beschaffung")
	for i in int(game.cfg.shop.offers):
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		v.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cv)
		var nm := _label("", cv, 16, UiTheme.TEXT, true)
		var rar := _mono("", cv, 11)
		var info := _mono("", cv, 11, UiTheme.MUTED)
		var b := _small_button("", row, func(): game.buy_offer(i))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 15)
		_offer_cards.append({"panel": card, "rarity": rar, "name": nm, "info": info, "button": b})
	_reroll = UiUtil.button("", v, func(): game.reroll())
	UiTheme.accent_button(_reroll, LINE, UiTheme.GOLD_DARK)
	_reroll.tooltip_text = tr("Neue Auswahl im Laden (R). Jede Welle gibt es eine neue kostenlos.")
	var up := _panel(col, 12, false, true)
	var uv := VBoxContainer.new()
	uv.add_theme_constant_override("separation", 4)
	up.add_child(uv)
	_head(uv, "Aufrüsten")
	for u in game.cfg.upgrades:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = tr(str(u.desc))
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		uv.add_child(row)
		var nm := _label(tr(str(u.name)).to_upper(), row, 14, UiTheme.TEXT, true)
		nm.custom_minimum_size.x = 104
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
		nm.tooltip_text = row.tooltip_text
		var seg := SvHolo.Seg.new(mini(int(u.max), 10), Vector2(64, 7))
		seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(seg)
		var lv := _mono("", row, 11, UiTheme.MUTED)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := str(u.id)
		var b := _small_button("", row, func(): game.buy_upgrade(id))
		b.custom_minimum_size.x = 56
		b.tooltip_text = row.tooltip_text
		_upgrade_rows.append({"id": id, "name": nm, "seg": seg, "level": lv, "button": b})


func _build_bottom() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.offset_bottom = -8
	root.add_child(v)
	var cap := _mono(tr("WELLEN-ZEITLEISTE · BOSS ALLE %d · BONUS ALLE %d") % [int(game.cfg.waves.boss_every), int(game.cfg.waves.perk_every)], v, 11, UiTheme.DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ruler = SvHolo.Ruler.new()
	_ruler.count = int(game.cfg.waves.count)
	_ruler.boss_every = int(game.cfg.waves.boss_every)
	_ruler.perk_every = int(game.cfg.waves.perk_every)
	v.add_child(_ruler)
	var hint := _mono(tr("Klick wählt aus · Q/E drehen · Mausrad zoomt · Leertaste Pause · R neu würfeln"), v, 11, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _set_play_visible(on: bool) -> void:
	for c in root.get_children():
		if c != _overlay and c != _banner:
			c.visible = on


# ---------------------------------------------------------------- Auswahl

## Klick ins Spielfeld (von SvGame): Waffe auf ihrem Platz, sonst der Turm, sonst Auswahl aufheben.
func pick(screen: Vector2) -> void:
	var cam: Camera3D = game.camera
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.001:
		sel.clear()
		return
	# Ebene etwas über dem Deck, dort sitzen die Waffen
	var y := SvPlatform.DECK_Y + 0.5
	var hit := o + d * ((y - o.y) / d.y)
	var best := -1
	var best_d := 1.15
	for i in game.platform.SLOTS:
		if game.weapons[i] == null:
			continue
		var p: Vector3 = game.platform.pads[i].root.global_position
		var dist := Vector2(hit.x - p.x, hit.z - p.z).length()
		if dist < best_d:
			best_d = dist
			best = i
	if best >= 0:
		sel.select("slot", best)
	elif Vector2(hit.x, hit.z).length() < SvPlatform.DECK_R + 0.6:
		sel.select("tower")
	else:
		sel.clear()
	refresh()


func deselect() -> bool:
	if not sel.has_selection():
		return false
	sel.clear()
	refresh()
	return true


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


func _process(dt: float) -> void:
	var real := dt / maxf(Engine.time_scale, 0.01)
	if _banner_t > 0.0:
		_banner_t -= real
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
	var left := maxi(0, ceili(dur - game.wave_time))
	_wave.text = "%02d/%d" % [game.wave, int(wv.count)]
	_next.text = "00:%02d" % left if left < 60 else "%d:%02d" % [left / 60, left % 60]
	_gold.text = "%d" % int(game.gold)
	_income.text = tr("+%.0f/S") % game.income()
	_kills.text = "%d" % game.kills
	_dps.text = "%d" % roundi(game.total_dps())
	# Schadensverlauf: eine Probe je Spielsekunde (läuft mit dem Spieltempo, auch im Zeitraffer der Bilder)
	if game.play_time < _graph_t:
		_graph_t = 0.0
	if game.state == "play" and game.play_time - _graph_t >= 1.0:
		_graph_t = game.play_time
		_graph.push(game.total_dps())
	_ruler.set_pos(float(game.wave - 1) + minf(game.wave_time / dur, 1.0))
	_pause_button.text = "▶" if game.paused else "II"
	var mh: float = game.max_hp()
	var f: float = game.hp / maxf(mh, 1.0)
	_gauge.set_value(f, "%d%%" % roundi(f * 100.0), "%d/%d" % [roundi(game.hp), roundi(mh)], LINE if f > 0.3 else UiTheme.MISSING)
	_stats.text = "\n".join([
		tr("PANZ ..... %d") % roundi(game.armor()),
		tr("REP .. %.1f/S") % game.regen(),
		tr("DORN ..... %d%%") % roundi(game.thorns() * 100.0),
		tr("SCHADEN . +%d%%") % roundi(game.mod("damage") * 100.0),
		tr("TEMPO ... +%d%%") % roundi(game.mod("rate") * 100.0),
		tr("REICHW .. +%d%%") % roundi(game.mod("range") * 100.0),
	])
	var pk: Array = []
	for id in game.perks:
		pk.append(tr(str(game.perk_defs[id].name)))
	_perk_list.text = tr("BONI: %s") % (", ".join(pk) if not pk.is_empty() else tr("alle 5 Wellen einer aus drei"))
	_reroll.text = tr("↻ NEU WÜRFELN · %d") % game.reroll_price()
	_reroll.disabled = game.gold < game.reroll_price() or game.state != "play"
	for i in _offer_cards.size():
		_fill_offer(i)
	for r in _upgrade_rows:
		var u: Dictionary = game.upgrade_defs[r.id]
		var lv: int = game.upgrade_level(r.id)
		r.seg.set_value(float(lv) / float(u.max))
		r.level.text = "%d/%d" % [lv, int(u.max)]
		var cost: int = game.upgrade_price(r.id)
		var b: Button = r.button
		b.text = tr("MAX") if cost < 0 else "%d" % cost
		b.disabled = cost < 0 or game.gold < cost or game.state != "play"
	var armed := 0
	for i in _slot_cards.size():
		_fill_slot(i)
		if game.weapons[i] != null:
			armed += 1
	_slot_count.text = "%d/%d" % [armed, game.slots_open]


func _fill_offer(i: int) -> void:
	var c: Dictionary = _offer_cards[i]
	var id: String = game.offers[i] if i < game.offers.size() else ""
	var b: Button = c.button
	var p: PanelContainer = c.panel
	if id == "":
		p.add_theme_stylebox_override("panel", HoloTheme.frame(Color(LINE, 0.03), Color(LINE, 0.25), 9))
		c.name.text = tr("GEKAUFT")
		c.name.add_theme_color_override("font_color", UiTheme.MUTED)
		c.rarity.text = ""
		c.info.text = ""
		p.tooltip_text = ""
		b.visible = false
		return
	var w: Dictionary = game.weapon_defs[id]
	var rc: Color = game.rarity_color(str(w.rarity))
	p.add_theme_stylebox_override("panel", HoloTheme.frame(Color(rc, 0.08), rc, 9))
	c.name.text = tr(str(w.name)).to_upper()
	c.name.add_theme_color_override("font_color", UiTheme.TEXT)
	var tname := tr(str(game.cfg.damage_types[str(w.type)].name))
	c.rarity.text = "%s · %s" % [tr(str(game.cfg.rarities[str(w.rarity)].name)).to_upper(), tname.to_upper()]
	c.rarity.add_theme_color_override("font_color", rc)
	c.info.text = _numbers(w)
	p.tooltip_text = tr(str(w.desc))
	b.visible = true
	var cost: int = game.price(id)
	var slot: int = game.target_slot(id)
	var owned = game.weapons[slot] if slot >= 0 else null
	if slot < 0:
		b.text = tr("VOLL")
	elif owned != null:
		b.text = tr("STF %d · %d") % [owned.level + 1, cost]
	else:
		b.text = "%d" % cost
	b.disabled = slot < 0 or game.gold < cost or game.state != "play"


## Kurzwerte einer Waffe auf Stufe 1: Schaden, Takt, Reichweite.
func _numbers(w: Dictionary) -> String:
	var s := tr("%d SCH") % int(w.damage)
	if int(w.get("shots", 1)) > 1:
		s += " ×%d" % int(w.shots)
	return s + tr(" · %.2fS · %d M") % [float(w.cooldown), roundi(float(w.range))]


func _fill_slot(i: int) -> void:
	var c: Dictionary = _slot_cards[i]
	var p: PanelContainer = c.panel
	var sell: Button = c.sell
	var seg: SvHolo.Seg = c.seg
	if i >= game.slots_open:
		p.add_theme_stylebox_override("panel", HoloTheme.frame(Color(UiTheme.MISSING, 0.05), Color(UiTheme.MISSING, 0.45), 9))
		c.name.text = tr("P%d · GESPERRT") % (i + 1)
		c.name.add_theme_color_override("font_color", Color(UiTheme.MISSING, 0.9))
		c.info.text = tr("AUFRÜSTEN: MONTAGEPLATZ")
		seg.visible = false
		sell.visible = false
		return
	var w = game.weapons[i]
	if w == null:
		p.add_theme_stylebox_override("panel", HoloTheme.frame(Color(LINE, 0.03), Color(LINE, 0.3), 9))
		c.name.text = tr("P%d · FREI") % (i + 1)
		c.name.add_theme_color_override("font_color", UiTheme.MUTED)
		c.info.text = tr("WAFFE IM LADEN KAUFEN")
		seg.visible = false
		sell.visible = false
		return
	var rc: Color = game.rarity_color(str(w.data.rarity))
	var picked := sel.selected_slot() == i
	p.add_theme_stylebox_override("panel", HoloTheme.frame(Color(rc, 0.22 if picked else 0.08), Color.WHITE if picked else rc, 9))
	c.name.text = "P%d %s" % [i + 1, tr(str(w.data.name)).to_upper()]
	c.name.add_theme_color_override("font_color", UiTheme.TEXT)
	seg.visible = true
	seg.n = int(game.cfg.max_level)
	seg.set_value(float(w.level) / float(game.cfg.max_level), rc)
	c.info.text = tr("%s · %d DPS · %d K") % [tr(str(game.cfg.damage_types[w.type()].name)).to_upper(), roundi(w.dps()), w.kills]
	sell.visible = true
	sell.text = "+%d" % roundi(float(game.paid[i]) * float(game.cfg.sell_factor))
	sell.tooltip_text = tr("Verkaufen")
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
