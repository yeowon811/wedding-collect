import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/demo_links.dart';
import 'data/account_service.dart';
import 'data/repositories/repositories.dart';
import 'features/chat/agent/gemini_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Gemini 연결 (실패하면 AI 상담은 규칙 기반으로 동작)
  await GeminiClient.init();
  // 로그인 상태 확인 + 저장된 내 정보 불러오기 (시연 링크로 열면 둘러보기로 시작)
  await AccountService.instance.init(startAsGuest: DemoLinks.isDemoLink);
  DemoLinks.applyProfile(); // 웹 ?demo=1 (시연용)
  // 예약 현황(작은 파일)을 미리 읽어 두면 예식장 상세의 달력이 늦게 튀어나오지 않는다. 실패해도 앱은 그대로
  Repos.booking.loadAll().ignore();
  runApp(const WeddingCollectApp());
}
