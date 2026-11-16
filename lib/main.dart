import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/chat/agent/gemini_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Gemini 연결 (실패하면 AI 상담은 규칙 기반으로 동작)
  await GeminiClient.init();
  runApp(const WeddingCollectApp());
}
