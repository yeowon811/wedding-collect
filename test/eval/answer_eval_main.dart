// ⑤ 답변 문장 평가: 앱이 데이터로 만든 답변(draft) → Gemini가 다시 쓴 답변
//
// 실행: flutter run -d chrome --dart-define-from-file=secrets.json -t test/eval/answer_eval_main.dart
// `ANS\t{json}` 줄을 출력하고 끝나면 `ANS_DONE`. 보고서: tools/answer_eval_report.py
//
// 자동 채점:
// - grounded: Gemini 답변의 숫자가 모두 조회 결과에 있는지 (없으면 앱이 Gemini 문장을 버림)
// - 주의 문구 유지: 조회 결과에 "확인할 것"·"시연용"·"기관"(확인 안내)이 있으면 답변에도 있어야 함
// - 표시어 추가 없음: 조회 결과에 없는 "시연용"·"가상"·"예비부부"·"신혼부부"·"기관"을 붙이지 않음
// - 이름 유지: 카드로 붙는 정책·예식장·업체 이름 중 답변에 나온 비율 (참고용)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/agent/gemini_client.dart';
import 'package:wedding_collect/features/chat/chat_agent.dart';

/// (ID, 질문, 사용할 내 정보). 질문이 null이면 상담 시작(전체 추천)
final _engaged = UserProfile(
  sido: '서울',
  age: 29,
  stage: MarriageStage.engaged,
  weddingDate: DateTime.now().add(const Duration(days: 200)),
  guests: 150,
  budget: 3000,
  homeless: true,
);
final _married = UserProfile(
  sido: '경기',
  age: 33,
  stage: MarriageStage.married,
  marriedYears: 2,
  weddingDate: DateTime.now().add(const Duration(days: 100)),
  guests: 100,
  budget: 2000,
  homeless: true,
);

final _cases = <(String, String?, UserProfile)>[
  ('W01', null, _engaged),
  ('W02', '받을 수 있는 정책 알려줘', _engaged),
  ('W03', '신혼집 주거 지원 정책 알려줘', _married),
  ('W04', '결혼 장려금 정책 알려줘', _married),
  ('W05', '임신 준비 중인데 지원되는 거 있어?', _married),
  ('W06', '공공예식장 추천해줘', _engaged),
  ('W07', '부산 공공예식장 추천해줘', _engaged),
  ('W08', '하객 200명 들어가는 예식장 있어?', _married),
  ('W09', '드레스 추천해줘', _engaged),
  ('W10', '식대 업체 추천해줘', _married),
  ('W11', '스냅 작가 추천해줘', _engaged),
  ('W12', '예산 어떻게 나누면 돼?', _engaged),
  ('W13', '뭐부터 해야 해?', _married),
  ('W14', '메이크업 예산 안에서 추천해줘', _married),
  ('W15', null, _married),
];

const _cautions = ['확인할 것', '시연용', '기관'];

Set<String> _nums(String s) =>
    RegExp(r'\d+(?:\.\d+)?').allMatches(s.replaceAll(',', '')).map((m) => m.group(0)!).toSet();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('답변 문장 평가 중…')))));
  await GeminiClient.init();
  final gemini = GeminiClient.instance;
  if (gemini == null) {
    debugPrint('ANS_ERROR\tGemini 연결 실패');
    return;
  }
  const onlyRaw = String.fromEnvironment('EVAL_ONLY');
  final only = onlyRaw.isEmpty ? null : onlyRaw.split(',');

  for (final (id, question, profile) in _cases) {
    if (only != null && !only.contains(id)) continue;
    AppState.instance.saveProfile(profile);
    final agent = ConsultAgent(); // 규칙 기반으로 draft를 만든다 (Gemini 없이)
    final ChatMessage m = question == null ? await agent.start() : await agent.reply(question);
    if (m.isQuestion) {
      debugPrint('ANS_SKIP\t$id 되묻기 발생: ${m.text.split('\n').first}');
      continue;
    }
    final q = question ?? '내 정보에 맞게 예식장·정책·예산·할 일을 한 번에 추천해줘';
    final draft = ConsultAgent.draftOf(m);

    final sw = Stopwatch()..start();
    String? out;
    String? error;
    try {
      out = await gemini.rewriteRaw(question: q, draft: draft);
    } catch (e) {
      error = '$e';
    }
    sw.stop();

    final o = out ?? '';
    final extra = _nums(o).difference(_nums(draft)).toList();
    final cautionsInDraft = _cautions.where(draft.contains).toList();
    final cautionsLost = cautionsInDraft.where((c) => !o.contains(c)).toList();
    final names = m.cards.map((c) => c.title.replaceFirst('[시연] ', '')).toList();
    final named = names.where(o.contains).length;

    debugPrint('ANS\t${jsonEncode({
          'id': id,
          'question': q,
          'profile': profile.summary,
          'draft': draft,
          'output': out,
          'error': error,
          'grounded': out != null && extra.isEmpty,
          'extraNumbers': extra,
          'termsGrounded': out != null && GeminiClient.termsAreGrounded(o, draft),
          'addedTerms': GeminiClient.guardedTerms.where((t) => o.contains(t) && !draft.contains(t)).toList(),
          'cautionsInDraft': cautionsInDraft,
          'cautionsLost': cautionsLost,
          'names': names.length,
          'namesKept': named,
          'hasMarkdown': o.contains('**') || o.contains('#'),
          'draftLen': draft.length,
          'outLen': o.length,
          'ms': sw.elapsedMilliseconds,
        })}', wrapWidth: 1000000);
    await Future<void>.delayed(const Duration(seconds: 4));
  }
  debugPrint('ANS_DONE');
}
