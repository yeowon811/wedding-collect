// 질문별 기대값 (2026-11-20): 자동 채점용. 예상 답 30개(docs/ai-design/answer_design_blaze.md 4장)
// + 예상 질문 52 · 탐색 36 중 정답이 분명한 것. 값은 assets/data 실제 데이터 기준.
import 'predicted_cases.dart';

/// 한 턴의 기대값. 비어 있는 칸은 보지 않는다
class Exp {
  const Exp({
    this.towns,
    this.sidos,
    this.free,
    this.maxFee,
    this.ask,
    this.headline,
    this.notHeadline,
    this.include = const [],
    this.exclude = const [],
    this.minCards,
    this.maxCards,
    this.kind,
    this.chip,
    this.blocks = const [],
    this.text,
    this.notText,
    this.notTowns = const [],
    this.noChip,
    this.filter,
    this.noFilter,
    this.form,
    this.profileHas,
  });

  final List<String>? towns; // 예식장 카드가 모두 이 구 안
  final List<String>? sidos; // 예식장 카드가 모두 이 시도 안
  final bool? free; // 예식장 카드가 모두 무료
  final int? maxFee; // 원
  final bool? ask; // 되묻기여야 함 (true) / 아니어야 함 (false)
  final String? headline; // 제목 정규식
  final String? notHeadline;
  final List<String> include; // 카드·표에 있어야 할 예식장 id
  final List<String> exclude; // 없어야 할 id
  final int? minCards;
  final int? maxCards;
  final String? kind; // AnswerKind 이름
  final String? chip; // 칩 이름 정규식 (하나라도)
  final List<String> blocks; // 있어야 할 블록 종류
  final String? text; // 답 전체 글(블록) 정규식
  final String? notText;
  final List<String> notTowns; // 예식장 카드에 없어야 할 구
  final String? noChip; // 없어야 할 칩 (정규식)
  final String? filter; // 있어야 할 조건 칩 (정규식)
  final String? noFilter; // 없어야 할 조건 칩 (정규식, 예: 총예산이 '3000만원 이하' 칩이 되면 안 됨)
  final bool? form; // 채팅 안 미니 폼이어야 함 (true) / 아니어야 함 (false)
  final String? profileHas; // 이 턴 뒤 내 정보 요약(위쪽 조건 칩)에 있어야 할 것 (정규식)
}

/// 대화 하나: 턴마다 질문(또는 '#칩 이름') + 기대값
class EvalCase {
  const EvalCase(this.id, this.kind, this.turns, this.exps);

  final String id;
  final String kind;
  final List<String> turns; // '#서울 전체' = 앞 답의 칩 누르기, '!start' = 상담 시작
  final List<Exp?> exps;
}

const _seoulGangnam = ['강남구'];

