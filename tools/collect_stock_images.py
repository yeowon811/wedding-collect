"""[시연] 가상 업체용 항목별 무료 사진 (Wikimedia Commons).

- 라이선스: CC0 · 공공 도메인 · CC BY · CC BY-SA만 (상업 이용 가능, 저작자·라이선스 표시)
  파일은 고치지 않고(가로 640px 축소본만) 앱에서 그대로 보여준다
- 1단계 `candidates <dir>`: 항목별 후보 → 눈으로 고르는 확인용 HTML
- 2단계 `pick <candidates.json> <항목>:<번호> ...`: 고른 사진의 주소·출처를 assets/data/stock_images.json 에 기록
  (파일은 받지 않고 앱이 위키미디어에서 불러옴, 소개서 출처 표에 그대로 옮김)

사용:
  python -I tools/collect_stock_images.py candidates <out_dir>
  python -I tools/collect_stock_images.py pick <out_dir>/candidates.json dress:0 dress:3 ...
"""
import html
import json
import re
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = 'wedding-collect-data/1.0 (hackathon demo app)'
API = 'https://commons.wikimedia.org/w/api.php'
OK_LICENSE = re.compile(r'^(CC0|Public domain|PD|CC BY(-SA)? \d\.\d)', re.I)

# 항목(VendorCategory.name) → 검색어
QUERIES = {
    'dress': ['wedding dress bride', 'bridal gown'],
    'makeup': ['bridal makeup', 'bride makeup artist'],
    'studio': ['wedding photography couple', 'wedding photoshoot bride groom'],
    'snap': ['wedding couple outdoor', 'bride groom park'],
    'video': ['wedding videographer', 'videographer camera'],
    'meal': ['wedding buffet', 'wedding banquet table'],
    'invitation': ['wedding invitation card', 'wedding invitations'],
    'props': ['bridal bouquet', 'wedding cake'],
    'suit': ['groom suit wedding', 'tuxedo'],
    'hanbok': ['hanbok', 'hanbok woman'],
    'parentMakeup': ['makeup brushes', 'makeup artist applying'],
}


def fetch(url: str) -> bytes:
    # 일시적인 거절(429 등)은 조금 기다렸다 다시
    for wait in (0, 30, 90, 180):
        time.sleep(wait)
        r = subprocess.run(['curl', '-sfL', '-A', UA, '--max-time', '60', url], capture_output=True)
        if r.returncode == 0:
            return r.stdout
    raise RuntimeError(f'요청 실패: {url}')


def plain(s: str | None) -> str:
    return re.sub(r'\s+', ' ', re.sub('<[^>]+>', '', html.unescape(s or ''))).strip()


def search(q: str) -> list[dict]:
    time.sleep(1)  # 위키미디어 API 예의: 천천히
    url = API + '?' + urllib.parse.urlencode({
        'action': 'query', 'format': 'json', 'generator': 'search', 'gsrnamespace': 6,
        'gsrsearch': f'{q} filetype:bitmap', 'gsrlimit': 20, 'prop': 'imageinfo',
        'iiprop': 'url|extmetadata|size', 'iiurlwidth': 640,
        'iiextmetadatafilter': 'LicenseShortName|Artist|LicenseUrl'})
    pages = json.loads(fetch(url)).get('query', {}).get('pages', {})
    rows = []
    for p in sorted(pages.values(), key=lambda p: p.get('index', 0)):
        ii = p['imageinfo'][0]
        m = ii.get('extmetadata', {})
        lic = plain(m.get('LicenseShortName', {}).get('value'))
        if not OK_LICENSE.match(lic) or ii.get('width', 0) < 600 or ii.get('height', 0) < 400:
            continue
        rows.append({'title': p['title'].removeprefix('File:'), 'license': lic,
                     'licenseUrl': m.get('LicenseUrl', {}).get('value'),
                     'creator': plain(m.get('Artist', {}).get('value'))[:80] or 'Unknown',
                     'source': ii['descriptionurl'], 'thumb': ii['thumburl']})
    return rows


def candidates(out_dir: str) -> None:
    out = {}
    for cat, qs in QUERIES.items():
        seen, rows = set(), []
        for q in qs:
            for r in search(q):
                if r['title'] not in seen:
                    seen.add(r['title'])
                    rows.append(r)
        out[cat] = rows[:24]
    Path(out_dir, 'candidates.json').write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding='utf-8')
    cells = []
    for cat, rows in out.items():
        cells.append(f'<h3>{cat}</h3><section>')
        for i, r in enumerate(rows):
            cells.append(f'<div><img src="{html.escape(r["thumb"])}"><b>{i}</b></div>')
        cells.append('</section>')
    Path(out_dir, 'index.html').write_text(
        '<meta charset=utf-8><style>body{margin:0;font:12px sans-serif}h3{margin:3px 4px;font-size:13px}'
        'section{display:grid;grid-template-columns:repeat(12,1fr);gap:2px}div{position:relative}'
        'img{width:100%;height:68px;object-fit:cover;display:block;background:#ddd}'
        'b{position:absolute;left:1px;top:1px;background:#fff;padding:0 2px}</style>' + ''.join(cells),
        encoding='utf-8')
    print({k: len(v) for k, v in out.items()})


def small(url: str, width: int = 500) -> str:
    """위키미디어 이미지 주소 → 가로 500px 축소본 주소 (카드·상세 화면에 충분, 앱 용량 절약)"""
    url = url.split('?')[0]
    m = re.match(r'https://(?:upload|thumb)\.wikimedia\.org/wikipedia/commons/thumb/(\w/\w\w)/([^/]+)/\d+px-', url)
    if m:
        return f'https://upload.wikimedia.org/wikipedia/commons/thumb/{m[1]}/{m[2]}/{width}px-{m[2]}'
    m = re.match(r'https://upload\.wikimedia\.org/wikipedia/commons/(\w/\w\w)/([^/]+)$', url)
    if m:  # 축소본 없이 원본만 준 경우
        return f'https://upload.wikimedia.org/wikipedia/commons/thumb/{m[1]}/{m[2]}/{width}px-{m[2]}'
    return url


def pick(cand_file: str, picks: list[str]) -> None:
    """고른 사진의 위키미디어 축소본 주소와 출처를 assets/data/stock_images.json 에 기록.
    파일은 내려받지 않고 앱이 위키미디어에서 직접 불러온다 (앱 용량 절약, 위키미디어는 직접 연결 허용)."""
    cand = json.loads(Path(cand_file).read_text(encoding='utf-8'))
    table = {}
    for p in picks:
        cat, idx = p.split(':')
        r = cand[cat][int(idx)]
        table.setdefault(cat, []).append({'url': r['thumb'].split('?')[0], **{
            k: r[k] for k in ('title', 'creator', 'license', 'licenseUrl', 'source')}})
    (ROOT / 'assets/data/stock_images.json').write_text(json.dumps(table, ensure_ascii=False, indent=1),
                                                        encoding='utf-8')
    print({k: len(v) for k, v in table.items()})


if __name__ == '__main__':
    if sys.argv[1] == 'candidates':
        candidates(sys.argv[2])
    else:
        pick(sys.argv[2], sys.argv[3:])
