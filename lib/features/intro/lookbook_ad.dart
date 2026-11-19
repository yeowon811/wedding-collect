import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/demo_links.dart';
import '../../data/models/venue.dart';
import '../../data/repositories/repositories.dart';
import '../venue/venue_detail_screen.dart';

/// 앱을 처음 열 때 띄우는 '룩북' 광고 (시안 6의 LAYER 1).
/// 사진은 분위기 이미지(AI 생성)이고, 이름·지역·대관료·정원은 실제 예식장 데이터에서 가져온다.
/// [터치하여 예식장 보기] → 그 예식장 상세로 이동. 위 X로 닫기, [오늘 하루 보지 않기]는 기기에 날짜를 저장한다.
class LookbookAd extends StatefulWidget {
  const LookbookAd({super.key, this.slides = catalog, required this.onOpenVenue});

  final List<LookbookSlide> slides;
  final void Function(Venue v) onOpenVenue;

  /// 테스트에서는 끈다
  static bool enabled = true;
  static const _hideKey = 'lookbook_hide_date';

  /// 사진 ↔ 실제 예식장 (사진 분위기와 맞는 곳). highlight는 그 예식장 데이터(이용 안내·피로연)에서 고른 한 줄
  static const catalog = [
    LookbookSlide('assets/images/lookbook/1_hanok-01.jpg', 'H084', '창녕위궁재사 한옥 · 도시락 피로연'),
    LookbookSlide('assets/images/lookbook/2_forest-02.jpg', 'H126', '서울숲 야외 정원 · 케이터링 피로연'),
    LookbookSlide('assets/images/lookbook/3_atelier-03.jpg', 'H099', '썬큰가든 50명 · 별광장 100명'),
    LookbookSlide('assets/images/lookbook/4_couture-04.jpg', 'H089', '식물원 잔디마당 · 도시락 피로연'),
    LookbookSlide('assets/images/lookbook/5_lawn-05.jpg', 'H105', '야외 잔디 예식 · 케이터링 피로연'),
    LookbookSlide('assets/images/lookbook/6_nocturne-06.jpg', 'H147', '야간 예식 18~21시 · 중정·로비'),
  ];

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// 앱 시작 때: 시연 링크가 아니고, 오늘 숨기지 않았으면 띄운다
  /// 앱이 뜨자마자(첫 화면을 누르기 전에) 보여 준다: 예식장 데이터를 기다리지 않고 사진부터,
  /// 이름·대관료는 데이터가 오면 채운다
  static Future<void> showIfNeeded(BuildContext context) async {
    if (!enabled || DemoLinks.isDemoLink) return;
    if (await hiddenToday()) return;
    if (!context.mounted) return;
    // 첫 사진을 미리 읽어 두면 빈 화면 없이 바로 보인다 (오래 걸리면 기다리지 않음)
    await Future.any([
      precacheImage(AssetImage(catalog.first.asset), context),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    final picked = await showGeneralDialog<Venue>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, _) => LookbookAd(onOpenVenue: (v) => Navigator.of(ctx).pop(v)),
    );
    if (picked != null) {
      nav.push(MaterialPageRoute(builder: (_) => VenueDetailScreen(venue: picked)));
    }
  }

  /// 오늘 [오늘 하루 보지 않기]를 눌렀는지 (저장소를 못 쓰면 false = 띄운다)
  static Future<bool> hiddenToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_hideKey) == _today();
    } catch (_) {
      return false;
    }
  }

  static Future<void> hideToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hideKey, _today());
    } catch (_) {}
  }

  @override
  State<LookbookAd> createState() => _LookbookAdState();
}

class LookbookSlide {
  const LookbookSlide(this.asset, this.venueId, this.highlight);

  final String asset;
  final String venueId;
  final String highlight;
}

