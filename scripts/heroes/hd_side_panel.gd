class_name HdSideUi
extends Control
## Seitenleiste rechts im Arcade-Stil (Bollwerk Etappe 3), Teil von HdHud:
## - Ereignis-Karte: Entscheidung (Blutmond, Schrein) mit Knöpfen und Restzeit, Wanderhändler mit
##   Kaufknöpfen, Stand von Karawane/Gefangenem/Segen.
## - Zonen-Karte, solange der Held in einer Sonderzone steht: Arena (Wächter rufen), Holzhain
##   (Holzfäller), Schmiede (Edelstein wählen, Items veredeln/Stein einsetzen), Prüfungen (starten).
## - Ausblick: nächster Kriegsherr mit Welle und Straße.
## Alle Aktionen über HdShop.act(cmd).

var game  ## HdGame
var shop: HdShop
var gem_pick := "rubin"
var _box: VBoxContainer
var _panel_node: PanelContainer
var _sig := ""


func _init(g) -> void:
	game = g
	shop = g.shop
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_panel_node = PanelContainer.new()
	_panel_node.add_theme_stylebox_override("panel", UiTheme.panel(12))
	_panel_node.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel_node.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel_node.offset_right = -12
	_panel_node.offset_top = 92
	_panel_node.custom_minimum_size.x = 340
	add_child(_panel_node)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_panel_node.add_child(_box)


func _label(text: String, parent: Node, size := 13, color := UiTheme.TEXT, bold := false, wrap := false) -> Label:
	var l := UiUtil.label(text, parent, size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 310
	return l


func _say(why: String) -> void:
	if why != "" and why != "?":
		game.message.emit(why)
	refresh(true)


func _button(text: String, parent: Node, why: String, cb: Callable, main := false) -> Button:
	var b := UiUtil.button(text, parent, cb)
	b.disabled = why != ""
	b.tooltip_text = why
	b.add_theme_font_size_override("font_size", 12)
	if main and why == "":
		UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.GOLD_DARK)
	return b


func _sep() -> void:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator", UiTheme.box(UiTheme.BORDER, Color.TRANSPARENT, 0, 0, 0))
	s.custom_minimum_size.y = 6
	_box.add_child(s)


# ---------------------------------------------------------------- Aufbau

func _signature() -> String:
	var z: HdZones = game.zones
	var ev: HdEvents = game.events
	var parts: Array = [z.hero_zone(), shop.gold / 10, shop.wood, shop.marks, str(shop.inv), str(shop.merchant), gem_pick,
		str(ev.choice.get("id", "")), ceili(float(ev.choice.get("until", 0.0)) - game.play_time), ev.status(),
		z.arena_wins, z.arena_fight != null, z.lumberjacks, str(z.trial.get("kills", "")), ceili(float(z.trial.get("t", 0.0))),
		str(z.trial_done), game.wave, game.boss_warned, str(game.final.lines()), _clock_text()]
	if z.arena_fight != null:
		parts.append(roundi(z.arena_fight.hp / z.arena_fight.max_hp * 20.0))
	return str(parts)


func refresh(force := false) -> void:
	if game.state != "play":
		_panel_node.visible = false
		return
	var sig := _signature()
	if sig == _sig and not force:
		return
	_sig = sig
	for c in _box.get_children():
		c.queue_free()
	var any := false
	if game.final.active:
		_fill_final()
		_panel_node.visible = true
		return
	any = _fill_event() or any
	var zid: String = game.zones.hero_zone()
	if zid != "":
		if any:
			_sep()
		_fill_zone(zid)
		any = true
	if _fill_outlook(any):
		any = true
	_panel_node.visible = any


