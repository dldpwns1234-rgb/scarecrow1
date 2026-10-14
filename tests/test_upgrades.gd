extends "res://tests/test_case.gd"
## 업그레이드 나무: 비용, 열림(앞 업그레이드), 구매, 상한 (GDD 6절)


func run() -> void:
	_fresh()
	var R: int = Balance.Upgrade.RADIUS
	var N: int = Balance.Upgrade.LONG_NIGHT
	_close(Balance.upgrade_cost(R, 0), 10.0, "넓은 구름 첫 비용")
	_close(Balance.upgrade_cost(R, 1), 16.0, "다음 비용은 ×1.6")
	_equal(Upgrades.is_unlocked(R), true, "처음부터 열림")
	_equal(Upgrades.is_unlocked(N), false, "긴 밤은 넓은 구름이 있어야")
	_equal(Upgrades.can_buy(R), false, "휴식이 없으면 못 산다")
	Game.rest = 100.0
	_equal(Upgrades.buy(N), false, "잠긴 것은 못 산다")
	_equal(Upgrades.buy(R), true, "넓은 구름 구매")
	_close(Game.rest, 90.0, "비용만큼 썼다")
	_equal(Upgrades.is_unlocked(N), true, "긴 밤이 열린다")
	_equal(Upgrades.buy(N), true, "긴 밤 구매")
	_close(Game.night_seconds(), Balance.NIGHT_BASE_SECONDS + Balance.NIGHT_SECONDS_PER_LEVEL, "긴 밤 1레벨이면 밤이 길어진다")
	Upgrades.levels[R] = Balance.upgrade_max_level(R)
	Game.rest = 1e9
	_equal(Upgrades.is_maxed(R), true, "최대 레벨")
	_equal(Upgrades.buy(R), false, "최대면 못 산다")
	var T: int = Balance.Upgrade.TOXIN
	_equal(Balance.upgrade_max_level(T), 0, "독한 포자는 상한 없음")
	_equal(Upgrades.is_maxed(T), false, "상한이 없으면 다 차지 않는다")
	_equal(is_inf(Balance.upgrade_cost(T, 100000)), false, "비용은 무한대가 되지 않는다")
	for i in Balance.UPGRADES.size():
		var need := Balance.upgrade_requires(i)
		_equal(need < i, true, "%d번은 앞의 업그레이드만 요구한다 (순환 없음)" % i)
	_fresh()
