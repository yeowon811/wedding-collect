import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/main_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/region_fields.dart';
import '../../data/app_state.dart';
import '../../data/models/policy.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/venue.dart';
import '../../data/repositories/repositories.dart';
import '../auth/login_screen.dart';
import '../chat/chat_screen.dart';
import '../favorites/favorites_screen.dart';
import '../policy/policy_matcher.dart';
import '../policy/policy_screen.dart';
import '../venue/venue_home_screen.dart';

/// 홈 (2026-11-21, 사용자 시안 기반): 브랜드 머리줄 · 배너 3장 · 바로가기 4칸 · 안내 띠 · 맞춤 지원 찾아보기 · 추천 서비스.
/// 숫자(무료 예식장 수·정책 수·수집 날짜)는 모두 앱 데이터에서 센 값. 이용 통계가 없어 '많이 찾는' 같은 말은 쓰지 않는다.
/// 정부 상징·'대한민국 정부' 표시는 공식 서비스로 오해될 수 있어 쓰지 않는다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// 배너 자동 넘김 (테스트에서는 끈다)
  static bool autoPlay = true;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _app = AppState.instance;
  late final Future<(List<Venue>, List<Policy>)> _data = () async {
    final r = await Future.wait([Repos.venue.loadAll(), Repos.policy.loadAll()]);
    return (r[0] as List<Venue>, r[1] as List<Policy>);
  }();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _app,
          builder: (context, _) => FutureBuilder(
            future: _data,
            builder: (context, snap) {
              final venues = snap.data?.$1 ?? const <Venue>[];
              final policies = snap.data?.$2 ?? const <Policy>[];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 28),
                    children: [
                      _Header(onBell: () => _showNotices(context)),
                      _Banner(venues: venues, policies: policies),
                      const SizedBox(height: 18),
                      const _QuickGrid(),
                      const SizedBox(height: 14),
                      _NoticeBar(),
                      const SizedBox(height: 14),
                      _MatchCard(policies: policies),
                      const SizedBox(height: 22),
                      const _Recommend(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 알림: 앱에 있는 실제 일정만 (예식일 D-day, 다가오는 상담 일정). 없으면 없다고
  void _showNotices(BuildContext context) {
    final items = _HomeNotices.of(_app);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('알림', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text('새 알림이 없어요.\n예식일을 정하거나 업체 상담을 신청하면 여기에 일정이 보여요.',
                  style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary))
            else
              for (final n in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(n.icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(n.text, style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textBody)),
                    ),
                  ]),
                ),
          ]),
        ),
      ),
    );
  }
}

class _HomeNotices {
  const _HomeNotices(this.icon, this.text);

  final IconData icon;
  final String text;

  static List<_HomeNotices> of(AppState app) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final out = <_HomeNotices>[];
    final w = app.profile.weddingDate;
    if (w != null && !w.isBefore(today)) {
      final d = DateTime(w.year, w.month, w.day).difference(today).inDays;
      out.add(_HomeNotices(Icons.favorite_border, '예식일까지 D-$d (${w.year}.${w.month}.${w.day})'));
    }
    final upcoming = [for (final c in app.consultations) if (!c.dateTime.isBefore(now)) c]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    for (final c in upcoming.take(3)) {
      final t = c.dateTime;
      out.add(_HomeNotices(Icons.event_available_outlined,
          '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')} ${c.vendor.name} 상담'));
    }
    return out;
  }
}

/// 머리줄: 링 로고 + We Connect | 청년 결혼지원 통합플랫폼 · 알림 · 찜 · 계정
class _Header extends StatelessWidget {
  const _Header({required this.onBell});

  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final has = _HomeNotices.of(AppState.instance).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
      child: Row(children: [
        Image.asset('assets/images/brand/rings_rose.png', height: 30, errorBuilder: (_, _, _) => const SizedBox()),
        const SizedBox(width: 9),
        // 좁은 휴대폰에서 한 줄에 두면 부제가 잘려서 두 줄로
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('We Connect',
                style: TextStyle(
                    fontSize: 18, height: 1.15, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: -0.2)),
            Text('청년 결혼지원 통합플랫폼',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ]),
        ),
        IconButton(
          tooltip: '알림',
          onPressed: onBell,
          icon: Badge(
            isLabelVisible: has,
            smallSize: 7,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
          ),
        ),
        const FavoritesAction(),
        const AccountButton(),
      ]),
    );
  }
}

