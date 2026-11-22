part of 'consult_agent.dart';

/// 새 답 화면 (2026-11-20): 앱이 만든 답(ChatMessage: 글·카드·버튼)을 블록 답으로 바꾼다.
/// ② 앱이 조회·판정한 결과로 [AnswerFacts]를 만들고 → ④ Gemini가 블록 배치 → ⑤ 앱 검사 K1~K5 + Gemini 검토 →
/// 걸리면 한 번 다시 → 또 걸리면 기본 틀. 예전 글(text)은 대화 기억·평가용으로 그대로 두고 접힌 줄에도 넣는다.
extension _Present on ConsultAgent {
  /// 블록 답으로 바꾸기 (이미 블록이 있거나 사용자 메시지면 그대로)
  Future<ChatMessage> _present(ChatMessage m) async {
    if (!ConsultAgent.useBlocks || m.fromUser || m.blocks.isNotEmpty) return m;
    final sw = Stopwatch()..start();
    if (_llm != null && !m.isQuestion) step.value = AgentStep.write;
    final f = await _factsFor(m);
    final c = await _composer.compose(f);
    sw.stop();
    var blocks = c.blocks;
    // 시작 인사·도움말처럼 데이터를 찾지 않은 답은 접힌 줄(출처·과정)이 인사말 반복뿐이라 뺀다
    if (_lastU == null && m.sources.isEmpty && m.cards.isEmpty && !m.isQuestion) {
      blocks = blocks.where((b) => b.type != BlockType.fold).toList();
    }
    // 예상 총 예식비 (Red Team P1-2): 예식장 답에는 '대관료 무료'만 두지 않고 식대·꽃장식 등 예상 범위를 한 번 (참고 단가표 추정)
    if (f.kind.isVenue) {
      final shown = [
        for (final c in blocks.allCards)
          if (c.ref.startsWith('venue:') && f.byId(c.ref)?.venue != null) f.byId(c.ref)!.venue!,
      ];
      final vs = shown.isNotEmpty ? shown : [for (final i in f.items) if (i.venue != null) i.venue!];
      final est = vs.isEmpty
          ? null
          : VenueCostEstimate.of(await Repos.vendor.options(),
              guests: f.scope?.guests ?? (_plan?.args['no_guests'] == true ? null : _known.guests),
              budget: _known.budget,
              allFree: vs.every((v) => v.isFree),
              anyFree: vs.any((v) => v.isFree));
      if (est != null) {
        final at = blocks.indexWhere((b) => b.type != BlockType.headline && b.type != BlockType.ask);
        blocks = [...blocks]..insert(at < 0 ? blocks.length : at, est.block);
        blocks = [
          for (final b in blocks)
            b.type == BlockType.fold
                ? b.copyWith(calc: est.formula, pending: [...b.pending, '실제 식대·꽃장식 비용 (업체 견적으로 확인)'].take(6).toList())
                : b,
        ];
      }
    }
    final scope = _scopeNote;
    if (scope != null) {
      final at = blocks.indexWhere((b) => b.type != BlockType.headline);
      blocks = [...blocks]..insert(at < 0 ? blocks.length : at, AnswerBlock(BlockType.notice, text: scope));
    }
    final note = _appliedNote;
    if (note != null) {
      final at = blocks.indexWhere((b) => b.type == BlockType.next || b.type == BlockType.fold);
      blocks = [...blocks]..insert(at < 0 ? blocks.length : at, AnswerBlock(BlockType.notice, text: note));
    }
    final replies = m.isQuestion
        ? m.quickReplies
        : [
            ..._scopeReplies,
            ...AnswerAi.repliesFor(blocks, f),
            for (final r in m.quickReplies)
              if (r.action == 'undo_profile' || r.action == 'save_profile') _shortReply(r),
          ];
    lastComposed = c;
    lastComposeMs = sw.elapsedMilliseconds;
    lastFacts = f;
    _prevAnswer = PrevAnswer(
      question: _question,
      headline: blocks.headline ?? '',
      ids: [for (final x in blocks.allCards) x.ref.split(':').last],
      text: blocks.plainText,
    );
    return m.copyWith(blocks: blocks, quickReplies: replies);
  }

  /// 답 제목·더 보기 이름에 쓰는 찾은 범위: 마지막 검색의 구(여러 개면 ·로) → 없으면 시도
  String _placeOr(String sido) {
    final p = _lastScope?.placeLabel ?? '';
    return p.isEmpty ? sido : p;
  }

