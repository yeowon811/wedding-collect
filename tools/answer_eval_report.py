"""⑤ 답변 문장 평가 결과(ANS 줄)를 보고서로 만든다.

사용: python -I tools/answer_eval_report.py <flutter run 출력 파일> [보고서 이름]
결과: docs/ai-eval/<이름>.md (기본 answer_report)
"""
import json
import os
import sys
from datetime import date

TERMS = ['시연용', '가상', '예비부부', '신혼부부', '기관']  # GeminiClient.guardedTerms와 같게
CAUTIONS = ['확인할 것', '시연용', '기관']


def load(path):
    rows = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            i = line.find("ANS\t")
            if i >= 0:
                r = json.loads(line[i + 4:])
                if "addedTerms" not in r:  # 표시어 검사 도입 전 결과도 같은 기준으로 채점
                    o, d = r["output"] or "", r["draft"]
                    r["addedTerms"] = [t for t in TERMS if t in o and t not in d]
                    r["termsGrounded"] = r["output"] is not None and not r["addedTerms"]
                    r["cautionsInDraft"] = [c for c in CAUTIONS if c in d]
                    r["cautionsLost"] = [c for c in r["cautionsInDraft"] if c not in o]
                rows.append(r)
    return rows


def quote(text):
    return "\n".join("> " + l if l else ">" for l in (text or "(응답 없음)").splitlines())


def main():
    src = sys.argv[1]
    name = sys.argv[2] if len(sys.argv) > 2 else "answer_report"
    rows = load(src)
    n = len(rows)
    answered = [r for r in rows if r["output"]]
    grounded = sum(1 for r in answered if r["grounded"])
    with_caution = [r for r in answered if r["cautionsInDraft"]]
    caution_ok = sum(1 for r in with_caution if not r["cautionsLost"])
    names_total = sum(r["names"] for r in answered)
    names_kept = sum(r["namesKept"] for r in answered)
    markdown = sum(1 for r in answered if r["hasMarkdown"])
    terms_ok = sum(1 for r in answered if r.get("termsGrounded", True))
    # 앱이 실제로 Gemini 문장을 쓰는 경우: 두 검사를 모두 통과
    used = sum(1 for r in answered if r["grounded"] and r.get("termsGrounded", True))
    ms = sorted(r["ms"] for r in answered)
    med = ms[len(ms) // 2] if ms else 0

    out = [
        "# ⑤ 답변 문장 평가: 앱 답변 → Gemini가 다시 쓴 답변",
        "",
        f"- 날짜: {date.today().isoformat()} · 질문 {n}개 · 모델 gemini-3.5-flash-lite",
        "- 실행: `flutter run -d chrome --dart-define-from-file=secrets.json -t test/eval/answer_eval_main.dart` "
        "→ `python -I tools/answer_eval_report.py <출력>`",
        "",
        "| 항목 | 결과 | 의미 |",
        "|---|---|---|",
        f"| 응답 | {len(answered)}/{n} | 시간 안에 답한 비율 |",
        f"| 숫자 검사 통과 | {grounded}/{len(answered)} | 조회 결과에 없는 숫자를 쓰지 않음. **통과한 답변만 앱에 표시**, 나머지는 원래 문장 |",
        f"| 표시어 검사 통과 | {terms_ok}/{len(answered)} | 조회 결과에 없는 \"시연용\"·\"가상\"·\"예비부부\"·\"신혼부부\"·\"기관\"을 붙이지 않음. **통과한 답변만 앱에 표시** |",
        f"| 주의 문구 유지 | {caution_ok}/{len(with_caution)} | \"확인할 것\"·\"시연용\"·기관 확인 안내를 빠뜨리지 않음 |",
        f"| 이름 언급 | {names_kept}/{names_total} | 카드로 붙는 정책·예식장·업체 이름 중 본문에 나온 수 (카드는 앱이 항상 붙임, 참고용) |",
        f"| 마크다운 사용 | {markdown}건 | 굵게(**)·제목(#) (앱에서 **는 지움) |",
        f"| 응답 시간 | 중앙값 {med}ms · 최대 {ms[-1] if ms else 0}ms | |",
        "",
        f"→ 사용자에게 Gemini 문장이 보이는 비율: **{used}/{n}**",
        "",
        "## 문제 있는 답변",
        "",
    ]
    bad = [r for r in rows if not r["output"] or not r["grounded"] or r.get("addedTerms") or r["cautionsLost"]]
    if not bad:
        out.append("없음")
    for r in bad:
        reasons = []
        if not r["output"]:
            reasons.append(f"응답 없음 ({r.get('error')})")
        elif not r["grounded"]:
            reasons.append(f"조회 결과에 없는 숫자: {', '.join(r['extraNumbers'])}")
        if r.get("addedTerms"):
            reasons.append(f"조회 결과에 없는 표시어: {', '.join(r['addedTerms'])}")
        if r["cautionsLost"]:
            reasons.append(f"빠진 주의 문구: {', '.join(r['cautionsLost'])}")
        out.append(f"- **{r['id']}** {r['question']} — {' / '.join(reasons)}")

    out += ["", "## 전체 답변 (사람 검토용)", ""]
    for r in rows:
        mark = "✅" if r["output"] and r["grounded"] and not r.get("addedTerms") and not r["cautionsLost"] else "⚠️"
        out += [
            f"### {mark} {r['id']} · {r['question']}",
            f"내 정보: {r['profile']} · {r['ms']}ms",
            "",
            "**앱 답변 (조회 결과)**",
            "",
            quote(r["draft"]),
            "",
            "**Gemini 답변**",
            "",
            quote(r["output"]),
            "",
        ]

    os.makedirs("docs/ai-eval", exist_ok=True)
    path = f"docs/ai-eval/{name}.md"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print(f"{path}: answered {len(answered)}/{n}, grounded {grounded}, caution {caution_ok}/{len(with_caution)}, "
          f"names {names_kept}/{names_total}, markdown {markdown}, median {med}ms")


if __name__ == "__main__":
    main()
