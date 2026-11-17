"""대화 흐름 이해 평가 결과(CTX 줄)를 채점해 보고서로 만든다.

사용: python -I tools/context_eval_report.py <flutter run 출력 파일> [<추가 출력 파일> ...]
결과: docs/ai-eval/context_report.md

채점 (질문마다 정해 둔 항목만):
- 정답: 모든 항목이 맞음
- 놓침: 틀린 값은 없고 일부를 모름(null) → 앱이 되묻거나 덜 구체적으로 답함 (덜 나쁨)
- 틀림: 하나라도 다른 값 (목적·지역 오인, 이어받으면 안 되는 것을 이어받음) → 그럴듯한 오답 (가장 나쁨)
만족도 점수 = 정답 1점, 놓침 0.4점, 틀림 -0.5점 (질문 수로 나눠 100점 만점)
"보완": Gemini 결과에서 빈 refIndex·filter·item·topic을 규칙 결과로 채운 경우 (앱에 쓸 조합 후보)
"""
import json
import os
import sys
from collections import OrderedDict, defaultdict
from datetime import date

NAMES = OrderedDict([
    ('rule', '규칙만 (AI 없음)'),
    ('g_none', 'Gemini · 질문만 (지금 방식)'),
    ('g_raw1', 'Gemini · 원문 1턴'),
    ('g_raw3', 'Gemini · 원문 3턴'),
    ('g_raw5', 'Gemini · 원문 5턴'),
    ('g_state1', 'Gemini · 요약 상태 1턴'),
    ('g_state3', 'Gemini · 요약 상태 3턴'),
    ('g_state1_raw2', 'Gemini · 요약 1턴 + 원문 2턴'),
])
FILL = ['refIndex', 'filter', 'item', 'topic']
SCORE = {'ok': 1.0, 'missed': 0.4, 'wrong': -0.5}


def load(paths):
    rows = []
    for p in paths:
        with open(p, encoding='utf-8', errors='replace') as f:
            for line in f:
                i = line.find('CTX\t')
                if i >= 0:
                    rows.append(json.loads(line[i + 4:]))
    # 같은 (id, cond)가 여러 번이면 마지막 것
    last = OrderedDict()
    for r in rows:
        last[(r['id'], r['cond'])] = r
    return list(last.values())


def grade(expect, got):
    if got is None:
        return 'missed', ['응답 없음']
    wrong, missed = [], []
    for k, want in expect.items():
        v = got.get(k)
        if want is None:
            if v is not None:
                wrong.append(f'{k}={v}(없어야 함)')
        elif isinstance(want, list):
            if v is None:
                missed.append(k)
            elif v not in want:
                wrong.append(f'{k}={v}')
        elif v is None:
            missed.append(k)
        elif v != want:
            wrong.append(f'{k}={v}')
    if wrong:
        return 'wrong', wrong + [f'{m}=?' for m in missed]
    if missed:
        return 'missed', [f'{m}=?' for m in missed]
    return 'ok', []


