import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/grid.dart';
import '../../data/app_state.dart';
import '../../data/repositories/repositories.dart';
import '../chat/chat_card_link.dart';
import '../policy/policy_matcher.dart';
import '../vendor/widgets/vendor_cards.dart';
import '../venue/widgets/venue_card.dart';

/// 찜 목록: 하트를 누른 예식장·업체·정책을 모아 본다
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('찜 목록')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => FutureBuilder(
          future: _load(state.favorites),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final (venues, real, demo, policies) = snap.data!;
            if (venues.isEmpty && real.isEmpty && demo.isEmpty && policies.isEmpty) {
              return const EmptyState(
                icon: Icons.favorite_border,
                title: '아직 찜한 것이 없어요',
                message: '예식장·업체·정책 카드의 하트를 누르면 여기에 모아 볼 수 있어요.',
              );
            }
            void open(String ref) =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatCardLink(ref: ref)));
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (venues.isNotEmpty) ...[
                  _title('예식장', venues.length),
                  TileGrid(children: [
                    for (final v in venues) VenueCard(venue: v, onTap: () => open('venue:${v.id}')),
                  ]),
                ],
                if (real.isNotEmpty || demo.isNotEmpty) ...[
                  _title('업체', real.length + demo.length),
                  TileGrid(children: [
                    for (final v in real) RealVendorTile(vendor: v, onTap: () => open('real:${v.id}')),
                    for (final v in demo) DemoVendorCard(vendor: v, onTap: () => open('vendor:${v.id}')),
                  ]),
                ],
                if (policies.isNotEmpty) ...[
                  _title('정책', policies.length),
                  for (final m in policies)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      title: Text(m.policy.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${m.policy.category.label} · ${m.policy.regionLabel}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open('policy:${m.policy.id}'),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _title(String text, int n) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Text('$text $n', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      );

  static Future<(List, List, List, List<PolicyMatch>)> _load(Set<String> refs) async {
    final ids = {for (final r in refs) r};
    bool has(String kind, String id) => ids.contains('$kind:$id');
    final venues = (await Repos.venue.loadAll()).where((v) => has('venue', v.id)).toList();
    final real = (await Repos.vendor.realVendors()).where((v) => has('real', v.id)).toList();
    final demo = (await Repos.vendor.demoVendors()).where((v) => has('vendor', v.id)).toList();
    final all = await Repos.policy.loadAll();
    final judged = PolicyMatcher.judge(all, PolicyProfile.fromUser(AppState.instance.profile));
    final policies = [
      for (final p in all.where((p) => has('policy', p.id)))
        judged.matches.where((m) => m.policy.id == p.id).firstOrNull ??
            PolicyMatch(p, MatchLevel.check, const [], const []),
    ];
    return (venues, real, demo, policies);
  }
}

/// 탭 상단의 찜 목록 버튼 (찜 개수 표시)
class FavoritesAction extends StatelessWidget {
  const FavoritesAction({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => IconButton(
        tooltip: '찜 목록',
        // 오른쪽 계정 버튼에 조금 붙여 둔다 (11-21 사용자 요청): 버튼 폭 48 → 36, 오른쪽 여백 없이
        padding: const EdgeInsets.only(left: 6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 48),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
        icon: Badge(
          isLabelVisible: state.favorites.isNotEmpty,
          backgroundColor: const Color(0xFFF04452),
          label: Text('${state.favorites.length}'),
          child: Icon(Icons.favorite_border, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
