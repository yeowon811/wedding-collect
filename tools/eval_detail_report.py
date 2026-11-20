"""블록 답 평가 로그 → 문항별 자세한 보고서 (2026-11-20, 최소 비용 시험용).

사용: python -I tools/eval_detail_report.py 로그 [로그 …] --out docs/ai-eval/파일.md [--title 제목]
로그: test/eval/blocks_eval_main.dart 출력 (EVAL\t{json} 줄 + Gemini 오류 줄). App Check 토큰 줄은 읽지 않고 쓰지도 않는다.
비용: 입력 $0.30 / 출력(생각 포함) $2.50 per 1M 토큰 (gemini-3.5-flash-lite 가정), 검색·지도 그라운딩은 호출 수만 센다(별도 과금).
"""
import argparse
import json
from collections import Counter

IN_PRICE, CACHED_PRICE, OUT_PRICE = 0.30, 0.03, 2.50
PATH_LABEL = {
    'ai': 'Gemini 블록 배치 (검사·검토 통과)',
    'ai_rewrite': 'Gemini 다시 쓰기 후 통과',
    'template': '앱 기본 틀 (Gemini 미연결)',
    'template_after_ai': '앱 기본 틀 (Gemini 실패·검사 탈락 뒤)',
}


def cost(u):
    cached = u.get('cached', 0)
    return ((u.get('in', 0) - cached) * IN_PRICE + cached * CACHED_PRICE + (u.get('out', 0) + u.get('think', 0)) * OUT_PRICE) / 1e6


def load(paths):
    rows, errors, done = [], Counter(), []
    for path in paths:
        for line in open(path, encoding='utf-8', errors='replace'):
            if 'token' in line.lower() and 'debug' in line.lower():
                continue
            if line.startswith('EVAL\t'):
                rows.append(json.loads(line[5:]))
            elif line.startswith('EVAL_DONE'):
                done.append(line.strip())
            elif '실패:' in line:
                errors[line.split('실패:', 1)[1].strip()[:120]] += 1
    return rows, errors, done