/// 배너 3장: 브랜드 · 무료 공공예식장 · 지원 정책 (숫자는 데이터에서 셈)
class _Banner extends StatefulWidget {
  const _Banner({required this.venues, required this.policies});

  final List<Venue> venues;
  final List<Policy> policies;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  final _page = PageController();
  int _at = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (HomeScreen.autoPlay) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_page.hasClients) return;
        _page.animateToPage((_at + 1) % 3, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final free = widget.venues.where((v) => v.isFree).length;
    final me = AppState.instance.profile;
    final known = me.sido != null || me.age != null || me.stage != null;
    final mine = known && widget.policies.isNotEmpty
        ? PolicyMatcher.match(widget.policies, PolicyProfile.fromUser(me)).length
        : null;
    final slides = <Widget>[
      const _BrandSlide(),
      _PhotoSlide(
        photo: 'assets/images/lookbook/2_forest-02.jpg',
        kicker: '공공예식장',
        title: widget.venues.isEmpty ? '대관료 무료 공공예식장' : '대관료 무료 공공예식장 $free곳',
        sub: '식대·꽃장식은 따로예요 · 전국 ${widget.venues.isEmpty ? '' : '${widget.venues.length}곳 중'}',
        onTap: () {
          VenueHomeScreen.freeOnlyRequest.value = true;
          MainShell.goTo(0);
        },
      ),
      _PhotoSlide(
        photo: 'assets/images/lookbook/1_hanok-01.jpg',
        kicker: '결혼 지원 정책',
        title: mine != null ? '내 조건에 맞는 정책 $mine건' : '결혼 지원 정책 ${widget.policies.isEmpty ? '' : '${widget.policies.length}건'}',
        sub: mine != null ? '내 정보 기준 · 조건 확인이 필요한 것 포함' : '사는 곳·나이를 알려 주면 맞는 것만 골라요',
        onTap: () => MainShell.goTo(1),
      ),
    ];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 210,
            child: PageView(
              controller: _page,
              onPageChanged: (i) => setState(() => _at = i),
              children: slides,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < slides.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == _at ? 18 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == _at ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ]),
    ]);
  }
}

class _BrandSlide extends StatelessWidget {
  const _BrandSlide();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDF0F4), Color(0xFFF7D3DF)],
          ),
        ),
        child: Stack(children: [
          // 오른쪽 아래 큰 흰 링 (장식)
          Positioned(
            right: -28,
            bottom: -18,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset('assets/images/brand/rings_white.png', width: 190, errorBuilder: (_, _, _) => const SizedBox()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.asset('assets/images/brand/rings_rose.png', height: 28, errorBuilder: (_, _, _) => const SizedBox()),
              const SizedBox(height: 6),
              Text('We Connect',
                  style: TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textBody),
                  children: [
                    const TextSpan(text: '청년의 결혼, 정책과 일상을 잇는\n'),
                    TextSpan(text: '공공 웨딩', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const TextSpan(text: ' 플랫폼'),
                  ],
                ),
              ),
            ]),
          ),
        ]),
      );
}

class _PhotoSlide extends StatelessWidget {
  const _PhotoSlide({required this.photo, required this.kicker, required this.title, required this.sub, required this.onTap});

  final String photo;
  final String kicker;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(photo, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: AppColors.primarySoft)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xB0201418)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6)),
                child: Text(kicker, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ]),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
            ]),
          ),
        ]),
      );
}

/// 바로가기 4칸
class _QuickGrid extends StatelessWidget {
  const _QuickGrid();

