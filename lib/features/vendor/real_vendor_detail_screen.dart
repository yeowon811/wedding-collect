import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/info_badge.dart';
import '../../data/models/vendor.dart';

/// 실제 연계업체 상세: 공개된 정보와 연락 수단만 보여준다 (가격 없음)
class RealVendorDetailScreen extends StatelessWidget {
  const RealVendorDetailScreen({super.key, required this.vendor});

  final RealVendor vendor;

  @override
  Widget build(BuildContext context) {
    final v = vendor;
    final phone = v.phone.replaceAll(RegExp(r'[^0-9]'), '');
    return Scaffold(
      appBar: AppBar(title: const Text('업체 정보')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(spacing: 6, children: [
            InfoBadge(label: v.categoryText, color: AppColors.primaryDark),
            InfoBadge(
              label: v.official,
              color: v.isOfficial ? AppColors.success : AppColors.textSecondary,
            ),
          ]),
          const SizedBox(height: 10),
          Text(v.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _row(Icons.location_on_outlined, v.address),
          _row(Icons.call_outlined, v.phone),
          _row(Icons.design_services_outlined, v.services),
          _row(Icons.payments_outlined, '가격: 공개 정보 없음 · 업체에 직접 문의'),
          const SizedBox(height: 20),
          if (v.url.isNotEmpty)
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse(v.url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: const Text('홈페이지 열기'),
            ),
          const SizedBox(height: 10),
          if (phone.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
              icon: const Icon(Icons.call),
              label: const Text('전화 문의'),
            ),
          const SizedBox(height: 16),
          Text('출처: 전국 공공예식장 및 연계업체 현황 (직접 수집)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
          ],
        ),
      );
}