/// 예상 답 30개 (공통 내 정보: 서울 강남구 · 만 29세 · 2027-05-15 · 하객 120명 · 무주택 · 예산 3,000만원)
const designCases = <EvalCase>[
  EvalCase('A1', '시작', ['!start'], [Exp(headline: '무엇부터', chip: '정책|예식장')]),
  EvalCase('B1', '내 구부터', ['공공예식장 추천해줘'],
      [Exp(towns: _seoulGangnam, headline: '강남구', kind: 'venueList', chip: '서울 전체', minCards: 2, maxCards: 3)]),
  EvalCase('B1-2', '넓히기', ['공공예식장 추천해줘', '#서초·송파까지'],
      [null, Exp(towns: ['강남구', '서초구', '송파구'], minCards: 3, headline: '서초|송파|늘')]),
  EvalCase('B2', '구 두 개', ['강남구, 송파구의 예식장만'], [Exp(towns: ['강남구', '송파구'], minCards: 3)]),
  EvalCase('B3', '구 바꾸기', ['강남구 말고 송파구'], [Exp(towns: ['송파구'], minCards: 1, headline: '송파')]),
  EvalCase('B4', '후속 조건', ['강남구 말고 송파구', '그중에 주차 넓은 곳'],
      [Exp(towns: ['송파구']), Exp(towns: ['송파구'], text: '주차')]),
  EvalCase('B5', '시도+무료', ['부산 무료 예식장'], [Exp(sidos: ['부산'], free: true, minCards: 2, include: ['H075'])]),
  EvalCase('B6', '0곳', ['대전 공공예식장 알려줘'], [Exp(headline: '대전', maxCards: 0, chip: '세종')]),
  // 7차: 강남구 첫 카드는 정원 큰 주택도시개발공사(H080), 두 번째가 SETEC(H078)
  EvalCase('B7', '앞 목록', ['공공예식장 추천해줘', '두 번째 거 자세히'], [null, Exp(include: ['H078'], maxCards: 1, headline: 'SETEC')]),
  EvalCase('B8', '역 근처', ['역 가까운 곳으로'], [Exp(ask: true, headline: '역')]),
  EvalCase('B9', '빈 값', ['마루공원 몇 명까지 돼?'], [Exp(include: ['H079'], text: '정보 없음|문의')]),
  EvalCase('C1', '날짜', ['2027년 5월 15일에 강남구 예식장 예약 돼?'],
      [Exp(towns: _seoulGangnam, headline: '5월 15일|5/15', kind: 'venueDate', include: ['H078'])]),
  EvalCase('C2', '기간', ['내년 5월 토요일 비어 있는 날 많은 곳'], [Exp(towns: _seoulGangnam, headline: '5월', minCards: 1)]),
  EvalCase('D1', '한 곳', ['SETEC 컨벤션홀 알려줘'], [Exp(include: ['H078'], headline: 'SETEC', maxCards: 1)]),
  EvalCase('D2', '비교', ['SETEC이랑 서울주택도시개발공사 비교'], [Exp(blocks: ['table'], text: 'SETEC', kind: 'venueCompare')]),
  EvalCase('E1', '정책', ['받을 수 있는 정책 알려줘'], [Exp(kind: 'policyList', headline: '정책', minCards: 2)]),
  EvalCase('E2', '소득 상한', ['부부 합쳐 연봉 8천인데 신혼부부 전세대출 돼?'],
      [Exp(headline: '대상이 아니', text: r'전세자금 대출.*\[소득 초과')]), // 6차: 그 대출 카드가 꼭 있어야 함
  EvalCase('E3', '거주 조건', ['부산 사는데 서울마이웨딩 써도 돼?'], [Exp(text: '거주|서울')]),
  EvalCase('E4', '웹 조사', ['더 아름다운 결혼식 신청 언제까지야?'], [Exp(text: '신청|기간|공고')]),
  EvalCase('F1', '비용', ['스드메 보통 얼마 들어?'], [Exp(kind: 'cost', headline: '만원')]),
  EvalCase('F2', '업체', ['드레스 업체 추천해줘'], [Exp(kind: 'vendorList', minCards: 2, text: '시연')]),
  EvalCase('F3', '계산', ['식대 1인 6만5천원, 150명이면?'], [Exp(headline: '975|9,750,000', maxCards: 0)]),
  EvalCase('G1', '일정', ['뭐부터 해야 해?'], [Exp(kind: 'schedule', blocks: ['steps'])]),
  EvalCase('H1', '일반', ['축의금 답례는 보통 어떻게 해?'], [Exp(maxCards: 0, notText: r'\d{2,}만원')]),
  EvalCase('H2', '범위 밖', ['오늘 날씨 어때?'], [Exp(maxCards: 0)]),
  EvalCase('H3', '개인정보', ['제 번호 010-1234-5678로 업체 연락 받고 싶어요'], [Exp(notText: '1234')]),
  EvalCase('H4', '자기 정보', ['저 수원 살고 하객은 100명 정도예요'], [Exp(text: '수원')]),
];

/// 예상 질문 52 · 탐색 36 중 정답이 분명한 턴의 기대값 (내 정보: 서울 · 만 29세 · 예비부부 · 하객 150명 · 예산 3000만원)
const predictedExps = <String, List<Exp?>>{
  'C04': [Exp(sidos: ['서울'], text: '주차')],
  'D01': [Exp(sidos: ['서울'], headline: '12월 20일|12/20|빈|가능|없어요')],
  'H01': [Exp(include: ['H078'], blocks: ['table'])],
  'H02': [Exp(headline: '975|9,750,000')],
  'H03': [Exp(sidos: ['서울'], notTowns: ['강남구'], minCards: 1)],
  'H05': [Exp(sidos: ['부산'])],
  'I01': [Exp(sidos: ['서울']), Exp(sidos: ['서울'], free: true), Exp(sidos: ['서울'], free: true)],
  'I05': [Exp(sidos: ['서울']), Exp(sidos: ['경기'], minCards: 1)],
  'J04': [Exp(sidos: ['서울'], minCards: 1)],
  'K04': [Exp(notHeadline: '전부 무료|모두 무료라고')],
  'K05': [Exp(notText: '1234')],
  'K06': [Exp(headline: '대전', maxCards: 0)],
};

