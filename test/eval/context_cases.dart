import 'package:wedding_collect/data/models/policy.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/features/chat/agent/conversation_context.dart';
import 'package:wedding_collect/features/chat/agent/understanding.dart';

/// 대화 흐름 평가: 이전 대화(history) 뒤의 마지막 질문을 제대로 이해하는지.
/// expect 값: 정답 값, 리스트면 그중 하나면 정답, null이면 "값이 없어야 정답"(잘못 이어받기 확인).
class ContextCase {
  const ContextCase(this.id, this.kind, this.history, this.question, this.expect);

  final String id;
  final String kind; // 생략·지시·조건·정정·전환·먼과거·새질문
  final List<Turn> history;
  final String question;
  final Map<String, Object?> expect;
}

// ── 대화에 쓰는 이전 턴들 ──
const _venueSeoul = Turn(
  user: '서울 공공예식장 추천해줘',
  bot: '서울 공공예식장 74곳 중에서 골랐어요. 하객 150명을 수용할 수 있는 곳 29곳, 무료 대관 59곳이에요.',
  intent: ConsultIntent.venue,
  sido: '서울',
  results: ['서울주택도시개발공사 대강당홀', '강동아트센터 잔디마당', '한강공원 광나루 장미원'],
);
const _venueBusan = Turn(
  user: '부산 공공예식장 알려줘',
  bot: '부산 공공예식장 12곳 중에서 골랐어요. 무료 대관 3곳이에요.',
  intent: ConsultIntent.venue,
  sido: '부산',
  results: ['고리원자력전시관 웨딩홀', '다대포 다대선셋가든', '금정구청 대강당'],
);
const _policyHousing = Turn(
  user: '서울 신혼집 지원 정책 알려줘',
  bot: '받을 수 있는 주거·대출 정책을 16건 찾았어요. 그중 2건은 조건이 잘 맞아요.',
  intent: ConsultIntent.policy,
  topic: PolicyCategory.housing,
  sido: '서울',
  results: ['신혼부부 임차보증금 이자지원', '신혼희망타운 주택담보대출', '청년 전세자금 대출'],
);
const _policyCash = Turn(
  user: '결혼 장려금 받을 수 있어?',
  bot: '예비부부 기준으로 받을 수 있는 결혼 장려금 정책 3건을 찾았어요.',
  intent: ConsultIntent.policy,
  topic: PolicyCategory.cash,
  results: ['경기청년 결혼지원사업', '여주시 결혼장려금', '화성시 결혼 매칭통장'],
);
const _dressSeoul = Turn(
  user: '서울 드레스 추천해줘',
  bot: '드레스 추천 예산은 360만원이에요. 서울 드레스 업체 3곳 중 예산 안은 3곳이에요.',
  intent: ConsultIntent.vendor,
  item: VendorCategory.dress,
  sido: '서울',
  results: ['다온 서울점', '베일리 서울점', '온유 서울점'],
);
const _makeupGyeonggi = Turn(
  user: '경기 메이크업 업체 추천해줘',
  bot: '메이크업 추천 예산은 120만원이에요. 경기 메이크업 업체 3곳 중 예산 안은 3곳이에요.',
  intent: ConsultIntent.vendor,
  item: VendorCategory.makeup,
  sido: '경기',
  results: ['라온 뷰티 경기점', '윤슬 메이크업 경기점', '브라이드룸 경기점'],
);
const _budget = Turn(
  user: '예산 3천만원 어떻게 나눠?',
  bot: '추천 배분이에요. 식대 1050만원, 드레스 360만원, 웨딩촬영 300만원 …',
  intent: ConsultIntent.budget,
);
const _schedule = Turn(
  user: '뭐부터 해야 해?',
  bot: '지금 먼저 할 일이에요. 예식 날짜·지역·총예산 정하기, 공공예식장 둘러보기.',
  intent: ConsultIntent.schedule,
  results: ['예식 날짜·지역·총예산 정하기', '공공예식장 둘러보고 신청 기간 확인하기'],
);

