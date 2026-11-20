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
- **사진 규칙 (2026-11-19 완화):** 프로토타입이므로 예식장 사진은 실제 그 예식장 사진이 아니어도 됨 (AI 생성·분위기 사진 허용, 예: 시안 6 룩북 사진). 정원·대관료·정책·예약 현황 같은 데이터 값은 계속 실제 데이터만. 소개서 출처 표에 'AI 생성 이미지'로 기재
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

## 개발 환경 (현재 PC, 2026-11-19 옮김)
- Flutter 3.50.0 (Dart 3.14.0) at `C:\Users\User\flutter` (git 태그로 받아 `flutter doctor`에 channel 경고가 나오지만 무시해도 됨, `flutter channel`로 바꾸면 버전이 달라지니 하지 말 것), Android SDK 36 + Android Studio + NDK 28.2.13676358(APK 빌드에 필요, `sdkmanager "ndk;28.2.13676358"`), Node, Firebase CLI, Chrome. `flutter test` 104개 통과 확인 (11-19)
- 이전 PC: `C:\Users\LG\flutter`, 에뮬레이터 `Medium_Phone_API_37.0`
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
  - AI 상담 (2026-11-16 구조 개편, 상세: `docs/ai-architecture.md`): ⓪ 내 정보 입력(`profile_setup_view.dart`, `UserProfile`) → 시작 시 질문 추천 버튼만(내 정보에 맞춘 문구, 2026-11-20부터 처음에 추천 목록을 보여주지 않음) → ① 질문 이해(`agent/understanding.dart`, 지금은 `RuleUnderstander`) → ② 내 정보+대화 기억 합치기 → ③ 목적별 필수 정보가 없으면 하나씩 되묻기(선택 버튼 + "잘 모르겠어요") → ④ `agent/consult_tools.dart`로 데이터 조회 → ⑤ 기준·근거·출처·다음 질문 버튼과 답변(`agent/consult_agent.dart`)
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
- **예식장 지역 선택 (2026-11-17):** 시도 칩을 누르면 시군구 선택창(3열 격자, '서울 전체' 포함) → [확인]. 목록 위에 펼쳐지던 시군구 칩은 없앰. 고른 시군구는 칩에 '서울 · 강남구 ▾'로 표시, 다시 누르면 선택창. 시군구가 1곳뿐인 시도는 바로 적용. **2026-11-20 여러 곳 선택:** 시도·시군구를 여러 개 함께 고름(`_regions`: 시도 → 고른 시군구, 비면 시도 전체). 선택창은 눌러서 넣었다 뺐다·'서울 전체'·[확인 (n곳)]·'이 지역 빼기', 칩 '서울 · 강남구 외 2', 결과 줄 '서울 강남구·송파구, 전북 n곳', [전체] 칩·지역 초기화로 모두 풀기. 시군구 1곳뿐인 시도는 칩을 눌러 넣었다 뺐다
- **정책 공고 카드 (2026-11-17):** 시안(test3)처럼 배너 그림 + [지역] 정책명 + 기간. `features/policy/widgets/policy_banner.dart`(분야별 색·그림: 예식 분홍·장려금 주황·주거 파랑·검진 초록·교육 보라, 기관·접수 상태·괄호 앞 이름·괄호 안 설명·기간 알약). 휴대폰 1열(TileGrid minColumns 1), 상세 화면 맨 위에도 배너
  - **기간은 데이터에 없어 정직하게 표시:** 전국 사업(대출·세제·검진)은 '상시 신청', 지자체 사업은 '2026년 12월 31일(목) 까지 · 예산 소진 시 마감'(2026년 사업 기준), 상세에 '정확한 신청 기간은 기관 공고에서 확인'. 실제 마감일을 모으면 Policy에 필드 추가해 바꾸기
