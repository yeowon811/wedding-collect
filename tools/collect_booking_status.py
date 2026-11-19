"""공공예식장 날짜별 예약 현황 수집 → assets/data/booking_status.json

- 공유누리(eshare.go.kr): 시설 상세 페이지의 예약 달력이 쓰는 공개 주소
  POST /UserPortal/Upv/{rsrc_no}/selectCpsResvExclShareCalendar.do (startDate, endDate)
  → 날짜마다 useYn(Y=예약 가능, N=예약 불가: 이미 예약됨·휴관·접수 기간 아님을 구분하지 않음)
  robots.txt 허용 경로. 예식장마다 1번 요청(이번 달 ~ 13개월 뒤), 요청 사이 1초 쉼.
- 서울마이웨딩(wedding.seoulwomen.or.kr): 달력 API(/wp-json/sknk/v1/calendar?facility_id=&year=&month=)가
  스크립트 요청을 막아(403) 앱 내 브라우저에서 시설 페이지를 연 채로 모은 결과(tools/raw/booking_seoul_compact.json,
  하루 한 글자)를 합친다. 칸의 초록 '오전/오후' = 공석(가능), 검은 '예약확정 ○'·회색 '예약불가' = 예약됨,
  빈칸 = 그날 예식 접수 없음. 시설 페이지에 달력이 없는 4곳(H091·H128·H149·H152)은 비워 둔다.
- 그 밖의 예식장(구글·네이버 폼, 전화, 기타 사이트)은 예약 현황이 공개되지 않아 비워 둔다 → 앱은 '사이트에서 확인'.

저장 형식(작게): 예식장마다 months = {"2026-11": "NNNY…"} — 그 달 1일부터 하루 한 글자
(Y 가능 / A 오전 공석 / P 오후 공석 / B 오전·오후 공석 / N 불가 / . 정보 없음).

결과는 수집 시점의 스냅샷이다. 앱은 확인 날짜와 출처를 함께 보여 주고, 실제 예약 전 사이트에서 다시 확인하라고 안내한다.

사용: python -I tools/collect_booking_status.py [--only H002,H003] [--skip-eshare]
"""
import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VENUES = ROOT / 'assets/data/venues.json'
SEOUL_RAW = ROOT / 'tools/raw/booking_seoul_compact.json'
# 서울마이웨딩 원본 글자: A 오전 공석 / P 오후 공석 / B 오전·오후 공석 / Y 공석(이름 없음) / N 예약됨 / . 빈칸
SEOUL_SLOTS = {'A': ['오전'], 'P': ['오후'], 'B': ['오전', '오후'], 'Y': []}
SLOT_CODE = {tuple(v): k for k, v in SEOUL_SLOTS.items()}
OUT = ROOT / 'assets/data/booking_status.json'

UA = 'Mozilla/5.0 (compatible; wedding-collect-data/1.0)'
ESHARE_CAL = 'https://www.eshare.go.kr/UserPortal/Upv/{rsrc}/selectCpsResvExclShareCalendar.do'
RSRC = re.compile(r'rsrc_no=([A-Z0-9]+)')
MONTHS_AHEAD = 13


