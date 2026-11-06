class_name GameData
extends RefCounted
## Данные игры: коллекция карточек, состав, монеты, прогресс сезона и сохранение.

const SAVE_PATH := "user://ice_legends.json"

const SURNAMES := [
	"Волков", "Орлов", "Серов", "Беляев", "Крылов", "Лавров", "Громов", "Седов", "Тихонов", "Баранов",
	"Зайцев", "Мартынов", "Ковалёв", "Фролов", "Жуков", "Дроздов", "Никонов", "Родин", "Ершов", "Лосев",
	"Широков", "Воронин", "Соболев", "Власов", "Кузин", "Рябов", "Мороз", "Карпов", "Назаров", "Юдин",
	"Бородин", "Савин", "Лебедев", "Холодов", "Стрелков", "Метелин", "Снегирёв", "Ледов", "Андерсен",
	"Свенссон", "Корхонен", "Новак", "Мюллер", "Тремблэ", "Лавуа", "Кларк", "Брукс", "Харви", "Йохансон", "Нюберг",
]
const INITIALS := "АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЭЮЯ"

const OPPONENTS := [
	["Невские Рыси", 56], ["Уральские Медведи", 60], ["Сибирские Соколы", 64], ["Волжские Ястребы", 68],
	["Балтийские Акулы", 72], ["Северные Волки", 75], ["Донские Казаки", 78], ["Тихоокеанские Тигры", 81],
	["Арктические Медведи", 84], ["Алтайские Барсы", 87], ["Столичные Орлы", 90], ["Золотая Шайба", 93],
]

const PACKS := [
	{"id": "bronze", "name": "Бронзовый пак", "cost": 400, "lo": 54, "hi": 68, "n": 3, "min80": false},
	{"id": "silver", "name": "Серебряный пак", "cost": 1200, "lo": 64, "hi": 78, "n": 3, "min80": false},
	{"id": "gold", "name": "Золотой пак", "cost": 3200, "lo": 74, "hi": 90, "n": 3, "min80": true},
]

const SLOT_ORDER := ["G", "C", "LD", "RD", "LW", "RW"]
const SLOT_POS := {"LW": "W", "C": "C", "RW": "W", "LD": "D", "RD": "D", "G": "G"}
const SLOT_LABEL := {"LW": "Левый нап.", "C": "Центр", "RW": "Правый нап.", "LD": "Левый защ.", "RD": "Правый защ.", "G": "Вратарь"}
const POS_LABEL := {"W": "КН", "C": "Ц", "D": "ЗАЩ", "G": "ВР"}
const POS_NAME := {"W": "Крайний нападающий", "C": "Центр", "D": "Защитник", "G": "Вратарь"}
const RARITY_NAME := {"bronze": "БРОНЗА", "silver": "СЕРЕБРО", "gold": "ЗОЛОТО", "ice": "ЛЁД"}

var coins := 1000
var next_id := 1
var cards: Array = []
var lineup: Dictionary = {}
var match_idx := 0
var wins := 0
var losses := 0
var goals_for := 0
var goals_against := 0


static func rarity(ovr: int) -> String:
	if ovr < 65:
		return "bronze"
	if ovr < 75:
		return "silver"
	if ovr < 85:
		return "gold"
	return "ice"


static func rarity_color(r: String) -> Color:
	match r:
		"bronze":
			return Color(0.79, 0.54, 0.33)
		"silver":
			return Color(0.83, 0.86, 0.91)
		"gold":
			return Color(0.95, 0.78, 0.27)
	return Color(0.56, 0.85, 1.0)


static func random_name() -> String:
	var i := randi() % INITIALS.length()
	return INITIALS[i] + ". " + String(SURNAMES.pick_random())


func make_card(pos: String, lo: int, hi: int) -> Dictionary:
	var ovr := randi_range(lo, hi)
	var c := {"id": next_id, "name": random_name(), "pos": pos, "ovr": ovr, "base": ovr}
	next_id += 1
	return c


func new_game() -> void:
	coins = 1000
	next_id = 1
	cards = []
	lineup = {}
	match_idx = 0
	wins = 0
	losses = 0
	goals_for = 0
	goals_against = 0
	for p in ["W", "W", "C", "D", "D", "G", "W", "C", "D", "G"]:
		cards.append(make_card(p, 54, 62))
	auto_lineup()
	save()


func card_by_id(id: int) -> Dictionary:
	for c in cards:
		if int(c["id"]) == id:
			return c
	return {}