  @override
  Widget build(BuildContext context) {
    Widget cell(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(children: [
                    Icon(icon, size: 28, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        cell(Icons.account_balance_outlined, '결혼지원 정책', () => MainShell.goTo(1)),
        cell(Icons.event_available_outlined, '공공예식장', () => MainShell.goTo(0)),
        cell(Icons.storefront_outlined, '웨딩업체', () => MainShell.goTo(2)),
        cell(Icons.calculate_outlined, '예산 관리', () => MainShell.goTo(3)),
      ]),
    );
  }
}

/// 안내 띠: 앱 데이터 기준 안내 (지어낸 공지 없이)
class _NoticeBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final at = Repos.booking.collectedAt;
    final text = at == null
        ? '공공예식장·정책은 공공데이터 기준이에요'
        : '예약 현황은 ${at.month}/${at.day} 수집 기준이에요';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => MainShell.goTo(0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Icon(Icons.campaign_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('안내', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 10), color: AppColors.border),
              Expanded(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: AppColors.textBody)),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 맞춤 지원 찾아보기: 거주지역 · 결혼 단계 · 예식 예정일 = 내 정보 (정책 탭·AI 상담·체크리스트와 같은 값)
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.policies});

  final List<Policy> policies;

  AppState get _app => AppState.instance;

  @override
  Widget build(BuildContext context) {
    final me = _app.profile;
    final region = me.sido == null ? null : (me.sigungu == null ? me.sido! : '${me.sido} ${me.sigungu}');
    final date = me.weddingDate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.manage_search_rounded, size: 30, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('맞춤 지원 찾아보기',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('나에게 맞는 결혼지원 정책을 한 번에 확인해요',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _field(Icons.place_outlined, region ?? '거주지역', region != null, () => _pickRegion(context)),
            const SizedBox(width: 6),
            _field(Icons.people_outline_rounded, me.stage?.label ?? '결혼 단계', me.stage != null, () => _pickStage(context)),
            const SizedBox(width: 6),
            _field(Icons.calendar_today_outlined, date == null ? '예식 예정일' : '${date.year % 100}.${date.month}.${date.day}',
                date != null, () => _pickDate(context)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => MainShell.goTo(1),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('맞춤 조회하기'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(IconData icon, String label, bool set, VoidCallback onTap) => Expanded(
        child: Material(
          color: set ? AppColors.primarySoft : AppColors.fill,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 15, color: set ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: set ? FontWeight.w700 : FontWeight.w500,
                          color: set ? AppColors.primary : AppColors.textBody)),
                ),
              ]),
            ),
          ),
        ),
      );

  Future<void> _pickRegion(BuildContext context) async {
    var sido = _app.profile.sido;
    String? sigungu = _app.profile.sigungu;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('거주 지역', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            RegionFields(
              sido: sido,
              sigungu: sigungu,
              onChanged: (s, g) => setSheet(() {
                sido = s;
                sigungu = g;
              }),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('적용')),
          ]),
        ),
      ),
    );
    if (ok != true || sido == null) return;
    _app.updateProfileDraft(_app.profile.copyWith(sido: sido, sigungu: sigungu, clearSigungu: sigungu == null));
  }

  Future<void> _pickStage(BuildContext context) async {
    final picked = await showModalBottomSheet<MarriageStage>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in MarriageStage.values)
            ListTile(
              title: Text(s == MarriageStage.engaged ? '예비부부 (예식 전)' : '신혼부부 (혼인신고 했어요)'),
              trailing: _app.profile.stage == s ? Icon(Icons.check_rounded, color: AppColors.primary) : null,
              onTap: () => Navigator.pop(ctx, s),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return;
    _app.updateProfileDraft(_app.profile.copyWith(stage: picked));
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _app.profile.weddingDate ?? DateTime(now.year, now.month + 6, now.day),
      firstDate: DateTime(now.year - 7),
      lastDate: DateTime(now.year + 3, 12, 31),
      helpText: '예식 예정일',
    );
    if (picked == null) return;
    _app.updateProfileDraft(_app.profile.copyWith(weddingDate: picked));
  }
}

/// 추천 서비스 3칸 (이용 통계가 없으므로 '많이 찾는' 대신 추천)
class _Recommend extends StatelessWidget {
  const _Recommend();

  @override
  Widget build(BuildContext context) {
    Widget card(IconData icon, String title, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
                  child: Column(children: [
                    Icon(icon, size: 26, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text('추천 서비스', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          card(Icons.local_offer_outlined, '무료 예식장\nBEST', () {
            VenueHomeScreen.freeOnlyRequest.value = true;
            MainShell.goTo(0);
          }),
          card(Icons.workspace_premium_outlined, '지원금 혜택\n모음', () {
            PolicyScreen.categoryRequest.value = PolicyCategory.cash;
            MainShell.goTo(1);
          }),
          card(Icons.favorite_border_rounded, '예산별\n웨딩 가이드', () {
            final b = AppState.instance.profile.budget;
            ChatScreen.questionRequest.value =
                b == null ? '예산별로 결혼 준비 비용을 어떻게 나누면 좋아?' : '총예산 $b만원이면 결혼 준비 비용을 어떻게 나누면 좋아?';
            MainShell.goTo(4);
          }),
        ]),
      ),
    ]);
  }
}
