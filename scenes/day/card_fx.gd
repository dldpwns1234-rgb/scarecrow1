extends RefCounted
## 어둠의 나무 카드 연출: 새로 나타날 때 작게 시작해 떠오르고, 샀을 때 톡 튀며 금빛으로 번쩍인다 (방장 #529: 살 때마다 자라는 맛).
## 카드의 부모는 판(tree_board)이고, 연출이 끝나면 그때의 판 줌에 크기를 맞춘다. 연출 중인 카드는 판이 크기를 건드리지 않는다(busy). 상수는 연출용이다

const REVEAL_SECONDS: float = 0.35
const PULSE_UP_SECONDS: float = 0.1
const PULSE_DOWN_SECONDS: float = 0.22
const PULSE_SCALE: float = 1.18
const FLASH := Color(1.7, 1.45, 0.75)   # 산 순간 금빛으로 밝게, 천천히 제 색으로


static func reveal(card: Button, zoom: float) -> void:
	card.scale = Vector2.ONE * 0.6 * zoom
	card.modulate.a = 0.0
	var tween := _start(card)
	tween.tween_property(card, "scale", Vector2.ONE * zoom, REVEAL_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, REVEAL_SECONDS)
	_finish(card, tween)


static func pulse(card: Button, zoom: float) -> void:
	var tween := _start(card)
	card.modulate = FLASH
	tween.tween_property(card, "modulate", Color.WHITE, PULSE_UP_SECONDS + PULSE_DOWN_SECONDS)
	tween.tween_property(card, "scale", Vector2.ONE * zoom * PULSE_SCALE, PULSE_UP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * zoom, PULSE_DOWN_SECONDS).set_delay(PULSE_UP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_finish(card, tween)


static func busy(card: Button) -> bool:
	return card.has_meta("fx")


## 앞 연출이 돌고 있으면 멈추고 새로 시작한다
static func _start(card: Button) -> Tween:
	if busy(card):
		(card.get_meta("fx") as Tween).kill()
	var tween := card.create_tween().set_parallel(true)
	card.set_meta("fx", tween)
	return tween


static func _finish(card: Button, tween: Tween) -> void:
	tween.chain().tween_callback(func() -> void:
		card.remove_meta("fx")
		card.modulate = Color.WHITE
		card.scale = Vector2.ONE * float(card.get_parent().get("zoom")))
