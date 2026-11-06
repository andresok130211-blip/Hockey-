extends Control
## Экран матча: рисует каток, обрабатывает джойстик, кнопки и клавиатуру.

signal finished(result: Dictionary)

const W := 800.0
const H := 400.0
const HUD_H := 56.0
const STICK_R := 90.0

var sim: MatchSim
var opp_name := ""
var paused := false
var acc := 0.0
var shoot_flag := false
var pass_flag := false
var tackle_flag := false
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var banner_text := ""
var banner_t := 0.0
var rink_style: StyleBoxFlat
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	rink_style = StyleBoxFlat.new()
	rink_style.bg_color = Color("e3f2fc")
	rink_style.set_corner_radius_all(60)
	rink_style.set_border_width_all(6)
	rink_style.border_color = Color("7a8fb8")
	mouse_filter = Control.MOUSE_FILTER_STOP


func start(teams: Array, p_opp_name: String, ai_level: float) -> void:
	opp_name = p_opp_name
	sim = MatchSim.new()
	sim.setup(teams, 45.0, ai_level)
	paused = false
	acc = 0.0
	_banner("Вбрасывание!", 1.0)


func _banner(t: String, secs: float) -> void:
	banner_text = t
	banner_t = secs


# ---------- раскладка ----------
func _rink_scale() -> float:
	return minf(size.x / W, (size.y - HUD_H) / H)


func _rink_origin() -> Vector2:
	var s := _rink_scale()
	return Vector2((size.x - W * s) / 2.0, HUD_H + (size.y - HUD_H - H * s) / 2.0)


func _shot_c() -> Vector2:
	return Vector2(size.x - 110.0, size.y - 120.0)


func _pass_c() -> Vector2:
	return Vector2(size.x - 250.0, size.y - 80.0)


func _tackle_c() -> Vector2:
	return Vector2(size.x - 215.0, size.y - 215.0)


func _pause_btn_rect() -> Rect2:
	return Rect2(size.x - 110.0, 8.0, 100.0, 40.0)


func _pause_rects() -> Array:
	var cx := size.x / 2.0
	var cy := size.y / 2.0
	return [Rect2(cx - 170.0, cy - 60.0, 340.0, 64.0), Rect2(cx - 170.0, cy + 20.0, 340.0, 64.0)]


# ---------- цикл ----------
func _process(delta: float) -> void:
	if sim == null:
		return
	if banner_t > 0.0:
		banner_t -= delta
	if not paused:
		acc += minf(delta, 0.1)
		while acc >= 1.0 / 60.0:
			sim.step(1.0 / 60.0, _read_input())
			shoot_flag = false
			pass_flag = false
			tackle_flag = false
			_handle_events()
			acc -= 1.0 / 60.0
			if sim.over:
				_finish()
				return
	queue_redraw()


func _read_input() -> Dictionary:
	var mv := stick_vec
	var kx := 0.0
	var ky := 0.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		kx += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		kx -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		ky += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		ky -= 1.0
	if kx != 0.0 or ky != 0.0:
		mv = Vector2(kx, ky).normalized()
	return {"mx": mv.x, "my": mv.y, "shoot": shoot_flag, "pass": pass_flag, "tackle": tackle_flag}


func _handle_events() -> void:
	for e in sim.events:
		match e["type"]:
			"goal":
				_banner("ГОЛ!" if e["team"] == 0 else "Гол соперника", 1.6)
			"period":
				_banner("ОВЕРТАЙМ!" if e["per"] == 4 else "%d-й период" % e["per"], 1.3)


func _finish() -> void:
	var sc: Array = sim.score.duplicate()
	var win := false
	if sim.shootout >= 0:
		win = sim.shootout == 0
		sc[sim.shootout] += 1
	else:
		win = sc[0] > sc[1]
	var res := {
		"quit": false, "win": win, "score": sc,
		"shots": sim.shots.duplicate(), "saves": sim.saves.duplicate(),
		"ot": sim.ot, "shootout": sim.shootout >= 0,
	}
	sim = null
	finished.emit(res)


func _quit_match() -> void:
	sim = null
	finished.emit({"quit": true})


