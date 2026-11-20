// 블록 답 평가 실행·채점 (2026-11-20). Chrome(Gemini) 실행과 flutter test(규칙만) 실행이 함께 쓴다.
import 'dart:convert';

import 'package:wedding_collect/core/utils/region.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/gemini_client.dart';
import 'package:wedding_collect/features/chat/answer/answer_blocks.dart';
import 'package:wedding_collect/features/chat/answer/answer_checks.dart';
import 'package:wedding_collect/features/chat/chat_agent.dart';

import 'expectations.dart';
import 'predicted_cases.dart';
import 'probe_cases.dart';

/// 평가 세트: design(예상 답 30) · predicted(52) · probe(36)
List<EvalCase> evalSet(String name) => switch (name) {
      'design' => designCases,
      'predicted' => fromPredicted(predictedCases, predictedExps),
      'probe' => fromPredicted(probeCases, probeExps),
      'extra' => extraCases,
      _ => const [],
    };

UserProfile profileFor(String set) => set == 'design' || set == 'extra'
    ? UserProfile(
        sido: '서울', sigungu: '강남구', age: 29, guests: 120, homeless: true, budget: 3000, weddingDate: DateTime(2027, 5, 15))
    : const UserProfile(sido: '서울', age: 29, stage: MarriageStage.engaged, guests: 150, budget: 3000);

/// 한 대화를 실행하고 턴마다 결과(JSON)를 돌려준다
Future<List<Map<String, Object?>>> runCase(String set, EvalCase c, {GeminiClient? llm, int run = 1}) async {
  // 'Q'로 시작하는 대화는 내 정보 없이 시작 (미니 폼 확인)
  AppState.instance.saveProfile(c.id.startsWith('Q') ? const UserProfile() : profileFor(set));
  final agent = ConsultAgent(llm: llm);
  final out = <Map<String, Object?>>[];
  ChatMessage? m;
  Map<String, Object?>? prev;
  for (var i = 0; i < c.turns.length; i++) {
    final q = c.turns[i];
    GeminiClient.instance?.lastPlanRaw = null;
    final calls0 = GeminiClient.callCount;
    final usage0 = Map<String, int>.of(GeminiClient.usage);
    final log0 = GeminiClient.callLog.length;
    final sw = Stopwatch()..start();
    if (q == '!start') {
      m = await agent.start();
    } else if (q.startsWith('!form ')) {
      // 미니 폼 제출: '!form sido=서울;age=29;stage=engaged;homeless=true' (화면의 [조건 적용하고 결과 보기]와 같은 값)
      final kv = {
        for (final p in q.substring(6).split(';'))
          if (p.contains('=')) p.split('=')[0].trim(): p.split('=')[1].trim(),
      };
      m = await agent.choose(QuickReply(kv.values.join(' · '), action: 'form', value: <String, Object?>{
        if (kv['sido'] != null) 'sido': kv['sido'],
        if (kv['sigungu'] != null) 'sigungu': kv['sigungu'],
        if (kv['age'] != null) 'age': int.parse(kv['age']!),
        if (kv['stage'] != null) 'stage': kv['stage'],
        if (kv['homeless'] != null) 'homeless': kv['homeless'] == 'true',
        'slots': m?.form ?? const <String>[],
      }));
    } else if (q.startsWith('~=')) {
      // 조건 칩으로 값 바꾸기: '~=sigungu:강남구' (여러 개는 |로)
      final kv = q.substring(2).split(':');
      m = await agent.choose(QuickReply(q, action: 'refine', value: <String, Object?>{
        'set': <String, Object?>{kv[0]: kv[1].split('|')},
        'remove': <String>[],
      }));
    } else if (q.startsWith('~')) {
      // 조건 칩: '~-guests' 빼기, '~+free_only' 더하기 (화면의 ✕·+ 조건과 같은 동작)
      final k = q.substring(2);
      final v = <String, Object?>{
        'set': q[1] == '+' ? <String, Object?>{k: k == 'needs' ? ['parking'] : (k == 'sort' ? 'capacity_high' : true)} : <String, Object?>{},
        'remove': q[1] == '-' ? [k] : <String>[],
      };
      m = await agent.choose(QuickReply(q, action: 'refine', value: v));
    } else if (q.startsWith('#')) {
      final want = q.substring(1);
      final r = m?.quickReplies.where((r) => r.label == want || r.label.contains(want.replaceAll('까지', ''))).firstOrNull ??
          m?.quickReplies.where((r) => r.action == 'refine' && r.label.endsWith('까지')).firstOrNull;
      m = r == null ? await agent.reply(want) : await agent.choose(r);
    } else {
      m = await agent.reply(q);
    }
    sw.stop();
    final usageDiff = {
      for (final e in GeminiClient.usage.entries)
        if (e.value - (usage0[e.key] ?? 0) != 0) e.key: e.value - (usage0[e.key] ?? 0),
    };
    final row = await gradeTurn(set, c, i, q, m, agent, ms: sw.elapsedMilliseconds, calls: GeminiClient.callCount - calls0, run: run);
    row['usage'] = usageDiff;
    row['calls_detail'] = GeminiClient.callLog.sublist(log0);
    if (prev != null) {
      row['repeat'] = prev['headline'] == row['headline'] && jsonEncode(prev['ids']) == jsonEncode(row['ids']) && (row['ids'] as List).isNotEmpty;
    }
    prev = row;
    out.add(row);
  }
  return out;
}

