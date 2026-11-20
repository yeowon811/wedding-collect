import '../../core/utils/format.dart';
import '../../data/models/user_profile.dart';
import 'answer/answer_blocks.dart';
import 'chat_agent.dart';

/// 파트너에게 공유 (Red Team P2-1, 2026-11-20): 카카오톡에 붙여 넣기 좋은 상담 요약 글.
/// 내 조건(지역·하객·총예산·예식일) + 지금 추천 TOP 3(이름 — 핵심 값) + 예상 총 예식비 줄 + 같은 조건으로 여는 링크.
/// 이름·연락처 같은 개인정보는 넣지 않는다 (대화 내용도 옮기지 않음).
class ShareSummary {
  ShareSummary._();

  /// 공유 링크에 넣는 조건 (지역·하객·총예산·예식일만)
  static Map<String, String> linkParams(UserProfile p) => {
        'tab': '4',
        if (p.sido != null) 'sido': p.sido!,
        if (p.sido != null && p.sigungu != null) 'sigungu': p.sigungu!,
        if (p.guests != null) 'guests': '${p.guests}',
        if (p.budget != null) 'budget': '${p.budget}',
        if (p.weddingDate != null)
          'date': '${p.weddingDate!.year}-${p.weddingDate!.month.toString().padLeft(2, '0')}-${p.weddingDate!.day.toString().padLeft(2, '0')}',
      };

  /// 공유 링크: [origin](웹이면 지금 주소, 앱이면 배포 주소) + 조건
  static String link(UserProfile p, {required String origin}) =>
      Uri.parse(origin).replace(path: '/', queryParameters: linkParams(p)).toString();

  /// 가장 최근 추천 답 (카드가 있는 AI 답)
  static ChatMessage? latestPicks(List<ChatMessage> chat) =>
      chat.reversed.where((m) => !m.fromUser && m.blocks.allCards.isNotEmpty).firstOrNull;

  static String conditions(UserProfile p) => [
        if (p.regionLabel != null) p.regionLabel!,
        if (p.guests != null) '하객 ${p.guests}명',
        if (p.budget != null) '총예산 ${formatManwon(p.budget!)}',
        if (p.weddingDate != null) '예식일 ${p.weddingDate!.year}.${p.weddingDate!.month}.${p.weddingDate!.day}',
      ].join(' · ');

  static String build(UserProfile p, List<ChatMessage> chat, {required String origin}) {
    final picks = latestPicks(chat);
    final cards = picks?.blocks.allCards.take(3).toList() ?? const <BlockCard>[];
    final estimate = picks?.blocks.firstOf(BlockType.estimate)?.text;
    final cond = conditions(p);
    return [
      '[We Connect 결혼 준비 상담 요약]',
      '내 조건: ${cond.isEmpty ? '아직 입력하지 않았어요' : cond}',
      if (cards.isNotEmpty) ...[
        '',
        '추천 TOP ${cards.length}${picks!.blocks.headline == null ? '' : ' (${picks.blocks.headline})'}',
        for (final (i, c) in cards.indexed) '${i + 1}. ${c.title}${c.values.isEmpty ? '' : ' — ${c.values.join(' · ')}'}',
      ],
      if (estimate != null) ...['', estimate],
      '',
      '같은 조건으로 보기: ${link(p, origin: origin)}',
    ].join('\n');
  }
}
