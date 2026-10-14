extends RefCounted
## 한글 글 다듬기 (화면용). 고도의 줄바꿈은 한글 낱자 사이에서도 줄을 바꿔 낱말이 갈라지므로, 좁은 칸의 설명 글은 여기서 띄어쓰기 자리에서만 줄을 바꾼다.
## 조사도 받침에 맞춰 고른다 ("검둥이를", "볏짚을")


## 띄어쓰기 자리에서만 줄을 바꿔 한 줄이 max_chars 글자를 넘지 않게 한다 (이미 있는 줄바꿈은 그대로). 한 낱말이 더 길면 그 낱말만 한 줄
static func wrap(text: String, max_chars: int) -> String:
	var lines := PackedStringArray()
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			if line.is_empty():
				line = word
			elif line.length() + 1 + word.length() <= max_chars:
				line += " " + word
			else:
				lines.append(line)
				line = word
		lines.append(line)
	return "\n".join(lines)


## 받침이 있으면 with_final, 없으면 without_final (예: 을/를, 이/가, 은/는). 한글이 아니면 without_final
static func particle(word: String, with_final: String, without_final: String) -> String:
	if word.is_empty():
		return without_final
	var code := word.unicode_at(word.length() - 1) - 0xAC00
	if code < 0 or code > 11171:
		return without_final
	return with_final if code % 28 != 0 else without_final
