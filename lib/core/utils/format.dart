/// 금액(만원 단위) 표시: 1250 → "1,250만원", 12000 → "1억 2,000만원"
/// 좁은 칸용 짧은 금액: 3000 → "3천만원", 2500 → "2,500만원", 12000 → "1억 2천만원"
String formatManwonShort(int manwon) {
  String part(int m) => m % 1000 == 0 && m > 0 ? '${m ~/ 1000}천만원' : '${_comma(m)}만원';
  if (manwon >= 10000) {
    final eok = manwon ~/ 10000;
    final rest = manwon % 10000;
    return rest == 0 ? '$eok억원' : '$eok억 ${part(rest)}';
  }
  return part(manwon);
}

String formatManwon(int manwon) {
  if (manwon >= 10000) {
    final eok = manwon ~/ 10000;
    final rest = manwon % 10000;
    return rest == 0 ? '$eok억원' : '$eok억 ${_comma(rest)}만원';
  }
  return '${_comma(manwon)}만원';
}

String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );

String formatDate(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
String formatDateWithDay(DateTime d) => '${d.month}/${d.day}(${_weekdays[d.weekday - 1]})';
