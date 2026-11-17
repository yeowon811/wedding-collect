import '../../core/widgets/favorite_button.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/info_badge.dart';
import '../../core/widgets/inputs.dart';
import 'policy_matcher.dart';

/// 정책 상세: 판정 근거, 확인할 조건, 지원 자격 원문, 신청 링크
class PolicyDetailScreen extends StatelessWidget {
  const PolicyDetailScreen({super.key, required this.match});

  final PolicyMatch match;

  @override
  Widget build(BuildContext context) {
    final p = match.policy;
    final host = Uri.tryParse(p.url)?.host.replaceFirst('www.', '') ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('정책 정보'), actions: [FavoriteButton(ref: 'policy:${match.policy.id}')]),
      bottomNavigationBar: BottomActionBar(children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => launchUrl(Uri.parse(p.url), mode: LaunchMode.externalApplication),
            child: const Text('신청 페이지 열기'),
          ),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 6,
            children: [
              InfoBadge(label: p.category.label, color: AppColors.primaryDark),
              InfoBadge(label: p.regionLabel, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          Text(p.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(p.agency, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          _box(
            title: '내 상황과 맞는 부분',
            color: AppColors.success,
            icon: Icons.check_circle_outline,
            lines: match.reasons,
          ),
          if (match.checks.isNotEmpty)
            _box(
              title: '직접 확인해야 할 조건',
              color: AppColors.warning,
              icon: Icons.help_outline,
              lines: match.checks,
            ),
          const SizedBox(height: 8),
          const Text('지원 자격 (원문)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.placeholder.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(p.eligibility, style: const TextStyle(height: 1.55)),
          ),
          const SizedBox(height: 20),
          Text(
            '출처: $host · 조건 항목은 원문에서 자동 추출(검수 전)했어요. '
            '실제 대상 여부는 담당 기관에서 최종 확인하세요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _box({
    required String title,
    required Color color,
    required IconData icon,
    required List<String> lines,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ]),
          const SizedBox(height: 6),
          for (final l in lines) Text('•  $l', style: const TextStyle(height: 1.6)),
        ],
      ),
    );
  }
}
