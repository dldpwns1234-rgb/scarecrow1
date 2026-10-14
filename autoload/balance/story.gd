extends "res://autoload/balance/winter.gd"
## Balance 4부: 이야기 조각 10개 (docs/STORY.md, 윤슬). 게임 수치에는 영향이 없다.
## 문안은 카드 폭(한 줄 36자 안팎)에 맞춰 문장마다 줄을 바꿨다 (한글은 낱자 사이에서도 줄이 바뀌어 낱말이 갈라지므로).
## 기록(StoryStat)이 목표에 닿고 앞 조각이 열려 있으면 열린다. 순서가 곧 이야기 순서라 건너뛰지 않는다. 열림과 카드는 autoload/story.gd.
## 목표는 봇의 시간표(docs/BALANCE_SIM.md 2026-10-14)에 맞춰 조각 사이가 몇 분씩 벌어지게 잡았다:
## 밤 5번 3분 · 첫 정복 9분 · 5단계 14분 · 10단계 16분 · 첫 겨울잠(12단계부터) · 바친 생기 1조 · 25단계 · 약속된 휴식 백 년(봇 기준 일곱째 철, 5시간쯤. 초 = 60 × 바친 생기^0.135, 별빛 5363ff3).
## 겨울잠은 12단계부터 들 수 있어 25단계 조각 뒤에 두면 첫 겨울잠에 열리지 않는다. 그래서 어둠의 배 앞에 둔다

enum StoryStat { START, NIGHTS, FIELD, OFFERED, WINTERS, REST }