  /// 칩 이름을 12자 안으로 (F7). 동작은 그대로
  static QuickReply _shortReply(QuickReply r) {
    final more = RegExp(r'^더 보기 \((\d+)(곳|건|개) 남음\)$').firstMatch(r.label);
    final label = more != null
        ? '${more[1]}${more[2]} 더 보기'
        : const {
              '체크리스트에서 금액 정하기': '금액 정하기',
              '이 정보를 내 정보에 저장': '내 정보에 저장',
              '예식장 탭에서 전체 보기': '예식장 탭 열기',
              '정책 탭에서 전체 보기': '정책 탭 열기',
              '업체 탭에서 전체 보기': '업체 탭 열기',
            }[r.label] ??
            (r.label.length > 12 && RegExp(r'^(.+?)·.+ 업체 보기$').hasMatch(r.label)
                ? '${RegExp(r'^(.+?)·').firstMatch(r.label)![1]} 업체 보기'
                : r.label);
    return label == r.label ? r : QuickReply(label, slot: r.slot, value: r.value, text: r.text, action: r.action);
  }

  /// 답 종류: 되묻기 → 답 함수가 준 힌트 → 이번 질문의 목적 → 카드 종류
  AnswerKind _kindOf(ChatMessage m) {
    if (m.isQuestion) return AnswerKind.ask;
    if (_hint != null) return _hint!.kind;
    final u = _lastU;
    final ref = m.cards.firstOrNull?.ref?.split(':').first;
    if (u != null) {
      switch (u.intent) {
        case ConsultIntent.venue:
          if (u.kind == AskKind.detail && m.cards.length == 1) return AnswerKind.venueDetail;
          if (u.kind == AskKind.compare) return AnswerKind.venueCompare;
          return _askDate != null ? AnswerKind.venueDate : AnswerKind.venueList;
        case ConsultIntent.policy:
          return m.cards.length == 1 && m.basis == m.cards.first.title ? AnswerKind.policyDetail : AnswerKind.policyList;
        case ConsultIntent.vendor:
          return AnswerKind.vendorList;
        case ConsultIntent.budget:
          return u.kind == AskKind.calc ? AnswerKind.calc : (u.kind == AskKind.cost ? AnswerKind.cost : AnswerKind.budget);
        case ConsultIntent.schedule:
          return AnswerKind.schedule;
        case ConsultIntent.help:
          return u.kind == AskKind.general || m.aiWritten ? AnswerKind.general : AnswerKind.other;
        case ConsultIntent.recommend:
          return AnswerKind.other;
      }
    }
    return switch (ref) {
      'venue' => AnswerKind.venueList,
      'policy' => AnswerKind.policyList,
      'vendor' || 'real' => AnswerKind.vendorList,
      _ => m.aiWritten ? AnswerKind.general : AnswerKind.other,
    };
  }

  Future<AnswerFacts> _factsFor(ChatMessage m) async {
    final kind = _kindOf(m);
    // 더 보기로 나눠 보여 주는 답이면 전체 결과를 사실로 (건수·K1 검사 기준)
    final paged = m.cards.isNotEmpty &&
        _moreCards.length > m.cards.length &&
        _moreShown == m.cards.length &&
        [for (final c in _moreCards.take(m.cards.length)) c.ref].join() == [for (final c in m.cards) c.ref].join();
    final cards = paged ? _moreCards : m.cards;
    final scope = kind == AnswerKind.venueList || kind == AnswerKind.venueDate
        ? _lastScope
        : QueryScope(guests: _known.guests, date: _askDate);
    final items = await _itemsFor(cards, scope);
    // K2 이름 검사용 이름 목록 (한 번만): 괄호 앞 이름 5자 이상
    // (Gemini가 설명을 쓸 때만 필요. 못 읽으면 이름 검사 없이 숫자 검사만)
    if (_llm != null && AnswerChecks.knownNames.isEmpty) {
      try {
        AnswerChecks.knownNames = {
          for (final v in await Repos.venue.loadAll())
            if (v.name.split('(').first.trim().length >= 5) v.name.split('(').first.trim(),
          for (final p in await Repos.policy.loadAll())
            if (p.name.split('(').first.trim().length >= 6) p.name.split('(').first.trim(),
        };
      } catch (_) {}
    }
    // 카드 이유 후보: 데이터로 참인 것만 앱이 문장으로 (Gemini는 키만 고름)
    fillReasons(items, guests: scope?.guests ?? _known.guests, date: scope?.date);
    final options = <NextOption>[
      for (final r in m.quickReplies.map(_shortReply))
        if (r.action != 'undo_profile' && r.action != 'save_profile')
          NextOption(r, kind: switch (r.action) {
            'more' => 'more',
            'refine' => 'widen',
            null when r.slot == null => 'next',
            _ => 'action',
          }),
      if (kind == AnswerKind.venueList || kind == AnswerKind.venueDate) ...await _widenOptions(scope, items.length),
    ];
    // "3개만"처럼 수를 정했으면 더 보기는 없다 (넓히기 칩은 그대로)
    if (_cardLimit != null) options.removeWhere((o) => o.kind == 'more');
    // 넓히기 칩과 같은 일을 하는 예전 글 칩은 뺀다
    if (options.any((o) => o.kind == 'widen')) {
      options.removeWhere((o) => o.kind == 'next' && RegExp(r'^(조건 없이 보기|.. 예식장)$').hasMatch(o.label));
    }
    return AnswerFacts(
      question: _question,
      kind: kind,
      scope: scope,
      items: items,
      total: cards.length,
      headBadges: headBadgesFor(kind, items, scope),
      options: options,
      notes: [for (final l in m.text.split('\n')) if (l.trim().startsWith('•') && l.contains('→')) l.trim()],
      sources: m.sources,
      log: m.trace,
      // '내 정보에 반영했어요' 줄은 알림 블록이 따로 보여 준다
      detail: m.text.split('\n').where((l) => !l.startsWith('내 정보에 반영했어요')).join('\n').trim(),
      hint: _hint,
      previous: _prevAnswer,
      context: _contextBefore,
      aiGeneral: m.aiWritten && kind == AnswerKind.general,
      followUp: _followUpTurn,
      templateOnly: _templateOnly,
      allowMixed: _lastU?.intent == ConsultIntent.recommend || _lastU?.also != null,
      cardLimit: _cardLimit,
      // 답의 주인공 카드 (질문에 이름이 나온 대출이 소득 초과일 때)
      pinned: [for (final c in m.cards) if (c.badge == '소득 초과' && c.ref != null) c.ref!],
      // '어떻게 찾았나요' 사용자 말 요약 재료 (Red Team P1-3)
      steps: _funnel,
      pending: [for (final x in _unsupported) '"$x" (앱 데이터로 확인할 수 없어요)'],
      profile: _known,
    );
  }

