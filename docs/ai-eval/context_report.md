# 대화 흐름 이해 평가: 이전 대화를 어떻게 넘길 것인가

- 날짜: 2026-11-17 · 질문 32개 (생략·지시·조건·정정·주제 전환·먼 과거·긴 대화 뒤 새 질문) · 모델 gemini-3.5-flash-lite
- 채점: 정답 / 놓침(일부를 모름 → 되물으면 됨) / **틀림(그럴듯한 오답)**. 만족도 = 정답 1, 놓침 0.4, 틀림 -0.5 (100점 만점)
- "+규칙 보완": Gemini가 비워 둔 몇 번째·조건·항목·분야를 규칙 결과로 채움
- 실행: `flutter run -d chrome --dart-define-from-file=secrets.json -t test/eval/context_eval_main.dart` → `python -I tools/context_eval_report.py <출력>`

## 방식별 결과 (만족도 순)

| 방식 | 정답 | 놓침 | 틀림 | 만족도 | 응답 시간(중앙값) | 보낸 글자(평균) |
|---|---|---|---|---|---|---|
| Gemini · 원문 3턴 + 규칙 보완 | 32/32 | 0 | **0** | **100** | 4467ms | 167 |
| Gemini · 요약 상태 3턴 + 규칙 보완 | 32/32 | 0 | **0** | **100** | 2206ms | 103 |
| Gemini · 요약 상태 3턴 | 31/32 | 1 | **0** | **98** | 2206ms | 103 |
| Gemini · 원문 1턴 + 규칙 보완 | 31/32 | 1 | **0** | **98** | 3799ms | 131 |
| Gemini · 요약 상태 1턴 + 규칙 보완 | 31/32 | 0 | **1** | **95** | 4258ms (12초 초과 1) | 82 |
| Gemini · 요약 1턴 + 원문 2턴 + 규칙 보완 | 31/32 | 0 | **1** | **95** | 4733ms | 230 |
| Gemini · 원문 1턴 | 29/32 | 3 | **0** | **94** | 3799ms | 131 |
| Gemini · 원문 3턴 | 29/32 | 3 | **0** | **94** | 4467ms | 167 |
| Gemini · 원문 5턴 + 규칙 보완 | 30/32 | 1 | **1** | **93** | 4259ms (12초 초과 2) | 183 |
| Gemini · 요약 1턴 + 원문 2턴 | 29/32 | 2 | **1** | **92** | 4733ms | 230 |
| Gemini · 원문 5턴 | 27/32 | 5 | **0** | **91** | 4259ms (12초 초과 2) | 183 |
| Gemini · 요약 상태 1턴 | 28/32 | 3 | **1** | **90** | 4258ms (12초 초과 1) | 82 |
| 규칙만 (AI 없음) | 27/32 | 3 | **2** | **85** | 0ms | 12 |
| Gemini · 질문만 (지금 방식) + 규칙 보완 | 26/32 | 0 | **6** | **72** | 4980ms (12초 초과 1) | 12 |
| Gemini · 질문만 (지금 방식) | 23/32 | 3 | **6** | **66** | 4980ms (12초 초과 1) | 12 |

## 유형별 정답 수

| 방식 | 생략 | 지시 | 조건 | 정정 | 전환 | 먼과거 | 새질문 |
|---|---|---|---|---|---|---|---|
| Gemini · 원문 3턴 + 보완 | 7/7 | 6/6 | 4/4 | 3/3 | 6/6 | 4/4 | 2/2 |
| Gemini · 요약 상태 3턴 + 보완 | 7/7 | 6/6 | 4/4 | 3/3 | 6/6 | 4/4 | 2/2 |
| Gemini · 요약 상태 3턴 | 7/7 | 5/6 | 4/4 | 3/3 | 6/6 | 4/4 | 2/2 |
| Gemini · 원문 1턴 + 보완 | 7/7 | 6/6 | 4/4 | 3/3 | 6/6 | 3/4 | 2/2 |
| Gemini · 요약 상태 1턴 + 보완 | 7/7 | 6/6 | 4/4 | 3/3 | 6/6 | 3/4 | 2/2 |
| Gemini · 요약 1턴 + 원문 2턴 + 보완 | 7/7 | 6/6 | 4/4 | 3/3 | 6/6 | 3/4 | 2/2 |
| Gemini · 원문 1턴 | 7/7 | 4/6 | 4/4 | 3/3 | 6/6 | 3/4 | 2/2 |
| Gemini · 원문 3턴 | 7/7 | 4/6 | 4/4 | 3/3 | 6/6 | 3/4 | 2/2 |
| Gemini · 원문 5턴 + 보완 | 7/7 | 6/6 | 4/4 | 2/3 | 6/6 | 4/4 | 1/2 |
| Gemini · 요약 1턴 + 원문 2턴 | 7/7 | 4/6 | 4/4 | 3/3 | 6/6 | 3/4 | 2/2 |
| Gemini · 원문 5턴 | 7/7 | 4/6 | 4/4 | 2/3 | 6/6 | 3/4 | 1/2 |
| Gemini · 요약 상태 1턴 | 7/7 | 5/6 | 3/4 | 3/3 | 6/6 | 2/4 | 2/2 |
| 규칙만 (AI 없음) | 5/7 | 6/6 | 4/4 | 1/3 | 6/6 | 3/4 | 2/2 |
| Gemini · 질문만 (지금 방식) + 보완 | 5/7 | 4/6 | 4/4 | 2/3 | 6/6 | 3/4 | 2/2 |
| Gemini · 질문만 (지금 방식) | 4/7 | 3/6 | 3/4 | 2/3 | 6/6 | 3/4 | 2/2 |

