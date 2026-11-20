import '../../../data/models/policy.dart';
import '../../policy/policy_matcher.dart';
import '../agent/policy_text.dart';
import 'answer_blocks.dart';
import 'answer_facts.dart';

/// '출처 보기 · 어떻게 찾았나요'를 사용자 말로 (Red Team P1-3, 2026-11-20).
///
/// 화면에는 ① 검증 배지 ② 걸러진 과정(앱이 센 건수와 이유) ③ 충족한 조건 / 확인이 필요한 조건(미입력·현장 확인) + 출처만 보인다.
/// 함수 이름·JSON·ms·내부 검사 코드(K1~K8)가 섞인 기록(fold의 log)은 블록에 그대로 남겨 평가·개발용으로만 쓴다.
class FoldSummary {
  /// ① 검증 배지: 무엇으로 확인했는지 (앱 데이터가 아니면 주황). 되묻기에는 없다
  static BlockBadge? verify(AnswerFacts f) {
    if (f.kind == AnswerKind.ask) return null;
    if (f.aiGeneral || f.kind == AnswerKind.general) return const BlockBadge('일반 안내 · 앱 데이터 아님', Tone.check);
    if (!f.kind.isVenue && (f.hint?.web.isNotEmpty ?? false)) return const BlockBadge('웹 정보 · 출처 확인 필요', Tone.check);
    final demo = f.items.any((i) => i.ref.startsWith('vendor:'));
    return switch (f.kind) {
      AnswerKind.venueDate => const BlockBadge('공공데이터·예약 현황으로 확인', Tone.good),
      AnswerKind.venueList || AnswerKind.venueDetail || AnswerKind.venueCompare => const BlockBadge('공공데이터로 확인', Tone.good),
      AnswerKind.policyList || AnswerKind.policyDetail => const BlockBadge('공공데이터·자격 규칙으로 확인', Tone.good),
      AnswerKind.vendorList when demo => const BlockBadge('시연용 업체 · 가격은 예시', Tone.check),
      AnswerKind.vendorList => const BlockBadge('공공데이터 연계 업체', Tone.good),
      AnswerKind.cost => const BlockBadge('참고 단가표로 계산 · 추정', Tone.check),
      AnswerKind.calc => const BlockBadge('질문 속 숫자로 앱이 계산', Tone.good),
      AnswerKind.budget => const BlockBadge('내 체크리스트 금액 기준', Tone.good),
      AnswerKind.schedule => const BlockBadge('내 예식일·체크리스트 기준', Tone.good),
      _ => const BlockBadge('앱 데이터 기준', Tone.info),
    };
  }

  /// 화면에 보여도 되는 글로: JSON·ms·내부 코드·함수 이름을 지운다
  static String plain(String s) => s
      .replaceAll(RegExp(r'\{[^{}]*\}'), '')
      .replaceAll(RegExp(r'\(?\b\d+\s*ms\b\)?'), '')
      .replaceAll(RegExp(r'\bK\d(~K\d)?\b'), '')
      .replaceAll(RegExp(r'\b[a-z]+(_[a-z]+)+\b'), '')
      .replaceAll('Gemini', 'AI')
      .replaceAll(RegExp(r'\s*그라운딩'), '')
      .replaceAll(RegExp(r'\(\s*[,·]?\s*\)'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'\s+([,):])'), r'$1')
      .trim();

  /// ② 걸러진 과정: 앱이 기록한 단계(건수) → 없으면 데이터 조회 기록을 사용자 말로 바꿔 나눈다
  static List<String> steps(AnswerFacts f) {
    if (f.steps.isNotEmpty) return f.steps;
    const prefix = '데이터 조회 · ';
    final look = f.log.where((l) => l.startsWith(prefix)).firstOrNull;
    if (look == null) return const [];
    return [
      for (final s in plain(look.substring(prefix.length)).split(RegExp(r'\s*(→|/)\s*')))
        if (s.trim().length > 1) s.trim(),
    ].take(6).toList();
  }

