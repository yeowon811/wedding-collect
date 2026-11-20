import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/venue.dart';

/// 예식장 상세의 '위치': 작은 지도(OpenStreetMap) + 위치 표시 + [네이버 지도로 보기]
///
/// 좌표는 수집 데이터(240곳 모두 있음). 지도는 보기 전용(움직이지 않음),
/// 길찾기·주변 정보는 네이버 지도로 넘긴다.
class VenueLocationMap extends StatelessWidget {
  const VenueLocationMap({super.key, required this.venue, required this.onOpen});

  final Venue venue;
  final void Function(Uri uri) onOpen;

  /// 테스트에서는 지도 타일(네트워크)을 끈다
  static bool showTiles = true;

  /// 네이버 지도 검색 주소. 주소 뒤의 층·호실 같은 덧붙임은 빼고 도로명 + 건물 번호까지만 쓴다
  /// (예: "서울특별시 강남구 남부순환로 3104 SETEC 2층" → "서울특별시 강남구 남부순환로 3104")
  static Uri naverMapUri(Venue v) {
    final a = v.address.trim();
    // 도로명 주소: "…로 3104", "…로58번길 10-5" / 지번 주소: "…동 380-1", "…동 산 42-3", "…리 217"
    final m = RegExp(r'^(.*?\S(?:로|길)\s+\d+(?:-\d+)?)').firstMatch(a) ??
        // 띄어쓰기 없이 붙은 번호: "양화로72 지하1,2층", "증산로32(…)", "율곡로3길4"
        RegExp(r'^(.*?\S(?:로|길)\d+(?:-\d+)?)(?=\s|\(|$)').firstMatch(a) ??
        RegExp(r'^(.*?\S(?:동|리|가)\s+(?:산\s*)?\d+(?:-\d+)?)').firstMatch(a);
    // 둘 다 안 맞으면(예: "증산로32(월드컵공원 …)") 괄호 설명만 빼고 그대로
    final query = m?.group(1) ?? a.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    return Uri.parse('https://map.naver.com/p/search/${Uri.encodeComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(venue.lat, venue.lng);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('위치', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        // 양옆을 조금 줄여 가운데에 (화면 폭과 같으면 답답해 보여서)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              color: AppColors.fill,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: showTiles
                ? FlutterMap(
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 15,
                      // 보기 전용: 상세 화면을 넘길 때 지도가 스크롤을 가로채지 않게
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.weddingcollect.wedding_collect',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: point,
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: Icon(Icons.location_on, size: 36, color: AppColors.primary),
                        ),
                      ]),
                      // OpenStreetMap 이용 조건: 지도 위에 저작권 표시
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('© OpenStreetMap',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ),
                      ),
                    ],
                  )
                : Center(child: Icon(Icons.map_outlined, size: 36, color: AppColors.textHint)),
          ),
        ),
        ),
        const SizedBox(height: 10),
        // 지도 아래: 왼쪽 주소, 오른쪽 작은 버튼 (지도와 같은 양옆 여백)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Text(venue.address,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 2),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => onOpen(naverMapUri(venue)),
              // 작은 버튼: 글자·아이콘은 버튼 안 가운데
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.center,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('네이버 지도로 보기', textAlign: TextAlign.center),
            ),
          ]),
        ),
      ]),
    );
  }
}
