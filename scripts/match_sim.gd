class_name MatchSim
extends RefCounted
## Логика матча без отрисовки: физика шайбы, ИИ игроков и вратарей, периоды, овертайм.

const W := 800.0
const H := 400.0
const GY1 := 170.0
const GY2 := 230.0
const GX := 40.0
const SLOTS := ["LW", "C", "RW", "LD", "RD"]
const HOME := {
	"LW": Vector2(0.30, 0.20), "C": Vector2(0.38, 0.5), "RW": Vector2(0.30, 0.80),
	"LD": Vector2(0.17, 0.34), "RD": Vector2(0.17, 0.66),
}


class Sk:
	var team := 0
	var slot := ""
	var pname := ""
	var ovr := 50
	var spd := 50.0
	var shot := 50.0
	var def := 50.0
	var pas := 50.0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var face := 0.0
	var cd := 0.0
	var tk := 0.0
	var tkc := 0.0
	var think := 0.0


class Gk:
	var team := 0
	var ovr := 50
	var pos := Vector2.ZERO
	var err := 0.0


var per_len := 45.0
var per := 1
var per_t := 0.0
var ot := false
var score := [0, 0]
var shots := [0, 0]
var saves := [0, 0]
var state := "faceoff"
var timer := 1.4
var over := false
var ai := 0.8
var sk: Array = []
var gk: Array = []
var owner: Sk = null
var ctrl: Sk = null
var events: Array = []
var puck_pos := Vector2(W / 2.0, H / 2.0)
var puck_vel := Vector2.ZERO
var puck_last: Sk = null
var puck_target: Sk = null
var shootout := -1
var sudden := false
var rng := RandomNumberGenerator.new()


func setup(teams: Array, p_per_len: float, p_ai: float) -> void:
	rng.randomize()
	per_len = p_per_len
	ai = p_ai
	for ti in 2:
		var t: Dictionary = teams[ti]
		for s in SLOTS:
			var c: Dictionary = t[s]
			var k := Sk.new()
			k.team = ti
			k.slot = s
			k.pname = String(c["name"])
			k.ovr = int(c["ovr"])
			var is_d: bool = c["pos"] == "D"
			k.spd = float(k.ovr)
			k.shot = float(k.ovr) + (-6.0 if is_d else 3.0)
			k.def = float(k.ovr) + (5.0 if is_d else -3.0)
			k.pas = float(k.ovr)
			k.face = PI if ti == 1 else 0.0
			sk.append(k)
		var g := Gk.new()
		g.team = ti
		g.ovr = int(t["G"]["ovr"])
		g.pos = Vector2(W - 58.0 if ti == 1 else 58.0, H / 2.0)
		gk.append(g)
	reset_faceoff()


func cur_len() -> float:
	return 30.0 if ot else per_len


func max_spd(s: Sk) -> float:
	return 150.0 + (s.spd - 50.0) * 1.6


func home_xy(s: Sk, has_puck: bool) -> Vector2:
	var h: Vector2 = HOME[s.slot]
	var adv := 0.0
	if has_puck:
		adv = 0.14 if (s.slot == "LD" or s.slot == "RD") else 0.26
	var x := (h.x + adv) * W
	if s.team == 1:
		x = W - x
	return Vector2(x, h.y * H)


func reset_faceoff() -> void:
	state = "faceoff"
	timer = 1.2
	owner = null
	puck_pos = Vector2(W / 2.0, H / 2.0)
	puck_vel = Vector2.ZERO
	puck_last = null
	puck_target = null
	for s in sk:
		s.pos = home_xy(s, false)
		s.vel = Vector2.ZERO
		s.cd = 0.0
		s.face = PI if s.team == 1 else 0.0
		if s.slot == "C":
			s.pos = Vector2(W / 2.0 + (16.0 if s.team == 1 else -16.0), H / 2.0)
	for g in gk:
		g.pos.y = H / 2.0


func give(s: Sk) -> void:
	owner = s
	puck_last = s
	puck_target = null
	s.cd = 0.0


func move_to(s: Sk, target: Vector2, dt: float, mul: float) -> void:
	var d := target - s.pos
	var dist := d.length()
	var ms := max_spd(s) * mul * (dist / 25.0 if dist < 25.0 else 1.0)
	var tv := Vector2.ZERO
	if dist > 1.0:
		tv = d / dist * ms
	s.vel += (tv - s.vel) * minf(1.0, 5.0 * dt)


