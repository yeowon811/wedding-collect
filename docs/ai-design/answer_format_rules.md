# AI 답변 형식 규칙 모음 (2026-11-20 조사)

목적: "글이 너무 많아 한눈에 안 들어온다"는 문제를 풀기 위해, 대화형 UI·AI 답변 화면을 다루는 공개 가이드에서 규칙을 모으고 우리 앱에 맞게 정리한다.

주의: 검색으로 확인한 내용이며, 일부는 원문 대신 2차 글(요약 기사)로만 확인했다. 출처 칸에 표시.

## 1. 모은 규칙

### 길이
| 규칙 | 출처 | 확인 |
|---|---|---|
| 짧게, 바로 요점으로 ("Keep it short", 사용자 시간 존중) | Google Conversation Principles | 원문 요약 |
| 정보는 주되 응답은 간결하게, 이득이 분명할 때만 자세히 | Google Assistant 대화 설계 (language) | 원문 |
| 한 메시지 최대 2문장, "한 호흡 테스트". 문단처럼 보이면 너무 긴 것 → 나눔 | Salesforce Lightning Design System (대화 설계) | 원문 인용 |
| 한두 호흡에 읽을 수 있는 길이 | Amazon Alexa Haus "Be brief" | 원문 인용 |
| 한 메시지에 정보를 몰아넣지 말 것 | Google Business Messages | 원문 인용 |
| 한 문장에 메시지 하나, 앱 화면에서 한 줄을 넘지 않게, "~하고"로 두 문장 잇지 않기 | 토스 UX 라이팅 소개 글 (디자인 전문지) | 2차 글 |
| AI가 만든 글은 웹 글쓰기 기본(짧게, 훑어 읽기 쉽게)을 자주 어김. 요약보다 훑어 읽기 쉬운 형식이 먼저 | NN/g "GenAI write for the web" | 일부만 확인 |

### 구조·순서
| 규칙 | 출처 | 확인 |
|---|---|---|
| 답 먼저, 서론 없이 → 그다음 출처 → 관련 질문 | Perplexity 화면 분석 | 2차 글 |
| 출처는 본문 숫자 대신 아래 카드로 모으는 방향 | Google AI Overviews 실험 보도 (2026-06) | 2차 글 |
| 가장 작은 쓸모 있는 답 + 펼치기(과정·출처 보기) | 점진적 공개 패턴 글 | 2차 글 |
| 펼치기 버튼 이름은 구체적으로 ("자세히" 대신 "출처 보기") | 점진적 공개 패턴 글 | 2차 글 |
| 기본은 접힌 상태, 경고·출처는 너무 깊이 숨기지 않기 | 점진적 공개 패턴 글 | 2차 글 |

### 선택지·목록
| 규칙 | 출처 | 확인 |
|---|---|---|
| 한 번에 선택지 3개 (상황에 따라 3~5개) | Alexa 디자인 가이드 | 원문 요약 |
| 목록은 관련도 순, 길면 나눠서 | Alexa Haus 목록 패턴 | 원문 요약 |
| 목록 항목은 같은 형태(명사·동사)로 맞추기 | Alexa "What Alexa says" | 원문 인용 |
| 추천 칩은 최대 8개, 칩 하나 25자 이내, 짧고 행동 중심 | Google Assistant 대화 설계 (suggestions) | 원문 |
| 목록·카드에 이미 나온 선택지를 칩으로 반복하지 말 것. 칩은 목록을 좁히거나 "다른 것"을 고르는 용도 | Google Assistant 대화 설계 | 원문 |
| 말(문장)에 나온 선택지를 칩에 또 쓰지 말 것 | Google Assistant 대화 설계 | 원문 |

### 카드
| 규칙 | 출처 | 확인 |
|---|---|---|
| 제목은 짧게, 본문은 보조 정보 | Microsoft 에이전트 디자인 (Adaptive Cards) | 원문 요약 |
| 행동 버튼은 일을 진행시키는 것만 | Microsoft 에이전트 디자인 | 원문 요약 |
| 카드에 내용을 과하게 담지 말 것, 글은 간결하게 | Copilot Studio 모범 사례 | 원문 요약 |
| 모바일은 한 열 배치 | Copilot Studio 카드 가이드 | 원문 요약 |
| 데이터가 비었을 때 카드가 빈 채로 나오지 않게 처리 | Microsoft 365 Copilot 카드 문서 | 원문 요약 |

### 생성형 UI (AI가 화면을 정할 때)
| 규칙 | 출처 | 확인 |
|---|---|---|
| 정해 둔 컴포넌트 목록에서만 고르게(정적·선언형). 완전 자유 형식은 결과가 매번 달라짐 | CopilotKit 생성형 UI 패턴 | 원문 요약 |
| 디자인 토큰·허용 목록·검토를 둘 것 | 생성형 UI 패턴 글 | 2차 글 |

### 말투
| 규칙 | 출처 | 확인 |
|---|---|---|
| 해요체로 통일 | 토스 UX 라이팅 소개 글 | 2차 글 |
| 버튼은 동사 명사형 ([신청하기] [결제하기]), 행동과 이득을 함께 ("카드 쓰고 6만 원 받기") | 토스 UX 라이팅 소개 글 | 2차 글 |
| 쉽게 쓰다 위험 정보를 빼거나 지나치게 단순화하지 말 것 (토스가 받은 비판) | 디자인 전문지 기사 | 2차 글 |
| 공공 서비스 글: 명확하게, 간결하게, 일관되게, 배려하며, 정확하게 | 와이어링크 공공언어 가이드 (국립국어원 지침 + KRDS 기반) | 2차 글 |

