/// 상담 속 단순 계산 ("식대 6만5천원에 150명이면?"). Gemini는 식만 만들고 계산은 앱이 한다.
library;

/// 숫자·괄호·+−×÷만 있는 식을 계산. 형식이 틀리면 null
num? evalExpr(String expr) {
  final s = expr.replaceAll(RegExp(r'[\s,원]'), '').replaceAll('×', '*').replaceAll('x', '*').replaceAll('÷', '/');
  if (s.isEmpty || !RegExp(r'^[\d.+\-*/()]+$').hasMatch(s)) return null;
  var i = 0;
  late num? Function() parseExpr;
  num? parseNum() {
    final m = RegExp(r'^\d+(\.\d+)?').firstMatch(s.substring(i));
    if (m == null) return null;
    i += m[0]!.length;
    return num.parse(m[0]!);
  }

  num? parseAtom() {
    if (i < s.length && s[i] == '(') {
      i++;
      final v = parseExpr();
      if (v == null || i >= s.length || s[i] != ')') return null;
      i++;
      return v;
    }
    if (i < s.length && s[i] == '-') {
      i++;
      final v = parseAtom();
      return v == null ? null : -v;
    }
    return parseNum();
  }

  num? parseTerm() {
    var v = parseAtom();
    while (v != null && i < s.length && (s[i] == '*' || s[i] == '/')) {
      final op = s[i++];
      final r = parseAtom();
      if (r == null || (op == '/' && r == 0)) return null;
      v = op == '*' ? v * r : v / r;
    }
    return v;
  }

  parseExpr = () {
    var v = parseTerm();
    while (v != null && i < s.length && (s[i] == '+' || s[i] == '-')) {
      final op = s[i++];
      final r = parseTerm();
      if (r == null) return null;
      v = op == '+' ? v + r : v - r;
    }
    return v;
  };
  final v = parseExpr();
  return v != null && i == s.length ? v : null;
}

/// "6만5천원", "65,000원", "3천만원", "200만원" → 원
int? parseWon(String t) {
  final m = RegExp(r'(\d+)\s*억\s*(?:(\d+)\s*천)?\s*(?:(\d+)\s*백)?\s*만?\s*원?|(\d+)\s*천\s*만\s*원?|(\d+)\s*만\s*(?:(\d+)\s*천)?\s*원?|(\d+)\s*천\s*원|(\d{1,3}(?:,\d{3})+|\d{4,})\s*원')
      .firstMatch(t);
  if (m == null) return null;
  int g(int i) => int.parse(m[i]!.replaceAll(',', ''));
  if (m[1] != null) return g(1) * 100000000 + (m[2] != null ? g(2) * 10000000 : 0) + (m[3] != null ? g(3) * 1000000 : 0);
  if (m[4] != null) return g(4) * 10000000;
  if (m[5] != null) return g(5) * 10000 + (m[6] != null ? g(6) * 1000 : 0);
  if (m[7] != null) return g(7) * 1000;
  return g(8);
}

/// 규칙으로 만든 식: 금액 + N명 + '얼마/이면/계산' → "금액*N"
String? ruleCalc(String text) {
  if (!RegExp(r'얼마|이면|계산|총').hasMatch(text)) return null;
  final won = parseWon(text);
  // "1인 6만5천원에 150명": '1인'은 단가 단위라 명·장·개를 먼저 본다
  final people = RegExp(r'(\d{1,4})\s*(?:명|장|개)').firstMatch(text) ??
      RegExp(r'(\d{2,4})\s*인').firstMatch(text);
  if (won == null || people == null) return null;
  return '$won*${people[1]}';
}

String _comma(num n) {
  final s = n.round().toString();
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

/// 원 금액 읽기 좋게: 9,750,000원 (약 975만원)
String wonLabel(num won) {
  final base = '${_comma(won)}원';
  if (won.abs() < 10000) return base;
  final man = won / 10000;
  final manText = man == man.roundToDouble() ? _comma(man) : man.toStringAsFixed(1);
  return '$base (약 $manText만원)';
}

/// 식을 사람이 읽는 모양으로: 65000*150 → 65,000 × 150
String exprLabel(String expr) => expr
    .replaceAll(' ', '')
    .replaceAllMapped(RegExp(r'\d+(\.\d+)?'), (m) => m[0]!.contains('.') ? m[0]! : _comma(int.parse(m[0]!)))
    .replaceAll('*', ' × ')
    .replaceAll('/', ' ÷ ')
    .replaceAll('+', ' + ')
    .replaceAllMapped(RegExp(r'(?<=\d)-'), (_) => ' − ');
