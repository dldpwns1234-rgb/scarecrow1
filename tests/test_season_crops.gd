extends "res://tests/test_case.gd"
## 철마다 새 작물 (방장 #626): 겨울잠 수로 섞여 들기, 얼음꽃(둘레를 얼린다), 버섯(번진 채 심기고 시들면 상하좌우를 번지게), 달맞이꽃(새벽이 가까울수록)


func run() -> void:
	_test_weights()
	_test_iceflower()
	_test_mushroom()
	_test_moonflower()
	_fresh()
	Winter.reset()
	Night.reset()


func _start(sleeps: int, seed: int = 8) -> void:
	_fresh()
	Winter.reset()
	Night.reset()
	Winter.sleeps = sleeps
	Upgrades.levels[Balance.Upgrade.DENSE] = Balance.upgrade_max_level(Balance.Upgrade.DENSE)
	Night.best_level = 12
	Night.field_level = 12
	Game.start_night()
	Night.begin(seed)
	Night.time_left = 999.0
	Night.night_length = 999.0
	Night.set_cloud(Vector2(-99.0, -99.0))


## kind 작물을 칸에 놓는다 (체력은 밭 단계대로)
func _place(index: int, kind: int) -> void:
	Night.kinds[index] = kind
	Night.max_hp[index] = Balance.crop_hp(kind, Night.field_level)
	Night.hp[index] = Night.max_hp[index]
	Night.infected[index] = 0
	Night.frost[index] = 0
	Night.regrown[index] = 0


func _test_weights() -> void:
	_equal(Balance.crop_season(Balance.Crop.ICEFLOWER), 1, "얼음꽃은 첫 겨울잠 뒤")
	_equal(Balance.crop_season(Balance.Crop.MUSHROOM), 2, "버섯은 둘째 겨울잠 뒤")
	_equal(Balance.crop_season(Balance.Crop.MOONFLOWER), 3, "달맞이꽃은 셋째 겨울잠 뒤")
	_equal(Balance.crop_season(Balance.Crop.GRAPE), 0, "포도는 밭 단계로만")
	_close(Balance.crop_weights(20, 0, 0)[Balance.Crop.ICEFLOWER], 0.0, "첫 철엔 얼음꽃이 없다")
	_equal(Balance.crop_weights(5, 0, 1)[Balance.Crop.ICEFLOWER] > 0.0, true, "첫 겨울잠 뒤엔 그 철 첫 밭부터 얼음꽃")
	_close(Balance.crop_weights(20, 0, 1)[Balance.Crop.MUSHROOM], 0.0, "버섯은 아직")
	_equal(Balance.crop_weights(20, 0, 3)[Balance.Crop.MOONFLOWER] > 0.0, true, "셋째 겨울잠 뒤엔 달맞이꽃")
	var total := 0.0
	for weight in Balance.crop_weights(40, 3, 3):
		total += weight
	_close(total, 1.0, "작물 비율의 합은 1")
	_equal(Balance.crop_unlocked(Balance.Crop.MUSHROOM, 30, 1), false, "겨울잠이 모자라면 안 열림")
	_equal(Balance.crop_unlocked(Balance.Crop.MUSHROOM, 1, 2), true, "겨울잠이 차면 첫 밭부터")


func _test_iceflower() -> void:
	_start(1)
	var size := Night.field_size
	var center := 3 * size + 3
	for y in range(2, 5):
		for x in range(2, 5):
			_place(y * size + x, Balance.Crop.WHEAT)
	_place(center, Balance.Crop.ICEFLOWER)
	var near := center + 1
	var corner := center + size + 1  # 대각선 (1.41칸)
	var far := center + 2
	_place(far, Balance.Crop.WHEAT)
	Night.hp[near] = Night.max_hp[near] * 0.5
	var share := Night.hp[near] / Night.max_hp[near]
	var frozen := [-1]
	Night.crops_frozen.connect(func(index: int, _targets: PackedInt32Array) -> void: frozen[0] = index, CONNECT_ONE_SHOT)
	Night._damage(center, 1e30)
	_equal(frozen[0], center, "얼음꽃이 시들면 둘레를 얼린다")
	_equal(Night.is_frosted(near) and Night.is_frosted(corner), true, "옆 칸과 대각선 칸이 언다")
	_equal(Night.is_frosted(far), false, "두 칸 떨어진 작물은 그대로")
	_close(Night.hp[near] / Night.max_hp[near], share, "얼어도 남은 체력의 몫은 그대로")
	_close(Night.max_hp[near], Balance.crop_hp(Balance.Crop.WHEAT, Night.field_level) * Balance.FROST_HP, "언 작물은 체력 ×2.5")
	Night.stop()


func _test_mushroom() -> void:
	_start(2)
	var mushrooms := 0
	var clean := 0
	for i in Night.cell_count():
		if Night.is_alive(i) and Night.kinds[i] == Balance.Crop.MUSHROOM:
			mushrooms += 1
			clean += 1 if Night.infected[i] == 0 else 0
	_equal(mushrooms > 0, true, "둘째 겨울잠 뒤엔 버섯이 심긴다 (%d)" % mushrooms)
	_equal(clean, 0, "버섯은 번진 채 심긴다")
	var size := Night.field_size
	var center := 3 * size + 3
	for n in [center - 1, center + 1, center - size, center + size]:
		_place(n, Balance.Crop.PUMPKIN)
	_place(center, Balance.Crop.MUSHROOM)
	Night._damage(center, 1e30)
	var infected := 0
	for n in [center - 1, center + 1, center - size, center + size]:
		infected += Night.infected[n]
	_equal(infected, 4, "버섯이 시들면 상하좌우가 다 번진다")
	Night.stop()


func _test_moonflower() -> void:
	_start(3)
	var cell := 0
	_place(cell, Balance.Crop.MOONFLOWER)
	Night.moon = Vector2.ONE * 999.0  # 달빛 밖
	Night.time_left = Night.night_length
	var dusk := Night.crop_vitality(cell)
	Night.time_left = 0.0
	_close(Night.crop_vitality(cell), dusk * (1.0 + Balance.MOONFLOWER_BLOOM), "새벽엔 달맞이꽃 생기 ×3")
	Night.time_left = Night.night_length * 0.5
	_close(Night.crop_vitality(cell), dusk * (1.0 + Balance.MOONFLOWER_BLOOM * 0.5), "밤 한가운데엔 ×2")
	Night.time_left = Night.night_length * 2.0
	_close(Night.night_progress(), 0.0, "새벽 미루기로 밤이 늘면 0 아래로는 안 간다")
	Night.stop()
