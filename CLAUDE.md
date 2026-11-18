# wedding-collect: 프로젝트 맥락

이 파일은 다른 컴퓨터나 새 Claude 세션에서도 이전 기획 대화를 이어갈 수 있게 정리한 요약입니다. (최종 정리: 2026-11-15)

## 무엇을 만드나
예비부부를 위한 **공공예식장 + AI 에이전트 추천 앱 (안드로이드)**.
- 문제: 결혼 비용 부담. 공공예식장은 지역마다 신청 방법이 달라 불편하고(전국 240곳, 신청 방식 36가지), 업체 가격이 공개돼 있지 않으며, 무엇부터 할지 모름.
- 해결: 사용자가 일정·위치·예산·하객 수·결혼 방식 등을 입력하면, AI 에이전트가 등록된 데이터로 공공예식장·업체·지원 정책을 추천하고 정리해 줌. 상담 신청과 일정 조정 흐름 포함.
- 준비 항목: 드레스, 식대, 웨딩촬영, 스냅, 청첩장, 소품(부케·케이크), 본식 영상, 정장, 어머니 한복, 혼주 메이크업, 메이크업
- 추가 기능: 지역·나이·결혼 방식에 맞춘 **청년 결혼 지원 정책 추천**
- 나중 아이디어: 같은 날 같은 장소의 여러 팀이 장식비를 함께 부담하는 매칭

## 공모전 (해커톤)
- 2026 대한민국 청년 CAREER FAIR AI 해커톤 (대한상공회의소): https://korcham-careerfair.com/hackathon
- 주제: AI 에이전트로 푸는 청년의 일·생활 문제. **개인 참가**
- **예선 제출 마감: 2026-11-23(월) 17:00.** 마감 후 기능·프롬프트·데이터 변경 불가. 본선은 12-07(10분 발표·시연 + 5분 질의응답)
- 제출물: 프로젝트 소개서(양식 있음), AI 활용 내역, **심사위원이 실행할 수 있는 MVP**
- 배점: 문제 정의 20, **AI 활용 25** (그중 오류·불확실성 대응 5), 창의성 20, **구현 20**, 확장성 15
- 규칙: 외부 자원은 출처·라이선스를 표로 기재해야 함. **실제 개인정보를 외부 AI API로 보내는 것은 금지** (가상 데이터 사용)

## 지금까지 정한 것
- 개발 도구: **Flutter** (Kotlin + Compose에서 변경). 심사위원용으로 APK와 시연 영상 제출
- 범위: **전국 단위.** 시연 지역은 일부러 아직 정하지 않음
- 대전·제주에는 공공예식장이 없음 (확인 완료)
- 업체 가격: 실제 업체(103곳)에는 **가격을 붙이지 않음.** 가격·패키지·상담 예약은 "시연용" 표시를 단 **가상 업체**로 보여줌
- AI 원칙: 가격과 대상 여부는 DB 값과 규칙으로 판정하고, AI는 정리·설명만 함. 출처와 확인 날짜를 표시. 모르는 값은 "확인 필요"로 표시
- 정책: 자격 원문에서 AI로 구조화 항목(지역, 나이, 혼인 조건, 소득, 무주택, 지원 유형·금액)을 뽑은 뒤 사람이 검수
- 수용 인원·대관료: 사용자가 나중에 수집해서 제공 예정 (11/21쯤까지). 그때까지 DB에서 비워 둘 수 있게 설계
- 디자인: Flutter 기본 Material 느낌을 피하고 직접 정한 디자인을 적용할 예정. **사용자가 버튼 등 컴포넌트 기준을 정리하는 중**이라, 받은 뒤 시안 3가지(웜 로즈 / 세이지 그린 / 모노톤·골드)를 만들어 고르기로 함
  - 참고 후보: `flutter/samples`, `rydmike/flex_color_scheme`, `nank1ro/flutter-shadcn-ui`, `forus-labs/forui`, Pretendard 폰트
  - **UI 뼈대 확정 (2026-11-15): `mitesh77/Best-Flutter-UI-Templates`의 `hotel_booking` 템플릿.** 목록(hotel_home_screen, hotel_list_view), 필터(filters_screen, range/slider), 날짜 선택(calendar_popup_view, custom_calendar) 구조를 예식장·업체 찾기에 활용
    - 라이선스: MIT + "판매·수익 목적 금지" 문구 → 출처 표에 기재. 템플릿 이미지(assets)는 쓰지 않음
    - 구조만 가져오고 색상·글꼴·버튼은 우리 테마(`hotel_app_theme.dart` 대신 공용 테마)로 교체