def main():
    rows = load(sys.argv[1:])
    by = defaultdict(dict)  # id -> cond -> row
    for r in rows:
        by[r['id']][r['cond']] = r
    ids = list(OrderedDict.fromkeys(r['id'] for r in rows))
    conds = [c for c in NAMES if any(c in by[i] for i in ids)]

    results = defaultdict(dict)  # cond -> id -> (grade, detail)
    for i in ids:
        rule_got = by[i].get('rule', {}).get('got') or {}
        for c in conds:
            r = by[i].get(c)
            if not r:
                continue
            results[c][i] = grade(r['expect'], r['got'])
            if c.startswith('g_'):
                got = dict(r['got'] or {})
                if r['got'] is None:
                    got = dict(rule_got)
                else:
                    for k in FILL:
                        if got.get(k) is None and rule_got.get(k) is not None:
                            got[k] = rule_got[k]
                results[c + '+rule'][i] = grade(r['expect'], got)

    def summary(c):
        g = [results[c][i][0] for i in ids if i in results[c]]
        n = len(g)
        ok, mi, wr = g.count('ok'), g.count('missed'), g.count('wrong')
        score = round(100 * sum(SCORE[x] for x in g) / n) if n else 0
        ms = sorted(by[i][c.replace('+rule', '')]['ms'] for i in ids if c.replace('+rule', '') in by[i])
        chars = [by[i][c.replace('+rule', '')]['chars'] for i in ids if c.replace('+rule', '') in by[i]]
        return n, ok, mi, wr, score, (ms[len(ms) // 2] if ms else 0), (sum(chars) // len(chars) if chars else 0)

    all_conds = conds + [c + '+rule' for c in conds if c.startswith('g_')]
    ranked = sorted(all_conds, key=lambda c: -summary(c)[4])
    kinds = list(OrderedDict.fromkeys(by[i][conds[0]]['kind'] for i in ids))

    out = [
        '# 대화 흐름 이해 평가: 이전 대화를 어떻게 넘길 것인가',
        '',
        f'- 날짜: {date.today().isoformat()} · 질문 {len(ids)}개 (생략·지시·조건·정정·주제 전환·먼 과거·긴 대화 뒤 새 질문) · 모델 gemini-3.5-flash-lite',
        '- 채점: 정답 / 놓침(일부를 모름 → 되물으면 됨) / **틀림(그럴듯한 오답)**. 만족도 = 정답 1, 놓침 0.4, 틀림 -0.5 (100점 만점)',
        '- "+규칙 보완": Gemini가 비워 둔 몇 번째·조건·항목·분야를 규칙 결과로 채움',
        '- 실행: `flutter run -d chrome --dart-define-from-file=secrets.json -t test/eval/context_eval_main.dart` → `python -I tools/context_eval_report.py <출력>`',
        '',
        '## 방식별 결과 (만족도 순)',
        '',
        '| 방식 | 정답 | 놓침 | 틀림 | 만족도 | 응답 시간(중앙값) | 보낸 글자(평균) |',
        '|---|---|---|---|---|---|---|',
    ]
    for c in ranked:
        n, ok, mi, wr, score, med, chars = summary(c)
        name = NAMES.get(c.replace('+rule', ''), c) + (' + 규칙 보완' if c.endswith('+rule') else '')
        slow = sum(1 for i in ids if c.replace('+rule', '') in by[i] and by[i][c.replace('+rule', '')]['ms'] > 12000)
        out.append(f'| {name} | {ok}/{n} | {mi} | **{wr}** | **{score}** | {med}ms{f" (12초 초과 {slow})" if slow else ""} | {chars} |')

    out += ['', '## 유형별 정답 수', '', '| 방식 | ' + ' | '.join(kinds) + ' |', '|---|' + '---|' * len(kinds)]
    for c in ranked:
        cells = []
        for k in kinds:
            ks = [i for i in ids if by[i][conds[0]]['kind'] == k and i in results[c]]
            cells.append(f"{sum(1 for i in ks if results[c][i][0] == 'ok')}/{len(ks)}")
        name = NAMES.get(c.replace('+rule', ''), c) + (' + 보완' if c.endswith('+rule') else '')
        out.append(f'| {name} | ' + ' | '.join(cells) + ' |')

    out += ['', '## 질문별 결과', '', '| ID | 유형 | 이전 대화 → 질문 | 정답 | ' + ' | '.join(
        NAMES[c].replace('Gemini · ', '') for c in conds) + ' |', '|---|---|---|---|' + '---|' * len(conds)]
    mark = {'ok': '✅', 'missed': '◻️', 'wrong': '❌'}
    for i in ids:
        r0 = by[i][conds[0]]
        exp = ', '.join(f'{k}={v}' for k, v in r0['expect'].items())
        cells = []
        for c in conds:
            g, d = results[c].get(i, ('missed', ['-']))
            cells.append(mark[g] + (' ' + ', '.join(d) if d else ''))
        out.append(f"| {i} | {r0['kind']} | {r0['q']} | {exp} | " + ' | '.join(cells) + ' |')

    os.makedirs('docs/ai-eval', exist_ok=True)
    with open('docs/ai-eval/context_report.md', 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out) + '\n')
    for c in ranked:
        n, ok, mi, wr, score, med, chars = summary(c)
        print(f'{c:22s} ok {ok}/{n} missed {mi} wrong {wr} score {score} median {med}ms chars {chars}')


if __name__ == '__main__':
    main()
