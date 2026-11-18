// 예상 질문 평가: 실제 상담(ConsultAgent + Gemini)에 예상 질문 대화를 넣고 답변을 그대로 기록한다.
// 실행: flutter run -d chrome --dart-define-from-file=secrets.json -t test/eval/predicted_eval_main.dart
// `PRED\t{json}` 줄을 출력하고 끝나면 `PRED_DONE`. 판정은 사람이 답변을 읽고 docs/ai-eval/predicted_report.md에 적는다.
// 내 정보는 가상 값(서울·만 29세·예비부부·하객 150명·예산 3000만원)만 쓴다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/gemini_client.dart';

import 'predicted_cases.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('예상 질문 평가 중…')))));
  await GeminiClient.init();
  final gemini = GeminiClient.instance;
  if (gemini == null) {
    debugPrint('PRED_ERROR\tGemini 연결 실패');
    return;
  }
  const onlyRaw = String.fromEnvironment('EVAL_ONLY');
  final only = onlyRaw.isEmpty ? null : onlyRaw.split(',');
  for (final c in predictedCases) {
    if (only != null && !only.contains(c.id)) continue;
    AppState.instance.saveProfile(const UserProfile(
        sido: '서울', age: 29, stage: MarriageStage.engaged, guests: 150, budget: 3000));
    final agent = ConsultAgent(llm: gemini);
    for (var i = 0; i < c.turns.length; i++) {
      final sw = Stopwatch()..start();
      final m = await agent.reply(c.turns[i]);
      sw.stop();
      debugPrint(
          'PRED\t${jsonEncode({
            'id': c.id, 'kind': c.kind, 'src': c.src, 'turn': i + 1, 'q': c.turns[i],
            'text': m.text, 'ai': m.aiWritten, 'question': m.isQuestion, 'basis': m.basis,
            'cards': [for (final x in m.cards) '${x.title} [${x.badge ?? ''}]'],
            'replies': [for (final r in m.quickReplies) r.label],
            'trace': m.trace, 'ms': sw.elapsedMilliseconds,
          })}',
          wrapWidth: 1000000);
      await Future<void>.delayed(const Duration(seconds: 8)); // 사람이 묻는 속도 (분당 사용량 한도 고려)
    }
  }
  debugPrint('PRED_DONE');
}
