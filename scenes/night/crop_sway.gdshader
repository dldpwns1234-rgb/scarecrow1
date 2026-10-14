shader_type canvas_item;
// 밤 작물 (field_view.gd가 모든 작물 그림에 같이 씌운다): 밑동은 두고 위쪽만 바람에 흔들리고, 달빛 아래 푸르스름하게 가라앉히고,
// 머리께는 달빛을 받아 조금 밝힌다. 칸마다 흔들림 박자가 달라 물결처럼 지나간다. 그림 좌표는 밑동이 원점 (field_view의 offset)

uniform float sway_amount = 7.0;       // 머리 끝이 흔들리는 폭 (그림 픽셀)
uniform float sway_speed = 1.5;
uniform float picture_height = 144.0;  // 그림 높이 (96 × 가져오기 1.5배)
uniform vec3 night_tint : source_color = vec3(0.78, 0.82, 0.96);
uniform vec3 moon_light : source_color = vec3(1.0, 0.95, 0.78);
uniform float moon_rim = 0.16;         // 머리께가 받는 달빛 세기

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float lift = clamp(-VERTEX.y / picture_height, 0.0, 1.0);
	float phase = world.x * 0.021 + world.y * 0.013;
	VERTEX.x += (sin(TIME * sway_speed + phase) + 0.35 * sin(TIME * sway_speed * 2.3 + phase * 1.7)) * sway_amount * lift * lift;
}

void fragment() {
	vec4 c = COLOR;
	c.rgb *= night_tint;
	float top = 1.0 - UV.y;
	c.rgb += moon_light * moon_rim * top * top * c.a;
	COLOR = c;
}
