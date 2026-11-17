"""실제 연계업체 대표 이미지 수집.

업체 홈페이지의 대표 이미지(og:image / twitter:image)를 찾아 주소만 기록한다.
- 이미지 파일은 저장소에 복사하지 않고, 앱이 원래 주소에서 불러온다 (출처 페이지를 함께 표시)
- 인스타그램·링크 모음 등 로그인/대표 이미지가 없는 곳은 비워 둔다 → 앱은 항목 아이콘
- 같은 홈페이지(예: 여러 지점)는 같은 이미지를 쓴다

사용: python -I tools/collect_vendor_images.py   → assets/data/vendor_images.json
"""
import html
import json
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VENDORS = ROOT / 'assets/data/vendors.json'
OUT = ROOT / 'assets/data/vendor_images.json'

UA = 'Mozilla/5.0 (compatible; wedding-collect-data/1.0)'
SKIP_HOSTS = ('instagram.com', 'linktr.ee', 'blog.naver.com', 'band.us', 'pf.kakao.com')
META = re.compile(
    r'<meta[^>]+(?:property|name)\s*=\s*["\'](?:og:image(?::secure_url)?|twitter:image)["\'][^>]*>', re.I)
CONTENT = re.compile(r'content\s*=\s*["\']([^"\']+)["\']', re.I)
# 사람이 눈으로 검수해 뺀 이미지 (2026-11-17): 대표 사진이 아닌 안내·광고·깨진 이미지
REVIEW_EXCLUDE = {
    'V001': '사이트 템플릿 안내 이미지', 'V015': '이미지가 열리지 않음', 'V027': '이미지가 열리지 않음',
    'V016': '이벤트 광고 배너', 'V048': '박람회 광고 배너', 'V059': '영업시간 안내 공지',
    'V070': '홍보 문구 배너', 'V085': '홍보 문구 배너',
    'V009': '로고가 잘려 알아볼 수 없음', 'V051': '로고가 잘려 알아볼 수 없음', 'V052': '로고가 잘려 알아볼 수 없음',
}
BAD = re.compile(r'(logo|favicon|icon|blank|default|noimage|no_image|kakao|naver)', re.I)


def fetch(url: str, limit: int = 600_000) -> tuple[str, str]:
    ctx = ssl.create_default_context()
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'ko'})
    try:
        r = urllib.request.urlopen(req, timeout=12, context=ctx)
    except (ssl.SSLError, urllib.error.URLError):
        ctx = ssl._create_unverified_context()  # 인증서가 깨진 업체 사이트 (읽기만 함)
        r = urllib.request.urlopen(req, timeout=12, context=ctx)
    raw = r.read(limit)
    enc = r.headers.get_content_charset() or 'utf-8'
    return r.geturl(), raw.decode(enc, errors='replace')


IMG = re.compile(r'''<img[^>]+?(?:data-src|src)\s*=\s*["']([^"']+\.(?:jpe?g|png|webp)(?:\?[^"']*)?)["']''', re.I)


def image_ok(url: str, min_bytes: int = 0) -> bool:
    """이미지 주소가 실제로 열리고 이미지인지, 필요하면 최소 크기(로고·아이콘 거르기)"""
    try:
        req = urllib.request.Request(url, headers={'User-Agent': UA, 'Range': 'bytes=0-2048'})
        r = urllib.request.urlopen(req, timeout=12, context=ssl._create_unverified_context())
        if not r.headers.get_content_type().startswith('image/'):
            return False
        if min_bytes:
            total = (r.headers.get('Content-Range') or '').rpartition('/')[2] or r.headers.get('Content-Length') or '0'
            return total.isdigit() and int(total) >= min_bytes
        return True
    except Exception:
        return False


def find_image(site: str) -> tuple[str | None, str]:
    host = urllib.parse.urlparse(site).netloc.lower()
    if any(h in host for h in SKIP_HOSTS):
        return None, '대표 이미지를 가져올 수 없는 페이지(SNS·링크 모음)'
    try:
        final, page = fetch(site)
    except Exception as e:
        return None, f'접속 실패 ({type(e).__name__})'
    for tag in META.findall(page):
        m = CONTENT.search(tag)
        if not m:
            continue
        img = urllib.parse.urljoin(final, html.unescape(m.group(1).strip()))
        if img.startswith('http://'):
            img = 'https://' + img[len('http://'):]  # 앱(https)에서 섞인 콘텐츠 차단 방지
        if BAD.search(urllib.parse.urlparse(img).path):
            continue
        if image_ok(img):
            return img, 'og:image'
    # 대표 이미지 지정이 없으면 본문의 첫 큰 사진 (40KB 이상, 로고·아이콘 제외)
    for src in IMG.findall(page)[:25]:
        img = urllib.parse.urljoin(final, html.unescape(src.strip()))
        if img.startswith('http://'):
            img = 'https://' + img[len('http://'):]
        if BAD.search(urllib.parse.urlparse(img).path):
            continue
        if image_ok(img, min_bytes=40_000):
            return img, '본문 첫 사진'
    return None, '홈페이지에 쓸 만한 사진이 없음'


