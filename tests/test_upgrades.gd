extends "res://tests/test_case.gd"
## 어둠의 나무: 비용, 네 갈래의 뿌리, 열림(앞 업그레이드), 구매, 상한 (GDD 6절)


func run() -> void:
	_fresh()
	var R: int = Balance.Upgrade.RADIUS
	var T: int = Balance.Upgrade.TOXIN
	var N: int = Balance.Upgrade.LONG_NIGHT
	_close(Balance.upgrade_cost(R, 0), 10.0, "넓은 구름 첫 비용")
	_close(Balance.upgrade_cost(R, 1), floor(10.0 * float(Balance.UPGRADES[R]["growth"])), "다음 비용은 ×성장")
	_equal(Balance.UPGRADES.size() >= 60, true, "어둠의 나무는 60칸 넘게 (방장 2026-10-15: 두세 배로)")
	for i in Balance.UPGRADES.size():
		_equal(Balance.upgrade_requires(i) < i, true, "%s: 앞 칸은 늘 앞 번호" % Balance.upgrade_name(i))
	_equal(Upgrades.is_unlocked(R), true, "뿌리는 처음부터 열림")
	_equal(Upgrades.is_unlocked(N), true, "긴 밤도 뿌리 (왼쪽 갈래)")
	_equal(Upgrades.is_unlocked(T), false, "독한 포자는 넓은 구름이 있어야")
	_equal(Upgrades.can_buy(R), false, "생기가 없으면 못 산다")
	Game.vitality = 100.0
	_equal(Upgrades.buy(T), false, "잠긴 것은 못 산다")
	_equal(Upgrades.buy(R), true, "넓은 구름 구매")
	_close(Game.vitality, 90.0, "비용만큼 썼다")
	_equal(Upgrades.is_unlocked(T), true, "독한 포자가 열린다")
	_equal(Upgrades.buy(N), true, "긴 밤 구매")
	_close(Game.night_seconds(), Balance.NIGHT_BASE_SECONDS + Balance.NIGHT_SECONDS_PER_LEVEL, "긴 밤 1레벨이면 밤이 길어진다")
	Upgrades.levels[R] = Balance.upgrade_max_level(R)
	Game.vitality = 1e9
	_equal(Upgrades.is_maxed(R), true, "최대 레벨")
	_equal(Upgrades.buy(R), false, "최대면 못 산다")
	_equal(Balance.upgrade_max_level(T), 0, "독한 포자는 상한 없음")
	_equal(Upgrades.is_maxed(T), false, "상한이 없으면 다 차지 않는다")
	_equal(is_inf(Balance.upgrade_cost(T, 100000)), false, "비용은 무한대가 되지 않는다")
	Upgrades.levels[T] = 0
	Game.vitality = Balance.upgrade_cost(T, 0) + Balance.upgrade_cost(T, 1) + Balance.upgrade_cost(T, 2) + 0.5
	_equal(Upgrades.buy_max(T), 3, "최대: 생기로 살 수 있는 만큼 (세 레벨)")
	_equal(Upgrades.level(T) == 3 and Game.vitality < Balance.upgrade_cost(T, 3), true, "남은 생기로는 다음 레벨을 못 산다")
	_equal(Upgrades.buy_max(T), 0, "못 사면 0")
	Upgrades.levels[R] = Balance.upgrade_max_level(R) - 2
	Game.vitality = 1e30
	_equal(Upgrades.buy_max(R), 2, "최대: 상한까지만")
	Game.vitality = 1e300
	_equal(Upgrades.buy_max(T), Balance.BUY_MAX_LIMIT, "상한 없는 칸은 한 번에 BUY_MAX_LIMIT까지")
	var branches: Array[String] = []
	for i in Balance.UPGRADES.size():
		var need := Balance.upgrade_requires(i)
		_equal(need < i, true, "%s: 앞의 업그레이드만 요구한다 (순환 없음, 화면 배치가 기댄다)" % Balance.upgrade_name(i))
		if need < 0:
			branches.append(Balance.UPGRADES[i]["branch"])
	branches.sort()
	_equal(branches, ["down", "left", "right", "up"], "뿌리는 네 갈래에 하나씩")
	_fresh()
