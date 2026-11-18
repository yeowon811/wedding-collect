import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/region.dart';
import '../../../data/app_state.dart';
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
import 'venue_features.dart';
import 'gemini_client.dart';
import 'understanding.dart';

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
  late UserProfile _known = _app.profileDone ? _app.profile : const UserProfile();
  late UserProfile _seenApp = _app.profile; // 마지막으로 본 앱의 내 정보

  /// 이번 질문에서 방금 지역(시도)을 되물어 답을 받았는지 → 그때만 이어서 시·군·구를 묻는다
  bool _sidoJustAsked = false;

  /// 이번 질문의 날짜 조건과, 앱 데이터로 확인할 수 없는 조건 (Gemini가 판단)
  DateTime? _askDate;
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

  /// 체크리스트·내 정보 화면에서 바뀐 결혼 정보만 대화 기억에 반영 (대화에서 말한 값은 덮지 않음)
  void _syncFromApp() {
    final cur = _app.profile;
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
    _known = _app.profileDone ? _app.profile : _known;
    if (!_app.profileDone) {
      return ChatMessage(
        fromUser: false,
        text: '안녕하세요! 결혼 준비를 도와드릴게요.\n'
            '궁금한 걸 편하게 물어보세요. 답하는 데 필요한 정보가 없으면 제가 하나씩 여쭤볼게요.',
        quickReplies: _starterReplies,
      );
    }
    _question = '내 정보에 맞게 예식장·정책·예산·할 일을 한 번에 추천해줘';
    _nluNote = '상담 시작 시 내 정보로 바로 추천';
    final rec = await _finish(const Understanding(intent: ConsultIntent.recommend));
    return rec.copyWith(
      text: rec.aiWritten ? rec.text : '입력해 주신 정보로 먼저 정리해 봤어요.\n\n${rec.text}',
    );
  }

  @override
  Future<ChatMessage> reply(String question) async {
    _syncFromApp();
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
      if (_asking == Slot.sido) _sidoJustAsked = true;
      if (_asking == Slot.item && u.item != null) _pending = _pending!.withItem(u.item!);
      if (!_isFilled(_asking!, _pending!)) {
        return _ask(_asking!, _pending!, retry: true);
      }
      return _process(_pending!);
    }
    if (_isMoreRequest(text)) return _moreAnswer();
    _question = text;
    _sidoJustAsked = false;
    step.value = AgentStep.understand;
    return _process((await _understand(text)).u);
  }

  /// ① 질문 이해: Gemini가 있으면 Gemini, 실패하거나 없으면 규칙.
  /// 규칙으로 뽑은 값도 함께 써서, Gemini가 놓친 값은 규칙 결과로 채운다.
  Future<({Understanding u, bool isAnswer})> _understand(String text, {Slot? expecting}) async {
    final plain = _nlu.parse(text, expecting: expecting);
    if (expecting == null) {
      _askDate = parseAskDate(text);
      _unsupported = const [];
    }
    // 되묻기 답("서울")이 아니면 대화 흐름 규칙도 적용 ("두 번째", "그중에 무료", "그럼 부산은?")
    final rule = expecting == null ? ContextRules.apply(plain, text, _turns) : plain;
    final context = _turns.isEmpty ? null : ConversationContext.state(_turns, _memoryTurns, known: _known);
    final ai = await _llm?.understand(text, expecting: expecting, context: context);
    final flow = context == null ? '' : ' · 최근 ${_turns.length.clamp(1, _memoryTurns)}턴 대화 요약을 함께 봄';
    if (ai == null) {
      _nluNote = (_llm == null ? '규칙(키워드·대화 흐름)으로 이해' : 'Gemini 응답 없음 → 규칙(키워드·대화 흐름)으로 이해');
      return (u: _withTown(rule, text), isAnswer: false);
    }
    _nluNote = 'Gemini가 이해$flow (정해진 형식·값 범위 검사 후 사용, 놓친 값은 규칙으로 보완)';
    final intent = ai.u.intent;
    final town = _noExcluded(_townFacts(text, plain.facts.merge(ai.u.facts)), [...ai.u.exclude, ...rule.exclude]);
    if (expecting == null) {
      _askDate = ai.u.date ?? _askDate;
      // 날짜 조건은 앱이 예식 가능일로 판단하므로 '확인 못 함'에서 뺀다
      _unsupported = [
        for (final x in ai.u.unsupported)
          if (!RegExp(r'날짜|일자|예약 가능|가능일|\d|주차|피로연|뷔페|케이터링|식사|야외|비용|얼마|추가금|비교|나아|계산|싸|무료|하객|사진|그중|많이 주|금액|소득|연봉|봄|여름|가을|겨울|요일|주말')
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
  Future<ChatMessage> _polish(ChatMessage m) async {
    final llm = _llm;
    if (llm == null || m.isQuestion || m.aiWritten) return m;
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
    switch (r.action) {
      case 'open_checklist':
        MainShell.goTo(3);
        return ChatMessage(fromUser: false, text: '체크리스트 탭을 열었어요. 준비 항목을 눌러 금액을 적어 주세요.');
      case 'skip_ask':
        return _skipCurrent();
      case 'more':
        return _moreAnswer();
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
      return _process(_pending!);
    }
    if (r.slot != null && _pending != null) {
      if (r.slot == Slot.sido.name) _sidoJustAsked = true;
      _known = _known.merge(_valueToFacts(Slot.values.byName(r.slot!), r.value));
      return _process(_pending!);
    }
    if (r.text != null) return reply(r.text!);
    return _help();
  }

  // ───────────────────────── 대화 흐름 ─────────────────────────

  Future<ChatMessage> _process(Understanding u) async {
    _known = _known.merge(u.facts);
    _flowNote = '';
    if (u.monthsLeft != null) {
      _known = _known.merge(UserProfile(weddingDate: DateTime.now().add(Duration(days: u.monthsLeft! * 30))));
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
      return _ask(missing.first, u, remaining: missing.length);
    }
    final skipped = [for (final s in _skipped) _slotLabel[s]!];
    _clearPending();
    if (u.intent == ConsultIntent.help) return _helpAnswer();
    return _finish(u, skipped: skipped);
  }

  /// ④ 데이터 조회 → ⑤ 답변 작성 + "왜 이렇게 답했나요?" 기록
  Future<ChatMessage> _finish(Understanding u,
      {List<String> skipped = const [], Future<ChatMessage> Function()? build}) async {
    step.value = AgentStep.lookup;
    _lookupNote = '';
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
      '답변 작성 · ${_llm == null ? '앱이 정해진 문장 틀로 작성 (Gemini 미연결)' : _llm.lastRewriteNote}',
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
    return _process(_pending!);
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
    var topicNote = u.topic != null ? '${u.topic!.label} ' : '';
    if (matches.isEmpty && u.topic != null) {
      matches = await ConsultTools.matchPolicies(_known);
      topicNote = '';
    }
    // 질문에 소득이 있으면 원문의 소득 상한과 비교, "제일 많이 주는"이면 원문의 최대 금액 순
    final income = incomeFromQuestion(_question);
    final byAmount = RegExp(r'제일\s*많이|가장\s*많이|많이\s*주|금액.{0,4}(큰|많)|최대\s*얼마').hasMatch(_question);
    final notes = <String>[];
    if (income != null) {
      final over = matches.where((m) => (incomeCap(m.policy.eligibility) ?? 1 << 30) < income).toList();
      matches = matches.where((m) => !over.contains(m)).toList();
      final noNumber = matches.where((m) => m.policy.hasIncomeLimit && incomeCap(m.policy.eligibility) == null).length;
      notes.add('부부합산 연소득 ${manwonLabel(income)} 기준으로 원문의 소득 상한을 비교했어요. '
          '상한을 넘는 ${over.length}건은 뺐어요${over.isEmpty ? '' : ' (${over.take(2).map((m) => m.policy.name).join(', ')}${over.length > 2 ? ' 외' : ''})'}'
          '${noNumber > 0 ? ', 소득 조건이 숫자로 적혀 있지 않은 $noNumber건은 기관에 확인이 필요해요' : ''}.');
    }
    if (byAmount) {
      matches = [...matches]..sort((a, b) => (maxAmount(b.policy.eligibility) ?? -1).compareTo(maxAmount(a.policy.eligibility) ?? -1));
      final withAmount = matches.where((m) => maxAmount(m.policy.eligibility) != null).length;
      notes.add('원문에 적힌 "최대 금액" 순이에요 (금액이 적힌 정책 $withAmount건). '
          '대출·이자 지원의 금액은 받는 돈이 아니라 빌릴 수 있는 한도라서 현금 지원과 성격이 달라요.');
    }
    String extra(PolicyMatch m) => [
          if (income != null && incomeCap(m.policy.eligibility) != null) '소득 상한 연 ${manwonLabel(incomeCap(m.policy.eligibility)!)} (통과)',
          if (byAmount && maxAmount(m.policy.eligibility) != null) '원문 최대 ${manwonLabel(maxAmount(m.policy.eligibility)!)}',
        ].map((x) => ' / $x').join();
    final likely = matches.where((m) => m.level == MatchLevel.likely).length;
    _lookupNote = '정책 데이터를 정해진 규칙으로 판정 → 해당 가능 ${matches.length}건 '
        '${income != null ? '· 원문 소득 상한과 비교 ' : ''}${byAmount ? '· 원문 최대 금액 순 ' : ''}'
        '(가능성 높음 $likely건)${topicNote.isEmpty ? '' : ' · ${topicNote.trim()} 분야만'}';
    final top = matches.take(3).toList();
    final region = _known.sido ?? '전국';
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
      cards: [for (final m in top) policyCard(m)],
      sources: const ['청년 결혼 지원 정책 177건 (복지로·온통청년·지자체 공고)'],
      quickReplies: _withSave([
        ...more,
        if (u.topic != PolicyCategory.cash) const QuickReply('결혼 장려금도 보기', text: '결혼 장려금 정책 알려줘'),
        if (u.topic != PolicyCategory.housing) const QuickReply('주거 지원도 보기', text: '신혼집 주거 지원 정책 알려줘'),
        const QuickReply('공공예식장 추천', text: '공공예식장 추천해줘'),
      ]),
    );
  }

  /// "12/20에 예약 가능한 예식장": 예식 가능일 원문을 Gemini가 읽고 판단 (실패하면 규칙).
  /// 원문이 없는 곳은 "정보 없음"으로 나누고, 이미 예약이 찼는지는 알 수 없다고 안내한다.
  Future<ChatMessage> _venueDateAnswer(DateTime date, Understanding u) async {
    final sido = _known.sido!;
    final guests = _known.guests;
    final label = dateLabel(date);
    final pool = await _venuePool(u);
    final all = pool.list;
    final withText = {for (final v in all) if (dateTextOf(v, date) case final t?) v.id: t};
    // 원문에 월 범위·요일·불가일이 분명하면 규칙으로 '불가'를 확정하고,
    // 나머지(지정일·협의·문장으로 적힌 조건 등)만 Gemini가 원문을 읽고 판단한다 (이름·주소 없이 id와 원문만)
    final sure = {
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
    final possible = all.where((v) => judged[v.id]!.fit == DateFit.possible).toList();
    final impossible = all.where((v) => judged[v.id]!.fit == DateFit.impossible).toList();
    final unclear = all.where((v) => withText.containsKey(v.id) && judged[v.id]!.fit == DateFit.unknown).toList();
    final noInfo = all.where((v) => !withText.containsKey(v.id)).toList();
    _lookupNote = '$sido 공공예식장 ${all.length}곳 중 날짜 정보(예식 가능일 원문) 있는 곳 ${withText.length}곳 → '
        '규칙으로 분명한 불가 ${sure.length}곳, 나머지 ${withText.length - sure.length}곳은 '
        '${ai == null ? '규칙으로 판단(Gemini 없음·실패)' : 'Gemini가 원문을 읽고 판단(${ai.length}곳)'}: 가능 ${possible.length} · 불가 ${impossible.length} · '
        '원문만으론 모름 ${unclear.length} / 정보 없음 ${noInfo.length}곳';

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
      for (final v in possible) card(v, '$label 가능일'),
      if (possible.isEmpty) ...[
        for (final v in unclear) card(v, '기관 확인 필요'),
        for (final v in noInfo) card(v, '날짜 정보 없음'),
      ],
    ];
    final more = _startMore(cards, '$label $sido 공공예식장', tab: 0);
    String names(List<Venue> l) =>
        l.take(3).map((v) => '${v.name}(${judged[v.id]!.reason})').join(', ') + (l.length > 3 ? ' 외 ${l.length - 3}곳' : '');
    final lines = <String>[
      if (possible.isNotEmpty) '• 그날 예식이 가능한 기간·요일인 곳: ${possible.length}곳 (아래)',
      if (impossible.isNotEmpty) '• 그날은 예식이 없는 곳: ${impossible.length}곳 — ${names(impossible)}',
      if (unclear.isNotEmpty) '• 날짜 안내는 있지만 판단이 어려운 곳: ${unclear.length}곳 — ${names(unclear)}',
      if (noInfo.isNotEmpty) '• 예식 가능일 정보가 앱에 없는 곳: ${noInfo.length}곳 → 예약 페이지·문의처에서 확인',
    ];
    final head = withText.isEmpty
        ? '$sido 공공예식장 ${all.length}곳은 예식 가능일 정보가 앱 데이터에 없어서 $label 예약 가능 여부를 알려드릴 수 없어요. '
            '대신 정원·요금 기준으로 고른 곳을 보여드릴게요. 각 예약 페이지나 문의처에서 날짜를 확인해 주세요.'
        : '$label에 예식이 가능한지, 앱에 있는 예식장별 "예식 가능일" 안내로 확인했어요.';
    return ChatMessage(
      fromUser: false,
      basis: [sido, if (_known.sigungu != null) _known.sigungu!, label, if (guests != null) '하객 $guests명'].join(' · '),
      text: '${pool.notes.isEmpty ? '' : '${pool.notes.join('\n')}\n'}$head\n\n${withText.isEmpty ? '' : '${lines.join('\n')}\n\n'}'
          '${shown.take(3).map((v) => '• ${v.name}\n   ${v.capacityLabel} · ${v.feeLabel} · ${v.bookingType.label}').join('\n')}\n\n'
          '이미 다른 예약이 잡혔는지는 앱에서 알 수 없어요. 신청 전에 예약 페이지에서 그 날짜가 비어 있는지 꼭 확인해 주세요.',
      cards: cards.take(3).toList(),
      sources: const ['전국 공공예식장 현황 · 예식 가능일: 서울마이웨딩·기관 안내 수집 원문'],
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
    // "서울에 안 살아도 서울 공공예식장 쓸 수 있어?" → 이용 대상 원문 + 지원 정책 거주 조건
    final residencySido = u.facts.sido ?? _known.sido;
    if (residencySido != null && _isResidencyQuestion) return () => _residencyAnswer(residencySido);
    // "내년 봄 토요일" → 그 계절의 그 요일 전부를 예식 가능일 원문으로 확인
    final season = _seasonDates(_question);
    if (season != null && _known.sido != null && (u.intent == ConsultIntent.venue || _question.contains('예식장'))) {
      return () => _venueSeasonAnswer(u, season.dates, season.label);
    }
    final expr = u.calc ?? (u.kind == AskKind.calc ? ruleCalc(_question) : null);
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
    if (u.kind == AskKind.general && _llm != null) return () => _generalAnswer(u);
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

  /// "내년 봄 토요일" → 그 계절의 그 요일 날짜들
  ({List<DateTime> dates, String label})? _seasonDates(String q) {
    final s = RegExp(r'(봄|여름|가을|겨울)').firstMatch(q)?[1];
    if (s == null) return null;
    final months = switch (s) { '봄' => [3, 4, 5], '여름' => [6, 7, 8], '가을' => [9, 10, 11], _ => [12, 1, 2] };
    final days = q.contains('토요일') || RegExp(r'토\s*(요일)?에').hasMatch(q)
        ? [DateTime.saturday]
        : q.contains('일요일')
            ? [DateTime.sunday]
            : q.contains('평일')
                ? [1, 2, 3, 4, 5]
                : [DateTime.saturday, DateTime.sunday];
    final now = DateTime.now();
    var year = q.contains('내년') ? now.year + 1 : now.year;
    if (!q.contains('내년') && months.last < now.month && s != '겨울') year++;
    final dates = <DateTime>[];
    for (final m in months) {
      final y = (s == '겨울' && m <= 2) ? year + 1 : year;
      for (var d = DateTime(y, m, 1); d.month == m; d = d.add(const Duration(days: 1))) {
        if (days.contains(d.weekday) && d.isAfter(now)) dates.add(d);
      }
    }
    final dayLabel = days.length == 1 ? (days.first == 6 ? '토요일' : '일요일') : (days.length == 2 ? '주말' : '평일');
    return dates.isEmpty ? null : (dates: dates, label: '$year년 $s(${months.first}~${months.last}월) $dayLabel');
  }

  /// 계절·요일 질문: 날짜마다 예식 가능일 원문을 규칙으로 확인 → 가능한 날이 있는 곳
  Future<ChatMessage> _venueSeasonAnswer(Understanding u, List<DateTime> dates, String label) async {
    final sido = _known.sido!;
    final pool = await _venuePool(u);
    final counts = <Venue, int>{};
    var unknown = 0, none = 0;
    for (final v in pool.list) {
      final fits = dates.map((d) => ruleJudgeDate(v, d).fit).toList();
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
    _lookupNote = '$label ${dates.length}일 × $sido 공공예식장 ${pool.list.length}곳의 예식 가능일 원문을 규칙(월 범위·요일·불가일)으로 확인';
    final cards = [for (final v in ranked) _venueCard(v, badge: '${counts[v]}/${dates.length}일 가능')];
    final more = _startMore(cards, '$label 가능한 $sido 공공예식장', tab: 0);
    return ChatMessage(
      fromUser: false,
      basis: '$sido · $label (${dates.length}일)',
      text: '${pool.notes.isEmpty ? '' : '${pool.notes.join('\n')}\n'}'
          '$label ${dates.length}일을 예식장마다 예식 가능일 원문으로 확인했어요.\n'
          '• 그중 하루라도 예식이 가능한 곳: ${ranked.length}곳\n'
          '• 그 기간엔 예식이 없는 곳: $none곳\n'
          '• 원문만으로는 알 수 없는 곳(지정일·협의·정보 없음): $unknown곳\n\n'
          '${ranked.take(3).map((v) => '• ${v.name}: ${dates.length}일 중 ${counts[v]}일 가능 (${v.capacityLabel} · ${v.feeLabel})').join('\n')}\n\n'
          '날짜를 하나 정하면 그날 기준으로 다시 확인해 드려요. 이미 찬 날짜는 앱에서 알 수 없어요.',
      cards: cards.take(3).toList(),
      sources: const ['전국 공공예식장 현황 · 예식 가능일 원문'],
      quickReplies: [...more, const QuickReply('날짜 골라서 다시 보기', slot: 'weddingDate', action: 'input')],
    );
  }

  /// 짧은 후속 질문("12/20에 되는 곳은?")은 바로 앞 예식장 답변의 조건(무료·제외·주차 등)을 이어받는다
  Understanding _carryVenueConds(Understanding u) {
    final prev = _turns.lastOrNull;
    if (u.intent != ConsultIntent.venue || prev?.intent != ConsultIntent.venue || _question.length > 20) return u;
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

  /// 예식장 후보 + 조건 적용 (무료·하객 수용·사진·더 싼 곳 / 시군구 제외 / 주차·피로연·야외 원문)
  Future<({List<Venue> list, List<String> notes, List<String> conds})> _venuePool(Understanding u) async {
    final sido = _known.sido!;
    final guests = _known.guests;
    var list = await ConsultTools.searchVenues(sido: sido, guests: guests, sigungu: _known.sigungu);
    final total = list.length;
    final notes = <String>[];
    final conds = <String>[];
    final filter = u.filter;
    if (filter != null && _filterLabel.containsKey(filter)) {
      list = switch (filter) {
        'free' => list.where((v) => v.isFree).toList(),
        'fits_guests' => guests == null ? list : list.where((v) => v.fits(guests) == true).toList(),
        'has_photo' => list.where((v) => v.images.isNotEmpty).toList(),
        _ => ([...list.where((v) => v.rentalFee != null)]..sort((a, b) => a.rentalFee!.compareTo(b.rentalFee!))),
      };
      conds.add(_filterLabel[filter]!);
      notes.add('• ${_filterLabel[filter]}: $total곳 → ${list.length}곳');
    }
    for (final ex in u.exclude) {
      final key = ex.replaceAll(RegExp(r'(구|시|군)$'), '');
      final before = list.length;
      list = list.where((v) => !v.sigungu.startsWith(key)).toList();
      conds.add('$ex 제외');
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
      notes.add('• ${_needLabel[need]} 가능(원문 기준) ${yes.length}곳 · 불가 $no곳 · 정보 없음 ${before.length - yes.length - no}곳'
          '${need == 'outdoor' ? ' (실내외 칸이 비면 이름의 잔디·공원·마당 등으로 판단)' : ''}${need == 'parking' ? ' → 주차 대수가 많은 순' : ''}');
    }
    _lastVenueConds = (filter: filter, exclude: u.exclude, needs: u.needs);
    _lookupNote = '$sido 공공예식장 $total곳${conds.isEmpty ? '' : ' → 조건(${conds.join(', ')}) 적용 ${list.length}곳'} → '
        '${_known.sigungu != null ? '${_known.sigungu} 먼저 · ' : ''}하객 수용 · 무료 · 예약 가능 순';
    return (list: list, notes: notes, conds: conds);
  }

  /// 예식장 한 곳의 정보 (원문 그대로): 정원·요금·예약·접수 기간·이용 대상·주차·피로연·예식 가능일·기타 안내
  String _venueInfo(Venue v, Understanding u) {
    final p = VenueFeatures.parking(v);
    final r = VenueFeatures.reception(v);
    final asksBooking = RegExp(r'예약|남아|자리|비어|마감|신청').hasMatch(_question);
    String cut(String t, [int n = 90]) => t.length > n ? '${t.substring(0, n)}…' : t;
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
      if (_askDate != null)
        '• ${dateLabel(_askDate!)}: ${switch (ruleJudgeDate(v, _askDate!)) {
          DateJudgement(fit: DateFit.possible, :final reason) => '예식 가능일 조건에 맞아요 ($reason)',
          DateJudgement(fit: DateFit.impossible, :final reason) => '그날은 예식이 없어요 ($reason)',
          _ => '원문만으로는 알 수 없어요',
        }}',
      if (v.extraInfo != null) '• 기타 안내: ${cut(v.extraInfo!, 120)}',
      '• 문의: ${v.bookingContact}',
      '',
      asksBooking
          ? '이미 찬 날짜·남은 자리는 앱 데이터에 없어요. 예약 페이지나 문의처에서 확인해 주세요.'
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

  ChatMessage _venueDetailAnswer(Venue v, Understanding u) {
    _lookupNote = '질문에 나온 이름으로 공공예식장 데이터에서 "${v.name}" 찾음 → 정원·요금·예약·주차·피로연·예식 가능일 원문';
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
    if (text == null) return _help();
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
    final sido = _known.sido!;
    final guests = _known.guests;
    final pool = await _venuePool(u);
    final list = pool.list;
    if (list.isEmpty && pool.notes.isNotEmpty) {
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
      return ChatMessage(
        fromUser: false,
        basis: sido,
        text: '$sido에는 등록된 공공예식장이 없어요. 가까운 지역으로 찾아볼까요?',
        quickReplies: [
          for (final s in kSidoList.where((s) => s != sido).take(4))
            QuickReply('$s 예식장', text: '$s 공공예식장 추천해줘'),
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
    final more = _startMore([for (final v in list) venueCard(v)], '$sido 공공예식장', tab: 0);
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
    final daysLeft = date?.difference(DateTime.now()).inDays;
    // 권장 시기(예식 D-N)가 이미 지난 일: 남은 날보다 D-N이 크면 늦은 것
    bool late(ChecklistTask t) => daysLeft != null && t.dMinus > daysLeft;
    final lateCount = tasks.where(late).length;
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

  ChatMessage _help() => const ChatMessage(
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
