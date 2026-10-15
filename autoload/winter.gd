extends Node
## 겨울잠 (회귀, GDD 8절 M4): 열린 밭 단계가 12 이상이면 겨울잠에 들어 꿈 조각을 받고 생기·어둠의 나무·밭 단계를 내려놓는다.
## 남는 것: 꿈 조각과 꿈의 상점, 겨울잠 횟수, 바친 생기 합(약속된 휴식), 밤 수, 이야기, 설정. 꿈의 상점 효과는 Night·Game이 아래 함수로 묻는다.
## 상태 변경은 이 오토로드의 함수로만 하고 UI는 표시만 한다

signal shards_changed(shards: float)
signal dream_changed(index: int, level: int)
signal slept(reward: float)  # 겨울잠에 들었다. 받은 꿈 조각

var shards: float = 0.0          # 꿈 조각
var dream_levels: Array[int] = []  # 꿈의 상점 레벨. Balance.Dream 순서
var sleeps: int = 0              # 겨울잠 횟수


func _ready() -> void:
	reset()


## 데이터 초기화에서만 부른다. 겨울잠은 perform()이다
func reset() -> void:
	shards = 0.0
	sleeps = 0
	dream_levels.clear()
	dream_levels.resize(Balance.DREAMS.size())
	dream_levels.fill(0)
	shards_changed.emit(shards)
	for i in dream_levels.size():
		dream_changed.emit(i, 0)


func to_dict() -> Dictionary:
	return {"shards": shards, "dream_levels": dream_levels.duplicate(), "sleeps": sleeps}


## 없는 필드는 기본값으로, 상한을 넘는 레벨은 상한으로 (옛 저장·망가진 저장)
func from_dict(data: Dictionary) -> void:
	reset()
	shards = Balance.cap(maxf(float(data.get("shards", 0.0)), 0.0))
	sleeps = maxi(int(data.get("sleeps", 0)), 0)
	var saved: Variant = data.get("dream_levels", [])
	if saved is Array:
		for i in mini((saved as Array).size(), dream_levels.size()):
			var cap := Balance.dream_max_level(i)
			dream_levels[i] = clampi(int(saved[i]), 0, cap if cap > 0 else 1000000)
	shards_changed.emit(shards)
	for i in dream_levels.size():
		dream_changed.emit(i, dream_levels[i])


func level(index: int) -> int:
	return dream_levels[index]


## 낮에만, 열린 밭 단계가 12 이상일 때
func can_sleep() -> bool:
	return not Game.is_night() and Balance.can_winter(Night.best_level)


## 지금 겨울잠에 들면 받을 꿈 조각
func shard_reward() -> float:
	return Balance.shard_reward(Night.best_level)


## 겨울잠: 꿈 조각을 받고 한 철을 내려놓는다. 새 철은 겨울 씨앗만큼 열린 밭과 기억하는 손의 업그레이드로 시작한다
func perform() -> bool:
	if not can_sleep():
		return false
	var reward := shard_reward()
	shards = Balance.cap(shards + reward)
	sleeps += 1
	Game.start_season()
	Upgrades.start_season(level(Balance.Dream.HANDS))
	Night.start_season(Balance.winter_start_level(level(Balance.Dream.WINTER_SEED)))
	shards_changed.emit(shards)
	slept.emit(reward)
	Save.save_game()
	return true


## 겨울잠 밖에서 받는 꿈 조각 (도깨비불의 꿈 부스러기)
func add_shards(amount: float) -> void:
	if amount <= 0.0:
		return
	shards = Balance.cap(shards + amount)
	shards_changed.emit(shards)


func is_maxed(index: int) -> bool:
	var cap := Balance.dream_max_level(index)
	return cap > 0 and dream_levels[index] >= cap


func cost(index: int) -> float:
	return Balance.dream_cost(index, dream_levels[index])


func can_buy(index: int) -> bool:
	return not is_maxed(index) and shards >= cost(index)


func buy(index: int) -> bool:
	if not can_buy(index):
		return false
	shards -= cost(index)
	dream_levels[index] += 1
	shards_changed.emit(shards)
	dream_changed.emit(index, dream_levels[index])
	return true


# 효과 (Night·Game이 묻는다)

func damage_multiplier() -> float:
	return Balance.dream_damage_multiplier(level(Balance.Dream.DEEP_SLEEP))


func vitality_multiplier() -> float:
	return Balance.dream_vitality_multiplier(level(Balance.Dream.DREAM_HARVEST))


func extra_crows() -> int:
	return level(Balance.Dream.DREAM_CROW)


func extra_seconds() -> float:
	return Balance.sleepwalk_seconds(level(Balance.Dream.SLEEPWALK))
