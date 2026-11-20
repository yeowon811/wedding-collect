import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';

/// 빈 정원·대관료는 모든 곳에서 '문의로 확인해 주세요' + 연결처 (2026-11-20)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('정원·대관료가 빈 예식장은 모두 안내 문구와 연결처(전화 또는 예약 페이지)가 있다', () async {
    final venues = await Repos.venue.loadAll();
    final gaps = venues.where((v) => v.capacity == null || v.rentalFee == null).toList();
    expect(gaps, hasLength(91));
    for (final v in gaps) {
      if (v.capacity == null) {
        expect(v.capacityGap, contains('문의로 확인해 주세요'), reason: v.id);
        expect(v.capacityLabel, '정원 문의 필요');
      }
      if (v.rentalFee == null) {
        expect(v.feeGap, contains('문의로 확인해 주세요'), reason: v.id);
        expect(v.feeLabel, '대관료 문의 필요');
      }
      expect(v.phone != null || v.bookingUrl.startsWith('http'), isTrue, reason: '${v.id} 연결처 없음');
    }
  });

  test('요금 원문 종류에 따라 안내가 다르다', () async {
    final venues = {for (final v in await Repos.venue.loadAll()) v.id: v};
    expect(venues['H057']!.feeGap, startsWith('협의 후 결정')); // "협의 후 결정"
    expect(venues['H119']!.feeGap, startsWith('정확한 금액은')); // 시간당 요금 원문
    expect(venues['H004']!.capacityGap, startsWith('시간대마다')); // "시간별 상이"
    expect(venues['H079']!.capacityGap, startsWith('정보 없음')); // 공유누리 "1명" 등록 오류
    expect(venues['H079']!.phone, '02-2133-6546');
    expect(venues['H168']!.phone, '052-120'); // 울산 콜센터
  });
}
