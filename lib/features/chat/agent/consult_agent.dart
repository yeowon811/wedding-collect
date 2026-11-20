import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/region.dart';
import '../../../data/app_state.dart';
import '../../../data/models/booking_status.dart';
import '../../../data/models/policy.dart';
import '../../../data/models/wedding_option.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/venue.dart';
import '../../../data/models/wedding_plan.dart';
import '../../../data/repositories/repositories.dart';
import '../../policy/policy_detail_screen.dart';
import '../../policy/policy_matcher.dart';
import '../../vendor/demo_vendor_detail_screen.dart';
import '../../vendor/vendor_screen.dart';
import '../../vendor/real_vendor_detail_screen.dart';
import '../../venue/venue_detail_screen.dart';
import '../chat_agent.dart';
import '../../../app/main_shell.dart';
import 'consult_tools.dart';
import 'conversation_context.dart';
import 'calc.dart';
import 'date_check.dart';
import 'policy_text.dart';
import 'tool_planner.dart';
import 'venue_features.dart';
import 'gemini_client.dart';
import 'understanding.dart';
import '../answer/answer_ai.dart';
import '../answer/answer_blocks.dart';
import '../answer/answer_checks.dart';
import '../answer/answer_composer.dart';
import '../answer/answer_facts.dart';
import '../answer/venue_cost.dart';
import '../answer/venue_scope.dart';

part 'consult_present.dart';

/// 상담 에이전트 (대화 관리자)
///
/// ① 질문 이해 ([Understander]) → ② 내 정보·대화 기억과 합치기 → ③ 답에 꼭 필요한 정보가
/// 빠졌으면 하나씩 되묻기 → ④ 도구([ConsultTools])로 데이터 조회 → ⑤ 근거·출처와 함께 답변
class ConsultAgent implements ChatAgent {
  ConsultAgent({Understander? understander, GeminiClient? llm})
      : _nlu = understander ?? RuleUnderstander(),
        _llm = llm;

  final Understander _nlu;
  final GeminiClient? _llm; // null이면 규칙 기반으로만 동작

  @override
  String get name => _llm != null ? 'Gemini AI 상담' : '앱 데이터 상담 (규칙 기반)';

  String _question = ''; // 지금 답하고 있는 원래 질문 (⑤ 답변 문장에 사용)

  @override
  final step = ValueNotifier<AgentStep?>(null);

  // "왜 이렇게 답했나요?"에 쓰는 기록
  String _nluNote = ''; // 질문을 누가(규칙/Gemini) 이해했는지
  String _lookupNote = ''; // 어떤 데이터를 어떻게 골랐는지
  List<String> _funnel = const []; // '어떻게 찾았나요' 걸러진 과정 (사용자 말 + 앱이 센 건수, Red Team P1-3)
  String _flowNote = ''; // 대화 흐름을 어떻게 썼는지 (이전 목록의 몇 번째, 조건 등)

  /// 최근 대화 기억: 턴마다 목적·조건·보여준 목록. 질문 이해 때 최근 3턴 요약을 함께 보낸다
  /// (평가: 요약 3턴 + 규칙 보완이 32/32로 가장 좋음, docs/ai-eval/README.md)
  final List<Turn> _turns = [];
  final List<List<ChatCard>> _turnCards = []; // 각 턴에 보여준 결과 카드 ("두 번째 거" 찾기용)
  static const _memoryTurns = 3;

  void _remember(Turn t, List<ChatCard> cards) {
    _turns.add(t);
    _turnCards.add(cards);
    while (_turns.length > 6) {
      _turns.removeAt(0);
      _turnCards.removeAt(0);
    }
  }

  @override
  void restore(List<ChatMessage> messages) {
    _turns.clear();
    _turnCards.clear();
    var lastUser = '';
    for (final m in messages) {
      if (m.fromUser) {
        lastUser = m.text;
        continue;
      }
      if (m.isQuestion) continue;
      final kind = m.cards.isEmpty ? null : m.cards.first.ref?.split(':').first;
      _remember(
        Turn(
          user: lastUser,
          bot: m.text,
          intent: switch (kind) {
            'venue' => ConsultIntent.venue,
            'policy' => ConsultIntent.policy,
            'vendor' => ConsultIntent.vendor,
            _ => ConsultIntent.help,
          },
          results: [for (final c in m.cards) c.title],
        ),
        m.cards,
      );
    }
  }

  static const _intentLabel = {
    ConsultIntent.recommend: '전체 추천',
    ConsultIntent.policy: '지원 정책',
    ConsultIntent.venue: '공공예식장',
    ConsultIntent.vendor: '업체 추천',
    ConsultIntent.budget: '예산 현황',
    ConsultIntent.schedule: '준비 순서',
    ConsultIntent.help: '일반 질문',
  };

  static const _slotLabel = {
    Slot.sido: '지역',
    Slot.sigungu: '시·군·구',
    Slot.age: '나이',
    Slot.stage: '결혼 단계',
    Slot.marriedYears: '혼인 연차',
    Slot.guests: '하객 수',
    Slot.budget: '총예산',
    Slot.item: '항목',
    Slot.homeless: '무주택 여부',
    Slot.weddingDate: '예식일',
  };

  AppState get _app => AppState.instance;

  /// 이번 대화에서 알고 있는 정보 = 저장된 내 정보 + 대화 중 새로 들은 정보
  // 저장된 내 정보가 항상 출발점 (처음 입력 폼을 건너뛰었어도 체크리스트·공유 링크·지난 대화로 들어온 값은 쓴다, 2026-11-21)
  late UserProfile _known = _app.profile;
  late UserProfile _seenApp = _app.profile; // 마지막으로 본 앱의 내 정보

  // ───── 새 답 화면 (블록, 2026-11-20) ─────
  /// false면 예전 글 답 (비교·되돌리기용)
  static bool useBlocks = true;
  late final AnswerComposer _composer = AnswerComposer(_llm);
  AnswerHint? _hint; // 이번 답의 기본 틀 힌트 (답 함수가 채움)
  int? _hintBudget; // 업체 답: 이번 질문의 항목 예산 (만원)
  QueryScope? _lastScope; // 마지막 예식장 검색에 실제로 적용된 조건
  Map<String, Object?>? _lastVenueArgs; // 같은 조건 (search_venues 형식, 조건 칩·넓히기용)
  String? _appliedNote; // '내 정보에 반영했어요: …'
  Understanding? _lastU; // 이번 답의 질문 이해
  PrevAnswer? _prevAnswer; // 직전 답 (K3 반복 검사)
  String _contextBefore = ''; // 이번 질문 전 2턴 (검토용)
  bool _followUpTurn = false; // 앞 답을 고치는 후속 질문·조건 칩 (Gemini 검토 대상)
  int? _cardLimit; // "3개만"처럼 사용자가 정한 카드 수

  /// 질문 속 카드 수 ("3개만", "두 곳만 알려줘", "5곳 추천") → 1~5, 없으면 null. "3개월"·"2곳 비교"는 아님
  static int? cardLimitOf(String q) {
    final m = RegExp(r'(?<!\d)(\d|한|두|세|네|다섯)\s*(개|곳|군데|건)(?!월)\s*(만|추천|알려|보여|골라)').firstMatch(q);
    if (m == null) return null;
    final n = int.tryParse(m[1]!) ?? const {'한': 1, '두': 2, '세': 3, '네': 4, '다섯': 5}[m[1]];
    return n != null && n >= 1 && n <= 5 ? n : null;
  }
  String? _templateOnly; // 이유가 있으면 Gemini 작성 없이 기본 틀 (더 보기·인사·앱 동작 안내)

  /// 평가·화면용: 마지막 답을 어떻게 만들었는지
  Composed? lastComposed;
  int lastComposeMs = 0;
  AnswerFacts? lastFacts;
  ReviewVerdict? get lastVerdict => _composer.lastVerdict;
  UserProfile _selfFacts = const UserProfile(); // 이번 턴에 사용자가 '자기 이야기'로 말한 값 → 내 정보에 자동 반영
  ({UserProfile profile, WeddingPlan plan})? _undo; // [되돌리기]용 반영 전 값

  /// 이번 질문에서 방금 지역(시도)을 되물어 답을 받았는지 → 그때만 이어서 시·군·구를 묻는다
  bool _sidoJustAsked = false;

  /// 이번 질문의 날짜 조건과, 앱 데이터로 확인할 수 없는 조건 (Gemini가 판단)
  DateTime? _askDate;
  AgentPlan? _plan; // 새 구조: Gemini가 고른 도구와 조건 (null이면 예전 규칙 경로)
  VenueQuery? _vq; // 예식장 검색 조건 (도구 경로)
  bool _forceByAmount = false; // 정책: 금액 많은 순 (도구 경로)
  bool _noLlmUnderstand = false; // 이번 질문은 규칙으로만 이해
  final List<({String q, String tool, Map<String, Object?> args})> _planLog = []; // 이전 도구 조건 (후속 질문용)
  ({List<DateTime> dates, String label})? _period; // 기간 질문의 날짜들 ("내년 3월")
  List<String> _unsupported = const [];

  /// 더 보기: 마지막 추천의 전체 결과(카드)와 지금까지 보여준 개수
  List<ChatCard> _moreCards = const [];
  int _moreShown = 0;
  String _moreLabel = ''; // 예: '서울 공공예식장'
  String _moreUnit = '곳';
  int _moreTab = 0; // 전체 보기로 열 탭 (0 예식장 · 1 정책 · 2 업체)
  VendorCategory? _moreCategory;
  static const _page = 3;

  /// 추천 답변이 전체 결과를 기억해 두고, 남은 게 있으면 [더 보기] 버튼을 준다
  List<QuickReply> _startMore(List<ChatCard> all, String label,
      {String unit = '곳', int tab = 0, VendorCategory? category}) {
    _moreCards = all;
    _moreShown = all.length < _page ? all.length : _page;
    _moreLabel = label;
    _moreUnit = unit;
    _moreTab = tab;
    _moreCategory = category;
    return _moreReplies();
  }

  List<QuickReply> _moreReplies() {
    final left = _moreCards.length - _moreShown;
    return [if (left > 0) QuickReply('더 보기 ($left$_moreUnit 남음)', action: 'more')];
  }

  bool _isMoreRequest(String t) =>
      _moreCards.length > _moreShown &&
      ['더 보여', '더보여', '더 보기', '더보기', '더 있어', '다른 곳', '다른 데', '더 알려'].any(t.contains);

  /// [더 보기]: 다음 3개
  ChatMessage _moreAnswer() {
    final start = _moreShown;
    final next = _moreCards.skip(start).take(_page).toList();
    _moreShown += next.length;
    final left = _moreCards.length - _moreShown;
    final tabName = switch (_moreTab) { 1 => '정책', 2 => '업체', _ => '예식장' };
    _lookupNote = '앞서 찾은 $_moreLabel ${_moreCards.length}$_moreUnit 중 ${start + 1}~$_moreShown번째';
    _templateOnly = '더 보기: 앞 결과의 다음 장 (Gemini 호출 없음)';
    final kindRef = next.firstOrNull?.ref?.split(':').first;
    _hint = AnswerHint(
      kind: switch (kindRef) { 'policy' => AnswerKind.policyList, 'vendor' || 'real' => AnswerKind.vendorList, _ => AnswerKind.venueList },
      headline: '$_moreLabel ${start + 1}~$_moreShown번째',
      sentence: left > 0 ? null : '여기까지가 전부예요.',
    );
    final m = ChatMessage(
      fromUser: false,
      basis: '$_moreLabel ${_moreCards.length}$_moreUnit 중 ${start + 1}~$_moreShown번째',
      text: '$_moreLabel ${start + 1}~$_moreShown번째예요.\n\n'
          '${next.map((c) => '• ${c.title.replaceFirst('[시연] ', '')}\n   ${c.subtitle}').join('\n')}'
          '${left > 0 ? '' : '\n\n여기까지가 전부예요. $tabName 탭에서 지역·항목별로 더 자세히 볼 수 있어요.'}',
      cards: next,
      quickReplies: [
        ..._moreReplies(),
        QuickReply('$tabName 탭에서 전체 보기', action: 'open_tab'),
      ],
    );
    _remember(Turn(user: '더 보기', bot: m.text, intent: _turns.lastOrNull?.intent ?? ConsultIntent.help,
        results: [for (final c in next) c.title]), next);
    return m;
  }

  /// 사용자가 자기 이야기로 말한 값을 모은다 (지역은 [region]일 때만)
  void _noteSelf(UserProfile f, {bool region = false}) {
    _selfFacts = _selfFacts.merge(UserProfile(
      sido: region ? f.sido : null,
      sigungu: region ? f.sigungu : null,
      age: f.age,
      ageMax: f.age != null ? f.ageMax : null,
      stage: f.stageInput,
      marriedYears: f.marriedYearsInput,
      weddingDate: f.weddingDate,
      weddingUndecided: f.weddingUndecided,
      guests: f.guests,
      budget: f.budget,
      homeless: f.homeless,
      firstMarriage: f.firstMarriage,
      income: f.income,
    ));
  }

