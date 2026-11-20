import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// 입력 화면 공용 부품 (디자인 시안 A).
/// - 숫자를 정확히 넣어야 하는 값(나이)은 슬라이더 대신 [StepperField]: − / + 와 숫자 직접 입력
/// - 대략 고르는 값(하객 수·예산)은 [PresetPicker]: 자주 쓰는 값 칩 + "직접 입력"
/// - 묶음 제목은 [FormSection]: 아이콘·테두리 없이 제목과 간격으로만 구분

/// 화면 아래에 고정되는 주요 행동 버튼 영역. 화면마다 같은 자리·같은 모양을 쓴다.
/// 버튼 규칙: 주 행동 1개는 [FilledButton](파랑), 보조는 [OutlinedButton], 둘을 나란히 둘 때는 보조가 왼쪽·좁게.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: children)),
    );
  }
}

/// 보조 + 주 버튼 한 줄 (예: [전화 문의] [예약 페이지 열기])
class ActionPair extends StatelessWidget {
  const ActionPair({super.key, required this.secondary, required this.primary});

  final Widget secondary; // OutlinedButton
  final Widget primary; // FilledButton

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 2, child: secondary),
      const SizedBox(width: 8),
      Expanded(flex: 3, child: primary),
    ]);
  }
}

/// 입력 묶음: 제목(+선택 설명) 아래에 입력 부품
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, this.hint, required this.child, this.trailing});

  final String title;
  final String? hint;
  final Widget child;
  final Widget? trailing; // 제목 오른쪽 (예: 현재 값)

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            ?trailing,
          ]),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// − 값 + . 값을 누르면 키패드로 직접 입력. [value]가 null이면 "입력 안 함"
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.unit = '',
    this.prefix = '',
    this.initial,
    this.step = 1,
    this.label,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String unit; // 예: 세
  final String prefix; // 예: 만
  final int? initial; // 입력 안 한 상태에서 −/+를 누를 때 시작 값
  final String? label; // 직접 입력 창 제목

  int get _start => initial ?? ((min + max) ~/ 2);

  Future<void> _type(BuildContext context) async {
    final controller = TextEditingController(text: value?.toString() ?? '');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label ?? '직접 입력'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(hintText: '$min~$max', suffixText: unit),
          onSubmitted: (t) => Navigator.pop(ctx, int.tryParse(t)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)), child: const Text('확인')),
        ],
      ),
    );
    if (result != null) onChanged(result.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    Widget round(IconData icon, String tip, VoidCallback? onTap) => SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: tip,
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.fill,
              disabledBackgroundColor: AppColors.fill.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(icon, size: 20),
          ),
        );
    return Row(children: [
      round(Icons.remove, '줄이기', v != null && v <= min ? null : () => onChanged(((v ?? _start) - step).clamp(min, max))),
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _type(context),
          child: SizedBox(
            height: 48,
            child: Center(
              child: v == null
                  ? Text('눌러서 입력', style: TextStyle(fontSize: 16, color: AppColors.textHint))
                  : Text.rich(TextSpan(children: [
                      if (prefix.isNotEmpty)
                        TextSpan(text: prefix, style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      TextSpan(
                          text: '$v',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      TextSpan(text: unit, style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                    ])),
            ),
          ),
        ),
      ),
      round(Icons.add, '늘리기', v != null && v >= max ? null : () => onChanged(((v ?? _start - step) + step).clamp(min, max))),
    ]);
  }
}

/// 자주 쓰는 값 칩 + "직접 입력". 목록에 없는 값을 넣으면 "직접 입력" 칩이 선택된 상태가 된다.
class PresetPicker extends StatelessWidget {
  const PresetPicker({
    super.key,
    required this.value,
    required this.presets,
    required this.format,
    required this.onChanged,
    this.unit = '',
    this.min = 1,
    this.max = 100000,
    this.label,
  });