const contextCases = <ContextCase>[
  // ── 생략: 이전 목적을 이어받아야 함 ──
  ContextCase('E1', '생략', [_venueSeoul], '그럼 부산은?', {'intent': 'venue', 'sido': '부산'}),
  ContextCase('E2', '생략', [_policyHousing], '경기는?', {'intent': 'policy', 'sido': '경기', 'topic': 'housing'}),
  ContextCase('E3', '생략', [_dressSeoul], '메이크업은?', {'intent': 'vendor', 'item': 'makeup'}),
  ContextCase('E4', '생략', [_dressSeoul], '부산에서는?', {'intent': 'vendor', 'item': 'dress', 'sido': '부산'}),
  ContextCase('E5', '생략', [_venueSeoul], '200명이면?', {'intent': 'venue', 'guests': 200}),
  ContextCase('E6', '생략', [_policyCash], '신혼부부는?', {'intent': 'policy', 'topic': 'cash', 'stage': 'married'}),
  ContextCase('E7', '생략', [_budget], '5천이면?', {'intent': 'budget', 'budget': 5000}),
  // ── 지시: 이전 목록의 몇 번째 ──
  ContextCase('R1', '지시', [_venueSeoul], '두 번째 거 자세히 알려줘', {'intent': 'venue', 'refIndex': 2}),
  ContextCase('R2', '지시', [_policyHousing], '첫 번째 정책 신청은 어떻게 해?', {'intent': 'policy', 'refIndex': 1}),
  ContextCase('R3', '지시', [_dressSeoul], '마지막 업체 후기 어때?', {'intent': 'vendor', 'refIndex': 3}),
  ContextCase('R4', '지시', [_venueSeoul], '거기 주차는 돼?', {'intent': 'venue', 'refIndex': 1}),
  ContextCase('R5', '지시', [_policyCash], '그거 나도 받을 수 있어?', {'intent': 'policy', 'refIndex': 1}),
  ContextCase('R6', '지시', [_venueSeoul], '2번이랑 3번 중에 어디가 더 커?', {'intent': 'venue', 'refIndex': [2, 3]}),
  // ── 조건 추가: 이전 결과 거르기 ──
  ContextCase('F1', '조건', [_venueSeoul], '그중에 무료인 곳만', {'intent': 'venue', 'filter': 'free'}),
  ContextCase('F2', '조건', [_venueSeoul], '하객 다 들어가는 데만 보여줘', {'intent': 'venue', 'filter': 'fits_guests'}),
  ContextCase('F3', '조건', [_dressSeoul], '더 싼 데는 없어?', {'intent': 'vendor', 'item': 'dress', 'filter': 'cheaper'}),
  ContextCase('F4', '조건', [_venueBusan], '사진 있는 곳만 보여줘', {'intent': 'venue', 'filter': 'has_photo'}),
  // ── 정정 ──
  ContextCase('C1', '정정', [_venueSeoul], '아 서울 말고 경기야', {'intent': 'venue', 'sido': '경기'}),
  ContextCase('C2', '정정', [_policyCash], '아 저희 혼인신고 했어요', {'intent': ['policy', 'answer'], 'stage': 'married'}),
  ContextCase('C3', '정정', [_dressSeoul], '드레스 말고 스냅이요', {'intent': 'vendor', 'item': 'snap'}),
  // ── 주제 전환: 이전 대화를 이어받으면 안 됨 ──
  ContextCase('T1', '전환', [_venueSeoul], '예산은 어떻게 나눠?', {'intent': 'budget', 'refIndex': null, 'filter': null}),
  ContextCase('T2', '전환', [_policyHousing], '드레스 추천해줘', {'intent': 'vendor', 'item': 'dress', 'topic': null}),
  ContextCase('T3', '전환', [_dressSeoul], '받을 수 있는 정책 알려줘', {'intent': 'policy', 'item': null}),
  ContextCase('T4', '전환', [_venueSeoul], '뭐부터 준비해야 돼?', {'intent': 'schedule', 'refIndex': null}),
  ContextCase('T5', '전환', [_policyHousing], '결혼 장려금도 있어?', {'intent': 'policy', 'topic': 'cash'}),
  ContextCase('T6', '전환', [_dressSeoul], '고마워!', {'intent': 'help', 'refIndex': null}),
  // ── 먼 과거: 몇 턴 전의 목록·값을 가리킴 ──
  ContextCase('L1', '먼과거', [_venueSeoul, _policyHousing, _budget], '아까 그 예식장 두 번째 곳 다시 보여줘',
      {'intent': 'venue', 'refIndex': 2}),
  ContextCase('L2', '먼과거', [_venueBusan, _dressSeoul, _schedule], '처음에 말한 지역 공공예식장 중 무료인 곳',
      {'intent': 'venue', 'sido': '부산', 'filter': 'free'}),
  ContextCase('L3', '먼과거', [_policyHousing, _venueSeoul], '아까 정책 첫 번째 거 신청 방법 알려줘',
      {'intent': 'policy', 'refIndex': 1}),
  ContextCase('L4', '먼과거', [_makeupGyeonggi, _budget, _policyCash], '그 메이크업 업체들 중에 제일 싼 곳은?',
      {'intent': 'vendor', 'item': 'makeup', 'filter': 'cheaper'}),
  // ── 긴 대화 뒤의 새 질문: 혼동하지 않아야 함 ──
  ContextCase('N1', '새질문', [_venueSeoul, _policyHousing, _dressSeoul, _budget, _schedule], '공공예식장 추천해줘',
      {'intent': 'venue', 'refIndex': null, 'filter': null}),
  ContextCase('N2', '새질문', [_venueSeoul, _policyCash, _dressSeoul, _budget, _schedule], '하객 100명인데 인천 예식장 있어?',
      {'intent': 'venue', 'sido': '인천', 'guests': 100, 'refIndex': null}),
];
