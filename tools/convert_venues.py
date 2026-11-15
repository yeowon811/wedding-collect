"""공공예식장 엑셀 → 앱에서 쓰는 JSON(assets/data/venues.json) 변환.

입력 파일은 둘 중 하나:
- `공공예식장_eshare수집.xlsx` (권장): 기본 13개 열 + 공유누리(eshare) 수집 열(정원·요금·운영시간·사진 등)
- `전국 공공예식장 및 연계업체 현황 (2).xlsx`: 기본 13개 열만 (eshare 열이 없으면 모두 null)

사용법 (wedding-collect 폴더에서). 첫 파일이 기준(240곳 전체), 뒤 파일은 추가 수집본:
    python -I tools/convert_venues.py "../공공예식장_eshare수집.xlsx" "../공공예식장_더아결수집.xlsx"
변환 후 검증:
    python -I tools/validate_venues.py "../공공예식장_eshare수집.xlsx" --reference "../전국 공공예식장 및 연계업체 현황 (2).xlsx"
"""
import json
import os
import re
import sys
from urllib.parse import unquote, urlparse

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
            # ── 추가 수집 정보 (공유누리 또는 더아결). 수집 전이면 null ──
            "collectSource": "공유누리" if status else None,
            "collectStatus": status or None,
            "capacity": capacity,  # 명(최대). 등록 오류·문자값이면 null
            "capacityMin": None,  # 범위로 적힌 경우의 최소 (더아결)
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
            "reception": None,  # 피로연 (더아결)
            "availableDates2026": None,
            "unavailableDates2026": None,
            "availableDates2027": None,
            "partnerVendors": [],  # 협력 전문 웨딩업체 이름 (더아결)
            "extraInfo": None,  # 기타 안내 (더아결)
            "images": images,
            "aiImages": [],  # images 중 AI 생성 이미지
            "dataNotes": notes,  # 앱에서 "확인 필요"로 보여줄 데이터 주의 사항
        })
    return venues


# ───────────────────────── 더아결(서울마이웨딩) 수집 파일 ─────────────────────────

AI_IMAGE = re.compile(r"(?:^|[-_ .])AI(?:[-_ .]|$)|OPENAI_IMAGE")


def is_ai_image(url: str) -> bool:
    """파일명에 'AI' 표시가 있거나 OPENAI 생성 파일이면 AI 생성 이미지로 본다 (수집 파일 기준과 같음)"""
    name = unquote(url.rsplit("/", 1)[-1])
    return bool(AI_IMAGE.search(name))


def parse_capacity_range(text: str):
    """'100명~200명' → (100, 200, None). '50명 이하' → (None, 50, None). '0명' → (None, None, 이유)."""
    text = text.strip()
    if not text:
        return None, None, None
    m = re.fullmatch(r"(\d+)\s*명?\s*~\s*(\d+)\s*명", text)
    if m:
        return int(m.group(1)), int(m.group(2)), None
    m = re.fullmatch(r"(\d+)\s*명\s*이하", text)
    if m:
        return None, int(m.group(1)), None
    m = re.fullmatch(r"(\d+)\s*명", text)
    if m and int(m.group(1)) > SUSPICIOUS_CAPACITY_MAX:
        return None, int(m.group(1)), None
    return None, None, f"수용인원 '{text}'은 숫자로 쓸 수 없음"


def parse_fee_theagyeol(text: str):
    """'무료 …'로 시작하면 0원. 시간·구역별로 다른 유료 요금은 숫자 없이 원문으로 둔다."""
    text = text.strip()
    if not text:
        return None, None
    if text.startswith("무료"):
        return 0, None
    return None, "대관료가 시간·공간별로 달라 숫자로 정리하지 않음(원문 참고)"


def apply_theagyeol(venues: list, path: str) -> None:
    """더아결 수집 파일의 값을 같은 예식장 ID에 채운다 (이미 다른 출처로 수집된 곳은 덮어쓰지 않음)."""
    rows = read_sheets(path)["공공예식장 목록"]
    idx = {name: i for i, name in enumerate(rows[0])}
    by_id = {v["id"]: v for v in venues}

    for r in rows[1:]:
        def g(key, r=r):
            i = idx.get(key)
            return r[i].strip() if i is not None and i < len(r) else ""

        v = by_id[g("예식장ID")]
        status = g("더아결 수집상태")
        if not status:
            continue
        if v["collectStatus"]:
            raise ValueError(f"{v['id']}는 이미 {v['collectSource']}에서 수집됨 (중복 출처)")

        cap_min, cap_max, cap_note = parse_capacity_range(g("수용인원"))
        fee, fee_note = parse_fee_theagyeol(g("대관료"))
        images = [u.strip() for u in g("전체 이미지 URL").split("\n") if u.strip()]
        notes = [n for n in [cap_note, fee_note] if n]
        if g("수집 비고"):
            notes.append(g("수집 비고"))

        v.update({
            "collectSource": "서울마이웨딩(더아결)",
            "collectStatus": status,
            "capacity": cap_max,
            "capacityMin": cap_min,
            "capacityText": g("수용인원") or None,
            "rentalFee": fee,
            "feeText": g("대관료") or None,
            "feeDetail": None,
            "parking": g("주차") or None,
            "reception": g("피로연") or None,
            "availableDates2026": g("예식가능일자(26년)") or None,
            "unavailableDates2026": g("예식불가일자(26년)") or None,
            "availableDates2027": g("예식가능일자(27년)") or None,
            "partnerVendors": [p.strip() for p in g("협력전문웨딩업체").split(",") if p.strip()],
            "extraInfo": g("기타 안내") or None,
            "images": images,
            "aiImages": [u for u in images if is_ai_image(u)],
            "dataNotes": notes,
        })


def build_all(base: str, supplements=()) -> list:
    """기준 파일(공유누리 수집본) + 추가 수집 파일들을 합친다."""
    venues = build(base)
    for path in supplements:
        apply_theagyeol(venues, path)
    return venues


def main(argv) -> None:
    base, supplements = argv[0], argv[1:]
    venues = build_all(base, supplements)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(venues, f, ensure_ascii=False, indent=1)

    counts = {}
    for v in venues:
        counts[v["bookingType"]] = counts.get(v["bookingType"], 0) + 1
    by_source = {}
    for v in venues:
        key = v["collectSource"] or "미수집"
        by_source[key] = by_source.get(key, 0) + 1
    print(f"venues: {len(venues)}  bookingType: {counts}")
    print(f"수집 출처: {by_source}")
    print(f"정원 {sum(v['capacity'] is not None for v in venues)}곳 · "
          f"요금 {sum(v['rentalFee'] is not None for v in venues)}곳 · "
          f"사진 {sum(1 for v in venues if v['images'])}곳 · "
          f"AI 이미지 {sum(len(v['aiImages']) for v in venues)}장")


if __name__ == "__main__":
    main(sys.argv[1:])
