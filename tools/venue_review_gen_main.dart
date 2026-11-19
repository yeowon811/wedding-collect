// 공공예식장 'AI 예시 후기' 생성기 (2026-11-19)
// 예식장마다 앱 데이터(정원·대관료·주차·피로연·실내외·예약 방식)만 Gemini에 주고, 그 정보로 쓴 예시 후기 2개를 받는다.
// - 실제 이용 후기가 아니므로 앱은 항상 "AI로 작성된 예시 후기" 표시와 함께 보여 준다 (venue_reviews.dart)
// - 정보에 없는 숫자가 들어간 후기는 버린다 (GeminiClient.numbersAreGrounded)
// - 이름·연락처 같은 개인정보는 보내지 않는다 (예식장 공개 정보만)
// 실행: flutter run -d chrome --dart-define-from-file=secrets.json -t tools/venue_review_gen_main.dart
//   `VREV\t{json}` 줄을 모아 assets/data/venue_reviews.json으로 저장 (tools/save_venue_reviews.py)
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:wedding_collect/data/models/venue.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/gemini_client.dart';
import 'package:wedding_collect/features/chat/agent/venue_features.dart';

const _batch = 6;

const _prompt = '''
너는 결혼 준비 앱의 '예시 후기' 작성기다. 앱 화면에 "AI로 작성된 예시 후기"라고 표시되며, 이 기능이 어떤 모습일지 보여 주는 용도다.
예식장마다 주어진 "정보"만 근거로, 그 예식장에서 결혼식을 올린 사람이 쓴 것 같은 짧은 후기 2개를 쓴다.

규칙:
- 정보에 없는 사실은 쓰지 않는다: 직원 태도, 음식 맛, 날씨, 사고, 가격 흥정, 다른 업체 이름 등 지어내지 않는다.
- 숫자는 정보에 나온 숫자만 쓴다. 하객 수·금액·주차 대수를 새로 만들지 않는다.
- 정보에서 좋은 점(무료·저렴한 대관료, 넓은 정원, 주차, 야외, 피로연 가능 등)과 아쉬울 수 있는 점(직접 준비할 것, 정보 없음 등)을 자연스럽게 담는다.
- 2~3문장, 존댓말 아닌 후기 말투(~했어요, ~좋았어요). 과장 광고 말투 금지.
- rating: 1~5 정수. 대부분 4~5, 아쉬운 점이 큰 정보면 3.
- tags: 아래 중 1~2개만: 대관료 부담 적음, 넓어요, 아담해요, 주차 편해요, 야외 분위기, 피로연 가능, 준비할 게 많아요, 예약 쉬워요, 교통 확인 필요
''';

final _schema = Schema.object(properties: {
  'venues': Schema.array(
    items: Schema.object(properties: {
      'id': Schema.string(),
      'reviews': Schema.array(
        items: Schema.object(properties: {
          'rating': Schema.integer(),
          'text': Schema.string(),
          'tags': Schema.array(items: Schema.string()),
        }),
      ),
    }),
  ),
});

/// 예식장 공개 정보 (연락처·주소 번지 없이)
String _facts(Venue v) {
  final p = VenueFeatures.parking(v);
  final r = VenueFeatures.reception(v);
  return [
    '이름: ${v.name}',
    '지역: ${v.region}',
    '정원: ${v.capacityLabel}',
    '대관료: ${v.feeLabel}',
    '예약: ${v.bookingType.label}',
    if (p.text != null) '주차: ${p.text}',
    if (r.text != null) '피로연: ${r.text}',
    if (v.indoorOutdoor != null) '실내외: ${v.indoorOutdoor}',
    if (v.target != null) '이용 대상: ${v.target}',
  ].join(' / ');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('AI 예시 후기 만드는 중…')))));
  await GeminiClient.init();
  if (GeminiClient.instance == null) {
    debugPrint('VREV_ERROR\tGemini 연결 실패');
    return;
  }
  final model = FirebaseAI.googleAI().generativeModel(
    model: GeminiClient.modelName,
    systemInstruction: Content.system(_prompt),
    generationConfig: GenerationConfig(
      temperature: 0.7,
      responseMimeType: 'application/json',
      responseSchema: _schema,
      thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.minimal),
    ),
  );
  const onlyRaw = String.fromEnvironment('ONLY');
  final only = onlyRaw.isEmpty ? null : onlyRaw.split(',').toSet();
  final venues = (await Repos.venue.loadAll()).where((v) => only == null || only.contains(v.id)).toList();
  final facts = {for (final v in venues) v.id: _facts(v)};
  for (var i = 0; i < venues.length; i += _batch) {
    final part = venues.skip(i).take(_batch).toList();
    final ask = part.map((v) => 'id ${v.id}: ${facts[v.id]}').join('\n');
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await model.generateContent([Content.text(ask)]).timeout(const Duration(seconds: 40));
        final out = (jsonDecode(res.text ?? '{}') as Map)['venues'] as List? ?? const [];
        for (final e in out.cast<Map>()) {
          final id = e['id'] as String?;
          final src = facts[id];
          if (src == null) continue;
          final ok = [
            for (final r in (e['reviews'] as List? ?? const []).cast<Map>())
              if (GeminiClient.numbersAreGrounded('${r['text']}', src) &&
                  (r['rating'] as num?) != null &&
                  (r['rating'] as num) >= 1 &&
                  (r['rating'] as num) <= 5)
                {'rating': (r['rating'] as num).toInt(), 'text': '${r['text']}'.trim(), 'tags': r['tags'] ?? const []},
          ];
          debugPrint('VREV\t${jsonEncode({'id': id, 'reviews': ok})}', wrapWidth: 1000000);
        }
        break;
      } catch (e) {
        debugPrint('VREV_RETRY\t$i\t$e');
        await Future<void>.delayed(const Duration(seconds: 20));
      }
    }
    await Future<void>.delayed(const Duration(seconds: 8)); // 분당 사용량 한도
  }
  debugPrint('VREV_DONE');
}
