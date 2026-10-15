extends RefCounted
## 마을 소문 문안 (방장 #587, 장르 조사 제안 1: Cookie Clicker 뉴스 티커처럼 진행에 따라 바뀌는 한 줄). balance/story.gd가 불러 Balance.rumors_now로 내보낸다.
## stat은 any(늘)·nights(밤 수)·field(겨울잠을 넘어 가장 높이 연 밭 단계)·winters(겨울잠 수)·offered(바친 생기), from 이상이고 until(있으면) 미만일 때 들린다.
## 마을 사람의 말투로, 사람은 다치지 않는다(GDD 1절). 밭 단계 소문은 그 단계에 처음 나오는 것(작물·지키는 이)에 맞췄다. 한 줄 36자 안쪽

const LINES: Array[Dictionary] = [
	{"stat": "any", "from": 0.0, "text": "짚을 새로 갈아 줬는데도 허수아비가 피곤해 보인대."},
	{"stat": "any", "from": 0.0, "text": "밤에 밭에서 바스락 소리가 나면 뒤돌아보지 말래."},
	{"stat": "any", "from": 0.0, "text": "까마귀 한 마리가 밤마다 같은 허수아비 어깨에만 앉는대."},
	{"stat": "any", "from": 0.0, "text": "방앗간 할멈 말로는 올해 달이 유난히 낮게 뜬대."},
	# 처음 며칠
	{"stat": "nights", "from": 0.0, "until": 20.0, "text": "윗마을 밀밭에 밤새 잿빛 곰팡이가 피었대."},
	{"stat": "nights", "from": 0.0, "until": 20.0, "text": "요즘 허수아비들이 밤마다 고개를 돌린다나."},
	{"stat": "nights", "from": 0.0, "until": 40.0, "text": "농부 영감이 아침마다 밭을 세어 보고 한숨을 쉰대."},
	{"stat": "nights", "from": 3.0, "until": 40.0, "text": "올해는 풍년이라더니, 어째 밤이 길어진 것 같지 않아?"},
	{"stat": "nights", "from": 30.0, "text": "아이들이 '밤 까마귀' 노래를 부르며 놀더라."},
	{"stat": "nights", "from": 80.0, "text": "흉흉한 밤이 하도 길어서 다들 날짜를 잊었대."},
	# 밭 단계 (작물: 순무 3·해바라기 6·수박 10·포도 16, 지키는 이: 감독관 25·관리 45·여신 70, 수확일 5단계마다, 아지트 10)
	{"stat": "field", "from": 2.0, "text": "밭 하나가 통째로 시들었대. 벌레 한 마리 없었는데."},
	{"stat": "field", "from": 2.0, "until": 30.0, "text": "약장수가 보랏빛 구름을 봤다고 떠들고 다녀."},
	{"stat": "field", "from": 3.0, "text": "순무는 한 포기가 시들면 무더기로 따라 시든대."},
	{"stat": "field", "from": 5.0, "text": "수확일엔 온 마을이 밭을 지킨대. 횃불까지 들고."},
	{"stat": "field", "from": 6.0, "text": "해바라기가 쓰러지면서 옆 줄기까지 꺾었대."},
	{"stat": "field", "from": 10.0, "text": "수박이 밤중에 펑 터졌대. 밭이 온통 빨갛더래."},
	{"stat": "field", "from": 10.0, "text": "이웃 밭 허수아비가 감쪽같이 사라졌대."},
	{"stat": "field", "from": 16.0, "text": "포도 덩굴이 한 줄로 쭉 말라 들어갔대."},
	{"stat": "field", "from": 20.0, "text": "밭은 해마다 넓어지는데 일손은 그대로래."},
	{"stat": "field", "from": 25.0, "text": "마을에서 밭 감독관을 불렀대. 등불 들고 밤새 돈다나."},
	{"stat": "field", "from": 25.0, "text": "감독관이 허수아비를 한참 들여다보다 갔대."},
	{"stat": "field", "from": 45.0, "text": "영주가 관리를 보냈대. 약통을 둘이나 메고."},
	{"stat": "field", "from": 70.0, "text": "풍년의 여신이 직접 밭에 내려온다는 소문이야."},
	{"stat": "field", "from": 100.0, "text": "이제는 지도에 없는 밭까지 생겼대."},
	{"stat": "field", "from": 150.0, "text": "밭 끝이 안 보인대. 허수아비만 끝없이 서 있고."},
	# 겨울잠
	{"stat": "winters", "from": 1.0, "text": "겨울 내내 허수아비가 눈을 감고 있었대."},
	{"stat": "winters", "from": 1.0, "until": 3.0, "text": "봄이 왔는데 밭이 작년보다 더 넓어졌어."},
	{"stat": "winters", "from": 2.0, "text": "올해도 흉년이면 마을을 떠나겠다는 집이 늘었대."},
	{"stat": "winters", "from": 2.0, "text": "농부 영감이 허수아비한테 말을 걸더래. 대답은 없었고."},
	{"stat": "winters", "from": 3.0, "text": "흉년이 세 해째라 예배당에서 기도회를 연대."},
	{"stat": "winters", "from": 4.0, "text": "도시로 간 사람들이 편지를 보냈대. 거기도 다들 지쳤대."},
	# 바친 생기 (이야기 조각 '어둠의 배' 10조·'농부의 한숨' 1경과 함께 짙어진다, 별빛 2ec315d 곡선: 1억 30분 · 10조 97분 · 1경 152분 · 10경 165분)
	{"stat": "offered", "from": 1e8, "text": "밤하늘로 반딧불 같은 게 줄지어 올라간대."},
	{"stat": "offered", "from": 1e13, "text": "구름도 없는데 달이 반쯤 가려진 밤이 잦아졌어."},
	{"stat": "offered", "from": 1e13, "text": "까마귀 그림자가 지붕만큼 크더래."},
	{"stat": "offered", "from": 1e16, "text": "어둠이 마을 우물까지 내려왔다는 말이 있어."},
	{"stat": "offered", "from": 1e16, "text": "농부들이 허수아비 옆에 의자를 하나씩 놓기 시작했대."},
	{"stat": "offered", "from": 1e17, "text": "오래 쓴 밭은 쉬게 둬야 한다고 할머니가 그러시더라."},
]
