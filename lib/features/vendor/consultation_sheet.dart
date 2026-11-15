import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import '../../data/models/wedding_plan.dart';

const _hours = [10, 11, 13, 14, 15, 16, 18];

/// 가상 업체의 예약 가능 여부 (업체·날짜·시간으로 정해지는 고정 패턴, 시연용)
bool _isOpen(DemoVendor v, DateTime day, int hour) {
  if (day.weekday == DateTime.monday) return false; // 월요일 휴무
  final seed = v.id.codeUnits.fold(0, (a, b) => a * 31 + b) + day.day * 7 + day.month * 13 + hour;
  return seed % 3 != 0;
}

/// 상담 신청: 날짜 → 시간 → 메모 → 완료
Future<void> showConsultationSheet(BuildContext context, DemoVendor vendor) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _ConsultationSheet(vendor: vendor),
  );
}

class _ConsultationSheet extends StatefulWidget {
  const _ConsultationSheet({required this.vendor});

  final DemoVendor vendor;

  @override
  State<_ConsultationSheet> createState() => _ConsultationSheetState();
}

class _ConsultationSheetState extends State<_ConsultationSheet> {
  final _today = DateTime.now();
  late final _days = [
    for (var i = 1; i <= 14; i++) DateTime(_today.year, _today.month, _today.day + i),
  ];
  late DateTime _day = _days.firstWhere((d) => d.weekday != DateTime.monday);
  int? _hour;
  final _memo = TextEditingController();

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  void _submit() {
    final c = Consultation(
      vendor: widget.vendor,
      dateTime: DateTime(_day.year, _day.month, _day.day, _hour!),
      memo: _memo.text.trim(),
    );
    AppState.instance.addConsultation(c);
    // 시트를 닫으면 이 화면의 context는 사라지므로, 닫기 전에 바깥 화면의 navigator를 잡아 둔다
    final navigator = Navigator.of(context);
    navigator.pop();
    showDialog(
      context: navigator.context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.check_circle, color: AppColors.success, size: 40),
        title: const Text('상담 신청 완료'),
        content: Text(
          '${widget.vendor.name}\n${formatDateWithDay(c.dateTime)} ${_hour.toString().padLeft(2, '0')}:00\n\n'
          '체크리스트 탭의 "내 상담 일정"에서 확인할 수 있어요.\n(시연용: 실제로 업체에 전달되지 않아요)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('상담 신청', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(v.name, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          const Text('날짜', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final d in _days)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(d.weekday == DateTime.monday
                          ? '${formatDateWithDay(d)}\n휴무'
                          : formatDateWithDay(d), textAlign: TextAlign.center),
                      selected: _day == d,
                      showCheckmark: false,
                      onSelected: d.weekday == DateTime.monday
                          ? null
                          : (_) => setState(() {
                                _day = d;
                                _hour = null;
                              }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('시간', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in _hours)
                ChoiceChip(
                  label: Text(_isOpen(v, _day, h) ? '$h:00' : '$h:00 마감'),
                  selected: _hour == h,
                  showCheckmark: false,
                  onSelected: _isOpen(v, _day, h) ? (_) => setState(() => _hour = h) : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _memo,
            decoration: const InputDecoration(
              labelText: '요청 사항 (선택)',
              hintText: '예: 공공예식장 야외 예식이에요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _hour == null ? null : _submit,
            child: Text(_hour == null ? '시간을 선택해 주세요' : '상담 신청하기'),
          ),
        ],
      ),
    );
  }
}
