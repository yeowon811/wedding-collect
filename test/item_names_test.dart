import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/features/chat/agent/understanding.dart';

/// 준비 항목 이름 정리 (11-21 사용자 요청)
void main() {
  test('새 이름', () {
    expect(VendorCategory.snap.label, '본식 스냅');
    expect(VendorCategory.props.label, '부케·웨딩 케이크');
    expect(VendorCategory.suit.label, '신랑 예복');
    expect(VendorCategory.hanbok.label, '혼주 한복');
    expect(VendorCategory.parentMakeup.label, '혼주 헤어·메이크업');
    // 예산에서는 식대, 업체를 고를 때는 하객 식사
    expect(VendorCategory.meal.label, '식대');
    expect(VendorCategory.meal.vendorLabel, '하객 식사');
    expect(VendorCategory.hanbok.description, '양가 부모님 의상');
  });

  test('예전 저장 이름은 새 이름으로', () {
    expect(VendorCategory.renamed['어머니 한복'], '혼주 한복');
    expect(VendorCategory.renamed['신랑 정장'], '신랑 예복');
  });

  test('"혼주 한복"은 혼주 헤어·메이크업이 아니라 한복, 예전 말도 그대로 알아듣는다', () {
    final r = RuleUnderstander();
    expect(r.parse('혼주 한복 대여 얼마야?').item, VendorCategory.hanbok);
    expect(r.parse('어머니 한복 대여는 보통 얼마야?').item, VendorCategory.hanbok);
    expect(r.parse('혼주 메이크업 추천').item, VendorCategory.parentMakeup);
    expect(r.parse('신랑 예복 어디서 해?').item, VendorCategory.suit);
    expect(r.parse('본식 스냅 추천해줘').item, VendorCategory.snap);
  });
}