- **AI 상담 내 정보 입력 (2026-11-17):** 거주 지역은 입력칸+드롭다운(`DropdownMenu`, 글자 치면 목록 좁혀짐, 고르면 적용), 하객 수·총예산은 `NumberConfirmField`(입력칸 + [확인], 범위 밖이면 안내, '하객 120명으로 저장했어요'). `core/widgets/inputs.dart`. 체크리스트·시뮬레이터는 여전히 `PresetPicker`(칩 + 직접 입력)
- **체크리스트 빈 상태로 시작 (2026-11-17):** 결혼 정보(예식일·지역·총예산·하객)는 `WeddingPlan.entered`에 입력한 항목만 표시('입력하기', D-?), 값은 계산용 기본값을 그대로 가짐(업체·시뮬레이터 내부 계산). 예식일 전엔 할 일 날짜·캘린더 계산 안 함, 총예산 전엔 남은 예산 대신 안내. 할 일은 빈 목록으로 시작 → [추천 할 일 20개 불러오기](`AppState.loadRecommendedTasks`)·[할 일 추가]. 준비 항목 11개는 유지. AI 상담 '뭐부터?'는 할 일이 없으면 추천 목록 기준. 예전 저장본은 저장된 값을 입력한 것으로 봄. 시연 링크 `?demo=1`은 추천 할 일도 불러옴
- **체크리스트 ↔ AI 상담 연동 (2026-11-17):** `AppState.updatePlan`이 내 정보(profile)에도 입력한 값(지역·하객·총예산·예식일)을 넣고, AI 상담 내 정보 화면은 값을 바꿀 때마다 `updateProfileDraft`로 체크리스트(plan)에 바로 반영, 화면이 열려 있는 동안 바깥 변경도 받아 옴. 상담 에이전트는 답할 때마다 앱에서 바뀐 값만 대화 기억에 반영(`_syncFromApp`, 대화에서 말한 값은 덮지 않음)
  - 체크리스트 입력 창: 지역은 입력칸+드롭다운, 총예산·하객은 `NumberConfirmField`, 할 일 추가의 '언제까지'는 캘린더로 날짜 선택(오늘~예식일, 예식일 미입력이면 비활성) → 예식일 기준 D-값으로 저장. 예산 카드의 총예산 버튼·추천 할 일 불러오기 버튼은 없앰(`loadRecommendedTasks`는 시연 링크·테스트용으로만 남김)
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
- **AI 상담 되묻기 지역·직접 입력 (2026-11-18):** `Slot.sigungu` 추가. 지역 질문에 방금 시도로 답했을 때만(`_sidoJustAsked`) 이어서 '○○의 어느 시·군·구?'(시군구 버튼, 건너뛰기 가능, 시군구 1개뿐이면 안 물음). 글로 적은 시군구는 `findSigungu`(core/utils/region.dart, '강남'처럼 끝 글자 빼도, 여러 시도에 있는 이름은 시도를 알 때만)로 읽어 Gemini·규칙 결과에 보탬. 나이·하객·예산·혼인 연차 질문에 [직접 입력](숫자 창), 예식일 질문에 [날짜 고르기](캘린더) — QuickReply action `input`, 화면(chat_screen `_askInput`)이 값을 받아 선택 버튼처럼 넘김. 예식장 추천은 내 시군구를 먼저
- **AI 상담 더 보기 (2026-11-18):** 예식장·정책·업체 추천은 처음 3개 + [더 보기 (n곳 남음)](action `more`) → 다음 3개씩(`_moreAnswer`, '서울 공공예식장 4~6번째'), 글로 '더 보여줘·더 있어·다른 곳' 도 같음. 끝나면 '여기까지가 전부' + [○○ 탭에서 전체 보기](action `open_tab`, 업체는 그 항목으로). 업체는 시연 3곳 다음에 그 항목의 실제 연계 업체(공식전담 먼저). 더 보기로 본 목록도 '두 번째 거' 참조 가능
- **AI 상담 날짜 질문·확인 못 하는 조건 (2026-11-18):** '12/20에 예약 가능한 예식장?'처럼 날짜가 있으면 `_venueDateAnswer`. 날짜는 규칙(`date_check.dart` parseAskDate)+Gemini(`date`). 예식장마다 날짜 원문(예식 가능일·불가일·이용 기간, `dateTextOf`)을 모아, 월 범위·요일·불가일로 분명히 안 되는 곳은 규칙(`ruleJudgeDate`)이 확정하고 나머지는 Gemini(`judgeDates`, 12곳씩 동시, id+원문만 전송, 같은 날짜는 캐시)가 가능/불가/모름 판단 → 가능·불가·판단 어려움·정보 없음 개수와 이유를 보여 주고 '이미 예약이 찼는지는 앱에서 알 수 없음' 안내. 가능한 곳이 없으면 판단 어려움·정보 없음 곳을 보여 줌. 질문 이해에서 Gemini가 앱 데이터로 확인할 수 없는 조건(`unsupported`, 예: 역에서 가까운·주차 넓은)을 뽑으면 답 끝에 '반영하지 못했어요' 안내. Gemini 판단은 같은 질문에서 1~2곳 정도 달라질 수 있음
- **AI 상담 = Gemini가 계획 → 앱 도구 실행 → Gemini가 작성 (2026-11-18):** 예상 질문 52개 평가(`docs/ai-eval/predicted_report.md`, 웹에서 모은 예비부부 걱정 기반, `test/eval/predicted_*.dart`)에서 28개가 틀려 구조를 바꿈. 질문 이해(Gemini 1회)가 목적 + **계획**(`AskKind` list·detail·compare·cost·calc·general, names, exclude, needs 주차·피로연·야외, items 묶음, itemBudget, calc 식, monthsLeft, also 두 번째 목적)을 JSON으로 → 앱이 `_directAnswer`로 도구 선택: 계산(`calc.dart`, 앱이 계산), 이름 나온 예식장 상세·비교(`venue_features.dart` findVenuesByName), 비용(업체_요소 단가: 공공·실속 vs 일반+추가금), 스드메 묶음+예산, 정책 이름, 일반 지식(Gemini `general`, '일반 안내 · 앱 데이터 아님' 표시 + 공공예식장 데이터 사실). 예식장 목록은 `_venuePool`(무료·제외 시군구·주차·피로연·야외 원문 분류, 짧은 후속 질문은 앞 조건 이어받기). 규칙 이해도 같은 계획 필드를 일부 채움(Gemini 실패 대비). 정책 무주택은 주거 분야일 때만 되묻기, '6개월 남았는데'는 예식일 반영
  - Gemini 사용량: 무료 분당 한도 초과가 평가 중 59턴에 34번 → 한도 초과면 3초 뒤 1회 재시도(`_call`), 날짜 판단은 한 번에 묶어 1회. 호출은 질문당 이해 1 + 작성 1(날짜 질문은 +1)
  - v3 (2026-11-18): 거주 조건(`_residencyAnswer`: 이용 대상 원문 + 예식 지원 정책 거주 조건), 계절·요일(`_seasonDates`/`_venueSeasonAnswer`: 그 기간 날짜 전부 규칙 판정), 중복·동시 신청(일반 안내 + 원문 안내), 정책 이름 단어 찾기(`_policyHits`), 소득 상한·최대 금액(`policy_text.dart` 원문 정규식). 평가 52/52 (`docs/ai-eval/predicted_report.md`)
  - 주차·피로연 원문 분류 검수 표: `python -I tools/venue_features_report.py` → `docs/data-validation/venue_features.md`
