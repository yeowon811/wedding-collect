import '../../../data/models/policy.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/vendor.dart';
import 'understanding.dart';

/// 대화 한 턴의 기록: 사용자 질문 + 상담 답변 + 그 답변의 목적과 보여준 목록
class Turn {
  const Turn({
    required this.user,
    required this.bot,
    required this.intent,
    this.topic,
    this.item,
    this.sido,
    this.results = const [],
  });

  final String user;
  final String bot;
  final ConsultIntent intent;
  final PolicyCategory? topic;
  final VendorCategory? item;
  final String? sido;
  final List<String> results; // 답변에 보여준 목록 (예식장·정책·업체 이름, 순서대로)
}

const _intentLabel = {
  ConsultIntent.recommend: '전체 추천',
  ConsultIntent.policy: '지원 정책',
  ConsultIntent.venue: '공공예식장',
  ConsultIntent.vendor: '업체',
  ConsultIntent.budget: '예산 현황',
  ConsultIntent.schedule: '준비 순서',
  ConsultIntent.help: '일반 질문',
};

/// 질문 이해에 함께 보낼 "이전 대화"를 만든다.
/// - [raw]: 최근 N턴의 원문 (답변은 앞부분만)
/// - [state]: 최근 N턴의 요약 상태 (목적·분야·항목·지역·보여준 목록) — 짧고 개인 문장이 적다
class ConversationContext {
  ConversationContext._();

  static String _list(List<String> r) =>
      r.isEmpty ? '' : ' / 목록: ${[for (var i = 0; i < r.length; i++) '${i + 1}) ${r[i]}'].join(' ')}';

  static String raw(List<Turn> turns, int n, {int botChars = 160}) {
    final recent = turns.length <= n ? turns : turns.sublist(turns.length - n);
    return [
      for (final t in recent) ...[
        '사용자: ${t.user}',
        '상담: ${t.bot.length > botChars ? '${t.bot.substring(0, botChars)}…' : t.bot}${_list(t.results)}',
      ],
    ].join('\n');
  }

  static String state(List<Turn> turns, int n, {UserProfile known = const UserProfile()}) {
    final recent = turns.length <= n ? turns : turns.sublist(turns.length - n);
    final lines = <String>[
      for (var i = 0; i < recent.length; i++)
        '[${recent.length - i == 1 ? '직전' : '${recent.length - i}턴 전'}] 목적 ${_intentLabel[recent[i].intent]}'
            '${recent[i].topic != null ? ' · 분야 ${recent[i].topic!.label}' : ''}'
            '${recent[i].item != null ? ' · 항목 ${recent[i].item!.name}' : ''}'
            '${recent[i].sido != null ? ' · 지역 ${recent[i].sido}' : ''}'
            '${_list(recent[i].results)}',
    ];
    if (known.summary.isNotEmpty) lines.add('알고 있는 정보: ${known.summary}');
    return lines.join('\n');
  }
}

/// AI 없이 규칙으로 이어지는 질문을 처리한다 (Gemini 실패 시 대체용).
/// - "두 번째", "2번", "마지막", "거기/그거" → refIndex
/// - "무료", "하객 다 들어가는", "더 싼", "사진" → filter
/// - 목적을 알 수 없는 짧은 질문·지시·필터 질문은 직전 목적·분야·항목을 이어받는다
class ContextRules {
  ContextRules._();

  static const _ordinals = <String, int>{
    '첫번째': 1, '첫째': 1, '1번': 1, '하나': 1,
    '두번째': 2, '둘째': 2, '2번': 2,
    '세번째': 3, '셋째': 3, '3번': 3,
    '네번째': 4, '4번': 4, '다섯번째': 5, '5번': 5,
  };

  static Understanding apply(Understanding u, String text, List<Turn> history) {
    final t = text.replaceAll(' ', '');
    int? ref;
    for (final e in _ordinals.entries) {
      if (t.contains(e.key)) {
        ref = e.value;
        break;
      }
    }
    String? filter;
    if (t.contains('무료') || t.contains('공짜')) filter = 'free';
    if (t.contains('다들어가') || t.contains('수용')) filter = 'fits_guests';
    if (t.contains('싼') || t.contains('저렴')) filter = 'cheaper';
    if (t.contains('사진')) filter = 'has_photo';

    // 이어받을 이전 턴: 질문이 목적을 말하면 그 목적의 가장 최근 턴, 아니면 직전 턴
    Turn? prev;
    if (history.isNotEmpty) {
      prev = u.intent != ConsultIntent.help
          ? history.lastWhere((h) => h.intent == u.intent, orElse: () => history.last)
          : history.last;
    }
    final pointsBack = ref != null || filter != null;
    if (ref == null && RegExp(r'거기|그거|그곳|그정책|그예식장|그업체').hasMatch(t)) ref = 1;
    if (t.contains('마지막') && prev != null && prev.results.isNotEmpty) ref = prev.results.length;

    final short = t.length <= 12;
    final inherit = prev != null &&
        u.intent == ConsultIntent.help &&
        (pointsBack || ref != null || short) &&
        !RegExp(r'고마|감사|안녕').hasMatch(t);

    return u.copyWith(
      intent: inherit ? prev.intent : u.intent,
      topic: u.topic ?? (inherit ? prev.topic : null),
      item: u.item ?? (inherit || (u.intent == ConsultIntent.vendor && prev?.intent == ConsultIntent.vendor) ? prev?.item : null),
      refIndex: ref,
      filter: filter,
    );
  }
}
