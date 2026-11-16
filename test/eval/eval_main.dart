// ① 질문 이해 정확도 비교: 규칙 기반 vs Gemini (실제 Gemini 호출)
//
// 일반 테스트가 아니라 Chrome에서 따로 띄워 실행한다:
//   flutter run -d chrome -t test/eval/eval_main.dart > eval.txt
// `EVAL\t{json}` 줄을 출력하고 끝나면 `EVAL_DONE`. 보고서: tools/eval_report.py
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wedding_collect/features/chat/agent/gemini_client.dart';
import 'package:wedding_collect/features/chat/agent/understanding.dart';

import 'understanding_cases.dart';

typedef Parsed = ({Understanding u, bool isAnswer});

Map<String, Object?> _fields(Parsed p) => {
      'intent': p.isAnswer ? 'answer' : p.u.intent.name,
      'topic': p.u.topic?.name,
      'item': p.u.item?.name,
      'sido': p.u.facts.sido,
      'age': p.u.facts.age,
      'ageMax': p.u.facts.ageMax,
      'stage': p.u.facts.stage?.name,
      'marriedYears': p.u.facts.marriedYears,
      'guests': p.u.facts.guests,
      'budget': p.u.facts.budget,
      'homeless': p.u.facts.homeless,
    };

/// 틀린 항목 목록 (비어 있으면 정답)
List<String> _grade(EvalCase c, Parsed p) {
  final got = _fields(p);
  final wrong = <String>[];
  for (final e in c.expect.entries) {
    if (e.key == 'intent') {
      final want = e.value as String;
      final ok = c.expecting == null
          ? got['intent'] == want
          : want == 'answer'
              // 되묻는 중: 원래 질문을 이어가면 정답 (앱 규칙과 같음)
              ? p.isAnswer || p.u.intent == ConsultIntent.help || p.u.intent.name == c.pending
              : !p.isAnswer && p.u.intent.name == want;
      if (!ok) wrong.add('intent');
    } else if (got[e.key] != e.value) {
      wrong.add(e.key);
    }
  }
  return wrong;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('질문 이해 평가 중…')))));
  await GeminiClient.init();
  final gemini = GeminiClient.instance;
  if (gemini == null) {
    debugPrint('EVAL_ERROR\tGemini 연결 실패');
    return;
  }
  final rule = RuleUnderstander();
  // 이어서 실행: --dart-define=EVAL_FROM=V01 (그 ID부터), EVAL_ONLY=P03,P07 (그 ID만)
  const from = String.fromEnvironment('EVAL_FROM');
  const onlyRaw = String.fromEnvironment('EVAL_ONLY');
  final only = onlyRaw.isEmpty ? null : onlyRaw.split(',');
  final start = from.isEmpty ? 0 : evalCases.indexWhere((c) => c.id == from);

  for (final c in evalCases.skip(start < 0 ? 0 : start)) {
    if (only != null && !only.contains(c.id)) continue;
    final expecting = c.expecting == null ? null : Slot.values.byName(c.expecting!);
    final r = (u: rule.parse(c.text, expecting: expecting), isAnswer: false);

    final sw = Stopwatch()..start();
    final g = await gemini.understand(c.text, expecting: expecting);
    sw.stop();

    // 앱에서 실제로 쓰는 결과: Gemini 결과 + Gemini가 놓친 값은 규칙으로 보완, Gemini 실패 시 규칙
    final Parsed app = g == null
        ? r
        : (
            isAnswer: g.isAnswer,
            u: Understanding(
              intent: g.u.intent,
              facts: r.u.facts.merge(g.u.facts),
              topic: g.u.topic ?? (g.u.intent == ConsultIntent.policy ? r.u.topic : null),
              item: g.u.item ?? (g.u.intent == ConsultIntent.vendor ? r.u.item : null),
            ),
          );

    debugPrint('EVAL\t${jsonEncode({
          'id': c.id,
          'text': c.text,
          'note': c.note,
          'expect': c.expect,
          'rule': _fields(r),
          'ruleWrong': _grade(c, r),
          'gemini': g == null ? null : _fields(g),
          'geminiWrong': g == null ? ['응답 없음'] : _grade(c, g),
          'appWrong': _grade(c, app),
          'ms': sw.elapsedMilliseconds,
        })}', wrapWidth: 100000);
    // 무료 등급 분당 요청 제한을 넘지 않도록 간격을 둔다
    await Future<void>.delayed(const Duration(seconds: 4));
  }
  debugPrint('EVAL_DONE');
}