# ---------- ввод ----------
func _input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			_press(te.index, te.position)
		elif te.index == stick_id:
			stick_id = -1
			stick_vec = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		if de.index == stick_id:
			_update_stick(de.position)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_SPACE:
				shoot_flag = true
			KEY_E:
				pass_flag = true
			KEY_Q:
				tackle_flag = true
			KEY_ESCAPE:
				paused = not paused


func _press(idx: int, p: Vector2) -> void:
	if paused:
		var r := _pause_rects()
		if r[0].has_point(p):
			paused = false
		elif r[1].has_point(p):
			_quit_match()
		return
	if _pause_btn_rect().has_point(p):
		paused = true
		stick_id = -1
		stick_vec = Vector2.ZERO
		return
	if p.distance_to(_shot_c()) < 80.0:
		shoot_flag = true
	elif p.distance_to(_pass_c()) < 64.0:
		pass_flag = true
	elif p.distance_to(_tackle_c()) < 64.0:
		tackle_flag = true
	elif p.x < size.x * 0.5 and stick_id == -1 and p.y > HUD_H:
		stick_id = idx
		stick_origin = p
		stick_vec = Vector2.ZERO


func _update_stick(p: Vector2) -> void:
	var d := p - stick_origin
	if d.length() > STICK_R:
		d = d.normalized() * STICK_R
	stick_vec = d / STICK_R


# ---------- отрисовка ----------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("06102a"))
	if sim == null:
		return
	_draw_hud()
	var s := _rink_scale()
	draw_set_transform(_rink_origin(), 0.0, Vector2(s, s))
	_draw_rink()
	_draw_players()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_controls()
	if banner_t > 0.0:
		draw_string(font, Vector2(2.0, size.y * 0.42 + 2.0), banner_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(0.0, size.y * 0.42), banner_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color("ffc83d"))
	if paused:
		_draw_pause()


func _clock_text() -> String:
	var length := sim.cur_len()
	var rem := maxf(0.0, length - sim.per_t)
	var total := 300.0 if sim.ot else 1200.0
	var sec := int(round(rem / length * total))
	var prefix := "ОТ" if sim.ot else "%d период" % sim.per
	return "%s · %02d:%02d" % [prefix, floori(sec / 60.0), sec % 60]