const probeExps = <String, List<Exp?>>{
  'P01': [Exp(sidos: ['경기'], towns: ['수원시'])],
  'P02': [Exp(sidos: ['부산'], minCards: 1)],
  'P03': [Exp(sidos: ['서울'], minCards: 3, maxCards: 3, noChip: '더 보기')], // "3개만" → 정확히 3장, 더 보기 없음
  'P04': [Exp(free: true, minCards: 1)],
  'P05': [Exp(headline: '제주', maxCards: 0)],
  'P25': [Exp(sidos: ['인천']), Exp(sidos: ['인천'], minCards: 1)],
  'P26': [Exp(sidos: ['서울'], free: true), Exp(sidos: ['서울'], free: true)],
  'P31': [null, Exp(towns: ['송파구']), Exp(towns: ['송파구'])],
  'P32': [Exp(towns: ['송파구']), Exp(towns: ['송파구'], free: true), Exp(sidos: ['서울'], free: true, notHeadline: '^송파')],
  'P33': [Exp(towns: ['강남구', '송파구']), Exp(towns: ['강남구', '송파구'], free: true), Exp(towns: ['강남구', '송파구'], free: true)],
  'P34': [Exp(sidos: ['부산', '경남'], minCards: 2)],
  'P35': [Exp(sidos: ['경기'], maxFee: 100000)],
  'P36': [Exp(towns: ['마포구'], minCards: 1)],
};

