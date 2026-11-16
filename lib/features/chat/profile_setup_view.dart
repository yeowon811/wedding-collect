import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/region.dart';
import '../../core/widgets/inputs.dart';
import '../../data/app_state.dart';
import '../../data/models/user_profile.dart';

/// 상담 전에 내 정보를 입력하는 화면.
/// 입력한 정보로 첫 추천을 만들고, 비워 둔 항목은 상담 중에 필요할 때 다시 묻는다.
/// 나이는 정확한 숫자가 필요해 −/+·직접 입력, 하객·예산은 자주 쓰는 값 칩 + 직접 입력.
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
    if (!_ageKnown) {
      p = UserProfile(
          sido: p.sido, stage: p.stage, marriedYears: p.marriedYears, weddingDate: p.weddingDate,
          weddingUndecided: p.weddingUndecided, guests: p.guests, budget: p.budget, homeless: p.homeless);
    }
    _app.saveProfile(p);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(widget.editing ? '내 정보 수정' : '상담 전에 알려주세요',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(
                '입력한 정보로 먼저 추천해 드려요. 모르는 항목은 비워 두세요.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              FormSection(
                title: '거주 지역',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in kSidoList)
                      ChoiceChip(
                        label: Text(s),
                        selected: p.sido == s,
                        onSelected: (_) => _set(p.copyWith(sido: s)),
                      ),
                  ],
                ),
              ),
              FormSection(
                title: '만 나이',
                child: StepperField(
                  value: _ageKnown ? p.age : null,
                  min: 19,
                  max: 49,
                  initial: 29,
                  unit: '세',
                  label: '만 나이',
                  onChanged: (v) => setState(() {
                    _ageKnown = true;
                    _p = p.copyWith(age: v, clearAgeMax: true);
                  }),
                ),
              ),
              FormSection(
                title: '결혼 단계',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChoiceRow<MarriageStage>(
                      options: const [
                        (MarriageStage.engaged, '예비부부'),
                        (MarriageStage.married, '신혼부부'),
                      ],
                      value: p.stage,
                      onChanged: (v) => _set(p.copyWith(stage: v)),
                    ),
                    if (p.stage == MarriageStage.married) ...[
                      const SizedBox(height: 14),
                      Text('혼인신고한 지', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final (label, y) in [('1년 이내', 1), ('2~3년', 3), ('4~7년', 7), ('7년 넘음', 8)])
                          ChoiceChip(
                            label: Text(label),
                            selected: p.marriedYears == y,
                            onSelected: (_) => _set(p.copyWith(marriedYears: y)),
                          ),
                      ]),
                    ],
                  ],
                ),
              ),
              FormSection(
                title: '예식일',
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: p.weddingDate ?? DateTime.now().add(const Duration(days: 240)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) _set(p.copyWith(weddingDate: picked, weddingUndecided: false));
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(p.weddingDate != null ? formatDate(p.weddingDate!) : '날짜 고르기'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('아직 미정'),
                    selected: p.weddingDate == null && p.weddingUndecided,
                    onSelected: (_) => _set(UserProfile(
                        sido: p.sido, age: p.age, ageMax: p.ageMax, stage: p.stage, marriedYears: p.marriedYears,
                        weddingUndecided: true, guests: p.guests, budget: p.budget, homeless: p.homeless)),
                  ),
                ]),
              ),
              FormSection(
                title: '하객 수',
                child: PresetPicker(
                  value: p.guests,
                  presets: const [50, 100, 150, 200, 300],
                  format: (v) => '$v명',
                  unit: '명',
                  min: 10,
                  max: 2000,
                  label: '하객 수',
                  onChanged: (v) => _set(p.copyWith(guests: v)),
                ),
              ),
              FormSection(
                title: '총예산',
                child: PresetPicker(
                  value: p.budget,
                  presets: const [1000, 2000, 3000, 5000, 7000],
                  format: formatManwon,
                  unit: '만원',
                  min: 100,
                  max: 100000,
                  label: '총예산 (만원)',
                  onChanged: (v) => _set(p.copyWith(budget: v)),
                ),
              ),
              FormSection(
                title: '주택 보유',
                hint: '주거·대출 지원 대상인지 판단할 때 써요.',
                child: ChoiceRow<int>(
                  options: const [(1, '무주택'), (0, '집 있음'), (-1, '잘 모름')],
                  value: p.homeless == null ? -1 : (p.homeless! ? 1 : 0),
                  onChanged: (v) => _set(v < 0 ? p.copyWith(clearHomeless: true) : p.copyWith(homeless: v == 1)),
                ),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '기기 안에서만 쓰고, AI에는 이름·연락처 없이 조건만 보내요.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ]),
            ],
          ),
        ),
        BottomActionBar(children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(widget.editing ? '저장하고 다시 추천받기' : '이 정보로 상담 시작'),
            ),
          ),
          if (widget.onSkip != null)
            TextButton(onPressed: widget.onSkip, child: const Text('건너뛰고 바로 질문하기')),
        ]),
      ],
    );
  }
}