func _draw_hud() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, HUD_H), Color("0d183a"))
	draw_string(font, Vector2(16.0, 36.0), "Вы", HORIZONTAL_ALIGNMENT_LEFT, 200.0, 24, Color("7fa6ff"))
	draw_string(font, Vector2(0.0, 36.0), "%d : %d" % [sim.score[0], sim.score[1]], HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color("ffc83d"))
	draw_string(font, Vector2(0.0, 52.0), _clock_text(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("8fa3d4"))
	draw_string(font, Vector2(size.x - 420.0, 36.0), opp_name, HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 22, Color("ff8a85"))
	var pr := _pause_btn_rect()
	draw_rect(pr, Color("2a4494"))
	draw_string(font, Vector2(pr.position.x, pr.position.y + 28.0), "Пауза", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 18, Color.WHITE)


func _draw_rink() -> void:
	var red := Color("dd3333")
	draw_style_box(rink_style, Rect2(0.0, 0.0, W, H))
	draw_line(Vector2(W / 2.0, 4.0), Vector2(W / 2.0, H - 4.0), red, 3.0)
	for x in [W * 0.34, W * 0.66]:
		draw_line(Vector2(x, 4.0), Vector2(x, H - 4.0), Color("2b5bd7"), 3.0)
	draw_arc(Vector2(W / 2.0, H / 2.0), 40.0, 0.0, TAU, 48, red, 2.0)
	for pt in [Vector2(130, 100), Vector2(130, 300), Vector2(670, 100), Vector2(670, 300)]:
		draw_arc(pt, 30.0, 0.0, TAU, 32, red, 2.0)
	draw_circle(Vector2(W / 2.0, H / 2.0), 5.0, red)
	for x in [MatchSim.GX, W - MatchSim.GX]:
		draw_line(Vector2(x, 12.0), Vector2(x, H - 12.0), red, 2.0)
	draw_arc(Vector2(MatchSim.GX, H / 2.0), 36.0, -PI / 2.0, PI / 2.0, 24, red, 2.0)
	draw_arc(Vector2(W - MatchSim.GX, H / 2.0), 36.0, PI / 2.0, PI * 1.5, 24, red, 2.0)
	var gh := MatchSim.GY2 - MatchSim.GY1
	for gx in [14.0, W - 40.0]:
		draw_rect(Rect2(gx, MatchSim.GY1, 26.0, gh), Color(1, 1, 1, 0.85))
		draw_rect(Rect2(gx, MatchSim.GY1, 26.0, gh), Color("cc3333"), false, 3.0)


func _draw_players() -> void:
	var cols := [Color("2f6bff"), Color("e8433f")]
	for s in sim.sk:
		var dir := Vector2(cos(s.face), sin(s.face))
		draw_line(s.pos, s.pos + dir * 20.0, Color("3a2a14"), 3.0)
		draw_circle(s.pos, 9.0, cols[s.team])
		draw_arc(s.pos, 9.0, 0.0, TAU, 20, Color.WHITE, 2.0)
		var lab := "Ц" if s.slot == "C" else ("З" if s.slot.ends_with("D") else "Н")
		draw_string(font, s.pos + Vector2(-10.0, 4.0), lab, HORIZONTAL_ALIGNMENT_CENTER, 20.0, 10, Color.WHITE)
		if s == sim.ctrl:
			draw_arc(s.pos, 14.0, 0.0, TAU, 24, Color("ffc83d"), 3.0)
			draw_colored_polygon(PackedVector2Array([
				s.pos + Vector2(0, -22), s.pos + Vector2(-5, -30), s.pos + Vector2(5, -30)]), Color("ffc83d"))
	for g in sim.gk:
		draw_circle(g.pos, 11.0, Color("9b1d1d") if g.team == 1 else Color("143a9b"))
		draw_arc(g.pos, 11.0, 0.0, TAU, 20, Color.WHITE, 2.0)
		draw_string(font, g.pos + Vector2(-10.0, 4.0), "В", HORIZONTAL_ALIGNMENT_CENTER, 20.0, 11, Color.WHITE)
	draw_circle(sim.puck_pos, 5.0, Color("111111"))
	draw_arc(sim.puck_pos, 5.0, 0.0, TAU, 12, Color.WHITE, 1.5)


func _draw_controls() -> void:
	# джойстик
	var base := stick_origin if stick_id != -1 else Vector2(150.0, size.y - 130.0)
	draw_circle(base, STICK_R, Color(1, 1, 1, 0.10))
	draw_arc(base, STICK_R, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
	var knob := base + (stick_vec * STICK_R if stick_id != -1 else Vector2.ZERO)
	draw_circle(knob, 38.0, Color(1, 1, 1, 0.55))
	# кнопки
	_draw_round_btn(_shot_c(), 64.0, Color("e03c42"), "БРОСОК", 20)
	_draw_round_btn(_pass_c(), 48.0, Color("2fa35f"), "ПАС", 18)
	_draw_round_btn(_tackle_c(), 48.0, Color("3b5bb5"), "ОТБОР", 16)


func _draw_round_btn(c: Vector2, r: float, col: Color, text: String, fs: int) -> void:
	draw_circle(c, r, Color(col, 0.85))
	draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 3.0)
	draw_string(font, Vector2(c.x - r, c.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)


func _draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(0.0, size.y / 2.0 - 90.0), "Пауза", HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, Color.WHITE)
	var r := _pause_rects()
	draw_rect(r[0], Color("ffb400"))
	draw_string(font, Vector2(r[0].position.x, r[0].position.y + 42.0), "Продолжить", HORIZONTAL_ALIGNMENT_CENTER, r[0].size.x, 26, Color("1b1300"))
	draw_rect(r[1], Color("e03c42"))
	draw_string(font, Vector2(r[1].position.x, r[1].position.y + 42.0), "Сдаться и выйти", HORIZONTAL_ALIGNMENT_CENTER, r[1].size.x, 26, Color.WHITE)