- **예식장 예약 현황 달력 (2026-11-19):** 실제 예약 사이트 달력을 수집한 스냅샷 `assets/data/booking_status.json` (174곳: 공유누리 113 + 서울마이웨딩 61, 2026-11 ~ 2027-12). 형식은 예식장마다 `months: {"2026-11": "NNY…"}` 하루 한 글자(Y 가능 / A 오전 공석 / P 오후 공석 / B 오전·오후 / N 불가 / . 정보 없음) + source·sourceUrl·checkedAt·closedMeaning
  - 수집: `python -I tools/collect_booking_status.py` (공유누리: 공개 달력 주소 `POST /UserPortal/Upv/{rsrc_no}/selectCpsResvExclShareCalendar.do`, 온라인 예약 시설만, 1초 간격, robots.txt 허용). 서울마이웨딩은 달력 API(`/wp-json/sknk/v1/calendar?facility_id=&year=&month=`)가 스크립트 요청을 403으로 막아, 앱 내 브라우저로 시설 페이지를 연 채 그 API를 읽어 `tools/raw/booking_seoul_compact.json`에 저장 → `--skip-eshare`로 다시 합침. 초록 '오전/오후' = 공석, 검은 '예약확정 ○'·회색 '예약불가' = 예약됨, 빈칸 = 그날 접수 없음. 달력 없는 4곳(H091·H128·H149·H152)
  - 공유누리 '불가'는 예약됨·휴관·접수 기간 아님을 사이트가 구분하지 않음 → 앱에 그대로 안내. 나머지 66곳(폼·전화·기타 사이트)은 현황 비공개 → '예약 페이지에서 확인'
  - 화면: 예식장 상세 '예약 현황' 달력 (`features/venue/widgets/booking_calendar.dart`, 내 예식일 표시·날짜 누르면 상태·공석, '○/○ 확인 · 출처 · 이후 바뀔 수 있어요', 사이트 링크). 모델 `data/models/booking_status.dart`, 저장소 `Repos.booking` (main에서 미리 읽음, `rootBundle.load`로 직접 디코딩: 테스트에서 loadString의 isolate가 멈추는 문제 피함)
  - AI: `bookingJudge`(date_check.dart)가 현황으로 먼저 확정 → 없는 곳만 원문 규칙·Gemini 판단(Gemini 호출도 줄어듦). 날짜 질문은 '예약 달력에서 비어 있던 곳'을 먼저, 카드 배지 '○월 ○일 비어 있음', 출처에 확인 날짜. 계절 질문·예식장 한 곳 정보(앞으로 6개월 빈 주말)에도 반영. 항상 '수집한 날 기준이라 바뀔 수 있음' 안내
