import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/info_badge.dart';
import '../../core/utils/region.dart';
import '../../data/models/policy.dart';
import '../../data/models/vendor.dart';
import '../../data/models/venue.dart';
import '../../data/repositories/repositories.dart';
import '../policy/policy_detail_screen.dart';
import '../policy/policy_matcher.dart';
import '../vendor/real_vendor_detail_screen.dart';
import '../vendor/widgets/vendor_cards.dart';
import 'widgets/booking_type_style.dart';

/// 이 예식장 지역에서 받을 수 있는 예식 관련 정책 (공공예식장 ↔ 정책 연결)
class _RelatedPolicies extends StatelessWidget {
  const _RelatedPolicies({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Policy>>(
      future: Repos.policy.loadAll(),
      builder: (context, snap) {
        final list = (snap.data ?? const <Policy>[])
            .where((p) =>
                p.category == PolicyCategory.wedding &&
                (p.isNational || sidoMatches(venue.sido, p.sido)))
            .toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('함께 받을 수 있는 예식 지원 정책',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final p in list)
              Card(
                elevation: 0,
                color: AppColors.primary.withValues(alpha: 0.07),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.volunteer_activism, color: AppColors.primaryDark),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.regionLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PolicyDetailScreen(
                      match: PolicyMatch(p, MatchLevel.check, ['${p.regionLabel} 예식 지원'],
                          const ['거주 요건 등 신청 조건']),
                    ),
                  )),
                ),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

/// 예식장 근처 실제 업체 (거리 매칭 데이터)
class _NearbyVendors extends StatelessWidget {
  const _NearbyVendors({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<(VendorMatch, RealVendor)>>(
      future: Repos.vendor.nearbyFor(venue.id, perCategory: 1),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('근처 실제 연계 업체',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('분류별 가장 가까운 업체 · 공식 전담/협력 업체 우선',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            for (final (m, v) in list)
              RealVendorCard(
                vendor: v,
                distanceKm: m.distanceKm,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RealVendorDetailScreen(vendor: v)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 예식장 상세: 기본 정보, 신청 방법 단계, 예약·문의 버튼, 출처
class VenueDetailScreen extends StatelessWidget {
  const VenueDetailScreen({super.key, required this.venue});

  final Venue venue;

  static final _phonePattern = RegExp(r'^[0-9\-]+$');

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('열 수 없어요: $uri')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = venue;
    final contactIsPhone = _phonePattern.hasMatch(v.bookingContact.trim());

    return Scaffold(
      appBar: AppBar(title: const Text('예식장 정보')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(v.region, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            v.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              InfoBadge(
                label: v.isLimited ? '기간 제한' : '예약 가능',
                color: v.isLimited ? AppColors.warning : AppColors.success,
              ),
              InfoBadge(
                label: v.bookingType.label,
                icon: v.bookingType.icon,
                color: v.bookingType.color,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section('기본 정보', [
            _row(Icons.location_on_outlined, '주소', v.address),
            _row(Icons.groups_outlined, '수용 인원',
                v.capacity == null ? '기관 확인 필요' : '${v.capacity}명'),
            _row(Icons.payments_outlined, '대관료',
                v.rentalFee == null ? '기관 확인 필요' : '${v.rentalFee}원'),
            _row(Icons.info_outline, '운영 상태', v.statusText),
          ]),
          _section('신청 방법', [
            _row(Icons.event_available_outlined, '예약 방식', v.bookingMethod),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(v.bookingSteps, style: const TextStyle(height: 1.5)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _open(context, Uri.parse(v.bookingUrl)),
            icon: const Icon(Icons.open_in_new),
            label: const Text('예약 페이지 열기'),
          ),
          const SizedBox(height: 10),
          if (contactIsPhone)
            OutlinedButton.icon(
              onPressed: () => _open(context, Uri.parse('tel:${v.bookingContact}')),
              icon: const Icon(Icons.call_outlined),
              label: Text('전화 문의 ${v.bookingContact}'),
            )
          else
            Text('문의: ${v.bookingContact}',
                style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          _RelatedPolicies(venue: v),
          _NearbyVendors(venue: v),
          const SizedBox(height: 16),
          Text(
            '출처: ${v.source} · 수용 인원과 대관료는 담당 기관에 최종 확인하세요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