func auto_lineup() -> void:
	var used := {}
	var result := {}
	for slot in SLOT_ORDER:
		var best: Dictionary = {}
		for c in cards:
			if c["pos"] != SLOT_POS[slot] or used.has(int(c["id"])):
				continue
			if best.is_empty() or int(c["ovr"]) > int(best["ovr"]):
				best = c
		if not best.is_empty():
			result[slot] = int(best["id"])
			used[int(best["id"])] = true
	lineup = result


func lineup_full() -> bool:
	for slot in SLOT_POS:
		if card_by_id(int(lineup.get(slot, -1))).is_empty():
			return false
	return true


func team_ovr() -> int:
	var sum := 0.0
	var w := 0.0
	for slot in SLOT_POS:
		var c := card_by_id(int(lineup.get(slot, -1)))
		var k := 1.5 if slot == "G" else 1.0
		sum += (float(c["ovr"]) if not c.is_empty() else 40.0) * k
		w += k
	return int(round(sum / w))


@warning_ignore("integer_division")
func opponent_info() -> Dictionary:
	var i := match_idx % OPPONENTS.size()
	var r: int = match_idx / OPPONENTS.size()
	return {"name": OPPONENTS[i][0], "ovr": mini(98, int(OPPONENTS[i][1]) + r * 3)}


func gen_team(ovr: int) -> Dictionary:
	var t := {}
	for slot in SLOT_POS:
		t[slot] = {
			"name": random_name(),
			"pos": SLOT_POS[slot],
			"ovr": clampi(ovr + randi_range(-4, 4), 40, 99),
		}
	return t


func lineup_team() -> Dictionary:
	var t := {}
	for slot in SLOT_POS:
		var c := card_by_id(int(lineup[slot]))
		t[slot] = {"name": c["name"], "pos": c["pos"], "ovr": c["ovr"]}
	return t


func open_pack(pk: Dictionary) -> Array:
	var got: Array = []
	if coins < int(pk["cost"]):
		return got
	coins -= int(pk["cost"])
	var positions := ["W", "W", "C", "D", "D", "G", "W", "C", "D"]
	for i in int(pk["n"]):
		var c := make_card(String(positions.pick_random()), int(pk["lo"]), int(pk["hi"]))
		if pk["min80"] and i == int(pk["n"]) - 1:
			var has80 := false
			for g in got:
				if int(g["ovr"]) >= 80:
					has80 = true
			if not has80:
				c["ovr"] = randi_range(80, int(pk["hi"]))
				c["base"] = c["ovr"]
		cards.append(c)
		got.append(c)
	save()
	return got


func train_cost(c: Dictionary) -> int:
	return 100 + (int(c["ovr"]) - 50) * 15


func can_train(c: Dictionary) -> bool:
	return int(c["ovr"]) < int(c["base"]) + 8 and int(c["ovr"]) < 99 and coins >= train_cost(c)


func train(id: int) -> void:
	var c := card_by_id(id)
	if c.is_empty() or not can_train(c):
		return
	coins -= train_cost(c)
	c["ovr"] = int(c["ovr"]) + 1
	save()


func sell_price(c: Dictionary) -> int:
	return int(round(float(c["ovr"]) * float(c["ovr"]) / 12.0))


func in_lineup(id: int) -> bool:
	for slot in lineup:
		if int(lineup[slot]) == id:
			return true
	return false


func sell(id: int) -> void:
	var c := card_by_id(id)
	if c.is_empty() or in_lineup(id):
		return
	coins += sell_price(c)
	cards.erase(c)
	save()


func save() -> void:
	var d := {
		"coins": coins, "next_id": next_id, "cards": cards, "lineup": lineup,
		"match_idx": match_idx, "wins": wins, "losses": losses, "gf": goals_for, "ga": goals_against,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func _from_dict(d: Dictionary) -> bool:
	if not d.has("cards") or not d.has("lineup"):
		return false
	coins = int(d.get("coins", 0))
	next_id = int(d.get("next_id", 1))
	match_idx = int(d.get("match_idx", 0))
	wins = int(d.get("wins", 0))
	losses = int(d.get("losses", 0))
	goals_for = int(d.get("gf", 0))
	goals_against = int(d.get("ga", 0))
	cards = []
	for c in d["cards"]:
		cards.append({
			"id": int(c["id"]), "name": String(c["name"]), "pos": String(c["pos"]),
			"ovr": int(c["ovr"]), "base": int(c["base"]),
		})
	lineup = {}
	for k in d["lineup"]:
		lineup[String(k)] = int(d["lineup"][k])
	return cards.size() > 0


static func load_or_new() -> GameData:
	var g := GameData.new()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary and g._from_dict(parsed):
				return g
	g.new_game()
	return g