func shoot(s: Sk, aim_y: float, has_aim: bool) -> void:
	var tx := (GX - 6.0) if s.team == 1 else (W - GX + 6.0)
	var corner := (-1.0 if rng.randf() < 0.5 else 1.0) * rng.randf_range(10.0, 28.0)
	var ty := aim_y if has_aim else H / 2.0 + corner
	var err := (100.0 - s.shot) * 0.0015 + 0.005
	var a := atan2(ty - s.pos.y, tx - s.pos.x) + rng.randf_range(-err, err)
	var sp := 420.0 + s.shot * 3.2
	var dir := Vector2(cos(a), sin(a))
	puck_pos = s.pos + dir * 15.0
	puck_vel = dir * sp
	puck_last = s
	puck_target = null
	owner = null
	s.cd = 0.35
	shots[s.team] += 1
	var g: Gk = gk[1 - s.team]
	g.err = rng.randf_range(-1.0, 1.0) * (100.0 - float(g.ovr)) * 0.55
	events.append({"type": "shot", "team": s.team})


func pass_puck(s: Sk, dir_ang: float, has_dir: bool) -> bool:
	var fwd := dir_ang if has_dir else (PI if s.team == 1 else 0.0)
	var best: Sk = null
	var bs := -1e9
	for o in sk:
		if o.team != s.team or o == s:
			continue
		var d: Vector2 = o.pos - s.pos
		var dist := d.length()
		if dist < 40.0:
			continue
		var ang := atan2(d.y, d.x)
		var da := absf(angle_difference(ang, fwd))
		if has_dir and da > 1.0:
			continue
		var fx: float = -o.pos.x if s.team == 1 else o.pos.x
		var sc := -da * 120.0 - dist * 0.15 + fx * 0.05
		if sc > bs:
			bs = sc
			best = o
	if best == null:
		return false
	var t := minf(0.5, s.pos.distance_to(best.pos) / 480.0)
	var tp: Vector2 = best.pos + best.vel * t
	var err := (100.0 - s.pas) * 0.002
	var a := atan2(tp.y - s.pos.y, tp.x - s.pos.x) + rng.randf_range(-err, err)
	var dir := Vector2(cos(a), sin(a))
	puck_pos = s.pos + dir * 15.0
	puck_vel = dir * 480.0
	puck_last = s
	puck_target = best
	owner = null
	s.cd = 0.3
	events.append({"type": "pass", "team": s.team})
	return true


func goal(team: int) -> void:
	score[team] += 1
	state = "goal"
	timer = 1.8
	events.append({"type": "goal", "team": team})
	if ot:
		sudden = true


func end_match() -> void:
	over = true
	state = "end"
	events.append({"type": "end"})


func team_power(ti: int) -> float:
	var sum := 0.0
	for s in sk:
		if s.team == ti:
			sum += float(s.ovr)
	return sum / 5.0 + float(gk[ti].ovr) * 0.5


func ai_carrier(s: Sk, dt: float) -> void:
	var dir := -1.0 if s.team == 1 else 1.0
	var gx := GX if s.team == 1 else W - GX
	var near: Sk = null
	var nd := 1e9
	for o in sk:
		if o.team == s.team:
			continue
		var d: float = o.pos.distance_to(s.pos)
		if d < nd:
			nd = d
			near = o
	var ty := H / 2.0
	if near != null and nd < 80.0:
		ty = s.pos.y + (60.0 if s.pos.y > near.pos.y else -60.0)
	ty = clampf(ty, 50.0, H - 50.0)
	move_to(s, Vector2(gx - dir * 30.0, ty), dt, 0.95)
	s.think += dt
	if s.think > 0.45:
		var dg := absf(gx - s.pos.x)
		if dg < 260.0 and rng.randf() < dt * 1.7 * ai:
			shoot(s, 0.0, false)
			s.think = 0.0
		elif near != null and nd < 48.0 and rng.randf() < dt * 2.0 * ai:
			pass_puck(s, 0.0, false)
			s.think = 0.0


