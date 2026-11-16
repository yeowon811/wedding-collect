"""질문 이해 평가 결과(EVAL 줄)를 보고서로 만든다.

사용: python -I tools/eval_report.py <flutter run 출력 파일> [보고서 이름]
결과: docs/ai-eval/<이름>.md (기본 understanding_report)
"""
import json
import os
import sys
from datetime import date


def load(path):
    rows = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            i = line.find("EVAL\t")
            if i >= 0:
                rows.append(json.loads(line[i + 5:]))
    return rows


def fmt(v):
    return "-" if v is None else str(v)


def main():
    src = sys.argv[1]
    name = sys.argv[2] if len(sys.argv) > 2 else "understanding_report"
    rows = load(src)
    n = len(rows)
    rule_ok = sum(1 for r in rows if not r["ruleWrong"])
    gem_ok = sum(1 for r in rows if not r["geminiWrong"])
    app_ok = sum(1 for r in rows if not r.get("appWrong", ["?"]))
    no_resp = sum(1 for r in rows if r["gemini"] is None)
    ms = sorted(r["ms"] for r in rows if r["gemini"] is not None)
    med = ms[len(ms) // 2] if ms else 0

    out = [
        "# ① 질문 이해 평가: 규칙 기반 vs Gemini",
        "",
        f"- 날짜: {date.today().isoformat()} · 질문 {n}개 · 모델 gemini-3.5-flash-lite",
        "- 채점: 질문마다 정한 항목(목적·지역·나이·결혼 단계·분야·항목·하객·예산·무주택)이 모두 맞아야 정답",
        "- 실행: `flutter run -d chrome -t test/eval/eval_main.dart` → `python -I tools/eval_report.py <출력>`",
        "",
        "| | 정답 | 정확도 |",
        "|---|---|---|",
        f"| 규칙 기반 | {rule_ok}/{n} | {rule_ok * 100 // max(n, 1)}% |",
        f"| Gemini 단독 | {gem_ok}/{n} | {gem_ok * 100 // max(n, 1)}% |",
        f"| **앱 실제 (Gemini + 규칙 보완, 실패 시 규칙)** | **{app_ok}/{n}** | **{app_ok * 100 // max(n, 1)}%** |",
        "",
        f"- Gemini 응답 없음(규칙 기반으로 대체): {no_resp}건 · 응답 시간 중앙값 {med}ms · 최대 {ms[-1] if ms else 0}ms",
        "",
        "## 질문별 결과",
        "",
        "| ID | 질문 | 정답 | 규칙 | Gemini |",
        "|---|---|---|---|---|",
    ]
    for r in rows:
        exp = ", ".join(f"{k}={fmt(v)}" for k, v in r["expect"].items())

        def cell(wrong, got):
            if not wrong:
                return "✅"
            if got is None:
                return "❌ 응답 없음"
            return "❌ " + ", ".join(f"{k}={fmt(got.get(k))}" for k in wrong)

        out.append(
            f"| {r['id']} | {r['text']}{' (' + r['note'] + ')' if r.get('note') else ''} | {exp} "
            f"| {cell(r['ruleWrong'], r['rule'])} | {cell(r['geminiWrong'], r['gemini'])} |"
        )

    os.makedirs("docs/ai-eval", exist_ok=True)
    path = f"docs/ai-eval/{name}.md"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print(f"{path}: rule {rule_ok}/{n}, gemini {gem_ok}/{n}, app {app_ok}/{n}, no-response {no_resp}, median {med}ms, max {ms[-1] if ms else 0}ms")


if __name__ == "__main__":
    main()
