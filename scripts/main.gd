extends Control
## Главное меню: матч, состав, магазин паков, коллекция.

const MatchViewScript := preload("res://scripts/match_view.gd")

var data: GameData
var tab := "home"
var content: VBoxContainer
var coins_label: Label
var nav_buttons := {}
var overlay: Control = null
var match_view: Control = null
var current_opp := ""


func _ready() -> void:
	data = GameData.load_or_new()
	_build_ui()
	_show_tab("home")


# ---------- помощники интерфейса ----------
func _sb(color: Color, radius := 12, border := 0, border_color := Color.WHITE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	s.set_content_margin_all(10)
	return s


func _label(text: String, size := 18, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, cb: Callable, color := Color("ffb400"), fcolor := Color("1b1300"), h := 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", fcolor)
	b.add_theme_color_override("font_hover_color", fcolor)
	b.add_theme_color_override("font_pressed_color", fcolor)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.add_theme_stylebox_override("normal", _sb(color))
	b.add_theme_stylebox_override("hover", _sb(color.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _sb(color.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", _sb(color.darkened(0.55)))
	b.pressed.connect(cb)
	return b


func _panel(parent: Control) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _sb(Color("13214a"), 14, 2, Color("2b4490")))
	parent.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	return vb


func _card(c: Dictionary, small := false, selected := false, cb := Callable()) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(96, 134) if small else Vector2(120, 168)
	if c.is_empty():
		pc.add_theme_stylebox_override("panel", _sb(Color("0d183a"), 12, 2, Color("2b4490")))
		var l := _label("пусто\n+", 16, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_CENTER)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pc.add_child(l)
	else:
		var r := GameData.rarity(int(c["ovr"]))
		var bcol := Color("ffc83d") if selected else Color(1, 1, 1, 0.5)
		pc.add_theme_stylebox_override("panel", _sb(GameData.rarity_color(r), 12, 4 if selected else 2, bcol))
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(_label(str(c["ovr"]), 28 if small else 34, Color("111111")))
		vb.add_child(_label(GameData.POS_LABEL[c["pos"]], 14, Color("222222")))
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(sp)
		var nm := _label(String(c["name"]), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		nm.add_theme_color_override("font_outline_color", Color.BLACK)
		nm.add_theme_constant_override("outline_size", 4)
		vb.add_child(nm)
		pc.add_child(vb)
	if cb.is_valid():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.pressed.connect(cb)
		pc.add_child(b)
	return pc


func _open_modal(width := 760) -> VBoxContainer:
	_close_modal()
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, 0)
	pc.add_theme_stylebox_override("panel", _sb(Color("13214a"), 16, 3, Color("2b4490")))
	center.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	return vb


func _close_modal() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null


# ---------- каркас ----------
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0b1530")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _sb(Color("16275a"), 0))
	root.add_child(header)
	var hb := HBoxContainer.new()
	header.add_child(hb)
	var title := _label("ICE LEGENDS", 26, Color("ffc83d"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(title)
	coins_label = _label("", 24, Color("ffc83d"), HORIZONTAL_ALIGNMENT_RIGHT)
	hb.add_child(coins_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	root.add_child(nav)
	for t in [["home", "Матч"], ["squad", "Состав"], ["shop", "Паки"], ["coll", "Коллекция"]]:
		var b := _btn(t[1], _show_tab.bind(t[0]), Color("1a2c5f"), Color("eaf1ff"), 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(b)
		nav_buttons[t[0]] = b


func _show_tab(t: String) -> void:
	tab = t
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	coins_label.text = "Монеты: %d" % data.coins
	for k in nav_buttons:
		var b: Button = nav_buttons[k]
		var col := Color("ffb400") if k == t else Color("1a2c5f")
		var fc := Color("1b1300") if k == t else Color("eaf1ff")
		b.add_theme_stylebox_override("normal", _sb(col, 0))
		b.add_theme_stylebox_override("hover", _sb(col.lightened(0.1), 0))
		b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.15), 0))
		b.add_theme_color_override("font_color", fc)
		b.add_theme_color_override("font_hover_color", fc)
		b.add_theme_color_override("font_pressed_color", fc)
	match t:
		"home":
			_tab_home()
		"squad":
			_tab_squad()
		"shop":
			_tab_shop()
		"coll":
			_tab_coll()


# ---------- вкладка «Матч» ----------
func _vs_side(big: String, small: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(_label(big, 52, Color("ffc83d"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_label(small, 18, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_CENTER))
	return v


func _stat_row(p: VBoxContainer, a: String, b: String) -> void:
	var h := HBoxContainer.new()
	var l := _label(a, 20, Color("8fa3d4"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(_label(b, 20))
	p.add_child(h)


func _tab_home() -> void:
	var opp := data.opponent_info()
	var p := _panel(content)
	p.add_child(_label("Сезон · матч %d" % (data.match_idx + 1), 26, Color("ffc83d")))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	row.add_child(_vs_side(str(data.team_ovr()), "Ваша команда"))
	row.add_child(_label("VS", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_vs_side(str(opp["ovr"]), String(opp["name"])))
	p.add_child(row)
	if not data.lineup_full():
		p.add_child(_label("Состав не заполнен — откройте вкладку «Состав».", 18, Color("ff8a85"), HORIZONTAL_ALIGNMENT_LEFT, true))
	var play := _btn("ИГРАТЬ", _start_match)
	play.disabled = not data.lineup_full()
	p.add_child(play)

	var st := _panel(content)
	st.add_child(_label("Статистика", 22, Color("ffc83d")))
	_stat_row(st, "Победы", str(data.wins))
	_stat_row(st, "Поражения", str(data.losses))
	_stat_row(st, "Забито / пропущено", "%d / %d" % [data.goals_for, data.goals_against])

	var hp := _panel(content)
	hp.add_child(_label("Как играть", 22, Color("ffc83d")))
	hp.add_child(_label("Левая половина экрана — джойстик. Вверх/вниз при броске выбирает угол ворот. БРОСОК — удар, ПАС — передача по направлению джойстика, ОТБОР — рывок за шайбой. Клавиатура: WASD или стрелки, Пробел — бросок, E — пас, Q — отбор, Esc — пауза.", 18, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_LEFT, true))
	hp.add_child(_label("За матчи вы получаете монеты: открывайте паки, собирайте звёзд и прокачивайте состав.", 18, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_LEFT, true))


# ---------- вкладка «Состав» ----------
func _slot_widget(slot: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	var c := data.card_by_id(int(data.lineup.get(slot, -1)))
	v.add_child(_card(c, true, false, func(): _pick_for_slot(slot)))
	v.add_child(_label(String(GameData.SLOT_LABEL[slot]), 15, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_CENTER))
	return v


func _lineup_row(slots: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for s in slots:
		row.add_child(_slot_widget(s))
	return row


func _tab_squad() -> void:
	var p := _panel(content)
	p.add_child(_label("Состав · рейтинг %d" % data.team_ovr(), 24, Color("ffc83d")))
	p.add_child(_lineup_row(["LW", "C", "RW"]))
	p.add_child(_lineup_row(["LD", "RD", "G"]))
	content.add_child(_btn("Лучший состав автоматически", _auto_lineup, Color("3b5bb5"), Color.WHITE))


func _auto_lineup() -> void:
	data.auto_lineup()
	data.save()
	_show_tab("squad")


func _assign_slot(slot: String, cid: int) -> void:
	data.lineup[slot] = cid
	data.save()
	_close_modal()
	_show_tab("squad")


func _pick_for_slot(slot: String) -> void:
	var pos: String = GameData.SLOT_POS[slot]
	var cur := int(data.lineup.get(slot, -1))
	var used_else := {}
	for s in data.lineup:
		if s != slot:
			used_else[int(data.lineup[s])] = true
	var list: Array = []
	for c in data.cards:
		if c["pos"] == pos and not used_else.has(int(c["id"])):
			list.append(c)
	list.sort_custom(func(a, b): return int(a["ovr"]) > int(b["ovr"]))
	var vb := _open_modal()
	vb.add_child(_label("%s (%s)" % [GameData.POS_NAME[pos], GameData.SLOT_LABEL[slot]], 24, Color("ffc83d")))
	if list.is_empty():
		vb.add_child(_label("Нет подходящих карт. Откройте паки!", 18, Color("8fa3d4")))
	else:
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(0, 360)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vb.add_child(sc)
		var fl := HFlowContainer.new()
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.add_theme_constant_override("h_separation", 10)
		fl.add_theme_constant_override("v_separation", 10)
		sc.add_child(fl)
		for c in list:
			var cid := int(c["id"])
			fl.add_child(_card(c, true, cid == cur, _assign_slot.bind(slot, cid)))
	vb.add_child(_btn("Закрыть", _close_modal, Color("3b5bb5"), Color.WHITE))


# ---------- вкладка «Паки» ----------
func _tab_shop() -> void:
	for pk in GameData.PACKS:
		var p := _panel(content)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		p.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label(String(pk["name"]), 24, Color("ffc83d")))
		var extra := " (минимум один 80+)" if pk["min80"] else ""
		info.add_child(_label("%d игрока · рейтинг %d–%d%s" % [pk["n"], pk["lo"], pk["hi"], extra], 17, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_LEFT, true))
		row.add_child(info)
		var b := _btn("%d" % pk["cost"], _open_pack.bind(pk))
		b.custom_minimum_size = Vector2(160, 64)
		b.disabled = data.coins < int(pk["cost"])
		row.add_child(b)
	content.add_child(_label("Монеты зарабатываются в матчах и продажей лишних карт.", 17, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_CENTER, true))


func _open_pack(pk: Dictionary) -> void:
	var got := data.open_pack(pk)
	if got.is_empty():
		return
	coins_label.text = "Монеты: %d" % data.coins
	var vb := _open_modal()
	vb.add_child(_label(String(pk["name"]), 28, Color("ffc83d"), HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	var i := 0
	for c in got:
		var card := _card(c)
		card.modulate.a = 0.0
		row.add_child(card)
		var tw := create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.35).set_delay(0.3 * i)
		i += 1
	vb.add_child(_btn("Забрать", _after_pack))


func _after_pack() -> void:
	_close_modal()
	_show_tab("shop")


# ---------- вкладка «Коллекция» ----------
func _tab_coll() -> void:
	var p := _panel(content)
	p.add_child(_label("Коллекция (%d)" % data.cards.size(), 24, Color("ffc83d")))
	p.add_child(_label("Нажмите на карту: прокачка и продажа. Золотая рамка — игрок в составе.", 17, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_LEFT, true))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 10)
	fl.add_theme_constant_override("v_separation", 10)
	p.add_child(fl)
	var sorted := data.cards.duplicate()
	sorted.sort_custom(func(a, b): return int(a["ovr"]) > int(b["ovr"]))
	for c in sorted:
		var cid := int(c["id"])
		fl.add_child(_card(c, true, data.in_lineup(cid), func(): _card_menu(cid)))
	content.add_child(_btn("Сбросить прогресс", _confirm_reset, Color("e03c42"), Color.WHITE))


func _card_menu(id: int) -> void:
	var c := data.card_by_id(id)
	if c.is_empty():
		return
	var vb := _open_modal(560)
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_child(_card(c))
	vb.add_child(crow)
	vb.add_child(_label("%s · прокачка +%d из 8" % [GameData.POS_NAME[c["pos"]], int(c["ovr"]) - int(c["base"])], 18, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_CENTER))
	var train_btn := _btn("Тренировка +1  (%d монет)" % data.train_cost(c), _train_card.bind(id))
	train_btn.disabled = not data.can_train(c)
	vb.add_child(train_btn)
	var inl := data.in_lineup(id)
	var sl := _btn("Продать за %d%s" % [data.sell_price(c), " (в составе)" if inl else ""], _sell_card.bind(id), Color("e03c42"), Color.WHITE)
	sl.disabled = inl
	vb.add_child(sl)
	vb.add_child(_btn("Закрыть", _close_modal, Color("3b5bb5"), Color.WHITE))


func _train_card(id: int) -> void:
	data.train(id)
	_close_modal()
	_show_tab("coll")
	_card_menu(id)


func _sell_card(id: int) -> void:
	data.sell(id)
	_close_modal()
	_show_tab("coll")


func _confirm_reset() -> void:
	var vb := _open_modal(560)
	vb.add_child(_label("Удалить весь прогресс и начать заново?", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	vb.add_child(_btn("Да, сбросить", _do_reset, Color("e03c42"), Color.WHITE))
	vb.add_child(_btn("Отмена", _close_modal, Color("3b5bb5"), Color.WHITE))


func _do_reset() -> void:
	data.new_game()
	_close_modal()
	_show_tab("home")


# ---------- матч ----------
func _start_match() -> void:
	if not data.lineup_full():
		return
	var opp := data.opponent_info()
	current_opp = String(opp["name"])
	var teams := [data.lineup_team(), data.gen_team(int(opp["ovr"]))]
	match_view = MatchViewScript.new()
	add_child(match_view)
	match_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match_view.finished.connect(_on_match_finished)
	var ai_level := clampf((float(opp["ovr"]) - 45.0) / 45.0, 0.55, 1.0)
	match_view.start(teams, current_opp, ai_level)


func _on_match_finished(res: Dictionary) -> void:
	if match_view != null:
		match_view.queue_free()
		match_view = null
	if res.get("quit", false):
		data.losses += 1
		data.match_idx += 1
		data.goals_against += 3
		data.save()
		_show_tab("home")
		return

	var sc: Array = res["score"]
	var win: bool = res["win"]
	var reward := (600 + 100 * (data.match_idx % GameData.OPPONENTS.size()) if win else 150) + int(sc[0]) * 100
	if win and res["ot"]:
		reward -= 150
	data.coins += reward
	data.match_idx += 1
	data.goals_for += int(sc[0])
	data.goals_against += int(sc[1])
	if win:
		data.wins += 1
	else:
		data.losses += 1
	data.save()

	var vb := _open_modal(620)
	vb.add_child(_label("ПОБЕДА!" if win else "Поражение", 36, Color("ffc83d") if win else Color("ff8a85"), HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	row.add_child(_vs_side(str(sc[0]), "Вы"))
	row.add_child(_label(":", 48, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_vs_side(str(sc[1]), current_opp))
	vb.add_child(row)
	if res["shootout"]:
		vb.add_child(_label("Решающий буллит", 18, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_CENTER))
	elif res["ot"]:
		vb.add_child(_label("Овертайм", 18, Color("8fa3d4"), HORIZONTAL_ALIGNMENT_CENTER))
	var shots: Array = res["shots"]
	var saves: Array = res["saves"]
	_stat_row(vb, "Броски", "%d : %d" % [shots[0], shots[1]])
	_stat_row(vb, "Сейвы вратарей", "%d : %d" % [saves[0], saves[1]])
	_stat_row(vb, "Награда", "+%d монет" % reward)
	vb.add_child(_btn("Продолжить", _back_home))


func _back_home() -> void:
	_close_modal()
	_show_tab("home")
