import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/models/venue.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/features/venue/widgets/venue_location_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('예식장 240곳 모두 좌표가 한국 안에 있고 네이버 지도 검색 주소가 만들어진다', () async {
    final venues = await Repos.venue.loadAll();
    expect(venues, hasLength(240));
    for (final v in venues) {
      expect(v.lat, inInclusiveRange(33, 39), reason: v.id);
      expect(v.lng, inInclusiveRange(124, 132), reason: v.id);
      final uri = VenueLocationMap.naverMapUri(v);
      expect(uri.host, 'map.naver.com');
      final q = uri.pathSegments.last; // pathSegments는 이미 풀린 글자
      expect(q, isNotEmpty, reason: v.id);
      expect(q.contains('('), isFalse, reason: '${v.id} $q');
    }
  });

  test('네이버 지도 검색어는 도로명·지번 번호까지만', () async {
    final venues = await Repos.venue.loadAll();
    String q(String id) =>
        VenueLocationMap.naverMapUri(venues.firstWhere((Venue v) => v.id == id)).pathSegments.last;
    for (final v in venues) {
      final query = q(v.id);
      expect(query.endsWith('층'), isFalse, reason: '${v.id} $query');
    }
  });
}
