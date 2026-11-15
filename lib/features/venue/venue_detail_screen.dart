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
import '../../data/app_state.dart';
import 'widgets/booking_type_style.dart';
import 'widgets/venue_image.dart';

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
          if (v.images.isNotEmpty) ...[
            _Gallery(venue: v),
            const SizedBox(height: 16),
          ],
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
            _row(Icons.groups_outlined, '정원', _capacityText(v)),
            _row(Icons.payments_outlined, '대관료',
                v.rentalFee == null ? '기관 확인 필요${v.feeText != null ? ' (${v.feeText})' : ''}' : v.feeLabel),
            if (v.feeDetail != null) _detailBox(v.feeDetail!),
            // "무료(냉난방 시 추가)"처럼 조건이 붙은 원문은 그대로 보여준다
            if (v.feeDetail == null && v.feeText != null && v.feeText != '무료' && v.rentalFee != null)
              _detailBox(v.feeText!),
            _row(Icons.info_outline, '운영 상태', v.statusText),
          ]),
          _usageSection(v),
          _weddingSection(v),
          _PartnerVendors(venue: v),
          _dataNotice(v),
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
            '출처: ${v.source}${v.isCollected ? ' · 정원·요금·사진 등: ${v.collectSource}' : ''} · '
            '정원과 대관료는 담당 기관에 최종 확인하세요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _capacityText(Venue v) {
    if (v.capacity == null) {
      return '기관 확인 필요${v.capacityText != null ? ' (등록값: ${v.capacityText})' : ''}';
    }
    final guests = AppState.instance.plan.guests;
    final range = v.capacityMin != null ? '${v.capacityMin}~${v.capacity}명' : '${v.capacity}명';
    return '$range · 내 하객 $guests명 ${v.capacity! >= guests ? '수용 가능' : '초과'}';
  }

  /// 예식 가능일·피로연·기타 안내 (더아결 수집 항목)
  Widget _weddingSection(Venue v) {
    final rows = [
      if (v.availableDates2026 != null) _row(Icons.event_available, '26년 예식일', v.availableDates2026!),
      if (v.unavailableDates2026 != null) _row(Icons.event_busy, '26년 불가일', v.unavailableDates2026!),
      if (v.availableDates2027 != null) _row(Icons.event_note, '27년 예식일', v.availableDates2027!),
      if (v.reception != null) _row(Icons.restaurant, '피로연', v.reception!),
      if (v.extraInfo != null) _row(Icons.campaign_outlined, '기타 안내', v.extraInfo!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _section('예식 안내', rows);
  }

  Widget _detailBox(String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(left: 28, bottom: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.placeholder.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
      );

  /// 공유누리에서 수집한 이용 정보 (값이 있는 항목만)
  Widget _usageSection(Venue v) {
    final hours = [
      if (v.hoursWeekday != null) '평일 ${v.hoursWeekday}',
      if (v.hoursSaturday != null) '토요일 ${v.hoursSaturday}',
      if (v.hoursHoliday != null) '일·공휴일 ${v.hoursHoliday}',
    ];
    final rows = [
      if (hours.isNotEmpty) _row(Icons.schedule, '운영시간', hours.join('\n')),
      if (v.operatingPeriod != null) _row(Icons.date_range, '이용 기간', v.operatingPeriod!),
      if (v.applyPeriod != null) _row(Icons.edit_calendar_outlined, '접수', v.applyPeriod!),
      if (v.approval != null) _row(Icons.fact_check_outlined, '심사', v.approval!),
      if (v.prepTime != null) _row(Icons.timer_outlined, '준비 시간', v.prepTime!),
      if (v.target != null) _row(Icons.person_outline, '이용 대상', v.target!),
      if (v.indoorOutdoor != null) _row(Icons.park_outlined, '실내·외', v.indoorOutdoor!),
      if (v.parking != null) _row(Icons.local_parking, '주차', v.parking!),
      if (v.area != null) _row(Icons.square_foot, '면적', v.area!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _section('이용 정보', rows);
  }

  /// 데이터가 없거나 확인이 필요한 경우 안내
  Widget _dataNotice(Venue v) {
    final notes = v.isCollected
        ? [
            ...v.dataNotes,
            if (v.aiImages.isNotEmpty) '사진 ${v.images.length}장 중 ${v.aiImages.length}장은 AI 생성 이미지예요 (실제 모습과 다를 수 있음).',
          ]
        : ['정원·요금·예식 가능일·사진이 아직 수집되지 않았어요. 예약 페이지나 문의처에서 확인해 주세요.'];
    if (notes.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline, size: 18, color: AppColors.warning),
            SizedBox(width: 6),
            Text('데이터 확인 필요', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
          ]),
          const SizedBox(height: 4),
          for (final n in notes) Text('•  $n', style: const TextStyle(fontSize: 13, height: 1.5)),
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

/// 서울마이웨딩(더아결)에 등록된 협력 전문 웨딩업체. 실제 업체 목록에 있으면 상세로 연결한다.
class _PartnerVendors extends StatelessWidget {
  const _PartnerVendors({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    if (venue.partnerVendors.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<List<RealVendor>>(
      future: Repos.vendor.realVendors(),
      builder: (context, snap) {
        final byName = {for (final v in snap.data ?? const <RealVendor>[]) v.name: v};
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('협력 전문 웨딩업체',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('서울마이웨딩에 이 예식장과 함께 등록된 업체예요',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in venue.partnerVendors)
                    if (byName[name] != null)
                      ActionChip(
                        avatar: Icon(byName[name]!.category.icon, size: 16),
                        label: Text(name),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RealVendorDetailScreen(vendor: byName[name]!),
                        )),
                      )
                    else
                      Chip(label: Text(name)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 사진 넘겨보기 (AI 생성 이미지는 표시)
class _Gallery extends StatefulWidget {
  const _Gallery({required this.venue});

  final Venue venue;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  List<String> get images => widget.venue.images;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => VenueImage(url: images[i]),
            ),
            if (widget.venue.isAiImage(images[_page]))
              const Positioned(left: 10, top: 10, child: AiImageBadge()),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text('${_page + 1}/${images.length} · 사진: ${widget.venue.collectSource ?? '기관'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