- **AI 상담 탐색 평가·수정 (2026-11-19):** 예상 질문에 없는 30개(`test/eval/probe_cases.dart`, 실행 `probe_eval_main.dart`)로 틀린 답 11개를 찾아 고침 (`docs/ai-eval/probe_report.md`, 규칙 경로 테스트 `test/probe_fixes_test.dart`). 기간 질문 `ConsultAgent.periodDates`("내년 3월", "다음 달", "4월 토요일", "예약 현황"=앞으로 3개월 주말, 달만 있으면 Gemini의 1일 날짜를 쓰지 않음) → 예식장 이름 있으면 그곳의 빈 날, 없으면 지역 예식장 날짜별 확인. "그중에 …" 후속은 길어도 앞 조건 이어받기. 날짜+'며칠'은 달력으로 계산(`_daysUntilAnswer`, 결혼이면 예식일로 일정), 날짜 있으면 계산식 금지. 나이 넣은 정책 질문은 정책 판정. "A 사는데 B 지원"은 B 거주 조건(`_otherRegionAsk`). 장려금 많은 지역은 전국 현금 지원 금액 순(`_cashRegionAnswer`, 대출 제외). "제일 큰 곳"은 정원 순. 국립공원은 `_parkAnswer`. 수량 질문("몇 장")은 일반 안내, 일반 안내 숫자는 질문 속 숫자만 허용하고 실패 시 이유 안내
  - 남은 문제: Gemini 무료 요금제에서 34턴 중 7턴 '응답 없음·연결 오류'(규칙으로 대신 답함), 답변 15~25초. 같은 질문도 Gemini 이해가 달라질 수 있음
- **피드백 반영 (2026-11-19):**
  - 예식장 홈: '무료 웨딩홀 Best'(무료 중 사진·하객 수용·정원 확인 순, [전체 보기] = 무료만), '빈 주말 많은 곳'(앞으로 3개월, 예약 현황 기준), 목록 위 [무료만] 칩 + 정렬(기본순·대관료 낮은 순·정원 큰 순), 카드 사진에 '무료' 배지. 예식장 리뷰 데이터는 없어서 '리뷰 Best'는 만들지 않음
  - 결혼 단계는 입력받지 않음: `UserProfile.stage`가 예식일로 계산(예식 전 예비부부 · 지나면 신혼부부, `marriedYears` = 예식 후 N년차). 대화에서 "혼인신고 했어요"(`stageInput`)는 예식 전이어도 신혼부부. 저장은 직접 말한 값(stageInput·marriedYearsInput)만. 예식일 선택은 지난 날짜도 가능
  - 정책 '내 상황': 예식일(판정 설명), 초혼 여부(`FirstMarriage` 둘 다/한 명만/둘 다 재혼), 무주택, 부부 합산 연소득(원문 소득 상한과 비교). 정책 데이터 `firstMarriage`('one' 1명 이상 초혼 / 'both' 초혼 부부, 11건). 예비부부에겐 '혼인신고 후 N년 이내 신청 (예식일 기준 YYYY.M까지)' 안내
  - **AI 상담에서 말한 내 정보 자동 반영:** 사용자가 자기 이야기로 말한 값(`_noteSelf`: 나이·하객·예산·예식일·무주택·초혼·"혼인신고 했어요", 되묻기·버튼 답)은 턴이 끝날 때 내 정보 = 체크리스트 결혼 정보에 저장(`_applySelfFacts` → `updateProfileDraft`)하고 답변 끝에 '내 정보에 반영했어요: …' + [되돌리기](`undo_profile`, 반영 전 profile·plan 복원). 지역은 사는 곳을 말했을 때만(`_livingRegion`: "수원 살아요", "경기도 사는데 …"의 앞 지역) 또는 '어디 사세요?'에 답했을 때만 — "부산 예식장 알려줘"의 부산은 찾는 곳이라 저장 안 함. '3개월 뒤' 같은 어림 예식일은 저장 안 함. 테스트 `test/chat_profile_sync_test.dart`
  - 정책 분류 규칙 보완(`convert_policies.py`): 결혼자금·결혼비용·바우처 → 결혼 장려금, 신혼집·리모델링 → 주거, 엽산 → 건강 (함양 결혼자금 등 5건, 기타는 1건만 남음)
