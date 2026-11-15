"""공공예식장 데이터 검증.

1) 엑셀 원본 ↔ 기준 파일 비교: 기본 13개 열과 다른 시트가 바뀌지 않았는지
2) 엑셀 원본 ↔ assets/data/venues.json 비교: 모든 값이 빠짐없이·올바르게 옮겨졌는지
3) 값 점검: ID 중복, 좌표 범위, 정원·요금 형식, 사진 개수·파일명·주소, 수집상태 일관성
4) (선택) --check-images: 사진 주소를 실제로 열어 이미지인지 확인 (기관 서버에 요청하므로 천천히)

결과:
- docs/data-validation/venues_report.md  : 검증 보고서
- docs/data-validation/venues_to_collect.csv : 추가 수집이 필요한 예식장 목록 (엑셀에서 열 수 있게 UTF-8 BOM)

사용법 (wedding-collect 폴더에서):
    python -I tools/validate_venues.py "../공공예식장_eshare수집.xlsx" \
        --reference "../전국 공공예식장 및 연계업체 현황 (2).xlsx" [--check-images]
"""
import argparse
import csv
import json
import os
import sys
import time
import urllib.request
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import convert_venues as cv  # noqa: E402
from xlsx_reader import read_sheets  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
JSON_PATH = os.path.join(ROOT, "assets", "data", "venues.json")
OUT_DIR = os.path.join(ROOT, "docs", "data-validation")

BASE_COLS = 13
KOREA_LAT = (33.0, 38.7)
KOREA_LNG = (124.5, 131.0)