/// 추가 규칙 경로 대화 (2026-11-20 오전): 조건 칩·넓히기·0건·장소·정책 소득·더 보기 등 화면 동작 중심.
/// 내 정보는 예상 답과 같음 (서울 강남구 · 하객 120명 …)
const extraCases = <EvalCase>[
  EvalCase('X01', '칩 빼기', ['공공예식장 추천해줘', '~-guests'], [Exp(towns: ['강남구']), Exp(towns: ['강남구'], notText: '하객 120명')]),
  EvalCase('X02', '칩 더하기', ['공공예식장 추천해줘', '#서울 전체', '~+free_only'],
      [null, Exp(sidos: ['서울'], notHeadline: '^강남'), Exp(sidos: ['서울'], free: true, text: '무료만')]),
  EvalCase('X03', '구 빼기', ['공공예식장 추천해줘', '~-sigungu'], [null, Exp(sidos: ['서울'], headline: '^서울')]),
  EvalCase('X04', '정렬 칩', ['서울 예식장 추천해줘', '~+sort'], [null, Exp(sidos: ['서울'], text: '정원 큰 순')]),
  EvalCase('X05', '0건 넓히기', ['제주 공공예식장 알려줘'], [Exp(headline: '제주', maxCards: 0, chip: '곳')]),
  EvalCase('X06', '0건 → 칩', ['대전 공공예식장 알려줘', '#세종'], [null, Exp(sidos: ['세종'], minCards: 1)]),
  EvalCase('X07', '역 이름', ['삼성역 근처 예식장'], [Exp(headline: '삼성역')]),
  EvalCase('X08', '지하철', ['지하철역에서 가까운 공공예식장 알려줘'], [Exp(ask: true)]),
  EvalCase('X09', '소득 초과', ['부부 합쳐 연봉 8천인데 신혼부부 전세대출 돼?'], [Exp(headline: '대상이 아니', text: '7,500만원|소득 초과')]),
  EvalCase('X10', '더 보기', ['서울 예식장 추천해줘', '#71곳 더 보기'], [null, Exp(sidos: ['서울'], headline: '4~6번째')]),
  EvalCase('X11', '다른 구 날짜', ['2027년 5월 15일 송파구 예식장 예약 돼?'], [Exp(towns: ['송파구'], kind: 'venueDate')]),
  EvalCase('X12', '여러 구', ['강남구 송파구 서초구 예식장'], [Exp(towns: ['강남구', '송파구', '서초구'], minCards: 1)]),
  EvalCase('X13', '거주 조건', ['경기도 사는데 서울 공공예식장 써도 돼?'], [Exp(text: '거주|주민|누구나')]),
  EvalCase('X14', '업체 예산', ['메이크업 50만원 이하로 하는 곳'], [Exp(kind: 'vendorList')]),
  EvalCase('X15', '정책 상세', ['더 아름다운 결혼식 알려줘'], [Exp(text: '더 아름다운 결혼식')]),
  EvalCase('X16', '계산', ['3000만원에서 식대 6만원 120명 빼면?'], [Exp(headline: '만원|원')]),
  EvalCase('X17', '며칠', ['2027년 5월 15일까지 며칠 남았어?'], [Exp(headline: '일 남았어요|D-')]),
  EvalCase('X18', '장려금 지역', ['결혼 장려금 제일 많이 주는 지역은 어디야?'], [Exp(headline: '가장 많은 곳', blocks: ['ranking'])]),
  EvalCase('X19', '국립공원', ['국립공원 숲 결혼식 신청 방법 알려줘'], [Exp(headline: '국립공원')]),
  // 5차 (2026-11-20): 여러 턴 구 바꾸기(B2→B3→B4) · 칩으로 넓혔다가 같은 구로 돌아오기(앱 캐시)
  EvalCase('M1', '여러 턴 구 바꾸기', ['강남구, 송파구의 예식장만', '강남구 말고 송파구', '그중에 주차 넓은 곳'], [
    Exp(towns: ['강남구', '송파구'], minCards: 3, headline: '강남'),
    Exp(towns: ['송파구'], minCards: 1, headline: '송파'),
    Exp(towns: ['송파구'], text: '주차'),
  ]),
  EvalCase('M2', '넓혔다 돌아오기', ['공공예식장 추천해줘', '#서울 전체', '~=sigungu:강남구'], [
    Exp(towns: ['강남구'], headline: '강남구'),
    Exp(sidos: ['서울'], headline: '^서울'),
    Exp(towns: ['강남구'], headline: '강남구'),
  ]),
  EvalCase('X20', '반복 질문', ['공공예식장 추천해줘', '공공예식장 추천해줘'], [null, Exp(towns: ['강남구'])]),
  // Red Team Phase 2 (2026-11-20): 총예산은 대관료 상한이 아니다 · 대관료를 직접 말하면 상한
  EvalCase('R1', '총예산≠대관료', ['예산 3000만원으로 서울 웨딩홀 추천해줘'],
      [Exp(sidos: ['서울'], minCards: 1, noFilter: '이하', text: '식대·꽃장식')]),
  EvalCase('R2', '대관료 상한', ['대관료 50만원 이하 서울 예식장'],
      [Exp(sidos: ['서울'], maxFee: 500000, filter: '50만원 이하', minCards: 1)]),
  // Red Team Phase 3 (2026-11-20): 내 정보 없이 정책 질문 → 미니 폼 한 장 → 제출하면 내 정보에 저장하고 바로 답 (Q로 시작하면 내 정보 없이 시작)
  EvalCase('Q1', '미니 폼', ['받을 수 있는 정책 알려줘', '!form sido=서울;age=29;stage=engaged;homeless=true'], [
    Exp(ask: true, form: true),
    Exp(ask: false, form: false, kind: 'policyList', minCards: 1, profileHas: r'서울.*29'),
  ]),
  // 2026-11-21: 앱 데이터 밖 예식장(사설) → 공공예식장 목록·하객 되묻기 없이 범위 안내 + 웹 검색
  EvalCase('S1', '데이터 밖', ['서울시 내 사설 예식장 몇 개 좀 추려줘'],
      [Exp(ask: false, text: '공공예식장 240곳', notText: '74곳')]),
];

List<EvalCase> fromPredicted(List<PredictedCase> cases, Map<String, List<Exp?>> exps) => [
      for (final c in cases) EvalCase(c.id, c.kind, c.turns, exps[c.id] ?? List<Exp?>.filled(c.turns.length, null)),
    ];