- **AI 상담 새 구조 (2026-11-20, 진행 중):** Gemini가 도구 하나와 조건을 고르고(함수 호출, `agent/tool_planner.dart` + `GeminiClient.plan`) 앱이 검사·실행. 도구: search_venues(시도·구 여러 개, 제외 구, 무료, 대관료 상한, 하객, 주차·피로연·야외, 날짜/기간+요일, 정렬 fee_low·capacity_high·open_days) · venue_info · search_policies(topic, target_sido, nationwide, sort_by_amount, names) · search_vendors · estimate_cost · calculate · wedding_schedule · recommend_overview · general_answer · refer_previous · show_more. 모든 도구에 user_facts(자기 이야기). 후속 질문은 refine_previous+remove를 받아 **앱이** 앞 조건과 합침(`ToolPlanner.refine`). 자기 이야기·남은 개월은 질문에 근거 말이 있을 때만(`ToolPlanner.grounded`). 실행은 기존 답변 함수 재사용(`_processPlanned`·`_planDirect`, 예식장 목록은 `_vq`로 `_venuePool`). 실패하면 예전 경로(도구 고르기와 동시에 시작한 예전 Gemini 이해 → 규칙). JSON 한 장 방식은 엉뚱한 칸을 채워 버림. **답 다시 쓰기 끔**(`ConsultAgent.rewriteAnswers = false`, 속도). 테스트 `test/tool_planner_test.dart`
  - 평가: 새 구조로 답한 턴은 대부분 정확(여러 구·여러 시도·대관료 상한·후속 질문). 다만 무료 요금제 Gemini가 느림(도구 고르기 10~20초, 59턴 중 26턴 시간 초과). 11-20 평가를 많이 돌려 **일일 사용량 초과** → 모든 Gemini 호출 실패(배포본도 규칙만). 초기화 후 52+36 평가 다시 돌려야 함. 심사 기간 사용량 대비 Blaze 전환 권장
