extends Node
## 밤 시뮬레이션 (GDD 4절, 밸런스용). 실제 Balance·Upgrades·Game·Night 코드를 화면 없이 그대로 돌린다.
##
##   godot --headless --path . res://tools/sim_night.tscn [-- --nights=60 --speed=12 --day=15 --seed=1 --log=1]
##
## 사람 흉내: 밤에는 구름을 '값어치가 가장 몰린 자리'로 옮긴다 (원 안 작물의 생기 ÷ 남은 체력 합이 가장 큰 작물 자리, 0.25초마다 다시 고름).
## 커서는 초당 speed칸까지 움직인다. 낮에는 살 수 있는 업그레이드를 싼 것부터 다 사고, 열린 가장 높은 밭 단계로 나간다.
## 낮에 쓰는 시간(day초)을 밤 길이에 더해 실제 시간을 어림한다. 결과는 docs/BALANCE_SIM.md에 적는다

const DT: float = 0.05
const RETARGET: float = 0.25

var _speed: float = 12.0
var _day: float = 15.0
var _log: bool = true


func _ready() -> void:
	Save.blocked = true
	var args := _args()
	var nights := int(args.get("nights", "60"))
	_speed = float(args.get("speed", "12"))
	_day = float(args.get("day", "15"))
	_log = args.get("log", "1") == "1"
	var seed := int(args.get("seed", "1"))
	Upgrades.reset()
	Game.reset()
	Night.reset()
	var clock := 0.0
	print("밤 | 단계 | 생기 | 시든/전체 | 정복 | 누적 분 | 산 것")
	var firsts: Dictionary = {}
	for n in nights:
		var bought := _shop()
		var level := Night.field_level
		Game.start_night()
		Night.begin(seed * 1000 + n)
		var seconds := _play()
		clock += seconds + _day
		var cleared := Night.cleared
		if cleared and not firsts.has(level):
			firsts[level] = [n + 1, clock / 60.0]
		if _log:
			print("%d | %d | %s | %d/%d | %s | %.1f | %s" % [n + 1, level, Num.format(Game.last_haul), Night.withered, Night.crops_total,
				"정복" if cleared else "-", clock / 60.0, bought])
	print("")
	print("단계 첫 정복: ", _firsts_text(firsts))
	print("업그레이드: ", _levels_text())
	get_tree().quit()


## 밤 한 판을 끝까지 돈다. 걸린 시간(초)을 돌려준다
func _play() -> float:
	var elapsed := 0.0
	var retarget := 0.0
	var target := Night.cloud
	while Night.active:
		retarget -= DT
		if retarget <= 0.0:
			retarget = RETARGET
			target = _best_spot()
		var step := target - Night.cloud
		var reach := _speed * DT
		Night.set_cloud(Night.cloud + (step if step.length() <= reach else step.normalized() * reach))
		Night.tick(DT)
		elapsed += DT
	return elapsed


## 원 안 작물의 (생기 ÷ 남은 체력) 합이 가장 큰 작물 자리
func _best_spot() -> Vector2:
	var radius := Night.cloud_radius()
	var best := -1.0
	var spot := Night.cloud
	for i in Night.cell_count():
		if not Night.is_alive(i):
			continue
		var center := Night.cell_position(i)
		var score := 0.0
		for j in Night.cell_count():
			if Night.is_alive(j) and Night.cell_position(j).distance_to(center) <= radius:
				score += Night.crop_vitality(j) / maxf(Night.hp[j], 1e-9)
		if score > best:
			best = score
			spot = center
	return spot


## 살 수 있는 업그레이드를 싼 것부터 다 산다. 산 것의 이름 목록
func _shop() -> String:
	var names: Array[String] = []
	while true:
		var pick := -1
		for i in Balance.UPGRADES.size():
			if Upgrades.can_buy(i) and (pick < 0 or Upgrades.cost(i) < Upgrades.cost(pick)):
				pick = i
		if pick < 0 or not Upgrades.buy(pick):
			break
		names.append(Balance.upgrade_name(pick))
	return ",".join(names)


func _firsts_text(firsts: Dictionary) -> String:
	var parts: Array[String] = []
	for level: int in firsts:
		parts.append("%d단계 %d번째 밤(%.1f분)" % [level, firsts[level][0], firsts[level][1]])
	return "  ".join(parts)


func _levels_text() -> String:
	var parts: Array[String] = []
	for i in Balance.UPGRADES.size():
		parts.append("%s %d" % [Balance.upgrade_name(i), Upgrades.level(i)])
	return ", ".join(parts)


func _args() -> Dictionary:
	var result: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=")
		if pair.size() == 2:
			result[pair[0]] = pair[1]
	return result
