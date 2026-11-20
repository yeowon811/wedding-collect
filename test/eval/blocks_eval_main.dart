// 블록 답 평가 (2026-11-20): 실제 상담(ConsultAgent + Gemini)에 평가 세트를 넣고 자동 채점한다.
// 실행: flutter run -d chrome --dart-define-from-file=secrets.json -t test/eval/blocks_eval_main.dart
//   --dart-define=EVAL_SET=design|predicted|probe (쉼표로 여러 개, 기본 design)
//   --dart-define=EVAL_ONLY=B1,C1   일부만 · --dart-define=EVAL_REPEAT=3  흔들림 검사(같은 대화 3번)
//   --dart-define=EVAL_GAP=2        턴 사이 쉬는 초 (Blaze면 짧게)
// 출력: `EVAL\t{json}` 줄, 끝나면 `EVAL_DONE`. 보고서: python -I tools/blocks_eval_report.py <로그> --out docs/ai-eval/…
// 내 정보는 가상 값만 쓴다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/gemini_client.dart';

import 'grader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('블록 답 평가 중…')))));
  await GeminiClient.init();
  final gemini = GeminiClient.instance;
  if (gemini == null) debugPrint('EVAL_WARN\tGemini 연결 실패 → 규칙만');
  await Repos.venue.loadAll();
  await Repos.booking.loadAll();
  const setsRaw = String.fromEnvironment('EVAL_SET', defaultValue: 'design');
  const onlyRaw = String.fromEnvironment('EVAL_ONLY');
  const repeat = int.fromEnvironment('EVAL_REPEAT', defaultValue: 1);
  const gap = int.fromEnvironment('EVAL_GAP', defaultValue: 2);
  final only = onlyRaw.isEmpty ? null : onlyRaw.split(',');
  for (final set in setsRaw.split(',')) {
    for (final c in evalSet(set)) {
      if (only != null && !only.contains(c.id)) continue;
      for (var run = 1; run <= repeat; run++) {
        for (final row in await runCase(set, c, llm: gemini, run: run)) {
          debugPrint('EVAL\t${jsonEncode(row)}', wrapWidth: 1000000);
        }
        await Future<void>.delayed(const Duration(seconds: gap));
      }
    }
  }
  debugPrint('EVAL_DONE\tcalls=${GeminiClient.callCount}\tusage=${jsonEncode(GeminiClient.usage)}');
}