Future<Map<String, Object?>> gradeTurn(String set, EvalCase c, int i, String q, ChatMessage m, ConsultAgent agent,
    {required int ms, required int calls, int run = 1}) async {
  final blocks = m.blocks;
  final f = agent.lastFacts;
  final venues = {for (final v in await Repos.venue.loadAll()) v.id: v};
  final refs = [for (final card in blocks.allCards) card.ref];
  final ids = [for (final r in refs) r.split(':').last];
  final venueIds = [for (final r in refs) if (r.startsWith('venue:')) r.split(':').last];
  final text = blocks.plainText;
  final tableText = [for (final b in blocks.where((b) => b.type == BlockType.table)) ...b.columns, for (final b in blocks.where((b) => b.type == BlockType.table)) for (final r in b.rows) ...r].join(' ');
  final headline = blocks.headline ?? '';
  final chips = [for (final r in m.quickReplies) r.label];
  final fails = <String>[];

  // 공통 검사: 블록이 있고, 첫 블록이 제목/되묻기, 형식(K5), 숫자 출처(K2)
  if (blocks.isEmpty) fails.add('블록 없음');
  final issues = f == null ? const <CheckIssue>[] : AnswerChecks.run(blocks, f).issues.where((x) => x.code != 'K3').toList();
  for (final x in issues) {
    fails.add('${x.code} ${x.message}');
  }

  // Red Team P1-3: 화면에 보이는 접힌 줄(검증·과정·조건·계산)에 함수 이름·JSON·ms·검사 코드가 없어야
  final internal = RegExp(r'[a-z]+_[a-z]+|\{|\d+\s*ms|K\d');
  for (final b in blocks.where((b) => b.type == BlockType.fold)) {
    for (final l in [...b.items, ...b.met, ...b.pending, ...b.calc]) {
      if (internal.hasMatch(l)) fails.add('접힌 줄에 내부 기록: $l');
    }
  }
  // Red Team P1-2: 예식장 카드가 있으면 예상 총 예식비 줄이 한 번
  if (refs.any((r) => r.startsWith('venue:')) && blocks.where((b) => b.type == BlockType.estimate).length != 1) {
    fails.add('예상 비용 줄 없음·중복');
  }

  final e = i < c.exps.length ? c.exps[i] : null;
  if (e != null) {
    final vs = [for (final id in venueIds) if (venues[id] != null) venues[id]!];
    if (e.towns != null && vs.any((v) => !e.towns!.contains(v.sigungu))) {
      fails.add('구 밖 카드: ${vs.where((v) => !e.towns!.contains(v.sigungu)).map((v) => '${v.sigungu} ${v.name}').join(', ')}');
    }
    if (e.notTowns.isNotEmpty && vs.any((v) => e.notTowns.contains(v.sigungu))) fails.add('뺀 구가 나옴');
    bool inSidos(v) => e.sidos!.any((sd) => sidoMatches(v.sido as String, sd));
    if (e.sidos != null && vs.any((v) => !inSidos(v))) {
      fails.add('시도 밖 카드: ${vs.where((v) => !inSidos(v)).map((v) => v.sido).toSet().join(',')}');
    }
    if (e.free == true && vs.any((v) => v.rentalFee != 0)) fails.add('무료 아닌 카드');
    if (e.maxFee != null && vs.any((v) => v.rentalFee == null || v.rentalFee! > e.maxFee!)) fails.add('대관료 상한 초과');
    if (e.ask != null && (blocks.firstOrNull?.type == BlockType.ask || m.isQuestion) != e.ask) {
      fails.add(e.ask! ? '되물어야 함' : '되묻지 말아야 함');
    }
    if (e.headline != null && !RegExp(e.headline!).hasMatch(headline)) fails.add('제목 "$headline" ≠ /${e.headline}/');
    if (e.notHeadline != null && RegExp(e.notHeadline!).hasMatch(headline)) fails.add('제목 "$headline"에 /${e.notHeadline}/');
    for (final id in e.include) {
      final name = venues[id]?.name ?? id;
      if (!ids.contains(id) && !tableText.contains(name.split('(').first.trim())) fails.add('$id 없음');
    }
    for (final id in e.exclude) {
      if (ids.contains(id)) fails.add('$id 나오면 안 됨');
    }
    if (e.minCards != null && refs.length < e.minCards!) fails.add('카드 ${refs.length} < ${e.minCards}');
    if (e.maxCards != null && refs.length > e.maxCards!) fails.add('카드 ${refs.length} > ${e.maxCards}');
    if (e.kind != null && f?.kind.name != e.kind) fails.add('종류 ${f?.kind.name} ≠ ${e.kind}');
    if (e.chip != null && !chips.any((x) => RegExp(e.chip!).hasMatch(x))) fails.add('칩 /${e.chip}/ 없음');
    if (e.noChip != null && chips.any((x) => RegExp(e.noChip!).hasMatch(x))) fails.add('칩 /${e.noChip}/ 있음');
    final filterLabels = [for (final b in blocks.where((b) => b.type == BlockType.filters)) for (final x in b.filters) x.label];
    if (e.filter != null && !filterLabels.any((x) => RegExp(e.filter!).hasMatch(x))) fails.add('조건 칩 /${e.filter}/ 없음');
    if (e.form != null && m.form.isNotEmpty != e.form) fails.add(e.form! ? '미니 폼이어야 함' : '미니 폼이 아니어야 함');
    if (e.profileHas != null && !RegExp(e.profileHas!).hasMatch(AppState.instance.profile.summary)) {
      fails.add('내 정보에 /${e.profileHas}/ 없음: ${AppState.instance.profile.summary}');
    }
    if (e.noFilter != null && filterLabels.any((x) => RegExp(e.noFilter!).hasMatch(x))) {
      fails.add('조건 칩 /${e.noFilter}/ 있음: ${filterLabels.join(', ')}');
    }
    for (final t in e.blocks) {
      if (!blocks.any((b) => b.type.name == t)) fails.add('$t 블록 없음');
    }
    final all = '$text $tableText ${m.text}';
    if (e.text != null && !RegExp(e.text!).hasMatch(all)) fails.add('글에 /${e.text}/ 없음');
    if (e.notText != null && RegExp(e.notText!).hasMatch('$text $tableText')) fails.add('글에 /${e.notText}/ 있음');
  }

  final v = agent.lastVerdict;
  return {
    'set': set,
    'id': c.id,
    'kind': c.kind,
    'run': run,
    'turn': i + 1,
    'q': q,
    'graded': e != null,
    'ok': fails.isEmpty,
    'fails': fails,
    'path': agent.lastComposed?.path,
    'calls': calls,
    'ms': ms,
    'compose_ms': agent.lastComposeMs,
    'answer_kind': f?.kind.name,
    'headline': headline,
    'ids': ids,
    'chips': chips,
    'text': text,
    'visible_chars': text.length,
    'old_chars': m.text.length,
    'verdict': v?.summary,
    'log': [for (final b in blocks.where((b) => b.type == BlockType.fold)) ...b.log],
    'estimate': blocks.firstOf(BlockType.estimate)?.toJson(),
    'fold_view': [
      for (final b in blocks.where((b) => b.type == BlockType.fold))
        {'verify': [for (final x in b.badges) x.text], 'steps': b.items, 'met': b.met, 'pending': b.pending},
    ],
    'filters': [for (final b in blocks.where((b) => b.type == BlockType.filters)) for (final x in b.filters) x.label],
    'form': m.form,
    'profile': AppState.instance.profile.summary,
    'plan': GeminiClient.instance?.lastPlanRaw,
    'trace': m.trace,
    'checks': [for (final x in issues) '$x'],
    'blocks': [for (final b in blocks) b.toJson()],
  };
}
