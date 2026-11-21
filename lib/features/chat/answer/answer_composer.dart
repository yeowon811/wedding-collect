import 'dart:convert';

import '../../../core/utils/korean.dart';
import '../agent/gemini_client.dart';
import 'answer_ai.dart';
import 'answer_blocks.dart';
import 'answer_checks.dart';
import 'answer_facts.dart';
import 'answer_template.dart';

/// 답 만들기 결과
class Composed {
  const Composed(this.blocks, {required this.path, this.calls = 0, this.log = const []});

  final List<AnswerBlock> blocks;
  final String path; // ai · ai_rewrite · template · template_after_ai
  final int calls; // 이번 답에서 부른 Gemini 횟수 (작성·검토)
  final List<String> log; // 검사 기록 (접힌 줄에도 들어감)
}

/// ④ 답 작성 → ⑤ 검사(앱 K1~K5 + Gemini 검토) → 걸리면 고칠 점을 붙여 한 번 다시 → 또 걸리면 기본 틀 (R14)
class AnswerComposer {
  AnswerComposer(GeminiClient? llm, {this.review = true})
      : write = llm?.writeBlocks,
        reviewer = llm?.reviewAnswer;

  /// 테스트용: Gemini 대신 함수를 넣는다
  AnswerComposer.fake({this.write, this.reviewer, this.review = true});

  final Future<Map<String, Object?>?> Function(String input)? write;
  final Future<Map<String, Object?>?> Function(String input)? reviewer;
  final bool review; // Gemini 검토 사용 (평가에서 끄고 비교할 수 있게)

  /// 마지막 답의 검토 판정 (평가용)
  ReviewVerdict? lastVerdict;

  Future<Composed> compose(AnswerFacts f) async {
    lastVerdict = null;
    // K3(앞 답과 같은 결과)는 검사가 안내 문장을 직접 넣는다
    final template = _finish(AnswerChecks.run(_tidy(AnswerTemplate.build(f), f), f, strictFormat: false), f, const []);
    final ai = write;
    if (ai == null || f.kind == AnswerKind.ask || f.templateOnly != null) {
      final why = ai == null ? 'Gemini 미연결' : (f.templateOnly ?? '되묻기');
      return Composed(_withLog(template.blocks, f, ['답 작성 · 앱 기본 틀 ($why)', ...template.fixed]), path: 'template');
    }
    // 앱 캐시: 같은 조건·같은 결과면 앞서 받은 Gemini 배치를 다시 쓴다 (조건 칩 ✕로 돌아가기·같은 범위 다시 보기)
    final key = signature(f);
    final hit = _cache[key];
    if (hit != null) {
      final checked = AnswerChecks.run(AnswerAi.resolve(hit, f), f);
      if (checked.ok) {
        final done = _finish(checked, f, const []);
        return Composed(
          _withLog(done.blocks, f, ['답 작성 · 같은 조건의 앞 배치를 다시 씀 (Gemini 호출 없음, 앱 캐시)', ...checked.fixed]),
          path: 'ai_cached',
        );
      }
    }
    var calls = 0;
    final log = <String>[];
    String? fix;
    String? draft;
    for (var attempt = 0; attempt < 2; attempt++) {
      calls++;
      final json = await ai(AnswerAi.writerInput(f, fix: fix, draft: draft));
      if (json == null) {
        log.add('답 작성 · Gemini 응답 없음 → 기본 틀');
        break;
      }
      final blocks = AnswerAi.resolve(json, f);
      final checked = AnswerChecks.run(blocks, f);
      log.addAll(checked.fixed);
      if (!checked.ok) {
        log.add('앱 검사 ${attempt == 0 ? '' : '(다시 쓴 답) '}· ${checked.issues.join(' / ')}');
        fix = checked.issues.map((i) => i.message).join('; ');
        draft = jsonEncode(json);
        continue;
      }
      log.add('앱 검사 K1~K8 ${attempt == 0 ? '' : '(다시 쓴 답) '}통과');
      final rv = reviewer;
      final risks = reviewReasons(f, checked, attempt);
      if (review && rv != null && risks.isNotEmpty) {
        calls++;
        final v = await rv(AnswerAi.reviewInput(f, checked.blocks));
        if (v != null) {
          final verdict = ReviewVerdict.fromJson(v);
          lastVerdict = verdict;
          log.add('Gemini 검토 (${risks.join('·')}) · ${verdict.summary}');
          if (!verdict.ok) {
            fix = verdict.fix.isNotEmpty ? verdict.fix : verdict.summary;
            draft = jsonEncode(json);
            continue;
          }
        } else {
          log.add('Gemini 검토 · 응답 없음 (앱 검사만 통과)');
        }
      } else if (rv != null) {
        log.add('Gemini 검토 생략 · 위험 낮은 답 (정책 판정·후속 질문·비교·웹 결과·앱 경고 없음, 앱 검사 K1~K8 통과)');
      }
      _cache[key] = json;
      final done = _finish(checked, f, const []);
      return Composed(
        _withLog(done.blocks, f, ['답 작성 · Gemini가 블록 배치${attempt == 0 ? '' : ' (고칠 점 반영해 다시 씀)'}', ...log]),
        path: attempt == 0 ? 'ai' : 'ai_rewrite',
        calls: calls,
        log: log,
      );
    }
    return Composed(
      _withLog(template.blocks, f, [...log, '답 작성 · 검사에 두 번 걸려 앱 기본 틀로 답함', ...template.fixed]),
      path: 'template_after_ai',
      calls: calls,
      log: log,
    );
  }

