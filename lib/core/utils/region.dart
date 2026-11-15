/// 시도 목록과 지역 비교 도우미
const kSidoList = [
  '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종', '경기',
  '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
];

/// 2026 행정구역 기준 데이터에는 '광주·전남'이 묶여 있어, 광주·전남 선택 시 함께 맞춘다.
bool sidoMatches(String dataSido, String? selected) {
  if (selected == null) return true;
  if (dataSido == selected) return true;
  if (dataSido == '광주·전남') return selected == '광주' || selected == '전남';
  if (selected == '광주·전남') return dataSido == '광주' || dataSido == '전남';
  return false;
}
