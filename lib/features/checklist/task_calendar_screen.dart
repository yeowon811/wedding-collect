import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/app_state.dart';
import '../../data/models/wedding_plan.dart';

/// 할 일 캘린더: 예식일 기준 할 일(마감일)·상담 일정·예식일을 달력에 표시한다.
/// 날짜를 누르면 그날 일정이 아래에 나오고, 할 일 체크·추가를 할 수 있다.
class TaskCalendarScreen extends StatefulWidget {
  const TaskCalendarScreen({super.key});

  @override
  State<TaskCalendarScreen> createState() => _TaskCalendarScreenState();
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class _TaskCalendarScreenState extends State<TaskCalendarScreen> {
  final _app = AppState.instance;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = _day(DateTime.now());

  DateTime _due(ChecklistTask t) => _day(_app.plan.weddingDate.subtract(Duration(days: t.dMinus)));

  /// 날짜별 일정: 할 일 / 상담 / 예식일
  Map<DateTime, List<_Event>> _events() {
    final map = <DateTime, List<_Event>>{};
    void add(DateTime d, _Event e) => map.putIfAbsent(_day(d), () => []).add(e);
    for (final t in _app.tasks) {
      add(_due(t), _Event.task(t));
    }
    for (final c in _app.consultations) {
      add(c.dateTime, _Event.consult(c));
    }
    add(_app.plan.weddingDate, const _Event.wedding());
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('할 일 캘린더')),
      body: ListenableBuilder(
        listenable: _app,
        builder: (context, _) {
          final events = _events();
          final dayEvents = events[_selected] ?? const [];
          final monthEvents = [
            for (final e in events.entries)
              if (e.key.year == _month.year && e.key.month == _month.month) ...[for (final x in e.value) (e.key, x)],
          ]..sort((a, b) => a.$1.compareTo(b.$1));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _monthHeader(),
              _Legend(),
              const SizedBox(height: 8),
              _grid(events),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: Text(formatDateWithDay(_selected),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: () => _addTask(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('이 날 할 일 추가'),
                ),
              ]),
              if (dayEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('이 날은 일정이 없어요.', style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                for (final e in dayEvents) _eventRow(e, null),
              const SizedBox(height: 20),
              Text('${_month.month}월 일정 ${monthEvents.length}개',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              if (monthEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('이번 달에는 일정이 없어요.', style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                for (final (d, e) in monthEvents) _eventRow(e, d),
            ],
          );
        },
      ),
    );
  }

  Widget _monthHeader() => Row(children: [
        IconButton(
          tooltip: '이전 달',
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text('${_month.year}년 ${_month.month}월',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        IconButton(
          tooltip: '다음 달',
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ]);

  Widget _grid(Map<DateTime, List<_Event>> events) {
    const week = ['일', '월', '화', '수', '목', '금', '토'];
    final first = DateTime(_month.year, _month.month);
    final lead = first.weekday % 7; // 일요일 시작
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final today = _day(DateTime.now());
    final cells = <Widget>[
      for (var i = 0; i < 7; i++)
        Center(
          child: Text(week[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: i == 0 ? AppColors.warning : AppColors.textSecondary,
              )),
        ),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++) _cell(DateTime(_month.year, _month.month, d), events, today),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.82,
      children: cells,
    );
  }

  Widget _cell(DateTime d, Map<DateTime, List<_Event>> events, DateTime today) {
    final list = events[d] ?? const [];
    final selected = d == _selected;
    final wedding = list.any((e) => e.kind == _Kind.wedding);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selected = d),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : (wedding ? const Color(0xFFFFEEF0) : null),
          borderRadius: BorderRadius.circular(10),
          border: d == today && !selected ? Border.all(color: AppColors.primary) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${d.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: list.isEmpty ? FontWeight.w400 : FontWeight.w700,
                color: selected ? Colors.white : (d.weekday == DateTime.sunday ? AppColors.warning : AppColors.textPrimary),
              )),
          const SizedBox(height: 3),
          SizedBox(
            height: 6,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final e in list.take(3))
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: e.color(_app), shape: BoxShape.circle),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _eventRow(_Event e, DateTime? date) {
    final when = date == null ? '' : '${formatDateWithDay(date)} · ';
    switch (e.kind) {
      case _Kind.task:
        final t = e.task!;
        final done = _app.isTaskDone(t);
        final auto = t.category != null && _app.statusOf(t.category!).isDone;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: auto ? null : () => _app.toggleTask(t.id),
          leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? AppColors.success : e.color(_app)),
          title: Text(t.title,
              style: TextStyle(
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? AppColors.textSecondary : AppColors.textPrimary,
              )),
          subtitle: Text('${when}D-${t.dMinus}${auto ? ' · 계약 완료로 자동 체크' : ''}'),
        );
      case _Kind.consult:
        final c = e.consult!;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.event_available, color: e.color(_app)),
          title: Text('상담 · ${c.vendor.name.replaceFirst('[시연] ', '')}'),
          subtitle: Text('$when${c.dateTime.hour}:${c.dateTime.minute.toString().padLeft(2, '0')}'),
        );
      case _Kind.wedding:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.favorite, color: e.color(_app)),
          title: const Text('예식일', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('$when${_app.plan.sido} · 하객 ${_app.plan.guests}명'),
        );
    }
  }

  /// 고른 날짜를 마감일로 할 일 추가 (예식일 며칠 전인지로 저장)
  Future<void> _addTask(BuildContext context) async {
    final dMinus = _day(_app.plan.weddingDate).difference(_selected).inDays;
    if (dMinus < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('예식일 이후 날짜에는 할 일을 추가할 수 없어요')));
      return;
    }
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${formatDateWithDay(_selected)} 할 일'),
        content: TextField(
          controller: title,
          autofocus: true,
          decoration: InputDecoration(hintText: '예: 청첩장 발송', helperText: '예식 $dMinus일 전'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) _app.addTask(title.text, dMinus);
  }
}

enum _Kind { task, consult, wedding }

class _Event {
  const _Event.task(ChecklistTask t)
      : kind = _Kind.task,
        task = t,
        consult = null;
  const _Event.consult(Consultation c)
      : kind = _Kind.consult,
        task = null,
        consult = c;
  const _Event.wedding()
      : kind = _Kind.wedding,
        task = null,
        consult = null;

  final _Kind kind;
  final ChecklistTask? task;
  final Consultation? consult;

  /// 점 색: 할 일(파랑, 끝나면 회색, 지나면 주황) · 상담(초록) · 예식일(분홍)
  Color color(AppState app) => switch (kind) {
        _Kind.wedding => const Color(0xFFF04452),
        _Kind.consult => AppColors.success,
        _Kind.task => app.isTaskDone(task!)
            ? AppColors.textHint
            : (_day(app.plan.weddingDate.subtract(Duration(days: task!.dMinus))).isBefore(_day(DateTime.now()))
                ? AppColors.warning
                : AppColors.primary),
      };
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
        ]);
    return Wrap(alignment: WrapAlignment.center, children: [
      item(AppColors.primary, '할 일'),
      item(AppColors.warning, '시기 지남'),
      item(AppColors.textHint, '완료'),
      item(AppColors.success, '상담'),
      item(const Color(0xFFF04452), '예식일'),
    ]);
  }
}