## inp: {mx, my, shoot, pass, tackle}
func step(dt: float, inp: Dictionary) -> void:
	events.clear()
	if over:
		return

	if state != "play":
		timer -= dt
		if timer > 0.0:
			return
		if state == "faceoff":
			state = "play"
			var c0: Sk = sk[1]
			var c1: Sk = sk[6]
			var w: Sk = c0 if rng.randf() < float(c0.ovr) / float(c0.ovr + c1.ovr) else c1
			give(w)
			events.append({"type": "start"})
		elif state == "goal":
			if sudden:
				end_match()
				return
			reset_faceoff()
		elif state == "break":
			reset_faceoff()
		return

	per_t += dt
	if per_t >= cur_len():
		if not ot and per < 3:
			per += 1
			per_t = 0.0
			state = "break"
			timer = 1.6
			events.append({"type": "period", "per": per})
			return
		if score[0] != score[1]:
			end_match()
			return
		if not ot:
			ot = true
			per = 4
			per_t = 0.0
			state = "break"
			timer = 1.6
			events.append({"type": "period", "per": 4})
			return
		var a := team_power(0)
		var b := team_power(1)
		shootout = 0 if rng.randf() < a / (a + b) else 1
		end_match()
		return

	# --- выбор управляемого игрока ---
	var best: Sk = null
	if owner != null and owner.team == 0:
		best = owner
	else:
		var bd := 1e9
		for s in sk:
			if s.team != 0:
				continue
			var d: float = s.pos.distance_to(puck_pos)
			if d < bd:
				bd = d
				best = s
		if ctrl != null and ctrl.team == 0 and ctrl.pos.distance_to(puck_pos) < bd + 30.0:
			best = ctrl
	ctrl = best
	var c: Sk = ctrl

	# --- управление игроком ---
	var mv := Vector2(float(inp.get("mx", 0.0)), float(inp.get("my", 0.0)))
	var mag := mv.length()
	var ms := max_spd(c) * (0.94 if owner == c else 1.0) * (1.45 if c.tk > 0.0 else 1.0)
	var k := minf(1.0, 7.0 * dt)
	var nv := Vector2.ZERO
	if mag > 0.08:
		nv = mv / maxf(1.0, mag) * minf(1.0, mag) * ms
	c.vel += (nv - c.vel) * k

	var want_shoot: bool = inp.get("shoot", false)
	var want_pass: bool = inp.get("pass", false)
	var want_tackle: bool = inp.get("tackle", false)
	if owner == c:
		if want_shoot:
			if absf(mv.y) > 0.3:
				shoot(c, H / 2.0 + clampf(mv.y, -1.0, 1.0) * 28.0, true)
			else:
				shoot(c, 0.0, false)
		elif want_pass:
			var ang := atan2(mv.y, mv.x) if mag > 0.3 else c.face
			if not pass_puck(c, ang, true):
				pass_puck(c, 0.0, false)
	elif want_tackle and c.tkc <= 0.0:
		c.tk = 0.45
		c.tkc = 1.0
		var dd := puck_pos - c.pos
		var l := dd.length()
		if l < 0.001:
			l = 1.0
		c.vel += dd / l * 120.0
	elif want_shoot and owner == null and puck_target == c:
		shoot(c, 0.0, false)

	# --- ИИ остальных игроков ---
	var order := [[], []]
	for s in sk:
		if s != c:
			order[s.team].append(s)
	var refp: Vector2 = owner.pos if owner != null else puck_pos
	order[0].sort_custom(func(x, y): return x.pos.distance_to(refp) < y.pos.distance_to(refp))
	order[1].sort_custom(func(x, y): return x.pos.distance_to(refp) < y.pos.distance_to(refp))

	for s in sk:
		if s == c:
			continue
		if owner == s:
			ai_carrier(s, dt)
			continue
		var mine: bool = owner != null and owner.team == s.team
		var rank: int = order[s.team].find(s)
		if mine:
			move_to(s, home_xy(s, true), dt, 0.9)
		elif owner != null:
			var car: Sk = owner
			if rank == 0:
				move_to(s, car.pos + car.vel * 0.2, dt, 1.0)
			elif rank == 1:
				var gxx := (W - GX) if s.team == 1 else GX
				move_to(s, Vector2((car.pos.x * 2.0 + gxx) / 3.0, (car.pos.y + H / 2.0) / 2.0), dt, 0.95)
			else:
				move_to(s, home_xy(s, false), dt, 0.85)
		else:
			if rank == 0 and (s.team == 1 or s.pos.distance_to(puck_pos) < 170.0):
				move_to(s, puck_pos + puck_vel * 0.25, dt, 1.0)
			else:
				var hp := home_xy(s, false)
				hp.x += -40.0 if s.team == 1 else 40.0
				move_to(s, hp, dt, 0.8)

	# --- движение, границы, развод игроков ---
	for s in sk:
		s.cd = maxf(0.0, s.cd - dt)
		s.tk = maxf(0.0, s.tk - dt)
		s.tkc = maxf(0.0, s.tkc - dt)
		s.pos += s.vel * dt
		s.pos.x = clampf(s.pos.x, 46.0, W - 46.0)
		s.pos.y = clampf(s.pos.y, 18.0, H - 18.0)
		if s.vel.length() > 25.0:
			s.face = atan2(s.vel.y, s.vel.x)
	for i in sk.size():
		for j in range(i + 1, sk.size()):
			var a: Sk = sk[i]
			var b: Sk = sk[j]
			var dv: Vector2 = b.pos - a.pos
			var dl := dv.length()
			if dl > 0.0 and dl < 16.0:
				var push := (16.0 - dl) / 2.0
				var u := dv / dl
				a.pos -= u * push
				b.pos += u * push

	# --- отбор ---
	if owner != null:
		var cr: Sk = owner
		for o in sk:
			if o.team == cr.team or o.cd > 0.0:
				continue
			if o.pos.distance_to(cr.pos) < 20.0:
				var rate: float = 0.9 * (o.def / maxf(30.0, cr.spd)) * (4.0 if o.tk > 0.0 else 1.0)
				if o.team == 1:
					rate *= 0.6 + 0.4 * ai
				if rng.randf() < dt * rate:
					cr.cd = 0.6
					give(o)
					events.append({"type": "steal", "team": o.team})
					break

	# --- шайба ---
	if owner != null:
		var ow: Sk = owner
		puck_pos = ow.pos + Vector2(cos(ow.face), sin(ow.face)) * 13.0
		puck_vel = ow.vel
	else:
		puck_pos += puck_vel * dt
		puck_vel *= pow(0.6, dt)
		if puck_pos.y < 10.0:
			puck_pos.y = 10.0
			puck_vel.y = absf(puck_vel.y) * 0.75
		if puck_pos.y > H - 10.0:
			puck_pos.y = H - 10.0
			puck_vel.y = -absf(puck_vel.y) * 0.75
		if puck_pos.x < 12.0:
			puck_pos.x = 12.0
			puck_vel.x = absf(puck_vel.x) * 0.75
		if puck_pos.x > W - 12.0:
			puck_pos.x = W - 12.0
			puck_vel.x = -absf(puck_vel.x) * 0.75
		var sp := puck_vel.length()

		# вратари
		var saved := false
		for g in gk:
			var towards: bool = puck_vel.x > 0.0 if g.team == 1 else puck_vel.x < 0.0
			if towards and g.pos.distance_to(puck_pos) < 16.0 and sp > 60.0:
				if rng.randf() < 0.95:
					saved = true
					saves[g.team] += 1
					var aa := (PI if g.team == 1 else 0.0) + rng.randf_range(-1.0, 1.0) * 1.1
					puck_vel = Vector2(cos(aa) * rng.randf_range(180.0, 320.0), sin(aa) * rng.randf_range(180.0, 320.0))
					puck_last = null
					puck_target = null
					events.append({"type": "save", "team": g.team})
					if rng.randf() < 0.4:
						for o in sk:
							if o.team == g.team and o.slot == "LD":
								var ad := atan2(o.pos.y - puck_pos.y, o.pos.x - puck_pos.x)
								puck_vel = Vector2(cos(ad), sin(ad)) * 350.0
								puck_target = o
								break

		# голы
		if not saved:
			if puck_pos.x < GX and puck_pos.y > GY1 and puck_pos.y < GY2 and puck_vel.x < 0.0:
				goal(1)
				return
			if puck_pos.x > W - GX and puck_pos.y > GY1 and puck_pos.y < GY2 and puck_vel.x > 0.0:
				goal(0)
				return

		# подбор / блок
		for s in sk:
			if s.cd > 0.0:
				continue
			var d: float = s.pos.distance_to(puck_pos)
			var mate: bool = puck_last != null and puck_last.team == s.team
			if d < 16.0:
				if puck_target == s or sp < (560.0 if mate else 500.0):
					give(s)
					break
			if (not mate) and puck_last != null and sp > 520.0 and d < 12.0 and rng.randf() < 0.3 * (s.def / 90.0):
				var ba := rng.randf() * TAU
				puck_vel = Vector2(cos(ba), sin(ba)) * 200.0
				puck_last = null
				puck_target = null
				events.append({"type": "block"})
				break

	# --- вратари: движение ---
	for g in gk:
		var own_x := (W - GX) if g.team == 1 else GX
		var toward: bool = puck_vel.x > 40.0 if g.team == 1 else puck_vel.x < -40.0
		var ty := H / 2.0
		if owner == null and toward:
			var t := (own_x - puck_pos.x) / puck_vel.x
			ty = puck_pos.y + puck_vel.y * t + g.err
		else:
			var ry: float = owner.pos.y if owner != null else puck_pos.y
			ty = H / 2.0 + (ry - H / 2.0) * 0.35
		ty = clampf(ty, GY1 + 6.0, GY2 - 6.0)
		var gspd := 170.0 + (float(g.ovr) - 50.0) * 3.2
		g.pos.y += clampf(ty - g.pos.y, -gspd * dt, gspd * dt)