  /// "강남구 살아요", "경기도 사는데 …" → 사는 곳 (사는다는 말 앞의 지역)
  UserProfile? get _livingRegion {
    final q = _question;
    final live = RegExp(r'살아요|살아|사는데|살고|사는\s*곳|거주|이사\s*왔').firstMatch(q);
    if (live == null) return null;
    final before = q.substring(0, live.start);
    final hits = [
      for (final sd in kSidoList)
        if (before.lastIndexOf(sd) >= 0) (sd, before.lastIndexOf(sd)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final sido = hits.lastOrNull?.$1;
    final town = findSigungu(before, sido: sido) ?? (sido == null ? findSigungu(before) : null);
    if (town != null) return UserProfile(sido: town.$1, sigungu: town.$2);
    return sido == null ? null : UserProfile(sido: sido);
  }

  /// 이번 턴의 자기 정보를 내 정보(= 체크리스트 결혼 정보)에 반영하고, 답변 끝에 무엇을 바꿨는지 알린다
  ChatMessage _applySelfFacts(ChatMessage m) {
    final f = _selfFacts;
    _selfFacts = const UserProfile();
    final before = _app.profile;
    final after = before.merge(f);
    final changed = [
      if (after.regionLabel != before.regionLabel && after.regionLabel != null) after.regionLabel!,
      if (after.age != before.age || after.ageMax != before.ageMax) after.ageLabel,
      if (after.stageInput != before.stageInput && after.stageInput != null) after.stageInput!.label,
      if (after.weddingDate != before.weddingDate && after.weddingDate != null) '예식일 ${formatDate(after.weddingDate!)}',
      if (after.guests != before.guests) '하객 ${after.guests}명',
      if (after.budget != before.budget) '예산 ${formatManwon(after.budget!)}',
      if (after.homeless != before.homeless && after.homeless != null) after.homeless! ? '무주택' : '집 있음',
      if (after.firstMarriage != before.firstMarriage && after.firstMarriage != null) after.firstMarriage!.label,
    ];
    if (changed.isEmpty) return m;
    _undo = (profile: before, plan: _app.plan);
    _app.updateProfileDraft(after);
    _seenApp = _app.profile;
    _appliedNote = '내 정보에 반영했어요: ${changed.join(' · ')}';
    return m.copyWith(
      text: '${m.text}\n\n내 정보에 반영했어요: ${changed.join(' · ')}',
      quickReplies: [
        ...m.quickReplies.where((r) => r.action != 'save_profile'),
        const QuickReply('되돌리기', action: 'undo_profile'),
      ],
    );
  }

  ChatMessage _undoSelfFacts() {
    final u = _undo;
    if (u == null) return const ChatMessage(fromUser: false, text: '되돌릴 변경이 없어요.');
    _undo = null;
    _app.updatePlan(u.plan);
    _app.updateProfileDraft(u.profile);
    _app.plan = u.plan; // 처음 입력한 값(빈칸)도 그대로 되돌린다
    _seenApp = _app.profile;
    return const ChatMessage(
      fromUser: false,
      text: '내 정보를 바꾸기 전으로 되돌렸어요. 이번 대화에서는 말씀하신 조건으로 계속 찾아 드릴게요.',
    );
  }

  /// 체크리스트·내 정보 화면에서 바뀐 결혼 정보만 대화 기억에 반영 (대화에서 말한 값은 덮지 않음)
  void _syncFromApp() {
    final cur = _app.profile;
    // 위쪽 조건 칩 ✕로 지운 값 (앱에 있던 값이 없어짐) → 대화 기억에서도 지운다
    _known = _known.copyWith(
      clearSido: _seenApp.sido != null && cur.sido == null,
      clearAge: _seenApp.age != null && cur.age == null,
      clearWeddingDate: _seenApp.weddingDate != null && cur.weddingDate == null,
      clearGuests: _seenApp.guests != null && cur.guests == null,
      clearBudget: _seenApp.budget != null && cur.budget == null,
      clearHomeless: _seenApp.homeless != null && cur.homeless == null,
    );
    _known = _known.merge(UserProfile(
      sido: cur.sido != _seenApp.sido ? cur.sido : null,
      sigungu: cur.sigungu != _seenApp.sigungu ? cur.sigungu : null,
      guests: cur.guests != _seenApp.guests ? cur.guests : null,
      budget: cur.budget != _seenApp.budget ? cur.budget : null,
      weddingDate: cur.weddingDate != _seenApp.weddingDate ? cur.weddingDate : null,
    ));
    _seenApp = cur;
  }

  Understanding? _pending; // 정보를 되묻는 동안 기다리는 원래 질문
  Slot? _asking; // 지금 되묻고 있는 항목
  final Set<Slot> _skipped = {}; // "잘 모르겠어요"로 건너뛴 항목

  UserProfile get known => _known; // 테스트·화면 표시용
  Slot? get asking => _asking;

  // ───────────────────────── 입력 처리 ─────────────────────────

  @override
  Future<ChatMessage> start() async {
    _known = _app.profile;
    _seenApp = _app.profile;
    // 아는 정보가 하나도 없을 때만 일반 인사, 하나라도 있으면 그 정보에 맞춘 질문 추천
    if (_known.summary.isEmpty) {
      return ChatMessage(
        fromUser: false,
        text: '안녕하세요! 결혼 준비를 도와드릴게요.\n'
            '궁금한 걸 편하게 물어보세요. 답하는 데 필요한 정보가 없으면 제가 하나씩 여쭤볼게요.',
        quickReplies: _starterReplies,
      );
    }
    // 처음부터 추천을 쏟아내지 않는다: 무엇이 궁금한지 먼저 고르게 하고, 답은 내 정보로 맞춘다 (2026-11-20)
    final summary = _known.summary;
    _templateOnly = '시작 인사';
    _hint = AnswerHint(
      kind: AnswerKind.other,
      headline: '무엇부터 알아볼까요?',
      sentence: summary.isEmpty ? null : '입력하신 내 정보로 맞춰 답해 드릴게요.',
    );
    return _present(ChatMessage(
      fromUser: false,
      text: '안녕하세요! 결혼 준비를 도와드릴게요.\n'
          '${summary.isEmpty ? '' : '입력해 주신 정보($summary)에 맞춰 답해 드릴게요.\n'}'
          '무엇부터 알아볼까요? 아래에서 고르거나 편하게 물어보세요.',
      quickReplies: _profileStarters(_known),
    ));
  }

  /// 내 정보에 맞춘 첫 질문 추천 (값이 있으면 질문에 넣는다)
  static List<QuickReply> _profileStarters(UserProfile k) {
    final region = k.sigungu ?? k.sido;
    final w = k.weddingDate;
    return [
      const QuickReply('받을 수 있는 정책', text: '받을 수 있는 정책 알려줘'),
      QuickReply(region == null ? '공공예식장 추천' : '$region 공공예식장',
          text: region == null ? '공공예식장 추천해줘' : '$region 공공예식장 추천해줘'),
      if (w != null && !k.weddingPassed)
        QuickReply('${w.month}/${w.day} 비어 있는 곳', text: '${w.year}년 ${w.month}월 ${w.day}일에 예약 가능한 예식장 있어?'),
      const QuickReply('예산 나누기', text: '예산 어떻게 나누면 돼?'),
      const QuickReply('뭐부터 해야 해?', text: '뭐부터 해야 해?'),
    ];
  }

  @override
  Future<ChatMessage> reply(String question) async {
    _selfFacts = const UserProfile();
    _resetTurn();
    _cardLimit = cardLimitOf(question);
    return _present(_applySelfFacts(await _reply(question)));
  }

  void _resetTurn() {
    _hint = null;
    _hintBudget = null;
    _followUpTurn = false;
    _templateOnly = null;
    _cardLimit = null;
    _lastU = null;
    _appliedNote = null;
    _contextBefore = _contextNow;
  }

  Future<ChatMessage> _reply(String question) async {
    _syncFromApp();
    // 예약 현황 (예식장 정보 답변에서 바로 쓰도록 미리 읽어 둠). 못 읽어도 원문 판단으로 답한다
    try {
      await Repos.booking.loadAll();
    } catch (_) {}
    final text = question.trim();
    if (_asking != null && _pending != null) {
      if (_isDontKnow(text)) return _skipCurrent();
      step.value = AgentStep.understand;
      final (:u, :isAnswer) = await _understand(text, expecting: _asking);
      if (!isAnswer && u.intent != ConsultIntent.help && u.intent != _pending!.intent) {
        // 되묻는 중에 다른 질문을 하면 새 질문으로 처리한다
        _clearPending();
        _question = text;
        return _process(u);
      }
      _known = _known.merge(u.facts);
      // 되묻기에 대한 답은 자기 정보 (지역은 '어디 사세요?'에 답했을 때만)
      _noteSelf(u.facts, region: _asking == Slot.sido || _asking == Slot.sigungu);
      if (_asking == Slot.sido) _sidoJustAsked = true;
      if (_asking == Slot.item && u.item != null) _pending = _pending!.withItem(u.item!);
      if (!_isFilled(_asking!, _pending!)) {
        return _ask(_asking!, _pending!, retry: true);
      }
      return _process(_pending!, plan: _plan);
    }
    if (_isMoreRequest(text)) return _moreAnswer();
    _question = text;
    _sidoJustAsked = false;
    step.value = AgentStep.understand;
    if (_llm != null) {
      // 도구 고르기 1번만 부른다. 실패·시간 초과일 때만 예전 질문 이해(Gemini 1번, 그래도 안 되면 규칙)로 (2026-11-20:
      // 예전에는 질문 이해를 미리 함께 불러 질문마다 Gemini 호출이 1번 더 들었음)
      final planned = await _planned(text);
      if (planned != null) return planned;
    }
    _plan = null;
    _vq = null;
    _forceByAmount = false;
    return _process((await _understand(text)).u);
  }

  // ───────────────────────── 새 구조: 도구 고르기 ─────────────────────────

  /// Gemini에 주는 맥락: 내 정보 + 최근 질문들의 도구·조건 + 바로 앞 답변 목록
  String _planContext() {
    final lines = <String>[
      if (_known.summary.isNotEmpty) '내 정보: ${_known.summary}',
      if (_planLog.isNotEmpty) '이전 도구 조건 (오래된 것부터):',
      for (final e in _planLog.skip(_planLog.length > 3 ? _planLog.length - 3 : 0))
        '- 질문 "${e.q}" → ${e.tool} ${jsonEncode(e.args)}',
    ];
    final last = _turnCards.lastWhere((c) => c.isNotEmpty, orElse: () => const []);
    if (last.isNotEmpty) {
      lines.add('바로 앞 답변 목록: ${[for (final (i, c) in last.indexed) '${i + 1}. ${c.title}'].join(' / ')}');
    }
    return lines.join('\n');
  }

  /// 질문 → 도구 하나 → 답. Gemini가 실패하면 null (예전 경로로)
  Future<ChatMessage?> _planned(String text) async {
    final sw = Stopwatch()..start();
    var p = await _llm!.plan(text, context: _planContext(), timeout: const Duration(seconds: 20));
    sw.stop();
    if (p == null) return null;
    final picked = '${p.tool} ${jsonEncode(p.args)}';
    // 앱 가드: 예식장을 물었는데 전체 추천·정책 검색을 고른 경우 등 (확실할 때만)
    final g = ToolPlanner.guard(p, text);
    p = g.plan;
    // 총예산 ≠ 대관료: "예산 3000만원으로 …"을 대관료 상한으로 쓰지 않는다 (Red Team P1-1)
    final fg = ToolPlanner.feeGuard(p, text);
    p = fg.plan;
    // 후속 질문이면 앞 예식장 조건과 앱이 합친다
    final prevVenue = _planLog.lastOrNull;
    String? referNote;
    if (prevVenue?.tool == 'search_venues') {
      final r = ToolPlanner.referToRefine(p, text);
      if (r != null) {
        p = r;
        referNote = '앞 목록 가리키기(번호 없음) → 앞 예식장 검색을 고치는 후속 질문으로 바꿈';
      }
    }
    if (RegExp(r'^(그중|그럼|거기서|그거|아니|말고)').hasMatch(text.trim())) _followUpTurn = true;
    if (p.tool == 'search_venues' && p.args['refine_previous'] == true && prevVenue?.tool == 'search_venues') {
      p = ToolPlanner.refine(p, prevVenue!.args);
      _followUpTurn = true;
    }
    return _runPlan(p, text,
        note: 'Gemini가 도구를 고름: $picked (조건은 앱이 검사, ${sw.elapsedMilliseconds}ms)'
            '${g.note == null ? '' : ' → 앱 가드: ${g.note} → ${p.tool} ${jsonEncode(p.args)}'}'
            '${fg.note == null ? '' : ' → 앱 가드: ${fg.note}'}'
            '${referNote == null ? '' : ' → 앱 가드: $referNote → ${p.tool} ${jsonEncode(p.args)}'}');
  }

  /// 검사한 계획 → 답 (Gemini 도구 고르기 · 조건 칩 · 넓히기가 함께 씀)
  Future<ChatMessage> _runPlan(AgentPlan p, String text, {required String note}) async {
    // 자기 이야기는 질문에 그 말이 있을 때만. '몇 개월 남음'도 질문에 'N개월·N달'이 있을 때만
    final monthsLeft = RegExp(r'\d+\s*(개월|달)').hasMatch(text) ? p.monthsLeft : null;
    p = AgentPlan(
      tool: p.tool, self: ToolPlanner.grounded(p.self, text), venue: p.venue, names: p.names, topic: p.topic,
      targetSido: p.targetSido, nationwide: p.nationwide, byAmount: p.byAmount, items: p.items,
      itemBudget: p.itemBudget, cheapest: p.cheapest, expr: p.expr, untilDate: p.untilDate,
      weddingDate: p.weddingDate, monthsLeft: monthsLeft, refIndex: p.refIndex, unsupported: p.unsupported,
      args: p.args,
    );
    _plan = p;
    _vq = p.venue;
    _forceByAmount = p.byAmount;
    _askDate = p.venue?.date;
    _period = p.venue != null && p.venue!.hasPeriod ? _periodOf(p.venue!) : null;
    _unsupported = p.unsupported;
    _nluNote = note;
    _planLog.add((q: text, tool: p.tool, args: p.args));
    // 자기 이야기 → 대화 기억 + 내 정보 (지역은 사는 곳을 말했을 때만)
    _known = _known.merge(p.self.profile);
    _noteSelf(p.self.profile, region: p.self.livesGiven);
    // 찾는 시도는 대화 기억에 시도가 없을 때만 채운다 (되묻지 않게)
    final firstSido = p.venue?.sidos.firstOrNull ?? p.targetSido;
    if (_known.sido == null && firstSido != null) _known = _known.merge(UserProfile(sido: firstSido));
    if (p.weddingDate != null) {
      _known = _known.merge(UserProfile(weddingDate: p.weddingDate));
      _noteSelf(UserProfile(weddingDate: p.weddingDate));
    }
    final lastIntent = _turns.lastOrNull?.intent ?? ConsultIntent.venue;
    final u = switch (p.tool) {
      'search_venues' || 'venue_info' => Understanding(
          intent: ConsultIntent.venue,
          kind: p.tool == 'venue_info' ? AskKind.detail : AskKind.list,
          names: p.names,
          filter: p.venue?.freeOnly == true ? 'free' : null,
          exclude: p.venue?.excludeTowns ?? const [],
          needs: p.venue?.needs ?? const [],
          date: p.venue?.date,
          unsupported: p.unsupported),
      'search_policies' => Understanding(
          intent: ConsultIntent.policy, topic: p.topic, names: p.names),
      'search_vendors' => Understanding(
          intent: ConsultIntent.vendor,
          item: p.items.length == 1 ? p.items.first : null,
          items: p.items,
          itemBudget: p.itemBudget,
          filter: p.cheapest ? 'cheaper' : null),
      'estimate_cost' => Understanding(intent: ConsultIntent.budget, kind: AskKind.cost, items: p.items,
          item: p.items.length == 1 ? p.items.first : null),
      'calculate' => Understanding(intent: ConsultIntent.budget, kind: AskKind.calc, calc: p.expr),
      'wedding_schedule' => Understanding(intent: ConsultIntent.schedule, monthsLeft: p.weddingDate == null ? p.monthsLeft : null),
      'recommend_overview' => const Understanding(intent: ConsultIntent.recommend),
      'general_answer' => const Understanding(intent: ConsultIntent.help, kind: AskKind.general),
      'near_place' => const Understanding(intent: ConsultIntent.venue, kind: AskKind.list),
      'web_lookup' => const Understanding(intent: ConsultIntent.help, kind: AskKind.general),
      'refer_previous' => Understanding(intent: lastIntent, refIndex: p.refIndex),
      _ => const Understanding(intent: ConsultIntent.help),
    };
    if (p.tool == 'show_more') return _moreAnswer();
    return _process(u, plan: p);
  }

  /// 예식장 답변에 쓰는 지역 이름: 도구 조건의 시도(여러 개면 ·로), 없으면 대화의 시도
  String get _searchSidoLabel => _vq != null && _vq!.sidos.isNotEmpty ? _vq!.sidos.join('·') : _known.sido!;

  /// 도구 조건의 기간 → 날짜들 (요일 말이 없으면 주말)
  ({List<DateTime> dates, String label}) _periodOf(VenueQuery q) {
    final days = q.weekdays.isEmpty ? const [DateTime.saturday, DateTime.sunday] : q.weekdays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = [
      for (var d = q.from!; !d.isAfter(q.to!); d = DateTime(d.year, d.month, d.day + 1))
        if (days.contains(d.weekday) && d.isAfter(today)) d,
    ];
    const names = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'};
    final dayLabel = days.length == 2 && days.contains(6) && days.contains(7)
        ? '주말'
        : days.length == 5 && !days.contains(6) && !days.contains(7)
            ? '평일'
            : '${days.map((d) => names[d]).join('·')}요일';
    final f = q.from!, t = q.to!;
    final sameMonth = f.year == t.year && f.month == t.month && f.day == 1 && DateTime(t.year, t.month + 1, 0).day == t.day;
    final range = sameMonth ? '${f.year}년 ${f.month}월' : '${formatDate(f)}~${formatDate(t)}';
    return (dates: dates, label: '$range $dayLabel');
  }

  /// 도구 경로의 바로 답하기: 도구 이름으로 고른다 (예전 경로의 정규식 대신)
  Future<Future<ChatMessage> Function()?> _planDirect(AgentPlan p, Understanding u) async {
    switch (p.tool) {
      case 'search_venues':
        if (_known.sido == null) return null; // 지역 되묻기
        if (_askDate != null) return () => _venueDateAnswer(_askDate!, u);
        if (_period != null && _period!.dates.isNotEmpty) {
          return () => _venueSeasonAnswer(u, _period!.dates, _period!.label);
        }
        return null;
      case 'venue_info':
        final named = findVenuesByName(await Repos.venue.loadAll(), _question, names: p.names);
        if (named.length == 1) return () async => _venueDetailAnswer(named.first, u);
        if (named.length >= 2) return () => _compareAnswer(named.take(3).toList(), u);
        return null;
      case 'search_policies':
        final home = _known.sido;
        if (p.targetSido != null && p.targetSido != home) return () => _residencyAnswer(p.targetSido!);
        if (p.nationwide && (p.topic == PolicyCategory.cash || p.byAmount)) return () => _cashRegionAnswer();
        if (p.names.isNotEmpty) {
          final hit = await _policyHits(u);
          if (hit.length == 1) return () async => _policyDetailAnswer(hit.first);
        }
        return null;
      case 'search_vendors':
        if (u.items.length > 1 && _known.sido != null) return () => _bundleAnswer(u);
        return null;
      case 'estimate_cost':
        return () => _costAnswer(u);
      case 'calculate':
        if (p.untilDate != null) return () async => _daysUntilAnswer(p.untilDate!);
        if (p.expr != null && evalExpr(p.expr!) != null) return () async => _calcAnswer(p.expr!);
        return _llm == null ? null : () => _generalAnswer(u);
      case 'general_answer':
        return _llm == null ? null : () => _generalAnswer(u);
      case 'near_place':
        return () => _nearPlaceAnswer(p);
      case 'web_lookup':
        return _llm == null || p.query == null ? null : () => _webAnswer(p.query!);
      default:
        return null;
    }
  }

  /// ① 질문 이해: Gemini가 있으면 Gemini, 실패하거나 없으면 규칙.
  /// 규칙으로 뽑은 값도 함께 써서, Gemini가 놓친 값은 규칙 결과로 채운다.
  Future<({Understanding u, bool isAnswer})> _understand(String text, {Slot? expecting}) async {
    final plain = _nlu.parse(text, expecting: expecting);
    if (expecting == null) {
      _askDate = parseAskDate(text);
      _period = null;
      _unsupported = const [];
    }
    // 되묻기 답("서울")이 아니면 대화 흐름 규칙도 적용 ("두 번째", "그중에 무료", "그럼 부산은?")
    final rule = expecting == null ? ContextRules.apply(plain, text, _turns) : plain;
    final context = _turns.isEmpty ? null : ConversationContext.state(_turns, _memoryTurns, known: _known);
    final ai = _noLlmUnderstand ? null : await _llm?.understand(text, expecting: expecting, context: context);
    _noLlmUnderstand = false;
    final flow = context == null ? '' : ' · 최근 ${_turns.length.clamp(1, _memoryTurns)}턴 대화 요약을 함께 봄';
    if (ai == null) {
      _nluNote = (_llm == null ? '규칙(키워드·대화 흐름)으로 이해' : 'Gemini 응답 없음 → 규칙(키워드·대화 흐름)으로 이해');
      return (u: _withTown(rule, text), isAnswer: false);
    }
    _nluNote = 'Gemini가 이해$flow (정해진 형식·값 범위 검사 후 사용, 놓친 값은 규칙으로 보완)';
    final intent = ai.u.intent;
    final town = _noExcluded(_townFacts(text, plain.facts.merge(ai.u.facts)), [...ai.u.exclude, ...rule.exclude]);
    if (expecting == null) {
      // "내년 3월"처럼 일(日) 없이 달만 물으면 Gemini가 1일로 채운 날짜를 쓰지 않는다 (기간 질문으로 처리).
      // "12월 둘째주 토요일"처럼 주가 정해진 말은 Gemini 날짜를 쓴다
      final monthOnly = _askDate == null &&
          RegExp(r'(?<![\d.])\d{1,2}\s*월|다음\s*달|이번\s*달|내년|올해|봄|여름|가을|겨울').hasMatch(text) &&
          !RegExp(r'\d{1,2}\s*일|째\s*주|첫\s*주|마지막\s*주|/').hasMatch(text);
      _askDate = monthOnly ? null : (ai.u.date ?? _askDate);
      // 날짜 조건은 앱이 예식 가능일로 판단하므로 '확인 못 함'에서 뺀다
      _unsupported = [
        for (final x in ai.u.unsupported)
          if (!RegExp(r'날짜|일자|예약 가능|가능일|\d|주차|피로연|뷔페|케이터링|식사|야외|비용|얼마|추가금|비교|나아|계산|싸|무료|하객|사진|그중|많이 주|금액|소득|연봉|봄|여름|가을|겨울|요일|주말|큰|넓|크기|정원|인원|월|달|예약|비어|자리|거주|살|주민')
              .hasMatch(x)) x,
      ];
    }
    return (
      isAnswer: ai.isAnswer || (expecting == Slot.sigungu && town.sigungu != null),
      u: ai.u
          .copyWith(
            facts: town,
            topic: ai.u.topic ?? (intent == ConsultIntent.policy ? rule.topic : null),
            item: ai.u.item ?? (intent == ConsultIntent.vendor ? rule.item : null),
            refIndex: ai.u.refIndex ?? rule.refIndex,
            filter: ai.u.filter ?? rule.filter,
          )
          .withPlanFrom(rule),
    );
  }

  /// 문장 속 시·군·구 ("강남구 살아요", "수원이에요") → 지역 정보에 보탠다 (이미 아는 시도 안에서 먼저 찾음)
  UserProfile _townFacts(String text, UserProfile facts) {
    if (facts.sigungu != null) return facts;
    final hit = findSigungu(text, sido: facts.sido ?? _known.sido) ?? (facts.sido == null ? findSigungu(text) : null);
    if (hit == null) return facts;
    return facts.merge(UserProfile(sido: hit.$1, sigungu: hit.$2));
  }

  Understanding _withTown(Understanding u, String text) => u.copyWith(facts: _noExcluded(_townFacts(text, u.facts), u.exclude));

  /// "강남구 말고"의 강남구는 사는 곳이 아니라 뺄 조건
  UserProfile _noExcluded(UserProfile f, List<String> exclude) =>
      f.sigungu != null && exclude.any((e) => f.sigungu!.startsWith(e.replaceAll(RegExp(r'(구|시|군)$'), '')))
          ? f.copyWith(clearSigungu: true)
          : f;

  /// ⑤ 답변 문장: 앱이 만든 답변(데이터 결과)을 Gemini가 질문에 맞게 다시 쓴다.
  /// 원문에 없는 숫자가 나오면 Gemini 문장을 버리고 원래 문장을 쓴다.
  /// Gemini가 답 문장을 다시 쓰는 단계. 2026-11-20 끔: 무료 요금제에서 Gemini가 느려(한 턴 20~50초, 시간 초과 잦음)
  /// 턴당 Gemini 호출을 도구 고르기 1번으로 줄였다. 답 문장은 앱이 조회 결과로 만든 문장 (숫자는 모두 데이터 그대로)
  static const rewriteAnswers = false;

  Future<ChatMessage> _polish(ChatMessage m) async {
    final llm = _llm;
    if (!rewriteAnswers || llm == null || m.isQuestion || m.aiWritten) return m;
    final text = await llm.rewrite(question: _question, draft: draftOf(m));
    return text == null ? m : m.copyWith(text: text, aiWritten: true);
  }

  /// Gemini에 넘기는 "조회 결과": 기준 + 앱이 만든 답변 + 출처 (카드·버튼은 앱이 직접 붙임)
  static String draftOf(ChatMessage m) => [
        if (m.basis != null) '기준: ${m.basis}',
        m.text,
        if (m.sources.isNotEmpty) '출처: ${m.sources.join(', ')}',
      ].join('\n');

  @override
  Future<ChatMessage> choose(QuickReply r) async {
    _resetTurn();
    if (r.action == 'undo_profile') {
      _templateOnly = '앱 동작 안내';
      return _present(_undoSelfFacts());
    }
    _selfFacts = const UserProfile();
    return _present(_applySelfFacts(await _choose(r)));
  }

  Future<ChatMessage> _choose(QuickReply r) async {
    if (const ['open_checklist', 'open_tab', 'save_profile', 'skip_ask'].contains(r.action)) _templateOnly = '앱 동작 안내';
    switch (r.action) {
      case 'open_checklist':
        MainShell.goTo(3);
        return ChatMessage(fromUser: false, text: '체크리스트 탭을 열었어요. 준비 항목을 눌러 금액을 적어 주세요.');
      case 'skip_ask':
        return _skipCurrent();
      case 'form':
        return _applyForm(r);
      case 'more':
        return _moreAnswer();
      case 'refine':
        return _refine(r);
      case 'open_tab':
        if (_moreTab == 2 && _moreCategory != null) VendorScreen.categoryRequest.value = _moreCategory;
        MainShell.goTo(_moreTab);
        return ChatMessage(
            fromUser: false, text: '${switch (_moreTab) { 1 => '정책', 2 => '업체', _ => '예식장' }} 탭을 열었어요.');
      case 'save_profile':
        _app.saveProfile(_app.profile.merge(_known));
        return const ChatMessage(
          fromUser: false,
          text: '이번 대화에서 알려주신 정보를 내 정보에 저장했어요. 다음 상담과 정책·업체 탭에도 반영돼요.',
        );
    }
    if (r.slot == Slot.item.name && _pending != null) {
      _pending = _pending!.withItem(VendorCategory.values.byName(r.value as String));
      return _process(_pending!, plan: _plan);
    }
    if (r.slot != null && _pending != null) {
      if (r.slot == Slot.sido.name) _sidoJustAsked = true;
      final slot = Slot.values.byName(r.slot!);
      _known = _known.merge(_valueToFacts(slot, r.value));
      // 버튼으로 고른 답도 자기 정보. '3개월 뒤'처럼 어림한 예식일은 정확한 날짜로 저장하지 않는다
      if (!(slot == Slot.weddingDate && const [90, 180, 365].contains(r.value))) {
        _noteSelf(_valueToFacts(slot, r.value), region: true);
      }
      return _process(_pending!, plan: _plan);
    }
    if (r.text != null) return reply(r.text!);
    return _help();
  }

  // ───────────────────────── 대화 흐름 ─────────────────────────

  Future<ChatMessage> _process(Understanding u, {AgentPlan? plan}) async {
    _flowNote = '';
    if (plan != null) return _processPlanned(u, plan);
    _known = _known.merge(u.facts);
    // 문장 속 나이·하객·예산·무주택 등은 자기 정보. 지역은 "강남 살아요"처럼 사는 곳을 말했을 때만
    // ("부산 예식장 알려줘"의 부산은 찾는 곳일 수 있어 내 정보로 저장하지 않음)
    _noteSelf(u.facts);
    final home = _livingRegion;
    if (home != null) _noteSelf(home, region: true);
    if (u.intent == ConsultIntent.schedule && _askDate != null && _askDate!.isAfter(DateTime.now())) {
      // "2027년 4월 10일 결혼이면 며칠 남았어?" → 질문 속 날짜가 예식일 ('몇 개월 남음' 어림값보다 우선)
      _known = _known.merge(UserProfile(weddingDate: _askDate));
      _noteSelf(UserProfile(weddingDate: _askDate));
    } else if (u.monthsLeft != null) {
      _known = _known.merge(UserProfile(weddingDate: DateTime.now().add(Duration(days: u.monthsLeft! * 30))));
    }
    // 규칙 이해가 "대관료 싼 예식장"을 정책 질문으로 읽으면 예식장 찾기(대관료 낮은 순)로
    if (u.intent == ConsultIntent.policy &&
        RegExp(r'예식장|웨딩홀|식장').hasMatch(_question) &&
        RegExp(r'싼|저렴|낮은').hasMatch(_question) &&
        !RegExp(r'정책|지원|대출|장려금|혜택').hasMatch(_question)) {
      u = u.copyWith(intent: ConsultIntent.venue, filter: 'cheaper');
    }
    // 짧은 후속 질문("그중에 …", "말고 …")은 검토 대상
    if (RegExp(r'^(그중|그럼|거기서|그거|아니|말고)').hasMatch(_question.trim()) || _isFollowUp) _followUpTurn = true;
    // 규칙 이해가 목적을 못 정했는데 문장에 시·군·구가 있으면 예식장 찾기로 ("강남구 말고 송파구", "저 수원 살고 하객 100명")
    if (u.intent == ConsultIntent.help &&
        u.kind != AskKind.general &&
        findSigungus(_question).isNotEmpty &&
        !RegExp(r'정책|지원|대출|장려금|업체|드레스|스냅|날씨').hasMatch(_question)) {
      u = u.copyWith(intent: ConsultIntent.venue);
    }
    u = _carryVenueConds(u);
    if (u.refIndex == null || _noReferent) {
      final direct = await _directAnswer(u);
      if (direct != null) {
        _clearPending();
        return _finish(u, build: direct);
      }
    }
    if (u.refIndex != null) {
      final picked = _pickFromHistory(u);
      if (picked != null) {
        _clearPending();
        return _finish(u, build: () => _refAnswer(u, picked.$1, picked.$2, picked.$3));
      }
    }
    final missing = _missing(u);
    if (missing.isNotEmpty) {
      _pending = u;
      _asking = missing.first;
      final form = _formSlots(u, missing);
      if (form.isNotEmpty) return _askForm(form, u);
      return _ask(missing.first, u, remaining: missing.length);
    }
    final skipped = [for (final s in _skipped) _slotLabel[s]!];
    _clearPending();
    if (u.intent == ConsultIntent.help) return _helpAnswer();
    return _finish(u, skipped: skipped);
  }

  /// 도구 경로: 도구 이름으로 바로 답하기 → 앞 목록 가리키기 → 빠진 정보 되묻기 → 목적별 답변
  Future<ChatMessage> _processPlanned(Understanding u, AgentPlan p) async {
    if (u.monthsLeft != null && p.weddingDate == null) {
      _known = _known.merge(UserProfile(weddingDate: DateTime.now().add(Duration(days: u.monthsLeft! * 30))));
    }
    if (u.refIndex != null) {
      final picked = _pickFromHistory(u);
      if (picked != null) {
        _clearPending();
        return _finish(u, build: () => _refAnswer(u, picked.$1, picked.$2, picked.$3));
      }
    }
    final direct = await _planDirect(p, u);
    if (direct != null) {
      _clearPending();
      return _finish(u, build: direct);
    }
    final missing = _missing(u);
    if (missing.isNotEmpty) {
      _pending = u;
      _asking = missing.first;
      final form = _formSlots(u, missing);
      if (form.isNotEmpty) return _askForm(form, u);
      return _ask(missing.first, u, remaining: missing.length);
    }
    // 되묻고 나서 지역이 생겼으면 날짜·기간 답으로
    if (p.tool == 'search_venues' && (_askDate != null || _period != null)) {
      final again = await _planDirect(p, u);
      if (again != null) {
        _clearPending();
        return _finish(u, build: again);
      }
    }
    final skipped = [for (final s in _skipped) _slotLabel[s]!];
    _clearPending();
    if (u.intent == ConsultIntent.help && u.kind != AskKind.general) return _helpAnswer();
    return _finish(u, skipped: skipped);
  }

  /// ④ 데이터 조회 → ⑤ 답변 작성 + "왜 이렇게 답했나요?" 기록
  Future<ChatMessage> _finish(Understanding u,
      {List<String> skipped = const [], Future<ChatMessage> Function()? build}) async {
    step.value = AgentStep.lookup;
    _lookupNote = '';
    _funnel = const [];
    _lastU = u;
    var m = await (build?.call() ?? _answer(u));
    if (u.also != null && u.also != u.intent && build == null && !m.isQuestion) m = await _withAlso(u, m);
    if (_unsupported.isNotEmpty && !m.isQuestion && u.kind != AskKind.general) {
      m = m.copyWith(
        text: '${m.text}\n\n참고: "${_unsupported.join('", "')}" 조건은 앱 데이터로 확인할 수 없어 반영하지 못했어요. '
            '상세 화면의 주소·문의처로 직접 확인해 주세요.',
      );
    }
    if (_llm != null) step.value = AgentStep.write;
    final out = await _polish(m);
    final what = [
      '목적 ${_intentLabel[u.intent]}${u.also != null ? ' + ${_intentLabel[u.also]}' : ''}',
      if (u.kind != AskKind.list) '질문 종류 ${_kindLabel[u.kind]}',
      if (u.names.isNotEmpty) '이름 ${u.names.join(', ')}',
      if (u.exclude.isNotEmpty) '제외 ${u.exclude.join(', ')}',
      if (u.needs.isNotEmpty) '조건 ${u.needs.map((n) => _needLabel[n]).join(', ')}',
      if (u.items.length > 1) '항목 묶음 ${u.items.map((i) => i.label).join('·')}',
      if (u.itemBudget != null) '항목 예산 ${u.itemBudget}만원',
      if (u.monthsLeft != null) '예식까지 ${u.monthsLeft}개월',
      if (u.topic != null) '분야 ${u.topic!.label}',
      if (u.item != null) '항목 ${u.item!.label}',
    ].join(' · ');
    final used = (m.basis?.isNotEmpty ?? false) ? m.basis! : (_known.summary.isEmpty ? '없음' : _known.summary);
    // 대화 기억: 몇 번째 항목 답변은 목록을 바꾸지 않는다 (다음 "세 번째 거"도 같은 목록을 가리키게)
    _remember(
      Turn(
        user: _question,
        bot: out.text,
        intent: u.intent,
        topic: u.topic,
        item: u.item,
        sido: _known.sido,
        results: build != null ? const [] : [for (final c in m.cards) c.title],
      ),
      build != null ? const [] : m.cards,
    );
    return out.copyWith(trace: [
      '질문 이해 · $what — $_nluNote',
      if (_flowNote.isNotEmpty) '대화 흐름 · $_flowNote',
      if (_askDate != null) '날짜 조건 · ${dateLabel(_askDate!)}',
      if (_unsupported.isNotEmpty) '앱 데이터에 없는 조건 · ${_unsupported.join(', ')} (Gemini가 판단, 답변에 안내)',
      '사용한 정보 · $used${skipped.isEmpty ? '' : ' (모른다고 하신 정보: ${skipped.join(', ')} → 없이 진행)'}',
      if (_lookupNote.isNotEmpty) '데이터 조회 · $_lookupNote',
      '답변 작성 · ${_llm == null ? '앱이 정해진 문장 틀로 작성 (Gemini 미연결)' : !rewriteAnswers ? (m.aiWritten ? 'Gemini 일반 안내 (앱 데이터 아님 표시)' : (useBlocks ? '앱이 조회 결과 정리 → 블록 답 (아래 답 작성·검사 기록)' : '앱이 조회 결과로 문장 작성')) : _llm.lastRewriteNote}',
    ]);
  }

  /// 데이터로 답할 수 없는 질문: Gemini가 일반 안내를 하고, 물어볼 수 있는 것을 보여준다
  Future<ChatMessage> _helpAnswer() async {
    final text = _question.isEmpty ? null : await _llm?.chat(_question);
    if (text == null) return _help();
    return ChatMessage(
      fromUser: false,
      text: text,
      aiWritten: true,
      quickReplies: _starterReplies,
    );
  }

  void _clearPending() {
    _pending = null;
    _asking = null;
    _skipped.clear();
  }

  Future<ChatMessage> _skipCurrent() async {
    if (_asking == null || _pending == null) return _help();
    _skipped.add(_asking!);
    return _process(_pending!, plan: _plan);
  }

  bool _isDontKnow(String t) => ['모르', '몰라', '패스', '건너', '상관없', '아무'].any(t.contains);

  /// 질문 목적별로 꼭 필요한 정보
  List<Slot> _required(Understanding u) => switch (u.intent) {
        ConsultIntent.policy => [
            Slot.sido,
            Slot.sigungu,
            Slot.age,
            Slot.stage,
            if (_known.stage == MarriageStage.married) Slot.marriedYears,
            if (u.topic == PolicyCategory.housing) Slot.homeless,
          ],
        ConsultIntent.venue => [Slot.sido, Slot.sigungu, Slot.guests],
        ConsultIntent.vendor => [
            if (u.item == null) Slot.item,
            Slot.sido,
            Slot.budget,
            if (u.item == VendorCategory.meal || u.item == VendorCategory.invitation) Slot.guests,
          ],
        ConsultIntent.budget => [Slot.budget],
        ConsultIntent.schedule => [Slot.weddingDate],
        ConsultIntent.recommend => [Slot.sido, Slot.sigungu, Slot.age, Slot.stage, Slot.guests, Slot.budget],
        ConsultIntent.help => const [],
      };

  List<Slot> _missing(Understanding u) =>
      _required(u).where((s) => !_skipped.contains(s) && !_isFilled(s, u)).toList();

  bool _isFilled(Slot s, Understanding u) => switch (s) {
        Slot.sido => _known.sido != null,
        // 시군구는 선택: 시도를 모르거나 시군구가 하나뿐이면 묻지 않는다
        Slot.sigungu => !_sidoJustAsked ||
            _known.sigungu != null ||
            _known.sido == null ||
            (kSigunguBySido[_known.sido]?.length ?? 0) <= 1,
        Slot.age => _known.age != null,
        Slot.stage => _known.stage != null,
        Slot.marriedYears => _known.marriedYears != null,
        Slot.guests => _known.guests != null,
        Slot.budget => _known.budget != null,
        Slot.homeless => _known.homeless != null,
        Slot.weddingDate => _known.weddingDate != null || _known.weddingUndecided,
        Slot.item => u.item != null,
      };

  UserProfile _valueToFacts(Slot s, Object? v) => switch (s) {
        Slot.sido => UserProfile(sido: v as String),
        Slot.sigungu => UserProfile(sido: _known.sido, sigungu: v as String),
        Slot.age => UserProfile(age: (v as List<int>)[0], ageMax: v.length > 1 ? v[1] : null),
        Slot.stage => UserProfile(stage: MarriageStage.values.byName(v as String)),
        Slot.marriedYears => UserProfile(marriedYears: v as int),
        Slot.guests => UserProfile(guests: v as int),
        Slot.budget => UserProfile(budget: v as int),
        Slot.homeless => UserProfile(homeless: v as bool),
        Slot.weddingDate => (v as int) < 0
            ? const UserProfile(weddingUndecided: true)
            : UserProfile(weddingDate: DateTime.now().add(Duration(days: v))),
        Slot.item => const UserProfile(),
      };

  // ───────────────────────── 되묻기 ─────────────────────────

  ChatMessage _ask(Slot s, Understanding u, {int? remaining, bool retry = false}) {
    final why = _purpose(u);
    final (String q, List<QuickReply> options) = switch (s) {
      Slot.sido => (
          '$why 사는 지역에 따라 달라져요. 어느 지역에 살고 계세요?',
          [for (final sido in kSidoList) QuickReply(sido, slot: s.name, value: sido)],
        ),
      Slot.sigungu => (
          '${_known.sido}의 어느 시·군·구에 사세요? 그 지역 정책·예식장까지 정확히 찾아 드려요. 글로 적어 주셔도 돼요.',
          [for (final g in kSigunguBySido[_known.sido] ?? const <String>[]) QuickReply(g, slot: s.name, value: g)],
        ),
      Slot.age => (
          '만 나이를 알려주세요. 나이 조건(예: 만 19~39세)이 있는 정책이 많아요. 숫자로 적어 주셔도 돼요.',
          [
            for (final (a, b) in [(19, 24), (25, 29), (30, 34), (35, 39), (40, 49)])
              QuickReply('만 $a~$b세', slot: s.name, value: [a, b]),
          ],
        ),
      Slot.stage => (
          '혼인신고는 하셨나요? 예비부부와 신혼부부는 받을 수 있는 지원이 달라요.',
          [
            QuickReply('아직이에요 (예비부부)', slot: s.name, value: MarriageStage.engaged.name),
            QuickReply('했어요 (신혼부부)', slot: s.name, value: MarriageStage.married.name),
          ],
        ),
      Slot.marriedYears => (
          '혼인신고한 지 얼마나 되셨어요? "혼인 7년 이내" 같은 조건이 많아요.',
          [
            QuickReply('1년 이내', slot: s.name, value: 1),
            QuickReply('2~3년', slot: s.name, value: 3),
            QuickReply('4~7년', slot: s.name, value: 7),
            QuickReply('7년 넘었어요', slot: s.name, value: 8),
          ],
        ),
      Slot.homeless => (
          '지금 집을 갖고 계신가요? 주거·대출 지원은 대부분 무주택 조건이 있어요.',
          [
            QuickReply('무주택이에요', slot: s.name, value: true),
            QuickReply('집이 있어요', slot: s.name, value: false),
          ],
        ),
      Slot.guests => (
          '하객은 몇 명 정도 예상하세요? 예식장 정원과 식대 계산에 써요.',
          [
            for (final n in [50, 100, 150, 200, 300]) QuickReply('$n명', slot: s.name, value: n),
          ],
        ),
      Slot.budget => (
          '결혼 총예산은 어느 정도 생각하세요?',
          [
            for (final n in [1000, 2000, 3000, 5000, 7000])
              QuickReply(formatManwon(n), slot: s.name, value: n),
          ],
        ),
      Slot.weddingDate => (
          '예식일은 정하셨나요? 남은 기간에 맞춰 할 일 순서를 알려드릴게요.',
          [
            QuickReply('3개월 뒤', slot: s.name, value: 90),
            QuickReply('6개월 뒤', slot: s.name, value: 180),
            QuickReply('1년 뒤', slot: s.name, value: 365),
            QuickReply('아직 미정', slot: s.name, value: -1),
          ],
        ),
      Slot.item => (
          '어떤 항목을 찾으세요?',
          [
            const QuickReply('공공예식장', text: '대관료 무료 공공예식장 알려줘'),
            for (final c in VendorCategory.planItems) QuickReply(c.label, slot: s.name, value: c.name),
          ],
        ),
    };
    // 숫자는 [직접 입력], 예식일은 [날짜 고르기] (화면에서 입력 창을 띄움)
    final input = switch (s) {
      Slot.age || Slot.guests || Slot.budget || Slot.marriedYears => QuickReply('직접 입력', slot: s.name, action: 'input'),
      Slot.weddingDate => QuickReply('날짜 고르기', slot: s.name, action: 'input'),
      _ => null,
    };
    final prefix = retry ? '죄송해요, 잘 알아듣지 못했어요. 아래에서 골라 주시거나 다시 적어 주세요.\n' : '';
    final known = _known.summary;
    return ChatMessage(
      fromUser: false,
      isQuestion: true,
      text: '$prefix$q${remaining != null && remaining > 1 ? '\n(확인할 것 $remaining개 중 하나예요)' : ''}',
      basis: known.isEmpty ? null : '지금까지 알려주신 정보: $known',
      quickReplies: [...options, ?input, const QuickReply('잘 모르겠어요', action: 'skip_ask')],
    );
  }

  // ───────────────────────── 채팅 안 미니 폼 (Red Team P2-2) ─────────────────────────

  static const _formSlotOf = {'region': Slot.sido, 'age': Slot.age, 'stage': Slot.stage, 'homeless': Slot.homeless};

  /// 정책 질문에 빠진 조건(사는 곳·나이·결혼 단계·주택)이 2개 이상이면 한 장의 폼으로 묻는다. 하나뿐이면 예전처럼 하나씩 (빈 목록)
  List<String> _formSlots(Understanding u, List<Slot> missing) {
    if (u.intent != ConsultIntent.policy) return const [];
    final core = missing.where((s) => _formSlotOf.containsValue(s)).length;
    if (core < 2) return const [];
    return [
      if (missing.contains(Slot.sido) || missing.contains(Slot.sigungu)) 'region', // 시도를 알아도 시·군·구는 폼에서 함께
      if (missing.contains(Slot.age)) 'age',
      if (missing.contains(Slot.stage)) 'stage',
      // 주택은 주거 정책이 아니어도 판정에 쓰이므로 모르면 함께 묻는다 (선택)
      if (missing.contains(Slot.homeless) || _known.homeless == null) 'homeless',
    ];
  }

  ChatMessage _askForm(List<String> slots, Understanding u) {
    final what = [
      if (slots.contains('region')) '사는 곳',
      if (slots.contains('age')) '나이',
      if (slots.contains('stage')) '결혼 단계',
      if (slots.contains('homeless')) '주택',
    ].join('·');
    _hint = const AnswerHint(kind: AnswerKind.ask, headline: '조건을 한 번에 골라 주세요');
    final known = _known.summary;
    return ChatMessage(
      fromUser: false,
      isQuestion: true,
      text: '${_purpose(u)} $what에 따라 달라져요. 아래 카드에서 한 번에 골라 주시면 바로 찾아 드릴게요.',
      basis: known.isEmpty ? null : '지금까지 알려주신 정보: $known',
      form: slots,
    );
  }

  /// 미니 폼 제출: 고른 값은 자기 정보로 저장(위쪽 조건 칩), 비운 칸은 '잘 모름'으로 건너뛰고 기다리던 질문에 답한다
  Future<ChatMessage> _applyForm(QuickReply r) async {
    final pending = _pending;
    if (pending == null) return _help();
    final v = (r.value as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
    final date = v['weddingDate'] is String ? DateTime.tryParse(v['weddingDate'] as String) : null;
    final f = UserProfile(
      sido: kSidoList.contains(v['sido']) ? v['sido'] as String : null,
      sigungu: v['sigungu'] is String ? v['sigungu'] as String : null,
      age: v['age'] is int ? v['age'] as int : null,
      stage: v['stage'] is String ? MarriageStage.values.byName(v['stage'] as String) : null,
      weddingDate: date,
      homeless: v['homeless'] is bool ? v['homeless'] as bool : null,
    );
    _known = _known.merge(f);
    _noteSelf(f, region: true);
    // 폼에서 비운 칸은 다시 묻지 않는다 (시·군·구도 폼에서 함께 골랐으므로 따로 묻지 않음)
    final slots = [for (final s in (v['slots'] as List?) ?? const []) if (s is String) s];
    for (final s in slots) {
      final slot = _formSlotOf[s];
      if (slot != null && !_isFilled(slot, pending)) _skipped.add(slot);
    }
    _skipped.add(Slot.sigungu);
    _sidoJustAsked = false;
    _asking = null;
    return _process(pending, plan: _plan);
  }

  String _purpose(Understanding u) => switch (u.intent) {
        ConsultIntent.policy => '지원 정책은',
        ConsultIntent.venue => '공공예식장은',
        ConsultIntent.vendor => '업체 추천은',
        ConsultIntent.recommend => '추천은',
        _ => '답변은',
      };

  // ───────────────────────── 답변 ─────────────────────────

  Future<ChatMessage> _answer(Understanding u) async => switch (u.intent) {
        ConsultIntent.policy => _policyAnswer(u),
        ConsultIntent.venue => _askDate != null ? _venueDateAnswer(_askDate!, u) : _venueAnswer(u),
        ConsultIntent.vendor => _vendorAnswer(u.item!, cheapest: u.filter == 'cheaper', itemBudget: u.itemBudget),
        ConsultIntent.budget => _budgetAnswer(),
        ConsultIntent.schedule => _scheduleAnswer(),
        ConsultIntent.recommend => _recommendAnswer(),
        ConsultIntent.help => _help(),
      };

  /// 대화에서 새로 알게 된 정보가 있으면 저장 버튼을 붙인다
  List<QuickReply> _withSave(List<QuickReply> replies) {
    final saved = _app.profile.summary;
    final now = _app.profile.merge(_known).summary;
    return [
      ...replies,
      if (now != saved) const QuickReply('이 정보를 내 정보에 저장', action: 'save_profile'),
    ];
  }

  Future<ChatMessage> _policyAnswer(Understanding u) async {
    var matches = await ConsultTools.matchPolicies(_known, topic: u.topic);
    final topicNote = u.topic != null ? '${u.topic!.label} ' : '';
    // 그 분야가 0건이면 조용히 전체 정책으로 바꾸지 않고 '없다'고 말한다 (같은 답 반복처럼 보이던 문제, 2026-11-20)
    if (matches.isEmpty && u.topic != null) return _emptyTopicAnswer(u.topic!);
    // 질문에 소득이 있으면 원문의 소득 상한과 비교, "제일 많이 주는"이면 원문의 최대 금액 순
    final income = incomeFromQuestion(_question);
    final byAmount = _forceByAmount || RegExp(r'제일\s*많이|가장\s*많이|많이\s*주|금액.{0,4}(큰|많)|최대\s*얼마').hasMatch(_question);
    final notes = <String>[];
    var overAsked = <PolicyMatch>[]; // 질문에 이름이 나온 정책인데 소득 상한을 넘는 것 ("신혼부부 전세대출 돼?")
    if (income != null) {
      final over = matches.where((m) => (incomeCap(m.policy.eligibility) ?? 1 << 30) < income).toList();
      const keys = ['신혼부부', '청년', '전세', '대출', '구입', '이자', '임대', '특공', '매입'];
      final asked = [for (final k in keys) if (_question.replaceAll(' ', '').contains(k)) k];
      if (asked.length >= 2) {
        overAsked = [for (final m in over) if (asked.every(m.policy.name.replaceAll(' ', '').contains)) m];
        // 내 정보에 소득이 들어가 판정에서 이미 빠진 정책도 (Gemini가 소득을 내 정보로 넘긴 경우) 전체 정책에서 찾는다
        if (overAsked.isEmpty) {
          overAsked = [
            for (final p in await Repos.policy.loadAll())
              if ((p.sido == '전국' || sidoMatches(p.sido, _known.sido)) &&
                  asked.every(p.name.replaceAll(' ', '').contains) &&
                  (incomeCap(p.eligibility) ?? 1 << 30) < income)
                PolicyMatch(p, MatchLevel.check, const [], const []),
          ];
        }
      }
      matches = matches.where((m) => !over.contains(m)).toList();
      final noNumber = matches.where((m) => m.policy.hasIncomeLimit && incomeCap(m.policy.eligibility) == null).length;
      // 내 정보에 소득이 이미 있어 판정에서 빠진 경우(over 0건)에도 물어본 정책이 상한을 넘으면 그렇게 말한다 ("0건 뺐어요"와 "대상 아님"이 어긋나지 않게)
      final shown = over.isNotEmpty ? over : overAsked;
      notes.add('부부합산 연소득 ${manwonLabel(income)} 기준으로 원문의 소득 상한을 비교했어요. '
          '${shown.isEmpty ? '상한을 넘는 정책은 없어요' : '상한을 넘는 정책: ${shown.take(2).map((m) => '${m.policy.name.split('(').first.trim()}(연 ${manwonLabel(incomeCap(m.policy.eligibility)!)})').join(', ')}${shown.length > 2 ? ' 외' : ''}'}'
          '${noNumber > 0 ? ', 소득 조건이 숫자로 적혀 있지 않은 $noNumber건은 기관에 확인이 필요해요' : ''}.');
    }
    if (byAmount) {
      // 받는 돈(현금 지원)을 먼저, 대출·이자·보증(빌리는 한도)은 뒤로 → 각각 원문 최대 금액 순
      int loan(PolicyMatch m) => RegExp(r'대출|이자|융자|보증').hasMatch(m.policy.name) ? 1 : 0;
      matches = [...matches]
        ..sort((a, b) {
          final byLoan = loan(a).compareTo(loan(b));
          return byLoan != 0 ? byLoan : (maxAmount(b.policy.eligibility) ?? -1).compareTo(maxAmount(a.policy.eligibility) ?? -1);
        });
      final withAmount = matches.where((m) => maxAmount(m.policy.eligibility) != null).length;
      notes.add('받는 돈(현금·비용 지원)을 먼저, 그다음 대출·이자 지원을 원문에 적힌 "최대 금액" 순으로 보여 드려요 (금액이 적힌 정책 $withAmount건). '
          '대출·이자 지원의 금액은 받는 돈이 아니라 빌릴 수 있는 한도예요.');
    }
    String extra(PolicyMatch m) => [
          if (income != null && incomeCap(m.policy.eligibility) != null) '소득 상한 연 ${manwonLabel(incomeCap(m.policy.eligibility)!)} (통과)',
          if (byAmount && maxAmount(m.policy.eligibility) != null) '원문 최대 ${manwonLabel(maxAmount(m.policy.eligibility)!)}',
        ].map((x) => ' / $x').join();
    final likely = matches.where((m) => m.level == MatchLevel.likely).length;
    _funnel = [
      '지원 정책 ${(await Repos.policy.loadAll()).length}건',
      '내 상황(지역·나이 등)으로 판정 · 해당 가능 ${matches.length}건',
      if (topicNote.isNotEmpty) '${topicNote.trim()} 분야만',
      if (income != null) '원문 소득 상한과 비교',
      '대상 가능성 높음 $likely건 · 조건 확인 ${matches.length - likely}건',
    ];
    _lookupNote = '정책 데이터를 정해진 규칙으로 판정 → 해당 가능 ${matches.length}건 '
        '${income != null ? '· 원문 소득 상한과 비교 ' : ''}${byAmount ? '· 원문 최대 금액 순 ' : ''}'
        '(가능성 높음 $likely건)${topicNote.isEmpty ? '' : ' · ${topicNote.trim()} 분야만'}';
    final top = matches.take(3).toList();
    final region = _known.sido ?? '전국';
    _hint = AnswerHint(
      kind: AnswerKind.policyList,
      headline: matches.isEmpty ? '맞는 ${topicNote}정책을 못 찾았어요' : '받을 수 있는 ${topicNote}정책 ${matches.length}건',
      sentence: income != null
          ? '연소득 ${manwonLabel(income)} 기준으로 소득 상한을 비교했어요.'
          : (_known.sido == null ? '지역을 알려 주시면 지자체 정책도 찾아요.' : null),
    );
    if (overAsked.isNotEmpty) {
      final cap = incomeCap(overAsked.first.policy.eligibility)!;
      _hint = AnswerHint(
        kind: AnswerKind.policyList,
        headline: overAsked.first.policy.name.contains('대출') ? '그 대출은 대상이 아니에요' : '그 정책은 대상이 아니에요',
        headBadges: [BlockBadge('소득 상한 연 ${manwonLabel(cap)}', Tone.no)],
        sentence: '아래는 소득 조건이 맞는 다른 정책이에요.',
      );
    }
    ChatCard policyCard(PolicyMatch m) => ChatCard(
          title: m.policy.name,
          subtitle: '${m.policy.regionLabel} · ${m.policy.category.label}',
          icon: Icons.volunteer_activism,
          badge: m.level == MatchLevel.likely ? '해당 가능성 높음' : '조건 확인 필요',
          open: () => PolicyDetailScreen(match: m),
          ref: 'policy:${m.policy.id}',
        );
    final more = _startMore([for (final m in matches) policyCard(m)], '받을 수 있는 ${topicNote}정책', unit: '건', tab: 1);
    final lines = [
      for (final m in top)
        '• ${m.policy.name}\n   ${m.reasons.take(2).join(', ')}'
            '${m.checks.isEmpty ? '' : ' / 확인할 것: ${m.checks.take(2).join(', ')}'}${extra(m)}',
    ];
    final tips = [
      if (_known.isAgeRange) '정확한 만 나이를 알려주시면 나이 조건을 더 정확히 판단할 수 있어요.',
      if (_known.homeless == null && matches.any((m) => m.policy.requiresHomeless))
        '무주택 여부를 알려주시면 주거 지원을 더 정확히 거를 수 있어요.',
      if (_known.sido == null) '지역을 알려주시면 지자체 정책까지 찾아드려요.',
    ];
    return ChatMessage(
      fromUser: false,
      basis: [region, _known.ageLabel, _known.stageLabel,
        if (_known.homeless != null) _known.homeless! ? '무주택' : '주택 보유'].join(' · '),
      text: matches.isEmpty
          ? '조건에 맞는 ${topicNote}정책을 찾지 못했어요. 지역이나 결혼 단계를 바꿔서 다시 찾아볼까요?'
          : '${notes.isEmpty ? '' : '${notes.join('\n')}\n\n'}받을 수 있는 ${topicNote}정책을 ${matches.length}건 찾았어요. '
              '그중 $likely건은 조건이 잘 맞고, 나머지는 직접 확인할 조건이 있어요.\n\n'
              '${lines.join('\n')}\n\n'
              '${tips.isEmpty ? '' : '${tips.join('\n')}\n'}'
              '대상 여부는 정해진 규칙으로 판정했고, 최종 확인은 담당 기관에서 해 주세요.',
      cards: [
        for (final m in overAsked.take(1))
          ChatCard(
            title: m.policy.name,
            subtitle: '${m.policy.regionLabel} · 소득 상한 연 ${manwonLabel(incomeCap(m.policy.eligibility)!)}',
            icon: Icons.volunteer_activism,
            badge: '소득 초과',
            open: () => PolicyDetailScreen(match: m),
            ref: 'policy:${m.policy.id}',
          ),
        for (final m in top.take(overAsked.isEmpty ? 3 : 2)) policyCard(m),
      ],
      sources: const ['청년 결혼 지원 정책 177건 (복지로·온통청년·지자체 공고)'],
      quickReplies: _withSave([
        ...more,
        // 다른 분야 칩은 내 조건으로 실제 결과가 있을 때만, 건수와 함께 (결과가 0건인 칩을 누르면 같은 답만 나오므로)
        ...await _topicChips(exclude: u.topic),
        const QuickReply('공공예식장 추천', text: '공공예식장 추천해줘'),
      ]),
    );
  }

  /// 정책 분야 칩에서 보내는 질문 (질문 이해가 그 분야로 읽는 말)
  static const _topicQuestion = {
    PolicyCategory.cash: '결혼 장려금 정책 알려줘',
    PolicyCategory.housing: '신혼집 주거 지원 정책 알려줘',
    PolicyCategory.wedding: '결혼식 지원 정책 알려줘',
    PolicyCategory.health: '건강검진 지원 정책 알려줘',
  };

  static const _topicChipLabel = {
    PolicyCategory.cash: '장려금',
    PolicyCategory.housing: '주거 지원',
    PolicyCategory.wedding: '예식 지원',
    PolicyCategory.health: '건강검진',
  };

  /// 내 조건으로 결과가 있는 다른 분야만 칩으로 (최대 2개, '주거 지원 3건')
  Future<List<QuickReply>> _topicChips({PolicyCategory? exclude}) async {
    final out = <QuickReply>[];
    for (final t in _topicQuestion.keys) {
      if (t == exclude || out.length >= 2) continue;
      final n = (await ConsultTools.matchPolicies(_known, topic: t)).length;
      if (n > 0) out.add(QuickReply('${_topicChipLabel[t]} $n건', text: _topicQuestion[t]));
    }
    return out;
  }

  /// 물어본 분야의 정책이 내 조건으로 0건일 때: 없다고 말하고, 이유(지역에 없음 / 조건이 안 맞음)와 다른 길을 안내
  Future<ChatMessage> _emptyTopicAnswer(PolicyCategory topic) async {
    final all = await Repos.policy.loadAll();
    final region = _known.regionLabel ?? '전국';
    final sido = _known.sido;
    // 내 지역(시·도) + 전국 사업 중 그 분야가 있는지 → 있으면 '조건이 안 맞음', 없으면 '지역에 없음'
    final inRegion = all
        .where((p) => p.category == topic && (p.sido == '전국' || (sido != null && sidoMatches(p.sido, sido))))
        .length;
    final bySido = <String, int>{};
    for (final p in all.where((p) => p.category == topic && p.sido != '전국')) {
      bySido[p.sido] = (bySido[p.sido] ?? 0) + 1;
    }
    final top = (bySido.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3);
    final where = top.map((e) => '${e.key} ${e.value}건').join('·');
    final others = await ConsultTools.matchPolicies(_known);
    final headline = inRegion == 0 ? '$region에는 ${topic.label} 정책이 없어요' : '조건에 맞는 ${topic.label} 정책이 없어요';
    final sentence = inRegion == 0
        ? '${topic.label}은 지자체마다 달라요${where.isEmpty ? '' : ' (많은 곳: $where)'}.'
        : '$region ${topic.label} $inRegion건은 나이·결혼 단계 등 조건이 맞지 않아요.';
    _funnel = [
      '지원 정책 ${all.length}건',
      '${topic.label} 분야 · ${sido ?? '전국'}·전국 사업 $inRegion건',
      '내 상황(지역·나이 등)으로 판정 · 해당 0건',
    ];
    _lookupNote = '정책 데이터를 정해진 규칙으로 판정 → ${topic.label} 분야 해당 0건 (지역·전국 사업 $inRegion건)';
    _hint = AnswerHint(kind: AnswerKind.policyList, headline: headline, sentence: sentence);
    return ChatMessage(
      fromUser: false,
      basis: [region, _known.ageLabel, _known.stageLabel].join(' · '),
      text: '$headline. $sentence\n\n'
          '${others.isEmpty ? '' : '대신 내 조건으로 받을 수 있는 다른 정책이 ${others.length}건 있어요.'}',
      sources: const ['청년 결혼 지원 정책 177건 (복지로·온통청년·지자체 공고)'],
      quickReplies: _withSave([
        if (others.isNotEmpty) QuickReply('전체 정책 ${others.length}건', text: '받을 수 있는 정책 알려줘'),
        ...await _topicChips(exclude: topic),
      ]),
    );
  }

  /// "12/20에 예약 가능한 예식장": 수집한 예약 현황(달력)이 있으면 그것으로 먼저 확정하고,
  /// 없는 곳은 예식 가능일 원문을 Gemini가 읽고 판단 (실패하면 규칙).
  /// 둘 다 없는 곳은 "정보 없음"으로 나누고, 현황은 수집 시점 기준이라 사이트에서 다시 확인하라고 안내한다.
  Future<ChatMessage> _venueDateAnswer(DateTime date, Understanding u) async {
    final sido = _searchSidoLabel;
    final guests = _known.guests;
    final label = dateLabel(date);
    final pool = await _venuePool(u);
    final all = pool.list;
    final bookings = Repos.booking.cached ?? const <String, BookingStatus>{};
    final booked = {for (final v in all) if (bookingJudge(bookings[v.id], date) case final j?) v.id: j};
    final withText = {
      for (final v in all)
        if (!booked.containsKey(v.id))
          if (dateTextOf(v, date) case final t?) v.id: t,
    };
    // 예약 현황으로 정해진 곳 + 원문에 월 범위·요일·불가일이 분명한 '불가'는 확정하고,
    // 나머지(지정일·협의·문장으로 적힌 조건 등)만 Gemini가 원문을 읽고 판단한다 (이름·주소 없이 id와 원문만)
    final sure = {
      ...booked,
      for (final v in all)
        if (withText.containsKey(v.id) && ruleJudgeDate(v, date).fit == DateFit.impossible) v.id: ruleJudgeDate(v, date),
    };
    final ai = await _llm?.judgeDates(date, {for (final e in withText.entries) if (!sure.containsKey(e.key)) e.key: e.value});
    final judged = <String, DateJudgement>{...sure};
    for (final v in all) {
      if (sure.containsKey(v.id)) continue;
      final g = ai?[v.id];
      judged[v.id] = g != null
          ? DateJudgement(DateFit.values.byName(g.status), g.reason)
          : (withText.containsKey(v.id) ? ruleJudgeDate(v, date) : const DateJudgement(DateFit.unknown, '예식 가능일 정보 없음'));
    }
    // 예약 현황으로 '비어 있음'이 확인된 곳을 먼저
    final possible = all.where((v) => judged[v.id]!.fit == DateFit.possible).toList()
      ..sort((a, b) => (booked.containsKey(a.id) ? 0 : 1).compareTo(booked.containsKey(b.id) ? 0 : 1));
    final impossible = all.where((v) => judged[v.id]!.fit == DateFit.impossible).toList();
    final unclear = all.where((v) => withText.containsKey(v.id) && judged[v.id]!.fit == DateFit.unknown).toList();
    final noInfo = all.where((v) => !withText.containsKey(v.id) && !booked.containsKey(v.id)).toList();
    final bookedOpen = possible.where((v) => booked.containsKey(v.id)).length;
    final bookedClosed = impossible.where((v) => booked.containsKey(v.id)).length;
    final checked = {for (final id in booked.keys) bookings[id]!.checkedLabel}.join(', ');
    _lookupNote = '$sido 공공예식장 ${all.length}곳 중 예약 현황(달력) 있는 곳 ${booked.length}곳 → 비어 있음 $bookedOpen · 불가 $bookedClosed'
        '${booked.isEmpty ? '' : ' ($checked)'} / 나머지 중 예식 가능일 원문 있는 곳 ${withText.length}곳 → '
        '규칙으로 분명한 불가 ${sure.length - booked.length}곳, 나머지 ${withText.length - sure.length + booked.length}곳은 '
        '${ai == null ? '규칙으로 판단(Gemini 없음·실패)' : 'Gemini가 원문을 읽고 판단(${ai.length}곳)'}: 가능 ${possible.length - bookedOpen} · 불가 ${impossible.length - bookedClosed} · '
        '원문만으론 모름 ${unclear.length} / 정보 없음 ${noInfo.length}곳';
    _funnel = [
      ..._funnel,
      '${date.month}/${date.day} 예약 현황·예식 가능일 확인',
      '비어 있음 ${possible.length}곳 · 안 됨 ${impossible.length}곳 · 확인 어려움 ${unclear.length + noInfo.length}곳',
    ];

    ChatCard card(Venue v, String badge) => ChatCard(
          title: v.name,
          subtitle: '${v.region} · ${v.capacityLabel} · ${v.feeLabel}',
          icon: Icons.location_city,
          badge: badge,
          open: () => VenueDetailScreen(venue: v),
          ref: 'venue:${v.id}',
        );
    final shown = possible.isNotEmpty ? possible : [...unclear, ...noInfo];
    final cards = [
      for (final v in possible) card(v, booked.containsKey(v.id) ? '$label 비어 있음' : '$label 가능일'),
      if (possible.isEmpty) ...[
        for (final v in unclear) card(v, '기관 확인 필요'),
        for (final v in noInfo) card(v, '날짜 정보 없음'),
      ],
    ];
    final more = _startMore(cards, '${_placeOr(sido)} $label', tab: 0);
    String names(List<Venue> l) =>
        l.take(3).map((v) => '${v.name}(${judged[v.id]!.reason})').join(', ') + (l.length > 3 ? ' 외 ${l.length - 3}곳' : '');
    final textOpen = possible.length - bookedOpen;
    final lines = <String>[
      if (bookedOpen > 0) '• 예약 달력에서 그날이 비어 있던 곳: $bookedOpen곳 (아래, $checked)',
      if (textOpen > 0) '• 예식 가능일 안내상 그날 예식이 가능한 곳: $textOpen곳 (예약이 찼는지는 모름)',
      if (impossible.isNotEmpty) '• 그날은 안 되는 곳: ${impossible.length}곳 — ${names(impossible)}',
      if (unclear.isNotEmpty) '• 날짜 안내는 있지만 판단이 어려운 곳: ${unclear.length}곳 — ${names(unclear)}',
      if (noInfo.isNotEmpty) '• 예약 현황·예식 가능일 정보가 앱에 없는 곳: ${noInfo.length}곳 → 예약 페이지·문의처에서 확인',
    ];
    _hint = AnswerHint(
      kind: AnswerKind.venueDate,
      sentence: booked.isNotEmpty ? '${{for (final id in booked.keys) '${bookings[id]!.checkedAt.month}/${bookings[id]!.checkedAt.day}'}.join('·')} 달력 기준이라 바뀌었을 수 있어요.' : '이미 찬 날은 예약 페이지에서 확인해 주세요.',
      headline: possible.isEmpty
          ? (withText.isEmpty && booked.isEmpty ? '${_placeOr(sido)} $label 정보 없음' : '${_placeOr(sido)} $label 빈 곳이 없어요')
          : null,
    );
    final hasAny = withText.isNotEmpty || booked.isNotEmpty;
    final head = !hasAny
        ? '$sido 공공예식장 ${all.length}곳은 예약 현황과 예식 가능일 정보가 앱 데이터에 없어서 $label 예약 가능 여부를 알려드릴 수 없어요. '
            '대신 정원·요금 기준으로 고른 곳을 보여드릴게요. 각 예약 페이지나 문의처에서 날짜를 확인해 주세요.'
        : booked.isNotEmpty
            ? '$label을 예약 사이트 달력(수집 시점)과 예식장별 "예식 가능일" 안내로 확인했어요.'
            : '$label에 예식이 가능한지, 앱에 있는 예식장별 "예식 가능일" 안내로 확인했어요.';
    return ChatMessage(
      fromUser: false,
      basis: [sido, if (_known.sigungu != null) _known.sigungu!, label, if (guests != null) '하객 $guests명'].join(' · '),
      text: '${pool.notes.isEmpty ? '' : '${pool.notes.join('\n')}\n'}$head\n\n${hasAny ? '${lines.join('\n')}\n\n' : ''}'
          '${shown.take(3).map((v) => '• ${v.name}${booked.containsKey(v.id) && judged[v.id]!.fit == DateFit.possible ? ' — ${judged[v.id]!.reason}' : ''}\n'
              '   ${v.capacityLabel} · ${v.feeLabel} · ${v.bookingType.label}').join('\n')}\n\n'
          '${booked.isNotEmpty ? '예약 현황은 수집한 날 기준이라 그사이 찼을 수 있어요. 신청 전에 예약 페이지에서 다시 확인해 주세요.' : '이미 다른 예약이 잡혔는지는 앱에서 알 수 없어요. 신청 전에 예약 페이지에서 그 날짜가 비어 있는지 꼭 확인해 주세요.'}',
      cards: cards.take(3).toList(),
      sources: [
        if (booked.isNotEmpty) '예약 현황: ${{for (final id in booked.keys) bookings[id]!.source}.join('·')} 예약 달력 ($checked)',
        '전국 공공예식장 현황 · 예식 가능일: 서울마이웨딩·기관 안내 수집 원문',
      ],
      quickReplies: _withSave([
        ...more,
        const QuickReply('날짜 상관없이 보기', text: '공공예식장 추천해줘'),
      ]),
    );
  }

  static const _kindLabel = {
    AskKind.list: '찾기',
    AskKind.detail: '특정 장소·정책',
    AskKind.compare: '비교',
    AskKind.cost: '비용',
    AskKind.calc: '계산',
    AskKind.general: '일반 지식',
  };
  static const _needLabel = {'parking': '주차', 'reception': '피로연', 'outdoor': '야외'};

  /// 바로 답할 수 있는 계획이면 답을 만드는 함수를 돌려준다 (없으면 기존 흐름: 필요한 정보 되묻기 → 목적별 답변)
  Future<Future<ChatMessage> Function()?> _directAnswer(Understanding u) async {
    // 정책 이름을 그대로 물으면 그 정책 ("더 아름다운 결혼식 알려줘"). 이름 앞부분(괄호 앞) 6자 이상이 질문에 있을 때만.
    // "결혼 장려금 제일 많이 주는 지역"처럼 비교·범위를 묻는 말은 제외
    if ((u.intent == ConsultIntent.help || u.intent == ConsultIntent.policy) &&
        !RegExp(r'제일|가장|어디|지역|받을\s*수|뭐가|무슨').hasMatch(_question)) {
      final q = normName(_question);
      final named = [
        for (final p in await Repos.policy.loadAll())
          if (normName(p.name.split('(').first).length >= 6 && q.contains(normName(p.name.split('(').first))) p,
      ];
      if (named.length == 1 && !RegExp(r'예식장|업체').hasMatch(_question.replaceAll(named.first.name, ''))) {
        return () async => _policyDetailAnswer(named.first);
      }
    }
    // "삼성역 근처 예식장", "역 가까운 곳" → 기준 장소 근처 (장소가 없으면 되묻기, 좌표는 Google 지도)
    final near = RegExp(r'([가-힣A-Za-z0-9]{1,10}역)\s*(근처|주변|부근|에서\s*가까|가까)').firstMatch(_question);
    if (near != null || RegExp(r'역\s*(에서\s*)?(근처|가까|주변)').hasMatch(_question)) {
      final place = near?.group(1);
      final generic = place == null || const ['지하철역', '역', '전철역', '기차역'].contains(place);
      return () => _nearPlaceAnswer(AgentPlan(tool: 'near_place', place: generic ? null : place));
    }
    // "서울에 안 살아도 서울 공공예식장 쓸 수 있어?" → 이용 대상 원문 + 지원 정책 거주 조건
    // "경기도 사는데 서울시 지원 받을 수 있어?" → 사는 곳이 아닌 다른 시도의 거주 조건
    final other = _otherRegionAsk;
    final residencySido = other ?? u.facts.sido ?? _known.sido;
    if (residencySido != null && (_isResidencyQuestion || other != null)) return () => _residencyAnswer(residencySido);
    // "국립공원 숲 결혼식" → 국립공원 예식장 데이터(전국)와 공통 지원 사업 안내
    if (_question.contains('국립공원')) return () => _parkAnswer();
    // "결혼 장려금 제일 많이 주는 지역" → 전국 현금 지원 정책을 원문 최대 금액 순으로 (대출 제외)
    if (RegExp(r'장려금|축하금|지원금|현금').hasMatch(_question) &&
        RegExp(r'제일|가장|많이|최대').hasMatch(_question) &&
        RegExp(r'지역|어디|어느|시도|지자체').hasMatch(_question)) {
      return () => _cashRegionAnswer();
    }
    // 기간 질문("내년 봄 토요일", "내년 3월", "다음 달") → 그 기간의 날짜 전부를 예약 현황·예식 가능일로 확인.
    // 하루짜리 날짜(12/20)는 _venueDateAnswer가 맡는다
    _period = _askDate == null ? periodDates(_question) : null;
    final season = _period;
    if (season != null) {
      final venueAsk = u.intent == ConsultIntent.venue || _question.contains('예식장') || _asksOpenings;
      // 예식장 이름이 있으면 그곳의 그 기간 빈 날
      final one = venueAsk ? findVenuesByName(await Repos.venue.loadAll(), _question, names: u.names) : const <Venue>[];
      if (one.length == 1) return () async => _venueDetailAnswer(one.first, u);
      if (venueAsk && _known.sido != null) return () => _venueSeasonAnswer(u, season.dates, season.label);
    }
    // "2027년 4월 10일 결혼이면 며칠 남았어?" → 날짜 차이는 앱이 달력으로 센다 (날짜 숫자로 빼기 식을 만들지 않음)
    if (_askDate != null && RegExp(r'며칠|몇\s*일|디데이|d-?day', caseSensitive: false).hasMatch(_question)) {
      if (RegExp(r'결혼|예식|식\s*올').hasMatch(_question) && _askDate!.isAfter(DateTime.now())) {
        _known = _known.merge(UserProfile(weddingDate: _askDate));
        _noteSelf(UserProfile(weddingDate: _askDate));
        return () async => _scheduleAnswer();
      }
      return () async => _daysUntilAnswer(_askDate!);
    }
    // 질문에 날짜가 있으면 그 숫자로 계산식을 만들지 않는다
    final expr = _askDate != null ? null : (u.calc ?? (u.kind == AskKind.calc ? ruleCalc(_question) : null));
    if (expr != null && evalExpr(expr) != null) return () async => _calcAnswer(expr);
    // 질문에 예식장 이름이 나오면 그 예식장 (둘 이상이면 비교)
    final mayName = u.intent == ConsultIntent.venue || u.intent == ConsultIntent.help || u.names.isNotEmpty ||
        u.kind == AskKind.detail || u.kind == AskKind.compare;
    final named = mayName ? findVenuesByName(await Repos.venue.loadAll(), _question, names: u.names) : const <Venue>[];
    if (named.length >= 2 && (u.kind == AskKind.compare || u.kind == AskKind.detail || u.kind == AskKind.list)) {
      return () => _compareAnswer(named.take(3).toList(), u);
    }
    if (named.length == 1 && u.kind != AskKind.general) return () async => _venueDetailAnswer(named.first, u);
    if (named.isEmpty && u.names.isEmpty && _noReferent) {
      return () async {
        _lookupNote = '"거기"가 가리킬 이전 답변이 없어 되물음';
        return const ChatMessage(
          fromUser: false,
          text: '어느 곳을 말씀하시는 걸까요? 예식장이나 업체 이름을 알려 주시거나, 먼저 추천을 받아 보세요.',
          quickReplies: [
            QuickReply('공공예식장 추천', text: '공공예식장 추천해줘'),
            QuickReply('받을 수 있는 정책', text: '받을 수 있는 정책 알려줘'),
          ],
        );
      };
    }
    // "만 34세인데 청년 정책 해당돼?" → 일반 지식이 아니라 그 나이로 정책 판정 (아래 목적별 답변으로)
    final policyByAge = u.intent == ConsultIntent.policy && RegExp(r'\d{2}\s*(세|살)').hasMatch(_question);
    // "청첩장 몇 장 뽑아야 해?" → 수량은 업체 목록이 아니라 일반 안내
    // ('몇 명'은 예식장 정원 질문일 수 있어 뺀다)
    final howMany = RegExp(r'몇\s*(장|개|벌|부)').hasMatch(_question) &&
        (u.intent == ConsultIntent.vendor || u.intent == ConsultIntent.help || u.intent == ConsultIntent.recommend);
    if (howMany && _llm != null) return () => _generalAnswer(u);
    // "2027년 4월 10일 결혼이면 며칠 남았어?" → 일반 지식이 아니라 그 날짜 기준 준비 일정
    final scheduleByDate = u.intent == ConsultIntent.schedule && _askDate != null;
    if (u.kind == AskKind.general && _llm != null && !policyByAge && !scheduleByDate) return () => _generalAnswer(u);
    // "스드메 정찰제가 뭐야?", "계약 전에 물어봐야 할 거" → 뜻·조언 질문은 가격표가 아니라 일반 안내
    final askingMeaning = RegExp(r'(이|가)?\s*뭐야\??$|뭔가요|무슨\s*뜻|란\s*(뭐|무엇)|물어봐야|확인해야\s*할|주의할|조심할|팁').hasMatch(_question.trim()) &&
        !RegExp(r'얼마|가격|비용|예산|싼|저렴|만원|원').hasMatch(_question) &&
        // "예약 가능한 예식장은 뭐야?"처럼 장소·날짜·정책을 찾는 말은 제외
        !RegExp(r'예식장|식장|업체|정책|곳|추천|어디|가능한|되는').hasMatch(_question) &&
        _askDate == null && _period == null;
    if (askingMeaning && _llm != null) return () => _generalAnswer(u);
    if (u.kind == AskKind.cost) return () => _costAnswer(u);
    if (u.items.length > 1 && _known.sido != null) return () => _bundleAnswer(u);
    if (u.intent == ConsultIntent.policy && u.kind != AskKind.general) {
      final hit = await _policyHits(u);
      if (hit.length == 1) return () async => _policyDetailAnswer(hit.first);
    }
    return null;
  }

  /// "거기 어때?"인데 가리킬 이전 답변 목록이 없음
  bool get _noReferent =>
      _turnCards.every((c) => c.isEmpty) && RegExp(r'^(거기|그거|그곳|저기|여기)').hasMatch(_question.trim());

  bool get _isResidencyQuestion =>
      RegExp(r'안\s*살|살지\s*않|거주하지\s*않|거주\s*안|타\s*지역|다른\s*지역\s*(사람|주민)|외지|주민이\s*아니|주소.{0,4}(달라|다르|없)')
          .hasMatch(_question) &&
      RegExp(r'예식장|식장|쓸 수|이용|신청|지원').hasMatch(_question);

  /// 거주 조건: 예식장 이용 대상 원문(전체·개인 / 관내자·주민 우선 등) + 그 시도 예식 지원 정책의 거주 조건 원문
  Future<ChatMessage> _residencyAnswer(String sido) async {
    final all = await ConsultTools.searchVenues(sido: sido, guests: null);
    final local = RegExp(r'관내|주민|임직원|시민\s*우선|구민|도민|시민만');
    bool restricted(Venue v) =>
        local.hasMatch('${v.target ?? ''} ${v.extraInfo ?? ''} ${v.reservationInfo ?? ''} ${v.selection ?? ''}');
    final rs = all.where(restricted).toList();
    final open = all.where((v) => !restricted(v) && v.target != null).length;
    final unknown = all.length - rs.length - open;
    final policies = (await Repos.policy.loadAll())
        .where((p) => p.sido == sido && p.category == PolicyCategory.wedding && RegExp(r'거주|주민|주소').hasMatch(p.eligibility))
        .toList();
    _lookupNote = '$sido 공공예식장 ${all.length}곳의 이용 대상·안내 원문(관내·주민·임직원 우선 등) + $sido 예식 지원 정책 ${policies.length}건의 거주 조건 원문';
    _hint = AnswerHint(
      kind: AnswerKind.other,
      headline: policies.isEmpty ? '$sido 예식장은 대부분 누구나 써요' : '예식장 이용과 지원금 조건은 달라요',
      headBadges: [
        BlockBadge('제한 없음 $open곳', Tone.good),
        if (rs.isNotEmpty) BlockBadge('주민 우선 ${rs.length}곳', Tone.no),
      ],
      sentence: policies.isEmpty ? '이용 대상 정보가 없는 곳은 기관에 확인해 주세요.' : '지원금·비품 지원은 $sido 거주 조건이 있어요.',
    );
    return ChatMessage(
      fromUser: false,
      basis: '$sido 공공예식장 이용 대상 · 예식 지원 정책 거주 조건',
      text: '$sido에 살지 않아도 되는지 앱 데이터의 이용 대상·안내 원문으로 확인했어요.\n'
          '• 이용 대상이 "전체·개인" 등으로 적혀 있고 거주 제한 문구가 없는 곳: $open곳\n'
          '• 주민·관내자·임직원 우선이나 한정이라고 적힌 곳: ${rs.length}곳'
          '${rs.isEmpty ? '' : ' (${rs.take(3).map((v) => v.name).join(', ')}${rs.length > 3 ? ' 외' : ''})'}\n'
          '• 이용 대상 정보가 없는 곳: $unknown곳 → 기관에 확인해 주세요\n'
          '${policies.isEmpty ? '' : '\n다만 지원금·비품 지원은 거주 조건이 있어요.\n${policies.take(2).map((p) => '• ${p.name}: ${snippetAround(p.eligibility, RegExp(r'거주|주민|주소')) ?? ''}').join('\n')}\n'}'
          '\n예식장 이용 가능 여부와 지원금 대상은 따로예요. 최종 확인은 각 기관에서 해 주세요.',
      cards: [
        for (final p in policies.take(2))
          ChatCard(
            title: p.name,
            subtitle: '${p.regionLabel} · ${p.category.label}',
            icon: Icons.volunteer_activism,
            badge: '거주 조건',
            open: () => PolicyDetailScreen(match: PolicyMatch(p, MatchLevel.check, const [], const [])),
            ref: 'policy:${p.id}',
          ),
        for (final v in rs.take(1)) _venueCard(v, badge: '주민 우선·한정'),
      ],
      sources: const ['전국 공공예식장 현황 (이용 대상·안내 원문)', '청년 결혼 지원 정책 177건'],
      quickReplies: [QuickReply('$sido 예식장 보기', text: '$sido 공공예식장 추천해줘')],
    );
  }

  /// 오늘부터 그 날짜까지 남은 날 (달력 날짜끼리 비교)
  ChatMessage _daysUntilAnswer(DateTime date) {
    final now = DateTime.now();
    final days = DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    _lookupNote = '오늘(${formatDate(now)})부터 ${formatDate(date)}까지 달력 날짜로 계산';
    _hint = AnswerHint(
      kind: AnswerKind.calc,
      headline: days >= 0 ? '$days일 남았어요' : '${-days}일 지났어요',
      headBadges: [BlockBadge(days >= 0 ? 'D-$days' : 'D+${-days}', Tone.info)],
      sentence: '오늘부터 ${dateLabel(date)}까지 달력으로 셌어요.',
    );
    return ChatMessage(
      fromUser: false,
      basis: '${formatDate(date)} 기준',
      text: days >= 0 ? '${dateLabel(date)}까지 $days일 남았어요.' : '${dateLabel(date)}은 ${-days}일 지났어요.',
    );
  }

  /// "경기도 사는데 서울시 지원…": 사는 곳 말고 질문에 나온 다른 시도 (없으면 null)
  String? get _otherRegionAsk {
    final q = _question;
    final live = RegExp(r'(사는데|살고\s*있는데|살아요|살아서|거주하는데|거주\s*중)').firstMatch(q);
    if (live == null) return null;
    final hits = [
      for (final s in kSidoList)
        if (q.indexOf(s) >= 0) (s, q.indexOf(s)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final before = hits.where((h) => h.$2 < live.start).toList();
    final after = hits.where((h) => h.$2 > live.start).toList();
    if (before.isEmpty || after.isEmpty) return null;
    return after.first.$1 == before.last.$1 ? null : after.first.$1;
  }

  /// 국립공원 숲 결혼식: 국립공원공단 예약 시스템을 쓰는 예식장(전국) + 공통 지원 사업 원문
  Future<ChatMessage> _parkAnswer() async {
    final all = await Repos.venue.loadAll();
    final parks = all
        .where((v) => '${v.bookingUrl} ${v.detailUrl} ${v.programInfo ?? ''} ${v.name}'.contains(RegExp(r'knps|국립공원')))
        .toList();
    final info = parks.map((v) => v.programInfo).whereType<String>().firstOrNull;
    final steps = parks.map((v) => v.bookingSteps).where((s) => s.isNotEmpty).firstOrNull;
    _lookupNote = '공공예식장 데이터에서 국립공원(국립공원공단 예약) 예식장 ${parks.length}곳 + 공통 지원 사업 안내 원문';
    final stepItems = steps == null
        ? const <String>[]
        : [
            for (final x in steps.split(RegExp(r'\s*(?:→|->|>|\d+\.\s)\s*')))
              if (x.trim().length >= 2) x.trim().length > 18 ? '${x.trim().substring(0, 17)}…' : x.trim(),
          ].take(4).toList();
    _hint = AnswerHint(
      kind: AnswerKind.other,
      headline: parks.isEmpty ? '국립공원 예식장 정보가 없어요' : '국립공원 예식장 ${parks.length}곳',
      sentence: '국립공원공단 예약 페이지에서 신청해요.',
      steps: stepItems,
    );
    String cut(String t, [int n = 220]) => t.length > n ? '${t.substring(0, n)}…' : t;
    return ChatMessage(
      fromUser: false,
      basis: '국립공원 예식장 ${parks.length}곳',
      text: parks.isEmpty
          ? '앱 데이터에 국립공원 예식장이 없어요. 국립공원공단 예약 누리집에서 확인해 주세요.'
          : '앱에 있는 국립공원 예식장은 ${parks.length}곳이에요 (${parks.map((v) => v.sido).toSet().join('·')}).\n'
              '${info != null ? '\n사업 안내(원문): ${cut(info)}\n' : ''}'
              '${steps != null ? '\n신청 방법: ${cut(steps, 160)}\n' : ''}'
              '\n${parks.take(3).map((v) => '• ${v.name} (${v.region}) · ${v.capacityLabel} · ${v.feeLabel}').join('\n')}'
              '${parks.length > 3 ? '\n외 ${parks.length - 3}곳은 예식장 탭에서 볼 수 있어요.' : ''}\n\n'
              '공원마다 예식 가능 기간과 인원이 달라요. 신청 전 국립공원공단 예약 페이지에서 확인해 주세요.',
      cards: [for (final v in parks.take(3)) _venueCard(v, badge: '국립공원')],
      sources: const ['전국 공공예식장 현황 · 국립공원공단 예약 안내 원문'],
    );
  }

  /// 결혼 장려금이 가장 많은 지역: 전국 정책 중 현금성 지원(결혼 장려금 분야)을 원문 최대 금액 순으로.
  /// 대출·이자 지원은 빌리는 한도라 비교에서 뺀다
  Future<ChatMessage> _cashRegionAnswer() async {
    final all = await Repos.policy.loadAll();
    final cash = [
      for (final p in all)
        if (p.category == PolicyCategory.cash && !RegExp(r'대출|이자|융자|보증').hasMatch(p.name))
          if (maxAmount(p.eligibility) case final amt?) (p, amt),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final noAmount = all.where((p) => p.category == PolicyCategory.cash).length - cash.length;
    final mine = _known.sido == null ? null : cash.where((e) => sidoMatches(e.$1.sido, _known.sido) || e.$1.isNational).toList();
    _lookupNote = '전국 결혼 장려금 정책 중 원문에 금액이 적힌 ${cash.length}건을 최대 금액 순으로 (대출·이자 지원 제외, 금액 없는 $noAmount건 제외)';
    _hint = AnswerHint(
      kind: AnswerKind.policyList,
      headline: cash.isEmpty ? '금액이 적힌 장려금이 없어요' : '가장 많은 곳은 ${cash.first.$1.regionLabel}',
      ranking: [for (final (p, amt) in cash.take(3)) '${p.regionLabel} · 최대 ${manwonLabel(amt)}'],
      sentence: '대출·이자 지원은 빼고 받는 돈만 비교했어요.',
    );
    return ChatMessage(
      fromUser: false,
      basis: '전국 결혼 장려금 · 원문 최대 금액 순',
      text: cash.isEmpty
          ? '앱 정책 데이터에 금액이 적힌 결혼 장려금이 없어요.'
          : '결혼 장려금(현금 지원)을 원문에 적힌 최대 금액 순으로 비교했어요. 대출·이자 지원은 빌리는 한도라 뺐어요.\n\n'
              '${cash.take(5).map((e) => '• ${e.$1.regionLabel}: ${e.$1.name} — 원문 최대 ${manwonLabel(e.$2)}').join('\n')}\n'
              '${mine == null ? '' : '\n${_known.sido}에서 받을 수 있는 결혼 장려금: ${mine.isEmpty ? '금액이 적힌 정책이 없어요' : mine.take(2).map((e) => '${e.$1.name}(최대 ${manwonLabel(e.$2)})').join(', ')}\n'}'
              '\n대부분 그 지역에 일정 기간 이상 살아야 받을 수 있어요. 금액이 없는 $noAmount건은 비교에서 뺐어요. 최종 조건은 각 기관에서 확인해 주세요.',
      cards: [
        for (final (p, amt) in cash.take(3))
          ChatCard(
            title: p.name,
            subtitle: '${p.regionLabel} · 원문 최대 ${manwonLabel(amt)}',
            icon: Icons.volunteer_activism,
            badge: '거주 조건 확인',
            open: () => PolicyDetailScreen(match: PolicyMatch(p, MatchLevel.check, const [], const ['거주 요건'])),
            ref: 'policy:${p.id}',
          ),
      ],
      sources: const ['청년 결혼 지원 정책 177건 (원문 최대 금액)'],
    );
  }

  /// 예식장 원문(기타 안내·예약 방법·선별 방법)에서 특정 말이 적힌 곳
  Future<String?> _venueTextNotes(RegExp word) async {
    final all = await Repos.venue.loadAll();
    final hits = [
      for (final v in all)
        if (snippetAround('${v.extraInfo ?? ''} ${v.reservationInfo ?? ''} ${v.selection ?? ''}', word, before: 25, after: 35)
            case final s?)
          '• ${v.name}: $s',
    ];
    if (hits.isEmpty) return null;
    return '앱 데이터(예식장 안내 원문)에 관련 내용이 적힌 곳:\n${hits.take(3).join('\n')}';
  }

  /// 질문 속 단어가 이름에 들어간 정책 (Gemini가 뽑은 이름 + 질문의 세 글자 이상 단어)
  Future<List<Policy>> _policyHits(Understanding u) async {
    const stop = {'공공예식장', '신혼부부', '예비부부', '지원받', '지원금', '받는다던데', '어떻게', '알려줘', '정책', '결혼'};
    final words = {
      for (final n in u.names) if (n.length >= 2) normName(n),
      for (final m in RegExp(r'[가-힣A-Za-z]{3,}').allMatches(_question))
        if (!stop.any((w) => m[0]!.contains(w))) normName(m[0]!),
    };
    if (words.isEmpty) return const [];
    final all = await Repos.policy.loadAll();
    return all.where((p) => p.sido == '전국' || p.sido == _known.sido).where((p) => words.any((w) => normName(p.name).contains(w))).toList();
  }

  /// 기간 질문 → 그 기간의 그 요일 날짜들 (요일 말이 없으면 주말)
  /// "내년 봄 토요일", "내년 3월", "2027년 5월 일요일", "다음 달", "이번 달 주말", "예약 현황"(앞으로 3개월)
  static ({List<DateTime> dates, String label})? periodDates(String q, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final days = q.contains('토요일') || RegExp(r'토\s*(요일)?에').hasMatch(q)
        ? [DateTime.saturday]
        : q.contains('일요일')
            ? [DateTime.sunday]
            : q.contains('평일')
                ? [1, 2, 3, 4, 5]
                : [DateTime.saturday, DateTime.sunday];
    final dayLabel = days.length == 1 ? (days.first == 6 ? '토요일' : '일요일') : (days.length == 2 ? '주말' : '평일');
    List<DateTime> collect(List<(int, int)> yms) => [
          for (final (y, m) in yms)
            for (var d = DateTime(y, m, 1); d.month == m; d = DateTime(d.year, d.month, d.day + 1))
              if (days.contains(d.weekday) && d.isAfter(t0)) d,
        ];
    final nextYear = q.contains('내년');
    final explicitYear = int.tryParse(RegExp(r'(20\d\d)\s*년').firstMatch(q)?[1] ?? '');

    // 계절
    final s = RegExp(r'(봄|여름|가을|겨울)').firstMatch(q)?[1];
    if (s != null) {
      final months = switch (s) { '봄' => [3, 4, 5], '여름' => [6, 7, 8], '가을' => [9, 10, 11], _ => [12, 1, 2] };
      var year = explicitYear ?? (nextYear ? t0.year + 1 : t0.year);
      if (explicitYear == null && !nextYear && months.last < t0.month && s != '겨울') year++;
      final dates = collect([for (final m in months) ((s == '겨울' && m <= 2) ? year + 1 : year, m)]);
      return dates.isEmpty ? null : (dates: dates, label: '$year년 $s(${months.first}~${months.last}월) $dayLabel');
    }
    // 다음 달·이번 달·다다음 달
    final rel = RegExp(r'(다다음|다음|이번)\s*달').firstMatch(q)?[1];
    // "3월", "내년 3월" (날짜까지 있으면 하루짜리 질문이라 여기서 다루지 않음)
    final mon = RegExp(r'(?<![\d.])(\d{1,2})\s*월(?!\s*\d{1,2}\s*일)').firstMatch(q);
    int? y, m;
    if (rel != null) {
      final add = switch (rel) { '다다음' => 2, '다음' => 1, _ => 0 };
      final first = DateTime(t0.year, t0.month + add);
      (y, m) = (first.year, first.month);
    } else if (mon != null && !RegExp(r'\d{1,2}\s*월\s*\d{1,2}\s*일|째\s*주|첫\s*주|마지막\s*주').hasMatch(q)) {
      m = int.parse(mon[1]!);
      if (m < 1 || m > 12) return null;
      y = explicitYear ?? (nextYear ? t0.year + 1 : (m < t0.month ? t0.year + 1 : t0.year));
    }
    if (y != null && m != null) {
      final dates = collect([(y, m)]);
      return dates.isEmpty ? null : (dates: dates, label: '$y년 $m월 $dayLabel');
    }
    // "내년 예약 남아 있어?"처럼 달 없이 내년만 → 내년 1~12월
    if (nextYear) {
      final ny = t0.year + 1;
      final dates = collect([for (var mm = 1; mm <= 12; mm++) (ny, mm)]);
      return dates.isEmpty ? null : (dates: dates, label: '$ny년 $dayLabel');
    }
    // 기간 없이 "예약 현황 / 빈 날짜"만 물으면 앞으로 3개월 주말
    if (RegExp(r'예약\s*현황|빈\s*날|비어\s*있는\s*날').hasMatch(q)) {
      final dates = collect([for (var i = 0; i < 3; i++) (DateTime(t0.year, t0.month + i).year, DateTime(t0.year, t0.month + i).month)]);
      return dates.isEmpty ? null : (dates: dates, label: '앞으로 3개월 $dayLabel');
    }
    return null;
  }

  /// 예약·빈자리를 묻는 말 (기간 질문을 예식장 날짜 답으로 보낼지 판단)
  bool get _asksOpenings => RegExp(r'예약\s*(현황|되|돼|가능|할 수)|비어\s*있|빈\s*(곳|날|자리)|자리\s*(있|남)|남아\s*있').hasMatch(_question);

  /// 계절·요일 질문: 날짜마다 예식 가능일 원문을 규칙으로 확인 → 가능한 날이 있는 곳
  Future<ChatMessage> _venueSeasonAnswer(Understanding u, List<DateTime> dates, String label) async {
    final sido = _searchSidoLabel;
    final pool = await _venuePool(u);
    final bookings = Repos.booking.cached ?? const <String, BookingStatus>{};
    final counts = <Venue, int>{};
    var unknown = 0, none = 0, byBooking = 0;
    for (final v in pool.list) {
      // 날짜마다 예약 현황(달력)이 있으면 그것, 없으면 예식 가능일 원문 규칙
      final fits = dates.map((d) => (bookingJudge(bookings[v.id], d) ?? ruleJudgeDate(v, d)).fit).toList();
      if (dates.any((d) => bookingJudge(bookings[v.id], d) != null)) byBooking++;
      final ok = fits.where((f) => f == DateFit.possible).length;
      if (ok > 0) {
        counts[v] = ok;
      } else if (fits.every((f) => f == DateFit.impossible)) {
        none++;
      } else {
        unknown++;
      }
    }
    final ranked = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    _lookupNote = '$label ${dates.length}일 × $sido 공공예식장 ${pool.list.length}곳: 예약 현황(달력) 있는 $byBooking곳은 날짜별 현황으로, '
        '나머지는 예식 가능일 원문을 규칙(월 범위·요일·불가일)으로 확인';
    _funnel = [..._funnel, '$label ${dates.length}일 확인', '가능한 날이 있는 곳 ${ranked.length}곳'];
    // 제목: 범위 + (들어가면) 짧은 기간 + 건수. "강남구 5월 토요일 가능한 곳 2곳"
    final shortLabel = label.replaceAll(RegExp(r'\(.*?\)'), '').replaceFirst(RegExp(r'^\d{4}년\s*'), '').trim();
    final withPeriod = ranked.isEmpty
        ? '${_placeOr(sido)} $shortLabel 가능한 곳 없음'
        : '${_placeOr(sido)} $shortLabel 가능한 곳 ${ranked.length}곳';
    _hint = AnswerHint(
      kind: AnswerKind.venueList,
      headline: withPeriod.length <= 24
          ? withPeriod
          : (ranked.isEmpty ? '${_placeOr(sido)} 그 기간 가능한 곳 없음' : '${_placeOr(sido)} 가능한 곳 ${ranked.length}곳'),
      sentence: '${label.replaceAll(RegExp(r'\(.*?\)'), '').trim()} 날짜를 확인했어요.',
    );
    final cards = [for (final v in ranked) _venueCard(v, badge: '${counts[v]}/${dates.length}일 가능')];
    final more = _startMore(cards, '${_placeOr(sido)} 가능한 곳', tab: 0);
    return ChatMessage(
      fromUser: false,
      basis: '$sido · $label (${dates.length}일)',
      text: '${pool.notes.isEmpty ? '' : '${pool.notes.join('\n')}\n'}'
          '$label ${dates.length}일을 예식장마다 ${byBooking > 0 ? '예약 달력(수집 시점, $byBooking곳)과 ' : ''}예식 가능일 원문으로 확인했어요.\n'
          '• 그중 하루라도 예식이 가능한 곳: ${ranked.length}곳\n'
          '• 그 기간엔 예식이 없는 곳: $none곳\n'
          '• 원문만으로는 알 수 없는 곳(지정일·협의·정보 없음): $unknown곳\n\n'
          '${ranked.take(3).map((v) => '• ${v.name}: ${dates.length}일 중 ${counts[v]}일 가능 (${v.capacityLabel} · ${v.feeLabel})').join('\n')}\n\n'
          '날짜를 하나 정하면 그날 기준으로 다시 확인해 드려요. '
          '${byBooking > 0 ? '예약 현황은 수집한 날 기준이라 그사이 바뀔 수 있고, 달력이 없는 곳은 이미 찬 날짜를 알 수 없어요.' : '이미 찬 날짜는 앱에서 알 수 없어요.'}',
      cards: cards.take(3).toList(),
      sources: [
        if (byBooking > 0) '예약 현황: 공유누리·서울마이웨딩 예약 달력 (${Repos.booking.collectedAt == null ? '' : '${Repos.booking.collectedAt!.month}/${Repos.booking.collectedAt!.day} 수집'})',
        '전국 공공예식장 현황 · 예식 가능일 원문',
      ],
      quickReplies: [...more, const QuickReply('날짜 골라서 다시 보기', slot: 'weddingDate', action: 'input')],
    );
  }

  /// 짧은 후속 질문("12/20에 되는 곳은?")은 바로 앞 예식장 답변의 조건(무료·제외·주차 등)을 이어받는다
  Understanding _carryVenueConds(Understanding u) {
    final prev = _turns.lastOrNull;
    // 짧은 후속 질문이거나 "그중에 …"로 시작하면 앞 조건을 이어받는다
    if (u.intent != ConsultIntent.venue || prev?.intent != ConsultIntent.venue) return u;
    if (_question.length > 20 && !_question.trim().startsWith('그중')) return u;
    if (u.filter != null || u.exclude.isNotEmpty || u.needs.isNotEmpty || _lastVenueConds == null) return u;
    final c = _lastVenueConds!;
    if (c.filter == null && c.exclude.isEmpty && c.needs.isEmpty) return u;
    _flowNote = '앞 질문의 조건(${[if (c.filter != null) _filterLabel[c.filter], ...c.exclude.map((e) => '$e 제외'), ...c.needs.map((n) => _needLabel[n])].join(', ')})을 이어서 씀';
    return Understanding(
      intent: u.intent, facts: u.facts, topic: u.topic, item: u.item, filter: c.filter, date: u.date,
      unsupported: u.unsupported, kind: u.kind, names: u.names, exclude: c.exclude, needs: c.needs,
      items: u.items, itemBudget: u.itemBudget, calc: u.calc, monthsLeft: u.monthsLeft, also: u.also,
    );
  }

  ({String? filter, List<String> exclude, List<String> needs})? _lastVenueConds;
  ({String sido, String town})? _lastTown; // 바로 앞 예식장 답변이 거른 시·군·구

  /// 이번 질문이 찾는 시·군·구: 질문에 나온 구 중 '말고·빼고'로 뺀 구가 아닌 첫 번째.
  /// 질문에 구가 없고 짧은 후속 질문("그중에 무료만")이면 앞 답변의 구를 이어받는다
  String? _askedTown(Understanding u, String sido) {
    String stem(String x) => x.replaceAll(RegExp(r'(구|시|군)$'), '');
    final excluded = u.exclude.map(stem).toSet();
    final asked = [
      for (final (sd, g) in findSigungus(_question, sido: sido))
        if (sd == sido && !excluded.contains(stem(g))) g,
    ];
    if (asked.isNotEmpty) return asked.first;
    final prev = _lastTown;
    final followUp = _question.trim().startsWith('그중') || _question.trim().length <= 20;
    final prevVenue = _turns.lastOrNull?.intent == ConsultIntent.venue;
    if (prev != null && prev.sido == sido && followUp && prevVenue && u.intent == ConsultIntent.venue &&
        !RegExp(r'전체|다른\s*(구|곳|지역)').hasMatch(_question)) {
      _flowNote = '앞 질문의 지역(${prev.town})을 이어서 씀';
      return prev.town;
    }
    return null;
  }

  /// 예식장 후보 + 조건 적용 (무료·하객 수용·사진·더 싼 곳 / 시군구 제외 / 주차·피로연·야외 원문)
  Future<({List<Venue> list, List<String> notes, List<String> conds})> _venuePool(Understanding u) async {
    final vq = _vq;
    final sidos = vq != null && vq.sidos.isNotEmpty ? vq.sidos : [_known.sido!];
    final sido = sidos.join('·');
    final noGuests = _plan?.args['no_guests'] == true;
    final guests = noGuests ? null : (vq?.guests ?? _known.guests);
    final notes = <String>[];
    final conds = <String>[];
    final funnel = <String>[];
    List<Venue> list;
    String? town;
    var scopeTowns = <String>[];
    var auto = false;
    if (vq != null) {
      // 도구 조건: 시도 여러 개 + 구 여러 개. 질문에 장소가 없으면 내 시·군·구부터 (R9, 넓히기는 칩으로)
      var towns = vq.towns;
      if (towns.isEmpty && _autoTownOk(sidos)) {
        towns = [_known.sigungu!];
        auto = true;
      }
      final one = towns.length == 1 ? towns.first : null;
      list = [
        for (final s in sidos) ...await ConsultTools.searchVenues(sido: s, guests: guests, sigungu: one ?? _known.sigungu),
      ];
      funnel.add('$sido 공공예식장 ${list.length}곳');
      if (towns.isNotEmpty) {
        final inTowns = list.where((v) => towns.contains(v.sigungu)).toList();
        final label = towns.join('·');
        final missingTowns = [for (final t in towns) if (!inTowns.any((v) => v.sigungu == t)) t];
        if (inTowns.isEmpty) {
          notes.add('• $label에는 등록된 공공예식장이 없어서 $sido 전체에서 찾았어요');
          funnel.add('$label 0곳이라 $sido 전체');
        } else {
          // 구마다 번갈아 (강남구 1등 → 송파구 1등 → 강남구 2등 …): 여러 구를 물으면 첫 카드들에 구가 고루 나오게 (7차)
          final byTown = {for (final t in towns) t: [for (final v in inTowns) if (v.sigungu == t) v]};
          final mixed = <Venue>[];
          for (var k = 0; mixed.length < inTowns.length; k++) {
            for (final t in towns) {
              if (k < byTown[t]!.length) mixed.add(byTown[t]![k]);
            }
          }
          inTowns
            ..clear()
            ..addAll(mixed);
          notes.add('• $label${auto ? '(내 지역)부터' : '만'}: $sido ${list.length}곳 → ${inTowns.length}곳'
              '${missingTowns.isEmpty ? '' : ' (${missingTowns.join('·')}에는 등록된 곳이 없어요)'}');
          conds.add('$label만');
          funnel.add('$label${auto ? '(내 지역)' : ''} ${inTowns.length}곳');
          list = inTowns;
          town = label;
          scopeTowns = [for (final t in towns) if (inTowns.any((v) => v.sigungu == t)) t];
        }
      }
      if (vq.maxFee != null) {
        final before = list.length;
        list = list.where((v) => v.rentalFee != null && v.rentalFee! <= vq.maxFee!).toList();
        conds.add('대관료 ${formatManwon(vq.maxFee! ~/ 10000)} 이하');
        funnel.add('대관료 ${formatManwon(vq.maxFee! ~/ 10000)} 이하 ${list.length}곳 (요금 모르는 곳 제외)');
        notes.add('• 대관료 ${formatManwon(vq.maxFee! ~/ 10000)} 이하: $before곳 → ${list.length}곳 (요금 모르는 곳 제외)');
      }
    } else {
      // 예전 경로: 질문에서 찾는 시·군·구 ("송파구만", "강남구 말고 송파구") → 그 구만. 내 정보의 시군구는 먼저 보여 주기만 한다
      town = _askedTown(u, sido);
      if (town == null && _autoTownOk(sidos) && !_isFollowUp) {
        town = _known.sigungu;
        auto = true;
      }
      list = await ConsultTools.searchVenues(sido: sido, guests: guests, sigungu: town ?? _known.sigungu);
      funnel.add('$sido 공공예식장 ${list.length}곳');
      if (town != null) {
        final inTown = list.where((v) => v.sigungu == town).toList();
        if (inTown.isEmpty) {
          notes.add('• $town에는 등록된 공공예식장이 없어서 $sido 전체에서 찾았어요');
          funnel.add('$town 0곳이라 $sido 전체');
        } else {
          notes.add('• $town${auto ? '(내 지역)부터' : '만'}: $sido ${list.length}곳 → ${inTown.length}곳');
          conds.add('$town만');
          funnel.add('$town${auto ? '(내 지역)' : ''} ${inTown.length}곳');
          list = inTown;
          scopeTowns = [town];
        }
      }
    }
    _lastTown = vq == null && town != null && conds.contains('$town만') ? (sido: sido, town: town) : null;
    final total = list.length;
    final filter = u.filter;
    if (filter != null && _filterLabel.containsKey(filter)) {
      list = switch (filter) {
        'free' => list.where((v) => v.isFree).toList(),
        'fits_guests' => guests == null ? list : list.where((v) => v.fits(guests) == true).toList(),
        'has_photo' => list.where((v) => v.images.isNotEmpty).toList(),
        _ => ([...list.where((v) => v.rentalFee != null)]..sort((a, b) => a.rentalFee!.compareTo(b.rentalFee!))),
      };
      conds.add(_filterLabel[filter]!);
      funnel.add('${_filterLabel[filter]} ${list.length}곳');
      notes.add('• ${_filterLabel[filter]}: $total곳 → ${list.length}곳');
    }
    for (final ex in u.exclude) {
      final key = ex.replaceAll(RegExp(r'(구|시|군)$'), '');
      final before = list.length;
      list = list.where((v) => !v.sigungu.startsWith(key)).toList();
      conds.add('$ex 제외');
      funnel.add('$ex 제외 ${list.length}곳');
      notes.add('• $ex 제외: ${before - list.length}곳 뺌');
    }
    for (final need in u.needs) {
      final before = list;
      final (yes, no) = switch (need) {
        'parking' => (
            before.where((v) => VenueFeatures.parking(v).ok == Avail.yes).toList(),
            before.where((v) => VenueFeatures.parking(v).ok == Avail.no).length,
          ),
        'reception' => (
            before.where((v) => VenueFeatures.reception(v).ok == Avail.yes).toList(),
            before.where((v) => VenueFeatures.reception(v).ok == Avail.no).length,
          ),
        _ => (
            before.where((v) => VenueFeatures.outdoor(v).ok == Avail.yes).toList(),
            before.where((v) => VenueFeatures.outdoor(v).ok == Avail.no).length,
          ),
      };
      if (need == 'parking') yes.sort((a, b) => (VenueFeatures.parking(b).spaces ?? 0).compareTo(VenueFeatures.parking(a).spaces ?? 0));
      list = yes;
      conds.add(_needLabel[need]!);
      funnel.add('${_needLabel[need]} 가능 ${yes.length}곳 (원문 기준)');
      notes.add('• ${_needLabel[need]} 가능(원문 기준) ${yes.length}곳 · 불가 $no곳 · 정보 없음 ${before.length - yes.length - no}곳'
          '${need == 'outdoor' ? ' (실내외 칸이 비면 이름의 잔디·공원·마당 등으로 판단)' : ''}${need == 'parking' ? ' → 주차 대수가 많은 순' : ''}');
    }
    if (vq != null && vq.sort == 'fee_low') {
      list = [...list]..sort((a, b) => (a.rentalFee ?? 1 << 30).compareTo(b.rentalFee ?? 1 << 30));
      conds.add('대관료 낮은 순');
      funnel.add('대관료 낮은 순');
    }
    if (vq != null && vq.sort == 'open_days') {
      final b = Repos.booking.cached ?? const <String, BookingStatus>{};
      final now = DateTime.now();
      int open(Venue v) => b[v.id]?.openBetween(now, DateTime(now.year, now.month + 3, now.day)).length ?? -1;
      list = [...list]..sort((x, y) => open(y).compareTo(open(x)));
      conds.add('빈 날 많은 순');
      funnel.add('빈 날 많은 순');
      notes.add('• 앞으로 3개월 예약 현황의 빈 날이 많은 순 (현황 없는 곳은 뒤로)');
    }
    // "제일 큰 곳", "넓은 곳", "많이 들어가는 곳" → 정원 큰 순 (정원 모르는 곳은 뒤로)
    if ((vq != null && vq.sort == 'capacity_high') || vq == null && RegExp(r'(제일|가장)\s*(큰|넓은|많이\s*들어)|큰\s*(곳|데|홀)|넓은\s*(곳|데|홀)|많이\s*들어가').hasMatch(_question)) {
      list = [...list]..sort((a, b) => (b.capacity ?? -1).compareTo(a.capacity ?? -1));
      conds.add('정원 큰 순');
      funnel.add('정원 큰 순');
      notes.add('• 정원(최대 인원)이 큰 순으로 정렬 (정원 모르는 ${list.where((v) => v.capacity == null).length}곳은 뒤로)');
    }
    // 따로 정렬하지 않았으면 앱의 기본 순서 (하객 수용 → 무료 → 기간 제한 아님 → 정원 큰 곳)
    if (!funnel.any((s) => s.endsWith('순')) && filter != 'cheaper') {
      if (guests != null) funnel.add('하객 $guests명 수용 ${list.where((v) => v.fits(guests) == true).length}곳 먼저');
      if (filter != 'free' && list.any((v) => v.isFree)) funnel.add('무료 우선');
    }
    _funnel = funnel;
    _lastVenueConds = (filter: filter, exclude: u.exclude, needs: u.needs);
    // 이번 검색에 실제로 적용된 조건 → 조건 칩·넓히기·K1 검사의 기준
    final sortKey = vq?.sort ?? (conds.contains('정원 큰 순') ? 'capacity_high' : 'default');
    final excl = vq?.excludeTowns.isNotEmpty == true ? vq!.excludeTowns : u.exclude;
    final free = filter == 'free' || (vq?.freeOnly ?? false);
    _lastScope = QueryScope(
      sidos: sidos,
      towns: scopeTowns,
      excludeTowns: excl,
      freeOnly: free,
      maxFee: vq?.maxFee,
      guests: guests,
      date: _askDate,
      periodLabel: _askDate == null ? _period?.label : null,
      needs: u.needs,
      sortLabel: const {'fee_low': '대관료 낮은 순', 'capacity_high': '정원 큰 순', 'open_days': '빈 날 많은 순'}[sortKey],
      autoTown: auto,
    );
    _lastVenueArgs = {
      'sido': sidos,
      if (scopeTowns.isNotEmpty) 'sigungu': scopeTowns,
      if (scopeTowns.isEmpty && (vq?.towns.isEmpty ?? true)) 'whole_sido': true,
      if (excl.isNotEmpty) 'exclude_sigungu': excl,
      if (free) 'free_only': true,
      if (vq?.maxFee != null) 'max_fee_won': vq!.maxFee,
      if (vq?.guests != null) 'guests': vq!.guests,
      if (noGuests) 'no_guests': true,
      if (u.needs.isNotEmpty) 'needs': u.needs,
      if (_askDate != null) 'date': BookingStatus.key(_askDate!),
      if (_askDate == null && vq?.from != null) 'date_from': BookingStatus.key(vq!.from!),
      if (_askDate == null && vq?.to != null) 'date_to': BookingStatus.key(vq!.to!),
      if (_askDate == null && vq != null && vq.weekdays.isNotEmpty)
        'weekdays': [for (final w in vq.weekdays) const {1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu', 5: 'fri', 6: 'sat', 7: 'sun'}[w]],
      if (sortKey != 'default') 'sort': sortKey,
    };
    _lookupNote = '$sido 공공예식장 $total곳${conds.isEmpty ? '' : ' → 조건(${conds.join(', ')}) 적용 ${list.length}곳'} → '
        '${town == null && _known.sigungu != null ? '${_known.sigungu} 먼저 · ' : ''}하객 수용 · 무료 · 예약 가능 순';
    return (list: list, notes: notes, conds: conds);
  }

  /// 질문에 장소가 없으면 내 시·군·구부터 보여 줄지 (R9). 시도·구를 말했거나 '전체'를 원하면 아니다
  bool _autoTownOk(List<String> sidos) {
    final mine = _known.sigungu;
    if (mine == null || sidos.length != 1 || sidos.first != _known.sido) return false;
    if (_plan?.args['whole_sido'] == true) return false;
    if (kSidoList.any(_question.contains) || findSigungus(_question).isNotEmpty) return false;
    if (RegExp(r'전체|전국|다른\s*(구|곳|지역|동네)|어디든|넓혀').hasMatch(_question)) return false;
    return (Repos.venue.cached ?? const <Venue>[]).any((v) => sidoMatches(v.sido, sidos.first) && v.sigungu == mine);
  }

  /// 짧은 후속 질문 ("그중에 무료만", "큰 순으로")
  bool get _isFollowUp {
    final q = _question.trim();
    return q.startsWith('그중') || (q.length <= 20 && _turns.lastOrNull?.intent == ConsultIntent.venue && !RegExp(r'추천|알려|찾아').hasMatch(q));
  }

  /// 예식장 한 곳의 정보 (원문 그대로): 정원·요금·예약·접수 기간·이용 대상·주차·피로연·예식 가능일·기타 안내
  String _venueInfo(Venue v, Understanding u) {
    final p = VenueFeatures.parking(v);
    final r = VenueFeatures.reception(v);
    final asksBooking = RegExp(r'예약|남아|자리|비어|마감|신청').hasMatch(_question);
    String cut(String t, [int n = 90]) => t.length > n ? '${t.substring(0, n)}…' : t;
    // 예약 현황(달력 스냅샷): 날짜를 물었으면 그날, 아니면 앞으로 비어 있는 주말 몇 개
    final b = Repos.booking.cached?[v.id];
    final askJudge = _askDate == null ? null : (bookingJudge(b, _askDate!) ?? ruleJudgeDate(v, _askDate!));
    String? bookingLine;
    final period = _askDate == null ? _period : null;
    if (period != null) {
      // "내년 3월에 자리 있어?" → 그 기간의 날마다 예약 현황(없으면 예식 가능일 원문 규칙)
      final judged = [for (final d in period.dates) (d, bookingJudge(b, d) ?? ruleJudgeDate(v, d))];
      final open = [for (final (d, j) in judged) if (j.fit == DateFit.possible) d];
      final known = judged.where((e) => e.$2.fit != DateFit.unknown).length;
      final via = b != null && period.dates.any((d) => b.covers(d)) ? '예약 현황(${b.checkedLabel})' : '예식 가능일 안내';
      bookingLine = known == 0
          ? '• ${period.label} ${period.dates.length}일: 예약 현황과 예식 가능일 정보가 없어 알 수 없어요'
          : open.isEmpty
              ? '• ${period.label} ${period.dates.length}일: $via 기준 비어 있는 날이 없어요'
              : '• ${period.label} ${period.dates.length}일 중 $via 기준 가능한 날 ${open.length}일 — '
                  '${open.take(5).map(formatDateWithDay).join(', ')}${open.length > 5 ? ' …' : ''}';
    } else if (b != null && _askDate == null && asksBooking) {
      final today = DateTime.now();
      final weekends = b
          .openBetween(today, DateTime(today.year, today.month + 6, today.day))
          .where((d) => d.weekday >= DateTime.saturday)
          .toList();
      bookingLine = weekends.isEmpty
          ? '• 예약 현황(${b.checkedLabel}): 앞으로 6개월 안에 비어 있는 주말이 없어요'
          : '• 예약 현황(${b.checkedLabel}): 앞으로 6개월 비어 있는 주말 ${weekends.length}일 — '
              '${weekends.take(4).map(formatDateWithDay).join(', ')}${weekends.length > 4 ? ' …' : ''}';
    }
    return [
      '${v.name} 정보예요.',
      '• 지역·정원·대관료: ${v.region} · ${v.capacityLabel} · ${v.feeLabel}',
      '• 예약: ${v.bookingType.label}${v.applyPeriod != null ? ' · 접수: ${v.applyPeriod}' : ''}',
      if (v.target != null && v.target != '전체') '• 이용 대상: ${v.target}',
      '• 주차: ${p.text ?? '정보 없음'}',
      '• 피로연: ${r.text ?? '정보 없음'}',
      if (v.availableDates2026 != null) '• 2026 예식 가능일: ${cut(v.availableDates2026!)}',
      if (v.unavailableDates2026 != null) '• 2026 예식 불가일: ${cut(v.unavailableDates2026!)}',
      if (v.availableDates2027 != null) '• 2027 예식 가능일: ${cut(v.availableDates2027!)}',
      if (askJudge != null)
        '• ${dateLabel(_askDate!)}: ${switch (askJudge) {
          DateJudgement(fit: DateFit.possible, :final reason) when bookingJudge(b, _askDate!) != null => '예약 달력에서 비어 있었어요 ($reason)',
          DateJudgement(fit: DateFit.possible, :final reason) => '예식 가능일 조건에 맞아요 ($reason)',
          DateJudgement(fit: DateFit.impossible, :final reason) => '그날은 안 돼요 ($reason)',
          _ => '원문만으로는 알 수 없어요',
        }}',
      ?bookingLine,
      if (v.extraInfo != null) '• 기타 안내: ${cut(v.extraInfo!, 120)}',
      '• 문의: ${v.bookingContact}',
      '',
      b != null && (asksBooking || _askDate != null || period != null)
          ? '예약 현황은 수집한 날 기준이라 그사이 바뀔 수 있어요. 카드를 눌러 달력을 보거나, 신청 전 ${b.source}에서 다시 확인해 주세요.'
          : asksBooking
              ? '이 예식장은 날짜별 예약 현황이 공개되지 않아 이미 찬 날짜는 알 수 없어요. 예약 페이지나 문의처에서 확인해 주세요.'
              : '자세한 신청 방법과 사진은 아래 카드를 눌러 확인하세요.',
    ].join('\n');
  }

  ChatCard _venueCard(Venue v, {String? badge}) => ChatCard(
        title: v.name,
        subtitle: '${v.region} · ${v.capacityLabel} · ${v.feeLabel}',
        icon: Icons.location_city,
        badge: badge,
        open: () => VenueDetailScreen(venue: v),
        ref: 'venue:${v.id}',
      );

  AnswerHint _venueDetailHint(Venue v) {
    final b = Repos.booking.cached?[v.id];
    final today = DateTime.now();
    final weekends = b == null
        ? const <DateTime>[]
        : b.openBetween(today, DateTime(today.year, today.month + 6, today.day)).where((d) => d.weekday >= DateTime.saturday).toList();
    final g = _known.guests;
    final judge = _askDate == null ? null : (bookingJudge(b, _askDate!) ?? ruleJudgeDate(v, _askDate!));
    return AnswerHint(
      kind: AnswerKind.venueDetail,
      headline: v.name.length <= 24 ? v.name : '${v.name.substring(0, 23)}…',
      headBadges: [
        if (v.rentalFee == 0) const BlockBadge('무료', Tone.good),
        if (g != null) switch (v.fits(g)) {
          true => BlockBadge('$g명 OK', Tone.good),
          false => BlockBadge('${v.capacity}명까지', Tone.no),
          null => const BlockBadge('정원 문의 필요', Tone.check),
        },
        if (judge != null)
          BlockBadge('${_askDate!.month}/${_askDate!.day} ${switch (judge.fit) { DateFit.possible => '가능', DateFit.impossible => '안 됨', _ => '확인 필요' }}',
              switch (judge.fit) { DateFit.possible => Tone.good, DateFit.impossible => Tone.no, _ => Tone.check }),
      ].take(2).toList(),
      columns: const [],
      rows: [
        ['예약', '${v.bookingType.label}${v.applyPeriod != null && v.applyPeriod!.length <= 20 ? ' · ${v.applyPeriod}' : ''}'],
        ['주차', VenueFeatures.parking(v).label],
        ['피로연', VenueFeatures.reception(v).label],
        if (b != null) ['빈 주말', weekends.isEmpty ? '6개월 안 없음' : weekends.take(3).map(formatDateWithDay).join(', ')],
        ['문의', v.bookingContact.length > 30 ? '${v.bookingContact.substring(0, 29)}…' : v.bookingContact],
      ],
    );
  }

  ChatMessage _venueDetailAnswer(Venue v, Understanding u) {
    _lookupNote = '질문에 나온 이름으로 공공예식장 데이터에서 "${v.name}" 찾음 → 정원·요금·예약·주차·피로연·예식 가능일 원문';
    _hint = _venueDetailHint(v);
    return ChatMessage(
      fromUser: false,
      basis: v.name,
      text: _venueInfo(v, u),
      cards: [_venueCard(v)],
      sources: const ['전국 공공예식장 현황 · 공유누리·서울마이웨딩·기관 안내 수집 원문'],
      quickReplies: const [
        QuickReply('비슷한 예식장 더 보기', text: '공공예식장 추천해줘'),
        QuickReply('관련 지원 정책', text: '예식 지원 정책 알려줘'),
      ],
    );
  }

  /// 예식장 비교: 같은 항목을 나란히 (앱 데이터 원문). 어디가 나은지는 정하지 않고 차이를 보여 준다
  Future<ChatMessage> _compareAnswer(List<Venue> vs, Understanding u) async {
    final guests = _known.guests;
    _lookupNote = '질문에 나온 이름으로 예식장 ${vs.length}곳 찾음 → 정원·대관료·예약·주차·피로연·예식 가능일 비교';
    String short(Venue v) {
      final n = v.name.split('(').first.trim();
      return n.length > 12 ? '${n.substring(0, 11)}…' : n;
    }
    _hint = AnswerHint(
      kind: AnswerKind.venueCompare,
      headline: '예식장 ${vs.length}곳 비교',
      columns: ['', for (final v in vs) short(v)],
      rows: [
        ['지역', for (final v in vs) v.sigungu.isEmpty ? v.sido : v.sigungu],
        ['정원', for (final v in vs) capShort(v)],
        ['대관료', for (final v in vs) feeShort(v)],
        ['주차', for (final v in vs) VenueFeatures.parking(v).label],
        ['피로연', for (final v in vs) VenueFeatures.reception(v).label],
        if (guests != null) ['하객 $guests명', for (final v in vs) switch (v.fits(guests)) { true => '수용', false => '부족', _ => '정원 미확인' }],
      ],
    );
    String row(String label, String Function(Venue) f) => '• $label: ${vs.map((v) => f(v)).join('  |  ')}';
    final fits = guests == null
        ? null
        : vs.map((v) => '${v.name.split('(').first.trim()} ${switch (v.fits(guests)) { true => '수용', false => '부족', _ => '정원 미확인' }}').join(', ');
    return ChatMessage(
      fromUser: false,
      basis: vs.map((v) => v.name).join(' vs '),
      text: '${vs.map((v) => v.name).join(' / ')} 비교예요 (순서대로).\n'
          '${row('지역', (v) => v.region)}\n'
          '${row('정원', (v) => v.capacityLabel)}\n'
          '${row('대관료', (v) => v.feeLabel)}\n'
          '${row('예약', (v) => v.bookingType.label)}\n'
          '${row('주차', (v) => VenueFeatures.parking(v).label)}\n'
          '${row('피로연', (v) => VenueFeatures.reception(v).label)}\n'
          '${row('야외', (v) => switch (VenueFeatures.outdoor(v)) { (ok: Avail.yes, guessed: final g) => g ? '야외(이름 기준)' : '야외', (ok: Avail.no, guessed: _) => '실내', _ => '정보 없음' })}\n'
          '${fits == null ? '' : '• 하객 $guests명: $fits\n'}\n'
          '어디가 나은지는 하객 수·날짜·식사 방식에 따라 달라요. 위 차이를 보고 고르시고, 각 카드에서 예식 가능일과 사진을 확인해 보세요.',
      cards: [for (final v in vs) _venueCard(v)],
      sources: const ['전국 공공예식장 현황 · 공유누리·서울마이웨딩·기관 안내 수집 원문'],
    );
  }

  ChatMessage _calcAnswer(String expr) {
    final v = evalExpr(expr)!;
    _lookupNote = '질문 속 숫자로 식을 만들고(Gemini/규칙) 앱이 계산: ${exprLabel(expr)}';
    _hint = AnswerHint(kind: AnswerKind.calc, headline: wonLabel(v), sentence: '${exprLabel(expr)} = ${wonLabel(v)}');
    return ChatMessage(
      fromUser: false,
      basis: '계산 ${exprLabel(expr)}',
      text: '${exprLabel(expr)} = ${wonLabel(v)}\n\n'
          '질문에 주신 숫자로 계산한 값이에요. 실제 견적에는 봉사료·부가세·보증 인원 같은 조건이 붙을 수 있어요.',
      quickReplies: const [
        QuickReply('식대 업체 보기', text: '식대 업체 추천해줘'),
        QuickReply('결혼 비용 수준', text: '결혼 비용 보통 얼마 들어?'),
      ],
    );
  }

  /// 앱 데이터가 아닌 일반 지식: Gemini가 일반 안내 + (공공예식장 이야기면) 앱 데이터로 본 사실
  Future<ChatMessage> _generalAnswer(Understanding u) async {
    final text = await _llm!.general(_question);
    if (text == null) {
      // 일반 상식인데 Gemini 답에 근거 없는 숫자가 있거나 응답이 없을 때: 메뉴 대신 이유를 말한다
      _lookupNote = '일반 지식 질문 → Gemini 답이 없거나 근거 없는 숫자가 있어 쓰지 않음';
      return ChatMessage(
        fromUser: false,
        text: '이 질문은 앱 데이터로 정확히 답할 수 없는 일반 상식이에요. '
            '근거 없는 숫자를 드리지 않으려고, 숫자가 필요한 답은 업체나 기관 안내로 확인하시길 권해요.\n\n'
            '앱 데이터로는 예식장·정책·업체 가격(시연용)·준비 일정을 바로 찾아 드릴 수 있어요.',
        quickReplies: const [
          QuickReply('공공예식장 추천', text: '공공예식장 추천해줘'),
          QuickReply('받을 수 있는 정책', text: '받을 수 있는 정책 알려줘'),
          QuickReply('뭐부터 해야 해?', text: '뭐부터 해야 해?'),
        ],
      );
    }
    final facts = u.intent != ConsultIntent.policy && RegExp(r'공공예식장|예식장|식장').hasMatch(_question) && _known.sido != null
        ? await _publicVenueFacts()
        : null;
    // 정책 이야기면 앱 정책 데이터에서 관련 정책을 함께 (지역을 알 때)
    var policies = u.intent == ConsultIntent.policy && _known.sido != null
        ? (await ConsultTools.matchPolicies(_known, topic: u.topic)).take(3).toList()
        : const <PolicyMatch>[];
    // 그 분야 정책이 내 지역에 없으면 (예: 서울엔 결혼 장려금 없음) 받을 수 있는 다른 정책을 보여 주고 그렇게 말한다
    final topicEmpty = policies.isEmpty && u.intent == ConsultIntent.policy && u.topic != null && _known.sido != null;
    if (topicEmpty) policies = (await ConsultTools.matchPolicies(_known)).take(3).toList();
    if (u.intent == ConsultIntent.policy && _known.sido != null) {
      // "비품비 지원" 처럼 정책 이름에 있는 말을 물으면 그 정책을 먼저
      final hits = await _policyHits(u);
      if (hits.isNotEmpty) {
        final judged = PolicyMatcher.judge(await Repos.policy.loadAll(), PolicyProfile.fromUser(_known)).matches;
        final hitMatches = [
          for (final p in hits.take(2))
            judged.where((m) => m.policy.id == p.id).firstOrNull ?? PolicyMatch(p, MatchLevel.check, const [], const []),
        ];
        policies = [...hitMatches, ...policies.where((m) => !hits.any((p) => p.id == m.policy.id))].take(3).toList();
      }
    }
    final dupNotes = RegExp(r'동시|중복|두\s*(군데|곳)|여러\s*(곳|군데)').hasMatch(_question) ? await _venueTextNotes(RegExp(r'중복|동시\s*(신청|접수|예약)')) : null;
    {
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final bullets = [for (final l in lines) if (l.startsWith('•') || l.startsWith('-')) l.replaceFirst(RegExp(r'^[•\-]\s*'), '')];
      final head = lines.where((l) => !l.startsWith('•') && !l.startsWith('-')).firstOrNull;
      String cut(String t, int n) => t.length > n ? '${t.substring(0, n - 1)}…' : t;
      _hint = AnswerHint(
        kind: AnswerKind.general,
        headline: head != null && head.length <= 24 ? head : '일반 안내',
        headBadges: const [BlockBadge('일반 안내 · 앱 데이터 아님', Tone.no)],
        steps: [for (final b in bullets.take(4)) cut(b.split(RegExp(r'[:：]')).first.trim(), 20)],
        sentence: head != null && head.length > 24 ? cut(head, 60) : null,
      );
    }
    final policyHead = topicEmpty
        ? '${u.topic!.label} 분야 정책은 ${_known.sido} 기준으로 앱 데이터에 없어요. 대신 받을 수 있는 정책'
        : '앱 데이터에서 ${_known.sido} 기준으로 찾은 관련 정책';
    _lookupNote = policies.isNotEmpty
        ? 'Gemini 일반 안내 + 정책 데이터 규칙 판정(${topicEmpty ? '${u.topic!.label} 분야 0건 → 전체' : u.topic?.label ?? '전체'} 상위 ${policies.length}건)'
        : facts == null
            ? '앱 데이터로 답할 질문이 아니라 Gemini 일반 안내'
            : 'Gemini 일반 안내 + 공공예식장 데이터로 센 사실';
    return ChatMessage(
      fromUser: false,
      basis: '일반 안내 · 앱 데이터가 아니에요${policies.isEmpty ? '' : ' (아래 정책 카드는 앱 데이터)'}',
      text: '$text${facts == null || dupNotes != null ? '' : '\n\n$facts'}${dupNotes == null ? '' : '\n\n$dupNotes'}'
          '${policies.isEmpty ? '' : '\n\n$policyHead:\n${policies.map((m) => '• ${m.policy.name}').join('\n')}'}',
      aiWritten: true,
      cards: [
        for (final m in policies)
          ChatCard(
            title: m.policy.name,
            subtitle: '${m.policy.regionLabel} · ${m.policy.category.label}',
            icon: Icons.volunteer_activism,
            badge: m.level == MatchLevel.likely ? '해당 가능성 높음' : '조건 확인 필요',
            open: () => PolicyDetailScreen(match: m),
            ref: 'policy:${m.policy.id}',
          ),
      ],
      sources: [
        'Gemini 일반 지식 (앱 데이터 아님)',
        if (facts != null) '전국 공공예식장 현황 (앱 데이터)',
        if (policies.isNotEmpty) '청년 결혼 지원 정책 177건 (앱 데이터)',
      ],
      quickReplies: _starterReplies,
    );
  }

  /// 공공예식장에 대한 걱정(준비 부담·식사·주차·신청 시기)을 앱 데이터로 센 것
  Future<String> _publicVenueFacts() async {
    final sido = _known.sido!;
    final all = await ConsultTools.searchVenues(sido: sido, guests: null);
    int n(bool Function(Venue) f) => all.where(f).length;
    return '앱 데이터로 본 $sido 공공예식장 ${all.length}곳:\n'
        '• 대관료 무료 ${n((v) => v.isFree)}곳\n'
        '• 장소만 빌려주고 장식·음향 등은 직접 준비라고 적힌 곳 ${n((v) => RegExp(r'미제공|당사자가 준비|직접 준비|장소만').hasMatch(v.extraInfo ?? ''))}곳\n'
        '• 피로연 가능 ${n((v) => VenueFeatures.reception(v).ok == Avail.yes)}곳 · 불가 ${n((v) => VenueFeatures.reception(v).ok == Avail.no)}곳\n'
        '• 주차 가능 ${n((v) => VenueFeatures.parking(v).ok == Avail.yes)}곳 · 불가 ${n((v) => VenueFeatures.parking(v).ok == Avail.no)}곳\n'
        '• 접수 기간 안내가 있는 곳 ${n((v) => v.applyPeriod != null && v.applyPeriod != '전화문의')}곳';
  }

  /// 비용 수준: 업체_요소 단가표(공공·실속 / 일반 평균 + 자주 붙는 추가금)
  Future<ChatMessage> _costAnswer(Understanding u) async {
    final opts = await Repos.vendor.options();
    final guests = _known.guests ?? _app.plan.guests;
    final q = normName(_question);
    const stop = {'기준', '하객', '본식', '양가', '예식', '공간', '전문', '기획', '종이', '모바일', '데이터', '렌탈', '집기'};
    VendorCategory? cat(WeddingOption o) => VendorCategory.values.where((c) => c.name == o.id).firstOrNull;
    bool asked(WeddingOption o) =>
        u.items.contains(cat(o)) ||
        (u.item != null && cat(o) == u.item) ||
        o.label.split(RegExp(r'[\s·()/,]+')).where((w) => w.length >= 2 && !stop.contains(w)).any((w) => q.contains(normName(w)));
    final totalMode = RegExp(r'총|전체|다 합|웨딩홀보다|일반.*비교|결혼.*(가능|얼마)|진짜 싸').hasMatch(_question) || u.facts.budget != null;
    final picked = totalMode ? <WeddingOption>[] : opts.where(asked).toList();
    final src = '업체_요소 단가표 (서울시 더아결 표준가격표·한국소비자원 참가격 등 정리, 참고 금액)';
    if (picked.isNotEmpty) {
      _lookupNote = '업체_요소 단가표에서 ${picked.map((o) => o.label).join('·')} 항목 (하객 $guests명 기준)';
      String line(WeddingOption o) {
        final general = o.averagePrice == 0 ? '일반 웨딩홀은 보통 포함' : '일반 평균 ${(o.averagePrice * (o.perGuest ? guests / 100 : 1)).round()}만원';
        return '• ${o.label}: 공공·실속 ${o.publicCost(guests)}만원 / $general'
            '${o.hiddenExtra > 0 ? ' + 자주 붙는 추가금 ${(o.hiddenExtra * (o.perGuest ? guests / 100 : 1)).round()}만원' : ''}'
            '${o.extraDetail.isEmpty ? '' : '\n   ${o.extraDetail}'}'
            '${o.support.isEmpty ? '' : '\n   절약: ${o.support}'}';
      }

      final pub = picked.fold<int>(0, (a, o) => a + o.publicCost(guests));
      final gen = picked.fold<int>(0, (a, o) => a + o.generalCost(guests));
      final cap = u.itemBudget;
      String avg(WeddingOption o) => o.averagePrice == 0 ? '보통 포함' : '${(o.averagePrice * (o.perGuest ? guests / 100 : 1)).round()}만원';
      String add(WeddingOption o) => o.hiddenExtra > 0 ? '${(o.hiddenExtra * (o.perGuest ? guests / 100 : 1)).round()}만원' : '-';
      _hint = AnswerHint(
        kind: AnswerKind.cost,
        headline: '공공·실속 약 $pub만원',
        headBadges: [
          BlockBadge('일반 약 $gen만원', Tone.info),
          if (cap != null) BlockBadge(cap >= pub ? '$cap만원이면 가능' : '${pub - cap}만원 부족', cap >= pub ? Tone.good : Tone.no),
        ],
        columns: const ['', '공공·실속', '일반 평균', '추가금'],
        rows: [for (final o in picked.take(5)) [o.label.split(' (').first, '${o.publicCost(guests)}만원', avg(o), add(o)]],
        sentence: '하객 $guests명 기준 참고 금액이에요.',
      );
      return ChatMessage(
        fromUser: false,
        basis: '하객 $guests명 · 업체_요소 단가표',
        text: '${picked.map(line).join('\n')}\n'
            '${picked.length > 1 ? '\n• 합계: 공공·실속 $pub만원 / 일반(추가금 포함) $gen만원\n' : ''}'
            '${cap == null ? '' : '• 말씀하신 $cap만원이면 공공·실속 기준 ${cap >= pub ? '가능한 수준' : '${pub - cap}만원 부족'}, 일반 기준 ${cap >= gen ? '가능한 수준' : '${gen - cap}만원 부족'}이에요.\n'}'
            '\n참고 금액이고 실제 견적은 업체·지역·날짜마다 달라요. 계약 전에 추가금 항목표를 꼭 받아 두세요.',
        sources: [src],
        quickReplies: [
          for (final o in picked.take(2))
            if (cat(o) != null) QuickReply('${o.label.split(' ').first} 업체 보기', text: '${cat(o)!.label} 추천해줘'),
          const QuickReply('체크리스트에서 금액 정하기', action: 'open_checklist'),
        ],
      );
    }
    final base = opts.where((o) => o.defaultOn).toList();
    final pub = base.fold<int>(0, (a, o) => a + o.publicCost(guests));
    final gen = base.fold<int>(0, (a, o) => a + o.generalCost(guests));
    final big = [...base]..sort((a, b) => b.publicCost(guests).compareTo(a.publicCost(guests)));
    final budget = u.facts.budget ?? (_question.contains('예산') ? _known.budget : null);
    _hint = AnswerHint(
      kind: AnswerKind.cost,
      headline: '공공·실속 약 $pub만원',
      headBadges: [
        BlockBadge('일반 약 $gen만원', Tone.info),
        if (budget != null) BlockBadge(budget >= pub ? '예산 안' : '${pub - budget}만원 부족', budget >= pub ? Tone.good : Tone.no),
      ],
      budgetRows: [for (final o in big.take(5)) [o.label.split(' (').first, '${o.publicCost(guests)}만원']],
      budgetTotal: '기본 ${base.length}개 합계 약 $pub만원 (하객 $guests명)',
      sentence: '대관료가 무료여도 식대·장식비는 따로 들어요.',
    );
    _lookupNote = '업체_요소 단가표의 기본 항목 ${base.length}개 합산 (하객 $guests명 기준: 공공·실속 vs 일반 평균+추가금)';
    return ChatMessage(
      fromUser: false,
      basis: '하객 $guests명 · 기본 항목 ${base.length}개 · 업체_요소 단가표',
      text: '하객 $guests명 기준, 기본 항목 ${base.length}개를 더한 참고 금액이에요.\n'
          '• 공공예식장·실속으로 준비하면: 약 $pub만원\n'
          '• 일반 웨딩홀(평균가 + 자주 붙는 추가금): 약 $gen만원\n'
          '${budget == null ? '' : '• 총예산 $budget만원이면 공공·실속 기준 ${budget >= pub ? '${budget - pub}만원 남는 수준' : '${pub - budget}만원 부족'}, 일반 기준 ${budget >= gen ? '${budget - gen}만원 남는 수준' : '${gen - budget}만원 부족'}이에요.\n'}'
          '\n공공예식장에서 금액이 큰 항목:\n'
          '${big.take(5).map((o) => '• ${o.label} ${o.publicCost(guests)}만원${o.averagePrice == 0 ? ' (일반 웨딩홀은 보통 포함, 공공예식장은 따로 준비)' : ''}').join('\n')}\n\n'
          '대관료가 무료여도 식대·꽃장식·음향·진행비가 따로 들어요. 참고 금액이고 실제 견적은 업체·지역·날짜마다 달라요.',
      sources: [src],
      quickReplies: const [
        QuickReply('무료 공공예식장', text: '대관료 무료 예식장 알려줘'),
        QuickReply('체크리스트에서 금액 정하기', action: 'open_checklist'),
      ],
    );
  }

  /// 묶음(스드메 등) + 항목 예산: 항목마다 가장 저렴한 시연 업체를 골라 합계를 예산과 비교
  Future<ChatMessage> _bundleAnswer(Understanding u) async {
    final sido = _known.sido!;
    final guests = _known.guests ?? _app.plan.guests;
    final all = await Repos.vendor.demoVendors();
    final picks = <DemoVendor>[];
    for (final item in u.items) {
      final list = all.where((v) => v.sido == sido && v.category == item).toList()
        ..sort((a, b) => a.estimate(guests: guests).compareTo(b.estimate(guests: guests)));
      if (list.isNotEmpty) picks.add(list.first);
    }
    final sum = picks.fold<int>(0, (a, v) => a + v.estimate(guests: guests));
    final cap = u.itemBudget;
    _hint = AnswerHint(
      kind: AnswerKind.vendorList,
      headline: '최저가로 고르면 약 $sum만원',
      headBadges: [if (cap != null) BlockBadge(sum <= cap ? '$cap만원 안' : '${sum - cap}만원 초과', sum <= cap ? Tone.good : Tone.no)],
      sentence: '[시연] 업체는 가격 비교용 가상 업체예요.',
    );
    _lookupNote = '$sido 시연용 업체에서 ${u.items.map((i) => i.label).join('·')} 항목마다 가장 저렴한 곳 → 합계 $sum만원'
        '${cap == null ? '' : ' vs 말씀하신 $cap만원'}';
    return ChatMessage(
      fromUser: false,
      basis: '$sido · ${u.items.map((i) => i.label).join('·')}${cap == null ? '' : ' · $cap만원 안'}',
      text: '${u.items.map((i) => i.label).join('·')}를 $sido에서 가장 저렴하게 고르면 합계 약 $sum만원이에요.\n'
          '${picks.map((v) => '• ${v.category.label}: ${v.name.replaceFirst('[시연] ', '')} — ${v.priceText} (예상 ${v.estimate(guests: guests)}만원)').join('\n')}\n'
          '${cap == null ? '' : '\n말씀하신 $cap만원 ${sum <= cap ? '안에 들어와요 (${cap - sum}만원 여유).' : '보다 ${sum - cap}만원 많아요. 추가 옵션을 빼거나 항목을 줄여야 해요.'}\n'}'
          '\n(가격은 시연용 가상 데이터예요. 추가 옵션을 고르면 금액이 늘어나요)',
      cards: [
        for (final v in picks)
          ChatCard(
            title: v.name,
            subtitle: '${v.category.label} · ${v.priceText}',
            icon: v.category.icon,
            badge: '최저가',
            open: () => DemoVendorDetailScreen(vendor: v),
            ref: 'vendor:${v.id}',
          ),
      ],
      sources: const ['시연용 가상 업체 데이터'],
      quickReplies: [
        for (final i in u.items.take(3)) QuickReply('${i.label} 더 보기', text: '${i.label} 추천해줘'),
      ],
    );
  }

  ChatMessage _policyDetailAnswer(Policy p) {
    _lookupNote = '질문에 나온 이름으로 정책 데이터에서 "${p.name}" 찾음';
    return ChatMessage(
      fromUser: false,
      basis: p.name,
      text: '${p.name} (${p.regionLabel} · ${p.category.label})\n'
          '• 지원 자격(원문): ${p.eligibility.length > 200 ? '${p.eligibility.substring(0, 200)}…' : p.eligibility}\n\n'
          '신청 방법과 링크는 아래 카드에서 볼 수 있어요. 최종 대상 여부는 담당 기관에서 확인해 주세요.',
      cards: [
        ChatCard(
          title: p.name,
          subtitle: '${p.regionLabel} · ${p.category.label}',
          icon: Icons.volunteer_activism,
          open: () => PolicyDetailScreen(match: PolicyMatch(p, MatchLevel.check, const [], const [])),
          ref: 'policy:${p.id}',
        ),
      ],
      sources: const ['청년 결혼 지원 정책 177건 (복지로·온통청년·지자체 공고)'],
    );
  }

  /// 목적 두 개를 함께 물으면("예식장이랑 정책 같이") 두 번째 답을 이어 붙인다
  Future<ChatMessage> _withAlso(Understanding u, ChatMessage first) async {
    final second = Understanding(intent: u.also!, facts: u.facts, topic: u.topic, item: u.item);
    final missing = _missing(second);
    if (missing.isNotEmpty) {
      return ChatMessage(
        fromUser: false,
        basis: first.basis,
        text: '${first.text}\n\n함께 물어보신 ${_intentLabel[u.also]}은(는) ${missing.map((s) => _slotLabel[s]).join(', ')} 정보가 있어야 찾을 수 있어요.',
        cards: first.cards,
        sources: first.sources,
        quickReplies: [...first.quickReplies, QuickReply('${_intentLabel[u.also]} 보기', text: '${_intentLabel[u.also]} 알려줘')],
      );
    }
    final m2 = await _answer(second);
    return ChatMessage(
      fromUser: false,
      basis: first.basis,
      text: '${first.text}\n\n[${_intentLabel[u.also]}]\n${m2.text}',
      cards: [...first.cards, ...m2.cards],
      sources: {...first.sources, ...m2.sources}.toList(),
      quickReplies: [
        ...m2.quickReplies.where((r) => r.action == 'more'),
        ...first.quickReplies.where((r) => r.action != 'more'),
      ],
    );
  }

  static const _filterLabel = {
    'free': '대관료 무료인 곳',
    'fits_guests': '하객이 다 들어가는 곳',
    'has_photo': '사진이 있는 곳',
    'cheaper': '대관료가 낮은 곳',
  };

  Future<ChatMessage> _venueAnswer(Understanding u) async {
    final sido = _searchSidoLabel;
    final guests = _known.guests;
    final pool = await _venuePool(u);
    final list = pool.list;
    final sidoHasAny = (Repos.venue.cached ?? const <Venue>[]).any((v) => sido.split('·').any((sd) => sidoMatches(v.sido, sd)));
    if (list.isEmpty && pool.notes.isNotEmpty && sidoHasAny) {
      _hint = const AnswerHint(kind: AnswerKind.venueList, headline: '조건에 맞는 곳이 없어요', sentence: '조건을 하나 빼거나 넓혀 볼 수 있어요.');
      return ChatMessage(
        fromUser: false,
        basis: [sido, ...pool.conds].join(' · '),
        text: '${pool.notes.join('\n')}\n\n조건에 맞는 곳을 앱 데이터에서 찾지 못했어요. '
            '정보가 비어 있는 곳은 기관에 확인하면 가능할 수도 있어요.',
        sources: const ['전국 공공예식장 현황'],
        quickReplies: const [QuickReply('조건 없이 보기', text: '공공예식장 추천해줘')],
      );
    }
    if (list.isEmpty) {
      _hint = AnswerHint(kind: AnswerKind.venueList, headline: '$sido에는 공공예식장이 없어요', sentence: '가까운 지역을 볼 수 있어요.');
      return ChatMessage(
        fromUser: false,
        basis: sido,
        text: '$sido에는 등록된 공공예식장이 없어요. 가까운 지역으로 찾아볼까요?',
        quickReplies: [
          for (final (s, n) in VenueScope.nearbySidos(Repos.venue.cached ?? const [], sido, n: 3))
            QuickReply('$s $n곳', action: 'refine', value: <String, Object?>{'set': {'sido': [s]}, 'remove': const ['sigungu']}),
          const QuickReply('지원 정책 보기', text: '받을 수 있는 정책 알려줘'),
        ],
        sources: const ['전국 공공예식장 현황'],
      );
    }
    final top = list.take(3).toList();
    String extra(Venue v) => [
          if (u.needs.contains('parking')) VenueFeatures.parking(v).label,
          if (u.needs.contains('reception')) VenueFeatures.reception(v).label,
          if (u.needs.contains('outdoor')) VenueFeatures.outdoor(v).guessed ? '야외(이름 기준)' : '야외',
        ].map((x) => ' · $x').join();
    ChatCard venueCard(Venue v) => ChatCard(
          title: v.name,
          subtitle: '${v.region} · ${v.capacityLabel} · ${v.feeLabel}${extra(v)}',
          icon: Icons.location_city,
          badge: guests != null && v.fits(guests) == true ? '하객 수용' : (v.isLimited ? '기간 제한' : '예약 가능'),
          open: () => VenueDetailScreen(venue: v),
          ref: 'venue:${v.id}',
        );
    final more = _startMore([for (final v in list) venueCard(v)], '${_placeOr(sido)} 공공예식장', tab: 0);
    return ChatMessage(
      fromUser: false,
      basis: [sido, if (guests != null) '하객 $guests명', ...pool.conds].join(' · '),
      text: '${pool.notes.isEmpty ? '' : '${pool.notes.join('\n')}\n'}'
          '$sido 공공예식장 ${list.length}곳 중에서 골랐어요.\n'
          '${guests != null ? '하객 $guests명을 수용할 수 있는 곳 ${list.where((v) => v.fits(guests) == true).length}곳, ' : ''}'
          '무료 대관 ${list.where((v) => v.isFree).length}곳, 정원 미확인 ${list.where((v) => v.capacity == null).length}곳이에요.\n\n'
          '${top.map((v) => '• ${v.name}\n   ${v.capacityLabel} · ${v.feeLabel} · ${v.bookingType.label}${extra(v)}').join('\n')}\n\n'
          '정원·요금을 모르는 곳은 기관에 확인이 필요해요.',
      cards: [for (final v in top) venueCard(v)],
      sources: const ['전국 공공예식장 현황 · 정원·요금·사진: 공유누리·서울마이웨딩 수집'],
      quickReplies: _withSave([
        ...more,
        const QuickReply('이 지역 지원 정책', text: '받을 수 있는 정책 알려줘'),
        const QuickReply('식대 업체 추천', text: '식대 업체 추천해줘'),
      ]),
    );
  }

  Future<ChatMessage> _vendorAnswer(VendorCategory item, {bool cheapest = false, int? itemBudget}) async {
    final sido = _known.sido!;
    final guests = _known.guests ?? _app.plan.guests;
    final budget = itemBudget ?? _app.budgetOf(item); // 질문에 말한 금액 → 체크리스트 준비 항목에 정한 금액
    final (picks, inBudget, count) = await ConsultTools.searchVendors(
        item: item, sido: sido, budget: budget, guests: guests, cheapest: cheapest);
    final order = cheapest ? '가격이 낮은 순' : '평점순';
    _lookupNote = budget == null
        ? '$sido ${item.label} 시연용 업체 $count곳 → 준비 항목 금액이 없어 $order'
        : '$sido ${item.label} 시연용 업체 $count곳 → 준비 항목 예산 $budget만원 안 $inBudget곳 먼저, $order';
    if (cheapest) _flowNote = '이전 질문을 이어서 더 싼 곳부터 다시 고름';
    _hintBudget = budget;
    _hint = AnswerHint(
      kind: AnswerKind.vendorList,
      headline: budget == null
          ? '$sido ${item.label} 업체 $count곳'
          : inBudget == 0
              ? '예산 $budget만원 안 업체가 없어요'
              : '예산 안 ${item.label} 업체 $inBudget곳',
      sentence: '[시연] 업체는 가격 비교용 가상 업체예요.',
    );
    final String head;
    if (budget == null) {
      head = '$sido ${item.label} 업체 $count곳 중 $order으로 골랐어요.';
    } else if (inBudget == 0) {
      head = '정해 두신 ${item.label} 예산 $budget만원 안의 업체는 $sido에 없어요. $order으로 보여드릴게요.';
    } else {
      head = '정해 두신 ${item.label} 예산 $budget만원 안의 업체가 $sido에 $inBudget곳 있어요. 그중 $order으로 골랐어요.';
    }
    String line(DemoVendor v) =>
        '${v.priceText}${v.totalLabel(guests: guests) != null ? ' (${v.totalLabel(guests: guests)})' : ''} · ★${v.rating}';
    ChatCard demoCard(DemoVendor v) => ChatCard(
          title: v.name,
          subtitle: line(v),
          icon: item.icon,
          badge: budget == null ? null : (v.estimate(guests: guests) <= budget ? '예산 안' : '예산 초과'),
          open: () => DemoVendorDetailScreen(vendor: v),
          ref: 'vendor:${v.id}',
        );
    // 더 보기: 시연 업체 다음에 이 항목을 하는 실제 연계 업체 (가격 문의)
    final real = (await Repos.vendor.realVendors())
        .where((v) => sidoMatches(v.sido, sido) && item.coversReal(v.category))
        .toList()
      ..sort((a, b) => (b.isOfficial ? 1 : 0) - (a.isOfficial ? 1 : 0));
    final more = _startMore([
      for (final v in picks) demoCard(v),
      for (final v in real)
        ChatCard(
          title: v.name,
          subtitle: '실제 연계 업체 · ${v.sigungu.isEmpty ? v.sido : v.sigungu} · 가격 문의',
          icon: item.icon,
          badge: v.isOfficial ? v.official : '실제 업체',
          open: () => RealVendorDetailScreen(vendor: v),
          ref: 'real:${v.id}',
        ),
    ], '$sido ${item.label} 업체', tab: 2, category: item);
    return ChatMessage(
      fromUser: false,
      basis: '$sido · ${budget == null ? '${item.label} 예산 미정' : '${item.label} 예산 $budget만원'} · 하객 $guests명',
      text: '$head\n\n'
          '${picks.map((v) => '• ${v.name.replaceFirst('[시연] ', '')} — ${line(v)}').join('\n')}\n\n'
          '${budget == null ? '체크리스트 준비 항목에서 ${item.label} 금액을 정하면 그 예산 안의 업체를 먼저 골라 드려요.\n' : ''}'
          '(가격·평점은 시연용 가상 데이터예요)',
      cards: [for (final v in picks) demoCard(v)],
      sources: const ['시연용 가상 업체 데이터'],
      quickReplies: _withSave([
        ...more,
        const QuickReply('내 예산 보기', text: '내 예산 현황 알려줘'),
        const QuickReply('메이크업도 추천', text: '메이크업 추천해줘'),
      ]),
    );
  }

  /// 질문이 가리키는 이전 목록을 찾는다: 같은 목적의 가장 최근 목록 (목적을 모르면 가장 최근 목록)
  (int turn, int index, ChatCard card)? _pickFromHistory(Understanding u) {
    for (var i = _turns.length - 1; i >= 0; i--) {
      final sameKind = u.intent == ConsultIntent.help || _turns[i].intent == u.intent;
      if (!sameKind || _turnCards[i].isEmpty) continue;
      final cards = _turnCards[i];
      final idx = u.refIndex! - 1;
      if (idx < 0 || idx >= cards.length) return null;
      return (i, idx, cards[idx]);
    }
    return null;
  }

  /// "두 번째 거 자세히": 이전 목록의 그 항목을 데이터에서 다시 찾아 자세히 답한다
  Future<ChatMessage> _refAnswer(Understanding u, int turn, int index, ChatCard card) async {
    final ago = _turns.length - 1 - turn;
    _flowNote = '${ago == 0 ? '직전' : '$ago턴 전'} 답변 목록의 ${index + 1}번째 "${card.title}"를 가리킨다고 이해';
    final [kind, id] = (card.ref ?? ':').split(':');
    switch (kind) {
      case 'venue':
        final v = (await Repos.venue.loadAll()).where((v) => v.id == id).firstOrNull;
        if (v == null) break;
        _lookupNote = '공공예식장 데이터에서 ${v.name} 정보 조회 (주차·피로연·예식 가능일 원문 포함)';
        _hint = _venueDetailHint(v); // 앞 목록의 한 곳 = 예식장 상세 (목록 제목이 아니라 그곳 이름)
        return ChatMessage(
          fromUser: false,
          basis: '이전 목록 ${index + 1}번째',
          text: _venueInfo(v, u),
          cards: [card],
          sources: const ['전국 공공예식장 현황 · 정원·요금·사진: 공유누리·서울마이웨딩 수집'],
          quickReplies: const [
            QuickReply('관련 지원 정책', text: '예식 지원 정책 알려줘'),
            QuickReply('식대 업체 추천', text: '식대 업체 추천해줘'),
          ],
        );
      case 'policy':
        final all = await Repos.policy.loadAll();
        final p = all.where((p) => p.id == id).firstOrNull;
        if (p == null) break;
        final m = PolicyMatcher.judge(all, PolicyProfile.fromUser(_known)).matches.where((m) => m.policy.id == id).firstOrNull;
        _lookupNote = '정책 데이터에서 ${p.name} 조회 + 규칙으로 대상 판정';
        return ChatMessage(
          fromUser: false,
          basis: '이전 목록 ${index + 1}번째',
          text: '${p.name} (${p.regionLabel} · ${p.category.label})\n'
              '${m == null ? '• 지금 정보로는 대상이 아닐 수 있어요. 조건을 기관에 확인해 주세요.\n' : '• 해당 이유: ${m.reasons.join(', ')}\n'}'
              '${m != null && m.checks.isNotEmpty ? '• 확인할 것: ${m.checks.join(', ')}\n' : ''}'
              '• 지원 자격(원문): ${p.eligibility.length > 140 ? '${p.eligibility.substring(0, 140)}…' : p.eligibility}\n\n'
              '신청은 아래 카드를 눌러 "신청 페이지 열기"에서 할 수 있어요. 최종 대상 여부는 담당 기관에서 확인해 주세요.',
          cards: [card],
          sources: const ['청년 결혼 지원 정책 177건 (복지로·온통청년·지자체 공고)'],
        );
      case 'vendor':
        final v = (await Repos.vendor.demoVendors()).where((v) => v.id == id).firstOrNull;
        if (v == null) break;
        final guests = _known.guests ?? _app.plan.guests;
        _lookupNote = '시연용 업체 데이터에서 ${v.name} 조회';
        return ChatMessage(
          fromUser: false,
          basis: '이전 목록 ${index + 1}번째',
          text: '${v.name.replaceFirst('[시연] ', '')} 정보예요.\n'
              '• 가격: ${v.priceText}${v.totalLabel(guests: guests) != null ? ' (${v.totalLabel(guests: guests)})' : ''}\n'
              '${_budgetLine(v, guests)}'
              '• 평점: ★${v.rating} (후기 ${v.reviewCount}개)\n'
              '• 포함: ${v.packageItems.join(', ')}\n'
              '${v.addOns.isEmpty ? '' : '• 추가 옵션(고르면 추가): ${v.addOns.map((a) => '${a.name} +${a.price}만원').join(', ')}\n'}\n'
              '후기와 상담 신청은 아래 카드를 눌러 확인하세요. (가격·평점은 시연용 가상 데이터예요)',
          cards: [card],
          sources: const ['시연용 가상 업체 데이터'],
        );
    }
    return ChatMessage(
      fromUser: false,
      text: '"${card.title}" 정보를 찾지 못했어요. 아래 카드를 눌러 확인해 주세요.',
      cards: [card],
    );
  }

  /// 준비 항목에 정한 금액이 있으면 "내 예산 안/초과" 한 줄
  String _budgetLine(DemoVendor v, int guests) {
    final b = _app.budgetOf(v.category);
    if (b == null) return '';
    return '• 내 ${v.category.label} 예산 $b만원 ${v.estimate(guests: guests) <= b ? '안이에요' : '보다 많아요'}\n';
  }

  /// 내 예산 현황: 체크리스트 준비 항목에 정한 금액 그대로 (임의 배분 비율은 쓰지 않음)
  ChatMessage _budgetAnswer() {
    final total = _known.budget!;
    final withAmount = _app.items.where((i) => (i.amount ?? 0) > 0).toList();
    final missing = _app.items.where((i) => (i.amount ?? 0) <= 0).map((i) => i.name).toList();
    final confirmed = _app.confirmedTotal;
    final planned = _app.plannedTotal;
    final left = total - confirmed - planned;
    _lookupNote = '체크리스트 준비 항목 ${_app.items.length}개 중 금액을 정한 ${withAmount.length}개 합산';
    const actions = [
      QuickReply('체크리스트에서 금액 정하기', action: 'open_checklist'),
      QuickReply('무료 공공예식장', text: '공공예식장 추천해줘'),
    ];
    if (withAmount.isEmpty) {
      return ChatMessage(
        fromUser: false,
        basis: '총예산 ${formatManwon(total)}',
        text: '아직 준비 항목에 금액을 정하지 않았어요.\n'
            '체크리스트의 준비 항목마다 금액을 적어 두면, 여기서 항목별 금액·합계·남은 예산을 정리해 드리고 '
            '업체를 추천할 때도 그 금액 안의 업체를 먼저 골라 드려요.',
        sources: const ['내 체크리스트'],
        quickReplies: actions,
      );
    }
    String line(PlanItem i) =>
        '• ${i.name} ${formatManwon(i.amount!)}${i.status == ItemStatus.todo ? '' : ' (${i.status.label})'}';
    _hint = AnswerHint(
      kind: AnswerKind.budget,
      headline: left >= 0 ? '남은 예산 ${formatManwon(left)}' : '${formatManwon(-left)} 초과예요',
      headBadges: [
        BlockBadge('계약 ${formatManwon(confirmed)}', Tone.good),
        if (missing.isNotEmpty) BlockBadge('금액 미정 ${missing.length}개', Tone.check),
      ],
      budgetRows: [for (final i in withAmount.take(6)) [i.name, formatManwon(i.amount!)]],
      budgetTotal: '총예산 ${formatManwon(total)}',
    );
    return ChatMessage(
      fromUser: false,
      basis: '총예산 ${formatManwon(total)} · 준비 항목에 정한 금액',
      text: '준비 항목에 정해 둔 금액이에요.\n'
          '${withAmount.map(line).join('\n')}\n\n'
          '• 계약·결제 완료 ${formatManwon(confirmed)} · 계약 전 ${formatManwon(planned)}\n'
          '• 총예산 ${formatManwon(total)}에서 ${left >= 0 ? '남은 예산 ${formatManwon(left)}' : '${formatManwon(-left)} 초과'}'
          '${missing.isEmpty ? '' : '\n\n아직 금액을 정하지 않은 항목: ${missing.join(', ')}'}',
      sources: const ['내 체크리스트'],
      quickReplies: actions,
    );
  }

  ChatMessage _scheduleAnswer() {
    final tasks = ConsultTools.nextTasks();
    _lookupNote = _app.tasks.isEmpty ? '내 할 일이 없어 추천 할 일 목록에서 순서대로' : '예식일 기준 체크리스트 ${_app.tasks.length}개 중 아직 안 한 일을 순서대로';
    final date = _known.weddingDate;
    // 날짜끼리 비교 (지금 시각 때문에 하루 적게 세지 않도록)
    final now = DateTime.now();
    final daysLeft = date == null ? null : DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    // 권장 시기(예식 D-N)가 이미 지난 일: 남은 날보다 D-N이 크면 늦은 것
    bool late(ChecklistTask t) => daysLeft != null && t.dMinus > daysLeft;
    final lateCount = tasks.where(late).length;
    String cut(String t) => t.length > 18 ? '${t.substring(0, 17)}…' : t;
    _hint = AnswerHint(
      kind: AnswerKind.schedule,
      headline: tasks.isEmpty ? '남은 할 일이 없어요' : '지금은 ${cut(tasks.first.title)}',
      headBadges: [
        if (daysLeft != null) BlockBadge('D-$daysLeft', Tone.info),
        if (lateCount > 0) BlockBadge('시기 지남 $lateCount개', Tone.check),
      ],
      steps: [for (final t in tasks.take(4)) cut(t.title)],
      sentence: date == null ? '예식일을 정하면 날짜별로 알려 드려요.' : null,
    );
    final head = date == null
        ? '예식일이 아직 정해지지 않았다면, 날짜·지역·예산을 먼저 정하는 게 시작이에요.'
        : '예식일 ${formatDate(date)}까지 $daysLeft일 남았어요.'
            '${lateCount > 0 ? ' 권장 시기가 지난 일이 $lateCount개 있으니 먼저 챙겨 주세요.' : ''}';
    return ChatMessage(
      fromUser: false,
      basis: date == null ? '예식일 미정' : '예식일 ${formatDate(date)}',
      text: '$head 지금 먼저 할 일이에요.\n'
          '${tasks.map((t) => late(t) ? '• ${t.title} (권장 D-${t.dMinus}, 시기 지남)' : '• D-${t.dMinus} ${t.title}').join('\n')}\n\n'
          '체크리스트 탭에서 전체 순서와 진행 상태를 볼 수 있어요.',
      sources: const ['예식일 기준 체크리스트 템플릿'],
      quickReplies: _withSave(const [
        QuickReply('공공예식장부터 보기', text: '공공예식장 추천해줘'),
        QuickReply('받을 수 있는 정책', text: '받을 수 있는 정책 알려줘'),
      ]),
    );
  }

  /// 내 정보로 한 번에 추천: 예식장 2곳 + 정책 3건 + 예산 + 할 일
  Future<ChatMessage> _recommendAnswer() async {
    final venues = _known.sido == null
        ? const []
        : (await ConsultTools.searchVenues(sido: _known.sido!, guests: _known.guests, sigungu: _known.sigungu))
            .take(2)
            .toList();
    final policies = (await ConsultTools.matchPolicies(_known)).take(3).toList();
    final budget = _known.budget;
    final used = _app.confirmedTotal + _app.plannedTotal;
    final budgetLine = budget == null || used == 0
        ? null
        : '💰 예산: 준비 항목에 정한 금액 ${formatManwon(used)} · '
            '${budget - used >= 0 ? '남은 예산 ${formatManwon(budget - used)}' : '${formatManwon(used - budget)} 초과'}';
    final tasks = ConsultTools.nextTasks(count: 2);
    _lookupNote = '예식장 검색 · 정책 판정 · 내 예산 현황 · 할 일 도구의 결과를 모아 정리';
    _hint = AnswerHint(
      kind: AnswerKind.other,
      headline: '내 정보로 고른 추천이에요',
      steps: [for (final t in tasks) t.title.length > 18 ? '${t.title.substring(0, 17)}…' : t.title],
    );

    return ChatMessage(
      fromUser: false,
      basis: _known.summary,
      text: [
        if (venues.isNotEmpty)
          '🏛 공공예식장: ${venues.map((v) => '${v.name}(${v.capacityLabel}, ${v.feeLabel})').join(', ')}',
        if (policies.isNotEmpty) '🎁 받을 수 있는 정책: ${policies.map((m) => m.policy.name).join(', ')}',
        if (budgetLine != null) budgetLine,
        if (tasks.isNotEmpty) '✅ 지금 할 일: ${tasks.map((t) => t.title).join(', ')}',
        '\n궁금한 부분을 눌러 자세히 보거나, 편하게 물어보세요.',
      ].join('\n'),
      cards: [
        for (final v in venues)
          ChatCard(
            title: v.name,
            subtitle: '${v.region} · ${v.capacityLabel} · ${v.feeLabel}',
            icon: Icons.location_city,
            badge: '예식장',
            open: () => VenueDetailScreen(venue: v),
            ref: 'venue:${v.id}',
          ),
        for (final m in policies)
          ChatCard(
            title: m.policy.name,
            subtitle: '${m.policy.regionLabel} · ${m.policy.category.label}',
            icon: Icons.volunteer_activism,
            badge: m.level == MatchLevel.likely ? '해당 가능성 높음' : '조건 확인 필요',
            open: () => PolicyDetailScreen(match: m),
            ref: 'policy:${m.policy.id}',
          ),
      ],
      sources: const ['공공예식장 현황 · 청년 결혼 지원 정책 177건 · 예식일 기준 체크리스트'],
      quickReplies: _withSave(const [
        QuickReply('정책 자세히', text: '받을 수 있는 정책 알려줘'),
        QuickReply('예식장 더 보기', text: '공공예식장 추천해줘'),
        QuickReply('예산 자세히', text: '예산 어떻게 나누면 돼?'),
        QuickReply('뭐부터 해야 해?', text: '뭐부터 해야 해?'),
      ]),
    );
  }

  static const _starterReplies = [
    QuickReply('받을 수 있는 정책', text: '받을 수 있는 정책 알려줘'),
    QuickReply('공공예식장 추천', text: '공공예식장 추천해줘'),
    QuickReply('예산 나누기', text: '예산 어떻게 나누면 돼?'),
    QuickReply('뭐부터 해야 해?', text: '뭐부터 해야 해?'),
  ];

  ChatMessage _help() {
    _templateOnly = '도움말';
    _hint = const AnswerHint(
      kind: AnswerKind.other,
      headline: '이런 걸 물어볼 수 있어요',
      steps: ['받을 수 있는 정책', '하객 수에 맞는 예식장', '예산 안 업체', '지금 할 일'],
    );
    return _helpMessage;
  }

  static const _helpMessage = ChatMessage(
        fromUser: false,
        text: '이런 걸 물어보실 수 있어요.\n'
            '• "20대 청년이 신혼생활에 받을 수 있는 정책이 뭐가 있어?"\n'
            '• "하객 100명 정도인데 서울 공공예식장 추천해줘"\n'
            '• "예산 3천만원인데 드레스 추천해줘"\n'
            '• "예산 어떻게 나누면 돼?"\n'
            '• "뭐부터 해야 해?"\n\n'
            '필요한 정보가 없으면 제가 하나씩 여쭤볼게요.',
        quickReplies: _starterReplies,
      );
}