def render(b):
    t = b['type']
    if t == 'headline':
        badges = ' '.join(f"[{x['t']}·{x['c']}]" for x in b.get('badges', []))
        return f"제목: **{b.get('title', '')}** {badges}".rstrip()
    if t == 'ask':
        return f"되묻기: **{b.get('title', '')}** · 선택지 {', '.join(b.get('items', []))}"
    if t in ('text', 'notice'):
        return f"{'설명' if t == 'text' else '알림'}: {b.get('text', '')}"
    if t == 'filters':
        return '조건 칩: ' + ' · '.join(f"{f['l']}{' ✕' if f.get('r') or f.get('s') else ''}" for f in b.get('filters', [])) + ' · + 조건'
    if t == 'cards':
        out = []
        for c in b.get('cards', []):
            badge = f" [{c['badge']['t']}·{c['badge']['c']}]" if c.get('badge') else ''
            out.append(f"카드: {c['title']}{badge} — {' · '.join(c.get('values', []))}"
                       f"{' ✦ ' + c['reason'] if c.get('reason') else ''}{' · 문의 ' + c['contact'] if c.get('contact') else ''}")
        return '\n'.join(out)
    if t == 'table':
        rows = [b.get('columns', [])] + b.get('rows', [])
        return '표:\n' + '\n'.join('  | ' + ' | '.join(r) + ' |' for r in rows)
    if t in ('ranking', 'steps'):
        return f"{'순위' if t == 'ranking' else '단계'}: " + ' → '.join(b.get('items', []))
    if t == 'budget':
        return '예산표: ' + ' / '.join(' '.join(r) for r in b.get('rows', [])) + (f" · {b['title']}" if b.get('title') else '')
    if t == 'web':
        return '웹: ' + ' / '.join(w['t'] for w in b.get('web', []))
    if t == 'next':
        return '다음 칩: ' + ' · '.join(b.get('items', []))
    if t == 'fold':
        return f"접힌 줄: 출처 {len(b.get('sources', []))}개 · 기록 {len(b.get('log', []))}줄"
    return t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('logs', nargs='+')
    ap.add_argument('--out', required=True)
    ap.add_argument('--title', default='Blaze 최소 시험')
    ap.add_argument('--note', default='')
    a = ap.parse_args()
    rows, errors, done = load(a.logs)
    total = Counter()
    for r in rows:
        total.update(r.get('usage') or {})
    lines = [f'# {a.title}', '']
    if a.note:
        lines += [a.note, '']
    lines += ['## 요약', '', '| 문항 | 턴 | 질문 | 정답 | 답한 경로 | 응답 | Gemini 호출 | 토큰 입력(캐시)/출력/생각 | 비용 |',
              '|---|---|---|---|---|---|---|---|---|']
    for r in rows:
        u = r.get('usage') or {}
        lines.append(f"| {r['id']} | {r['turn']} | {r['q']} | {'맞음' if r['ok'] else '틀림'} | {PATH_LABEL.get(r.get('path'), r.get('path'))} | "
                     f"{r['ms'] / 1000:.2f}s | {r['calls']} | {u.get('in', 0)}({u.get('cached', 0)})/{u.get('out', 0)}/{u.get('think', 0)} | ${cost(u):.5f} |")
    ok = sum(r['ok'] for r in rows)
    grounding = sum(v for k, v in total.items() if k in ('calls.search', 'calls.maps'))
    lines += ['', f"- 정답 {ok}/{len(rows)} · 평균 응답 {sum(r['ms'] for r in rows) / max(1, len(rows)) / 1000:.2f}s · "
              f"Gemini 호출 합계 {sum(r['calls'] for r in rows)}번 (성공 {sum(v for k, v in total.items() if k.startswith('calls.'))}번)",
              f"- 토큰 합계: 입력 {total.get('in', 0)} (그중 캐시 {total.get('cached', 0)}) · 출력 {total.get('out', 0)} · 생각 {total.get('think', 0)} → "
              f"**예상 비용 ${cost(total):.4f}** (입력 ${IN_PRICE}/1M · 캐시 입력 ${CACHED_PRICE}/1M · 출력 ${OUT_PRICE}/1M 기준, 실패한 요청은 과금 안 됨)",
              f"- 검색·지도 그라운딩 호출: {grounding}번 (별도 과금)", '']
    if errors:
        lines += ['## Gemini 오류', ''] + [f'- {n}번: {e}' for e, n in errors.most_common()] + ['']
    lines += ['## 문항별 자세히', '']
    for r in rows:
        u = r.get('usage') or {}
        lines += [f"### {r['id']}-{r['turn']} · {r['q']}", '']
        if r['turn'] > 1:
            prev = [x['q'] for x in rows if x['id'] == r['id'] and x['turn'] < r['turn'] and x.get('run') == r.get('run')]
            lines.append(f"- 앞 턴: {' → '.join(prev)}")
        lines += [
            f"- 고른 도구·조건: {r.get('plan') or '없음 (Gemini 도구 고르기 실패 → 규칙으로 이해)'}",
            f"- 답한 경로: {PATH_LABEL.get(r.get('path'), r.get('path'))} · 답 종류 {r.get('answer_kind')}",
            f"- 정답: {'맞음' if r['ok'] else '틀림'}{'' if r['ok'] else ' — ' + '; '.join(r['fails'])}"
            f"{' (기대값 모두 만족)' if r['ok'] and r.get('graded') else ''}",
            f"- 검사 K1~K5: {'; '.join(r.get('checks') or []) or '통과'} · Gemini 검토: {r.get('verdict') or '없음 (호출 안 됨)'} · "
            f"다시 쓰기: {'예' if r.get('path') == 'ai_rewrite' else '아니요'}",
            f"- 응답 {r['ms'] / 1000:.2f}s · Gemini 호출 {r['calls']}번 · 토큰 {json.dumps(u, ensure_ascii=False)} · 비용 ${cost(u):.5f}",
            '']
        detail = r.get('calls_detail') or []
        if detail:
            lines += ['| Gemini 호출 | 걸린 시간 | 입력 | 그중 캐시 | 출력 | 생각 | 결과 |', '|---|---|---|---|---|---|---|']
            for c in detail:
                lines.append(f"| {c.get('kind')} | {c.get('ms', 0) / 1000:.2f}s | {c.get('in', '-')} | {c.get('cached', '-')} | "
                             f"{c.get('out', '-')} | {c.get('think', '-')} | {'성공' if c.get('ok') else '실패: ' + str(c.get('error', ''))[:80]} |")
            lines.append('')
        lines += ['**화면 (글로 옮김)**', '', '```']
        lines += [render(b) for b in r.get('blocks', [])]
        lines += [f"칩 버튼: {' · '.join(r.get('chips', []))}", '```', '', '<details><summary>어떻게 찾았나요 (기록)</summary>', '']
        lines += [f'- {x}' for x in r.get('log', [])]
        lines += ['', '</details>', '', '<details><summary>블록 JSON 원본</summary>', '', '```json',
                  json.dumps(r.get('blocks', []), ensure_ascii=False, indent=1), '```', '', '</details>', '']
    open(a.out, 'w', encoding='utf-8').write('\n'.join(lines))
    print('wrote', a.out)


if __name__ == '__main__':
    main()
