import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/region.dart';
import '../../../data/app_state.dart';
import '../../../data/models/policy.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/wedding_plan.dart';
import '../../policy/policy_detail_screen.dart';
import '../../policy/policy_matcher.dart';
import '../../vendor/demo_vendor_detail_screen.dart';
import '../../venue/venue_detail_screen.dart';
import '../chat_agent.dart';
import 'consult_tools.dart';
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

  static const _intentLabel = {
    ConsultIntent.recommend: '전체 추천',
    ConsultIntent.policy: '지원 정책',
    ConsultIntent.venue: '공공예식장',
    ConsultIntent.vendor: '업체 추천',
    ConsultIntent.budget: '예산 배분',
    ConsultIntent.schedule: '준비 순서',
    ConsultIntent.help: '일반 질문',
  };

  static const _slotLabel = {
    Slot.sido: '지역',
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
      if (!_isFilled(_asking!, _pending!)) {
        return _ask(_asking!, _pending!, retry: true);
      }
      return _process(_pending!);
    }
    _question = text;
    step.value = AgentStep.understand;
    return _process((await _understand(text)).u);
  }

  /// ① 질문 이해: Gemini가 있으면 Gemini, 실패하거나 없으면 규칙.
  /// 규칙으로 뽑은 값도 함께 써서, Gemini가 놓친 값은 규칙 결과로 채운다.
  Future<({Understanding u, bool isAnswer})> _understand(String text, {Slot? expecting}) async {
    final rule = _nlu.parse(text, expecting: expecting);
    final ai = await _llm?.understand(text, expecting: expecting);
    if (ai == null) {
      _nluNote = _llm == null ? '규칙(키워드)으로 이해' : 'Gemini 응답 없음 → 규칙(키워드)으로 이해';
      return (u: rule, isAnswer: false);
    }
    _nluNote = 'Gemini가 이해 (정해진 형식·값 범위 검사 후 사용, 놓친 값은 규칙으로 보완)';
    return (
      isAnswer: ai.isAnswer,
      u: Understanding(
        intent: ai.u.intent,
        facts: rule.facts.merge(ai.u.facts),
        topic: ai.u.topic ?? (ai.u.intent == ConsultIntent.policy ? rule.topic : null),
        item: ai.u.item ?? (ai.u.intent == ConsultIntent.vendor ? rule.item : null),
      ),
    );
  }

  /// ⑤ 답변 문장: 앱이 만든 답변(데이터 결과)을 Gemini가 질문에 맞게 다시 쓴다.
  /// 원문에 없는 숫자가 나오면 Gemini 문장을 버리고 원래 문장을 쓴다.
  Future<ChatMessage> _polish(ChatMessage m) async {
    final llm = _llm;
    if (llm == null || m.isQuestion) return m;
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
      case 'skip_ask':
        return _skipCurrent();
      case 'save_profile':
        _app.saveProfile(_app.profile.merge(_known));
        return const ChatMessage(
          fromUser: false,
          text: '이번 대화에서 알려주신 정보를 내 정보에 저장했어요. 다음 상담과 정책·업체 탭에도 반영돼요.',
        );
    }
    if (r.slot != null && _pending != null) {
      _known = _known.merge(_valueToFacts(Slot.values.byName(r.slot!), r.value));
      return _process(_pending!);
    }
    if (r.text != null) return reply(r.text!);
    return _help();
  }

  // ───────────────────────── 대화 흐름 ─────────────────────────

  Future<ChatMessage> _process(Understanding u) async {
    _known = _known.merge(u.facts);
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
  Future<ChatMessage> _finish(Understanding u, {List<String> skipped = const []}) async {
    step.value = AgentStep.lookup;
    _lookupNote = '';
    final m = await _answer(u);
    if (_llm != null) step.value = AgentStep.write;
    final out = await _polish(m);
    final what = [
      '목적 ${_intentLabel[u.intent]}',
      if (u.topic != null) '분야 ${u.topic!.label}',
      if (u.item != null) '항목 ${u.item!.label}',
    ].join(' · ');
    final used = (m.basis?.isNotEmpty ?? false) ? m.basis! : (_known.summary.isEmpty ? '없음' : _known.summary);
    return out.copyWith(trace: [
      '질문 이해 · $what — $_nluNote',
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
            Slot.age,
            Slot.stage,
            if (_known.stage == MarriageStage.married) Slot.marriedYears,
            if (u.topic == PolicyCategory.housing || u.topic == null) Slot.homeless,
          ],
        ConsultIntent.venue => [Slot.sido, Slot.guests],
        ConsultIntent.vendor => [
            Slot.sido,
            Slot.budget,
            if (u.item == VendorCategory.meal || u.item == VendorCategory.invitation) Slot.guests,
          ],
        ConsultIntent.budget => [Slot.budget, Slot.guests],
        ConsultIntent.schedule => [Slot.weddingDate],
        ConsultIntent.recommend => [Slot.sido, Slot.age, Slot.stage, Slot.guests, Slot.budget],
        ConsultIntent.help => const [],
      };

  List<Slot> _missing(Understanding u) =>
      _required(u).where((s) => !_skipped.contains(s) && !_isFilled(s, u)).toList();

  bool _isFilled(Slot s, Understanding u) => switch (s) {
        Slot.sido => _known.sido != null,
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
          '결혼 총예산은 어느 정도 생각하세요? 항목별 추천 예산을 계산할게요.',
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
      Slot.item => ('어떤 항목을 찾으세요?', const <QuickReply>[]),
    };
    final prefix = retry ? '죄송해요, 잘 알아듣지 못했어요. 아래에서 골라 주시거나 다시 적어 주세요.\n' : '';
    final known = _known.summary;
    return ChatMessage(
      fromUser: false,
      isQuestion: true,
      text: '$prefix$q${remaining != null && remaining > 1 ? '\n(확인할 것 $remaining개 중 하나예요)' : ''}',
      basis: known.isEmpty ? null : '지금까지 알려주신 정보: $known',
      quickReplies: [...options, const QuickReply('잘 모르겠어요', action: 'skip_ask')],
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
        ConsultIntent.venue => _venueAnswer(),
        ConsultIntent.vendor => _vendorAnswer(u.item!),
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
    final likely = matches.where((m) => m.level == MatchLevel.likely).length;
    _lookupNote = '정책 데이터를 정해진 규칙으로 판정 → 해당 가능 ${matches.length}건 '
        '(가능성 높음 $likely건)${topicNote.isEmpty ? '' : ' · ${topicNote.trim()} 분야만'}';
    final top = matches.take(3).toList();
    final region = _known.sido ?? '전국';
    final lines = [
      for (final m in top)
        '• ${m.policy.name}\n   ${m.reasons.take(2).join(', ')}'
            '${m.checks.isEmpty ? '' : ' / 확인할 것: ${m.checks.take(2).join(', ')}'}',
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
          : '받을 수 있는 ${topicNote}정책을 ${matches.length}건 찾았어요. '
              '그중 $likely건은 조건이 잘 맞고, 나머지는 직접 확인할 조건이 있어요.\n\n'
              '${lines.join('\n')}\n\n'
              '${tips.isEmpty ? '' : '${tips.join('\n')}\n'}'
              '대상 여부는 정해진 규칙으로 판정했고, 최종 확인은 담당 기관에서 해 주세요.',
      cards: [
        for (final m in top)
          ChatCard(
            title: m.policy.name,
            subtitle: '${m.policy.regionLabel} · ${m.policy.category.label}',
            icon: Icons.volunteer_activism,
            badge: m.level == MatchLevel.likely ? '해당 가능성 높음' : '조건 확인 필요',
            open: () => PolicyDetailScreen(match: m),
          ),
      ],
      sources: const ['청년 결혼 지원 정책 177건 (복지로·온통청년·지자체 공고)'],
      quickReplies: _withSave([
        if (u.topic != PolicyCategory.cash) const QuickReply('결혼 장려금도 보기', text: '결혼 장려금 정책 알려줘'),
        if (u.topic != PolicyCategory.housing) const QuickReply('주거 지원도 보기', text: '신혼집 주거 지원 정책 알려줘'),
        const QuickReply('공공예식장 추천', text: '공공예식장 추천해줘'),
      ]),
    );
  }

  Future<ChatMessage> _venueAnswer() async {
    final sido = _known.sido!;
    final guests = _known.guests;
    final list = await ConsultTools.searchVenues(sido: sido, guests: guests);
    _lookupNote = '$sido 공공예식장 ${list.length}곳 → 하객 수용 · 무료 · 예약 가능 순으로 정렬';
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
    return ChatMessage(
      fromUser: false,
      basis: [sido, if (guests != null) '하객 $guests명'].join(' · '),
      text: '$sido 공공예식장 ${list.length}곳 중에서 골랐어요.\n'
          '${guests != null ? '하객 $guests명을 수용할 수 있는 곳 ${list.where((v) => v.fits(guests) == true).length}곳, ' : ''}'
          '무료 대관 ${list.where((v) => v.isFree).length}곳, 정원 미확인 ${list.where((v) => v.capacity == null).length}곳이에요.\n\n'
          '${top.map((v) => '• ${v.name}\n   ${v.capacityLabel} · ${v.feeLabel} · ${v.bookingType.label}').join('\n')}\n\n'
          '정원·요금을 모르는 곳은 기관에 확인이 필요해요.',
      cards: [
        for (final v in top)
          ChatCard(
            title: v.name,
            subtitle: '${v.region} · ${v.capacityLabel} · ${v.feeLabel}',
            icon: Icons.location_city,
            badge: guests != null && v.fits(guests) == true ? '하객 수용' : (v.isLimited ? '기간 제한' : '예약 가능'),
            open: () => VenueDetailScreen(venue: v),
          ),
      ],
      sources: const ['전국 공공예식장 현황 · 정원·요금·사진: 공유누리·서울마이웨딩 수집'],
      quickReplies: _withSave(const [
        QuickReply('이 지역 지원 정책', text: '받을 수 있는 정책 알려줘'),
        QuickReply('식대 업체 추천', text: '식대 업체 추천해줘'),
      ]),
    );
  }

  Future<ChatMessage> _vendorAnswer(VendorCategory item) async {
    final sido = _known.sido!;
    final total = _known.budget ?? _app.plan.budget;
    final guests = _known.guests ?? _app.plan.guests;
    final (picks, inBudget, count, budget) =
        await ConsultTools.searchVendors(item: item, sido: sido, totalBudget: total, guests: guests);
    _lookupNote = '$sido ${item.label} 시연용 업체 $count곳 → 추천 예산 $budget만원 안 $inBudget곳, 평점순';
    return ChatMessage(
      fromUser: false,
      basis: '$sido · 총예산 ${formatManwon(total)}${_known.budget == null ? '(기본값)' : ''} · 하객 $guests명',
      text: '총예산 중 ${item.label} 추천 예산은 $budget만원(${item.budgetShare}%)이에요.\n'
          '$sido ${item.label} 업체 $count곳 중 예산 안은 $inBudget곳이에요. '
          '${inBudget == 0 ? '예산 안 업체가 없어 평점순으로 보여드릴게요.' : '평점순으로 골랐어요.'}\n\n'
          '${picks.map((v) => '• ${v.name.replaceFirst('[시연] ', '')} — ${v.priceText}, 예상 ${v.estimate(guests: guests)}만원, ★${v.rating}').join('\n')}\n\n'
          '(가격·평점은 시연용 가상 데이터예요)',
      cards: [
        for (final v in picks)
          ChatCard(
            title: v.name,
            subtitle: '${v.priceText} · 예상 ${v.estimate(guests: guests)}만원 · ★${v.rating}',
            icon: item.icon,
            badge: v.estimate(guests: guests) <= budget ? '예산 안' : '예산 초과',
            open: () => DemoVendorDetailScreen(vendor: v),
          ),
      ],
      sources: const ['시연용 가상 업체 데이터'],
      quickReplies: _withSave(const [
        QuickReply('예산 배분 보기', text: '예산 어떻게 나누면 돼?'),
        QuickReply('메이크업도 추천', text: '메이크업 추천해줘'),
      ]),
    );
  }

  ChatMessage _budgetAnswer() {
    final total = _known.budget!;
    final plan = ConsultTools.budgetPlan(total);
    _lookupNote = '앱 기본 배분 비율 × 총예산 ${formatManwon(total)}';
    return ChatMessage(
      fromUser: false,
      basis: '총예산 ${formatManwon(total)}${_known.guests != null ? ' · 하객 ${_known.guests}명' : ''}',
      text: '추천 배분이에요.\n'
          '${plan.map((e) => '• ${e.$1.label} ${e.$2}만원 (${e.$1.budgetShare}%)').join('\n')}\n'
          '• 대관·기타 ${total * 5 ~/ 100}만원 (5%)\n\n'
          '공공예식장은 대관료가 무료이거나 저렴한 곳이 많아, 아낀 비용을 다른 항목에 쓸 수 있어요.',
      sources: const ['앱 기본 배분 비율 (조정 가능)'],
      quickReplies: _withSave(const [
        QuickReply('드레스 추천', text: '예산 안에서 드레스 추천해줘'),
        QuickReply('무료 공공예식장', text: '공공예식장 추천해줘'),
      ]),
    );
  }

  ChatMessage _scheduleAnswer() {
    final tasks = ConsultTools.nextTasks();
    _lookupNote = '예식일 기준 체크리스트 ${_app.tasks.length}개 중 아직 안 한 일을 순서대로';
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
        : (await ConsultTools.searchVenues(sido: _known.sido!, guests: _known.guests)).take(2).toList();
    final policies = (await ConsultTools.matchPolicies(_known)).take(3).toList();
    final budget = _known.budget;
    final top3 = budget == null ? const [] : ConsultTools.budgetPlan(budget).take(3).toList();
    final tasks = ConsultTools.nextTasks(count: 2);
    _lookupNote = '예식장 검색 · 정책 판정 · 예산 배분 · 할 일 도구의 결과를 모아 정리';

    return ChatMessage(
      fromUser: false,
      basis: _known.summary,
      text: [
        if (venues.isNotEmpty)
          '🏛 공공예식장: ${venues.map((v) => '${v.name}(${v.capacityLabel}, ${v.feeLabel})').join(', ')}',
        if (policies.isNotEmpty) '🎁 받을 수 있는 정책: ${policies.map((m) => m.policy.name).join(', ')}',
        if (top3.isNotEmpty) '💰 예산 배분: ${top3.map((e) => '${e.$1.label} ${e.$2}만원').join(', ')} …',
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
          ),
        for (final m in policies)
          ChatCard(
            title: m.policy.name,
            subtitle: '${m.policy.regionLabel} · ${m.policy.category.label}',
            icon: Icons.volunteer_activism,
            badge: m.level == MatchLevel.likely ? '해당 가능성 높음' : '조건 확인 필요',
            open: () => PolicyDetailScreen(match: m),
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
