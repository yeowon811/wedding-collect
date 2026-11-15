/// 금액(만원 단위) 표시: 1250 → "1,250만원", 12000 → "1억 2,000만원"
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