- **AI 상담 블록 답 (2026-11-20, 설계: `docs/ai-design/answer_design_blaze.md`·`answer_format_rules.md`):** 답은 글 대신 블록 목록(`ChatMessage.blocks`, 계정에도 저장). 예전 글(`text`)은 대화 기억·평가용으로 그대로 두고 접힌 줄 '자세한 설명'에 넣음. `ConsultAgent.useBlocks = false`면 예전 글 답
  - 코드 `lib/features/chat/answer/`: `answer_blocks.dart`(블록 12종 headline·text·filters·cards·table·ranking·steps·budget·ask·web·next·fold + 앱 전용 notice, 배지 색 Tone good 초록/check 주황/no 회색), `answer_facts.dart`(앱이 판정한 사실: 카드 값 순서 고정 구·정원·대관료, 배지 = 날짜 > 하객 > 요금, 빈 값이면 주황 + ☎ 문의처), `answer_template.dart`(기본 틀 R14), `answer_checks.dart`(K1 조건 밖 카드 뺌·K2 숫자 출처·K3 앞 답 반복·K4 빈 값 문의처·K5 형식 F1~F14: 제목 24자·설명 1문장 60자·칩 4개 12자·카드 3개·이유 첫 카드 18자), `answer_ai.dart`(Gemini 작성 지시문+스키마+예시, JSON → 블록 변환: id·배지 키만 받고 값은 앱이 채움, 검토 지시문·`ReviewVerdict`), `answer_composer.dart`(작성 → 앱 검사 → Gemini 검토 → 걸리면 고칠 점 붙여 1번 다시 → 또 걸리면 기본 틀), `venue_scope.dart`(넓히기: 서울은 구 중심 좌표, 그 밖은 예식장 좌표로 가까운 구·시도), `answer_view.dart`(화면). 에이전트 쪽 `agent/consult_present.dart`(part: 사실 만들기·넓히기 칩·조건 칩 다시 찾기·③ 보충 조사)
  - 흐름: ① 도구 고르기(기존) → ② 앱 조회 → (③ `near_place` Google 지도 좌표 → 앱이 거리 계산 / `web_lookup` Google 검색, 출처 없으면 버림. 검색·지도는 무료 요금제 불가, Blaze 필요) → ④ Gemini 블록 배치 → ⑤ 검사 + 검토. 답마다 Gemini 3~5번(도구·작성·검토 + 필요 시 다시 쓰기·조사). 하루 한도 초과를 받으면 10분 동안 부르지 않음(`GeminiClient.pausedUntil`)
  - R9 좁은 데서: 질문에 장소가 없으면 내 시·군·구부터(`_autoTownOk`, 시도·구를 말했거나 '전체'면 아님), 넓히기 칩 '서초·송파까지'·'서울 전체'·가까운 시도 'n곳'. 조건 칩 ✕·+조건·넓히기는 Gemini 없이 앱이 앞 조건(`_lastVenueArgs`)을 고쳐 다시 찾음(QuickReply action `refine`, `whole_sido`·`no_guests` 표시). 칩 이름은 12자 안으로 줄임(`_shortReply`: '71곳 더 보기', '금액 정하기')
  - 조사 고치기 `core/utils/korean.dart`(josa·withJosa·fixJosa·fixJosaAfter)
  - Gemini 설정: 작성·검토는 temperature 기본값(Gemini 3 권장), thinking minimal/low, JSON 스키마. 도구 고르기·이해는 0 그대로(평가로 검증된 값)
  - 평가: `test/eval/blocks_eval_main.dart`(Chrome·Gemini, `EVAL_SET=design|predicted|probe`, `EVAL_ONLY`, `EVAL_REPEAT=3` 흔들림, `EVAL_GAP`) · `blocks_eval_rules.dart`(flutter test, 규칙만) → `EVAL	{json}` → `python -I tools/blocks_eval_report.py 로그 [--prev 이전] --out docs/ai-eval/…md`. 기대값 `test/eval/expectations.dart`(예상 답 27대화 + 예상·탐색 질문 중 정답이 분명한 것), 채점 `test/eval/grader.dart`. **Chrome 실행 로그에는 App Check 디버그 토큰 줄이 찍히므로 EVAL 줄만 저장할 것.** 기본 틀 보기 `flutter test test/eval/blocks_dump.dart`. 테스트 `test/answer_blocks_test.dart`·`answer_composer_test.dart`
  - 평가 결과 (11-20, 규칙 경로만, Gemini 무료 하루 한도 초과): `docs/ai-eval/blocks_report_2026-11-20.md` — 예상 답 28/28 · 예상 질문 15/15 · 탐색 19/20 · 추가 21/22, 형식·숫자 검사 100%, 보이는 글 약 40% 줄어듦. **Gemini 경로(작성·검토·속도·호출 수·흔들림)는 아직 측정 전** (11-20 09:16 Blaze 전환 뒤 시험: "prepayment credits are depleted" — AI Studio 선불 크레딧 충전 필요. 결제 오류도 10분 쉼. 평가 EVAL 줄에 `usage` 토큰·호출 수·도구 조건·블록 JSON. 문항별 자세한 결과 `docs/ai-eval/blaze_min_test_2026-11-20.md`, 생성 `python -I tools/eval_detail_report.py 로그 --out 파일`) → 크레딧 충전 뒤 `EVAL_ONLY` 작은 묶음부터
  - **5차 수정 (11-20 10시, Blaze·선불 크레딧 뒤 Gemini 첫 실측, `docs/ai-eval/blaze_min_test_2026-11-20.md` 5차):** 13턴 13/13 정답, 턴당 Gemini 2.1번·3.3초·약 3.4원(입력 $0.30·캐시 $0.03·출력 $2.50/1M, $1=1,450원). 바꾼 것:
    - 도구 고르기 thinking low + 앱 가드 `ToolPlanner.guard`(예식장 질문에 전체 추천·정책 검색 → 예식장 검색, "대관료 싼 예식장" → fee_low) · `referToRefine`("그중에 주차…"에 번호 없는 refer_previous → 앞 검색 고치기)
    - 질문 이해를 미리 함께 부르던 호출 없앰 (도구 고르기 실패·시간 초과 때만 `understand`)
    - 제목 범위·건수는 앱(`AnswerTemplate.appHeadline`, Gemini는 title_kind app/숫자 없는 custom), 카드 종류 = 질문 목적(`cardItems`, 전체 추천·두 목적만 섞음), 넓히기·더 보기 칩은 앱이 먼저(`mergeChips`)
    - 검사 K6 제목 건수·K7 카드 종류(앱이 뺌)·K8 범위가 제목에, K3(앞과 같은 결과)는 앱이 안내 문장을 넣음(다시 쓰기 없음). 검토는 위험한 답만(`AnswerComposer.reviewReasons`: 정책·후속·비교·웹/지도·앱 경고)
    - 캐시: 고정 부분은 systemInstruction·tools에만, 날짜·맥락·질문·사실은 사용자 내용 끝에. `GeminiClient.usage`·`callLog`에 cachedContentTokenCount. 도구 고르기(약 8,500토큰)만 캐시가 맞음(6,080토큰), 답 배치·검토는 짧아 대상 아님. 앱 캐시(`AnswerComposer._cache`): 같은 조건·결과면 앞 배치를 다시 씀(Gemini 0번), 더 보기·인사·앱 동작 안내는 기본 틀만(`AnswerFacts.templateOnly`)
    - 남은 일: 카드 이유를 앱 문구로(현재 Gemini가 "주차 공간 여유"처럼 조금 더 말함), 도구 선언마다 붙은 user_facts를 줄여 도구 고르기 입력 절반으로, 흔들림 검사
  - **6차 (11-20 10:30, `blaze_min_test_2026-11-20.md` 6차):** 13턴 13/13, 같은 13턴 3번 39/39 정답, 턴당 2.1번·3.3초·약 2.6원 (6차 비용 약 139원, 오늘 합계 약 219원)
    - 카드 이유: Gemini는 `reason_key`만, 문장은 앱이 데이터로(`fillReasons`: biggest·cheapest·free·fits·parking·reception·outdoor·open_on_date·likely·max_amount·in_budget·top_rating·official). 자유 글 이유는 버림
    - 도구 고르기 입력 8,500→3,700토큰: user_facts를 도구마다 객체 대신 "key=value; …" 한 줄(`ToolPlanner.factsFromText`, 예전 객체도 읽음), 형식은 지시문에 한 번. 그 결과 고정 앞부분이 캐시 최소 길이 아래로 내려가 암묵적 캐시는 안 맞음(그래도 전체 비용 감소)
    - "3개만·두 곳만·5곳 추천" → 카드 정확히 그 수(`AnswerFacts.cardLimit`, `ConsultAgent.cardLimitOf`), 더 보기 없음, 넓히기 칩 유지
    - 답의 주인공 카드 고정(`AnswerFacts.pinned`, 예: 소득 초과 대출), 앱 제목이면 앱 배지
  - **7차 (11-20 10:45):** 목록 답(예식장·날짜·기간·정책·업체)은 앱이 카드와 순서를 정함(`AnswerTemplate.appPicksCards`, Gemini는 첫 카드 이유 키만, 비교·상세는 Gemini). 예식장 순서 = 내 구 → 하객 수용 → 무료 → 기간 제한 아님 → 정원 큰 곳 → ID(`ConsultTools.searchVenues`), 여러 구는 구마다 번갈아. 같은 13턴+X16 2번 실행에서 카드·순서·제목 14/14턴 같음, 28/28 정답, 턴당 2.1번·3.0초·약 2.5원. 계산 숫자("식대 6만원 120명")는 하객·예산으로 저장 안 함(`grounded`: "하객"·"예산" 말이 있을 때만)
  - **설명 글 제한 풀기 (11-20 11:40, 동료 요청):** `AnswerAi.freeText = true`(기본)면 Gemini가 매 답에 자연스러운 설명(이유·주의·다음 할 일)을 길이 제한 없이 쓰고 카드마다 이유 키(`reason_keys`), 쓰기 출력 한도 2048. K5의 설명 길이·문장 수·제목 숫자 반복은 보지 않음. K1·K2(숫자 + 설명 속 예식장·정책 이름 `AnswerChecks.knownNames`)·K6~K8·앱 제목·앱 카드 순서는 그대로. false면 7차 짧은 형식. 결과 `docs/ai-eval/free_text_2026-11-20.md`: 13/13, 설명 평균 173자, 3.6초, 턴당 약 3.1원, K2 0건
    - 줄바꿈: 이 PC는 git core.autocrlf=true라 작업 사본의 CRLF는 커밋 때 LF로 맞춰짐 (따로 손댈 필요 없음)
  - **답 복사 (11-20):** AI·사용자 말풍선을 `SelectionArea`로 감싸 끌기(데스크톱)·길게 누르기(휴대폰)로 골라 복사, 칩·버튼·접힌 줄은 그대로 동작. AI 답마다 복사 아이콘(`CopyAnswerButton`, 접힌 줄 오른쪽 또는 맨 아래 오른쪽) → `AnswerBlocksX.copyText`(제목(배지)·설명·카드 '이름 — 값 · 값 (배지) · 이유'·표·단계·출처, 칩·조건 칩·접힌 기록은 뺌) → '답변을 복사했어요'. 클립보드가 막힌 브라우저(앱 내 미리보기 창 등)는 '끌거나 길게 눌러 선택해 복사' 안내. 예전 글 답은 `_plainOld`. 테스트 `test/answer_copy_test.dart`
  - 데이터 점검 `python -I tools/audit_data.py --out docs/data-validation/audit_2026-11-20.md`. '광주·전남'(전남광주통합특별시) 예식장 11곳은 `sidoMatches`로 비교해야 함 (직접 == 비교 금지)
