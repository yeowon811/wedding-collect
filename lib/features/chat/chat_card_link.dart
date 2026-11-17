import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/repositories/repositories.dart';
import '../policy/policy_detail_screen.dart';
import '../policy/policy_matcher.dart';
import '../vendor/demo_vendor_detail_screen.dart';
import '../vendor/real_vendor_detail_screen.dart';
import '../venue/venue_detail_screen.dart';

/// 저장된 대화의 결과 카드를 눌렀을 때: 'venue:H078' 같은 연결 정보로 상세 화면을 찾아 연다
class ChatCardLink extends StatelessWidget {
  const ChatCardLink({super.key, required this.ref});

  final String ref;

  Future<Widget?> _resolve() async {
    final [kind, id] = ref.split(':').length == 2 ? ref.split(':') : ['', ''];
    switch (kind) {
      case 'venue':
        final v = (await Repos.venue.loadAll()).where((v) => v.id == id).firstOrNull;
        return v == null ? null : VenueDetailScreen(venue: v);
      case 'vendor':
        final v = (await Repos.vendor.demoVendors()).where((v) => v.id == id).firstOrNull;
        return v == null ? null : DemoVendorDetailScreen(vendor: v);
      case 'real':
        final v = (await Repos.vendor.realVendors()).where((v) => v.id == id).firstOrNull;
        return v == null ? null : RealVendorDetailScreen(vendor: v);
      case 'policy':
        final all = await Repos.policy.loadAll();
        final judged = PolicyMatcher.judge(all, PolicyProfile.fromUser(AppState.instance.profile));
        final match = judged.matches.where((m) => m.policy.id == id).firstOrNull;
        if (match != null) return PolicyDetailScreen(match: match);
        final p = all.where((p) => p.id == id).firstOrNull;
        return p == null ? null : PolicyDetailScreen(match: PolicyMatch(p, MatchLevel.check, const [], const []));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget?>(
      future: _resolve(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data ??
            Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('이 항목을 찾을 수 없어요. 데이터가 바뀌었을 수 있어요.')),
            );
      },
    );
  }
}