## 2. 우리 앱 규칙 (위를 합쳐 정함)

| # | 규칙 | 근거 |
|---|---|---|
| F1 | **답 먼저:** 첫 줄은 질문에 대한 답 한 줄 (20자 안팎). 서론·필터 설명 없음 | Perplexity, Google |
| F2 | **글은 두 문장까지:** 헤드라인 + 설명 1문장. 넘으면 앱이 다시 쓰게 함 | Lightning, Alexa |
| F3 | **한 문장에 하나:** "~하고, ~이며"로 잇지 않음. 한 줄을 넘기지 않음 | 토스 |
| F4 | **숫자는 배지로:** "무료", "120명 가능 4곳"은 문장에 쓰지 않고 배지 | NN/g 훑어 읽기 |
| F5 | **카드 3개:** 관련도 순 3개, 나머지는 "4곳 더 보기" | Alexa |
| F6 | **카드는 두 줄:** 이름 + 맞는지 배지 / 핵심 값 3개. 항목 순서는 모든 카드가 같게 (지역·정원·요금) | Microsoft, Alexa |
| F7 | **칩은 좁히기·넓히기·다음 행동만:** 최대 4개 (모바일 한 줄), 칩당 12자 안팎. 카드에 있는 걸 칩으로 반복하지 않음 | Google |
| F8 | **조건은 칩으로:** 적용된 조건을 칩으로 보여 주고 ✕로 빼기. 필터 설명 문장 없음 | Google (칩으로 좁히기) |
| F9 | **자세한 건 접기:** "출처 보기", "어떻게 찾았나요" 같은 구체적 이름. 기본 접힘 | 점진적 공개 |
| F10 | **주의는 숨기지 않기:** 대상 아님·정보 없음·바뀔 수 있음은 카드 배지로 항상 보이게 | 점진적 공개, 토스 비판 |
| F11 | **블록은 허용 목록에서만:** Gemini는 정해 둔 블록(text·cards·table·ranking·steps·budget·ask·web·caution·next·sources)만 고름 | CopilotKit |
| F12 | **빈 값 처리:** 값이 없으면 빈칸 대신 "정보 없음 · 문의" 배지 + 문의처 | Microsoft |
| F13 | **말투:** 해요체, 버튼은 명사형 ("신청 페이지 열기", "4곳 더 보기") | 토스 |
| F14 | **같은 말 반복 금지:** 헤드라인 숫자를 설명·카드에서 다시 쓰지 않음 | Google (반복 금지) |

## 3. 출처
- Google Conversation Principles: https://principles.design/examples/google-conversation-principles
- Google Assistant 대화 설계 (language): https://developers.google.com/assistant/conversation-design/language
- Google Assistant 대화 설계 (suggestions): https://developers.google.com/assistant/conversation-design/suggestions
- Google Business Messages (be conversational): https://developers.google.com/business-communications/business-messages/guides/how-to/design/language?hl=en
- Salesforce Lightning 대화 설계: https://spring-20.lightningdesignsystem.com/guidelines/conversation-design/language-and-style
- Amazon Alexa Haus "Be brief": https://developer.amazon.com/alexa/alexa-haus/design-principles/be-brief
- Alexa Haus 목록 패턴: https://developer.amazon.com/en-US/alexa/alexa-haus/patterns-and-components/patterns-lists
- Alexa "What Alexa says": https://developer.amazon.com/fr/designing-for-voice/what-alexa-says/
- NN/g GenAI write for the web: https://www.nngroup.com/articles/genai-write-for-the-web/
- Microsoft 에이전트 디자인 (Adaptive Cards): https://learn.microsoft.com/en-au/agents/design-guidelines/adaptive-cards-for-agent-design
- Copilot Studio 카드 모범 사례: https://microsoft.github.io/agent-academy/recruit/08-add-adaptive-card
- Copilot Studio 카드 가이드: https://microsoft.github.io/cat-agent-skills/skills/copilot-studio-adaptive-card-builder
- Microsoft 365 Copilot 카드: https://learn.microsoft.com/en-us/plugins/api-plugin-adaptive-cards
- CopilotKit 생성형 UI: https://copilotkit.ai/generative-ui
- 생성형 UI 패턴 글: https://www.elpassion.com/blog/generative-ui-patterns
- Perplexity 화면 분석: https://www.925studios.co/blog/perplexity-design-breakdown
- Google AI Overviews 출처 카드 실험: https://www.seo-day.de/news/article/google-ai-mode-ai-overviews-sliding-carousel-for-link-cards?lang=en
- 점진적 공개 패턴: https://tracker-7ex.pages.dev/01_ai_engineering/18_human_ai_product_experience/06-progressive-disclosure/
- 토스 UX 라이팅 (디자인 전문지): https://ditoday.com/?p=151644 , https://ditoday.com/%ED%86%A0%EC%8A%A4-10%EB%85%84-%EC%89%AC%EC%9A%B4-%EA%B8%88%EC%9C%B5%EC%9D%B4-%EB%A7%8C%EB%93%A0-%ED%98%81%EC%8B%A0%EA%B3%BC-%EA%B7%B8%EB%8A%98/
- 공공언어 가이드 (KRDS 관련): https://ditoday.com/?p=148961