  /// ③-1 충족한 조건 (이번 결과가 실제로 만족한 것만)
  static List<String> met(AnswerFacts f) {
    final out = <String>[];
    final s = f.scope;
    if (f.kind.isVenue && s != null) {
      final vs = [for (final i in f.items) if (i.venue != null) i.venue!];
      final place = s.towns.isNotEmpty
          ? '${s.sidos.length == 1 ? '${s.sidos.first} ' : ''}${s.towns.join('·')}'
          : s.sidos.join('·');
      if (place.isNotEmpty) out.add('지역 $place${s.autoTown ? ' (내 지역부터)' : ''}');
      for (final t in s.excludeTowns) {
        out.add('$t 제외');
      }
      if (s.freeOnly) out.add('대관료 무료');
      if (s.maxFee != null) out.add('대관료 ${_manwon(s.maxFee!)} 이하');
      final g = s.guests;
      if (g != null) {
        final fit = vs.where((v) => v.fits(g) == true).length;
        if (fit > 0) out.add('하객 $g명 수용 ($fit곳)');
      }
      for (final n in s.needs) {
        out.add('${const {'parking': '주차', 'reception': '피로연', 'outdoor': '야외 예식'}[n] ?? n} 가능 (원문 기준)');
      }
      if (s.date != null) {
        final open = f.items.where((i) => i.badge?.tone == Tone.good).length;
        if (open > 0) out.add('${md(s.date!)} 예약 비어 있음 ($open곳)');
      } else if (s.periodLabel != null) {
        out.add('${s.periodLabel} 날짜 확인');
      }
    }
    if (f.kind == AnswerKind.policyList || f.kind == AnswerKind.policyDetail) {
      final p = f.profile;
      if (p != null) {
        if (p.sido != null) out.add('거주지 ${p.sido}${p.sigungu == null ? '' : ' ${p.sigungu}'}');
        if (p.age != null) out.add('만 ${p.age}세');
        if (p.weddingDate != null || p.stageInput != null) out.add(p.stage == MarriageStage.married ? '신혼부부' : '예비부부');
        if (p.homeless == true) out.add('무주택');
        if (p.income != null) out.add('부부 연소득 ${p.income}만원');
      }
      final likely = f.items.where((i) => i.level == MatchLevel.likely).length;
      if (likely > 0) out.add('대상 가능성 높음 $likely건');
    }
    if (f.kind == AnswerKind.vendorList) {
      final inB = f.items.where((i) => i.badge?.text == '예산 안').length;
      if (inB > 0) out.add('내 예산 안 $inB곳');
    }
    return out.take(6).toList();
  }

  /// ③-2 확인이 필요한 조건 (미입력·정보 없음·현장 확인). 답 함수가 넘긴 것(앱 데이터로 못 보는 조건 등)을 먼저
  static List<String> pending(AnswerFacts f) {
    final out = <String>[...f.pending];
    final s = f.scope;
    final p = f.profile;
    if (f.kind.isVenue) {
      final vs = [for (final i in f.items) if (i.venue != null) i.venue!];
      final g = s?.guests;
      if (g == null) {
        out.add('하객 수 (미입력 · 정원은 비교하지 않았어요)');
      } else {
        final unknown = vs.where((v) => v.fits(g) == null).length;
        if (unknown > 0) out.add('정원 정보 없는 곳 $unknown곳 (문의처로 확인)');
      }
      final noFee = vs.where((v) => v.rentalFee == null).length;
      if (noFee > 0) out.add('대관료 정보 없는 곳 $noFee곳 (문의처로 확인)');
      if (s?.date != null || s?.periodLabel != null) {
        out.add('예약 현황은 수집한 날 기준 (예약 사이트에서 다시 확인)');
      } else if (f.kind == AnswerKind.venueList) {
        out.add(p?.weddingDate == null ? '예식일 (미입력 · 날짜를 물으면 예약 현황으로 확인해요)' : '예식일 예약 가능 여부 (날짜를 물으면 예약 현황으로 확인해요)');
      }
    }
    if (f.kind == AnswerKind.policyList || f.kind == AnswerKind.policyDetail) {
      final pols = [for (final i in f.items) if (i.policy != null) i.policy!];
      if (p?.sido == null) out.add('거주지 (미입력)');
      if (p?.age == null) out.add('나이 (미입력)');
      if (p?.income == null && pols.any((x) => incomeCap(x.eligibility) != null)) out.add('부부 합산 소득 (미입력 · 소득 상한은 기관에서 확인)');
      if (p?.homeless == null && pols.any((x) => x.category == PolicyCategory.housing)) out.add('무주택 여부 (미입력)');
      final check = f.items.where((i) => i.level == MatchLevel.check).length;
      if (check > 0) out.add('조건 확인 $check건 (원문의 소득·주택 조건은 기관 공고로 확인)');
    }
    if (f.kind == AnswerKind.vendorList) {
      if (f.items.any((i) => i.ref.startsWith('vendor:'))) out.add('시연용 업체 가격은 예시 (실제 견적 아님)');
      if (f.items.any((i) => i.ref.startsWith('real:'))) out.add('실제 업체 가격은 업체에 문의');
    }
    if (f.kind == AnswerKind.cost) out.add('실제 비용은 업체 견적으로 확인');
    if (f.aiGeneral || f.kind == AnswerKind.general) out.add('일반 안내라 기관·전문가에게 다시 확인');
    if (!f.kind.isVenue && (f.hint?.web.isNotEmpty ?? false)) out.add('웹 정보는 바뀔 수 있어 출처 페이지에서 확인');
    final seen = <String>{};
    return [for (final x in out) if (seen.add(x)) x].take(6).toList();
  }

  static String _manwon(int won) => won % 10000 == 0 ? '${won ~/ 10000}만원' : '${(won / 10000).toStringAsFixed(1)}만원';
}
