"""예식장 주차·피로연 원문 → 상담 분류(가능/불가/모름) 검수 표.

lib/features/chat/agent/venue_features.dart 와 같은 규칙. 원문이 바뀌면 다시 돌려 눈으로 확인한다.
실행: python -I tools/venue_features_report.py → docs/data-validation/venue_features.md
"""
import io
import json
import re
from collections import Counter

ROOT = __file__.replace('\\', '/').rsplit('/tools/', 1)[0]
venues = json.load(io.open(f'{ROOT}/assets/data/venues.json', encoding='utf-8'))


def parking(t):
    if not t:
        return 'unknown', None
    nums = [int(x) for x in re.findall(r'(\d+)\s*(?:대|면)', t)]
    spaces = max(nums) if nums else None
    if re.search(r'불가|없음|X', t) and spaces is None:
        return 'no', None
    if spaces is not None or '가능' in t or '주차장' in t:
        return 'yes', spaces
    return 'unknown', None


def reception(t):
    if not t:
        return 'unknown'
    kinds = [k for k, w in [('케이터링', '케이터링'), ('도시락', '도시락'), ('뷔페', '뷔페')] if w in t]
    if '케이터링' in kinds and '뷔페' in kinds:
        kinds.remove('뷔페')
    if not kinds and re.search(r'불가|^X|제한', t):
        return 'no'
    return 'yes(' + '·'.join(kinds) + ')' if kinds else 'unknown'


rows = []
for v in venues:
    p, sp = parking(v.get('parking'))
    r = reception(v.get('reception'))
    if v.get('parking') or v.get('reception'):
        rows.append((v['id'], v['name'], v.get('parking') or '', p + (f' {sp}대' if sp else ''), v.get('reception') or '', r))

out = ['# 예식장 주차·피로연 분류 검수', '',
       f"주차: {dict(Counter(parking(v.get('parking'))[0] for v in venues))} / "
       f"피로연: {dict(Counter(reception(v.get('reception')).split('(')[0] for v in venues))}", '',
       '| id | 예식장 | 주차 원문 | → | 피로연 원문 | → |', '|---|---|---|---|---|---|']
for row in rows:
    out.append('| ' + ' | '.join(str(x).replace('|', '/').replace('\n', ' ')[:70] for x in row) + ' |')
path = f'{ROOT}/docs/data-validation/venue_features.md'
io.open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(len(rows), 'rows →', path)
