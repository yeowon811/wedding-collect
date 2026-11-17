import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/candidates.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/data/models/wedding_plan.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/data/user_data_codec.dart';

/// 찜 = 후보 → 체크리스트, 예식장 체크리스트에 추가
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final s = AppState.instance;

  setUpAll(() async {
    await Repos.venue.loadAll();
    await Repos.vendor.realVendors();
    await Repos.vendor.demoVendors();
    await Repos.vendor.options();
  });
  setUp(s.resetAll);

  test('업체를 찜하면 체크리스트 항목의 후보가 되고 상태가 "후보"가 된다', () async {
    final demo = (await Repos.vendor.demoVendors()).firstWhere((v) => v.category == VendorCategory.dress);
    final dress = s.itemFor(VendorCategory.dress)!;
    s.toggleFavorite('vendor:${demo.id}');
    expect(dress.status, ItemStatus.candidate);
    final cands = Candidates.forItem(dress, s);
    expect(cands.single.price, demo.estimate(guests: s.plan.guests));
    expect(Candidates.summary(cands), startsWith('후보 1곳'));

    // 실제 스드메 업체도 드레스 후보 (가격은 문의)
    final real = (await Repos.vendor.realVendors()).firstWhere((v) => v.category == VendorCategory.directing);
    s.toggleFavorite('real:${real.id}');
    expect(Candidates.forItem(dress, s).length, 2);

    s.toggleFavorite('vendor:${demo.id}');
    s.toggleFavorite('real:${real.id}');
    expect(dress.status, ItemStatus.todo); // 후보가 없으면 다시 미정
  });

  test('예식장을 체크리스트에 추가하면 예식장 항목에 이름·대관료가 들어가고 지역이 채워진다', () async {
    final v = (await Repos.venue.loadAll()).firstWhere((v) => v.isFree && v.capacity != null);
    expect(s.items.any((i) => i.id == AppState.venueItemId), isFalse);
    s.chooseVenue(v);
    final item = s.items.first;
    expect(item.id, AppState.venueItemId);
    expect(item.vendorName, v.name);
    expect(item.amount, 0); // 무료
    expect(item.status, ItemStatus.consulting);
    expect(s.plan.hasSido, isTrue);
    expect(s.plan.sido, v.sido);
    expect(s.isFavorite('venue:${v.id}'), isTrue);
    s.clearVenue();
    expect(s.chosenVenueId, isNull);
    expect(item.vendorName, isNull);
  });

  test('체크리스트에 추가한 예식장은 계정 저장 후 그대로 돌아온다', () async {
    final v = (await Repos.venue.loadAll()).first;
    s.chooseVenue(v);
    final saved = jsonDecode(jsonEncode(UserDataCodec.encode(s))) as Map<String, dynamic>;
    s.resetAll();
    expect(s.chosenVenueId, isNull);
    UserDataCodec.apply(s, saved, await Repos.vendor.demoVendors());
    expect(s.chosenVenueId, v.id);
    expect(s.items.first.vendorName, v.name);
  });
}
