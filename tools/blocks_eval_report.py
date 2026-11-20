"""블록 답 평가 로그 → 보고서 (2026-11-20).

입력: test/eval/blocks_eval_main.dart(Chrome·Gemini) 또는 blocks_eval_rules.dart(규칙만)의 출력 로그.
      `EVAL\t{json}` 줄만 읽는다 (앞에 다른 글이 붙어 있어도 EVAL\t 뒤를 읽음).
사용:
  python -I tools/blocks_eval_report.py 로그.txt [--prev 이전로그.txt] [--title 제목] [--out docs/ai-eval/파일.md]
  python -I tools/blocks_eval_report.py 로그.txt --fails     실패만 화면에
보고서: 세트별 정답률·형식/숫자 검사·글자 수(예전 글 vs 블록)·속도·Gemini 호출 수·답 경로,
        실패 목록, 같은 답 반복, 흔들림(같은 대화 여러 번), 이전 실행과 달라진 질문.
"""
import argparse
import json
import statistics
import sys
from collections import Counter, defaultdict


def load(path):
    rows = []
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            i = line.find('EVAL\t')
            if i < 0:
                continue
            try:
                rows.append(json.loads(line[i + 5:].strip()))
            except json.JSONDecodeError:
                continue
    return rows


def key(r):
    return (r['set'], r['id'], r['turn'])


def pct(a, b):
    return f'{a}/{b} ({(100 * a / b):.0f}%)' if b else '-'


def summary(rows):
    out = ['| 세트 | 턴 | 채점 턴 정답 | 검사(K2·K5) 통과 | 블록 글자 평균 (예전 글) | 응답 평균·최대 | Gemini 호출/턴 | 답 경로 |',
           '|---|---|---|---|---|---|---|---|']
    by = defaultdict(list)
    for r in rows:
        if r.get('run', 1) == 1:
            by[r['set']].append(r)
    for s, rs in by.items():
        graded = [r for r in rs if r['graded']]
        ok_g = sum(r['ok'] for r in graded)
        fmt_ok = sum(not any(f.startswith(('K2', 'K5', '블록 없음')) for f in r['fails']) for r in rs)
        vis = statistics.mean(r['visible_chars'] for r in rs)
        old = statistics.mean(r['old_chars'] for r in rs)
        ms = [r['ms'] for r in rs]
        calls = statistics.mean(r['calls'] for r in rs)
        paths = Counter(r.get('path') or '-' for r in rs)
        out.append(f"| {s} | {len(rs)} | {pct(ok_g, len(graded))} | {pct(fmt_ok, len(rs))} | {vis:.0f} ({old:.0f}) | "
                   f"{statistics.mean(ms) / 1000:.1f}s · {max(ms) / 1000:.1f}s | {calls:.1f} | "
                   f"{', '.join(f'{k} {v}' for k, v in paths.most_common())} |")
    return out


def fails(rows):
    out = []
    for r in rows:
        if r.get('run', 1) != 1 or r['ok']:
            continue
        out.append(f"- **{r['set']} {r['id']}-{r['turn']}** \"{r['q']}\" → \"{r['headline']}\" · {'; '.join(r['fails'])}")
    return out or ['- 없음']


def repeats(rows):
    out = [f"- {r['set']} {r['id']}-{r['turn']} \"{r['q']}\" → 앞 답과 제목·카드가 같음 (\"{r['headline']}\")"
           for r in rows if r.get('repeat') and r.get('run', 1) == 1]
    return out or ['- 없음']


def stability(rows):
    runs = defaultdict(list)
    for r in rows:
        runs[key(r)].append(r)
    multi = {k: v for k, v in runs.items() if len(v) > 1}
    if not multi:
        return ['- (여러 번 실행한 대화 없음: EVAL_REPEAT=3으로 실행)']
    shaky = []
    for k, v in multi.items():
        sig = {(x['headline'], tuple(x['ids'])) for x in v}
        oks = {x['ok'] for x in v}
        if len(sig) > 1 or len(oks) > 1:
            shaky.append(f"- {k[0]} {k[1]}-{k[2]} \"{v[0]['q']}\": " + ' / '.join(
                f"[{x['headline']} · {','.join(x['ids'][:3])}{' ✗' if not x['ok'] else ''}]" for x in v))
    return [f'- {len(multi)}개 턴을 {max(len(v) for v in multi.values())}번씩 실행 → 흔들린 턴 {len(shaky)}개', *shaky]


def diff(rows, prev):
    old = {key(r): r for r in prev if r.get('run', 1) == 1}
    out = []
    better = worse = 0
    for r in rows:
        if r.get('run', 1) != 1 or key(r) not in old:
            continue
        o = old[key(r)]
        changed = o['headline'] != r['headline'] or o['ids'] != r['ids']
        if o['ok'] != r['ok']:
            better += r['ok']
            worse += not r['ok']
        if changed or o['ok'] != r['ok']:
            mark = '좋아짐' if r['ok'] and not o['ok'] else '나빠짐' if o['ok'] and not r['ok'] else '바뀜'
            out.append(f"- [{mark}] {r['set']} {r['id']}-{r['turn']} \"{r['q']}\": \"{o['headline']}\" ({','.join(o['ids'][:3])}) → "
                       f"\"{r['headline']}\" ({','.join(r['ids'][:3])})")
    return [f'- 바뀐 턴 {len(out)}개 (좋아짐 {better} · 나빠짐 {worse})', *out]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('log')
    ap.add_argument('--prev')
    ap.add_argument('--title', default='블록 답 평가')
    ap.add_argument('--out')
    ap.add_argument('--fails', action='store_true')
    a = ap.parse_args()
    rows = load(a.log)
    if a.fails:
        sys.stdout.reconfigure(encoding='utf-8')
        print('\n'.join(summary(rows)))
        print('\n'.join(fails(rows)))
        return
    lines = [f'# {a.title}', '', f'로그: `{a.log}` · 턴 {len(rows)}개', '', '## 요약', *summary(rows), '',
             '- 채점 턴 정답: 질문별 기대값(구·시도·무료·포함/제외 id·제목·블록)을 모두 만족한 턴 / 기대값이 있는 턴',
             '- 검사 통과: 앱 검사 K2(숫자 출처)·K5(형식 F1~F14)에 걸리지 않은 턴',
             '- 글자 수: 화면에 보이는 블록 글(접힌 줄·칩 제외) / 괄호 안은 예전 글 답의 글자 수', '',
             '## 틀린 턴', *fails(rows), '', '## 같은 답 반복 (대화형)', *repeats(rows), '', '## 흔들림 (같은 대화 여러 번)',
             *stability(rows), '']
    if a.prev:
        lines += ['## 이전 실행과 비교', f'이전 로그: `{a.prev}`', *diff(rows, load(a.prev)), '']
    text = '\n'.join(lines)
    if a.out:
        with open(a.out, 'w', encoding='utf-8') as f:
            f.write(text)
        print('wrote', a.out)
    else:
        sys.stdout.reconfigure(encoding='utf-8')
        print(text)


if __name__ == '__main__':
    main()
