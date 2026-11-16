"""공공예식장 데이터 검증.

1) 기준 파일 비교: 새 수집 파일의 기본 13개 열·다른 시트가 기존 데이터와 같은지
2) 추가 수집 파일(더아결 등) 비교: 대상 예식장·기본 13개 열이 기준과 같고, 다른 출처와 겹치지 않는지
3) 엑셀 원본 ↔ assets/data/venues.json: 모든 값이 빠짐없이·올바르게 옮겨졌는지 (출처별 원문 비교 포함)
4) 값 점검: ID 중복, 좌표, 정원·요금 범위, 사진 개수·파일명, AI 생성 이미지 표시, 협력업체 이름
5) (선택) --check-images: 사진 주소를 실제로 열어 이미지인지 확인 (기관 서버에 요청하므로 천천히)

결과:
- docs/data-validation/venues_report.md      : 검증 보고서
- docs/data-validation/venues_to_collect.csv : 추가 수집이 필요한 예식장 목록 (엑셀용 UTF-8 BOM)

사용법 (wedding-collect 폴더에서):
    python -I tools/validate_venues.py "../공공예식장_eshare수집.xlsx" \
        --supplement "../공공예식장_더아결수집.xlsx" --supplement "../공공예식장_나머지.xlsx" \
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
VENDORS_PATH = os.path.join(ROOT, "assets", "data", "vendors.json")
OUT_DIR = os.path.join(ROOT, "docs", "data-validation")

BASE_COLS = 13
KOREA_LAT = (33.0, 38.7)
KOREA_LNG = (124.5, 131.0)
THEAGYEOL = "서울마이웨딩(더아결)"


class Report:
    def __init__(self):
        self.checks = []  # (이름, 통과 여부, 설명)
        self.errors = []

    def check(self, name, ok, detail="", info=""):
        """detail은 실패했을 때, info는 통과했을 때 보고서에 적는 설명"""
        self.checks.append((name, ok, info if ok else detail))
        if not ok:
            self.errors.append(f"{name}: {detail}")


def sheet(path):
    rows = read_sheets(path)["공공예식장 목록"]
    idx = {h: i for i, h in enumerate(rows[0])}

    def g(r, k):
        i = idx.get(k)
        return r[i].strip() if i is not None and i < len(r) else ""
    return rows, g


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", help="기준 수집 파일 (240곳 전체, 공유누리 수집 열 포함)")
    ap.add_argument("--supplement", action="append", default=[], help="추가 수집 파일 (더아결 등)")
    ap.add_argument("--reference", help="비교할 기존 기준 파일")
    ap.add_argument("--check-images", action="store_true")
    args = ap.parse_args()

    rep = Report()
    src = read_sheets(args.source)
    rows, g = sheet(args.source)
    header, body = rows[0], rows[1:]
    base_by_id = {r[0]: r for r in body}

    # ── 1) 기준 파일과 비교 ──
    if args.reference:
        ref = read_sheets(args.reference)
        ref_rows = ref["공공예식장 목록"]
        rep.check("[기준] 기본 열 이름 일치", ref_rows[0] == header[:BASE_COLS],
                  f"기준 {ref_rows[0]} / 새 파일 {header[:BASE_COLS]}", "13개 열 이름·순서 같음")
        diffs = [a[0] for a, b in zip(ref_rows[1:], body) if a[:BASE_COLS] != b[:BASE_COLS]]
        rep.check("[기준] 예식장 수 일치", len(ref_rows) == len(rows),
                  f"기준 {len(ref_rows) - 1} / 새 {len(body)}", f"{len(body)}곳")
        rep.check("[기준] 기본 13개 열 값 일치", not diffs, f"다른 행: {diffs[:10]}",
                  "이름·주소·좌표·예약정보 모두 같음")
        for name in ref:
            if name != "공공예식장 목록":
                rep.check(f"[기준] '{name}' 시트 변경 없음", ref[name] == src.get(name), "내용이 다름",
                          f"{len(ref[name]) - 1}행 모두 같음")

    # ── 2) 추가 수집 파일 ──
    eshare_ids = {g(r, "예식장ID") for r in body if g(r, "eshare 수집상태")}
    done_ids = set(eshare_ids)  # 앞 파일들까지 수집된 예식장
    supp = []  # (종류, rows, g)
    for path in args.supplement:
        kind = cv.supplement_kind(path)
        srows, sg = sheet(path)
        supp.append((kind, srows, sg))
        name = os.path.basename(path)
        ids = [sg(r, "예식장ID") for r in srows[1:]]
        todo_ids = set(base_by_id) - done_ids
        rep.check(f"[{name}] 모든 ID가 기준 파일에 있음", set(ids) <= set(base_by_id),
                  f"없는 ID: {sorted(set(ids) - set(base_by_id))[:10]}", f"{len(ids)}곳")
        rep.check(f"[{name}] 앞 파일들에서 미수집인 예식장과 대상이 같음",
                  set(ids) == todo_ids,
                  f"차이: {sorted(set(ids) ^ todo_ids)[:10]}",
                  f"미수집 {len(todo_ids)}곳과 정확히 일치")
        bdiff = [r[0] for r in srows[1:] if r[:BASE_COLS] != base_by_id.get(r[0], [])[:BASE_COLS]]
        rep.check(f"[{name}] 기본 13개 열 값이 기준과 같음", not bdiff, f"다른 행: {bdiff[:10]}",
                  "이름·주소·좌표·예약정보 모두 같음")
        if kind == "theagyeol":
            collected = [r for r in srows[1:] if sg(r, "더아결 수집상태")]
        else:
            collected = [r for r in srows[1:] if sg(r, "수집상태") in cv.REST_COLLECTED]
        overlap = {sg(r, "예식장ID") for r in collected} & done_ids
        rep.check(f"[{name}] 앞 출처 수집분과 겹치지 않음", not overlap, f"겹침: {sorted(overlap)}",
                  f"수집 {len(collected)}곳, 겹침 0")
        done_ids |= {sg(r, "예식장ID") for r in collected}

        if kind == "rest":
            statuses = {}
            for r in srows[1:]:
                statuses[sg(r, "수집상태")] = statuses.get(sg(r, "수집상태"), 0) + 1
            unknown = [st for st in statuses if st not in cv.REST_COLLECTED | {"접근 차단", "접속 실패"}]
            rep.check(f"[{name}] 수집상태 값이 알려진 값", not unknown, f"모르는 값: {unknown}",
                      ", ".join(f"{k} {n}" for k, n in sorted(statuses.items(), key=lambda x: -x[1])))
            img_over = [sg(r, "예식장ID") for r in srows[1:]
                        if sum(1 for i in (1, 2) if sg(r, f"이미지{i} URL")) > int(sg(r, "사진 수(페이지 기준)") or 0)]
            rep.check(f"[{name}] 사진 주소 수 ≤ 페이지 사진 수", not img_over, f"{img_over}",
                      f"사진 주소 {sum(1 for r in srows[1:] for i in (1, 2) if sg(r, f'이미지{i} URL'))}장")
            continue

        img_bad, ai_bad = [], []
        for r in collected:
            vid = sg(r, "예식장ID")
            allu = [u for u in sg(r, "전체 이미지 URL").split("\n") if u.strip()]
            cols = [sg(r, f"이미지{i} URL") for i in range(1, 6)]
            files = [sg(r, f"이미지{i} 파일명") for i in range(1, 6)]
            if int(sg(r, "이미지 수") or 0) != len(allu):
                img_bad.append((vid, f"이미지 수 {sg(r, '이미지 수')} ≠ 전체 주소 {len(allu)}"))
            if [c for c in cols if c] != allu[:5]:
                img_bad.append((vid, "개별 열 5장이 전체 주소 앞 5장과 다름"))
            if any(bool(c) != bool(f) for c, f in zip(cols, files)) or any(
                    f and not f.startswith(vid + "_") for f in files):
                img_bad.append((vid, "주소·파일명 짝 또는 파일명 ID 불일치"))
            found_ai = sum(1 for u in allu if cv.is_ai_image(u))
            if found_ai != int(sg(r, "AI 생성 이미지 수") or 0):
                ai_bad.append((vid, f"표시 {sg(r, 'AI 생성 이미지 수')} / 파일명 판별 {found_ai}"))
        rep.check(f"[{name}] 사진 개수·순서·파일명", not img_bad, f"{img_bad[:10]}",
                  "이미지 수=전체 주소 수, 앞 5장=개별 열, 파일명=예식장ID")
        rep.check(f"[{name}] AI 생성 이미지 판별이 수집 파일 표시와 같음", not ai_bad, f"{ai_bad[:10]}",
                  f"{sum(int(sg(r, 'AI 생성 이미지 수') or 0) for r in collected)}장 모두 일치")

    # ── 3) JSON과 비교 ──
    with open(JSON_PATH, encoding="utf-8") as f:
        js = json.load(f)
    expected = cv.build_all(args.source, args.supplement)
    rep.check("[JSON] 건수", len(js) == len(body), f"JSON {len(js)} / 엑셀 {len(body)}", f"{len(js)}곳")
    mismatch = [(a["id"], k) for a, b in zip(js, expected) for k in b if a.get(k) != b[k]]
    rep.check("[JSON] 값이 엑셀 변환 결과와 같음 (모든 필드)", not mismatch, f"다른 값: {mismatch[:10]}",
              f"{len(js)}곳 × {len(expected[0])}개 필드")

    by_id = {v["id"]: v for v in js}
    raw_diff = []
    eshare_pairs = [("이용정원", "capacityText"), ("이용요금", "feeText"), ("요금 상세(상세설명)", "feeDetail"),
                    ("평일 운영시간", "hoursWeekday"), ("접수일시", "applyPeriod"), ("주차", "parking"),
                    ("규모면적", "area")]
    for r in body:
        v = by_id[g(r, "예식장ID")]
        if v["collectSource"] not in (None, "공유누리"):
            continue
        for col, key in eshare_pairs:
            if (g(r, col) or None) != v[key]:
                raw_diff.append((v["id"], col))
    the_pairs = [("수용인원", "capacityText"), ("대관료", "feeText"), ("주차", "parking"), ("피로연", "reception"),
                 ("예식가능일자(26년)", "availableDates2026"), ("예식불가일자(26년)", "unavailableDates2026"),
                 ("예식가능일자(27년)", "availableDates2027"), ("기타 안내", "extraInfo")]
    rest_pairs = [("정원", "capacityText"), ("요금", "feeText"), ("이용시간·예식 가능일", "hoursText"),
                  ("운영·이용기간", "operatingPeriod"), ("예약방법", "reservationInfo"), ("이용대상", "target"),
                  ("선별방법", "selection"), ("주차", "parking"), ("실내·외", "indoorOutdoor"), ("문의", "inquiry"),
                  ("기타 안내", "extraInfo"), ("공통 사업 안내", "programInfo")]
    for kind, srows, sg in supp:
        if kind == "rest":
            for r in srows[1:]:
                if sg(r, "수집상태") not in cv.REST_COLLECTED:
                    continue
                v = by_id[sg(r, "예식장ID")]
                for col, key in rest_pairs:
                    if (sg(r, col) or None) != v[key]:
                        raw_diff.append((v["id"], col))
                if [sg(r, f"이미지{i} URL") for i in (1, 2) if sg(r, f"이미지{i} URL")] != v["images"]:
                    raw_diff.append((v["id"], "이미지 URL"))
            continue
        for r in srows[1:]:
            if not sg(r, "더아결 수집상태"):
                continue
            v = by_id[sg(r, "예식장ID")]
            for col, key in the_pairs:
                if (sg(r, col) or None) != v[key]:
                    raw_diff.append((v["id"], col))
            if [u for u in sg(r, "전체 이미지 URL").split("\n") if u.strip()] != v["images"]:
                raw_diff.append((v["id"], "전체 이미지 URL"))
    rep.check("[JSON] 원본 글자가 그대로 들어감 (출처별 정원·요금·주차·피로연·예식일 등)", not raw_diff,
              f"{raw_diff[:10]}", "다른 글자 0건")

    # ── 4) 값 점검 ──
    ids = [v["id"] for v in js]
    rep.check("ID 중복 없음", len(ids) == len(set(ids)), "", f"{len(ids)}개")
    out_of_range = [v["id"] for v in js
                    if not (KOREA_LAT[0] <= v["lat"] <= KOREA_LAT[1] and KOREA_LNG[0] <= v["lng"] <= KOREA_LNG[1])]
    rep.check("좌표가 국내 범위", not out_of_range, f"{out_of_range}", "위도 33~38.7, 경도 124.5~131")
    cap_bad = [(v["id"], v["capacityText"]) for v in js if v["capacityText"] and v["capacity"] is None]
    fee_bad = [(v["id"], v["feeText"]) for v in js if v["feeText"] and v["rentalFee"] is None]
    rep.check("정원 숫자 변환", True, info=f"숫자로 쓸 수 없는 값 {len(cap_bad)}건은 null 처리 후 '확인 필요'로 표시")
    rep.check("요금 숫자 변환", True, info=f"숫자로 쓸 수 없는 값 {len(fee_bad)}건은 원문을 보여주고 '상세 참고'로 표시")
    rep.check("정원 값 범위 (2~2000명)", all(2 <= v["capacity"] <= 2000 for v in js if v["capacity"]), "", "통과")
    rep.check("정원 범위의 최소 ≤ 최대",
              all(v["capacityMin"] is None or v["capacityMin"] <= v["capacity"] for v in js), "", "통과")
    rep.check("요금 값 범위 (0~1천만원)",
              all(0 <= v["rentalFee"] <= 10_000_000 for v in js if v["rentalFee"] is not None), "", "통과")
    rep.check("AI 생성 이미지는 사진 목록 안에 있음",
              all(set(v["aiImages"]) <= set(v["images"]) for v in js), "", f"{sum(len(v['aiImages']) for v in js)}장")
    rep.check("수집상태가 없는 곳에는 값이 없음",
              all(v["collectStatus"] or not (v["capacityText"] or v["feeText"] or v["images"]) for v in js))

    with open(VENDORS_PATH, encoding="utf-8") as f:
        vendor_names = {v["name"] for v in json.load(f)}
    partners = [p for v in js for p in v["partnerVendors"]]
    matched = [p for p in partners if p in vendor_names]
    unmatched = sorted({p for p in partners if p not in vendor_names})
    rep.check("협력업체 이름 → 실제 업체 목록 연결", True,
              info=f"{len(partners)}건 중 {len(matched)}건 연결 (목록에 없는 업체 {len(unmatched)}곳은 이름만 표시)")

    # (선택) 사진 주소 실제 확인
    if args.check_images:
        broken = []
        urls = [(v["id"], u) for v in js for u in v["images"]]
        for vid, u in urls:
            try:
                req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=20) as res:
                    head = res.read(12)
                    if not (head.startswith(b"\xff\xd8") or head.startswith(b"\x89PNG")
                            or head.startswith(b"GIF8") or head[8:12] == b"WEBP"):
                        broken.append((vid, u))
            except Exception as e:  # noqa: BLE001
                broken.append((vid, f"{u} ({e.__class__.__name__})"))
            time.sleep(0.3)
        rep.check(f"사진 주소 실제 열림 ({len(urls)}장)", not broken, f"열리지 않음 {len(broken)}장: {broken[:10]}",
                  "모두 이미지(JPEG·PNG·GIF·WEBP)로 열림")

    # ── 추가 수집 목록 ──
    todo = []
    for v in js:
        need, why = [], []
        if not v["collectStatus"]:
            need += ["정원", "요금", "운영·예식 가능일", "사진"]
            why.append("공유누리·더아결·기관 페이지 모두 미수집")
            why += v["dataNotes"]
        else:
            if v["capacity"] is None:
                need.append("정원")
            if v["rentalFee"] is None and not v["feeText"]:
                need.append("요금")
            if not v["images"]:
                need.append("사진")
            elif len(v["aiImages"]) == len(v["images"]):
                need.append("실제 사진(현재 AI 생성 이미지만 있음)")
            why += v["dataNotes"]
        if need:
            todo.append({
                "예식장ID": v["id"], "지역": f"{v['sido']} {v['sigungu']}".strip(), "이름": v["name"],
                "수집출처": v["collectSource"] or "미수집", "필요한 항목": ", ".join(need),
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
    sources = {}
    for v in js:
        key = v["collectSource"] or "미수집"
        if key.startswith("기관 안내 페이지"):
            key = "기관 안내 페이지 (지자체·공공기관 사이트 직접 수집)"
        sources[key] = sources.get(key, 0) + 1
    files = [os.path.basename(args.source)] + [os.path.basename(p) for p in args.supplement]
    lines = [
        "# 공공예식장 데이터 검증 보고서",
        "",
        f"- 검증일: {date.today().isoformat()}",
        f"- 원본: {', '.join(f'`{x}`' for x in files)}"
        + (f" (기준: `{os.path.basename(args.reference)}`)" if args.reference else ""),
        f"- 결과: **{'통과' if not rep.errors else f'실패 {len(rep.errors)}건'}**",
        "",
        "## 검증 항목",
        "",
        "| 항목 | 결과 | 설명 |",
        "|---|---|---|",
        *[f"| {name} | {'✅' if ok else '❌'} | {detail} |" for name, ok, detail in rep.checks],
        "",
        "## 수집 출처 (240곳)",
        "",
        "| 출처 | 곳 수 |",
        "|---|---|",
        *[f"| {k} | {c} |" for k, c in sources.items()],
        "",
        "## 채워진 정도 (240곳 기준)",
        "",
        "| 항목 | 곳 수 | 비율 |",
        "|---|---|---|",
        *[f"| {label} | {c} | {c * 100 // n}% |" for label, c in [
            ("정원 (숫자로 사용 가능)", stat(lambda v: v["capacity"] is not None)),
            ("요금 (숫자로 사용 가능, 무료 포함)", stat(lambda v: v["rentalFee"] is not None)),
            ("└ 무료", stat(lambda v: v["rentalFee"] == 0)),
            ("사진 1장 이상", stat(lambda v: bool(v["images"]))),
            ("└ AI 생성 이미지 포함", stat(lambda v: bool(v["aiImages"]))),
            ("피로연 정보", stat(lambda v: v["reception"])),
            ("예식 가능일(26·27년)", stat(lambda v: v["availableDates2026"] or v["availableDates2027"])),
            ("주차", stat(lambda v: v["parking"])),
            ("지원 사업 공통 안내 (숲 결혼식·맺어드림 등)", stat(lambda v: v["programInfo"])),
        ]],
        "",
        "## 숫자로 쓰지 않고 원문·'확인 필요'로 둔 값",
        "",
        *[f"- {vid}: 정원 `{t}`" for vid, t in cap_bad],
        *[f"- {vid}: 요금 `{t}`" for vid, t in fee_bad],
        "",
        "## 협력업체 이름 중 실제 업체 목록에 없는 곳",
        "",
        ", ".join(unmatched) or "없음",
        "",
        "## 추가 수집이 필요한 예식장",
        "",
        f"총 **{len(todo)}곳** → `venues_to_collect.csv` (엑셀로 열 수 있어요)",
        "",
        f"- 아직 아무 출처에서도 수집 안 됨: {sum(1 for t in todo if t['수집출처'] == '미수집')}곳",
        f"- 수집했지만 정원 확인 필요: {sum(1 for t in todo if t['수집출처'] != '미수집' and '정원' in t['필요한 항목'])}곳",
        f"- 수집했지만 사진 없음·AI 이미지만 있음: "
        f"{sum(1 for t in todo if t['수집출처'] != '미수집' and '사진' in t['필요한 항목'])}곳",
        "",
        "## 앱에서의 처리",
        "",
        "- 값이 있으면: 하객 수·무료 대관 필터와 카드·상세 화면에 표시",
        "- 값이 없거나 오류로 보이면: **제외하지 않고** '기관 확인 필요'로 표시하고 목록 아래쪽에 정렬",
        "- 정원이 범위(예: 100명~200명)면 최대값으로 하객 수 수용 여부를 판단하고 범위를 함께 표시",
        "- **AI 생성 이미지는 'AI 생성 이미지' 표시**를 붙이고, 목록 카드 대표 사진으로는 실제 사진을 먼저 씀",
    ]
    with open(os.path.join(OUT_DIR, "venues_report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    for name, ok, detail in rep.checks:
        print(("PASS " if ok else "FAIL ") + name + (f" — {detail}" if not ok else ""))
    print(f"추가 수집 필요: {len(todo)}곳 → docs/data-validation/venues_to_collect.csv")
    sys.exit(1 if rep.errors else 0)


if __name__ == "__main__":
    main()
