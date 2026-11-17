import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wedding_collect/core/widgets/inputs.dart';

/// 하객 수·총예산 입력칸: [확인]을 눌러야 저장되고, 범위를 벗어나면 안내한다
void main() {
  testWidgets('입력하고 확인을 누르면 값이 저장된다', (tester) async {
    int? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => NumberConfirmField(
            value: saved,
            unit: '명',
            min: 10,
            max: 2000,
            preview: (v) => '하객 $v명',
            onConfirmed: (v) => setState(() => saved = v),
          ),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '5');
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pump();
    expect(saved, isNull);
    expect(find.text('10~2000명 사이로 입력해 주세요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '120');
    await tester.pump();
    expect(find.text('하객 120명 · 확인을 눌러 저장'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pump();
    expect(saved, 120);
    expect(find.text('저장됨'), findsOneWidget);
    expect(find.text('하객 120명으로 저장했어요'), findsOneWidget);
  });
}
