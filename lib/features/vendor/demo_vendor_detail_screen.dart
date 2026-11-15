import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/info_badge.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import '../../data/models/wedding_plan.dart';
import 'consultation_sheet.dart';

/// 시연용 업체 상세: 가격·구성, 예산 비교, 상담 신청, 계약 완료 표시
class DemoVendorDetailScreen extends StatelessWidget {
  const DemoVendorDetailScreen({super.key, required this.vendor});

  final DemoVendor vendor;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final v = vendor;

    return Scaffold(
      appBar: AppBar(title: Text(v.category.label)),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final estimate = v.estimate(guests: state.plan.guests);
          final budget = state.plan.budgetFor(v.category);
          final mine = state.consultations.where((c) => c.vendor.id == v.id).toList();
          final contracted = state.contracts[v.category]?.$1.id == v.id;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(spacing: 6, children: [
                const InfoBadge(label: '시연용 가상 업체', color: AppColors.unknown),
                InfoBadge(label: v.sido, color: AppColors.textSecondary),
                if (v.publicVenueOk)
                  const InfoBadge(label: '공공예식장 출장 가능', color: AppColors.success),
              ]),
              const SizedBox(height: 10),
              Text(v.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('★ ${v.rating} · 후기 ${v.reviewCount}개 · ${v.styles.join(' · ')}',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('가격대 ${v.priceText}',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    const SizedBox(height: 6),
                    Text('내 조건 예상 비용: $estimate만원'
                        '${v.priceUnit == '1인' ? ' (하객 ${state.plan.guests}명 기준)' : ''}'),
                    Text(
                      estimate <= budget
                          ? '추천 예산 $budget만원 안이에요'
                          : '추천 예산 $budget만원보다 ${estimate - budget}만원 많아요',
                      style: TextStyle(
                          color: estimate <= budget ? AppColors.success : AppColors.warning),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('포함 구성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final item in v.packageItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(Icons.check, size: 16, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Text(item),
                  ]),
                ),
              if (mine.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('내 상담 예약',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                for (final c in mine)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.event_available, color: AppColors.primaryDark),
                    title: Text('${formatDateWithDay(c.dateTime)} '
                        '${c.dateTime.hour.toString().padLeft(2, '0')}:00'),
                    subtitle: c.memo.isEmpty ? null : Text(c.memo),
                    trailing: TextButton(
                      onPressed: () => state.cancelConsultation(c),
                      child: const Text('취소'),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => showConsultationSheet(context, v),
                icon: const Icon(Icons.event_note),
                label: const Text('상담 신청 · 일정 선택'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: contracted
                    ? () => state.setStatus(v.category, ItemStatus.consulting)
                    : () {
                        state.contract(v);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${v.category.label}: 계약 완료로 표시했어요 (체크리스트 반영)'),
                        ));
                      },
                icon: Icon(contracted ? Icons.undo : Icons.handshake_outlined),
                label: Text(contracted ? '계약 완료 취소' : '이 업체로 계약 완료 표시'),
              ),
              const SizedBox(height: 16),
              Text('시연용으로 만든 가상 업체예요. 실제 예약은 이뤄지지 않아요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          );
        },
      ),
    );
  }
}