## 질문별 결과

| ID | 유형 | 이전 대화 → 질문 | 정답 | 규칙만 (AI 없음) | 질문만 (지금 방식) | 원문 1턴 | 원문 3턴 | 원문 5턴 | 요약 상태 1턴 | 요약 상태 3턴 | 요약 1턴 + 원문 2턴 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| E1 | 생략 | 그럼 부산은? | intent=venue, sido=부산 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| E2 | 생략 | 경기는? | intent=policy, sido=경기, topic=housing | ✅ | ❌ intent=answer, topic=? | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| E3 | 생략 | 메이크업은? | intent=vendor, item=makeup | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| E4 | 생략 | 부산에서는? | intent=vendor, item=dress, sido=부산 | ✅ | ❌ intent=venue, item=? | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| E5 | 생략 | 200명이면? | intent=venue, guests=200 | ◻️ guests=? | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| E6 | 생략 | 신혼부부는? | intent=policy, topic=cash, stage=married | ✅ | ◻️ topic=? | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| E7 | 생략 | 5천이면? | intent=budget, budget=5000 | ◻️ budget=? | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| R1 | 지시 | 두 번째 거 자세히 알려줘 | intent=venue, refIndex=2 | ✅ | ❌ intent=vendor | ✅ | ✅ | ◻️ refIndex=? | ✅ | ✅ | ✅ |
| R2 | 지시 | 첫 번째 정책 신청은 어떻게 해? | intent=policy, refIndex=1 | ✅ | ✅ | ◻️ refIndex=? | ✅ | ✅ | ◻️ refIndex=? | ◻️ refIndex=? | ◻️ refIndex=? |
| R3 | 지시 | 마지막 업체 후기 어때? | intent=vendor, refIndex=3 | ✅ | ◻️ refIndex=? | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| R4 | 지시 | 거기 주차는 돼? | intent=venue, refIndex=1 | ✅ | ✅ | ✅ | ◻️ refIndex=? | ✅ | ✅ | ✅ | ◻️ refIndex=? |
| R5 | 지시 | 그거 나도 받을 수 있어? | intent=policy, refIndex=1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| R6 | 지시 | 2번이랑 3번 중에 어디가 더 커? | intent=venue, refIndex=[2, 3] | ✅ | ❌ intent=help, refIndex=? | ◻️ refIndex=? | ◻️ refIndex=? | ◻️ refIndex=? | ✅ | ✅ | ✅ |
| F1 | 조건 | 그중에 무료인 곳만 | intent=venue, filter=free | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| F2 | 조건 | 하객 다 들어가는 데만 보여줘 | intent=venue, filter=fits_guests | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| F3 | 조건 | 더 싼 데는 없어? | intent=vendor, item=dress, filter=cheaper | ✅ | ◻️ item=? | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| F4 | 조건 | 사진 있는 곳만 보여줘 | intent=venue, filter=has_photo | ✅ | ✅ | ✅ | ✅ | ✅ | ◻️ filter=? | ✅ | ✅ |
| C1 | 정정 | 아 서울 말고 경기야 | intent=venue, sido=경기 | ❌ sido=서울 | ❌ intent=answer | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| C2 | 정정 | 아 저희 혼인신고 했어요 | intent=['policy', 'answer'], stage=married | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| C3 | 정정 | 드레스 말고 스냅이요 | intent=vendor, item=snap | ❌ item=dress | ✅ | ✅ | ✅ | ◻️ 응답 없음 | ✅ | ✅ | ✅ |
| T1 | 전환 | 예산은 어떻게 나눠? | intent=budget, refIndex=None, filter=None | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| T2 | 전환 | 드레스 추천해줘 | intent=vendor, item=dress, topic=None | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| T3 | 전환 | 받을 수 있는 정책 알려줘 | intent=policy, item=None | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| T4 | 전환 | 뭐부터 준비해야 돼? | intent=schedule, refIndex=None | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| T5 | 전환 | 결혼 장려금도 있어? | intent=policy, topic=cash | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| T6 | 전환 | 고마워! | intent=help, refIndex=None | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| L1 | 먼과거 | 아까 그 예식장 두 번째 곳 다시 보여줘 | intent=venue, refIndex=2 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| L2 | 먼과거 | 처음에 말한 지역 공공예식장 중 무료인 곳 | intent=venue, sido=부산, filter=free | ◻️ sido=? | ❌ sido=서울 | ◻️ sido=? | ✅ | ✅ | ❌ sido=서울 | ✅ | ❌ sido=서울 |
| L3 | 먼과거 | 아까 정책 첫 번째 거 신청 방법 알려줘 | intent=policy, refIndex=1 | ✅ | ✅ | ✅ | ◻️ refIndex=? | ◻️ refIndex=? | ◻️ refIndex=? | ✅ | ✅ |
| L4 | 먼과거 | 그 메이크업 업체들 중에 제일 싼 곳은? | intent=vendor, item=makeup, filter=cheaper | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| N1 | 새질문 | 공공예식장 추천해줘 | intent=venue, refIndex=None, filter=None | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| N2 | 새질문 | 하객 100명인데 인천 예식장 있어? | intent=venue, sido=인천, guests=100, refIndex=None | ✅ | ✅ | ✅ | ✅ | ◻️ guests=? | ✅ | ✅ | ✅ |
