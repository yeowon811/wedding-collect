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
    - **AI 생성 이미지 20장(18곳)**: 파일명 'AI'·'OPENAI_IMAGE'로 판별(수집 파일 표시와 일치). 앱에서 'AI 생성 이미지' 배지, 카드 대표 사진은 실제 사진 우선
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
  - 체크리스트: 결혼 정보(예식일·지역·총예산·하객 수, D-day), 예산(계약 합계), 11개 항목 상태, 내 상담 일정, 예식일 기준 할 일 20개(계약 완료 시 자동 체크)
  - AI 상담 (2026-11-16 구조 개편, 상세: `docs/ai-architecture.md`): ⓪ 내 정보 입력(`profile_setup_view.dart`, `UserProfile`) → 시작 시 전체 추천 → ① 질문 이해(`agent/understanding.dart`, 지금은 `RuleUnderstander`) → ② 내 정보+대화 기억 합치기 → ③ 목적별 필수 정보가 없으면 하나씩 되묻기(선택 버튼 + "잘 모르겠어요") → ④ `agent/consult_tools.dart`로 데이터 조회 → ⑤ 기준·근거·출처·다음 질문 버튼과 답변(`agent/consult_agent.dart`)
    - 사용자 요구: 상담 전에 내 정보 입력, 시작하면 추천, "20대 청년이 신혼생활에 받을 수 있는 정책?" 같은 질문은 지역 등 빠진 정보를 되물어 가며 답변
    - **Gemini 연결 (2026-11-16):** Firebase AI Logic(Gemini Developer API, 무료), 프로젝트 `wedding-collect`, 모델 `gemini-3.5-flash-lite`. ① 질문 이해(JSON)와 ⑤ 답변 문장만 Gemini, 실패하면 규칙 기반. 답변 숫자가 조회 결과에 없으면 Gemini 문장을 버림. 코드 `agent/gemini_client.dart`, 설정 `lib/firebase_options.dart`(`flutterfire configure --project=wedding-collect --platforms=android,web`로 다시 만들 수 있음)
    - **실행할 때 `--dart-define-from-file=secrets.json` 필수** (App Check 디버그 토큰, 저장소 제외. 없으면 Gemini 호출이 거절되고 규칙 기반으로만 동작). 토큰은 콘솔 App Check 웹·안드로이드 앱에 등록됨
    - 평가: `test/eval/` 질문 42개, 결과 `docs/ai-eval/` (질문 이해: 규칙 29/42 → Gemini·앱 42/42, 1.5초 / 답변 문장: 숫자·표시어 검사 통과 4/15 → 15/15)
    - 정책 판정(`policy_matcher.dart`)은 나이 범위(20대 등)·무주택 여부도 반영
- 후기 (2026-11-15 추가): **시연용 업체에만** 있음. `lib/data/repositories/review_repository.dart`가 업체 ID 고정 시드로 생성 (별점 분포는 업체 평점·후기 수와 정확히 일치, 최근 30개 표시). 업체 상세에 요약(평균·분포·키워드)+최근 3개, 전체 보기(정렬·별점 필터), 상담/계약한 업체만 후기 쓰기. **실제 업체에는 가짜 후기를 만들지 않음** (안내 문구만 표시)
- 공유 상태: `lib/data/app_state.dart` (메모리에만 저장, 앱 끄면 초기화)
- 테스트: `flutter test` (탭 전체, 비교·상담·계약 흐름, 데이터 건수, 상담 의도별 답변)
- **디자인 확정 (2026-11-16): 시안 A "클린 미니멀"** (시안 비교: https://claude.ai/artifact/FqvJzq1vPsHqxJiCKRUZzH). 흰 바탕 + 진한 회색 글자 + 파랑 포인트(#3B5BDB) 하나, 그림자 대신 회색 면·1px 테두리, 글꼴 Pretendard(`assets/fonts`, OFL). 색은 `app_palette.dart`/`app_colors.dart`, 컴포넌트 규칙은 `app_theme.dart` 상단 주석. 시안 전환 버튼은 삭제
  - 버튼: 화면당 주 버튼(파랑) 1개, 보조는 테두리. 상세 화면의 주요 행동은 **아래 고정 `BottomActionBar`**(+ `ActionPair` 보조·주) — `lib/core/widgets/inputs.dart`
  - 입력: 나이처럼 정확한 숫자는 **슬라이더 대신 `StepperField`**(−/+·직접 입력), 하객·예산은 `PresetPicker`(자주 쓰는 값 칩 + 직접 입력), 2~3개 중 고르기는 `ChoiceRow`, 묶음 제목은 `FormSection`(아이콘 없음)
  - 글자: 본문 15·설명 13 이상, 가장 연한 회색(textHint)은 입력 안내에만. 줄마다 아이콘·색 배지 남발 금지(정보는 이름·값 두 칸)
  - 로딩은 `SkeletonList`, 결과 없음은 `EmptyState`(원인에 맞는 다음 행동 버튼)
  - 화면 캡처: `flutter build web` → `python -I -m http.server 8095 --directory build/web` → `node tools/screenshots.mjs <폴더> "?tab=0" "?demo=1&tab=4" "?venue=H078" "?vendor=D0001" "?demo=1&policy=0"` (`|x,y`를 붙이면 그 위치를 누른 뒤 캡처, `WAIT_MS`로 대기 시간). 시연 링크는 `lib/app/demo_links.dart`

## 다음 할 일
1. 사용자의 디자인 기준(버튼 등) 받기 → 시안 3가지 → 디자인 기준 문서와 Flutter 테마 코드
2. 화면 흐름 (조건 입력 → 공공예식장 추천 / 정책 추천 / 업체 비교·상담 신청 / 체크리스트 / AI 채팅)
3. AI 에이전트 구조 설계
4. 구현 (마감 11/23 17:00 전에 APK, 시연 영상, 소개서 제출)
