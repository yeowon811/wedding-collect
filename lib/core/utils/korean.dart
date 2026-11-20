/// 한국어 조사 붙이기 (앱이 만드는 문장용).
///
/// "{이름}을/를"처럼 앞말의 받침에 따라 달라지는 조사를 골라 준다.
/// - 한글: 마지막 글자의 받침 (ㄹ 받침은 '으로' 대신 '로')
/// - 숫자: 읽는 소리 (0 영, 1 일, 3 삼, 6 육, 7 칠, 8 팔 → 받침 있음 / 1·7·8은 ㄹ)
/// - 영문: 마지막 글자 소리를 대략 (l·m·n·ng → 받침)
/// - 괄호·따옴표·공백은 건너뛰고 그 앞 글자로 판단 ("SETEC(컨벤션홀)" → 홀)
library;

/// 받침 종류: null 판단 불가 · 0 없음 · 1 있음(ㄹ 아님) · 2 ㄹ 받침
int? _final(String word) {
  var s = word.trimRight();
  // 끝의 괄호 묶음·따옴표는 읽지 않는다
  while (s.isNotEmpty) {
    final last = s[s.length - 1];
    if (last == ')' || last == ']') {
      final open = s.lastIndexOf(last == ')' ? '(' : '[');
      if (open <= 0) break;
      s = s.substring(0, open).trimRight();
      continue;
    }
    if ('"\'”’」』·.,!?~ '.contains(last)) {
      s = s.substring(0, s.length - 1);
      continue;
    }
    break;
  }
  if (s.isEmpty) return null;
  final c = s.codeUnitAt(s.length - 1);
  if (c >= 0xAC00 && c <= 0xD7A3) {
    final jong = (c - 0xAC00) % 28;
    if (jong == 0) return 0;
    return jong == 8 ? 2 : 1; // 8 = ㄹ
  }
  final ch = s[s.length - 1];
  if (RegExp(r'\d').hasMatch(ch)) {
    return switch (ch) { '0' || '3' || '6' => 1, '1' || '7' || '8' => 2, _ => 0 };
  }
  final lower = ch.toLowerCase();
  if (RegExp(r'[a-z]').hasMatch(lower)) {
    if (lower == 'l') return 2;
    if ('mn'.contains(lower)) return 1;
    if (s.toLowerCase().endsWith('ng')) return 1;
    // 끝소리가 받침으로 읽히는 자음 (SETEC → 세텍이, App → 앱이)
    if ('kcptbdg'.contains(lower)) return 1;
    return 0;
  }
  return null;
}

/// [word]에 맞는 조사. [pair]는 '을/를', '이/가', '은/는', '과/와', '으로/로', '이에요/예요', '이나/나', '아/야'
String josa(String word, String pair) {
  final parts = pair.split('/');
  if (parts.length != 2) return pair;
  final (withFinal, noFinal) = (parts[0], parts[1]);
  final f = _final(word);
  if (f == null) return '$withFinal($noFinal)'; // 판단할 수 없으면 둘 다 보여 준다
  if (pair == '으로/로') return f == 1 ? withFinal : noFinal;
  return f == 0 ? noFinal : withFinal;
}

/// 단어 + 알맞은 조사
String withJosa(String word, String pair) => '$word${josa(word, pair)}';

const _pairs = ['을/를', '이/가', '은/는', '과/와', '으로/로', '이에요/예요', '이나/나', '아/야'];

/// 문장 속 "을(를)", "이(가)", "{이름}을/를" 같은 표기를 앞말에 맞게 고친다.
/// 앱이 만든 문장을 내보내기 전에 한 번 거친다. 이미 맞는 조사는 건드리지 않는다.
String fixJosa(String text) {
  var out = text;
  for (final pair in _pairs) {
    final p = pair.split('/');
    // 'X을(를)' · 'X을/를' 꼴
    for (final pattern in ['${p[0]}(${p[1]})', '${p[1]}(${p[0]})', '${p[0]}/${p[1]}']) {
      var i = out.indexOf(pattern);
      while (i > 0) {
        final before = out.substring(0, i);
        final word = before.split(RegExp(r'\s')).last;
        final right = josa(word, pair);
        out = '$before$right${out.substring(i + pattern.length)}';
        i = out.indexOf(pattern, before.length + right.length);
      }
    }
  }
  return out;
}

/// 이미 붙어 있는 조사가 틀렸으면 고친다: "SETEC 컨벤션홀를" → "SETEC 컨벤션홀을".
/// 앱이 이름 뒤에 조사를 붙인 문장에만 쓴다 ([names]에 있는 이름 뒤만 본다).
String fixJosaAfter(String text, Iterable<String> names) {
  var out = text;
  for (final name in names) {
    if (name.isEmpty) continue;
    for (final pair in _pairs) {
      final p = pair.split('/');
      for (final wrongSide in [p[0], p[1]]) {
        final pattern = '$name$wrongSide';
        var i = out.indexOf(pattern);
        while (i >= 0) {
          final end = i + pattern.length;
          // 조사 뒤가 한글로 이어지면 다른 말일 수 있다 ("홀이에요"의 '이' 등) → 건너뜀
          final nextIsHangul = end < out.length && RegExp(r'[가-힣]').hasMatch(out[end]);
          if (!nextIsHangul) {
            final right = josa(name, pair);
            out = '${out.substring(0, i)}$name$right${out.substring(end)}';
          }
          i = out.indexOf(pattern, i + name.length + 1);
        }
      }
    }
  }
  return out;
}
