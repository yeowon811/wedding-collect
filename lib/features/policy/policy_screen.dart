import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/region.dart';
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
        actions: const [AccountButton()],
      ),
      body: FutureBuilder<List<Policy>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('데이터를 불러오지 못했어요\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const SkeletonList(header: false);
          }
          final judged = PolicyMatcher.judge(snap.data!, _profile);
          final matches = judged.matches;
          bool inCategory(Policy p) => _category == null || p.category == _category;
          final shown = matches.where((m) => inCategory(m.policy)).toList();
          final likely = shown.where((m) => m.level == MatchLevel.likely).toList();
          final check = shown.where((m) => m.level == MatchLevel.check).toList();
          final misses = judged.misses.where((m) => inCategory(m.policy)).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _profileCard(),
              _categoryChips(matches),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  '정책 ${snap.data!.length}건 중 내 조건으로 ${shown.length}건 · 대상 여부는 기관에서 최종 확인',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              if (likely.isNotEmpty) ...[
                _groupHeader('받을 가능성 높음', likely.length, '내 상황이 정책 조건과 맞아요', AppColors.success),
                for (final m in likely) _PolicyCard(match: m),
              ],
              if (check.isNotEmpty) ...[
                _groupHeader('조건 확인 필요', check.length, '소득·무주택처럼 앱이 알 수 없는 조건이 있어요', AppColors.warning),
                for (final m in check) _PolicyCard(match: m),
              ],
              if (shown.isEmpty)
                EmptyState(
                  title: '조건에 맞는 정책이 없어요',
                  message: _profile.sido == null
                      ? '거주 지역을 고르면 지자체 정책까지 찾아드려요.'
                      : '결혼 단계나 나이를 바꿔 보거나, AI 상담에서 상황을 설명해 보세요.',
                  actions: [
                    if (_category != null)
                      EmptyAction('전체 분야 보기', () => setState(() => _category = _savedCategory = null)),
                    EmptyAction('AI 상담에서 물어보기', () => MainShell.goTo(4)),
                  ],
                ),
              if (misses.isNotEmpty) _MissSection(misses: misses),
            ],
          );
        },
      ),
    );
  }

  /// 내 상황 요약 한 줄 + [조건 바꾸기] (입력은 아래에서 올라오는 창에서)
  Widget _profileCard() {
    final p = _profile;
    final summary = [
      p.sido ?? '지역 미선택',
      '만 ${p.age}세',
      p.stage == MarriageStage.married ? '신혼부부 ${p.marriedYears}년차' : '예비부부',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Material(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _editProfile,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('내 상황', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(summary,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ]),
              ),
              Text('조건 바꾸기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    var draft = _profile;
    final applied = await showModalBottomSheet<PolicyProfile>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  Text('내 상황', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 20),
                  FormSection(
                    title: '거주 지역',
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      ChoiceChip(
                        label: const Text('전국 정책만'),
                        selected: draft.sido == null,
                        onSelected: (_) => setSheet(() => draft = draft.copyWith(clearSido: true)),
                      ),
                      for (final s in kSidoList)
                        ChoiceChip(
                          label: Text(s),
                          selected: draft.sido == s,
                          onSelected: (_) => setSheet(() => draft = draft.copyWith(sido: s)),
                        ),
                    ]),
                  ),
                  FormSection(
                    title: '만 나이',
                    child: StepperField(
                      value: draft.age,
                      min: 19,
                      max: 49,
                      unit: '세',
                      label: '만 나이',
                      onChanged: (v) => setSheet(() => draft = draft.copyWith(age: v)),
                    ),
                  ),
                  FormSection(
                    title: '결혼 단계',
                    child: ChoiceRow<MarriageStage>(
                      options: [for (final s in MarriageStage.values) (s, s.label)],
                      value: draft.stage,
                      onChanged: (v) => setSheet(() => draft = draft.copyWith(stage: v)),
                    ),
                  ),
                  if (draft.stage == MarriageStage.married)
                    FormSection(
                      title: '혼인 연차',
                      child: StepperField(
                        value: draft.marriedYears,
                        min: 1,
                        max: 10,
                        unit: '년차',
                        label: '혼인 연차',
                        onChanged: (v) => setSheet(() => draft = draft.copyWith(marriedYears: v)),
                      ),
                    ),
                ],
              ),
            ),
            BottomActionBar(children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(ctx, draft), child: const Text('이 조건으로 보기')),
              ),
            ]),
          ],
        ),
      ),
    );
    if (applied != null) _update(applied);
  }

  /// 결과 묶음 제목: 색 점 + 이름 + 건수 + 한 줄 설명
  Widget _groupHeader(String title, int count, String desc, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('$title $count건',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(desc, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
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
                // 가능성은 묶음 제목이 알려주므로 카드에는 분야·지역만 (배지 줄이기)
                Text(
                  '${p.category.label} · ${p.regionLabel}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.eligibility,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                ),
                if (match.checks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '확인할 것 · ${match.checks.join(' · ')}',
                      style: const TextStyle(fontSize: 13, color: AppColors.warning),
                    ),
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

/// 내 지역·전국 정책 중 대상이 아닌 것 (접어 두고, 펼치면 이유를 보여준다)
class _MissSection extends StatefulWidget {
  const _MissSection({required this.misses});

  final List<PolicyMiss> misses;

  @override
  State<_MissSection> createState() => _MissSectionState();
}

class _MissSectionState extends State<_MissSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: AppColors.textHint, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '대상 아님 ${widget.misses.length}건',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      TextSpan(
                          text: '  왜 안 되는지 보기',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ])),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
                ]),
              ),
            ),
          ),
          if (_open)
            for (final m in widget.misses)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.policy.name,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textBody)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.block, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(m.reason, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ),
                    ]),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
