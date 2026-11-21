"""업체_요소.xlsx의 '웨딩옵션_단가DB_통합' 시트 → assets/data/wedding_options.json (비용 시뮬레이터·시연 업체 가격 기준)

- 금액은 만원 단위 정수로 바꾼다 (원 ÷ 10,000, 반올림)
- '숨은 필수 추가금' 내역 문구에서 "이름(N만)" 조각을 뽑아 업체 추가 옵션(addOns) 후보로 쓴다
- 엑셀 하단 합계 줄(수식)은 앱이 직접 계산하므로 읽지 않는다

사용: python -I tools/convert_options.py "../업체_요소.xlsx"
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from xlsx_reader import read_sheets  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

# 앱에 보이는 이름 (2026-11-21 이름 정리: 엑셀 이름 → 앱 이름, 앱의 VendorCategory 이름과 맞춤)
DISPLAY_NAMES = {
    '스냅사진 (본식스냅)': '본식 스냅',
    '부케·케이크·화기': '부케·웨딩 케이크·화기',
    '신랑 정장 (예복)': '신랑 예복',
    '어머니 한복 (양가 2벌)': '혼주 한복 (양가 2벌)',
    '혼주 메이크업 (양가 4인)': '혼주 헤어·메이크업 (양가 4인)',
}

# 엑셀 항목 → 앱 id, 준비 항목(VendorCategory) 연결
IDS = {
    '드레스': ('dress', 'DRESS'),
    '메이크업': ('makeup', 'MAKEUP'),
    '웨딩촬영': ('studio', 'STUDIO'),
    '스냅사진': ('snap', 'SNAP'),
    '본식 영상': ('video', 'VIDEO'),
    '식대': ('meal', 'MEAL'),
    '청첩장': ('invitation', 'INVITATION'),
    '부케·케이크·화기': ('props', 'PROPS'),
    '신랑 정장': ('suit', 'SUIT'),
    '어머니 한복': ('hanbok', 'HANBOK'),
    '혼주 메이크업': ('parentMakeup', 'PARENT_MAKEUP'),
    '사회·진행': ('host', 'HOST'),
    '대관료': ('rental', None),
    '꽃장식·공간연출': ('flower', None),
    '음향·조명·의자 집기 렌탈': ('equipment', None),
    '총괄 디렉팅·현장 진행비': ('directing', 'DIRECTING'),
    '하객 셔틀버스 대절': ('shuttle', None),
    '본식·촬영 헬퍼비': ('helper', None),
    '헤어 변형 출장 작가': ('hairChange', None),
    '축가·연주 섭외': ('song', None),
    '답례품': ('gift', None),
    '웰컴 아크릴 액자·포토테이블': ('welcome', None),
}
# 하객 수에 따라 달라지는 항목 (엑셀 기준 하객 100명)
PER_GUEST = {'meal', 'gift'}


def manwon(v: str) -> int:
    try:
        return round(float(v) / 10000)
    except (TypeError, ValueError):
        return 0


def find_id(name: str):
    for key, val in IDS.items():
        if name.startswith(key):
            return val
    raise KeyError(name)


def add_ons(text: str) -> list[dict]:
    """'추가금: 피팅비(투어 2곳 10만) + 신상/블랙라벨 업그레이드(25만)' → [{name, price}]"""
    text = re.sub(r'^.*?추가금\s*:\s*', '', text)
    out = []
    for piece in re.split(r'\s*\+\s*', text):
        m = re.search(r'\(([^()]*?)(\d+)만\)\s*$', piece)  # 맨 끝 "(… N만)"이 금액
        if not m:
            continue
        name, detail = piece[:m.start()].strip(' ·,/'), m.group(1).strip()
        if name:
            out.append({'name': f'{name} ({detail})' if detail else name, 'price': int(m.group(2))})
    return out


def main(path: str) -> None:
    rows = read_sheets(path)['웨딩옵션_단가DB_통합']
    head = next(i for i, r in enumerate(rows) if r and r[0] == '번호')
    idx = {h: i for i, h in enumerate(rows[head])}
    col = lambda r, k: (r[idx[k]] if idx[k] < len(r) else '') or ''  # noqa: E731
    out = []
    for r in rows[head + 1:]:
        if not r or not str(r[0]).strip().isdigit():
            continue
        name = col(r, '선택 항목명 (UI 칩)').strip()
        oid, category = find_id(name)
        detail = col(r, '세부 구성 및 숨은 추가금 발생 내역')
        # 엑셀에서 세부 구성과 추가금 내역이 한 칸에 " | "로 이어져 있으면 나눈다
        parts = [p.strip() for p in re.split(r'\s*\|\s*|\n', detail) if p.strip()]
        out.append({
            'id': oid,
            'category': category,
            'group': col(r, '구분 카테고리').strip(),
            'name': DISPLAY_NAMES.get(name, name),
            'defaultOn': col(r, '시뮬레이션 채택').strip().upper() == 'Y',
            'kind': col(r, '공공예식장 특화여부').strip(),
            'publicPrice': manwon(col(r, '실속·공공 표준가(원)')),
            'averagePrice': manwon(col(r, '일반 웨딩 평균가(원)')),
            'hiddenExtra': manwon(col(r, '숨은 필수 추가금(원)')),
            'perGuest': oid in PER_GUEST,
            'detail': parts[0] if parts else '',
            'extraDetail': ' '.join(parts[1:]),
            'addOns': add_ons(' '.join(parts[1:])),
            'support': col(r, '정부·지자체 지원 연계 혜택').strip(),
            'sourceName': col(r, '크롤링 타겟 플랫폼 및 출처').strip(),
            'sourceUrl': col(r, '크롤링 타겟 URL (클릭 이동)').strip(),
        })
    dest = ROOT / 'assets/data/wedding_options.json'
    dest.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding='utf-8')
    print(len(out), 'options')


if __name__ == '__main__':
    main(sys.argv[1])