## 데이터 (사용자가 직접 수집, 저장소에는 없음)
원래 위치: `C:\Users\User\OneDrive\문서\카카오톡 받은 파일\`. 다른 컴퓨터에서는 따로 복사해야 함.
- `전국 공공예식장 및 연계업체 현황 (2).xlsx` ← **최신 기준 파일**
  - 공공예식장 목록: 운영 중 240곳 (좌표, 운영상태, 예약방식 36종, 예약문의, 예약링크, 예약 이동 경로 안내)
  - 연계업체 마스터: 103곳 (스드메·디렉팅 34, 식사·케이터링 29, 사진·스냅 24, 사회·진행 16). 가격 없음, 휴대폰 번호 21건
  - 예식장-업체 거리매칭: 1,920건
  - 운영중단·제외 현황: 7곳 (근거 링크 포함)
- `전국 공공예식장 및 연계업체 현황 (1).xlsx`: (2)와 같고 좌표만 없음
- `youth_wedding_support_2026.xlsx`: 정책 177건 (정책명, 부처, 지원 자격 원문, 신청 링크). 공공예식장 관련 정책 14건
- 출처: 공유누리(eshare.go.kr), 서울마이웨딩(wedding.seoulwomen.or.kr), 복지로, 온통청년, 각 지자체 등. 소개서 출처 표에 정확히 기재해야 함

## DB 설계 초안
- `venue`: id, sido, sigungu, name, address, lat, lng, status, booking_type(ONLINE/FORM/PHONE_VISIT/CENTER), booking_method, booking_contact, booking_url, detail_url, booking_steps, capacity(null 가능), rental_fee(null 가능), source_url, verified_at
- `venue_excluded`: 제외 사유와 근거 링크
- `vendor`: 실제 업체 (가격 없음) / `venue_vendor_match`: 예식장-업체 거리 매칭
- `demo_vendor`, `demo_slot`: 시연용 가상 업체와 상담 가능 시간
- `policy`: 원문 + 구조화 항목 + reviewed / `policy_venue_link`: 예식장 관련 정책 연결
- `user_profile`: 기기에만 저장 / `checklist_item`: 예식일 기준 체크리스트
- 저장 방식: 정적 데이터를 JSON으로 앱에 넣고 로컬 DB에 불러옴. AI에는 조건과 후보 ID·요약만 전송. API 키 보호용 중계 서버 여부는 미정

## 개발 환경 (현재 PC, 2026-11-15 확인)
- Flutter 3.50.0 (Dart 3.14.0) at `C:\Users\LG\flutter`, Android SDK 36 + Android Studio, 에뮬레이터 `Medium_Phone_API_37.0`, Chrome. `flutter doctor` 이상 없음
- NDK 28.2.13676358 설치함 (APK 빌드에 필요)
- **에뮬레이터는 아직 실행 불가:** "Android Emulator hypervisor driver"가 없음 → Android Studio SDK Manager > SDK Tools에서 설치(관리자 권한) 또는 실제 폰 USB 디버깅으로 테스트. 그 전까지는 Chrome(`flutter run -d chrome`)으로 확인
- Figma MCP는 나중에 시간 나면 연결해 보기로 함 (지금은 사용 안 함)

## 코드 구조 (2026-11-15 시작)
- Flutter 프로젝트를 저장소 루트에 생성 (`wedding_collect`, 플랫폼 android·web)
- 기능별 폴더 구조:
  - `lib/app/`: 앱 시작(app.dart), 하단 탭 5개 틀(main_shell.dart: 예식장 / 정책 / 업체 / 체크리스트 / AI 상담)
  - `lib/core/`: 공용 테마(`theme/app_colors.dart`에 색 모음 → 시안 정해지면 여기만 교체), 공용 위젯(배지, 준비 중 화면), 도우미
  - `lib/data/`: 모델(venue.dart)과 저장소(venue_repository.dart, JSON 읽기)
  - `lib/features/<기능>/`: 기능별 화면. 지금은 `venue`(목록·검색·지역/예약유형 필터·상세)만 구현, 나머지 4개는 "만들 예정" 안내 화면
  - `lib/template/hotel_booking/`: 원본 템플릿 참고용 (앱에서 사용 안 함)
- 데이터 변환: `python -I tools/convert_venues.py "../공공예식장_eshare수집.xlsx"` → `assets/data/venues.json` (예약방식 36가지 → ONLINE 131 / FORM 81 / CENTER 15 / PHONE_VISIT 13)
  - **2026-11-16: `공공예식장_eshare수집.xlsx`가 새 기준 파일.** (2) 파일의 13개 열 + 공유누리 수집 28개 열(정원·요금·요금 상세·운영시간·접수·심사·준비시간·이용대상·실내외·주차·면적·사진 5장). 다른 3개 시트는 (2)와 동일
  - 수집 117곳 / 미수집 123곳. 정원 숫자 84곳(‘1명’ 25건은 eshare 등록 오류로 보고 null, ‘문의’·‘시간별 상이’ 7건도 null), 요금 114곳(무료 43), 사진 113곳(202장, 공유누리 주소 직접 사용)
  - 검증: `python -I tools/validate_venues.py "../공공예식장_eshare수집.xlsx" --reference "../전국 공공예식장 및 연계업체 현황 (2).xlsx" [--check-images]` → `docs/data-validation/venues_report.md`, 추가 수집 목록 `docs/data-validation/venues_to_collect.csv`(157곳)
  - **2026-11-16: `공공예식장_더아결수집.xlsx` 추가.** 대상 123곳 = 공유누리 미수집 123곳과 정확히 같음(겹침 없음). 수집 65곳(서울마이웨딩), 58곳은 여전히 미수집(인천·울산·세종 등 지자체 자체 예약처)
    - 열: 수용인원(범위 '100명~200명' → capacityMin/capacity), 대관료('무료…'로 시작하면 0, 그 외 원문), 피로연, 예식가능/불가일(26·27년), 주차, 협력전문웨딩업체(실제 업체 이름과 연결 164/268건), 기타 안내, 전체 이미지 URL(최대 32장)
    - **AI 생성 이미지 20장(18곳)**: 파일명 'AI'·'OPENAI_IMAGE'로 판별(수집 파일 표시와 일치). **2026-11-17: 실제 사진이 있는 14곳은 AI 이미지를 변환 때 삭제, 실제 사진이 없는 4곳(6장)만 남김. 앱의 AI 배지·안내 문구는 뺌**
    - 변환: `python -I tools/convert_venues.py "../공공예식장_eshare수집.xlsx" "../공공예식장_더아결수집.xlsx"`, 검증: `validate_venues.py ... --supplement "../공공예식장_더아결수집.xlsx"`
    - JSON 필드 `eshareStatus` → `collectSource`(공유누리/서울마이웨딩(더아결)) + `collectStatus`로 바꿈
  - **2026-11-16: `공공예식장_나머지.xlsx` 추가** (기관 페이지 직접 수집). 대상 58곳 = 앞 두 출처 미수집분과 정확히 같음, 기본 13개 열도 같음
    - 수집상태: 수집완료 15 · 수집완료(일부) 6 · 수집완료(공통) 1 · 시설별 정보 없음 27(지원 사업 공통 안내만) → 49곳 수집, **접근 차단 8(세종 가족센터)·접속 실패 1(전남여성가족재단) → 미수집 9곳**(상세 화면에 실패 사유 표시)
    - 새 필드: `hoursText`(이용시간 원문), `reservationInfo`(예약방법), `selection`(선별방법), `inquiry`(시설 문의), `programInfo`(공통 지원 사업 안내: 국립공원 숲 결혼식·인천 맺어드림·울산 U:ON 웨딩·충북 축복웨딩). `collectSource` = `기관 안내 페이지(도메인)`
    - 정원 문구 처리: '50명 이하' → 50, '250 여명'·'350명 정도' → 숫자 + "대략적인 값" 주의. 요금: '대관료 : 무료'·'무료대관…' → 0, '없음' → 0(주의 표시), '유료 450,000원(원/회차 당)' → 450000, '협의 후 결정'·프로그램별은 원문
    - 파주(pajumaru.com) 사진 2장은 사이트 인증서 문제로 https 접속 실패(브라우저는 열릴 수 있음, 안드로이드는 대체 이미지)
    - 전체: 240곳 중 231곳 수집, 정원 159 · 요금 183(무료 110) · 사진 180곳
  - 변환: `python -I tools/convert_venues.py "../공공예식장_eshare수집.xlsx" "../공공예식장_더아결수집.xlsx" "../공공예식장_나머지.xlsx"` (추가 파일 종류는 열 이름으로 자동 판별)
  - 검증: `python -I tools/validate_venues.py "../공공예식장_eshare수집.xlsx" --supplement "../공공예식장_더아결수집.xlsx" --supplement "../공공예식장_나머지.xlsx" --reference "../전국 공공예식장 및 연계업체 현황 (2).xlsx"`
  - 웹에서는 공유누리 이미지에 CORS 헤더가 없어 `WebHtmlElementStrategy.fallback` 사용. 사진 이용 조건(공공누리 유형)은 소개서 출처 표에 적기 전에 확인 필요
- `tools/xlsx_reader.py`: openpyxl 없이 xlsx를 읽는 표준 라이브러리 도우미
- 정책: `python -I tools/convert_policies.py "../youth_wedding_support_2026.xlsx"` → `assets/data/policies.json`
  - 지역·나이·혼인 N년·예비부부 가능·소득·무주택을 **정규식으로 1차 추출** (`extractedBy: rule`, `reviewed: false`). 다음 단계로 AI 추출 + 사람 검수 예정
  - 고성군 정책 2건은 강원/경남 구분이 안 돼 엑셀 순서로 **경남 추정** → 확인 필요
  - 판정은 `lib/features/policy/policy_matcher.dart` 규칙으로 함 (확실히 안 되는 것만 제외, 소득·무주택 등은 "조건 확인 필요")
- 업체: `python -I tools/convert_vendors.py "../전국 공공예식장 및 연계업체 현황 (2).xlsx"` → `vendors.json`(실제 103곳, 가격 없음), `venue_vendor_matches.json`(1,920건), `demo_vendors.json`(시연용 561곳 = 17개 시도 × 11개 항목 × 3곳, 이름 앞 `[시연]`, 고정 시드로 임의 생성한 가격·평점)
- 탭별 기능 (2026-11-15 기준 모두 구현):
  - 예식장: 검색 + 시도 칩 → 시군구 칩(가나다순, 서울이면 강남구·강동구 …). **예약유형 칩·조건 칩(하객 수용/무료/사진)은 사용자 요청으로 뺌 (2026-11-16)**. 상세(신청 단계, 예약/전화, **관련 예식 정책**, **근처 실제 업체**)
  - 정책: 내 상황(지역·나이·예비/신혼·연차) → 규칙 판정, 분류 칩, 상세(맞는 부분/확인할 조건/원문/링크)
  - 업체: 지역 칩 → 항목 칩, "가격 비교(시연용)" / "실제 연계 업체" 전환. 시연용은 예산 비교, 비교 담기(같은 항목 최대 3곳)→비교표, 상담 신청(날짜·시간 선택, 월요일 휴무·일부 마감은 고정 패턴), 계약 완료 표시
  - 체크리스트 (2026-11-17 편집 가능하게 개편): 결혼 정보(예식일·지역·총예산·하객 수, D-day) / 예산(총예산 수정, 계약·결제 완료 금액 + 예정 금액 → 남은 예산, 추천 예산 표시는 뺌) / 준비 항목(기본 11개 + 추가·삭제·되돌리기, 항목마다 상태 미정·상담 중·계약 완료·결제 완료, 금액, 업체 이름) / 내 상담 일정 / 예식일 기준 할 일(기본 20개 + 추가·삭제, 계약·결제 완료 시 자동 체크). 상태는 AppState.items·tasks (PlanItem, ChecklistTask)
  - AI 상담 (2026-11-16 구조 개편, 상세: `docs/ai-architecture.md`): ⓪ 내 정보 입력(`profile_setup_view.dart`, `UserProfile`) → 시작 시 전체 추천 → ① 질문 이해(`agent/understanding.dart`, 지금은 `RuleUnderstander`) → ② 내 정보+대화 기억 합치기 → ③ 목적별 필수 정보가 없으면 하나씩 되묻기(선택 버튼 + "잘 모르겠어요") → ④ `agent/consult_tools.dart`로 데이터 조회 → ⑤ 기준·근거·출처·다음 질문 버튼과 답변(`agent/consult_agent.dart`)
    - 사용자 요구: 상담 전에 내 정보 입력, 시작하면 추천, "20대 청년이 신혼생활에 받을 수 있는 정책?" 같은 질문은 지역 등 빠진 정보를 되물어 가며 답변
    - **Gemini 연결 (2026-11-16):** Firebase AI Logic(Gemini Developer API, 무료), 프로젝트 `wedding-collect`, 모델 `gemini-3.5-flash-lite`. ① 질문 이해(JSON)와 ⑤ 답변 문장만 Gemini, 실패하면 규칙 기반. 답변 숫자가 조회 결과에 없으면 Gemini 문장을 버림. 코드 `agent/gemini_client.dart`, 설정 `lib/firebase_options.dart`(`flutterfire configure --project=wedding-collect --platforms=android,web`로 다시 만들 수 있음)
    - **실행할 때 `--dart-define-from-file=secrets.json` 필수** (App Check 디버그 토큰, 저장소 제외. 없으면 Gemini 호출이 거절되고 규칙 기반으로만 동작). 토큰은 콘솔 App Check 웹·안드로이드 앱에 등록됨
    - 평가: `test/eval/` 질문 42개, 결과 `docs/ai-eval/` (질문 이해: 규칙 29/42 → Gemini·앱 42/42, 1.5초 / 답변 문장: 숫자·표시어 검사 통과 4/15 → 15/15)
    - **대화 흐름 (2026-11-17):** 최근 3턴 요약 상태 + 규칙 보완(평가 32/32). "두 번째 거"·"그중에 무료만"·"더 싼 곳"·"그럼 부산은?" 처리, 이어서 하기 때 기억 복원. `agent/conversation_context.dart`, 평가 `test/eval/context_*`, `docs/ai-eval/context_report.md`
    - 정책 판정(`policy_matcher.dart`)은 나이 범위(20대 등)·무주택 여부도 반영
- 후기 (2026-11-15 추가): **시연용 업체에만** 있음. `lib/data/repositories/review_repository.dart`가 업체 ID 고정 시드로 생성 (별점 분포는 업체 평점·후기 수와 정확히 일치, 최근 30개 표시). 업체 상세에 요약(평균·분포·키워드)+최근 3개, 전체 보기(정렬·별점 필터), 상담/계약한 업체만 후기 쓰기. **실제 업체에는 가짜 후기를 만들지 않음** (안내 문구만 표시)
- 공유 상태: `lib/data/app_state.dart`
- **회원가입·로그인 (2026-11-17):** Firebase 이메일/비밀번호 인증 + Firestore `users/{uid}` 문서에 내 정보 자동 저장(변경 0.8초 후). `lib/data/account_service.dart`(AccountMode: unavailable/signedOut/guest/signedIn), `user_data_codec.dart`(저장 형식, 이메일은 저장 안 함), `lib/features/auth/login_screen.dart`(로그인·회원가입·비밀번호 재설정·**로그인 없이 둘러보기**, 가입 시 개인정보 동의), 각 탭 오른쪽 위 계정 버튼(저장 시각·로그아웃). 로그아웃하면 상태 초기화
  - **AI 상담 대화도 저장** (최근 60개, AppState.chat): 사용자 문장의 전화번호·이메일은 가려서 저장, 결과 카드는 ref(`venue:H078` 등)로 다시 열기(`chat_card_link.dart`), 되묻기 상태·버튼은 저장 안 함. 다시 들어오면 "지난 상담이 있어요 → 이어서 하기 / 새로 시작하기", 상단 "새 상담" 버튼. 로그아웃하면 대화도 지움
  - 보안 규칙 `firestore.rules`(본인 문서만 읽기·쓰기), 배포: `firebase deploy --only firestore:rules --project wedding-collect`
  - 콘솔 준비: Authentication 이메일/비밀번호 사용 설정, Firestore 데이터베이스(asia-northeast3) 생성
  - Firebase가 없는 테스트 환경에서는 로그인 화면 없이 바로 앱(unavailable). 시연 링크(?tab= 등)로 열면 둘러보기로 시작
- **목록 배치 (2026-11-17):** 예식장·정책·업체 목록은 2열 격자(쇼핑앱식, 넓은 화면은 열 증가). `lib/core/widgets/grid.dart`(GridSpec·TileGrid). 예식장 카드: 정사각형 사진→지역→이름→대관료(굵게)→정원 / 업체: 4:3 항목 아이콘 면 + 비교 담기(+) 버튼→가격→평점 / 정책: 분야·지역→이름→자격 요약→확인할 것
- **업체 예산 (2026-11-17):** '추천 예산'(총예산 × 항목 비율)은 쓰지 않음. 체크리스트 준비 항목에 정한 금액(`AppState.budgetOf`)이 그 항목 예산 → 업체 상세·비교표·AI 상담에서 '내 ○○ 예산 N만원 안/초과', 예산 안 업체를 먼저 추천. 금액이 없으면 비교하지 않고 '준비 항목에 금액을 정하면…' 안내. 1인·100장 단위 가격만 '하객 N명 기준 약 N만원' 표시. AI 상담의 예산 질문(시작 추천 포함)도 비율 배분 대신 준비 항목에 정한 금액·계약 완료/계약 전 합계·남은 예산·금액 미정 항목을 보여줌, '체크리스트에서 금액 정하기' 버튼(action open_checklist)
- **업체 탭 통합 (2026-11-17):** 시연용/실제 연계업체 전환을 없애고 한 목록(실제 업체 먼저: 공식전담 → 사진 있는 곳, 그다음 [시연] 업체). 항목 칩 = 준비 항목 11개 + 사회·진행, 실제 업체 분류는 `VendorCategory.coversReal`로 칩에 연결(스드메→드레스·메이크업·웨딩촬영, 사진·스냅→웨딩촬영·스냅·본식 영상, 케이터링→식대). 공식전담 업체는 `OfficialMark`(✓ 공식전담(서울시) 등). 카드 `RealVendorTile`(가격 문의)
  - **실제 업체 대표 사진:** `python -I tools/collect_vendor_images.py` → `assets/data/vendor_images.json`. 업체 홈페이지의 og:image(없으면 본문 첫 큰 사진) **주소만** 기록, 파일은 복사 안 함. 상세 화면에 '사진: 도메인' 출처 표시. 103곳 중 65곳 수집 → 눈으로 검수해 안내·광고·깨진·잘린 로고 11장 제외(`REVIEW_EXCLUDE`) → **54곳**. 인스타그램·링크 모음 등은 아이콘
  - **하위 페이지 사진 (11-17):** `collect_vendor_images.py --deep`로 첫 화면에 사진이 없던 업체의 갤러리·포트폴리오 등 하위 페이지까지 찾음 → 검수 후 5곳 추가(`DEEP_EXCLUDE`로 6곳 제외) → **59곳**
  - **무료 사진 (11-17):** `tools/collect_stock_images.py`(Wikimedia Commons, CC0·PD·CC BY·CC BY-SA) → `assets/data/stock_images.json`(12개 묶음 44장, 주소·저작자·라이선스·출처). 파일은 받지 않고 앱이 위키미디어에서 불러옴(대량 다운로드 시 429 차단됨). `lib/data/repositories/stock_photos.dart`가 업체 ID로 고정 선택: [시연] 업체는 항목 사진, 사진 없는 실제 업체는 분류별 참고 사진(상세에 '참고 이미지 · 업체 사진 아님'). 상세 사진 아래 저작자·라이선스 표시. 화면 위젯 `vendor/widgets/vendor_photo.dart`
  - Gemini 이미지 생성은 무료 요금제 한도가 없어(quota 0) 쓰지 않음
  - 주의: 업체 사진은 저작권 허락을 받지 않은 이미지라, 소개서 출처 표에 '각 업체 홈페이지(대표 이미지 링크)'로 적고 필요하면 빼야 함
- **비용 기준 데이터 (2026-11-17):** 사용자가 만든 `../업체_요소.xlsx`(웨딩옵션 22개 단가: 실속·공공 표준가 / 일반 평균가 / 숨은 추가금, 출처·지원 연계). `python -I tools/convert_options.py "../업체_요소.xlsx"` → `assets/data/wedding_options.json`(만원, 추가금 내역에서 addOns 추출). 엑셀 합계 줄은 수식이라 앱에서 계산. 정책 시트(12건)·대시보드 시트는 아직 안 씀
  - **[시연] 업체 가격 재생성:** `convert_vendors.py`가 wedding_options.json 기준으로 등급(실속 35%·표준 40%·프리미엄 25%)을 뽑고 기준가 주변 범위를 무작위 생성(가격 전용 시드, 이름·평점·후기 수는 그대로). 업체마다 `tier`, `addOns`(±30%). 식대는 1인, 청첩장은 100장 단위로 나눔
  - **업체 상세 추가 옵션:** `AddOnPicker` 체크하면 '옵션 포함 예상' 금액·내 예산 비교가 바뀜
  - 결혼 비용 시뮬레이터는 만들었다가 사용자 요청으로 삭제함 (2026-11-18). 단가 데이터(wedding_options.json)는 시연 업체 가격·추가 옵션 기준으로 계속 씀
- **찜 (2026-11-17):** 예식장·업체·정책 카드와 상세 화면에 하트(`core/widgets/favorite_button.dart`, ref = `venue:`/`vendor:`(시연)/`real:`(실제)/`policy:`), 예식장·정책·업체 탭 상단 하트 → `features/favorites/favorites_screen.dart`(종류별 모아 보기, 시연 링크 `?page=favorites`). AppState.favorites로 계정 저장
- **할 일 캘린더 (2026-11-17):** 체크리스트 '예식일 기준 할 일' 카드에는 가장 가까운 남은 할 일만(D-남은 날·제목·마감일·예식 D-n, 시기 지난 개수, 완료 n/N) + [할 일 추가]·[캘린더로 보기]. 카드를 누르거나 버튼 → `features/checklist/task_calendar_screen.dart`. 월 달력(일요일 시작)에 할 일 마감일(예식일 − D)·상담 일정·예식일을 색 점으로 표시(할 일 파랑·시기 지남 주황·완료 회색·상담 초록·예식일 분홍), 날짜를 누르면 그날 일정 + 체크, '이 날 할 일 추가'(D-값으로 저장), 아래 이번 달 일정 목록 + 접히는 '전체 할 일'(체크·삭제·되돌리기). 시연 링크 `?page=calendar`
- **예식장 지역 선택 (2026-11-17):** 시도 칩을 누르면 시군구 선택창(3열 격자, '서울 전체' 포함) → [확인]. 목록 위에 펼쳐지던 시군구 칩은 없앰. 고른 시군구는 칩에 '서울 · 강남구 ▾'로 표시, 다시 누르면 선택창. 시군구가 1곳뿐인 시도는 바로 적용
- **정책 공고 카드 (2026-11-17):** 시안(test3)처럼 배너 그림 + [지역] 정책명 + 기간. `features/policy/widgets/policy_banner.dart`(분야별 색·그림: 예식 분홍·장려금 주황·주거 파랑·검진 초록·교육 보라, 기관·접수 상태·괄호 앞 이름·괄호 안 설명·기간 알약). 휴대폰 1열(TileGrid minColumns 1), 상세 화면 맨 위에도 배너
  - **기간은 데이터에 없어 정직하게 표시:** 전국 사업(대출·세제·검진)은 '상시 신청', 지자체 사업은 '2026년 12월 31일(목) 까지 · 예산 소진 시 마감'(2026년 사업 기준), 상세에 '정확한 신청 기간은 기관 공고에서 확인'. 실제 마감일을 모으면 Policy에 필드 추가해 바꾸기
- **AI 상담 내 정보 입력 (2026-11-17):** 거주 지역은 입력칸+드롭다운(`DropdownMenu`, 글자 치면 목록 좁혀짐, 고르면 적용), 하객 수·총예산은 `NumberConfirmField`(입력칸 + [확인], 범위 밖이면 안내, '하객 120명으로 저장했어요'). `core/widgets/inputs.dart`. 체크리스트·시뮬레이터는 여전히 `PresetPicker`(칩 + 직접 입력)
- **체크리스트 빈 상태로 시작 (2026-11-17):** 결혼 정보(예식일·지역·총예산·하객)는 `WeddingPlan.entered`에 입력한 항목만 표시('입력하기', D-?), 값은 계산용 기본값을 그대로 가짐(업체·시뮬레이터 내부 계산). 예식일 전엔 할 일 날짜·캘린더 계산 안 함, 총예산 전엔 남은 예산 대신 안내. 할 일은 빈 목록으로 시작 → [추천 할 일 20개 불러오기](`AppState.loadRecommendedTasks`)·[할 일 추가]. 준비 항목 11개는 유지. AI 상담 '뭐부터?'는 할 일이 없으면 추천 목록 기준. 예전 저장본은 저장된 값을 입력한 것으로 봄. 시연 링크 `?demo=1`은 추천 할 일도 불러옴
- **체크리스트 ↔ AI 상담 연동 (2026-11-17):** `AppState.updatePlan`이 내 정보(profile)에도 입력한 값(지역·하객·총예산·예식일)을 넣고, AI 상담 내 정보 화면은 값을 바꿀 때마다 `updateProfileDraft`로 체크리스트(plan)에 바로 반영, 화면이 열려 있는 동안 바깥 변경도 받아 옴. 상담 에이전트는 답할 때마다 앱에서 바뀐 값만 대화 기억에 반영(`_syncFromApp`, 대화에서 말한 값은 덮지 않음)
  - 체크리스트 입력 창: 지역은 입력칸+드롭다운, 총예산·하객은 `NumberConfirmField`, 할 일 추가의 '언제까지'는 숫자 입력칸('예식 ○일 전'). 예산 카드의 총예산 버튼·추천 할 일 불러오기 버튼은 없앰(`loadRecommendedTasks`는 시연 링크·테스트용으로만 남김)
- **찜 = 후보 → 체크리스트 (2026-11-17):** `lib/data/candidates.dart`(Candidates.forItem): 준비 항목마다 찜한 시연 업체(같은 항목)·실제 업체(coversReal)·예식장을 후보로 모음. 항목 줄에 '후보 n곳 · 최저~최고 만원 ›'(누르면 후보 목록 → 상세), 상태 `ItemStatus.candidate`('후보') 자동(찜 생기면 미정→후보, 다 빼면 후보→미정). 체크리스트를 열 때 업체·예식장 데이터를 읽어 둠
- **예식장 체크리스트에 추가:** 예식장 상세 [체크리스트에 추가](추가 후 '체크리스트에 추가됨 (누르면 취소)') → 체크리스트 맨 위 '예식장' 항목(id `venue`, AppState.chosenVenueId) 생성·이름·대관료(만원), 상담 중, 지역 미입력이면 채움, 할 일 t02 체크. 항목 줄에 정원·하객 수용 여부. 예식장을 찜만 해도 예식장 항목이 생김
- 내 결혼 견적서 A·B안은 만들었다가 사용자 요청으로 삭제함 (2026-11-17)
- **정책 탭 내 상황 (2026-11-17):** 따로 보관하던 값 대신 내 정보(AppState.profile)를 그대로 씀 → AI 상담·체크리스트와 연동. 지역·나이·결혼 단계가 모두 비어 있으면 '아직 입력하지 않았어요' + [입력하기], 판정 없이 전체 정책 177건(카드에 '내 상황을 입력하면 확인해 드려요'). 입력 창의 지역은 입력칸+드롭다운, 고치면 `updateProfileDraft`
- **거주 지역 시·군·구 (2026-11-17):** `UserProfile.sigungu`(계정 저장), `kSigunguBySido`(`core/utils/region.dart`, 2026 행정구역·시 단위·인천 개편 반영, 정책 데이터 이름과 모두 일치 테스트), 입력 위젯 `core/widgets/region_fields.dart`(시·도 → 시·군·구 두 칸 드롭다운, 시·도 바꾸면 시·군·구 비움). 정책 탭 내 상황·AI 상담 내 정보에서 사용. 판정: 시군구를 알면 같은 시군구 정책은 확인 없이 '경기 수원시 거주', 다른 시군구 정책은 제외, 모르면 예전처럼 '○○ 주민등록 필요'. 체크리스트 지역(시도)을 바꾸면 시군구 비움
- **준비 항목 상세 (2026-11-18):** 항목 줄 전체를 누르면 `showItemDetail` 시트: '담은 곳'(체크리스트에 추가한 예식장·계약한 업체를 파란 테두리 큰 카드로 먼저, 그다음 찜한 후보 카드 + 하트로 빼기, 누르면 상세) → [○○ 업체 찾아보기](업체 탭을 그 항목으로 열기: `VendorScreen.categoryRequest`) → 진행 상태·금액 + [상태·금액 수정](기존 편집 창). 항목 줄은 '담은 곳 · n곳'·› 표시, [+ 항목 추가]는 카드 제목 오른쪽(제목 '준비 항목 · n/N 완료'). 업체 상세(시연·실제)에도 [체크리스트에 추가](= 찜, 항목 후보)
- **담은 곳마다 상태·단계 막대 (2026-11-18):** 상태는 항목이 아니라 담은 곳(ref)마다 `AppState.placeStatus`(후보·상담 중·계약·결제 완료), 계약 금액 `placeAmount`, 계약일 `placeDate`, 직접 추가한 곳 `manualPlaces`(ManualPlace, ref `manual:id`) — 모두 계정 저장. 항목 상태 = 담은 곳 중 가장 앞선 단계(`recomputeItem`), 계약은 항목마다 한 곳(다른 곳은 상담 중으로), 계약한 곳 이름·금액이 항목에 들어가 예산 반영, 시연 업체면 contracts도 맞춤. 업체 [계약 완료 표시]·상담 신청·예식장 [체크리스트에 추가]도 이 규칙(예식장 '정하기'는 없앰, chosenVenueId는 계약한 예식장)
  - 목록(A안): 줄마다 '이름 · 금액'(계약) / '상담 n곳 · 후보 n곳' / '아직 담은 곳 없음' + `StageBar`(●●●○ 4칸, 색: 후보 파랑·상담 주황·계약 초록) + ›
  - 항목 상세: 계약 전엔 담은 곳 카드마다 상태 칩, 계약하면 그 한 곳만 초록 큰 카드(계약일, [결제 완료]·[계약 취소]·[금액 수정]) + '다른 후보 n곳 보기' 접힘. 아래 [+ 추가](직접 추가: 이름·금액)·[찾아보기], 작은 '항목 이름 변경·삭제'. '진행 상태·금액' 줄은 없앰
- **찜과 체크리스트 분리 (2026-11-18):** 하트(`favorites`)는 찜 목록에만, 체크리스트 담은 곳은 `AppState.checklistRefs`(업체·예식장 상세 [체크리스트에 추가] = `toggleChecklist`, 상담 신청·계약 완료 표시도 여기에 담음). 후보 계산(`Candidates.forItem`)은 checklistRefs 기준. 담은 곳 카드의 하트 → ✕(`removePlace`, 찜은 그대로). 계정에 따로 저장, 예전 저장본(checklistRefs 없음)은 찜(정책 제외)을 체크리스트로 옮김. 위의 '찜 = 후보' 설명은 이 규칙으로 바뀜
- 테스트: `flutter test` (탭 전체, 비교·상담·계약 흐름, 데이터 건수, 상담 의도별 답변)
- **디자인 확정 (2026-11-16): 시안 A "클린 미니멀"** (시안 비교: https://claude.ai/artifact/FqvJzq1vPsHqxJiCKRUZzH). 흰 바탕 + 진한 회색 글자 + 파랑 포인트(#3B5BDB) 하나, 그림자 대신 회색 면·1px 테두리, 글꼴 Pretendard(`assets/fonts`, OFL). 색은 `app_palette.dart`/`app_colors.dart`, 컴포넌트 규칙은 `app_theme.dart` 상단 주석. 시안 전환 버튼은 삭제
  - 버튼: 화면당 주 버튼(파랑) 1개, 보조는 테두리. 상세 화면의 주요 행동은 **아래 고정 `BottomActionBar`**(+ `ActionPair` 보조·주) — `lib/core/widgets/inputs.dart`
  - 입력: 나이처럼 정확한 숫자는 **슬라이더 대신 `StepperField`**(−/+·직접 입력), 하객·예산은 `PresetPicker`(자주 쓰는 값 칩 + 직접 입력), 2~3개 중 고르기는 `ChoiceRow`, 묶음 제목은 `FormSection`(아이콘 없음)
  - 글자: 본문 15·설명 13 이상, 가장 연한 회색(textHint)은 입력 안내에만. 줄마다 아이콘·색 배지 남발 금지(정보는 이름·값 두 칸)
  - 로딩은 `SkeletonList`, 결과 없음은 `EmptyState`(원인에 맞는 다음 행동 버튼)
  - 화면 캡처: `flutter build web` → `python -I -m http.server 8095 --directory build/web` → `node tools/screenshots.mjs <폴더> "?tab=0" "?demo=1&tab=4" "?venue=H078" "?vendor=D0001" "?demo=1&policy=0"` (`|x,y`를 붙이면 그 위치를 누른 뒤 캡처, `WAIT_MS`로 대기 시간). 시연 링크는 `lib/app/demo_links.dart`

## 배포 (2026-11-17)
- **웹: https://wedding-collect.web.app** (Firebase Hosting, `firebase.json`의 hosting: build/web, SPA rewrite)
- 다시 올리기: `flutter build web --release --dart-define-from-file=secrets.json` → `firebase deploy --only hosting --project wedding-collect`
- 웹 제목·설명: `web/index.html`, `web/manifest.json` (결혼 준비 도우미)
- 캐시: 앱 코드·데이터·첫 화면은 no-cache(배포 후 새로고침하면 바로 반영), 글꼴·그림만 하루 저장 (`firebase.json` headers)
- 주의: 배포본에 App Check 디버그 토큰이 들어감 (무료 요금제라 비용 위험은 없고 최악은 무료 사용량 소진). 웹은 reCAPTCHA 제공자로 바꾸는 것이 안전. 공모전 후 콘솔에서 토큰 삭제
- 캡처 도구로 배포본 확인: `BASE_URL=https://wedding-collect.web.app/ node tools/screenshots.mjs <폴더> "?demo=1&tab=4"`

## 다음 할 일
1. 사용자의 디자인 기준(버튼 등) 받기 → 시안 3가지 → 디자인 기준 문서와 Flutter 테마 코드
2. 화면 흐름 (조건 입력 → 공공예식장 추천 / 정책 추천 / 업체 비교·상담 신청 / 체크리스트 / AI 채팅)
3. AI 에이전트 구조 설계
4. 구현 (마감 11/23 17:00 전에 APK, 시연 영상, 소개서 제출)
