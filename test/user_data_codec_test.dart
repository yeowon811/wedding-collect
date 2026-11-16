import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/data/app_state.dart';
import 'package:wedding_collect/data/models/user_profile.dart';
import 'package:wedding_collect/data/models/vendor.dart';
import 'package:wedding_collect/data/models/wedding_plan.dart';
import 'package:wedding_collect/data/repositories/repositories.dart';
import 'package:wedding_collect/data/user_data_codec.dart';

/// 계정 저장: 내 정보를 저장용 데이터로 바꿨다가 다시 불러오면 그대로여야 한다
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('저장 → 초기화 → 불러오기 하면 내 정보가 그대로 돌아온다', () async {
    final s = AppState.instance;
    final vendors = await Repos.vendor.demoVendors();
    final dress = vendors.firstWhere((v) => v.category == VendorCategory.dress);

    s.saveProfile(UserProfile(
      sido: '부산',
      age: 31,
      stage: MarriageStage.married,
      marriedYears: 2,
      weddingDate: DateTime(2027, 5, 1),
      guests: 150,
      budget: 2500,
      homeless: true,
    ));
    s.addItem('신혼여행', status: ItemStatus.paid, amount: 400, vendorName: '○○ 여행사');
    s.contract(dress);
    s.addConsultation(Consultation(vendor: dress, dateTime: DateTime(2026, 12, 5, 14), memo: '가봉 상담'));
    final task = s.addTask('예물 맞추기', 120);
    s.toggleTask(task.id);
    s.removeItem(s.itemFor(VendorCategory.hanbok)!);

    // Firestore에 들어가는 형태(JSON)로 바꿔도 깨지지 않는지
    final saved = jsonDecode(jsonEncode(UserDataCodec.encode(s))) as Map<String, dynamic>;

    s.resetAll();
    expect(s.items.length, 11);
    expect(s.profile.sido, isNull);

    UserDataCodec.apply(s, saved, vendors);
    expect(s.profile.sido, '부산');
    expect(s.profile.stage, MarriageStage.married);
    expect(s.profileDone, isTrue);
    expect(s.plan.budget, 2500);
    expect(s.items.any((i) => i.name == '신혼여행' && i.status == ItemStatus.paid && i.amount == 400), isTrue);
    expect(s.itemFor(VendorCategory.hanbok), isNull); // 지운 항목은 지운 채로
    expect(s.statusOf(VendorCategory.dress), ItemStatus.contracted);
    expect(s.contracts[VendorCategory.dress]?.$1.id, dress.id);
    expect(s.consultations.single.memo, '가봉 상담');
    expect(s.tasks.any((t) => t.title == '예물 맞추기'), isTrue);
    expect(s.isTaskDone(s.tasks.firstWhere((t) => t.title == '예물 맞추기')), isTrue);
    expect(saved.containsKey('email'), isFalse); // 이메일은 저장하지 않음
  });
}
