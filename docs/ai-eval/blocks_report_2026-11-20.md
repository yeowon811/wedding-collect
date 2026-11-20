# AI 상담 블록 답: 결과 보고 (2026-11-20 새벽)

## 만든 것
- 블록 답 화면 (`lib/features/chat/answer/`): headline·text·filters·cards·table·ranking·steps·budget·ask·web·next·fold (+ 앱 전용 notice)
- 흐름: 도구 고르기 → 앱 조회 → (지도·검색 보충 조사) → Gemini 블록 배치 → 앱 검사 K1~K5 + Gemini 검토 → 1번 다시 쓰기 → 기본 틀
- 범위 넓히기 R9 (내 구부터, '서초·송파까지', '서울 전체', 가까운 시도), 조건 칩 ✕·+조건 (Gemini 없이 다시 찾기)
- 조사 고치기 `core/utils/korean.dart`, Gemini 하루 한도 초과 시 10분 쉬기

## 평가 (규칙 경로만: Gemini 무료 하루 한도 초과, 03:00·05:05·07:21·07:34 모두 같은 오류)
`docs/ai-eval/blocks_rules_2026-11-20.md` · 로그 `docs/ai-eval/raw/blocks_rules_v1~v6.log`

| 세트 | 채점 턴 정답 | 형식·숫자 검사 | 보이는 글자 (예전 글) |
|---|---|---|---|
| 예상 답 30 (design) | 28/28 | 30/30 | 158 (256) |
| 예상 질문 52 | 15/15 | 59/59 | 157 (262) |
| 탐색 36 | 19/20 | 46/46 | 182 (264) |
| 추가 20 (extra: 조건 칩·넓히기·0건·역·소득·더 보기) | 21/22 | 28/28 | 187 (234) |

- v1 → v6 (규칙 경로 고친 것): 이름으로 예식장 찾기(SETEC이랑·마루공원), 구 이름만 있는 질문 → 예식장 찾기(B3·B4),
  "신혼부부 전세대출"을 내 결혼 단계로 읽지 않기 + 이름 나온 정책이 소득 상한을 넘으면 "그 대출은 대상이 아니에요"(E2),
  "역 근처/가까운 곳" → 장소 되묻기·지도 조회(B8), 정책 이름을 그대로 물으면 그 정책(X15)
- 남은 실패 2개 (Gemini 경로에서 확인): P03 "대관료 제일 싼 서울 예식장 3개"를 정책으로 읽음, X16 "3000만원에서 식대 6만원 120명 빼면?" 계산식을 못 만듦
- 같은 답 반복 2건(P25-2, P31-3)은 결과가 실제로 같음 → "조건을 바꿔도 앞과 같은 결과예요" 문장 붙임
- Gemini 경로(작성·검토·다시 쓰기), 속도·호출 수, 흔들림(EVAL_REPEAT=3)은 **아직 측정 못 함**. 가짜 Gemini로 흐름만 단위 테스트(`test/answer_composer_test.dart`)
- 한도 초과 동작: 첫 질문에서 한도 오류를 받은 뒤 다음 질문은 Gemini 호출 0번·9ms로 바로 기본 틀 (`raw/blocks_gemini_quota_probe.log`)
- 화면 확인: 웹 빌드(포트 8098, `.claude/launch.json`의 `web-build-blocks`) 캡처 `docs/ai-eval/screens_2026-11-20/`. 8095 포트는 다른 세션의 다른 폴더 빌드를 띄우고 있었음

## 유료 전환 뒤 첫 시험 (09:16, design B1·C1·D2·F3)
- 무료 한도 오류는 사라졌지만 모든 호출이 **"Your prepayment credits are depleted"** (AI Studio 선불 크레딧 0) 로 실패 → 4문항 모두 기본 틀로 답함
- 4문항 모두 기대값 정답 (규칙 경로 + 기본 틀), 응답 0.9~1.9초, 실패 호출 질문당 3번, 토큰 0 → **비용 0원** (실패 요청은 과금되지 않음)
- 고침: 결제 오류(선불 크레딧 소진·billing)도 하루 한도처럼 10분 쉼 → 같은 2문항 재실행 시 실패 호출 6번 → 2번 (`raw/blocks_paid_try1.log`, `raw/blocks_paid_try2_pause.log`)
- 평가 출력에 종류별 호출 수·토큰(입력·출력·생각)·검색/지도 호출 수 기록 추가 (`GeminiClient.usage`, EVAL 줄의 `usage`)

## 다음에 돌릴 명령 (한도 초기화 또는 Blaze 뒤)
```
bash run_eval.sh 로그 --dart-define=EVAL_SET=design --dart-define=EVAL_GAP=2   (EVAL 줄만 저장! 토큰 줄 제외)
python -I tools/blocks_eval_report.py 로그 --prev docs/ai-eval/raw/blocks_rules_v3.log --out docs/ai-eval/blocks_gemini_YYYY-MM-DD.md
```
작은 묶음부터(EVAL_ONLY=B1,C1,D2,F3) → 전체 → predicted·probe → EVAL_REPEAT=3.

## 데이터 점검 (`docs/data-validation/audit_2026-11-20.md`)
- 코드 버그 고침: '광주·전남' 예식장 11곳을 새 검사(K1)·넓히기·자동 구 좁히기에서 `sidoMatches`로 비교
- 사람 확인 필요: 실제 업체 21곳 휴대폰 번호 노출, 정책 177건 사람 검수 0건, P059 분류 '기타', 예식장 빈 값(정원 81·대관료 57곳)