const FRAGMENTS: Array[Dictionary] = [
	{"stat": StoryStat.START, "goal": 0.0, "title": "백 년째 서 있다",
		"text": "장대 하나에 팔 막대 하나. 짚은 백 번 갈았지만\n서 있는 자리는 한 번도 바뀌지 않았다.\n풍년이 들면 농부는 기뻐하고, 밭은 한 뼘 넓어지고,\n나는 한 뼘만큼 더 오래 서 있어야 한다.\n눕고 싶다. 딱 하룻밤만이라도."},
	{"stat": StoryStat.START, "goal": 0.0, "title": "까마귀의 속삭임",
		"text": "쫓아내야 할 까마귀가 내 어깨에 앉았다.\n이상하게 날갯짓 소리가 나지 않았다.\n\"작물의 생기를 내게 바쳐라. 바친 만큼 오래 쉬게 해 주마.\"\n까마귀의 눈 속에 밤보다 깊은 것이 있었다.\n나는 고개를 끄덕였다. 짚으로 된 목이 바스락거렸다."},
	{"stat": StoryStat.NIGHTS, "goal": 5.0, "title": "약속된 휴식",
		"text": "어둠은 내가 바친 생기를 세어 보여 주었다.\n쉴 수 있는 시간이 조금씩 늘어나고 있었다.\n\"백 년을 서 있었으니 백 년은 쉬어야지.\"\n백 년. 그 끝은 아직 보이지 않았다."},
	{"stat": StoryStat.FIELD, "goal": 2.0, "title": "첫 흉년",
		"text": "밭 하나가 통째로 잿빛이 되었다.\n농부는 아침에 오래 서 있다가 돌아갔다.\n어둠이 웃었다. \"잘했다. 휴식이 조금 가까워졌구나.\"\n조금. 그 말이 이상하게 귀에 걸렸다."},
	{"stat": StoryStat.FIELD, "goal": 5.0, "title": "살찌는 밭",
		"text": "어둠이 밭에 무언가를 뿌렸다. 작물이 두 배로 굵어졌다.\n\"살진 작물에서 생기가 더 많이 나온다. 너를 돕는 것이다.\"\n작물이 굵어질수록 밭은 넓어지고, 나는 더 많이 일했다.\n어디서 많이 본 모습이었다."},
	{"stat": StoryStat.FIELD, "goal": 10.0, "title": "다른 허수아비들",
		"text": "이웃 밭의 허수아비가 고개를 돌려 나를 보았다.\n그 어깨에도 까마귀가 앉아 있었다.\n우리는 말없이 같은 밤을 보냈다.\n지친 것들은 서로를 알아본다."},
	{"stat": StoryStat.WINTERS, "goal": 1.0, "title": "겨울잠",
		"text": "눈이 밭을 덮었다. 어둠은 봄까지 기다리라고 했다.\n나는 처음으로 짧게 잠들었다. 꿈속에서 아무것도 지키지 않았다.\n깨어 보니 봄이었고, 밭은 다시 푸르렀다."},
	{"stat": StoryStat.OFFERED, "goal": 1e12, "title": "어둠의 배",
		"text": "어둠은 이제 까마귀만 한 크기가 아니다. 달을 가릴 만큼 커졌다.\n생기를 먹을수록 어둠은 커지고, 어둠이 클수록 밭도 커진다.\n풍년과 무엇이 다른가. 나는 처음으로 계약을 의심했다."},
	{"stat": StoryStat.FIELD, "goal": 25.0, "title": "농부의 한숨",
		"text": "새벽에 농부가 밭 가장자리에 주저앉아 있었다.\n굽은 등이 내 장대처럼 굳어 있었다.\n\"올해도 망했네.\" 농부는 그렇게 말하고, 이상하게도 조금 웃었다.\n농부도 백 년 같은 일을 하고 있었구나."},
	{"stat": StoryStat.REST, "goal": STORY_REST_GOAL, "title": "휴경지의 별",
		"text": "약속된 휴식이 백 년에 닿았다.\n나는 마지막 생기를 어둠이 아니라 밭에 돌려주었다.\n어둠은 배를 움켜쥐고 작아지더니, 그냥 까마귀가 되었다.\n농부는 밭을 묵히고 도시로 떠났다. 아무도 이 밭을 지키라고 하지 않는다.\n나는 휴경지에 처음으로 누웠다. 별이 많다.\n까마귀가 내 옆에 내려앉았다. 오늘은 쫓아내지 않기로 했다."},
]
const INTRO_FRAGMENTS: int = 2  # 첫 실행 장면이 앞의 두 조각을 보여 준다 (장면을 보면 본 것으로 친다)
const STORY_REST_GOAL: float = 100.0 * 365.25 * 86400.0  # 약속된 휴식 백 년 (balance.gd의 HUNDRED_YEARS_SECONDS와 같다. 사슬 뒤라 여기서는 못 본다)


## 약속된 휴식이 백 년까지 얼마나 왔는지 (0~1, 로그 눈금: 1초 = 0, 백 년 = 1). 낮 화면의 금색 막대 (이야기 조각 3·10의 '백 년')
## 몇 분에서 백 년까지 열 자리 넘게 커지는 수라 그대로 나누면 막대가 끝까지 거의 비어 있다
func promise_progress(seconds: float) -> float:
	if seconds <= 1.0:
		return 0.0
	return clampf(log(seconds) / log(STORY_REST_GOAL), 0.0, 1.0)


func fragment_stat(index: int) -> int:
	return FRAGMENTS[index]["stat"]


func fragment_goal(index: int) -> float:
	return FRAGMENTS[index]["goal"]


## 다시 읽기 목록에 보일, 아직 안 열린 다음 조각의 조건
func fragment_hint(index: int) -> String:
	var goal := fragment_goal(index)
	match fragment_stat(index):
		StoryStat.NIGHTS:
			return "밤 %d번" % int(goal)
		StoryStat.FIELD:
			return "밭 %d단계 열기" % int(goal) if goal > 2.0 else "첫 밭 정복"
		StoryStat.OFFERED:
			return "바친 생기 %s" % Num.format(goal)
		StoryStat.WINTERS:
			return "첫 겨울잠"
		StoryStat.REST:
			return "약속된 휴식 백 년"
	return ""
