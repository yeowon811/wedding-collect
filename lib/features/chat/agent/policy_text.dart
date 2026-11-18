/// 정책 지원 자격 원문에서 숫자 조건 읽기 (소득 상한·최대 지원 금액). 단위는 만원.
/// 원문에 숫자로 적혀 있을 때만 읽고, 없으면 null ("원문 확인 필요"로 남긴다).
library;

double? _num(String s) => double.tryParse(s.replaceAll(',', ''));

/// "7.5천만원" → 7500, "1.3억" → 13000, "100만원" → 100, "3억원" → 30000
int? toManwon(String number, String unit) {
  final n = _num(number);
  if (n == null) return null;
  return switch (unit) {
    '억' => (n * 10000).round(),
    '천만' || '천' => (n * 1000).round(),
    '백만' => (n * 100).round(),
    _ => n.round(),
  };
}

const _money = r'([\d,]+(?:\.\d+)?)\s*(억|천만|천|백만|만)\s*원?';

/// 소득 상한: "부부합산 연소득 7.5천만원 이하" → 7500
int? incomeCap(String eligibility) {
  final m = RegExp('(?:연\\s*소득|소득)[^/()]{0,12}?$_money\\s*이하').firstMatch(eligibility);
  return m == null ? null : toManwon(m[1]!, m[2]!);
}

/// 원문의 최대 지원 금액: "최대 3억원", "최대 100만 원" → 만원 (여러 개면 가장 큰 값)
int? maxAmount(String eligibility) {
  final all = [
    for (final m in RegExp('최대\\s*$_money').allMatches(eligibility)) toManwon(m[1]!, m[2]!),
  ].whereType<int>().toList();
  return all.isEmpty ? null : all.reduce((a, b) => a > b ? a : b);
}

/// 질문 속 소득: "부부 합산 소득 7천만원", "연봉 합쳐서 8천" → 만원
int? incomeFromQuestion(String q) {
  final m = RegExp('(?:소득|연봉|벌이|수입)[^\\d]{0,8}$_money').firstMatch(q);
  return m == null ? null : toManwon(m[1]!, m[2]!);
}

/// 만원 → "7,500만원" / "3억원" / "1억 3,000만원"
String manwonLabel(int v) {
  String comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  if (v < 10000) return '${comma(v)}만원';
  final eok = v ~/ 10000, rest = v % 10000;
  return rest == 0 ? '$eok억원' : '$eok억 ${comma(rest)}만원';
}

/// 원문에서 단어 주변만 짧게
String? snippetAround(String text, RegExp word, {int before = 15, int after = 45}) {
  final m = word.firstMatch(text);
  if (m == null) return null;
  final s = (m.start - before).clamp(0, text.length);
  final e = (m.end + after).clamp(0, text.length);
  return '${s > 0 ? '…' : ''}${text.substring(s, e).trim()}${e < text.length ? '…' : ''}';
}
