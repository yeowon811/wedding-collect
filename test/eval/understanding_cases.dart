/// ① 질문 이해 평가용 질문 세트.
///
/// - [expect]에 적은 항목만 채점한다 (적지 않은 항목은 무엇이 나와도 상관없음).
/// - intent 'answer': 되묻는 중의 짧은 답 → 원래 질문을 이어가야 함 (다른 질문으로 넘어가면 오답)
/// - [expecting]: 앱이 방금 되물은 항목, [pending]: 그때 기다리던 원래 질문의 목적
class EvalCase {
  const EvalCase(this.id, this.text, this.expect, {this.expecting, this.pending = 'policy', this.note});

  final String id;
  final String text;
  final Map<String, Object?> expect;
  final String? expecting;
  final String pending;
  final String? note;
}

const evalCases = <EvalCase>[
  // ── 정책 ──
  EvalCase('P01', '20대 청년이 신혼생활에 받을 수 있는 정책이 뭐가있어?',
      {'intent': 'policy', 'topic': 'housing', 'age': 20, 'ageMax': 29}),
  EvalCase('P02', '신혼집 구하는데 도움 받을 수 있는 거 있어?', {'intent': 'policy', 'topic': 'housing'}),
  EvalCase('P03', '스물아홉이고 부산 살아요 받을 수 있는 지원 알려줘',
      {'intent': 'policy', 'sido': '부산', 'age': 29}, note: '한글 숫자 나이'),
  EvalCase('P04', '결혼 축하금 주는 지자체 있나요', {'intent': 'policy', 'topic': 'cash'}),
  EvalCase('P05', '작년에 혼인신고했는데 전세대출 이자 지원 받을 수 있어?',
      {'intent': 'policy', 'topic': 'housing', 'stage': 'married'}),
  EvalCase('P06', '임신 준비 중인데 지원되는 검사 있어?', {'intent': 'policy', 'topic': 'health'}),
  EvalCase('P07', '전남 순천 사는 30대 중반 신혼부부 혜택',
      {'intent': 'policy', 'sido': '전남', 'age': 33, 'ageMax': 36, 'stage': 'married'}),
  EvalCase('P08', '혼인 3년차인데 받을 수 있는 거 있어?',
      {'intent': 'policy', 'stage': 'married', 'marriedYears': 3}),
  EvalCase('P09', '결혼식장 대관료 지원해주는 정책', {'intent': 'policy', 'topic': 'wedding'}),
  EvalCase('P10', '경상남도 거주 예비부부인데 나라에서 돈 주는 거 있음?',
      {'intent': 'policy', 'sido': '경남', 'stage': 'engaged'}),
  EvalCase('P11', '무주택 신혼부부 대출 금리 낮은 상품 알려줘',
      {'intent': 'policy', 'topic': 'housing', 'stage': 'married', 'homeless': true}),
  EvalCase('P12', '서울에서 결혼하면 주는 혜택 뭐 있어', {'intent': 'policy', 'sido': '서울'}),

  // ── 예식장 ──
  EvalCase('V01', '하객 150명 정도 들어가는 경기도 예식장 있어?',
      {'intent': 'venue', 'sido': '경기', 'guests': 150}),
  EvalCase('V02', '무료로 결혼식 할 수 있는 곳 있어? 대구 살아', {'intent': 'venue', 'sido': '대구'}),
  EvalCase('V03', '서울시 공공예식장 신청 어떻게 해', {'intent': 'venue', 'sido': '서울'}),
  EvalCase('V04', '작은 결혼식 하고 싶은데 부산에 저렴한 장소', {'intent': 'venue', 'sido': '부산'}),
  EvalCase('V05', '손님 80명쯤 올 건데 강원도에 식 올릴 데 추천',
      {'intent': 'venue', 'sido': '강원', 'guests': 80}),

  // ── 업체 ──
  EvalCase('D01', '결혼식 사진 찍는 곳 추천해줘', {'intent': 'vendor', 'item': 'studio'}),
  EvalCase('D02', '드레스 투어 비용 얼마 정도야', {'intent': 'vendor', 'item': 'dress'}),
  EvalCase('D03', '엄마 한복 대여 어디서 해', {'intent': 'vendor', 'item': 'hanbok'}),
  EvalCase('D04', '본식 스냅 작가 괜찮은 곳', {'intent': 'vendor', 'item': 'snap'}),
  EvalCase('D05', '신랑 턱시도 빌릴 곳', {'intent': 'vendor', 'item': 'suit'}),
  EvalCase('D06', '부케랑 케이크 업체', {'intent': 'vendor', 'item': 'props'}),
  EvalCase('D07', '식대 1인당 얼마 정도 잡아야 돼? 하객 백명',
      {'intent': 'vendor', 'item': 'meal', 'guests': 100}, note: '한글 숫자 하객'),
  EvalCase('D08', '청첩장 몇 장 찍어야 해? 하객은 200명', {'intent': 'vendor', 'item': 'invitation', 'guests': 200}),
  EvalCase('D09', '결혼식 영상 찍어주는 업체', {'intent': 'vendor', 'item': 'video'}),

  // ── 예산·일정·추천·기타 ──
  EvalCase('B01', '예산 삼천만원으로 어떻게 나눠 써야돼', {'intent': 'budget', 'budget': 3000}, note: '한글 숫자 예산'),
  EvalCase('B02', '예산 5천 정도인데 항목별로 얼마씩 써', {'intent': 'budget', 'budget': 5000}),
  EvalCase('S01', '다음달에 상견례인데 뭐부터 준비해야 돼?', {'intent': 'schedule'}),
  EvalCase('S02', '결혼 6개월 남았는데 지금 할 일', {'intent': 'schedule'}),
  EvalCase('R01', '결혼 준비 전체적으로 추천 좀 해줘', {'intent': 'recommend'}),
  EvalCase('H01', '안녕', {'intent': 'help'}),
  EvalCase('H02', '오늘 날씨 어때', {'intent': 'help'}),
  EvalCase('F01', '난 32살 예비신부고 집은 없어', {'age': 32, 'stage': 'engaged', 'homeless': true},
      note: '정보만 말함'),

  // ── 되묻는 중의 답 ──
  EvalCase('A01', '부산이요', {'intent': 'answer', 'sido': '부산'}, expecting: 'sido'),
  EvalCase('A02', '스물여덟', {'intent': 'answer', 'age': 28}, expecting: 'age'),
  EvalCase('A03', '아직 안 했어요', {'intent': 'answer', 'stage': 'engaged'}, expecting: 'stage'),
  EvalCase('A04', '전세 살고 있어요 집은 없어요', {'intent': 'answer', 'homeless': true}, expecting: 'homeless'),
  EvalCase('A05', '한 120명?', {'intent': 'answer', 'guests': 120}, expecting: 'guests', pending: 'venue'),
  EvalCase('A06', '2천5백만원', {'intent': 'answer', 'budget': 2500}, expecting: 'budget', pending: 'budget'),
  EvalCase('A07', '경기도 성남이에요', {'intent': 'answer', 'sido': '경기'}, expecting: 'sido'),
  EvalCase('A08', '근데 예산은 어떻게 나눠?', {'intent': 'budget'}, expecting: 'sido', note: '되묻는 중 다른 질문'),
];
