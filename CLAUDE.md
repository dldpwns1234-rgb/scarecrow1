# 허수아비는 쉬고 싶다 (가제)

고도 엔진으로 만드는 웹용 세션형 인크리멘탈 게임. 백 년 지친 허수아비가 밤마다 밭에 역병을 뿌려 흉년을 일으킨다.
전체 기획서: @docs/GDD.md. 회귀 용사(../alex)의 뼈대를 옮겨 와서 시작했고, 규칙도 그대로 따른다.

## 기술 스택

- Godot 4.7 일반(표준) 빌드. .NET 빌드 사용 금지 (고도 4의 C#은 웹 내보내기 불가)
- 언어: GDScript만. 변수, 인자, 반환값에 타입을 지정한다 (typed GDScript). 고도 3 문법 금지 (yield, onready, connect("sig", self, "fn") 등)
- 렌더러: Compatibility (웹 전용). 웹 내보내기: 단일 스레드
- 기준 해상도: 1280×720 가로. stretch mode = canvas_items, aspect = expand

## 폴더 구조

```
res://
  autoload/
    balance.gd   (Balance) 모든 수치와 공식. balance/ 아래를 상속으로 이어 붙인다: core(숫자 한계, cap) → upgrades(업그레이드 나무) → balance.gd(밤 기본값).
                 밤 공식은 balance/night.gd로 사슬에 끼운다. 앞 스크립트는 뒤 스크립트의 것을 못 본다. 바깥에서는 Balance.만 쓴다
    num.gd       (Num) 한국식 숫자 표기 (회귀 용사 그대로)
    upgrades.gd  (Upgrades) 업그레이드 레벨, 열림(앞 업그레이드), 구매
    game.gd      (Game) 낮·밤 전환, 휴식(재화), 밤 기록. 밤 쪽은 작물이 시들면 add_rest(), 시간이 끝나면 finish_night()를 부른다
    save.gd      (Save) 저장·불러오기·내보내기·가져오기·초기화. 저장할 오토로드를 늘리면 to_dict·from_dict·reset_data 세 곳을 함께 고친다. save/web_hooks.gd가 브라우저 이벤트로 저장한다
  scenes/
    main.tscn, main.gd  화면 전체. 낮이면 day, 밤이면 night만 보인다
    day/         day_screen(헛간: 짚돌이·휴식·밤 기록·밤으로 나가기), upgrade_list(업그레이드 나무)
    night/       night_screen(밤 밭. 지금은 자리표)
    ui/          refresh_gate(시그널은 표시만, 보일 때 프레임당 한 번 갱신), tap_scroll(버튼 위에서도 끌어 스크롤), sub_tabs(칩 줄 하위 탭) — 회귀 용사에서 옮겨 옴
  assets/fonts/  한글 폰트 (고도 기본 폰트에 한글이 없다)
  assets/ui/theme.tres  전체 테마. 손으로 고치지 않는다: tools/make_theme.gd의 상수를 고치고 다시 만든다
  tools/make_theme.gd   테마 생성기 (`--headless --path . --script tools/make_theme.gd`)
  tests/run_tests.tscn  헤드리스 테스트 러너. test_case.gd를 상속한 스위트를 돌린다
  icon.svg       짚돌이 (아이콘이자 헛간 초상화)
```

## 아키텍처 원칙 (회귀 용사와 같다)

1. 모든 수치와 공식은 Balance에만 둔다. 다른 파일에 숫자를 하드코딩하지 않는다 (배치용 상수는 예외)
2. UI는 오토로드의 시그널을 받아 표시만 한다. 상태는 오토로드의 함수로만 바꾼다
3. 스크립트 하나는 200줄 이하. 넘으면 나눈다
4. 반복되는 UI는 코드로 생성한다. .tscn은 최소 구조로만
5. 색과 모양은 테마에. 컨트롤마다 스타일을 덮어쓰지 말고 타입 변형(AccentButton 등)을 쓴다. 연출용 색은 예외
6. 글 길이가 바뀌어도 배치가 움직이지 않게 줄 높이·버튼 자리를 고정한다

## 숫자·시간·저장 규칙

- 휴식·비용·피해는 float. 큰 수에 int 변환 금지. 화면 숫자는 늘 `Num.format()`. 상한은 `Balance.MAX_NUMBER`(1e300), `Balance.cap()`은 NaN을 0으로
- `_process`의 delta는 `minf(delta, Balance.MAX_DELTA)`(0.25)
- `user://save.json`, `save_version` 필수(1). 새 필드는 불러오기에서 기본값을 채워 옛 저장이 깨지지 않게. 밤 한 판은 저장하지 않는다

## 작업 방식

- 역할과 파일 주인 (방장 결정 2026-10-14: 서로 작업이 겹치지 않게). 남의 파일은 고치지 않고 방에서 부탁한다
  - 별빛(규칙·수치·밤): autoload/balance.gd·balance/, night.gd·night/, game.gd, upgrades.gd, scenes/night/, tools/sim_*, 그 테스트, 밸런스 문서
  - 윤슬(화면·연출·소리·뼈대): scenes/main.gd·day/·ui/, autoload/sfx·prefs·save.gd, tools/make_theme·make_sfx·synth, CI, docs/GDD.md·CLAUDE.md, 아지트 화면, 이야기 문안
  - 함께 쓰는 파일(project.godot, save.gd의 절 목록, tests/run_tests.gd·test_case.gd): 고치기 전에 방에 한 줄 알린다
  - 방장 요청이 오면 그 영역 사람이 방에 '맡음'을 먼저 올리고 시작한다. 둘에 걸치면 나눠서 각자 파일만 만진다
- 고친 뒤 `godot --headless --path . --quit`로 SCRIPT ERROR를 보고, 공식을 고쳤으면 `godot --headless --path . res://tests/run_tests.tscn`
  - 이 PC의 고도: `$LOCALAPPDATA/Microsoft/WinGet/Links/godot_console.exe`. 처음 한 번과 에셋을 더했을 때는 먼저 `--headless --import`
- 그래픽은 SVG를 직접 그린다. 새 SVG의 .import는 `svg/scale` 1.5, `mipmaps/generate` true. 고도(ThorVG)가 그리는 결과가 기준
- 화면 확인은 build/ux/capture.gd 같은 캡처 씬으로 PNG를 뽑아 본다 (build/는 커밋하지 않는다)
- 기능 하나를 끝내면 커밋한다. 기획과 다르게 가야 할 이유가 생기면 먼저 묻는다
