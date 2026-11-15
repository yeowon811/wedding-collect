"""공공예식장 엑셀 → 앱에서 쓰는 JSON(assets/data/venues.json) 변환.

입력 파일은 둘 중 하나:
- `공공예식장_eshare수집.xlsx` (권장): 기본 13개 열 + 공유누리(eshare) 수집 열(정원·요금·운영시간·사진 등)
- `전국 공공예식장 및 연계업체 현황 (2).xlsx`: 기본 13개 열만 (eshare 열이 없으면 모두 null)

사용법 (wedding-collect 폴더에서):
    python -I tools/convert_venues.py "../공공예식장_eshare수집.xlsx"
변환 후 검증:
    python -I tools/validate_venues.py "../공공예식장_eshare수집.xlsx" --reference "../전국 공공예식장 및 연계업체 현황 (2).xlsx"
"""
import json
import os
import re
import sys
from urllib.parse import urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xlsx_reader import read_sheets  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "venues.json")

SIDO_SHORT = {
    "서울특별시": "서울", "부산광역시": "부산", "대구광역시": "대구", "인천광역시": "인천",
    "광주광역시": "광주", "대전광역시": "대전", "울산광역시": "울산", "세종특별자치시": "세종",
    "경기도": "경기", "강원특별자치도": "강원", "충청북도": "충북", "충청남도": "충남",
    "전북특별자치도": "전북", "전라남도": "전남", "전남광주통합특별시": "광주·전남",
    "경상북도": "경북", "경상남도": "경남", "제주특별자치도": "제주",
}

# 정원이 이 값 이하이면 실제 수용 인원이 아닌 등록 오류로 본다 (eshare 템플릿 기본값 '1명' 등)
SUSPICIOUS_CAPACITY_MAX = 1


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


def parse_capacity(text: str):
    """'100명' → (100, None). '1명'·'문의'·'시간별 상이' → (None, 이유)."""
    text = text.strip()
    if not text:
        return None, None
    m = re.fullmatch(r"([\d,]+)\s*명", text)
    if not m:
        return None, f"정원 값이 숫자가 아님('{text}')"
    n = int(m.group(1).replace(",", ""))
    if n <= SUSPICIOUS_CAPACITY_MAX:
        return None, f"정원 '{text}'은 등록 오류로 보임"
    return n, None


def parse_fee(text: str):
    """'무료' → (0, None). '기본요금 100,000원' → (100000, None). 그 외 → (None, 이유)."""
    text = text.strip()
    if not text:
        return None, None
    if text == "무료":
        return 0, None
    m = re.fullmatch(r"기본요금\s*([\d,]+)\s*원", text)
    if m:
        return int(m.group(1).replace(",", "")), None
    return None, f"요금 값을 숫자로 읽을 수 없음('{text}')"


def build(path: str):
    sheets = read_sheets(path)
    rows = sheets["공공예식장 목록"]
    header = rows[0]
    idx = {name: i for i, name in enumerate(header)}

    def getter(r):
        def g(key):
            i = idx.get(key)
            return r[i].strip() if i is not None and i < len(r) else ""
        return g

    venues = []
    for r in rows[1:]:
        g = getter(r)
        region = g("지역명")
        sido_full, _, sigungu = region.partition(" ")
        method = g("예약방식")
        booking_url = g("예약링크")

        status = g("eshare 수집상태")
        capacity, cap_note = parse_capacity(g("이용정원"))
        fee, fee_note = parse_fee(g("이용요금"))
        images = [g(f"이미지{i} URL") for i in range(1, 6) if g(f"이미지{i} URL")]
        reported_images = int(g("이미지 수") or 0)

        notes = [n for n in [cap_note, fee_note] if n]
        if reported_images and len(images) < reported_images:
            notes.append(f"사진 {reported_images}장 중 {len(images)}장만 주소 확인")
        if status == "페이지 없음":
            notes.append("공유누리 상세 페이지가 없음(삭제·비공개 추정) → 운영상태 재확인 필요")
        if g("수집 비고"):
            notes.append(g("수집 비고"))

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
            "source": source_name(booking_url),
            # ── 공유누리(eshare) 수집 정보. 수집 전이면 null ──
            "eshareStatus": status or None,
            "capacity": capacity,  # 명. 등록 오류·문자값이면 null
            "capacityText": g("이용정원") or None,  # 원본 값
            "rentalFee": fee,  # 원. 무료=0, 알 수 없으면 null
            "feeText": g("이용요금") or None,
            "feeDetail": g("요금 상세(상세설명)") or None,
            "hoursWeekday": g("평일 운영시간") or None,
            "hoursSaturday": g("토요일 운영시간") or None,
            "hoursHoliday": g("일요일/공휴일 운영시간") or None,
            "applyPeriod": g("접수일시") or None,
            "operatingPeriod": g("이용기간") or None,
            "approval": g("심사여부") or None,
            "prepTime": g("준비시간") or None,
            "target": g("이용대상") or None,
            "indoorOutdoor": g("실내·외") or None,
            "parking": g("주차") or None,
            "area": g("규모면적") or None,
            "images": images,
            "dataNotes": notes,  # 앱에서 "확인 필요"로 보여줄 데이터 주의 사항
        })
    return venues


def main(path: str) -> None:
    venues = build(path)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(venues, f, ensure_ascii=False, indent=1)

    counts = {}
    for v in venues:
        counts[v["bookingType"]] = counts.get(v["bookingType"], 0) + 1
    collected = sum(1 for v in venues if v["eshareStatus"])
    print(f"venues: {len(venues)}  bookingType: {counts}")
    print(f"eshare 수집: {collected}곳 · 정원 {sum(v['capacity'] is not None for v in venues)}곳 · "
          f"요금 {sum(v['rentalFee'] is not None for v in venues)}곳 · "
          f"사진 {sum(1 for v in venues if v['images'])}곳")


if __name__ == "__main__":
    main(sys.argv[1])
