import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/region_fields.dart';
import '../../data/models/user_profile.dart';
import 'chat_agent.dart';

/// 채팅 안 미니 폼 (Red Team P2-2, 2026-11-20): 정책 질문에 빠진 조건이 2개 이상이면 하나씩 되묻지 않고
/// 카드 한 장에서 사는 곳·만 나이·결혼 단계(또는 예식일)·주택을 한 번에 고른다.
/// [조건 적용하고 결과 보기] → QuickReply(action: 'form')로 에이전트에 넘기고, 에이전트가 자기 정보로 저장(위쪽 조건 칩)한 뒤 답한다.
/// slots: region · age · stage · homeless
class MiniFormCard extends StatefulWidget {
  const MiniFormCard({super.key, required this.slots, required this.initial, required this.onSubmit});

  final List<String> slots;
  final UserProfile initial;
  final void Function(QuickReply reply) onSubmit;

  @override
  State<MiniFormCard> createState() => _MiniFormCardState();
}

class _MiniFormCardState extends State<MiniFormCard> {
  late String? _sido = widget.initial.sido;
  late String? _sigungu = widget.initial.sigungu;
  late int? _age = widget.initial.age;
  late MarriageStage? _stage = widget.initial.stageInput;
  late DateTime? _date = widget.initial.weddingDate;
  late bool? _homeless = widget.initial.homeless;

  bool has(String s) => widget.slots.contains(s);

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today.add(const Duration(days: 180)),
      firstDate: DateTime(today.year - 10),
      lastDate: today.add(const Duration(days: 365 * 3)),
      helpText: '예식일을 골라 주세요',
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// 고른 값 → 에이전트로 보낼 답 (빈 값은 '잘 모름'으로 건너뜀)
  QuickReply _reply({bool skipAll = false}) {
    final stage = _date != null ? null : _stage;
    final v = <String, Object?>{
      if (!skipAll && has('region') && _sido != null) 'sido': _sido,
      if (!skipAll && has('region') && _sido != null && _sigungu != null) 'sigungu': _sigungu,
      if (!skipAll && has('age') && _age != null) 'age': _age,
      if (!skipAll && has('stage') && stage != null) 'stage': stage.name,
      if (!skipAll && has('stage') && _date != null) 'weddingDate': _date!.toIso8601String().substring(0, 10),
      if (!skipAll && has('homeless') && _homeless != null) 'homeless': _homeless,
      'slots': widget.slots,
    };
    final label = skipAll
        ? '잘 모르겠어요'
        : [
            if (v['sido'] != null) '${v['sido']}${v['sigungu'] == null ? '' : ' ${v['sigungu']}'}',
            if (v['age'] != null) '만 ${v['age']}세',
            if (v['stage'] != null) stage!.label,
            if (_date != null && has('stage')) '예식일 ${formatDate(_date!)}',
            if (v['homeless'] != null) _homeless! ? '무주택' : '집 있음',
          ].join(' · ');
    return QuickReply(label.isEmpty ? '잘 모르겠어요' : label, action: 'form', value: v);
  }

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary);
    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: label),
            const SizedBox(height: 6),
            child,
          ]),
        );
    Widget choice(String text, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(text),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        );
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('조건을 한 번에 골라 주세요',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 4),
        Text('모르는 항목은 비워 두면 그 조건 없이 찾아요. 고른 값은 내 정보에 저장돼요.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        if (has('region'))
          section('사는 곳', RegionFields(sido: _sido, sigungu: _sigungu, onChanged: (s, g) => setState(() {
                _sido = s;
                _sigungu = g;
              }))),
        if (has('age'))
          section('만 나이', StepperField(
            value: _age,
            min: 19,
            max: 60,
            initial: 29,
            prefix: '만 ',
            unit: '세',
            label: '만 나이',
            onChanged: (v) => setState(() => _age = v),
          )),
        if (has('stage'))
          section(
            '결혼 단계',
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              choice('예비부부', _date == null && _stage == MarriageStage.engaged, () => setState(() {
                    _stage = MarriageStage.engaged;
                    _date = null;
                  })),
              choice('신혼부부 (혼인신고 함)', _date == null && _stage == MarriageStage.married, () => setState(() {
                    _stage = MarriageStage.married;
                    _date = null;
                  })),
              ActionChip(
                avatar: Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primary),
                label: Text(_date == null ? '예식일 고르기' : '예식일 ${formatDate(_date!)}'),
                onPressed: _pickDate,
              ),
            ]),
          ),
        if (has('homeless'))
          section(
            '주택',
            Wrap(spacing: 6, runSpacing: 6, children: [
              choice('무주택', _homeless == true, () => setState(() => _homeless = true)),
              choice('집 있음', _homeless == false, () => setState(() => _homeless = false)),
              choice('잘 모름', _homeless == null, () => setState(() => _homeless = null)),
            ]),
          ),
        Row(children: [
          TextButton(onPressed: () => widget.onSubmit(_reply(skipAll: true)), child: const Text('잘 모르겠어요')),
          const Spacer(),
          FilledButton(onPressed: () => widget.onSubmit(_reply()), child: const Text('조건 적용하고 결과 보기')),
        ]),
      ]),
    );
  }
}

/// 공유받은 조건 안내 띠 (내 정보가 이미 있을 때만): [바꾸기] [그대로]
class SharedConditionsBanner extends StatelessWidget {
  const SharedConditionsBanner({super.key, required this.summary, required this.onApply, required this.onKeep});

  final String summary;
  final VoidCallback onApply;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text('공유받은 조건으로 바꿀까요?\n$summary',
                  style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textBody)),
            ),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: onKeep, child: const Text('그대로')),
            TextButton(onPressed: onApply, child: const Text('바꾸기')),
          ]),
        ]),
      );
}
