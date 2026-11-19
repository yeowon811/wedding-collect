import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/chat/agent/gemini_client.dart';
import 'package:wedding_collect/features/chat/agent/venue_features.dart';

/// AI 예시 후기: 모든 예식장에 있고, 숫자는 그 예식장 정보에 있는 것만 쓴다
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('예식장마다 AI 예시 후기가 있고 별점은 1~5', () async {
    final venues = await Repos.venue.loadAll();
    final reviews = await Repos.venueReview.loadAll();
    expect(venues.every((v) => (reviews[v.id] ?? const []).isNotEmpty), isTrue);
    expect(reviews.values.expand((x) => x).every((r) => r.rating >= 1 && r.rating <= 5), isTrue);
  });

  test('후기 속 숫자는 예식장 정보(정원·대관료·주차 등)에 있는 숫자뿐', () async {
    final venues = {for (final v in await Repos.venue.loadAll()) v.id: v};
    final reviews = await Repos.venueReview.loadAll();
    for (final e in reviews.entries) {
      final v = venues[e.key]!;
      final src = [v.region, v.capacityLabel, v.feeLabel, VenueFeatures.parking(v).text,
        VenueFeatures.reception(v).text, v.indoorOutdoor, v.target, v.name].whereType<String>().join(' ');
      for (final r in e.value) {
        expect(GeminiClient.numbersAreGrounded(r.text, src), isTrue, reason: '${e.key}: ${r.text}');
      }
    }
  });
}
