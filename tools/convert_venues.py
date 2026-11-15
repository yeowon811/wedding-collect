"""공공예식장 엑셀 → 앱에서 쓰는 JSON(assets/data/venues.json) 변환.

사용법 (wedding-collect 폴더에서):
    python -I tools/convert_venues.py "../전국 공공예식장 및 연계업체 현황 (2).xlsx"
"""
import json
import os
import sys
from urllib.parse import urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xlsx_reader import read_sheets  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "venues.json")

# 2026 행정구역 개편으로 광주·전남이 하나로 묶인 경우 등, 화면용 짧은 시도 이름
SIDO_SHORT = {
    "서울특별시": "서울", "부산광역시": "부산", "대구광역시": "대구", "인천광역시": "인천",
    "광주광역시": "광주", "대전광역시": "대전", "울산광역시": "울산", "세종특별자치시": "세종",
    "경기도": "경기", "강원특별자치도": "강원", "충청북도": "충북", "충청남도": "충남",
    "전북특별자치도": "전북", "전라남도": "전남", "전남광주통합특별시": "광주·전남",
    "경상북도": "경북", "경상남도": "경남", "제주특별자치도": "제주",
}


def classify_booking(method: str) -> str:
    """원본 예약방식 문구(36가지)를 4가지 유형으로 묶는다."""
    if "폼" in method:
        return "FORM"
    if "거점센터" in method or "맺어드림" in method:
        return "CENTER"
    if method.startswith(("유선", "방문", "신청서")) or "유선예약" in method:
        return "PHONE_VISIT"
    return "ONLINE"


def source_name(url: str) -> str:
    host = urlparse(url).netloc.lower()
    if "eshare.go.kr" in host:
        return "공유누리"
    if "seoulwomen" in host:
        return "서울마이웨딩"
    return host.removeprefix("www.") or "기관 안내"


def main(path: str) -> None:
    sheets = read_sheets(path)
    rows = sheets["공공예식장 목록"]
    header = rows[0]
    idx = {name: i for i, name in enumerate(header)}

    venues = []
    for r in rows[1:]:
        g = lambda key: r[idx[key]].strip() if idx[key] < len(r) else ""  # noqa: E731
        region = g("지역명")
        sido_full, _, sigungu = region.partition(" ")
        method = g("예약방식")
        booking_url = g("예약링크")
        venues.append({
            "id": g("예식장ID"),
            "sido": SIDO_SHORT.get(sido_full, sido_full),
            "sidoFull": sido_full,
            "sigungu": sigungu,
            "name": g("공공예식장 이름"),
            "address": g("주소"),
            "lat": float(g("위도")),
            "lng": float(g("경도")),
            "status": "LIMITED" if "기간제한" in g("운영상태") else "AVAILABLE",
            "statusText": g("운영상태"),
            "bookingType": classify_booking(method),
            "bookingMethod": method,
            "bookingContact": g("예약문의"),
            "bookingUrl": booking_url,
            "detailUrl": g("상세안내 링크"),
            "bookingSteps": g("예약이동경로 안내"),
            # 아직 수집 전인 값: 비워 두고 앱에서 "기관 확인 필요"로 표시
            "capacity": None,
            "rentalFee": None,
            "source": source_name(booking_url),
        })

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(venues, f, ensure_ascii=False, indent=1)

    counts = {}
    for v in venues:
        counts[v["bookingType"]] = counts.get(v["bookingType"], 0) + 1
    print(f"venues: {len(venues)}  bookingType: {counts}")


if __name__ == "__main__":
    main(sys.argv[1])