def month_range(today: date) -> tuple[str, str]:
    start = today.replace(day=1)
    y, m = today.year, today.month + MONTHS_AHEAD
    y += (m - 1) // 12
    m = (m - 1) % 12 + 1
    nxt = date(y + (m // 12), m % 12 + 1, 1)
    last = date.fromordinal(nxt.toordinal() - 1)
    return start.isoformat(), last.isoformat()


def eshare_rsrc(v: dict) -> str | None:
    """온라인 예약 달력이 있는 공유누리 시설만 (간편예약·문의형은 달력이 없음)"""
    if v.get('bookingType') != 'ONLINE':
        return None
    for key in ('bookingUrl', 'detailUrl'):
        url = v.get(key) or ''
        if 'eshare.go.kr' in url:
            m = RSRC.search(url)
            if m:
                return m.group(1)
    return None


def fetch_eshare(rsrc: str, start: str, end: str) -> list[dict]:
    body = urllib.parse.urlencode({'startDate': start, 'endDate': end}).encode()
    req = urllib.request.Request(ESHARE_CAL.format(rsrc=rsrc), data=body, headers={
        'User-Agent': UA, 'X-Requested-With': 'XMLHttpRequest',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'})
    raw = urllib.request.urlopen(req, timeout=30).read()
    return json.loads(raw)


def eshare_entry(v: dict, rsrc: str, start: str, end: str, today: str) -> dict:
    days = fetch_eshare(rsrc, start, end)
    open_, closed = [], []
    for d in days:
        # 사이트 화면과 같게: 제외 안내(excelShareMsg)가 있는 날은 불가
        ok = d.get('useYn') == 'Y' and not (d.get('excelShareMsg') or '')
        (open_ if ok else closed).append(d['date'])
    return {
        'source': '공유누리',
        'sourceUrl': f'https://www.eshare.go.kr/UserPortal/Upv/UprResrcFacl/index.do?rsrc_no={rsrc}',
        'checkedAt': today,
        'from': start, 'to': end,
        'open': open_, 'closed': closed,
        'closedMeaning': '예약됨·휴관·접수 기간 아님 (사이트가 구분하지 않음)',
    }


def compact(e: dict) -> dict:
    """open/closed 날짜 목록 → 달마다 한 글자씩 (Y/N/.)"""
    start, end = date.fromisoformat(e['from']), date.fromisoformat(e['to'])
    opened, closed = set(e['open']), set(e['closed'])
    months: dict[str, list[str]] = {}
    d = start
    while d <= end:
        k = d.isoformat()
        slot = SLOT_CODE.get(tuple(e.get('slots', {}).get(k, ())), 'Y')
        months.setdefault(k[:7], []).append(slot if k in opened else 'N' if k in closed else '.')
        d = date.fromordinal(d.toordinal() + 1)
    out = {k: v for k, v in e.items() if k not in ('open', 'closed', 'from', 'to', 'slots')}
    out['months'] = {m: ''.join(c) for m, c in months.items()}
    return out


def expand(e: dict) -> dict:
    """저장된 압축 형식 → open/closed 목록 (이전 결과 재사용용)"""
    if 'months' not in e:
        return e
    open_, closed, slots = [], [], {}
    for m, s in e['months'].items():
        for i, c in enumerate(s):
            k = f'{m}-{i + 1:02d}'
            if c in SEOUL_SLOTS:
                open_.append(k)
                if SEOUL_SLOTS[c]:
                    slots[k] = SEOUL_SLOTS[c]
            elif c == 'N':
                closed.append(k)
    ms = sorted(e['months'])
    last = ms[-1]
    out = {k: v for k, v in e.items() if k != 'months'}
    out.update(open=open_, closed=closed, slots=slots, **{'from': f'{ms[0]}-01', 'to': f"{last}-{len(e['months'][last]):02d}"})
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', help='예식장 ID 쉼표 구분 (시험용)')
    ap.add_argument('--skip-eshare', action='store_true', help='기존 공유누리 결과를 유지하고 서울만 다시 합치기')
    args = ap.parse_args()

    venues = json.loads(VENUES.read_text(encoding='utf-8'))
    only = set(args.only.split(',')) if args.only else None
    today = date.today()
    start, end = month_range(today)

    old = json.loads(OUT.read_text(encoding='utf-8')) if OUT.exists() else {'venues': {}}
    old['venues'] = {k: expand(v) for k, v in old['venues'].items()}
    result: dict[str, dict] = {}
    failed: list[str] = []

    if args.skip_eshare:
        result.update({k: v for k, v in old['venues'].items() if v.get('source') == '공유누리'})
    else:
        targets = [(v, eshare_rsrc(v)) for v in venues]
        targets = [(v, r) for v, r in targets if r and (not only or v['id'] in only)]
        print(f'공유누리 {len(targets)}곳, {start} ~ {end}')
        for i, (v, rsrc) in enumerate(targets):
            try:
                result[v['id']] = eshare_entry(v, rsrc, start, end, today.isoformat())
                e = result[v['id']]
                print(f"  [{i + 1}/{len(targets)}] {v['id']} 가능 {len(e['open'])} / 불가 {len(e['closed'])}")
            except (urllib.error.URLError, ValueError, KeyError, TimeoutError) as ex:
                failed.append(v['id'])
                print(f"  [{i + 1}/{len(targets)}] {v['id']} 실패: {ex}", file=sys.stderr)
                if v['id'] in old['venues']:
                    result[v['id']] = old['venues'][v['id']]  # 이전 결과 유지 (확인 날짜는 예전 그대로)
            time.sleep(1)

    if SEOUL_RAW.exists():
        seoul = json.loads(SEOUL_RAW.read_text(encoding='utf-8'))
        ids = {v['id'] for v in venues}
        n = 0
        for vid, e in seoul['venues'].items():
            if vid in ids and (not only or vid in only):
                open_, closed, slots = [], [], {}
                for m, s in e['m'].items():
                    for i, c in enumerate(s):
                        d = f'{m}-{i + 1:02d}'
                        if c in SEOUL_SLOTS:
                            open_.append(d)
                            if SEOUL_SLOTS[c]:
                                slots[d] = SEOUL_SLOTS[c]
                        elif c == 'N':
                            closed.append(d)
                ms = sorted(e['m'])
                result[vid] = {
                    'source': '서울마이웨딩',
                    'sourceUrl': f"https://wedding.seoulwomen.or.kr/facilities/{e['u']}",
                    'checkedAt': seoul['checkedAt'],
                    'from': f'{ms[0]}-01', 'to': f"{ms[-1]}-{len(e['m'][ms[-1]]):02d}",
                    'open': open_, 'closed': closed, 'slots': slots,
                    'closedMeaning': '예약됨(예약확정·예약불가)',
                }
                n += 1
        print(f'서울마이웨딩 {n}곳 합침 (확인 {seoul["checkedAt"]})')

    out = {
        'collectedAt': today.isoformat(),
        'note': '수집 시점 스냅샷. 실제 예약 가능 여부는 각 사이트에서 다시 확인해야 함',
        'venues': {k: compact(result[k]) for k in sorted(result)},
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(f'→ {OUT.relative_to(ROOT)}: {len(result)}곳' + (f', 실패 {failed}' if failed else ''))


if __name__ == '__main__':
    main()
