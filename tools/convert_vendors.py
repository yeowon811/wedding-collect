"""업체 데이터 만들기.

1) 실제 연계업체 103곳 → assets/data/vendors.json (가격 없음)
2) 예식장-업체 거리매칭 1,920건 → assets/data/venue_vendor_matches.json
3) 시연용 가상 업체 (11개 항목 × 17개 시도 × 3곳) → assets/data/demo_vendors.json
   - 이름 앞에 '[시연]'을 붙이고 isDemo=true. 실제 업체와 섞지 않는다.
   - 가격대는 임의로 만든 값이다 (시연용). 고정 시드라 매번 같은 결과가 나온다.

사용법 (wedding-collect 폴더에서):
    python -I tools/convert_vendors.py "../전국 공공예식장 및 연계업체 현황 (2).xlsx"
"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xlsx_reader import read_sheets  # noqa: E402

DATA = os.path.join(os.path.dirname(__file__), "..", "assets", "data")

SIDO_SHORT = {
    "서울특별시": "서울", "부산광역시": "부산", "대구광역시": "대구", "인천광역시": "인천",
    "광주광역시": "광주", "대전광역시": "대전", "울산광역시": "울산", "세종특별자치시": "세종",
    "경기도": "경기", "강원특별자치도": "강원", "충청북도": "충북", "충청남도": "충남",
    "전북특별자치도": "전북", "전라남도": "전남", "전남광주통합특별시": "광주·전남",
    "경상북도": "경북", "경상남도": "경남", "제주특별자치도": "제주",
}
SIDOS = ["서울", "부산", "대구", "인천", "광주", "대전", "울산", "세종", "경기",
         "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주"]

# 실제 업체 카테고리(4종) → 앱 카테고리 코드
REAL_CATEGORY = {
    "스드메·웨딩디렉팅": "DIRECTING",
    "식사·출장뷔페·케이터링": "CATERING",
    "웨딩사진·스냅": "PHOTO",
    "사회·예식도우미·진행": "HOST",
}

# 시연용 11개 항목: (코드, 최소가, 최대가, 단위, 이름 단어, 패키지 구성 후보, 스타일 후보)
DEMO_CATEGORIES = [
    ("DRESS", 80, 320, "", ["라벨르", "온유", "메종드블랑", "스텔라", "르시엘", "아뜰리에 화이트", "다온", "베일리"],
     ["본식 드레스 1벌", "촬영 드레스 3벌", "가봉 2회", "턱시도 할인", "베일·장갑 포함", "헬퍼 동행"],
     ["클래식", "모던", "내추럴", "러블리", "미니멀"]),
    ("MEAL", 3, 7, "1인", ["한상차림", "온새미 케이터링", "들녘뷔페", "바른식탁", "정담", "푸드앤모어"],
     ["한식 뷔페", "양식 코스", "출장 뷔페", "음료·주류 포함", "답례떡", "최소 80인부터"],
     ["한식", "양식", "퓨전", "뷔페", "코스"]),
    ("STUDIO", 80, 260, "", ["스튜디오 하루", "빛담", "포토그래피 결", "모먼트", "스튜디오 온", "필름로그"],
     ["원본 전체 제공", "앨범 2권", "액자 1개", "야외 촬영", "수정본 30장", "한복 촬영 추가"],
     ["인물 중심", "배경 중심", "흑백", "야외", "빈티지"]),
    ("SNAP", 30, 130, "", ["봄날스냅", "데일리스냅", "스냅작업실", "윤슬", "하루필름", "소소스냅"],
     ["본식 스냅", "원본 전체", "보정 80장", "작가 2인", "당일 미리보기", "공공예식장 출장"],
     ["자연광", "필름톤", "다큐", "감성", "밝은톤"]),
    ("INVITATION", 10, 45, "100장", ["종이와 잉크", "카드공방", "청첩상회", "레터프레스 숲", "봉투가게"],
     ["모바일 청첩장 무료", "샘플 3종", "봉투·스티커", "식권 제작", "디자인 수정 2회"],
     ["미니멀", "한지", "일러스트", "레터프레스", "모던"]),
    ("PROPS", 15, 70, "", ["꽃담", "플라워 소요", "케이크하우스", "블룸앤베이크", "꽃과 오후"],
     ["부케·부토니에", "웨딩 케이크", "포토테이블 장식", "화동 꽃", "생화 센터피스"],
     ["생화", "드라이플라워", "미니 케이크", "내추럴", "화이트톤"]),
    ("VIDEO", 40, 160, "", ["필름하우스", "영상공방", "시네마 웨딩", "무빙로그", "프레임"],
     ["본식 하이라이트", "풀영상", "드론 촬영", "4K 촬영", "USB 제공", "당일 편집본"],
     ["시네마틱", "다큐", "하이라이트", "감성", "밝은톤"]),
    ("SUIT", 40, 160, "", ["테일러 정", "맞춤정장 결", "수트하우스", "젠틀맨스", "모던테일러"],
     ["맞춤 정장 1벌", "셔츠 2장", "타이·행커치프", "가봉 1회", "대여 옵션"],
     ["클래식", "슬림핏", "쓰리피스", "턱시도", "캐주얼"]),
    ("HANBOK", 20, 120, "", ["한복담", "고운옷", "단아한복", "여울한복", "한복공방 비단"],
     ["혼주 한복 대여 2벌", "맞춤 한복", "장신구 포함", "당일 착장 도움", "사진 촬영용"],
     ["전통", "모던", "파스텔", "단아", "화사"]),
    ("PARENT_MAKEUP", 15, 50, "", ["메이크업 아뜰", "뷰티라운지", "단정", "헤어앤메이크업 빛"],
     ["혼주 2인 메이크업", "헤어 포함", "출장 가능", "얼리 스타트 무료"],
     ["내추럴", "단아", "화사", "클래식"]),
    ("MAKEUP", 30, 110, "", ["메이크업 결", "브라이드룸", "뷰티아뜰리에", "윤슬 메이크업", "라온 뷰티"],
     ["본식 메이크업", "촬영 메이크업", "헤어 2회", "리허설 1회", "출장 가능"],
     ["내추럴", "글로우", "클래식", "러블리", "모던"]),
]


def num(v):
    try:
        return float(v)
    except ValueError:
        return None


def build_real(sheets):
    rows = sheets["연계업체 마스터"]
    idx = {h: i for i, h in enumerate(rows[0])}
    out = []
    for r in rows[1:]:
        g = lambda k: r[idx[k]].strip() if idx[k] < len(r) else ""  # noqa: E731
        region = g("소재지(지역)")
        sido_full, _, sigungu = region.partition(" ")
        out.append({
            "id": g("업체ID"),
            "name": g("업체명"),
            "category": REAL_CATEGORY.get(g("카테고리"), "DIRECTING"),
            "categoryText": g("카테고리"),
            "official": g("공식연계여부"),
            "sido": SIDO_SHORT.get(sido_full, sido_full),
            "sigungu": sigungu,
            "address": g("주소"),
            "lat": num(g("위도")),
            "lng": num(g("경도")),
            "phone": g("연락처"),
            "url": g("링크/홈페이지"),
            "services": g("주요제공서비스"),
        })
    return out


def build_matches(sheets):
    rows = sheets["예식장-업체 거리매칭"]
    idx = {h: i for i, h in enumerate(rows[0])}
    out = {}
    for r in rows[1:]:
        venue = r[idx["예식장ID"]]
        out.setdefault(venue, []).append({
            "vendorId": r[idx["업체ID"]],
            "category": REAL_CATEGORY.get(r[idx["카테고리"]], "DIRECTING"),
            "rank": int(r[idx["추천순위"]]),
            "distanceKm": round(float(r[idx["거리(km)"]]), 1),
            "linkType": r[idx["연계유형(공식전담/거리기반)"]],
        })
    for v in out.values():
        v.sort(key=lambda m: (m["category"], m["rank"]))
    return out


def build_demo():
    rnd = random.Random(20261123)
    out = []
    n = 0
    for sido in SIDOS:
        for code, lo, hi, unit, words, items, styles in DEMO_CATEGORIES:
            for name in rnd.sample(words, 3):
                n += 1
                p_min = rnd.randint(lo, max(lo, int(hi * 0.7)))
                p_max = rnd.randint(p_min + max(1, (hi - lo) // 6), hi + max(1, (hi - lo) // 5))
                out.append({
                    "id": f"D{n:04d}",
                    "name": f"[시연] {name} {sido}점",
                    "category": code,
                    "sido": sido,
                    "priceMin": p_min,  # 만원 단위
                    "priceMax": p_max,
                    "priceUnit": unit,
                    "packageItems": rnd.sample(items, min(len(items), rnd.randint(3, 4))),
                    "styles": rnd.sample(styles, 2),
                    "rating": round(rnd.uniform(4.0, 4.9), 1),
                    "reviewCount": rnd.randint(12, 480),
                    "publicVenueOk": rnd.random() < 0.7,  # 공공예식장 출장·제휴 가능
                    "isDemo": True,
                })
    return out


def write(name, data):
    os.makedirs(DATA, exist_ok=True)
    with open(os.path.join(DATA, name), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))


def main(path):
    sheets = read_sheets(path)
    real = build_real(sheets)
    matches = build_matches(sheets)
    demo = build_demo()
    write("vendors.json", real)
    write("venue_vendor_matches.json", matches)
    write("demo_vendors.json", demo)
    print(f"real vendors: {len(real)}  matches: {sum(len(v) for v in matches.values())} "
          f"(venues {len(matches)})  demo vendors: {len(demo)}")


if __name__ == "__main__":
    main(sys.argv[1])
