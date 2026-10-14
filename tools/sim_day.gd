extends Node
## 밤 시뮬레이션 1부: 낮의 사람 흉내 (tools/sim_night.gd가 상속한다). 어둠의 나무와 헛간 확장을 싼 것부터 다 사고,
## 일꾼을 맞는 일자리부터 채우고(까마귀 → 망보기, 허수아비 → 포자 말리기, 남으면 생기 나르기) 낮 동안 생기 나르기를 흘리고, 겨울잠 뒤 꿈의 상점을 싼 것부터 다 산다

var _day: float = 15.0  # 밤 사이 낮에 쓰는 초


## 살 수 있는 업그레이드와 헛간 확장을 싼 것부터 다 산다. 산 것의 이름 목록
func _shop() -> String:
	var names: Array[String] = []
	while true:
		var pick := -1
		for i in Balance.UPGRADES.size():
			if Upgrades.can_buy(i) and (pick < 0 or Upgrades.cost(i) < Upgrades.cost(pick)):
				pick = i
		var expand := -1
		for j in Balance.JOBS.size():
			if Workers.can_expand(j) and (expand < 0 or Workers.expand_cost(j) < Workers.expand_cost(expand)):
				expand = j
		if expand >= 0 and (pick < 0 or Workers.expand_cost(expand) < Upgrades.cost(pick)):
			Workers.expand(expand)
			names.append("헛간 확장")
			continue
		if pick < 0 or not Upgrades.buy(pick):
			break
		names.append(Balance.upgrade_name(pick))
	return ",".join(names)


## 낮: 일꾼을 맞는 일자리부터 채우고(까마귀 → 망보기, 허수아비 → 포자 말리기, 남으면 생기 나르기), 낮 동안 생기 나르기를 흘린다
func _day_work() -> void:
	for w in Workers.worker_count():
		var favored := Balance.Job.WATCH if Workers.worker_kind(w) == Balance.Worker.CROW else Balance.Job.DRY
		if Workers.worker_job(w) < 0 and not Workers.assign(w, favored):
			Workers.assign(w, Balance.Job.CARRY)
	var left := _day
	while left > 0.0:
		Workers._process(minf(left, Balance.MAX_DELTA))
		left -= Balance.MAX_DELTA


## 꿈의 상점을 싼 것부터 다 산다
func _dream_shop() -> String:
	var names: Array[String] = []
	while true:
		var pick := -1
		for i in Balance.DREAMS.size():
			if Winter.can_buy(i) and (pick < 0 or Winter.cost(i) < Winter.cost(pick)):
				pick = i
		if pick < 0 or not Winter.buy(pick):
			break
		names.append(Balance.dream_name(pick))
	var parts: Array[String] = []
	for i in Balance.DREAMS.size():
		parts.append("%s %d" % [Balance.dream_name(i), Winter.level(i)])
	return ", ".join(parts)
