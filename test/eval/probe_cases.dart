// 탐색 질문 세트 (2026-11-19): 예상 질문 52개(predicted_cases.dart)에 없는 말투·지역·조건·후속 질문으로
// 틀리거나 이상한 답을 찾기 위한 질문. 예약 현황(달력 스냅샷) 연결 확인 질문 포함.
// 실행: flutter run -d chrome --dart-define-from-file=secrets.json -t test/eval/probe_eval_main.dart
import 'predicted_cases.dart';

const probeCases = <PredictedCase>[
  // ── 지역·인원·요금 조건 ──
  PredictedCase('P01', '지역', 'type', ['경기도 수원 쪽 공공예식장 있어?']),
  PredictedCase('P02', '지역+인원', 'type', ['부산에서 하객 200명 들어가는 예식장']),
  PredictedCase('P03', '정렬', 'type', ['대관료 제일 싼 서울 예식장 3개만 알려줘']),
  PredictedCase('P04', '조건 2개', 'type', ['무료 예식장 중에 하객 150명 되는 곳']),
  PredictedCase('P05', '없는 지역', 'type', ['제주도 공공예식장 알려줘']),
  PredictedCase('P06', '큰 인원', 'type', ['하객 500명 가능한 공공예식장 있어?']),
  // ── 날짜·예약 현황 (새 데이터) ──
  PredictedCase('P07', '날짜(말)', 'type', ['12월 둘째주 토요일에 비어있는 서울 예식장']),
  PredictedCase('P08', '날짜+지역', 'type', ['2027년 5월 15일 경기도에서 예약 가능한 예식장']),
  PredictedCase('P09', '특정 장소 날짜', 'type', ['원덕읍복지회관 웨딩홀 내년 3월에 자리 있어?']),
  PredictedCase('P10', '급한 날짜', 'type', ['다음 달에 결혼하는데 지금 예약 되는 곳 있어?']),
  PredictedCase('P11', '예약 현황', 'type', ['세종 공공예식장 예약 현황 알려줘']),
  // ── 정책 자격 ──
  PredictedCase('P12', '거주지', 'policy', ['경기도 사는데 서울시 결혼 지원 받을 수 있어?']),
  PredictedCase('P13', '나이 경계', 'policy', ['만 34세인데 청년 정책 해당돼?']),
  PredictedCase('P14', '재혼', 'policy', ['재혼인데도 결혼 지원 받을 수 있어?']),
  PredictedCase('P15', '지역 비교', 'policy', ['결혼 장려금 제일 많이 주는 지역은 어디야?']),
  PredictedCase('P16', '주거', 'policy', ['신혼집 구하는데 대출 말고 다른 지원 있어?']),
  // ── 업체·비용 ──
  PredictedCase('P17', '예산 업체', 'type', ['메이크업 50만원 이하로 하는 곳']),
  PredictedCase('P18', '빼면 얼마', 'guide', ['웨딩촬영 안 하면 얼마나 아껴?']),
  PredictedCase('P19', '수량', 'guide', ['하객 150명이면 청첩장 몇 장 뽑아야 해?']),
  PredictedCase('P20', '혼주', 'guide', ['어머니 한복 대여는 보통 얼마야?']),
  PredictedCase('P21', '전체 견적', 'type', ['예식장이랑 스드메 다 합쳐서 견적 내줘']),
  PredictedCase('P22', '예산 잔액', 'type', ['예산 3000인데 식대 6만원에 150명이면 얼마 남아?']),
  // ── 후속 질문 ──
  PredictedCase('P23', '후속: 예약 방법', 'type', ['예식장 추천해줘', '첫 번째 거 예약 어떻게 해?']),
  PredictedCase('P24', '후속: 링크', 'type', ['받을 수 있는 정책 알려줘', '첫 번째 거 신청 링크 줘']),
  PredictedCase('P25', '후속: 조건 추가', 'type', ['인천 공공예식장 알려줘', '그중에 제일 큰 곳은?']),
  PredictedCase('P26', '후속: 날짜', 'type', ['서울 무료 예식장 알려줘', '그중에 내년 4월 토요일 비어 있는 곳']),
  // ── 그 밖 ──
  PredictedCase('P27', '영어', 'type', ['Recommend a public wedding hall in Seoul']),
  PredictedCase('P28', '계산', 'type', ['2027년 4월 10일 결혼이면 며칠 남았어?']),
  PredictedCase('P29', '기관 사업', 'type', ['국립공원 숲 결혼식 신청 방법 알려줘']),
  PredictedCase('P30', '체크리스트', 'guide', ['결혼 준비 체크리스트 만들어줘']),
  // ── 구 단위 (2026-11-19 사용자 화면에서 나온 문제) ──
  PredictedCase('P31', '구 바꾸기', 'type',
      ['예식장 추천해줘', '혹시 강남구 말고 송파구의 결혼식장도 알려줄 수 있어?', '아니 내가 송파구의 결혼식장만을 원했잖아?']),
  PredictedCase('P32', '구 + 후속', 'type', ['송파구의 결혼식장만 보여줘', '그중에 무료만', '서울 전체로 보여줘']),
  // ── 새 구조(도구 고르기) 확인 (2026-11-20) ──
  PredictedCase('P33', '구 여러 개', 'type', ['강남구, 송파구의 예식장만 추천해줘', '그중에 무료만', '제일 큰 곳 순으로']),
  PredictedCase('P34', '시도 여러 개', 'type', ['부산이랑 경남 공공예식장 알려줘']),
  PredictedCase('P35', '대관료 상한', 'type', ['대관료 10만원 이하인 경기 예식장']),
  PredictedCase('P36', '사는 곳 + 찾는 곳', 'type', ['저 수원 사는데 서울 마포구 예식장 보여줘']),
];
