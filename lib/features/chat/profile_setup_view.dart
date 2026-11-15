import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/region.dart';
import '../../data/app_state.dart';
import '../../data/models/user_profile.dart';

/// 상담 전에 내 정보를 입력하는 화면.
/// 입력한 정보로 첫 추천을 만들고, 비워 둔 항목은 상담 중에 필요할 때 다시 묻는다.
class ProfileSetupView extends StatefulWidget {
  const ProfileSetupView({super.key, required this.onDone, this.onSkip, this.editing = false});

  final VoidCallback onDone;
  final VoidCallback? onSkip;
  final bool editing; // 이미 입력한 정보를 고치는 중인지

  @override
  State<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<ProfileSetupView> {
  late final _app = AppState.instance;
  late UserProfile _p = _app.profileDone || _app.profile.summary.isNotEmpty
      ? _app.profile
      : UserProfile(guests: _app.plan.guests, budget: _app.plan.budget);
  late bool _ageKnown = _p.age != null;

  void _set(UserProfile p) => setState(() => _p = p);

  void _save() {
    var p = _p;
    if (!_ageKnown) p = UserProfile(
          sido: p.sido, stage: p.stage, marriedYears: p.marriedYears, weddingDate: p.weddingDate,
          weddingUndecided: p.weddingUndecided, guests: p.guests, budget: p.budget, homeless: p.homeless);
    _app.saveProfile(p);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(widget.editing ? '내 정보 수정' : '상담 전에 알려주세요',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          '입력한 정보로 예식장·정책·예산을 먼저 추천해 드려요. 모르는 항목은 비워 두면 상담 중에 필요할 때 여쭤볼게요.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        _card('거주 지역', Icons.place_outlined, [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in kSidoList)
                ChoiceChip(
                  label: Text(s),
                  selected: p.sido == s,
                  showCheckmark: false,
                  onSelected: (_) => _set(p.copyWith(sido: s)),
                ),
            ],
          ),
        ]),
        _card('만 나이', Icons.cake_outlined, [
          Row(children: [
            Expanded(
              child: Slider(
                value: (p.age ?? 30).toDouble(),
                min: 19,
                max: 49,
                divisions: 30,
                label: '${p.age ?? 30}세',
                onChanged: (v) => setState(() {
                  _ageKnown = true;
                  _p = p.copyWith(age: v.round(), clearAgeMax: true);
                }),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(_ageKnown ? '${p.age ?? 30}세' : '미입력',
                  textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
          if (!_ageKnown)
            Text('슬라이더를 움직이면 입력돼요', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        _card('결혼 단계', Icons.favorite_border, [
          SegmentedButton<MarriageStage>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: MarriageStage.engaged, label: Text('예비부부')),
              ButtonSegment(value: MarriageStage.married, label: Text('신혼부부(혼인신고 함)')),
            ],
            selected: {if (p.stage != null) p.stage!},
            onSelectionChanged: (s) => _set(s.isEmpty ? p : p.copyWith(stage: s.first)),
          ),
          if (p.stage == MarriageStage.married) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              for (final (label, y) in [('1년 이내', 1), ('2~3년', 3), ('4~7년', 7), ('7년 넘음', 8)])
                ChoiceChip(
                  label: Text(label),
                  selected: p.marriedYears == y,
                  showCheckmark: false,
                  onSelected: (_) => _set(p.copyWith(marriedYears: y)),
                ),
            ]),
          ],
        ]),
        _card('예식일', Icons.event_outlined, [
          Row(children: [
            Expanded(
              child: Text(
                p.weddingDate != null ? formatDate(p.weddingDate!) : (p.weddingUndecided ? '아직 미정' : '미입력'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: p.weddingDate ?? DateTime.now().add(const Duration(days: 240)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (picked != null) _set(p.copyWith(weddingDate: picked, weddingUndecided: false));
              },
              child: const Text('날짜 고르기'),
            ),
            TextButton(
              onPressed: () => _set(UserProfile(
                  sido: p.sido, age: p.age, ageMax: p.ageMax, stage: p.stage, marriedYears: p.marriedYears,
                  weddingUndecided: true, guests: p.guests, budget: p.budget, homeless: p.homeless)),
              child: const Text('미정'),
            ),
          ]),
        ]),
        _card('하객 수 · 총예산', Icons.groups_outlined, [
          _slider('하객', (p.guests ?? 120).toDouble(), 20, 300, 28, '${p.guests ?? 120}명',
              (v) => _set(p.copyWith(guests: v.round()))),
          _slider('예산', (p.budget ?? 3000).toDouble(), 500, 8000, 75, formatManwon(p.budget ?? 3000),
              (v) => _set(p.copyWith(budget: (v / 100).round() * 100))),
        ]),
        _card('주택 보유 (주거 지원 판단용, 선택)', Icons.home_outlined, [
          Wrap(spacing: 6, children: [
            for (final (label, value) in [('무주택', true), ('집 있음', false)])
              ChoiceChip(
                label: Text(label),
                selected: p.homeless == value,
                showCheckmark: false,
                onSelected: (_) => _set(p.copyWith(homeless: value)),
              ),
            ChoiceChip(
              label: const Text('잘 모름'),
              selected: p.homeless == null,
              showCheckmark: false,
              onSelected: (_) => _set(p.copyWith(clearHomeless: true)),
            ),
          ]),
        ]),
        const SizedBox(height: 8),
        Text(
          '🔒 이 정보는 기기 안에서만 쓰여요. 생성형 AI를 연결해도 이름·연락처 없이 조건만 보내요.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.auto_awesome),
          label: Text(widget.editing ? '저장하고 새로 추천받기' : '이 정보로 상담 시작'),
        ),
        if (widget.onSkip != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: widget.onSkip, child: const Text('건너뛰고 바로 질문하기')),
        ],
      ],
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _slider(String label, double value, double min, double max, int div, String text,
          ValueChanged<double> onChanged) =>
      Row(children: [
        SizedBox(width: 40, child: Text(label)),
        Expanded(child: Slider(value: value, min: min, max: max, divisions: div, onChanged: onChanged)),
        SizedBox(width: 88, child: Text(text, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]);
}