func _fill_event() -> bool:
	var ev: HdEvents = game.events
	var id := str(ev.choice.get("id", ev.active.get("id", ev.kinds.task.get("id", ""))))
	var st = ev.status()
	if id == "" and st == "":
		return false
	UiTheme.caption("Ereignis", _box)
	if id != "":
		var d = ev.def(id)
		_label(tr(str(d.name)), _box, 17, UiTheme.GOLD, true)
		_label(tr(str(d.get("desc", ""))), _box, 12, UiTheme.MUTED, false, true)
	if not ev.choice.is_empty():
		var left := ceili(float(ev.choice.until) - game.play_time)
		_label(tr("Abstimmung: deine Stimme entscheidet · noch %d s") % left, _box, 12, UiTheme.CYAN)
		var opts: Array = ev.choice.options
		for i in opts.size():
			var k := i
			var why := ""
			if str(ev.choice.id) == "schrein" and i == 0 and game.lives <= int(ev.def("schrein").lives):
				why = tr("Die Feste hat zu wenig Leben")
			elif str(ev.choice.id) == "schrein" and i == 1 and shop.gold < ev._shrine_gold():
				why = tr("Zu wenig Gold")
			elif str(ev.def(str(ev.choice.id)).get("kind", "")) == "wahl":
				why = ev.kinds.can_pick(ev.def(str(ev.choice.id)), i)
			var b := _button(str(opts[i]), _box, why, func(): _say(shop.act({"kind": "event", "pick": k})), i == 0)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in shop.merchant.size():
		var m: Dictionary = shop.merchant[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		_box.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		_label(tr(str(shop.item(str(m.id)).name)), v, 13, shop.tier_color(str(m.id)), true)
		_label(HdShop.stat_text(shop.item(str(m.id)).get("stats", {})), v, 11, UiTheme.DIM, false, false).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var k := i
		var b := _button(tr("Verkauft") if bool(m.get("sold", false)) else tr("%d Gold") % int(m.price), h, shop.can_buy_merchant(i),
			func(): _say(shop.act({"kind": "merchant", "i": k})))
		b.custom_minimum_size.x = 92
	if st != "":
		_label(st, _box, 12, UiTheme.TEXT, true, true)
	return true


## Restzeit bis zum nächsten Ereignis („" = Uhr steht).
func _clock_text() -> String:
	var c = game.systems.get("timed_events")
	if c == null or not c.running():
		return ""
	var r := ceili(c.remaining())
	return tr("Nächstes Ereignis in %d:%02d") % [r / 60, r % 60]


## Endgebiet: Challenges, Weckuhr des Verschlingers (vorläufig, Mockup folgt).
func _fill_final() -> void:
	UiTheme.caption("Endgebiet", _box)
	var lines: Array = game.final.lines()
	for i in lines.size():
		_label(str(lines[i]), _box, 17 if i == 0 else 13, UiTheme.GOLD if i == 0 else UiTheme.TEXT, i == 0, true)


func _fill_zone(zid: String) -> void:
	var z: HdZones = game.zones
	var d := z.def(zid)
	UiTheme.caption("Sonderzone", _box)
	_label(tr(str(d.name)), _box, 17, UiTheme.GOLD, true)
	_label(tr(str(d.get("desc", ""))), _box, 12, UiTheme.MUTED, false, true)
	if not z.is_open(zid):
		_label(tr("Öffnet ab Welle %d") % int(d.open), _box, 13, UiTheme.MISSING, true)
		return
	match zid:
		"arena":
			_label(tr("Siege %d · Arena-Marken %d") % [z.arena_wins, shop.marks], _box, 13, UiTheme.TEXT)
			if z.arena_fight != null:
				_label(tr("Wächter: %d %% Leben") % roundi(z.arena_fight.hp / z.arena_fight.max_hp * 100.0), _box, 13, UiTheme.MISSING, true)
			else:
				var b := _button(tr("Wächter rufen (Runde %d)") % (z.arena_wins + 1), _box, z.can_arena(), func(): _say(shop.act({"kind": "arena"})), true)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_label(tr("Je Sieg dauerhaft: %s") % HdShop.stat_text(game.cfg.zones.arena.bonus), _box, 11, UiTheme.DIM, false, true)
		"hain":
			var lj: Dictionary = game.cfg.zones.hain.lumberjack
			_label(tr("Holzfäller %d / %d · je %d Holz alle %d s") % [z.lumberjacks, int(lj.max), int(lj.wood), int(lj.interval)], _box, 13, UiTheme.HAVE)
			var b := _button(tr("Holzfäller anheuern %d Gold") % int(lj.price), _box, z.can_lumberjack(), func(): _say(shop.act({"kind": "lumberjack"})), true)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		"schmiede":
			_fill_forge()
		"pruefung":
			if not z.trial.is_empty():
				var td: Dictionary = z.trial.def
				var left := ceili(float(td.time) - float(z.trial.t))
				var txt := tr("%s: %d / %d · noch %d s") % [tr(str(td.name)), int(z.trial.kills), int(td.count), left] if str(td.kind) == "kills" \
					else tr("%s: noch %d s ohne Treffer") % [tr(str(td.name)), left]
				_label(txt, _box, 14, UiTheme.CYAN, true)
			for t in game.cfg.zones.pruefungen.list:
				var id := str(t.id)
				var h := HBoxContainer.new()
				_box.add_child(h)
				var v := VBoxContainer.new()
				v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				v.add_theme_constant_override("separation", 0)
				h.add_child(v)
				_label(tr(str(t.name)), v, 13, UiTheme.TEXT, true)
				_label(tr(str(t.desc)), v, 11, UiTheme.DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				var why := z.can_trial(id)
				var b := _button(tr("Starten") if z.trial_wait(id) == 0 else tr("in %d W.") % z.trial_wait(id), h, why, func(): _say(shop.act({"kind": "trial", "id": id})), true)
				b.custom_minimum_size.x = 86


func _fill_forge() -> void:
	var z: HdZones = game.zones
	var sm: Dictionary = game.cfg.zones.schmiede
	_label(tr("Edelstein wählen (%d Gold):") % int(sm.gem_price), _box, 12, UiTheme.TEXT)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_box.add_child(grid)
	for gm in sm.gems:
		var gid := str(gm.id)
		var b := UiUtil.button(tr(str(gm.name)), grid, func():
			gem_pick = gid
			refresh(true))
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = HdShop.stat_text(gm.stats)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c := Color(str(gm.color))
		if gid == gem_pick:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_color_override("font_color", UiTheme.BG)
		else:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_2, c))
			b.add_theme_color_override("font_color", c)
	_label(HdShop.stat_text(z.gem(gem_pick).get("stats", {})), _box, 11, UiTheme.DIM)
	var any := false
	for i in shop.inv.size():
		var x = shop.inv[i]
		if x == null or shop.consumable(str(x.id)):
			continue
		any = true
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 0, 2, 6))
		_box.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var up := int(x.get("up", 0))
		var gems: Array = []
		for gid in x.get("gems", []):
			gems.append(tr(str(z.gem(str(gid)).name)))
		_label("%s%s  ·  %s %d/%d" % [tr(str(shop.item(str(x.id)).name)), (" +%d" % up) if up > 0 else "", tr("Sockel"), gems.size(), z.sockets(x)],
			v, 13, shop.tier_color(str(x.id)), true)
		if not gems.is_empty():
			_label(", ".join(gems), v, 11, UiTheme.MUTED)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		var k := i
		var fail := roundi(z.fail_chance(x) * 100.0)
		var ut := tr("Höchste Stufe") if up >= int(sm.max) else (tr("+%d: %d Gold") % [up + 1, z.upgrade_cost(x)] + ((tr(" · %d %% Risiko") % fail) if fail > 0 else ""))
		var b1 := _button(ut, h, z.can_upgrade("hero", i), func(): _say(shop.act({"kind": "upgrade", "where": "hero", "i": k})), true)
		b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(tr("%s einsetzen") % tr(str(z.gem(gem_pick).name)), h, z.can_socket("hero", i, gem_pick),
			func(): _say(shop.act({"kind": "socket", "where": "hero", "i": k, "gem": gem_pick})))
	if not any:
		_label(tr("Keine Ausrüstung am Helden."), _box, 12, UiTheme.MUTED)
	_label(tr("Ab +3 kann das Veredeln fehlschlagen; das Item bleibt erhalten. Volle Sockel: der neue Stein ersetzt den ältesten."), _box, 11, UiTheme.DIM, false, true)


## Ausblick: nächster Kriegsherr (Welle, Straße ab der Ansage) und offene Sonderzonen.
func _fill_outlook(any: bool) -> bool:
	var ct := _clock_text()
	if ct != "":
		if any:
			_sep()
		_label(ct, _box, 12, UiTheme.CYAN, true)
		any = true
	var next := 0
	for n in range(game.wave + 1, game.wave_count() + 1):
		if game.is_boss_wave(n):
			next = n
			break
	if next == 0 or next - game.wave > 3:
		return ct != ""
	if any:
		_sep()
	UiTheme.caption("Kriegsherr", _box)
	var bd: Dictionary = game._boss_def(next)
	var where := tr("Straße wird 20 s vorher angesagt")
	if game.boss_warned and next == game.wave + 1:
		where = tr("landet vor der Feste") if bool(bd.get("land", false)) else tr("über die %s") % tr(game.boss_road.name)
	_label(tr("%s in Welle %d") % [tr(str(bd.name)), next], _box, 14, UiTheme.MISSING, true)
	_label(where, _box, 12, UiTheme.MUTED)
	return true
