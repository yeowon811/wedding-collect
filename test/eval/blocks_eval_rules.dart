// 블록 답 평가 – 규칙만(Gemini 없음) 기준선: flutter test test/eval/blocks_eval_rules.dart
// --dart-define=EVAL_SET=design,predicted,probe · 출력 형식은 blocks_eval_main.dart와 같다 (EVAL\t{json})
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';

import 'grader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rules eval', () async {
    await Repos.venue.loadAll();
    await Repos.booking.loadAll();
    const setsRaw = String.fromEnvironment('EVAL_SET', defaultValue: 'design,predicted,probe,extra');
    const blocks = bool.fromEnvironment('EVAL_BLOCKS', defaultValue: true);
    ConsultAgent.useBlocks = blocks;
    const onlyRaw = String.fromEnvironment('EVAL_ONLY');
    final only = onlyRaw.isEmpty ? null : onlyRaw.split(',');
    for (final set in setsRaw.split(',')) {
      for (final c in evalSet(set)) {
        if (only != null && !only.contains(c.id)) continue;
        for (final row in await runCase(set, c)) {
          // ignore: avoid_print
          print('EVAL\t${jsonEncode(row)}');
        }
      }
    }
    // ignore: avoid_print
    print('EVAL_DONE');
    AppState.instance.resetProfile();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
