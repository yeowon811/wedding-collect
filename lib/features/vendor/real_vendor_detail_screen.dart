import '../../core/widgets/favorite_button.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/info_badge.dart';
import '../../core/widgets/inputs.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import 'widgets/vendor_cards.dart';
import 'widgets/vendor_photo.dart';

/// 실제 연계업체 상세: 공개된 정보와 연락 수단만 보여준다 (가격 없음)
class RealVendorDetailScreen extends StatelessWidget {
  const RealVendorDetailScreen({super.key, required this.vendor});

  final RealVendor vendor;

  @override
  Widget build(BuildContext context) {
    final v = vendor;
    final phone = v.phone.replaceAll(RegExp(r'[^0-9]'), '');
    return Scaffold(
      appBar: AppBar(title: const Text('업체 정보'), actions: [FavoriteButton(ref: 'real:${v.id}')]),
      bottomNavigationBar: BottomActionBar(children: [
              ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) {
              final app = AppState.instance;
              final ref = 'real:${v.id}';
              final on = app.isFavorite(ref);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      app.toggleFavorite(ref);
                      if (!on) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('체크리스트 준비 항목에 담았어요'),
                          duration: Duration(seconds: 2),
                        ));
                      }
                    },
                    icon: Icon(on ? Icons.check_circle : Icons.add_task, size: 18),
                    label: Text(on ? '체크리스트에 추가됨 (누르면 빼기)' : '체크리스트에 추가'),
                  ),
                ),
              );
            },
          ),
              if (v.url.isNotEmpty || phone.isNotEmpty)
              if (v.url.isNotEmpty && phone.isNotEmpty)
                ActionPair(
                  secondary: OutlinedButton(
                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                    child: const Text('전화 문의'),
                  ),
                  primary: FilledButton(
                    onPressed: () => launchUrl(Uri.parse(v.url), mode: LaunchMode.externalApplication),
                    child: const Text('홈페이지 열기'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: phone.isNotEmpty
                      ? FilledButton(
                          onPressed: () => launchUrl(Uri.parse('tel:$phone')), child: const Text('전화 문의'))
                      : FilledButton(
                          onPressed: () => launchUrl(Uri.parse(v.url), mode: LaunchMode.externalApplication),
                          child: const Text('홈페이지 열기')),
                ),
            ]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          VendorPhotoHeader(category: v.category, vendorId: v.id, url: v.image, site: v.url, isReal: true),
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, children: [
            InfoBadge(label: v.categoryText, color: AppColors.primaryDark),
            v.isOfficial
                ? OfficialMark(label: v.official)
                : InfoBadge(label: v.official, color: AppColors.textSecondary),
          ]),
          const SizedBox(height: 10),
          Text(v.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _row(Icons.location_on_outlined, v.address),
          _row(Icons.call_outlined, v.phone),
          _row(Icons.design_services_outlined, v.services),
          _row(Icons.payments_outlined, '가격: 공개 정보 없음 · 업체에 직접 문의'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.placeholder.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('후기', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                  '실제 업체의 후기는 아직 수집하지 않았어요. 실제 업체에는 임의로 만든 후기를 보여주지 않아요.\n'
                  '정식 서비스에서는 상담·계약을 인증한 이용자만 후기를 남길 수 있게 할 예정이에요.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