  /// 카드 → 사실 (예식장·정책·업체는 데이터에서 다시 찾아 앱이 값·배지를 정함)
  Future<List<FactItem>> _itemsFor(List<ChatCard> cards, QueryScope? scope) async {
    if (cards.isEmpty) return const [];
    final venues = {for (final v in await Repos.venue.loadAll()) v.id: v};
    final bookings = Repos.booking.cached ?? const <String, BookingStatus>{};
    final needPolicy = cards.any((c) => c.ref?.startsWith('policy:') ?? false);
    final judged = needPolicy ? PolicyMatcher.judge(await Repos.policy.loadAll(), PolicyProfile.fromUser(_known)) : null;
    final policies = needPolicy ? {for (final p in await Repos.policy.loadAll()) p.id: p} : const <String, Policy>{};
    final needDemo = cards.any((c) => c.ref?.startsWith('vendor:') ?? false);
    final demo = needDemo ? {for (final v in await Repos.vendor.demoVendors()) v.id: v} : const <String, DemoVendor>{};
    final needReal = cards.any((c) => c.ref?.startsWith('real:') ?? false);
    final real = needReal ? {for (final v in await Repos.vendor.realVendors()) v.id: v} : const <String, RealVendor>{};
    final multiSido = (scope?.sidos.length ?? 0) > 1;
    final guests = _known.guests ?? _app.plan.guests;
    return [
      for (final c in cards)
        switch (c.ref?.split(':')) {
          ['venue', final id] when venues[id] != null =>
            (venueFact(venues[id]!,
                scope: scope,
                booking: bookings[id],
                multiSido: multiSido,
                // 기간 질문의 '8일 가능'·'13일 모두 가능' 배지와 가능한 날 줄은 앱이 센 값 그대로
                override: RegExp(r'^\d+일 (모두 )?가능$').hasMatch(c.badge ?? '')
                    ? BlockBadge(c.badge!, Tone.good)
                    : RegExp(r'^[\d.]+km$').hasMatch(c.badge ?? '')
                        ? BlockBadge(c.badge!, Tone.info)
                        : null))
              ..note = c.note,
          ['policy', final id] when policies[id] != null => () {
              final hit = judged!.matches.where((x) => x.policy.id == id).firstOrNull;
              final miss = judged.misses.where((x) => x.policy.id == id).firstOrNull;
              // 소득 상한을 넘은 정책 (앱이 원문 상한과 비교한 값)
              if (c.badge == '소득 초과') return policyFact(policies[id]!, miss: true, missReason: '소득 초과');
              return policyFact(policies[id]!, level: hit?.level, miss: hit == null && miss != null, missReason: miss?.reason);
            }(),
          ['vendor', final id] when demo[id] != null =>
            demoVendorFact(demo[id]!, budget: _hintBudget ?? _app.budgetOf(demo[id]!.category), guests: guests),
          ['real', final id] when real[id] != null => realVendorFact(real[id]!),
          _ => cardFact(c),
        },
    ];
  }

