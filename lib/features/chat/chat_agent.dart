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

class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.cards = const [],
    this.sources = const [],
  });

  final bool fromUser;
  final String text;
  final List<ChatCard> cards;
  final List<String> sources; // 근거 데이터 출처
}

/// 상담 에이전트 인터페이스.
/// 지금은 [LocalDataAgent](앱 내 데이터 + 규칙)를 쓰고,
/// 생성형 AI를 붙일 때는 같은 인터페이스로 구현해서 바꿔 끼우면 된다.
///
/// 원칙: 가격·자격·예약 가능 여부는 반드시 앱 데이터(도구 결과)에서만 가져오고,
/// AI는 정리·설명만 한다. 외부로는 조건과 후보 ID·요약만 보내고 연락처·개인정보는 보내지 않는다.
abstract class ChatAgent {
  String get name;
  Future<ChatMessage> reply(String question);
}
