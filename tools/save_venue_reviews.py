"""AI 예시 후기 생성 결과(flutter run 로그의 `VREV\\t{json}` 줄) → assets/data/venue_reviews.json

사용: python -I tools/save_venue_reviews.py <로그 파일> [<로그 파일> ...]
같은 예식장이 여러 번 나오면 뒤의 결과를 쓴다 (다시 생성한 것).
태그는 정해진 목록에 있는 것만 남긴다.
"""
import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/data/venue_reviews.json'
TAGS = {'대관료 부담 적음', '넓어요', '아담해요', '주차 편해요', '야외 분위기', '피로연 가능',
        '준비할 게 많아요', '예약 쉬워요', '교통 확인 필요'}


def main(paths: list[str]) -> None:
    venues: dict[str, list] = {}
    for p in paths:
        for line in Path(p).read_bytes().decode('utf-8', 'replace').splitlines():
            if not line.startswith('VREV\t'):
                continue
            j = json.loads(line.split('\t', 1)[1])
            reviews = [
                {'rating': r['rating'], 'text': r['text'], 'tags': [t for t in r.get('tags', []) if t in TAGS][:2]}
                for r in j['reviews'] if r.get('text')
            ]
            if reviews:
                venues[j['id']] = reviews
    out = {
        'generatedAt': date.today().isoformat(),
        'model': 'gemini-3.5-flash-lite',
        'note': 'AI가 예식장 공개 정보(정원·대관료·주차·피로연 등)만 보고 쓴 예시 후기. 실제 이용 후기가 아님',
        'venues': {k: venues[k] for k in sorted(venues)},
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    n = sum(len(v) for v in venues.values())
    print(f'→ {OUT.relative_to(ROOT)}: 예식장 {len(venues)}곳, 후기 {n}개')


if __name__ == '__main__':
    main(sys.argv[1:])
