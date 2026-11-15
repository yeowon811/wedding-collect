import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/region.dart';
import '../../core/widgets/info_badge.dart';
import '../../data/app_state.dart';
import '../../data/models/policy.dart';
import '../../data/repositories/policy_repository.dart';
import 'policy_detail_screen.dart';
import 'policy_matcher.dart';

/// 맞춤 정책 찾기: 내 상황 입력 → 규칙으로 대상 판정 → 목록
class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key, required this.repository});

  final PolicyRepository repository;

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  // 시안을 바꿔 화면이 새로 만들어져도 입력값이 남도록 보관
  static PolicyProfile? _savedProfile;
  static PolicyCategory? _savedCategory;

  late final Future<List<Policy>> _future = widget.repository.loadAll();
  // 처음에는 체크리스트 탭 결혼 정보의 지역을 따른다
  PolicyProfile _profile = _savedProfile ??
      (AppState.instance.profileDone
          ? PolicyProfile.fromUser(AppState.instance.profile)
          : PolicyProfile(sido: AppState.instance.plan.sido));
  PolicyCategory? _category = _savedCategory;

  void _update(PolicyProfile p) => setState(() => _profile = _savedProfile = p);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('맞춤 지원 정책'),
        actions: const [PaletteButton()],
      ),
      body: FutureBuilder<List<Policy>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('데이터를 불러오지 못했어요\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = PolicyMatcher.match(snap.data!, _profile);
          final shown = _category == null
              ? matches
              : matches.where((m) => m.policy.category == _category).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _profileCard(),
              _categoryChips(matches),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '받을 수 있는 정책 ${shown.length}건',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: '  · 전체 ${snap.data!.length}건 중',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '조건은 원문에서 자동으로 뽑은 값이에요(검수 전). 최종 확인은 담당 기관에서 해 주세요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              for (final m in shown) _PolicyCard(match: m),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('조건에 맞는 정책이 없어요')),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _profileCard() {
    final p = _profile;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.18),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내 상황',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              _label('거주 지역'),
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: p.sido,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('선택 안 함 (전국 정책만)')),
                    for (final s in kSidoList) DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => _update(
                      v == null ? p.copyWith(clearSido: true) : p.copyWith(sido: v)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _label('만 나이'),
              Expanded(
                child: Slider(
                  value: p.age.toDouble(),
                  min: 19,
                  max: 49,
                  divisions: 30,
                  label: '${p.age}세',
                  onChanged: (v) => _update(p.copyWith(age: v.round())),
                ),
              ),
              SizedBox(width: 40, child: Text('${p.age}세')),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _label('결혼 단계'),
              Expanded(
                child: SegmentedButton<MarriageStage>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in MarriageStage.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {p.stage},
                  onSelectionChanged: (s) => _update(p.copyWith(stage: s.first)),
                ),
              ),
            ],
          ),
          if (p.stage == MarriageStage.married)
            Row(
              children: [
                _label('혼인 연차'),
                Expanded(
                  child: Slider(
                    value: p.marriedYears.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '${p.marriedYears}년차',
                    onChanged: (v) => _update(p.copyWith(marriedYears: v.round())),
                  ),
                ),
                SizedBox(width: 40, child: Text('${p.marriedYears}년차')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _label(String text) => SizedBox(
        width: 72,
        child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );

  Widget _categoryChips(List<PolicyMatch> matches) {
    final counts = <PolicyCategory, int>{};
    for (final m in matches) {
      counts[m.policy.category] = (counts[m.policy.category] ?? 0) + 1;
    }
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _chip('전체 ${matches.length}', _category == null, () {
            setState(() => _category = _savedCategory = null);
          }),
          for (final c in PolicyCategory.values)
            if ((counts[c] ?? 0) > 0)
              _chip('${c.label} ${counts[c]}', _category == c, () {
                setState(() => _category = _savedCategory = _category == c ? null : c);
              }),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        ),
      );
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.match});

  final PolicyMatch match;

  @override
  Widget build(BuildContext context) {
    final p = match.policy;
    final likely = match.level == MatchLevel.likely;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PolicyDetailScreen(match: match)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InfoBadge(label: p.category.label, color: AppColors.primaryDark),
                    const SizedBox(width: 6),
                    InfoBadge(label: p.regionLabel, color: AppColors.textSecondary),
                    const Spacer(),
                    InfoBadge(
                      label: likely ? '해당 가능성 높음' : '조건 확인 필요',
                      icon: likely ? Icons.check_circle_outline : Icons.help_outline,
                      color: likely ? AppColors.success : AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.eligibility,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                if (match.checks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '확인할 것: ${match.checks.join(' · ')}',
                    style: const TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