  /// 범위 넓히기 칩 (R9): 맞닿은 구 → 시 전체 → 가까운 시도. 누르면 Gemini 없이 앱이 조건을 고쳐 다시 찾는다
  Future<List<NextOption>> _widenOptions(QueryScope? s, int count) async {
    if (s == null) return const [];
    final all = await Repos.venue.loadAll();
    final out = <NextOption>[];
    QuickReply refine(String label, Map<String, Object?> set, [List<String> remove = const []]) =>
        QuickReply(label, action: 'refine', value: <String, Object?>{'set': set, 'remove': remove});
    final sido = s.sidos.length == 1 ? s.sidos.first : null;
    if (sido != null && s.towns.isNotEmpty) {
      final adj = VenueScope.adjacentTowns(all, sido, s.towns);
      if (adj.isNotEmpty) {
        final label = '${adj.map(VenueScope.shortTown).join('·')}까지';
        out.add(NextOption(refine(label.length <= 12 ? label : '${VenueScope.shortTown(adj.first)}까지', {'sigungu': [...s.towns, ...adj]}),
            kind: 'widen'));
      }
      out.add(NextOption(refine('$sido 전체', const {}, const ['sigungu']), kind: 'widen'));
    } else if (sido != null && count < 3) {
      for (final (near, n) in VenueScope.nearbySidos(all, sido, n: 3)) {
        out.add(NextOption(refine('$near $n곳', {'sido': [near]}, const ['sigungu', 'exclude_sigungu']), kind: 'widen'));
      }
    }
    if (s.freeOnly && count < 3) out.add(NextOption(refine('유료도 보기', const {}, const ['free_only']), kind: 'widen'));
    return out;
  }

