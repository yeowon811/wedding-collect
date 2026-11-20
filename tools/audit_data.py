"""앱 데이터 점검 (2026-11-20): assets/data/*.json 의 값끼리 맞지 않는 곳·빈 값·형식 오류를 찾는다.

사용: python -I tools/audit_data.py [--out docs/data-validation/audit_2026-11-20.md]
값을 고치지 않는다 (데이터는 실제 수집 값만 유지). 결과는 사람이 확인할 목록.
"""
import argparse
import json
import math
import re
import sys
from collections import Counter, defaultdict

D = 'assets/data/'


def load(name):
    with open(D + name + '.json', encoding='utf-8') as f:
        return json.load(f)


def region_lists():
    src = open('lib/core/utils/region.dart', encoding='utf-8').read()
    sidos = re.findall(r"'([^']+)'", re.search(r'const kSidoList = \[(.*?)\];', src, re.S).group(1))
    body = re.search(r'const kSigunguBySido = <String, List<String>>\{(.*?)\n\};', src, re.S).group(1)
    by = {}
    for m in re.finditer(r"'([^']+)':\s*\[(.*?)\]", body, re.S):
        by[m.group(1)] = re.findall(r"'([^']+)'", m.group(2))
    return sidos, by


def km(a, b, c, d):
    r = 6371
    p1, p2 = math.radians(a), math.radians(c)
    dp, dl = math.radians(c - a), math.radians(d - b)
    x = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(min(1, math.sqrt(x)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out')
    a = ap.parse_args()
    sidos, towns = region_lists()
    out = ['# 앱 데이터 점검 (2026-11-20)', '', '`python -I tools/audit_data.py` 결과. 값은 고치지 않았다(실제 수집 값만). '
           '"앱 버그"는 코드로 고친 것, "데이터 확인"은 원본(엑셀·사이트)을 사람이 확인해야 하는 것.', '']

    def sec(title, items, limit=40):
        out.append(f'## {title} ({len(items)})')
        out.extend(f'- {x}' for x in items[:limit])
        if len(items) > limit:
            out.append(f'- … 외 {len(items) - limit}건')
        if not items:
            out.append('- 없음')
        out.append('')

    # ── 예식장 ──
    venues = load('venues')
    ids = Counter(v['id'] for v in venues)
    vprob = []
    vprob += [f'id 중복 {i}' for i, n in ids.items() if n > 1]
    by_sido = defaultdict(list)
    for v in venues:
        by_sido[v['sido']].append(v)
        merged = v['sido'] == '광주·전남'  # 2026 전남광주통합특별시: 앱은 sidoMatches로 광주·전남 둘 다에 맞춤
        if v['sido'] not in sidos and not merged:
            vprob.append(f"{v['id']} 시도 이름 '{v['sido']}'가 목록에 없음")
        elif v['sigungu'] and v['sigungu'] not in (towns.get('광주', []) + towns.get('전남', []) if merged else towns.get(v['sido'], [])):
            vprob.append(f"{v['id']} {v['name']}: 시군구 '{v['sigungu']}'가 {v['sido']} 목록에 없음")
        if not v['sigungu'] and v['sido'] != '세종':
            vprob.append(f"{v['id']} {v['name']}: 시군구 빈 값")
        if v['bookingType'] not in ('ONLINE', 'FORM', 'PHONE_VISIT', 'CENTER'):
            vprob.append(f"{v['id']} 예약 유형 코드 '{v['bookingType']}'")
        if not (v.get('bookingContact') or '').strip():
            vprob.append(f"{v['id']} {v['name']}: 문의처 없음")
        if not (v.get('bookingUrl') or '').startswith('http'):
            vprob.append(f"{v['id']} {v['name']}: 예약 링크 없음/형식 '{v.get('bookingUrl')}'")
        cap, cmin, fee = v.get('capacity'), v.get('capacityMin'), v.get('rentalFee')
        if cap is not None and cap <= 0:
            vprob.append(f"{v['id']} 정원 {cap}")
        if cap is not None and cmin is not None and cmin > cap:
            vprob.append(f"{v['id']} {v['name']}: 최소 인원 {cmin} > 정원 {cap}")
        if fee is not None and fee < 0:
            vprob.append(f"{v['id']} 대관료 {fee}")
        if not (33 < v['lat'] < 39 and 124 < v['lng'] < 132):
            vprob.append(f"{v['id']} {v['name']}: 좌표가 한국 밖 ({v['lat']}, {v['lng']})")
        addr = v.get('address') or ''
        full = v.get('sidoFull') or ''
        if addr and full and not addr.startswith(full[:2]) and v['sido'] not in addr[:6]:
            vprob.append(f"{v['id']} {v['name']}: 주소 '{addr[:30]}'가 시도 '{full}'로 시작하지 않음")
    # 좌표가 같은 시도 예식장들과 멀리 떨어진 곳 (시도·좌표 불일치 의심)
    far = []
    for s, vs in by_sido.items():
        if len(vs) < 3:
            continue
        lat = sorted(x['lat'] for x in vs)[len(vs) // 2]
        lng = sorted(x['lng'] for x in vs)[len(vs) // 2]
        for v in vs:
            d = km(lat, lng, v['lat'], v['lng'])
            limit = 60 if s in ('서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종') else 160
            if d > limit:
                far.append(f"{v['id']} {v['sido']} {v['sigungu']} {v['name']}: 시도 중심에서 {d:.0f}km")
    names = Counter(v['name'] for v in venues)
    dup_names = [f'{n} ×{c}' for n, c in names.items() if c > 1]
    empty = Counter()
    for v in venues:
        for k in ('capacity', 'rentalFee', 'parking', 'reception', 'target', 'applyPeriod'):
            if v.get(k) in (None, ''):
                empty[k] += 1
    sec('예식장: 형식·값 문제', vprob)
    sec('예식장: 좌표가 같은 시도의 다른 곳과 멀리 떨어짐 (시도·좌표 확인)', far)
    sec('예식장: 같은 이름 (다른 홀이면 정상)', dup_names)
    out.append('## 예식장: 빈 값 수 (240곳 중)')
    out.append(', '.join(f'{k} {n}' for k, n in empty.items()))
    out.append('')
    free_no_fee = [f"{v['id']} {v['name']}: 대관료 0인데 요금 원문 '{(v.get('feeText') or '')[:40]}'"
                   for v in venues if v.get('rentalFee') == 0 and v.get('feeText') and re.search(r'\d{2,},?\d{3}\s*원', v['feeText'])
                   and not re.search(r'무료', v['feeText'])]
    sec('예식장: 무료(0)인데 요금 원문에 금액이 있음', free_no_fee)

    # ── 예약 현황 ──
    bs = load('booking_status')
    vid = set(ids)
    bprob = []
    bv = bs['venues']
    items = bv.items() if isinstance(bv, dict) else [(x.get('venueId') or x.get('id'), x) for x in bv]
    nb = 0
    vmap = {v['id']: v for v in venues}
    for k, x in items:
        nb += 1
        if k not in vid:
            bprob.append(f'{k}: 예식장 목록에 없는 id')
            continue
        for m, codes in (x.get('months') or {}).items():
            bad = set(codes) - set('YAPBN.')
            if bad:
                bprob.append(f'{k} {m}: 모르는 글자 {bad}')
            y, mo = map(int, m.split('-'))
            days = (31 if mo in (1, 3, 5, 7, 8, 10, 12) else 30 if mo != 2 else (29 if y % 4 == 0 else 28))
            if len(codes) != days:
                bprob.append(f'{k} {m}: 날 수 {len(codes)} ≠ {days}')
        if vmap[k]['bookingType'] == 'PHONE_VISIT':  # 서울마이웨딩(FORM)은 달력이 있음
            bprob.append(f"{k} {vmap[k]['name']}: 예약 현황이 있는데 예약 유형이 {vmap[k]['bookingType']}")
    sec(f'예약 현황 ({nb}곳): 문제', bprob)

    # ── 정책 ──
    pol = load('policies')
    pprob = []
    pid = Counter(p['id'] for p in pol)
    pprob += [f'id 중복 {i}' for i, n in pid.items() if n > 1]
    cats = Counter(p['category'] for p in pol)
    for p in pol:
        if p['sido'] != '전국' and p['sido'] not in sidos:
            pprob.append(f"{p['id']} 시도 '{p['sido']}'")
        if p['sigungu'] and p['sigungu'] not in towns.get(p['sido'], []):
            pprob.append(f"{p['id']} {p['name']}: 시군구 '{p['sigungu']}'가 {p['sido']} 목록에 없음")
        if p.get('ageMin') and p.get('ageMax') and p['ageMin'] > p['ageMax']:
            pprob.append(f"{p['id']} 나이 {p['ageMin']}>{p['ageMax']}")
        if not (p.get('url') or '').startswith('http'):
            pprob.append(f"{p['id']} {p['name']}: 신청 링크 없음")
        if len((p.get('eligibility') or '').strip()) < 10:
            pprob.append(f"{p['id']} {p['name']}: 자격 원문이 거의 비어 있음")
        # 이름의 지역과 시도가 다른지 ([지역] 표기)
        m = re.match(r'^\[?([가-힣]+)[\]\s]', p['name'])
        if m and m.group(1) in sidos and p['sido'] not in (m.group(1), '전국'):
            pprob.append(f"{p['id']} {p['name']}: 이름의 '{m.group(1)}'와 시도 '{p['sido']}'가 다름")
        if p['category'].lower() == 'etc':
            pprob.append(f"{p['id']} {p['name']}: 분야 '기타' (분류 확인)")
    reviewed = sum(1 for p in pol if p.get('reviewed'))
    sec(f'정책 {len(pol)}건 (분야 {dict(cats)}, 사람 검수 {reviewed}건): 문제', pprob)

    # ── 실제 업체 ──
    ven = load('vendors')
    rprob = []
    for x in ven:
        if x['sido'] not in sidos:
            rprob.append(f"{x['id']} {x['name']}: 시도 '{x['sido']}'")
        if x.get('sigungu') and x['sido'] in towns and x['sigungu'] not in towns[x['sido']]:
            rprob.append(f"{x['id']} {x['name']}: 시군구 '{x['sigungu']}'")
        if not (x.get('phone') or '').strip():
            rprob.append(f"{x['id']} {x['name']}: 전화 없음")
        if re.match(r'01[016789]', (x.get('phone') or '').replace('-', '')):
            rprob.append(f"{x['id']} {x['name']}: 휴대폰 번호 (개인 번호일 수 있어 화면 노출 확인)")
        if not (x.get('url') or '').startswith('http'):
            rprob.append(f"{x['id']} {x['name']}: 홈페이지 없음")
        for k in ('price', 'priceMin', 'priceMax'):
            if k in x:
                rprob.append(f"{x['id']} 실제 업체에 가격 칸 '{k}' (규칙 위반)")
    sec(f'실제 연계 업체 {len(ven)}곳 (분류 {dict(Counter(x["category"] for x in ven))}): 문제', rprob)

    # ── 시연 업체 ──
    demo = load('demo_vendors')
    dprob = []
    combo = Counter((x['sido'], x['category']) for x in demo)
    if len(demo) != 561:
        dprob.append(f'건수 {len(demo)} ≠ 561')
    for (s, c), n in combo.items():
        if n != 3:
            dprob.append(f'{s} {c}: {n}곳')
    for x in demo:
        if not x['name'].startswith('[시연]'):
            dprob.append(f"{x['id']} 이름에 [시연] 없음")
        if x['priceMin'] > x['priceMax']:
            dprob.append(f"{x['id']} 가격 {x['priceMin']}>{x['priceMax']}")
        if not (0 <= x['rating'] <= 5):
            dprob.append(f"{x['id']} 평점 {x['rating']}")
    sec('시연 업체 (17 시도 × 11 항목 × 3): 문제', dprob)

    # ── 매칭·후기·단가 ──
    mt = load('venue_vendor_matches')
    venid = {x['id'] for x in ven}
    mprob = []
    total = 0
    for k, lst in mt.items():
        if k not in vid:
            mprob.append(f'매칭: 예식장 {k} 없음')
        for m in lst:
            total += 1
            v2 = m.get('vendorId') or m.get('id')
            if v2 not in venid:
                mprob.append(f'매칭: {k} → 업체 {v2} 없음')
            if (m.get('distanceKm') or 0) < 0:
                mprob.append(f'매칭: {k} 거리 음수')
    rv = load('venue_reviews')['venues']
    no_review = [i for i in vid if i not in rv]
    if no_review:
        mprob.append(f'후기 없는 예식장 {len(no_review)}곳')
    opts = load('wedding_options')
    for o in opts:
        if o['publicPrice'] < 0 or o['averagePrice'] < 0:
            mprob.append(f"단가 {o['id']} 음수")
        if o['averagePrice'] and o['publicPrice'] > o['averagePrice']:
            mprob.append(f"단가 {o['id']} {o['name']}: 공공·실속 {o['publicPrice']} > 일반 평균 {o['averagePrice']}")
    sec(f'매칭 {total}건 · 후기 {len(rv)}곳 · 단가 {len(opts)}개: 문제', mprob)

    text = '\n'.join(out)
    if a.out:
        open(a.out, 'w', encoding='utf-8').write(text)
        print('wrote', a.out)
    else:
        sys.stdout.reconfigure(encoding='utf-8')
        print(text)


if __name__ == '__main__':
    main()
