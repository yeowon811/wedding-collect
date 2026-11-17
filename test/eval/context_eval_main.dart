// 대화 흐름 이해 평가: 이전 대화를 어떻게(몇 턴, 원문/요약) 넘길 때 가장 잘 이해하는가.
// 실행: flutter run -d chrome --dart-define-from-file=secrets.json -t test/eval/context_eval_main.dart
// `CTX\t{json}` 줄을 출력하고 끝나면 `CTX_DONE`. 보고서: tools/context_eval_report.py
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wedding_collect/features/chat/agent/conversation_context.dart';
import 'package:wedding_collect/features/chat/agent/gemini_client.dart';
import 'package:wedding_collect/features/chat/agent/understanding.dart';

import 'context_cases.dart';

/// 비교 방식: 이름 → 이전 대화 만들기 (null이면 이전 대화 없이)
final _conditions = <String, String? Function(List<Turn>)>{
  'g_none': (_) => null,
  'g_raw1': (h) => ConversationContext.raw(h, 1),
  'g_raw3': (h) => ConversationContext.raw(h, 3),
  'g_raw5': (h) => ConversationContext.raw(h, 5),
  'g_state1': (h) => ConversationContext.state(h, 1),
  'g_state3': (h) => ConversationContext.state(h, 3),
  'g_state1_raw2': (h) => '${ConversationContext.state(h, 1)}\n최근 대화 원문:\n${ConversationContext.raw(h, 2)}',
};

Map<String, Object?> _fields(({Understanding u, bool isAnswer}) p) => {
      'intent': p.isAnswer ? 'answer' : p.u.intent.name,
      'sido': p.u.facts.sido,
      'item': p.u.item?.name,
      'topic': p.u.topic?.name,
      'refIndex': p.u.refIndex,
      'filter': p.u.filter,
      'guests': p.u.facts.guests,
      'budget': p.u.facts.budget,
      'stage': p.u.facts.stage?.name,
    };

void _out(Map<String, Object?> m) => debugPrint('CTX\t${jsonEncode(m)}', wrapWidth: 1000000);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('대화 흐름 평가 중…')))));
  await GeminiClient.init();
  final gemini = GeminiClient.instance;
  if (gemini == null) {
    debugPrint('CTX_ERROR\tGemini 연결 실패');
    return;
  }
  const onlyRaw = String.fromEnvironment('EVAL_ONLY');
  final only = onlyRaw.isEmpty ? null : onlyRaw.split(',');
  const condRaw = String.fromEnvironment('EVAL_COND');
  final conds = condRaw.isEmpty ? _conditions.keys.toList() : condRaw.split(',');
  final rule = RuleUnderstander();

  for (final c in contextCases) {
    if (only != null && !only.contains(c.id)) continue;
    final base = c.expect.map((k, v) => MapEntry(k, v));

    // 규칙만 (AI 없음)
    final r = ContextRules.apply(rule.parse(c.question), c.question, c.history);
    _out({'id': c.id, 'kind': c.kind, 'q': c.question, 'cond': 'rule', 'expect': base,
      'got': _fields((u: r, isAnswer: false)), 'ms': 0, 'chars': c.question.length});

    for (final name in conds) {
      final ctx = _conditions[name]!(c.history);
      final sw = Stopwatch()..start();
      final g = await gemini.understand(c.question, context: ctx, timeout: const Duration(seconds: 30));
      sw.stop();
      _out({'id': c.id, 'kind': c.kind, 'q': c.question, 'cond': name, 'expect': base,
        'got': g == null ? null : _fields(g), 'ms': sw.elapsedMilliseconds,
        'chars': c.question.length + (ctx?.length ?? 0)});
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
  debugPrint('CTX_DONE');
}
