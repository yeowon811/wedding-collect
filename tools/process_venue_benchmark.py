"""사용자 제공 private_wedding_venue_benchmark_2026.xlsx 가공·검증 (2026-11-22)

원본 '대관_추가금_특이사항' 한 칸에 섞여 있던 정보를 항목별 열로 나누고,
모든 숫자를 한국소비자원 참가격 공식 페이지에서 읽은 값(assets/data/consumer_wedding_prices.json,
tools/raw/consumer_addons_2026-09.tsv)과 대조한다.

결과:
- docs/data-validation/private_venue_benchmark_clean_2026-11-22.csv  (가공한 표, 엑셀에서 열림)
- docs/data-validation/private_venue_benchmark_check_2026-11-22.md   (검증 보고서)

사용: python -I tools/process_venue_benchmark.py "<xlsx 경로>"
"""
import csv
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xlsx_reader import read_sheets  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "docs" / "data-validation"
COLLECTED = "2026-11-22"

# 원본 지역명 → 참가격 지역 키
REGION_KEY = {
    "전국 전체": "전국", "수도권 전체": "수도권", "비수도권 전체": "비수도권",
    "서울(강남)": "서울(강남)", "서울(강남 외)": "서울(강남외)", "경기도": "경기도", "인천광역시": "인천",
    "부산광역시": "부산", "대구광역시": "대구", "대전광역시": "대전", "울산광역시": "울산", "광주·전남": "전남광주",
    "강원특별자치도": "강원도", "충청권(세종·충북·충남)": "충청도", "전북특별자치도": "전북",
    "경상권(경북·경남)": "경상도", "제주특별자치도": "제주도",
}
ADDON_ITEMS = [("생화꽃장식", "생화꽃장식"), ("본식촬영", "본식 촬영 비용"), ("폐백음식", "폐백 음식"),
               ("폐백수모비", "폐백 수모비"), ("사회자", "본식 사회자")]


def man(v):
    """원 → 만원"""
    x = round(int(float(v)) / 10000, 1)
    return int(x) if x == int(x) else x


def num(v):
    x = float(v)
    return int(x) if x == int(x) else x


def parse_note(text):
    """'[필수 기본장식비] 평균 78만 원(중간값 0원, 상위10% 200만 원) | [… 선택 추가금 중간값] 생화꽃장식 256만 원(평균 432만 원), … | [보증인원·정산 유의] …(권역 설명)'"""
    out = {}
    m = re.search(r"\[필수 기본장식비\]\s*평균\s*([\d.]+)만 원\(중간값\s*([\d.]+)원,\s*상위10%\s*([\d.]+)만 원\)", text)
    if m:
        out["기본장식비_평균"], out["기본장식비_상위10"] = num(m[1]), num(m[3])
    m = re.search(r"\[([^\[\]]+?) 선택 추가금 중간값\]", text)
    if m:
        out["추가금_권역"] = m[1]
    m = re.search(r"생화꽃장식\s*([\d.]+)만 원\(평균\s*([\d.]+)만 원\)", text)
    if m:
        out["생화꽃장식_중간"], out["생화꽃장식_평균"] = num(m[1]), num(m[2])
    for name, _ in ADDON_ITEMS[1:]:
        m = re.search(name + r"\s*([\d.]+)만 원", text)
        if m:
            out[name + "_중간"] = num(m[1])
    m = re.search(r"\[보증인원·정산 유의\][^(]*\((.+)\)\s*$", text.strip())
    if m:
        out["포함_지역"] = m[1]
    return out