  /// 직전 2턴 (검토용)
  String get _contextNow => [
        for (final t in _turns.skip(_turns.length > 2 ? _turns.length - 2 : 0))
          '사용자: ${t.user}\n답: ${t.bot.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')}',
      ].join('\n');

  /// 조건 칩 ✕ · + 조건 · 넓히기: 앞 예식장 조건을 앱이 고쳐서 다시 찾는다 (Gemini 도구 고르기 없음)
  Future<ChatMessage> _refine(QuickReply r) async {
    final v = (r.value as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
    final base = <String, Object?>{...?_lastVenueArgs};
    final set = <String, Object?>{...?(v['set'] as Map?)?.cast<String, Object?>()};
    final remove = [for (final x in (v['remove'] as List?) ?? const []) if (x is String) x];
    if (set['needs'] is List && base['needs'] is List) {
      set['needs'] = {...(base['needs'] as List), ...(set['needs'] as List)}.toList();
    }
    if (set.containsKey('sido')) base.remove('sigungu');
    base.addAll(set);
    if (set.containsKey('sigungu')) base.remove('whole_sido');
    for (final k in remove) {
      base.remove(k);
      if (k == 'date') base.removeWhere((k, _) => const ['date_from', 'date_to', 'weekdays'].contains(k));
      if (k == 'sigungu') base['whole_sido'] = true;
      if (k == 'guests') base['no_guests'] = true;
    }
    final p = ToolPlanner.parse('search_venues', base)!;
    _question = r.label;
    _contextBefore = _contextNow;
    _followUpTurn = true;
    return _runPlan(p, r.label, note: '조건 칩으로 앞 조건을 고쳐 다시 찾음 (Gemini 호출 없음): ${jsonEncode(p.args)}');
  }

  // ───────────────────────── ③ 보충 조사 (앱 데이터 밖 질문만) ─────────────────────────

  /// 장소 근처 예식장: Google 지도로 기준 장소 좌표만 받고, 거리는 앱이 좌표로 계산한다 (R4).
  /// 장소를 말하지 않았으면 먼저 되묻는다 (R10)
  Future<ChatMessage> _nearPlaceAnswer(AgentPlan p) async {
    final place = p.place;
    if (place == null) {
      final cands = p.placeCandidates.where((c) => c.length <= 10).take(3).toList();
      _lookupNote = '기준 장소가 없어 되물음 (후보는 Gemini가 내 지역 근처로 제안)';
      _hint = const AnswerHint(kind: AnswerKind.ask, headline: '어느 역 기준으로 찾을까요?');
      return ChatMessage(
        fromUser: false,
        isQuestion: true,
        text: '어느 역(장소) 기준으로 찾을까요? 아래에서 고르거나 이름을 적어 주세요.',
        quickReplies: [
          for (final c in cands) QuickReply(c, text: '$c 근처 공공예식장'),
          if (cands.isEmpty) const QuickReply('내 지역 예식장', text: '공공예식장 추천해줘'),
        ],
      );
    }
    final loc = await _llm?.locate(place);
    if (loc == null) {
      _lookupNote = 'Google 지도에서 "$place" 위치를 찾지 못함';
      _hint = AnswerHint(
          kind: AnswerKind.other,
          headline: '$place 위치를 찾지 못했어요',
          sentence: _llm == null || GeminiClient.pausedUntil != null ? '지도 조회가 지금 안 돼서 잠시 뒤 다시 물어봐 주세요.' : '역 이름을 정확히 적어 주세요.');
      return ChatMessage(
        fromUser: false,
        text: '"$place" 위치를 찾지 못했어요. 역 이름을 정확히 적어 주시면 다시 찾아 드릴게요.',
        quickReplies: const [QuickReply('공공예식장 추천', text: '공공예식장 추천해줘')],
      );
    }
    final all = await Repos.venue.loadAll();
    final sidos = p.venue?.sidos ?? const <String>[];
    final ranked = [
      for (final v in all)
        if (v.lat != 0 && (sidos.isEmpty || sidos.contains(v.sido))) (v, VenueScope.km(loc.lat, loc.lng, v.lat, v.lng)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final near = ranked.where((e) => e.$2 <= 30).take(12).toList();
    String km(double d) => d < 10 ? d.toStringAsFixed(1) : d.round().toString();
    String short(String n) {
      final x = n.split('(').first.trim();
      return x.length > 10 ? '${x.substring(0, 9)}…' : x;
    }

    _lookupNote = 'Google 지도로 "$place" 좌표(${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)})만 받고 '
        '앱이 예식장 ${ranked.length}곳과의 직선 거리를 계산 → 30km 안 ${near.length}곳';
    _lastScope = QueryScope(guests: _known.guests);
    if (near.isEmpty) {
      _hint = AnswerHint(kind: AnswerKind.venueList, headline: '$place 30km 안에는 없어요');
      return ChatMessage(fromUser: false, text: '$place에서 30km 안에 공공예식장이 없어요.', quickReplies: ConsultAgent._starterReplies);
    }
    final cards = [for (final (v, d) in near) _venueCard(v, badge: '${km(d)}km')];
    final more = _startMore(cards, '$place 근처 공공예식장', tab: 0);
    _hint = AnswerHint(
      kind: AnswerKind.venueList,
      // 제목은 24자 안 (F1): 길면 장소 + 개수로, 가장 가까운 곳은 순위에서 (평가 X07)
      headline: '$place에서 가장 가까운 곳은 ${short(near.first.$1.name)}'.length <= 24
          ? '$place에서 가장 가까운 곳은 ${short(near.first.$1.name)}'
          : '$place 근처 공공예식장 ${near.length}곳',
      sentence: '직선 거리라 걷는 길은 더 길 수 있어요.',
      ranking: [for (final (v, d) in near.take(3)) '${short(v.name)} · ${km(d)}km'],
      web: [WebItem(text: '$place 위치 (${loc.name})', url: loc.uri, source: 'Google 지도')],
    );
    return ChatMessage(
      fromUser: false,
      basis: '$place 기준 직선 거리',
      text: '$place(${loc.name})에서 가까운 공공예식장이에요 (직선 거리).\n'
          '${near.take(3).map((e) => '• ${e.$1.name} — ${km(e.$2)}km · ${e.$1.capacityLabel} · ${e.$1.feeLabel}').join('\n')}',
      cards: cards.take(3).toList(),
      sources: ['장소 위치: Google 지도 (${loc.name})', '거리: 앱이 좌표로 계산 (직선)', '전국 공공예식장 현황 (좌표)'],
      quickReplies: [...more, const QuickReply('주차 되는 곳', text: '그중에 주차 되는 곳')],
    );
  }

  /// 앱 데이터에 없는 사실 (공고 기간 등): Google 검색 그라운딩. 출처가 없으면 쓰지 않는다 (R12).
  /// 예식장의 빈 값(정원·요금)은 웹으로 채우지 않는다 (R2) — 그런 질문은 도구 고르기에서 venue_info로 간다
  /// 사설·호텔·일반 웨딩홀처럼 앱 데이터(공공예식장)에 없는 예식장 질문: 웹 검색(출처 있는 것만) + 범위 안내 + 공공예식장 보기 칩.
  /// Gemini가 없거나 검색 결과가 없으면 지어내지 않고 '앱에는 공공예식장만 있다'고 안내
  Future<ChatMessage> _outOfScopeVenueAnswer(String text, String word) async {
    final sido = [for (final s in kSidoList) if (text.contains(s)) s].firstOrNull ?? _known.sido;
    final place = sido == null ? '' : '$sido ';
    _scopeNote = '앱에는 공공예식장 240곳 데이터만 있어요. $word 예식장은 웹 검색 결과로 보여 드리고, 가격·예약은 각 업체에 직접 확인해 주세요.';
    _scopeReplies = [QuickReply('${place}공공예식장 보기', text: '${place}공공예식장 추천해줘')];
    _lookupNote = '"$word" 예식장은 앱 데이터(공공예식장) 밖이라 공공예식장 검색을 쓰지 않음';
    if (_llm != null) {
      final m = await _webAnswer('$place$word 웨딩홀 추천 (공공예식장 제외)',
          venueList: true, headline: '$place$word 예식장 · 웹 검색', notFound: '$place$word 예식장을 웹에서 찾지 못했어요');
      // Gemini 설명을 다시 쓰지 않는다: 앱 조회 결과가 없어 "0건·찾지 못했어요"처럼 앱 데이터 문제로 읽히게 씀 (11-21 실측)
      _templateOnly ??= '앱 데이터 밖 예식장 (범위 안내 + 웹 목록)';
      return m;
    }
    _hint = AnswerHint(
      kind: AnswerKind.other,
      headline: '$word 예식장은 앱 데이터에 없어요',
      sentence: '공공예식장이라면 조건에 맞게 찾아 드릴 수 있어요.',
    );
    return ChatMessage(
      fromUser: false,
      text: '앱에는 공공예식장 240곳 데이터만 있어서 $word 예식장 목록은 드릴 수 없어요. 공공예식장이라면 조건에 맞게 찾아 드릴 수 있어요.',
      quickReplies: ConsultAgent._starterReplies,
    );
  }

  Future<ChatMessage> _webAnswer(String query, {bool venueList = false, String? headline, String? notFound}) async {
    final r = await _llm!.research(query, venueList: venueList);
    if (r == null && _llm.lastOffTopic) return _offTopicAnswer();
    // 앱 정책 데이터에 같은 이름이 있으면 카드로 함께 (신청 링크는 앱 데이터)
    final q = normName(query);
    final policies = [
      for (final p in await Repos.policy.loadAll())
        if (normName(p.name.split('(').first).length >= 4 && q.contains(normName(p.name.split('(').first))) p,
    ].take(1).toList();
    final cards = [
      for (final p in policies)
        ChatCard(
          title: p.name,
          subtitle: '${p.regionLabel} · ${p.category.label}',
          icon: Icons.volunteer_activism,
          open: () => PolicyDetailScreen(match: PolicyMatch(p, MatchLevel.check, const [], const [])),
          ref: 'policy:${p.id}',
        ),
    ];
    if (r == null) {
      _lookupNote = 'Google 검색으로 "$query"를 찾았지만 출처 있는 답이 없어 쓰지 않음';
      _hint = AnswerHint(
        kind: AnswerKind.other,
        headline: notFound ?? '웹에서 확인하지 못했어요',
        sentence: venueList
            ? '지도 앱에서 지역 이름과 "웨딩홀"로 찾아 보세요.'
            : (cards.isEmpty ? '기관 공고에서 직접 확인해 주세요.' : '아래 정책의 신청 페이지에서 확인해 주세요.'),
      );
      return ChatMessage(
        fromUser: false,
        text: venueList
            ? '웹 검색에서 출처가 있는 예식장 목록을 찾지 못했어요. 지도 앱에서 지역 이름과 "웨딩홀"로 찾아 보세요.'
            : '"$query"는 웹에서 출처가 있는 답을 찾지 못했어요. 기관 공고에서 직접 확인해 주세요.',
        cards: cards,
        quickReplies: ConsultAgent._starterReplies,
      );
    }
    final first = RegExp(r'^.+?(요|다)[.!?]?(\s|$)').firstMatch(r.text)?.group(0)?.trim() ?? r.text;
    _lookupNote = 'Google 검색 그라운딩: 검색어 ${r.queries.take(2).join(', ')} → 출처 ${r.links.length}개';
    _hint = AnswerHint(
      kind: AnswerKind.other,
      // 첫 문장이 길면 무엇을 찾았는지(검색어)를 제목으로 (평가 X19: '웹에서 찾은 정보'만으로는 무슨 답인지 모름)
      headline: headline ?? (first.length <= 24 ? first : (query.length <= 24 ? query : '${query.substring(0, 23)}…')),
      headBadges: const [BlockBadge('웹 정보 · 확인 필요', Tone.check)],
      web: [
        WebItem(text: r.text, url: r.links.first.uri, source: r.links.first.title),
        for (final l in r.links.skip(1).take(2)) WebItem(text: '다른 출처', url: l.uri, source: l.title),
      ],
      searchQueries: r.queries,
    );
    final now = DateTime.now();
    return ChatMessage(
      fromUser: false,
      basis: '웹에서 찾은 정보 · 확인 필요',
      text: r.text,
      cards: cards,
      sources: [
        for (final l in r.links) '${l.title} (${now.month}/${now.day} 확인)',
        'Google 검색 (웹 정보는 바뀔 수 있어요)',
      ],
      quickReplies: ConsultAgent._starterReplies,
    );
  }

  /// 공공예식장(앱 데이터) vs 일반 예식장(한국소비자원 참가격 조사) 금액 비교 표.
  /// 숫자는 모두 앱이 데이터에서 계산한다: 공공 = 수집한 대관료 + 참고 단가표 추정, 일반 = 소비자원 지역별 중간값.
  /// Gemini는 부르지 않는다 (조사값·추정값 숫자를 바꿔 쓰면 안 되므로)
  /// 소비자원 조사(2026년 9월, 시·도·권역 단위, 대관료·식대·보증인원·꽃장식 등) 밖을 묻는지
  ({String what, QuickReply? alt})? _consumerGap(String text, String? askedSido) {
    final year = RegExp(r'((?:19|20)\d{2})\s*년').firstMatch(text);
    if (year != null && year[1] != '2026') return (what: '${year[1]}년 가격', alt: null);
    if (RegExp(r'작년|지난해|재작년|내년|후년|전망|추이|변화|올랐|오를|인상|예전').hasMatch(text)) {
      return (what: '다른 시기의 가격이나 가격 변화', alt: null);
    }
    final t = findSigungu(text, sido: askedSido ?? _known.sido);
    if (t != null && t.$1 != '서울') {
      return (
        what: '${t.$2} 단위 가격',
        alt: QuickReply('${t.$1} 기준으로 보기', text: '${t.$1} 공공예식장과 일반 예식장 금액 비교해줘'),
      );
    }
    final item = RegExp(r'축가|축하\s*공연|주례|도우미|원판|플라워\s*샤워|축주|포토\s*테이블|한복').firstMatch(text);
    if (item != null) return (what: '${item[0]} 비용', alt: null);
    return null;
  }

  /// 가격 질문인데 앱 데이터 도구로 답할 수 없을 때 (Gemini 일반 안내 대신, 11-22)
  ChatMessage _noPriceData() {
    _templateOnly = '가격 정보 없음';
    _lookupNote = '가격 질문이 앱 데이터 도구에 맞지 않아 일반 안내(Gemini)로 답하지 않음';
    const have = '앱에서 볼 수 있는 가격은 공공예식장 대관료, 한국소비자원 일반 예식장 조사(2026년 9월), '
        '참고 단가표로 계산한 추정 비용, [시연] 업체 가격이에요.';
    _hint = const AnswerHint(
      kind: AnswerKind.other,
      headline: '정보가 없어 답변드리기 어려워요',
      sentence: '물어보신 가격 정보는 앱 데이터에 없어요. $have',
    );
    return const ChatMessage(
      fromUser: false,
      text: '물어보신 가격 정보는 앱 데이터에 없어서 답변드리기 어려워요. $have 정확한 금액은 업체나 기관에 직접 확인해 주세요.',
      quickReplies: [
        QuickReply('공공·일반 금액 비교', text: '공공예식장과 일반 예식장 금액 비교해줘'),
        QuickReply('결혼 비용 총액', text: '공공예식장 대관료 말고 실제로 총 얼마 들어?'),
      ],
    );
  }

  /// 데이터 밖 질문: 다른 값으로 채우지 않고 무엇이 있는지만 안내
  ChatMessage _noConsumerData(String what, ConsumerPrices prices, {QuickReply? alt}) {
    _lastCostCompare = true;
    _templateOnly = '소비자원 조사 범위 밖';
    _lookupNote = '"$what"는 한국소비자원 ${prices.surveyLabel} 조사에 없어 답하지 않음 (다른 값으로 대신하지 않음)';
    final have = '앱에는 한국소비자원 ${prices.surveyLabel} 조사의 시·도(권역)별 대관료·식대·최소 보증인원·꽃장식 등 추가금 값만 있어요.';
    _hint = AnswerHint(
      kind: AnswerKind.other,
      headline: '정보가 없어 답변드리기 어려워요',
      sentence: '$what 정보는 없어요. $have',
    );
    return ChatMessage(
      fromUser: false,
      text: '$what 정보는 앱 데이터에 없어서 답변드리기 어려워요. $have 정확한 금액은 예식장에 직접 견적을 받아 확인해 주세요.',
      sources: ['${prices.source} (${prices.surveyLabel} 조사)'],
      quickReplies: [?alt, const QuickReply('공공·일반 금액 비교', text: '공공예식장과 일반 예식장 금액 비교해줘')],
    );
  }

  Future<ChatMessage> _venueCostCompareAnswer(String text, {String? followSido}) async {
    _lastCostCompare = true;
    final asked = [for (final s in kSidoList) if (text.contains(s)) s].firstOrNull;
    final sido = asked ?? followSido ?? _known.sido;
    _lastCostSido = sido;
    final town = asked == null || asked == _known.sido ? _known.sigungu : findSigungu(text, sido: asked)?.$2;
    final prices = await ConsumerPrices.load();
    // 소비자원 조사 범위 밖(다른 시기·시군구 단위·조사에 없는 항목·지역)은 다른 값으로 채우지 않고 '정보 없음' (11-22 규칙)
    final gap = _consumerGap(text, asked ?? followSido);
    if (gap != null) return _noConsumerData(gap.what, prices, alt: gap.alt);
    final region = prices.region(sido, sigungu: town);
    if (region == null) return _noConsumerData('${sido ?? '그'} 지역 일반 예식장 가격', prices);
    final venues = [for (final v in await Repos.venue.loadAll()) if (sido == null || sidoMatches(v.sido, sido)) v];
    final free = venues.where((v) => v.rentalFee == 0).length;
    final paid = [for (final v in venues) if ((v.rentalFee ?? 0) > 0) v.rentalFee! / 10000]..sort();
    final unknownFee = venues.where((v) => v.rentalFee == null).length;
    final paidMedian = paid.isEmpty ? null : paid[paid.length ~/ 2].round();
    final guestsGiven = _known.guests != null;
    final guests = _known.guests ?? VenueCostEstimate.defaultGuests;
    final est = VenueCostEstimate.of(await Repos.vendor.options(), guests: guests);
    String won(num manwon) => '${VenueCostEstimate.fmt(manwon.round())}만원';
    String meal(num manwon) => '${manwon.toStringAsFixed(manwon % 1 == 0 ? 0 : 1)}만원';
    final place = sido == null ? '전국' : sido;
    final minG = region.minGuests.median.round();
    final billed = guests < minG ? minG : guests; // 일반 예식장은 최소 보증인원만큼 식대를 낸다
    // 일반 예식장 추가금 (참가격 선택품목 권역 중간값): 꽃장식은 공공 쪽 추정에도 들어가므로 같이 더해 비교한다
    final flower = prices.addOn(region, '생화꽃장식');
    final photo = prices.addOn(region, '본식 촬영 비용');
    final generalEst = region.rentalFee.median + region.mealPerGuest.median * billed + (flower?.median ?? 0);
    final publicMeal = est == null ? null : est.parts.firstWhere((p) => p.id == 'meal');
    final publicLow = est?.low;
    final publicHigh = est == null ? null : est.low + (paidMedian ?? 0);
    final rows = <List<String>>[
      ['대관료', '무료 $free곳 · 유료 중간 ${paidMedian == null ? '-' : won(paidMedian)}', '중간 ${won(region.rentalFee.median)}'],
      ['1인당 식대', publicMeal == null ? '업체마다 다름' : '약 ${meal(publicMeal.low / guests)} (외부 케이터링 참고가)', '중간 ${meal(region.mealPerGuest.median)}'],
      ['최소 보증인원', '예식장마다 달라요', '중간 $minG명'],
      [
        '하객 $guests명 예상',
        publicLow == null ? '-' : '약 ${won(publicLow)}~${won(publicHigh!)} (추정)',
        '약 ${won(generalEst)} (추정)',
      ],
      if (flower != null)
        [
          '자주 붙는 추가금',
          '꽃장식·음향·진행비 (위 예상에 포함)',
          '꽃장식 중간 ${won(flower.median)}${photo == null ? '' : ' · 본식 촬영 ${won(photo.median)}'}',
        ],
      ['계약 총액(조사)', '-', '중간 ${won(region.totalContract.median)}'],
    ];
    _lookupNote = '공공예식장 $place ${venues.length}곳 대관료(수집 데이터) + 참고 단가표 / 일반 예식장 = 한국소비자원 참가격 ${prices.surveyLabel} ${region.label} 중간값';
    _templateOnly = '금액 비교 (앱이 계산한 표)';
    final sentence = '공공예식장은 앱이 모은 실제 대관료, 일반 예식장은 한국소비자원 ${prices.surveyLabel} 조사(${region.label}) 중간값이에요.';
    _hint = AnswerHint(
      kind: AnswerKind.other,
      headline: '$place 공공 vs 일반 예식장 비용',
      headBadges: const [BlockBadge('조사값·추정 함께', Tone.check)],
      sentence: sentence,
      columns: ['항목', '$place 공공예식장', '${region.label} 일반'],
      rows: rows,
    );
    final note = [
      if (!guestsGiven) '하객 수를 입력하지 않아 $guests명 기준으로 계산했어요.',
      if (guests < minG) '일반 예식장은 최소 보증인원(중간 $minG명)만큼 식대를 내는 경우가 많아 $billed명으로 계산했어요.',
      if (unknownFee > 0) '대관료를 모르는 공공예식장 $unknownFee곳은 빼고 셌어요.',
      '공공 쪽 예상은 대관료 + 식대·꽃장식·음향·진행비(참고 단가표 추정)이고, '
          '일반 쪽은 대관료 + 식대${flower == null ? '' : ' + 꽃장식'}을 더한 값이에요.',
      if ((region.basicDecorationAvg ?? 0) > 0)
        '일반 예식장은 기본 장식비를 따로 받는 곳도 있어요 (${region.label} 평균 ${won(region.basicDecorationAvg!)}, 받지 않는 곳이 더 많음).',
      if (region.definition != null) '${region.label}은 ${region.definition} 기준이에요.',
    ];
    return ChatMessage(
      fromUser: false,
      basis: '$place 공공예식장 ${venues.length}곳 · 한국소비자원 참가격 ${prices.surveyLabel}',
      text: '$sentence\n'
          '${[for (final r in rows) '• ${r[0]}: 공공 ${r[1]} / 일반 ${r[2]}'].join('\n')}\n\n'
          '${note.join(' ')}\n'
          '실제 금액은 예식장·날짜·하객 수에 따라 달라서 견적으로 확인해 주세요.',
      sources: [
        '${prices.source} (${prices.surveyLabel} 조사, 표본 ${region.rentalFee.n}건) ${prices.sourceUrl}',
        '전국 공공예식장 현황 (공유누리·서울마이웨딩·기관 안내, 대관료)',
        '참고 단가표 (업체_요소: 공공 표준가)',
      ],
      quickReplies: [
        QuickReply('$place 무료 예식장', text: '$place 무료 공공예식장 추천해줘'),
        if (!guestsGiven) const QuickReply('하객 수 입력', slot: 'guests', action: 'input'),
        const QuickReply('스드메까지 총비용', text: '스드메까지 결혼 총비용 얼마 들어?'),
      ],
    );
  }
}