  final int? value;
  final List<int> presets;
  final String Function(int) format;
  final ValueChanged<int> onChanged;
  final String unit; // 직접 입력 창의 단위 (예: 명, 만원)
  final int min;
  final int max;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final custom = value != null && !presets.contains(value);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in presets)
          ChoiceChip(label: Text(format(p)), selected: value == p, onSelected: (_) => onChanged(p)),
        ChoiceChip(
          // 목록에 없는 값을 직접 넣었으면 "직접 입력" 칩이 선택된 상태로 보인다 (이름은 그대로)
          label: const Text('직접 입력'),
          selected: custom,
          avatar: Icon(Icons.edit_outlined, size: 16, color: custom ? Colors.white : AppColors.textBody),
          onSelected: (_) async {
            final controller = TextEditingController(text: value?.toString() ?? '');
            final r = await showDialog<int>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(label ?? '직접 입력'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(suffixText: unit),
                  onSubmitted: (t) => Navigator.pop(ctx, int.tryParse(t)),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)), child: const Text('확인')),
                ],
              ),
            );
            if (r != null) onChanged(r.clamp(min, max));
          },
        ),
      ],
    );
  }
}

/// 둘~넷 중 하나 고르기 (가로로 꽉 차는 회색 칸, 선택되면 검정)
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < options.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: value == options[i].$1 ? AppColors.ink : AppColors.fill,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(options[i].$1),
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    options[i].$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: value == options[i].$1 ? FontWeight.w700 : FontWeight.w500,
                      color: value == options[i].$1 ? Colors.white : AppColors.textBody,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// 숫자 입력칸 + [확인]. 확인(또는 키보드 완료)을 눌러야 값이 바뀐다. 범위를 벗어나면 안내.
/// [onDraft]를 주면 입력 중인 값(범위 안이면 숫자, 아니면 null)을 바로 알려 준다 → 화면 아래 저장 버튼이 함께 저장
class NumberConfirmField extends StatefulWidget {
  const NumberConfirmField({
    super.key,
    required this.value,
    required this.unit,
    required this.onConfirmed,
    this.min = 1,
    this.max = 100000,
    this.hint,
    this.preview,
    this.onDraft,
  });

  final int? value;
  final String unit; // 명, 만원
  final ValueChanged<int> onConfirmed;
  final int min;
  final int max;
  final String? hint; // 예: 예: 150
  final String Function(int)? preview; // 입력 중 아래에 보여줄 읽기 쉬운 값 (예: 3,000만원)
  final ValueChanged<int?>? onDraft;

  @override
  State<NumberConfirmField> createState() => _NumberConfirmFieldState();
}

class _NumberConfirmFieldState extends State<NumberConfirmField> {
  late final _c = TextEditingController(text: widget.value?.toString() ?? '');
  String? _error;

  @override
  void didUpdateWidget(NumberConfirmField old) {
    super.didUpdateWidget(old);
    // 바깥에서 값이 바뀌면(다른 화면에서 수정 등) 입력칸도 맞춘다
    if (old.value != widget.value && int.tryParse(_c.text) != widget.value) {
      _c.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int? get _typed => int.tryParse(_c.text);

  void _confirm() {
    final v = _typed;
    if (v == null) return setState(() => _error = '숫자를 입력해 주세요');
    if (v < widget.min || v > widget.max) {
      return setState(() => _error = '${widget.min}~${widget.max}${widget.unit} 사이로 입력해 주세요');
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    widget.onConfirmed(v);
  }

  @override
  Widget build(BuildContext context) {
    final typed = _typed;
    final saved = typed != null && typed == widget.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(
            controller: _c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              setState(() => _error = null);
              final v = _typed;
              widget.onDraft?.call(v != null && v >= widget.min && v <= widget.max ? v : null);
            },
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(hintText: widget.hint, suffixText: widget.unit, errorText: _error),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: typed == null || saved ? null : _confirm,
            child: Text(saved ? '저장됨' : '확인'),
          ),
        ),
      ]),
      if (typed != null && widget.preview != null && _error == null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            saved
                ? '${widget.preview!(typed)}으로 저장했어요'
                : widget.onDraft != null
                    ? '${widget.preview!(typed)} · 아래 버튼을 누르면 함께 저장돼요'
                    : '${widget.preview!(typed)} · 확인을 눌러 저장',
            style: TextStyle(fontSize: 13, color: saved ? AppColors.success : AppColors.textSecondary),
          ),
        ),
    ]);
  }
}