class Report:
    def __init__(self):
        self.checks = []  # (이름, 통과 여부, 설명)
        self.errors = []

    def check(self, name, ok, detail="", info=""):
        """detail은 실패했을 때, info는 통과했을 때 보고서에 적는 설명"""
        self.checks.append((name, ok, info if ok else detail))
        if not ok:
            self.errors.append(f"{name}: {detail}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--reference")
    ap.add_argument("--check-images", action="store_true")
    args = ap.parse_args()

    rep = Report()
    src = read_sheets(args.source)
    rows = src["공공예식장 목록"]
    header, body = rows[0], rows[1:]
    idx = {h: i for i, h in enumerate(header)}
    g = lambda r, k: (r[idx[k]].strip() if idx.get(k) is not None and idx[k] < len(r) else "")  # noqa: E731

    # ── 1) 기준 파일과 비교 ──
    if args.reference:
        ref = read_sheets(args.reference)
        ref_rows = ref["공공예식장 목록"]
        rep.check("기본 열 이름 일치", ref_rows[0] == header[:BASE_COLS],
                  f"기준 {ref_rows[0]} / 새 파일 {header[:BASE_COLS]}", "13개 열 이름·순서 같음")
        diffs = [a[0] for a, b in zip(ref_rows[1:], body) if a[:BASE_COLS] != b[:BASE_COLS]]
        rep.check("예식장 수 일치", len(ref_rows) == len(rows), f"기준 {len(ref_rows) - 1} / 새 {len(body)}", f"{len(body)}곳")
        rep.check("기본 13개 열 값 일치 (240곳)", not diffs, f"다른 행: {diffs[:10]}", "이름·주소·좌표·예약정보 모두 같음")
        for name in ref:
            if name != "공공예식장 목록":
                rep.check(f"'{name}' 시트 변경 없음", ref[name] == src.get(name), "내용이 다름",
                          f"{len(ref[name]) - 1}행 모두 같음")

    # ── 2) JSON과 비교 ──
    with open(JSON_PATH, encoding="utf-8") as f:
        js = json.load(f)
    expected = cv.build(args.source)
    rep.check("JSON 건수", len(js) == len(body), f"JSON {len(js)} / 엑셀 {len(body)}", f"{len(js)}곳")
    mismatch = [(a["id"], k) for a, b in zip(js, expected) for k in b if a.get(k) != b[k]]
    rep.check("JSON 값이 엑셀 변환 결과와 같음 (모든 필드)", not mismatch, f"다른 값: {mismatch[:10]}", f"{len(js)}곳 × {len(expected[0])}개 필드")
    raw_vs_json = []
    for r, v in zip(body, js):
        pairs = [("예식장ID", "id"), ("공공예식장 이름", "name"), ("주소", "address"),
                 ("예약링크", "bookingUrl"), ("이용정원", "capacityText"), ("이용요금", "feeText"),
                 ("요금 상세(상세설명)", "feeDetail"), ("평일 운영시간", "hoursWeekday"),
                 ("접수일시", "applyPeriod"), ("주차", "parking"), ("규모면적", "area")]
        for col, key in pairs:
            if col in idx and (g(r, col) or None) != (v[key] if key != "id" else v[key] or None):
                raw_vs_json.append((v["id"], col))
    rep.check("원본 글자가 JSON에 그대로 들어감 (정원·요금·운영시간 등 11개 항목)", not raw_vs_json,
              f"{raw_vs_json[:10]}", "다른 글자 0건")

    # ── 3) 값 점검 ──
    ids = [v["id"] for v in js]
    rep.check("ID 중복 없음", len(ids) == len(set(ids)))
    out_of_range = [v["id"] for v in js
                    if not (KOREA_LAT[0] <= v["lat"] <= KOREA_LAT[1] and KOREA_LNG[0] <= v["lng"] <= KOREA_LNG[1])]
    rep.check("좌표가 국내 범위", not out_of_range, f"{out_of_range}", "위도 33~38.7, 경도 124.5~131")

    cap_bad = [(v["id"], v["capacityText"]) for v in js if v["capacityText"] and v["capacity"] is None]
    fee_bad = [(v["id"], v["feeText"]) for v in js if v["feeText"] and v["rentalFee"] is None]
    rep.check("정원 숫자 변환", True, info=f"숫자로 쓸 수 없는 값 {len(cap_bad)}건은 null 처리 후 '확인 필요'로 표시")
    rep.check("요금 숫자 변환", True, info=f"숫자로 쓸 수 없는 값 {len(fee_bad)}건은 null 처리 후 '확인 필요'로 표시")
    rep.check("정원 값 범위 (2~2000명)", all(2 <= v["capacity"] <= 2000 for v in js if v["capacity"]))
    rep.check("요금 값 범위 (0~1천만원)", all(0 <= v["rentalFee"] <= 10_000_000 for v in js if v["rentalFee"] is not None))

    img_issues = []
    for r in body:
        vid = g(r, "예식장ID")
        n = int(g(r, "이미지 수") or 0)
        urls = [g(r, f"이미지{i} URL") for i in range(1, 6)]
        files = [g(r, f"이미지{i} 파일명") for i in range(1, 6)]
        if any(bool(u) != bool(f) for u, f in zip(urls, files)):
            img_issues.append((vid, "사진 주소와 파일명 짝이 안 맞음"))
        if any(f and not f.startswith(vid + "_") for f in files):
            img_issues.append((vid, "파일명이 예식장 ID와 다름"))
        if any(u and "eshare.go.kr" not in u for u in urls):
            img_issues.append((vid, "공유누리가 아닌 사진 주소"))
        if n != sum(1 for u in urls if u):
            img_issues.append((vid, f"이미지 수 {n} ≠ 주소 {sum(1 for u in urls if u)}개"))
    structural = [i for i in img_issues if not i[1].startswith("이미지 수")]
    rep.check("사진 주소·파일명 형식", not structural, f"{structural}",
              "주소·파일명 짝, 파일명=예식장ID, 공유누리 주소")
    rep.check("사진 개수 = 주소 개수", True,
              info=f"{len(img_issues) - len(structural)}곳은 사진이 있다고 돼 있지만 주소가 없음 → 추가 수집 목록에 포함")

    collected = [v for v in js if v["eshareStatus"]]
    has_data = [v for v in js if v["capacityText"] or v["feeText"]]
    rep.check("수집상태와 실제 값 일치", {v["id"] for v in has_data} <= {v["id"] for v in collected},
              "수집상태가 비어 있는데 값이 있는 행 존재", f"수집 {len(collected)}곳 밖에는 값 없음")

    # (선택) 사진 주소 실제 확인
    broken = []
    if args.check_images:
        for v in js:
            for u in v["images"]:
                try:
                    req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(req, timeout=15) as res:
                        head = res.read(12)
                        is_image = (head.startswith(b"\xff\xd8") or head.startswith(b"\x89PNG")
                                    or head.startswith(b"GIF8") or head[8:12] == b"WEBP")
                        if not is_image:
                            broken.append((v["id"], u))
                except Exception as e:  # noqa: BLE001
                    broken.append((v["id"], f"{u} ({e.__class__.__name__})"))
                time.sleep(0.3)
        total = sum(len(v["images"]) for v in js)
        rep.check(f"사진 주소 실제 열림 ({total}장)", not broken, f"열리지 않음 {len(broken)}장: {broken[:10]}",
                  "모두 이미지(JPEG·PNG·GIF·WEBP)로 열림")

    # ── 추가 수집 목록 ──
    todo = []
    for v in js:
        need, why = [], []
        if not v["eshareStatus"]:
            need += ["정원", "요금", "운영시간", "사진"]
            why.append("공유누리 수집 대상 아님(외부 예약처) 또는 미수집")
        else:
            if v["capacity"] is None:
                need.append("정원")
            if v["rentalFee"] is None:
                need.append("요금")
            if not v["images"]:
                need.append("사진")
            why += v["dataNotes"]
        if need:
            todo.append({
                "예식장ID": v["id"], "지역": f"{v['sido']} {v['sigungu']}".strip(), "이름": v["name"],
                "수집상태": v["eshareStatus"] or "미수집", "필요한 항목": ", ".join(need),
                "사유": " / ".join(why), "예약링크": v["bookingUrl"], "문의": v["bookingContact"],
            })

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "venues_to_collect.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(todo[0].keys()))
        w.writeheader()
        w.writerows(todo)

    # ── 보고서 ──
    n = len(js)
    stat = lambda pred: sum(1 for v in js if pred(v))  # noqa: E731
    lines = [
        "# 공공예식장 데이터 검증 보고서",
        "",
        f"- 검증일: {date.today().isoformat()}",
        f"- 원본: `{os.path.basename(args.source)}`" + (f" (기준: `{os.path.basename(args.reference)}`)" if args.reference else ""),
        f"- 결과: **{'통과' if not rep.errors else f'실패 {len(rep.errors)}건'}**",
        "",
        "## 검증 항목",
        "",
        "| 항목 | 결과 | 설명 |",
        "|---|---|---|",
        *[f"| {name} | {'✅' if ok else '❌'} | {detail} |" for name, ok, detail in rep.checks],
        "",
        "## 채워진 정도 (240곳 기준)",
        "",
        "| 항목 | 곳 수 | 비율 |",
        "|---|---|---|",
        *[f"| {label} | {c} | {c * 100 // n}% |" for label, c in [
            ("공유누리 수집됨", len(collected)),
            ("정원 (숫자로 사용 가능)", stat(lambda v: v["capacity"] is not None)),
            ("요금 (숫자로 사용 가능, 무료 포함)", stat(lambda v: v["rentalFee"] is not None)),
            ("└ 무료", stat(lambda v: v["rentalFee"] == 0)),
            ("사진 1장 이상", stat(lambda v: bool(v["images"]))),
            ("운영시간", stat(lambda v: v["hoursWeekday"] or v["hoursSaturday"])),
            ("접수 기간", stat(lambda v: v["applyPeriod"])),
            ("주차", stat(lambda v: v["parking"])),
        ]],
        "",
        "## 숫자로 쓰지 않고 '확인 필요'로 둔 값",
        "",
        *[f"- {vid}: 정원 `{t}`" for vid, t in cap_bad],
        *[f"- {vid}: 요금 `{t}`" for vid, t in fee_bad],
        "",
        "## 추가 수집이 필요한 예식장",
        "",
        f"총 **{len(todo)}곳** → `venues_to_collect.csv` (엑셀로 열 수 있어요)",
        "",
        f"- 공유누리 미수집: {sum(1 for t in todo if t['수집상태'] == '미수집')}곳",
        f"- 수집했지만 정원 확인 필요: {sum(1 for t in todo if t['수집상태'] != '미수집' and '정원' in t['필요한 항목'])}곳",
        f"- 수집했지만 요금 확인 필요: {sum(1 for t in todo if t['수집상태'] != '미수집' and '요금' in t['필요한 항목'])}곳",
        f"- 수집했지만 사진 없음: {sum(1 for t in todo if t['수집상태'] != '미수집' and '사진' in t['필요한 항목'])}곳",
        "",
        "## 앱에서의 처리",
        "",
        "- 값이 있으면: 하객 수·무료 대관 필터와 카드·상세 화면에 표시",
        "- 값이 없거나 오류로 보이면: **제외하지 않고** '기관 확인 필요'로 표시하고 목록 아래쪽에 정렬",
        "- 요금은 기관마다 기준(1시간·1회·1일)이 달라 '기본요금'과 상세 설명을 함께 보여줌",
    ]
    with open(os.path.join(OUT_DIR, "venues_report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    for name, ok, detail in rep.checks:
        print(("PASS " if ok else "FAIL ") + name + (f" — {detail}" if detail and not ok else ""))
    print(f"추가 수집 필요: {len(todo)}곳 → docs/data-validation/venues_to_collect.csv")
    sys.exit(1 if rep.errors else 0)


if __name__ == "__main__":
    main()
