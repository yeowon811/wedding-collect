# ① 질문 이해 평가: 규칙 기반 vs Gemini

- 날짜: 2026-11-16 · 질문 42개 · 모델 gemini-3.5-flash-lite
- 채점: 질문마다 정한 항목(목적·지역·나이·결혼 단계·분야·항목·하객·예산·무주택)이 모두 맞아야 정답
- 실행: `flutter run -d chrome -t test/eval/eval_main.dart` → `python -I tools/eval_report.py <출력>`

| | 정답 | 정확도 |
|---|---|---|
| 규칙 기반 | 29/42 | 69% |
| Gemini | 40/42 | 95% |

- Gemini 응답 없음(규칙 기반으로 대체): 1건 · 응답 시간 중앙값 6423ms

## 질문별 결과

| ID | 질문 | 정답 | 규칙 | Gemini |
|---|---|---|---|---|
| P01 | 20대 청년이 신혼생활에 받을 수 있는 정책이 뭐가있어? | intent=policy, topic=housing, age=20, ageMax=29 | ✅ | ✅ |
| P02 | 신혼집 구하는데 도움 받을 수 있는 거 있어? | intent=policy, topic=housing | ✅ | ✅ |
| P03 | 스물아홉이고 부산 살아요 받을 수 있는 지원 알려줘 (한글 숫자 나이) | intent=policy, sido=부산, age=29 | ❌ age=- | ✅ |
| P04 | 결혼 축하금 주는 지자체 있나요 | intent=policy, topic=cash | ✅ | ✅ |
| P05 | 작년에 혼인신고했는데 전세대출 이자 지원 받을 수 있어? | intent=policy, topic=housing, stage=married | ✅ | ✅ |
| P06 | 임신 준비 중인데 지원되는 검사 있어? | intent=policy, topic=health | ✅ | ❌ 응답 없음 |
| P07 | 전남 순천 사는 30대 중반 신혼부부 혜택 | intent=policy, sido=전남, age=33, ageMax=36, stage=married | ✅ | ✅ |
| P08 | 혼인 3년차인데 받을 수 있는 거 있어? | intent=policy, stage=married, marriedYears=3 | ✅ | ✅ |
| P09 | 결혼식장 대관료 지원해주는 정책 | intent=policy, topic=wedding | ✅ | ✅ |
| P10 | 경상남도 거주 예비부부인데 나라에서 돈 주는 거 있음? | intent=policy, sido=경남, stage=engaged | ❌ intent=budget | ✅ |
| P11 | 무주택 신혼부부 대출 금리 낮은 상품 알려줘 | intent=policy, topic=housing, stage=married, homeless=True | ✅ | ✅ |
| P12 | 서울에서 결혼하면 주는 혜택 뭐 있어 | intent=policy, sido=서울 | ✅ | ✅ |
| V01 | 하객 150명 정도 들어가는 경기도 예식장 있어? | intent=venue, sido=경기, guests=150 | ✅ | ❌ guests=- |
| V02 | 무료로 결혼식 할 수 있는 곳 있어? 대구 살아 | intent=venue, sido=대구 | ❌ intent=help | ✅ |
| V03 | 서울시 공공예식장 신청 어떻게 해 | intent=venue, sido=서울 | ✅ | ✅ |
| V04 | 작은 결혼식 하고 싶은데 부산에 저렴한 장소 | intent=venue, sido=부산 | ✅ | ✅ |
| V05 | 손님 80명쯤 올 건데 강원도에 식 올릴 데 추천 | intent=venue, sido=강원, guests=80 | ❌ intent=recommend, guests=- | ✅ |
| D01 | 결혼식 사진 찍는 곳 추천해줘 | intent=vendor, item=studio | ❌ item=meal | ✅ |
| D02 | 드레스 투어 비용 얼마 정도야 | intent=vendor, item=dress | ✅ | ✅ |
| D03 | 엄마 한복 대여 어디서 해 | intent=vendor, item=hanbok | ✅ | ✅ |
| D04 | 본식 스냅 작가 괜찮은 곳 | intent=vendor, item=snap | ✅ | ✅ |
| D05 | 신랑 턱시도 빌릴 곳 | intent=vendor, item=suit | ✅ | ✅ |
| D06 | 부케랑 케이크 업체 | intent=vendor, item=props | ✅ | ✅ |
| D07 | 식대 1인당 얼마 정도 잡아야 돼? 하객 백명 (한글 숫자 하객) | intent=vendor, item=meal, guests=100 | ❌ guests=- | ✅ |
| D08 | 청첩장 몇 장 찍어야 해? 하객은 200명 | intent=vendor, item=invitation, guests=200 | ✅ | ✅ |
| D09 | 결혼식 영상 찍어주는 업체 | intent=vendor, item=video | ✅ | ✅ |
| B01 | 예산 삼천만원으로 어떻게 나눠 써야돼 (한글 숫자 예산) | intent=budget, budget=3000 | ❌ budget=- | ✅ |
| B02 | 예산 5천 정도인데 항목별로 얼마씩 써 | intent=budget, budget=5000 | ✅ | ✅ |
| S01 | 다음달에 상견례인데 뭐부터 준비해야 돼? | intent=schedule | ✅ | ✅ |
| S02 | 결혼 6개월 남았는데 지금 할 일 | intent=schedule | ✅ | ✅ |
| R01 | 결혼 준비 전체적으로 추천 좀 해줘 | intent=recommend | ❌ intent=schedule | ✅ |
| H01 | 안녕 | intent=help | ✅ | ✅ |
| H02 | 오늘 날씨 어때 | intent=help | ✅ | ✅ |
| F01 | 난 32살 예비신부고 집은 없어 (정보만 말함) | age=32, stage=engaged, homeless=True | ❌ stage=-, homeless=- | ✅ |
| A01 | 부산이요 | intent=answer, sido=부산 | ✅ | ✅ |
| A02 | 스물여덟 | intent=answer, age=28 | ❌ age=- | ✅ |
| A03 | 아직 안 했어요 | intent=answer, stage=engaged | ❌ stage=- | ✅ |
| A04 | 전세 살고 있어요 집은 없어요 | intent=answer, homeless=True | ❌ homeless=- | ✅ |
| A05 | 한 120명? | intent=answer, guests=120 | ✅ | ✅ |
| A06 | 2천5백만원 | intent=answer, budget=2500 | ❌ budget=2000 | ✅ |
| A07 | 경기도 성남이에요 | intent=answer, sido=경기 | ✅ | ✅ |
| A08 | 근데 예산은 어떻게 나눠? (되묻는 중 다른 질문) | intent=budget | ✅ | ✅ |