SUBLINK = re.compile(r'''<a[^>]+href\s*=\s*["']([^"'#]+)["'][^>]*>(.*?)</a>''', re.I | re.S)
SUBWORD = re.compile(r'(gallery|portfolio|wedding|photo|work|sample|review|menu|story|collection|'
                     r'갤러리|포트폴리오|웨딩|사진|작품|후기|메뉴|촬영|드레스|스냅|본식|상품)', re.I)


# 하위 페이지 사진 중 검수에서 뺀 업체 (2026-11-17)
DEEP_EXCLUDE = {
    'V015': '이미지가 열리지 않음', 'V027': '이미지가 열리지 않음', 'V048': '행사장 사진(업체와 무관)',
    'V051': '광고 배너', 'V052': '광고 배너', 'V059': '수상 배지 이미지',
}


def find_deep(site: str, skip: set[str]) -> tuple[str | None, str]:
    """홈페이지 첫 화면에 사진이 없을 때: 갤러리·포트폴리오 같은 하위 페이지(최대 6개)의 첫 큰 사진"""
    host = urllib.parse.urlparse(site).netloc.lower()
    if any(h in host for h in SKIP_HOSTS):
        return None, '대표 이미지를 가져올 수 없는 페이지(SNS·링크 모음)'
    try:
        final, page = fetch(site)
    except Exception as e:
        return None, f'접속 실패 ({type(e).__name__})'
    base = urllib.parse.urlparse(final).netloc
    links = []
    for href, text in SUBLINK.findall(page):
        url = urllib.parse.urljoin(final, html.unescape(href.strip()))
        if urllib.parse.urlparse(url).netloc != base or url in links or url.rstrip('/') == final.rstrip('/'):
            continue
        if SUBWORD.search(href) or SUBWORD.search(re.sub('<[^>]+>', '', text)):
            links.append(url)
    for url in links[:6]:
        try:
            _, sub = fetch(url)
        except Exception:
            continue
        for src in IMG.findall(sub)[:30]:
            img = urllib.parse.urljoin(url, html.unescape(src.strip()))
            if img.startswith('http://'):
                img = 'https://' + img[len('http://'):]
            if img in skip or BAD.search(urllib.parse.urlparse(img).path):
                continue
            if image_ok(img, min_bytes=60_000):
                return img, '하위 페이지 사진'
    return None, '하위 페이지에도 쓸 만한 사진이 없음'


def deep_pass() -> None:
    """--deep: 이미 수집한 결과에서 사진이 없는 업체만 하위 페이지까지 다시 찾는다 (있는 사진은 그대로)"""
    data = json.loads(OUT.read_text(encoding='utf-8'))
    out = data['images']
    skip = {x.get('rejected') for x in out.values() if x.get('rejected')}
    sites = sorted({x['source'] for x in out.values() if not x['image'] and x['source']})
    with ThreadPoolExecutor(8) as ex:
        found = dict(zip(sites, ex.map(lambda s: find_deep(s, skip), sites)))
    for vid, x in out.items():
        if x['image'] or x['source'] not in found or vid in DEEP_EXCLUDE:
            continue
        img, note = found[x['source']]
        if img:
            x.update(image=img, note=note)
    data['meta']['deep'] = '첫 화면에 사진이 없던 업체는 하위 페이지(갤러리·포트폴리오 등)까지 찾음'
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding='utf-8')
    print(sum(1 for x in out.values() if x['image']), '/', len(out), file=sys.stderr)


def main() -> None:
    vendors = json.loads(VENDORS.read_text(encoding='utf-8'))
    sites = sorted({v['url'] for v in vendors if v['url']})
    with ThreadPoolExecutor(8) as ex:
        found = dict(zip(sites, ex.map(find_image, sites)))
    out = {}
    for v in vendors:
        img, note = found.get(v['url'], (None, '홈페이지 없음'))
        if v['id'] in REVIEW_EXCLUDE and img:
            img, note = None, f"검수 제외: {REVIEW_EXCLUDE[v['id']]}"
        out[v['id']] = {'image': img, 'source': v['url'], 'note': note}
    meta = {'collectedAt': date.today().isoformat(),
            'method': '업체 홈페이지 대표 이미지(og:image) 주소만 기록, 파일은 복사하지 않음'}
    OUT.write_text(json.dumps({'meta': meta, 'images': out}, ensure_ascii=False, indent=1), encoding='utf-8')
    ok = sum(1 for x in out.values() if x['image'])
    print(f'{ok}/{len(out)} 업체 대표 이미지', file=sys.stderr)
    for note in sorted({x['note'] for x in out.values()}):
        print(f"  {note}: {sum(1 for x in out.values() if x['note'] == note)}", file=sys.stderr)


if __name__ == '__main__':
    deep_pass() if '--deep' in sys.argv else main()
