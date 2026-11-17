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

  test('예식장을 체크리스트에 추가하면 후보로 담기고, 계약하면 이름·대관료가 항목에 들어간다', () async {
    final v = (await Repos.venue.loadAll()).firstWhere((v) => v.isFree && v.capacity != null);
    expect(s.items.any((i) => i.id == AppState.venueItemId), isFalse);
    s.chooseVenue(v);
    final item = s.items.first;
    expect(item.id, AppState.venueItemId);
    expect(item.status, ItemStatus.candidate);
    expect(s.plan.hasSido, isTrue);
    expect(s.plan.sido, v.sido);
    expect(s.chosenVenueId, isNull);

    s.setPlaceStatus(item, 'venue:${v.id}', ItemStatus.contracted);
    expect(item.status, ItemStatus.contracted);
    expect(item.vendorName, v.name);
    expect(item.amount, 0); // 무료
    expect(s.chosenVenueId, v.id);
    expect(s.placeDate['venue:${v.id}'], isNotNull); // 계약일

    s.setPlaceStatus(item, 'venue:${v.id}', ItemStatus.consulting); // 계약 취소
    expect(item.status, ItemStatus.consulting);
    expect(item.vendorName, isNull);
    s.toggleFavorite('venue:${v.id}'); // 빼기
    expect(item.status, ItemStatus.todo);
  });

  test('담은 곳마다 상태: 계약은 한 곳만, 직접 추가한 곳도 계약할 수 있다', () async {
    final dresses = (await Repos.vendor.demoVendors()).where((v) => v.category == VendorCategory.dress).take(2).toList();
    final dress = s.itemFor(VendorCategory.dress)!;
    for (final v in dresses) {
      s.toggleFavorite('vendor:${v.id}');
    }
    final a = 'vendor:${dresses[0].id}', b = 'vendor:${dresses[1].id}';
    s.setPlaceStatus(dress, a, ItemStatus.consulting);
    expect(dress.status, ItemStatus.consulting); // 가장 앞선 단계
    s.setPlaceStatus(dress, a, ItemStatus.contracted);
    expect(s.contracts[VendorCategory.dress]?.$1.id, dresses[0].id); // 업체 상세의 계약 표시와 연동
    s.setPlaceStatus(dress, b, ItemStatus.contracted);
    expect(s.statusOfPlace(a), ItemStatus.consulting); // 계약은 한 곳
    expect(dress.vendorName, dresses[1].name.replaceFirst('[시연] ', ''));
    s.setPlaceAmount(dress, b, 210);
    expect(dress.amount, 210);
    expect(s.confirmedTotal, 210); // 예산에 반영

    final m = s.addManualPlace(dress, '동네 드레스샵', 90);
    s.setPlaceStatus(dress, 'manual:${m.id}', ItemStatus.paid);
    expect(dress.status, ItemStatus.paid);
    expect(dress.vendorName, '동네 드레스샵');
    expect(dress.amount, 90);
    expect(s.statusOfPlace(b), ItemStatus.consulting);
  });

  test('체크리스트에 추가한 예식장은 계정 저장 후 그대로 돌아온다', () async {
    final v = (await Repos.venue.loadAll()).first;
    s.chooseVenue(v);
    s.setPlaceStatus(s.items.first, 'venue:${v.id}', ItemStatus.contracted);
    final m = s.addManualPlace(s.itemFor(VendorCategory.meal)!, '한상 케이터링', 600);
    final saved = jsonDecode(jsonEncode(UserDataCodec.encode(s))) as Map<String, dynamic>;
    s.resetAll();
    expect(s.chosenVenueId, isNull);
    UserDataCodec.apply(s, saved, await Repos.vendor.demoVendors());
    expect(s.chosenVenueId, v.id);
    expect(s.items.first.vendorName, v.name);
    expect(s.manualPlaces.single.name, m.name);
    expect(s.itemFor(VendorCategory.meal)!.status, ItemStatus.candidate);
  });
}
