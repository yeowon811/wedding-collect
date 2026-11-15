import 'package:flutter/widgets.dart';

/// 답변 안에 붙는 결과 카드 (누르면 해당 상세 화면으로 이동)
class ChatCard {
  const ChatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.open,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final Widget Function()? open; // 상세 화면
}

/// 답변 아래에 보여주는 선택 버튼.
/// - 되묻는 질문의 답(예: "서울")이면 [slot]과 [value]를 채워 보낸다.
/// - 이어서 할 질문(예: "예식장도 보기")이면 [text]를 질문처럼 보낸다.
class QuickReply {
  const QuickReply(this.label, {this.slot, this.value, this.text, this.action});

  final String label;
  final String? slot; // 되묻기 답일 때 채울 항목 이름 (Slot.name)
  final Object? value;
  final String? text; // 질문으로 보낼 문장
  final String? action; // 특별 동작 (예: 'save_profile', 'skip_ask')
}

class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.cards = const [],
    this.sources = const [],
    this.quickReplies = const [],
    this.basis,
    this.isQuestion = false,
  });

  final bool fromUser;
  final String text;
  final List<ChatCard> cards;
  final List<String> sources; // 근거 데이터 출처
  final List<QuickReply> quickReplies;
  final String? basis; // 어떤 조건으로 찾았는지 (예: 서울 · 만 20~29세 · 신혼부부)
  final bool isQuestion; // 정보를 되묻는 메시지인지
}

/// 상담 에이전트 인터페이스.
///
/// 지금은 규칙 기반 [ConsultAgent]를 쓰고, 생성형 AI를 붙일 때는 "질문 이해" 단계만
/// LLM으로 바꾸면 된다 (docs/ai-architecture.md 참고).
///
/// 원칙: 가격·자격·예약 가능 여부는 반드시 앱 데이터(도구 결과)에서만 가져오고,
/// AI는 정리·설명만 한다. 외부로는 조건과 후보 ID·요약만 보내고 연락처·개인정보는 보내지 않는다.
abstract class ChatAgent {
  String get name;

  /// 상담 시작: 내 정보로 첫 추천
  Future<ChatMessage> start();

  /// 사용자가 입력한 질문
  Future<ChatMessage> reply(String question);

  /// 사용자가 누른 선택 버튼
  Future<ChatMessage> choose(QuickReply reply);
}
