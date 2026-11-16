import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/consult_agent.dart';
import 'package:wedding_collect/features/chat/chat_agent.dart';
import 'package:wedding_collect/features/policy/policy_matcher.dart';

/// UX 개선 기능: 정책 "대상 아님" 이유, AI 답변의 진행 단계·"왜 이렇게 답했나요?"
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => AppState.instance.resetProfile());

  test('내 지역 정책 중 대상이 아닌 것은 이유와 함께 따로 모은다', () async {
    final all = await Repos.policy.loadAll();
    final old = PolicyMatcher.judge(all, const PolicyProfile(sido: '서울', age: 45));
    expect(old.misses, isNotEmpty);
    expect(old.misses.any((m) => m.reason.contains('세 이하 대상') && m.reason.contains('만 45세')), isTrue);
    // 다른 지역 정책은 "대상 아님"에 넣지 않는다
    expect(old.misses.every((m) => m.policy.isNational || m.policy.sido == '서울'), isTrue);
    // 해당 목록과 겹치지 않는다
    final ids = old.matches.map((m) => m.policy.id).toSet();
    expect(old.misses.any((m) => ids.contains(m.policy.id)), isFalse);
  });

  test('답변에 "왜 이렇게 답했나요?" 기록이 붙고, 진행 단계를 거친다', () async {
    AppState.instance.saveProfile(const UserProfile(
      sido: '서울',
      age: 29,
      stage: MarriageStage.engaged,
      guests: 150,
      budget: 3000,
    ));
    final agent = ConsultAgent();
    final seen = <AgentStep>[];
    agent.step.addListener(() {
      if (agent.step.value != null) seen.add(agent.step.value!);
    });
    final m = await agent.reply('공공예식장 추천해줘');
    expect(m.trace.length, 4);
    expect(m.trace[0], startsWith('질문 이해 · 목적 공공예식장'));
    expect(m.trace[0], contains('규칙(키워드)'));
    expect(m.trace[1], contains('서울'));
    expect(m.trace[2], startsWith('데이터 조회 · 서울 공공예식장'));
    expect(m.trace[3], contains('Gemini 미연결'));
    expect(seen, [AgentStep.understand, AgentStep.lookup]); // Gemini가 없으면 작성 단계는 건너뜀
  });
}