- **앱 시작 룩북 광고 (2026-11-19, 시안 6의 LAYER 1만):** 로그인(또는 둘러보기)하고 앱에 들어오면 전체 화면 사진첩, 앱을 켤 때 한 번(`features/intro/lookbook_ad.dart`, `main_shell.dart` initState). 사진 6장(시안 6 HTML에서 꺼낸 AI 생성 분위기 이미지, `assets/images/lookbook/`)마다 분위기가 맞는 실제 예식장(H084 꿈의숲 창녕위궁재사·H126 서울숲 포플러정원·H099 북서울미술관·H089 서울식물원 잔디마당·H105 서울시립대 자작마루·H147 서울역사박물관)의 이름·지역·대관료·정원(데이터) + 데이터에서 고른 한 줄. 3.8초 자동 넘김·밀어 넘기기·누르는 동안 멈춤·진행 막대. [터치하여 예식장 보기] → 그 예식장 상세, 위 X·아래 [닫기], [오늘 하루 보지 않기](shared_preferences `lookbook_hide_date`). 데이터를 기다리지 않고 사진부터 바로 띄움. 시연 링크(?demo·?venue 등)에서는 안 띄움, 테스트에서는 `LookbookAd.enabled = false`
- **AI 상담 구 단위 거르기 (2026-11-19):** 질문에서 찾는 시·군·구(`_askedTown`: `findSigungus`로 문장 속 구를 모두 찾아 '말고·빼고'로 뺀 구를 제외한 첫 번째)는 그 구만 거른다("송파구만: 서울 74곳 → 3곳", 더 보기도 그 안에서). 그 구에 없으면 시도 전체 + 안내. 짧은 후속("그중에 무료만")은 앞의 구를 이어받고 "전체·다른 구"면 풀린다. 내 정보의 시군구(사는 곳)는 먼저 보여 주기만 함. 예식장 홈 '무료만' 보기: 위에 '무료 웨딩홀만 보고 있어요 [✕ 전체 보기로]' 띠, 칩에 ✕, 뒤로 가기 = 필터 끄기. 테스트 `test/district_filter_test.dart`, Gemini 확인 P31·P32
- **예식장 위치 지도 (2026-11-20):** 상세 '기본 정보'와 '예약 현황' 사이 '위치': 작은 지도(`features/venue/widgets/venue_location_map.dart`, flutter_map + OpenStreetMap 타일, 보기 전용, 좌표는 수집 데이터 240곳 모두) + 주소 + [네이버 지도로 보기](`naverMapUri`: `https://map.naver.com/p/search/` + 도로명·지번 번호까지 자른 주소). 지도 위 '© OpenStreetMap' 표시 → 소개서 출처 표에 'OpenStreetMap 기여자, ODbL' 기재. 테스트에서는 `VenueLocationMap.showTiles = false`
- **예식장 AI 예시 후기 (2026-11-19):** 후기 기능이 들어갈 자리를 보여 주는 예시. Gemini가 예식장 공개 정보(정원·대관료·예약 방식·주차·피로연·실내외·이용 대상)만 보고 쓴 후기 2개씩, 240곳 483개 → `assets/data/venue_reviews.json` (별점 3~5, 태그 9종 중 1~2개)
  - 생성: `flutter run -d chrome --dart-define-from-file=secrets.json -t tools/venue_review_gen_main.dart *> 로그` (6곳씩, 8초 간격, 정보에 없는 숫자가 있으면 버림, `--dart-define=ONLY=H001,...`로 일부만) → `python -I tools/save_venue_reviews.py 로그...`
  - 화면: 예식장 상세 '후기' (`features/venue/widgets/venue_reviews.dart`): 예시 평균 별점, 맨 위 "AI로 작성된 후기입니다 … 실제 이용 후기가 아니에요" 각주, 'AI 예시 후기 N' (작성자·날짜·도움돼요 수는 만들지 않음), 사진 자리는 예식장 공식 사진 + 출처
  - 실제 시설이라 오해 방지: 별점은 상세 화면에만, 목록 카드·정렬·AI 상담 답변에는 쓰지 않음. 테스트 `test/venue_review_test.dart` (전 예식장 후기 있음 · 후기 숫자가 그 예식장 정보에 있음)
- 테스트: `flutter test` (탭 전체, 비교·상담·계약 흐름, 데이터 건수, 상담 의도별 답변, 예약 현황 판단, 탐색 질문 수정)
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
