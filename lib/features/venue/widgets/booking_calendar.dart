import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/app_state.dart';
import '../../../data/models/booking_status.dart';
import '../../../data/repositories/repositories.dart';

/// 예식장 상세의 '예약 현황' 달력.
/// 수집한 스냅샷(공유누리·서울마이웨딩)을 보여 주고, 확인 날짜·출처와 '사이트에서 최종 확인' 안내를 붙인다.
/// 예약 현황이 공개되지 않는 예식장은 한 줄 안내만 보여 준다.
class BookingCalendarSection extends StatelessWidget {
  const BookingCalendarSection({super.key, required this.venueId, this.onOpenSource});

  final String venueId;
  final void Function(String url)? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final loaded = Repos.booking.cached;
    return FutureBuilder<BookingStatus?>(
      // 이미 읽어 뒀으면 기다리지 않고 바로 그린다
      future: loaded != null ? null : Repos.booking.of(venueId),
      initialData: loaded?[venueId],
      builder: (context, snap) {
        if (loaded == null && snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final s = snap.data;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('예약 현황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (s == null)
                Text('이 예식장은 날짜별 예약 현황이 공개되지 않아요. 예약 페이지나 문의처에서 확인해 주세요.',
                    style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary))
              else
                BookingCalendar(status: s, onOpenSource: onOpenSource),
            ],
          ),
        );
      },
    );
  }
}

class BookingCalendar extends StatefulWidget {
  const BookingCalendar({super.key, required this.status, this.onOpenSource, this.initialMonth});

  final BookingStatus status;
  final void Function(String url)? onOpenSource;
  final DateTime? initialMonth;

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class _BookingCalendarState extends State<BookingCalendar> {
  BookingStatus get s => widget.status;
  late DateTime _month;
  DateTime? _selected;
  DateTime? _wedding;

  @override
  void initState() {
    super.initState();
    final plan = AppState.instance.plan;
    _wedding = plan.hasDate ? _day(plan.weddingDate) : null;
    // 내 예식일이 수집 범위 안이면 그 달부터, 아니면 이번 달부터
    final start = widget.initialMonth ??
        (_wedding != null && s.covers(_wedding!) ? _wedding! : DateTime.now());
    _month = DateTime(start.year, start.month);
    _selected = _wedding != null && s.covers(_wedding!) ? _wedding : null;
  }

  bool get _canPrev => DateTime(_month.year, _month.month).isAfter(DateTime(s.from.year, s.from.month));
  bool get _canNext => DateTime(_month.year, _month.month).isBefore(DateTime(s.to.year, s.to.month));

  @override
  Widget build(BuildContext context) {
    final monthOpen = s.openBetween(_month, DateTime(_month.year, _month.month + 1, 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${s.checkedLabel} · 이후 바뀔 수 있어요',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Column(children: [
            Row(children: [
              IconButton(
                tooltip: '이전 달',
                onPressed: _canPrev ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(children: [
                  Text('${_month.year}년 ${_month.month}월',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('예약 가능 ${monthOpen.length}일',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ]),
              ),
              IconButton(
                tooltip: '다음 달',
                onPressed: _canNext ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ]),
            _grid(),
          ]),
        ),
        const SizedBox(height: 8),
        _legend(),
        if (_selected != null) ...[
          const SizedBox(height: 10),
          _selectedLine(_selected!),
        ],
        const SizedBox(height: 8),
        Text(
          '불가: ${s.closedMeaning}. 실제 예약은 ${s.source}에서 다시 확인해 주세요.',
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
        ),
        if (widget.onOpenSource != null)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => widget.onOpenSource!(s.sourceUrl),
            child: Text('${s.source}에서 최신 현황 보기'),
          ),
      ],
    );
  }

  Widget _grid() {
    const week = ['일', '월', '화', '수', '목', '금', '토'];
    final first = DateTime(_month.year, _month.month);
    final lead = first.weekday % 7; // 일요일 시작
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: [
        for (var i = 0; i < 7; i++)
          Center(
            child: Text(week[i],
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: i == 0 ? AppColors.warning : AppColors.textSecondary)),
          ),
        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
        for (var d = 1; d <= days; d++) _cell(DateTime(_month.year, _month.month, d)),
      ],
    );
  }

  Widget _cell(DateTime d) {
    final state = s.on(d);
    final selected = d == _selected;
    final wedding = d == _wedding;
    final (bg, fg) = switch (state) {
      DayBooking.open => (AppColors.successSoft, AppColors.success),
      DayBooking.closed => (AppColors.fill, AppColors.unknown),
      DayBooking.unknown => (Colors.transparent, AppColors.textSecondary),
    };
    return Semantics(
      label: '${d.month}월 ${d.day}일 ${state.label}${wedding ? ', 내 예식일' : ''}',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selected = d),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : bg,
            borderRadius: BorderRadius.circular(8),
            border: wedding && !selected ? Border.all(color: AppColors.primary, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${d.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: state == DayBooking.open ? FontWeight.w700 : FontWeight.w400,
              color: selected ? Colors.white : fg,
              decoration: state == DayBooking.closed ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.unknown,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color bg, String label, {Color? border}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(3),
              border: border != null ? Border.all(color: border, width: 1.5) : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]);
    return Wrap(spacing: 12, runSpacing: 4, children: [
      item(AppColors.successSoft, '예약 가능'),
      item(AppColors.fill, '예약 불가'),
      item(Colors.transparent, '정보 없음', border: AppColors.divider),
      if (_wedding != null) item(Colors.transparent, '내 예식일', border: AppColors.primary),
    ]);
  }

  Widget _selectedLine(DateTime d) {
    final state = s.on(d);
    final slots = s.slotsOn(d);
    final text = switch (state) {
      DayBooking.open => '예약 가능${slots.isNotEmpty ? ' (${slots.join(', ')})' : ''}',
      DayBooking.closed => '예약 불가 (${s.closedMeaning})',
      DayBooking.unknown => s.covers(d) ? '이 날은 예식 접수 정보가 없어요' : '수집한 기간 밖이라 알 수 없어요',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: state == DayBooking.open ? AppColors.successSoft : AppColors.fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${formatDateWithDay(d)}${d == _wedding ? ' (내 예식일)' : ''} · $text',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: state == DayBooking.open ? AppColors.success : AppColors.textPrimary,
        ),
      ),
    );
  }
}