class _LookbookAdState extends State<LookbookAd> with SingleTickerProviderStateMixin {
  static const _interval = Duration(milliseconds: 3800);
  final _page = PageController();
  late final AnimationController _progress = AnimationController(vsync: this, duration: _interval)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _go(_index + 1);
    })
    ..forward();
  int _index = 0;
  Map<String, Venue>? _venues;

  int get _count => widget.slides.length;

  @override
  void initState() {
    super.initState();
    final cached = Repos.venue.cached;
    if (cached != null) {
      _venues = {for (final v in cached) v.id: v};
    } else {
      Repos.venue.loadAll().then((all) {
        if (mounted) setState(() => _venues = {for (final v in all) v.id: v});
      });
    }
    // 나머지 사진도 미리 읽어 둔다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in widget.slides.skip(1)) {
        precacheImage(AssetImage(s.asset), context).ignore();
      }
    });
  }

  void _go(int i) {
    final next = i % _count;
    _page.animateToPage(next, duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);
  }

  void _onPage(int i) {
    setState(() => _index = i);
    _progress
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.slides[_index];
    return Material(
      color: const Color(0xFF2C2926),
      child: Stack(fit: StackFit.expand, children: [
        // 지금 사진을 흐리게 깐 배경
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          child: ImageFiltered(
            key: ValueKey(cur.asset),
            imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Color(0x8C000000), BlendMode.darken),
              child: Transform.scale(scale: 1.2, child: Image.asset(cur.asset, fit: BoxFit.cover)),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            // 위: 로고 + 닫기(X)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 10),
              child: Row(children: [
                const Text('We Connect',
                    style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const Spacer(),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                ),
              ]),
            ),
            // 가운데: 사진첩
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Listener(
                    // 누르고 있는 동안 자동 넘김 멈춤
                    onPointerDown: (_) => _progress.stop(),
                    onPointerUp: (_) => _progress.forward(),
                    onPointerCancel: (_) => _progress.forward(),
                    child: PageView.builder(
                      controller: _page,
                      onPageChanged: _onPage,
                      itemCount: _count,
                      itemBuilder: (context, i) => _slide(widget.slides[i]),
                    ),
                  ),
                ),
              ),
            ),
            // 아래: 진행 막대 + 번호
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                for (var i = 0; i < _count; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _go(i),
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(2)),
                        alignment: Alignment.centerLeft,
                        child: i < _index
                            ? const FractionallySizedBox(widthFactor: 1, child: _BarFill())
                            : i == _index
                                ? AnimatedBuilder(
                                    animation: _progress,
                                    builder: (_, _) =>
                                        FractionallySizedBox(widthFactor: _progress.value, child: const _BarFill()),
                                  )
                                : null,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Text('${(_index + 1).toString().padLeft(2, '0')} / ${_count.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            // 맨 아래: 오늘 하루 보지 않기 · 닫기
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
              child: Row(children: [
                TextButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await LookbookAd.hideToday();
                    nav.pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('오늘 하루 보지 않기', style: TextStyle(fontSize: 14)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('닫기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _slide(LookbookSlide s) {
    final v = _venues?[s.venueId];
    final fee = v == null ? '' : (v.rentalFee == null ? '대관료 문의' : (v.isFree ? '대관료 무료' : v.feeLabel));
    return GestureDetector(
      onTap: v == null ? null : () => widget.onOpenVenue(v),
      child: Stack(fit: StackFit.expand, children: [
        Image.asset(s.asset, fit: BoxFit.cover),
        // 아래쪽을 어둡게 해서 글자가 잘 보이게
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x14000000), Color(0x05000000), Color(0x8C000000), Color(0xDB000000)],
              stops: [0, 0.45, 0.72, 1],
            ),
          ),
        ),
        if (v != null)
        Positioned(
          left: 22,
          right: 22,
          bottom: 30,
          child: Column(children: [
            Text('${v.region} · 공공예식장',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(v.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    shadows: [Shadow(color: Color(0x73000000), blurRadius: 20, offset: Offset(0, 4))])),
            const SizedBox(height: 10),
            Text('$fee · ${v.capacityLabel}\n${s.highlight}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 15, height: 1.55)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: const Text('터치하여 예식장 보기 →',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _BarFill extends StatelessWidget {
  const _BarFill();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
      );
}
