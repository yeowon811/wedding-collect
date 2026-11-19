"""청년 결혼 지원 정책 엑셀 → assets/data/policies.json 변환.

지원 자격 원문에서 지역·나이·혼인 조건 등을 **규칙(정규식)으로 1차 추출**한다.
추출 결과는 reviewed=false 로 저장하고, 앱에서는 "자동 추출 · 검수 전"으로 표시한다.
(다음 단계: AI로 다시 추출 → 사람이 검수 → reviewed=true)

사용법 (wedding-collect 폴더에서):
    python -I tools/convert_policies.py "../youth_wedding_support_2026.xlsx"
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xlsx_reader import read_sheets  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "policies.json")

NATIONAL = {"국토교통부", "보건복지부", "행정안전부"}

SIDO_BY_AGENCY = {
    "서울특별시": "서울", "부산광역시": "부산", "대구광역시": "대구", "인천광역시": "인천",
    "광주광역시": "광주", "대전광역시": "대전", "울산광역시": "울산", "세종특별자치시": "세종",
    "경기도": "경기", "강원특별자치도": "강원", "충청북도": "충북", "충청남도": "충남",
    "전북특별자치도": "전북", "전라남도": "전남", "경상북도": "경북", "경상남도": "경남",
    "제주특별자치도": "제주",
}

# 시·군 이름만 적힌 기관 → 시도
SIDO_BY_SIGUNGU = {
    "경기": "가평군 수원시 여주시 파주시 화성시 과천시 광명시 구리시 군포시 동두천시 시흥시 안산시 안양시 양평군 오산시 용인시 의왕시 이천시",
    "강원": "영월군 정선군 철원군 홍천군 화천군",
    "충북": "괴산군 음성군 청주시 충주시",
    "충남": "논산시 보령시 태안군 서천군 공주시 당진시 서산시 홍성군",
    "전북": "김제시 완주군 정읍시 고창군 익산시 전주시 장수군 군산시 남원시",
    "전남": "장흥군 순천시 영광군 화순군 광양시 고흥군 곡성군 무안군 영암군 장성군 진도군 함평군 나주시 여수시 완도군",
    "경북": "영천시 성주군 의성군 안동시 경산시 구미시 상주시 문경시 울진군 청송군",
    "경남": "함양군 밀양시 산청군 진주시 함안군 거창군 하동군 거제시 김해시 창원시 통영시",
}
SIGUNGU_TO_SIDO = {g: s for s, names in SIDO_BY_SIGUNGU.items() for g in names.split()}
AMBIGUOUS = {"고성군"}  # 강원·경남 둘 다 있음 → 앞뒤 정책의 시도로 판단

CATEGORY_RULES = [
    ("WEDDING", r"예식장|결혼식|대관|웨딩"),
    # 결혼자금·결혼비용·축하 바우처도 받는 돈 (2026-11-19: 함양 결혼자금 등이 기타로 분류되던 것 수정)
    ("CASH", r"장려금|축하금|지원금|목돈|공제|현금|결혼\s*자금|결혼\s*비용|바우처"),
    ("HOUSING", r"대출|이자|전세|임대|주택|주거|보증금|신혼집|리모델링"),
    ("HEALTH", r"검진|건강|가임|임신|엽산"),
    ("EDUCATION", r"교육|상담|교실|프로그램"),
]


def region_of(agency: str):
    name = agency.removesuffix("청")
    if agency in NATIONAL:
        return "전국", ""
    for full, short in SIDO_BY_AGENCY.items():
        if name == full:
            return short, ""
        if name.startswith(full + " "):
            return short, name[len(full) + 1:]
    if name in AMBIGUOUS:
        return None, name
    return SIGUNGU_TO_SIDO.get(name), name


def parse_age(text: str):
    m = re.search(r"(?:만\s*)?(\d{2})\s*세?\s*[~\-]\s*(?:만\s*)?(\d{2})\s*세", text)
    if m:
        return int(m.group(1)), int(m.group(2))
    m = re.search(r"(?:만\s*)?(\d{2})\s*세\s*이하", text)
    if m:
        return None, int(m.group(1))
    return None, None


def parse_married_years(text: str):
    m = re.search(r"(?:혼인|결혼)[^/]{0,12}?(\d{1,2})\s*년\s*(?:이내|미만)", text)
    return int(m.group(1)) if m else None


def parse_first_marriage(text: str):
    """초혼 조건: 'one' = 부부 중 1명 이상 초혼, 'both' = 초혼 부부(둘 다), None = 조건 없음·상관없음"""
    if "초혼" not in text or re.search(r"초혼\s*재혼\s*여부\s*상관\s*없", text):
        return None
    if re.search(r"(1\s*명|한\s*명|1\s*인)\s*이상\s*(이\s*)?초혼", text):
        return "one"
    return "both"


def category_of(name: str, text: str):
    for code, pattern in CATEGORY_RULES:
        if re.search(pattern, name):
            return code
    for code, pattern in CATEGORY_RULES:
        if re.search(pattern, text):
            return code
    return "ETC"


def main(path: str) -> None:
    rows = read_sheets(path)["청년결혼지원정책_전체"]
    policies = []
    for r in rows[1:]:
        no, name, agency, elig, url = (r + [""] * 5)[:5]
        sido, sigungu = region_of(agency.strip())
        age_min, age_max = parse_age(elig)
        policies.append({
            "id": f"P{int(no):03d}",
            "name": re.sub(r"^\[[^\]]+\]\s*", "", name).strip(),
            "agency": agency.strip(),
            "sido": sido,
            "sigungu": sigungu,
            "eligibility": elig.strip(),
            "url": url.strip(),
            "category": category_of(name, elig),
            "ageMin": age_min,
            "ageMax": age_max,
            "allowsEngaged": bool(re.search(r"예비|결혼\s*예정|혼인\s*예정|누구나", elig)),
            "marriedWithinYears": parse_married_years(elig),
            "firstMarriage": parse_first_marriage(elig),
            "hasIncomeLimit": "소득" in elig,
            "requiresHomeless": "무주택" in elig,
            "extractedBy": "rule",
            "reviewed": False,
        })

    # 시도를 못 정한 정책(고성군 등)은 바로 앞 정책의 시도를 따른다 (엑셀이 지역 순으로 정렬돼 있음)
    for i, p in enumerate(policies):
        if p["sido"] is None:
            prev = next((q["sido"] for q in reversed(policies[:i]) if q["sido"] not in (None, "전국")), None)
            p["sido"] = prev or "확인 필요"
            print(f"  시도 추정: {p['agency']} → {p['sido']} ({p['name']})")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(policies, f, ensure_ascii=False, indent=1)

    stat = lambda key: sum(1 for p in policies if p[key] not in (None, False))  # noqa: E731
    cats = {}
    for p in policies:
        cats[p["category"]] = cats.get(p["category"], 0) + 1
    print(f"policies: {len(policies)}  categories: {cats}")
    print(f"  나이 추출 {stat('ageMax')}건 · 혼인 N년 {stat('marriedWithinYears')}건 · "
          f"예비부부 가능 {stat('allowsEngaged')}건 · 소득조건 {stat('hasIncomeLimit')}건 · 초혼 조건 {stat('firstMarriage')}건")


if __name__ == "__main__":
    main(sys.argv[1])
