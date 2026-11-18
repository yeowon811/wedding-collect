import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/data/user_data_codec.dart';

/// 찜 저장, 시연 업체 추가 옵션
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('찜은 계정 저장 후 그대로 돌아온다', () async {
    final s = AppState.instance..resetAll();
    s.toggleFavorite('venue:H078');
    s.toggleFavorite('real:V003');
    s.toggleFavorite('policy:P001');
    s.toggleFavorite('policy:P001'); // 다시 누르면 해제

    final saved = jsonDecode(jsonEncode(UserDataCodec.encode(s))) as Map<String, dynamic>;
    s.resetAll();
    expect(s.favorites, isEmpty);

    UserDataCodec.apply(s, saved, await Repos.vendor.demoVendors());
    expect(s.favorites, {'venue:H078', 'real:V003'});
    s.resetAll();
  });

  test('찜과 체크리스트는 따로 저장되고, 예전 저장본은 찜을 체크리스트로 옮긴다', () async {
    final s = AppState.instance..resetAll();
    s.toggleFavorite('vendor:D0001');
    s.toggleFavorite('policy:P001');
    s.toggleChecklist('vendor:D0002');
    final saved = jsonDecode(jsonEncode(UserDataCodec.encode(s))) as Map<String, dynamic>;
    s.resetAll();
    UserDataCodec.apply(s, saved, await Repos.vendor.demoVendors());
    expect(s.favorites, {'vendor:D0001', 'policy:P001'});
    expect(s.checklistRefs, {'vendor:D0002'});
    s.toggleFavorite('vendor:D0001'); // 찜을 빼도 체크리스트는 그대로
    expect(s.inChecklist('vendor:D0002'), isTrue);

    // 예전 저장본: checklistRefs가 없으면 찜(정책 제외)이 체크리스트에 담겨 있던 것
    saved.remove('checklistRefs');
    s.resetAll();
    UserDataCodec.apply(s, saved, await Repos.vendor.demoVendors());
    expect(s.checklistRefs, {'vendor:D0001'});
    s.resetAll();
  });

  test('시연 업체는 등급과 추가 옵션이 있고 가격이 기준가 주변이다', () async {
    final demo = await Repos.vendor.demoVendors();
    expect(demo.map((v) => v.tier).toSet(), {'실속', '표준', '프리미엄'});
    expect(demo.where((v) => v.addOns.isNotEmpty).length, greaterThan(400));
    final dress = demo.where((v) => v.category.name == 'dress');
    // 드레스 기준: 실속 100만 ~ 일반 150만 → 너무 벗어나지 않게 (40~300만)
    expect(dress.every((v) => v.priceMin >= 40 && v.priceMax <= 300), isTrue);
  });
}