def main(xlsx):
    sheets = read_sheets(xlsx)
    rows = next(iter(sheets.values())) if isinstance(sheets, dict) else sheets[0][1]
    head = [str(c) for c in rows[0]]
    official = json.loads((ROOT / "assets" / "data" / "consumer_wedding_prices.json").read_text(encoding="utf-8"))
    regions, addons = official["regions"], official["addOns"]

    table, mismatches = [], []
    for r in rows[1:]:
        if not r or not r[0]:
            continue
        rec = dict(zip(head, r))
        # 특이사항 칸에 ' | '가 섞여 열이 밀린 경우: 출처 URL은 마지막 칸, 나머지는 특이사항으로 합침
        cells = [("" if c is None else str(c)) for c in r]
        url = next((c for c in reversed(cells) if c.startswith("http")), "")
        note = " | ".join(cells[head.index("대관_추가금_특이사항"): len(cells) - (1 if url else 0)])
        name = str(rec["지역명"]).strip()
        key = REGION_KEY.get(name)
        n = parse_note(note)
        out = {
            "지역명": name,
            "참가격_지역": key or "",
            "포함_지역": n.get("포함_지역", ""),
            "대관료_중간(만원)": man(rec["대관료_중간값(원)"]),
            "대관료_평균(만원)": man(rec["대관료_평균값(원)"]),
            "대관료_하위10%(만원)": man(rec["대관료_하위10%(원)"]),
            "대관료_상위10%(만원)": man(rec["대관료_상위10%(원)"]),
            "1인당식대_중간(만원)": man(rec["1인당식대_중간값(원)"]),
            "최소보증인원_중간(명)": int(float(rec["최소보증인원(명)"])),
            "기본장식비_평균(만원)": n.get("기본장식비_평균", ""),
            "기본장식비_상위10%(만원)": n.get("기본장식비_상위10", ""),
            "추가금_공표권역": n.get("추가금_권역", ""),
            "생화꽃장식_중간(만원)": n.get("생화꽃장식_중간", ""),
            "생화꽃장식_평균(만원)": n.get("생화꽃장식_평균", ""),
            "본식촬영_중간(만원)": n.get("본식촬영_중간", ""),
            "폐백음식_중간(만원)": n.get("폐백음식_중간", ""),
            "폐백수모비_중간(만원)": n.get("폐백수모비_중간", ""),
            "사회자_중간(만원)": n.get("사회자_중간", ""),
            "조사_시점": "2026년 9월 (참가격 최신 공표)",
            "수집일": COLLECTED,
            "출처": url,
        }
        table.append(out)
        if not key:
            mismatches.append(f"{name}: 참가격 지역 이름과 연결 못 함")
            continue
        o = regions[key]
        checks = [
            ("대관료 중간", out["대관료_중간(만원)"], o["rentalFee"]["median"]),
            ("대관료 평균", out["대관료_평균(만원)"], o["rentalFee"]["avg"]),
            ("대관료 하위10%", out["대관료_하위10%(만원)"], o["rentalFee"]["p10"]),
            ("대관료 상위10%", out["대관료_상위10%(만원)"], o["rentalFee"]["p90"]),
            ("1인당 식대 중간", out["1인당식대_중간(만원)"], o["mealPerGuest"]["median"]),
            ("최소보증인원 중간", out["최소보증인원_중간(명)"], o["minGuests"]["median"]),
            ("기본장식비 평균", out["기본장식비_평균(만원)"], o["basicDecoration"]["avg"]),
            ("기본장식비 상위10%", out["기본장식비_상위10%(만원)"], o["basicDecoration"]["p90"]),
        ]
        group = addons.get(o["addOnGroup"], {})
        checks.append(("생화꽃장식 평균", out["생화꽃장식_평균(만원)"], group.get("생화꽃장식", {}).get("avg")))
        for label, item in ADDON_ITEMS:
            checks.append((label + " 중간", out[label + "_중간(만원)"], group.get(item, {}).get("median")))
        for label, mine, theirs in checks:
            if mine == "" or theirs is None or float(mine) != float(theirs):
                mismatches.append(f"{name} {label}: 파일 {mine} / 참가격 {theirs}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    csv_path = OUT_DIR / "private_venue_benchmark_clean_2026-11-22.csv"
    with csv_path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(table[0].keys()))
        w.writeheader()
        w.writerows(table)

    md = [
        "# 사설(일반) 예식장 벤치마크 가공·검증 (2026-11-22)",
        "",
        f"- 원본: `{Path(xlsx).name}` (사용자 제공, 시트 1개 · 지역 {len(table)}개)",
        "- 대조 기준: 한국소비자원 참가격 결혼서비스 예식장 가격정보 2026년 9월 조사 (앱 내 브라우저로 공식 페이지에서 읽은 값)",
        f"- 수집일: {COLLECTED}",
        f"- 가공 결과: `{csv_path.relative_to(ROOT).as_posix()}` (열 {len(table[0])}개)",
        "",
        "## 대조 결과",
        f"- 비교한 숫자: 지역마다 대관료 4개·식대·보증인원·기본장식비 2개·추가금 6개 = {len(table) * 14}개",
        f"- 다른 값: **{len(mismatches)}개**",
    ]
    md += [f"  - {x}" for x in mismatches] if mismatches else ["  - 없음 (모두 참가격 공식 값과 같음)"]
    md += [
        "",
        "## 가공하면서 고친 점",
        "- '대관_추가금_특이사항' 한 칸에 섞여 있던 기본장식비·추가금·포함 지역을 각각 열로 나눔",
        "- 원 단위를 만원으로, 지역명을 참가격 지역 키로 맞춤",
        "- 선택 추가금은 참가격이 권역 7개(서울·경인·4대 광역시·통합특별시·이외 지역 등)로만 공표 → '추가금_공표권역' 열로 표시",
        "",
        "## 쓰지 않은 정보",
        "- '전국 예식장 68.3% 계약 후 최소보증인원 하향 불가' 문구: 참가격 공식 페이지에서 확인되지 않음. "
        "참가격의 68.3%는 강원도 계약금 중 식대 비중, 보도의 68.3%는 결혼 서비스 민원 중 계약 해지·불이행 비율로 다른 뜻이라 앱에 쓰지 않음",
        "",
        "## 앱 반영",
        "- 서울(강남) = 강남3구(강남·서초·송파): 앱이 강남구만 강남 값으로 보던 것을 서초·송파까지 넓힘",
        "- 공공 vs 일반 예식장 비교 표에 '자주 붙는 추가금'(생화 꽃장식·본식 촬영) 줄과 기본 장식비 안내 추가",
    ]
    md_path = OUT_DIR / "private_venue_benchmark_check_2026-11-22.md"
    md_path.write_text("\n".join(md) + "\n", encoding="utf-8")
    print(csv_path)
    print(md_path)
    print("mismatches", len(mismatches))
    for x in mismatches:
        print(" ", x)


if __name__ == "__main__":
    main(sys.argv[1])