  /// 앞서 받은 Gemini 배치 (이 상담 안에서만, 조건·결과가 같을 때 다시 씀)
  final _cache = <String, Map<String, Object?>>{};

  /// 캐시 열쇠: 답 종류 · 적용 조건 · 결과 id · 앱 제목. 결과 목록이 있으면 질문 문장은 넣지 않는다(같은 결과면 같은 배치).
  /// 결과 목록이 없는 답(일반 안내·웹·비교 설명)은 질문 문장까지 넣는다: 넣지 않으면 서로 다른 질문이 같은 열쇠가 되어
  /// 앞 답이 그대로 다시 나왔다 (11-21: "소비자원 데이터로 비교해 줄 수 있어?"에 앞 질문의 일반 안내가 그대로 나옴)
  static String signature(AnswerFacts f) => jsonEncode([
        f.kind.name,
        f.scope?.toJson(),
        [for (final i in f.items.take(12)) i.ref],
        f.count,
        AnswerTemplate.appHeadline(f),
        f.aiGeneral,
        if (f.items.isEmpty) f.question.trim(),
      ]);

  /// Gemini 검토가 필요한 답인지 (8: 위험한 답만 검토). 빈 목록이면 앱 검사만으로 내보낸다
  static List<String> reviewReasons(AnswerFacts f, CheckResult checked, int attempt) => [
        if (f.kind == AnswerKind.policyList || f.kind == AnswerKind.policyDetail) '정책 대상 판정',
        if (f.followUp) '후속 질문',
        if (f.kind == AnswerKind.venueCompare) '비교',
        if (f.hint != null && f.hint!.web.isNotEmpty) '웹·지도 결과',
        if (attempt > 0 || checked.fixed.any((x) => x.startsWith('K1') || x.startsWith('K7'))) '앱 검사 경고',
      ];

  /// 조사·이름 뒤 조사 고치기 (앱이 만든 문장 포함)
  static List<AnswerBlock> _tidy(List<AnswerBlock> blocks, AnswerFacts f) {
    final names = [for (final i in f.items) i.name];
    String t(String s) => fixJosaAfter(fixJosa(s), names);
    return [
      for (final b in blocks)
        switch (b.type) {
          BlockType.headline || BlockType.ask => b.copyWith(title: t(b.title ?? '')),
          BlockType.text || BlockType.notice => b.copyWith(text: t(b.text ?? '')),
          _ => b,
        },
    ];
  }

  /// 칩이 없는데 선택지가 있으면 붙이고(빈 답 방지), 접힌 줄을 맨 끝에
  static CheckResult _finish(CheckResult c, AnswerFacts f, List<String> extra) {
    var blocks = c.blocks.where((b) => b.type != BlockType.fold).toList();
    if (blocks.firstOf(BlockType.next) == null && blocks.firstOf(BlockType.ask) == null && f.options.isNotEmpty) {
      blocks.add(AnswerBlock(BlockType.next, items: [for (final o in AnswerTemplate.pickOptions(f.options)) o.label]));
    }
    // 결과가 하나도 남지 않았는데(K1로 모두 빠짐) 제목이 건수를 말하면 0건 문형으로
    if (f.items.isNotEmpty && blocks.allCards.isEmpty && f.kind == AnswerKind.venueList && blocks.firstOf(BlockType.cards) == null) {
      final head = blocks.firstOf(BlockType.headline);
      if (head != null && RegExp(r'\d+\s*곳').hasMatch(head.title ?? '') && f.items.every((i) => AnswerChecks.violates(i, f.scope, f.kind) != null)) {
        blocks = [for (final b in blocks) b.type == BlockType.headline ? b.copyWith(title: '조건에 맞는 곳이 없어요', badges: const []) : b];
      }
    }
    return CheckResult(blocks, c.issues, c.fixed);
  }

  static List<AnswerBlock> _withLog(List<AnswerBlock> blocks, AnswerFacts f, List<String> log) => [
        ...blocks.where((b) => b.type != BlockType.fold),
        AnswerTemplate.foldOf(f, extraLog: log),
      ];
}
