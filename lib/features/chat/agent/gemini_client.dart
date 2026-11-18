import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/region.dart';
import '../../../data/models/policy.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/vendor.dart';
import '../../../firebase_options.dart';
import 'understanding.dart';

/// Gemini(Firebase AI Logic, Gemini Developer API) 연결.
///
/// - API 키는 앱에 없고 Firebase가 관리한다.
/// - 쓰는 곳은 두 군데뿐: ① 질문 이해(JSON), ⑤ 답변 문장 다듬기.
///   숫자·자격·업체는 항상 앱 데이터(도구) 결과에서 나오고, Gemini 문장에 원문에 없는
///   숫자가 들어가면 버리고 원래 문장을 쓴다.
/// - 보내기 전에 전화번호·이메일 같은 개인정보 형태는 가린다.
/// - 실패(네트워크·사용량 초과·형식 오류)하면 null을 돌려주고, 상담은 규칙 기반으로 이어간다.
class GeminiClient {
  GeminiClient._(this._understandModel, this._writeModel);

  static const modelName = 'gemini-3.5-flash-lite';
  static const _timeout = Duration(seconds: 12);

  final GenerativeModel _understandModel;
  final GenerativeModel _writeModel;

  /// 앱 시작 때 [init]에 성공하면 채워진다. 테스트·오프라인에서는 null.
  static GeminiClient? instance;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await _activateAppCheck();
      final ai = FirebaseAI.googleAI();
      instance = GeminiClient._(
        ai.generativeModel(
          model: modelName,
          systemInstruction: Content.system(_understandPrompt),
          generationConfig: GenerationConfig(
            temperature: 0,
            responseMimeType: 'application/json',
            responseSchema: _understandSchema,
            // 단순 추출이라 깊게 생각할 필요가 없음 → 응답 속도 우선
            thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.minimal),
          ),
        ),
        ai.generativeModel(
          model: modelName,
          systemInstruction: Content.system(_writePrompt),
          generationConfig: GenerationConfig(
            temperature: 0.3,
            maxOutputTokens: 1024,
            thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.minimal),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Gemini 연결 실패, 규칙 기반으로 진행: $e');
      instance = null;
    }
  }

  /// App Check: Firebase가 "우리 앱에서 온 요청"만 Gemini로 넘기게 한다.
  /// 디버그 토큰은 저장소에 넣지 않고 빌드할 때 넣는다:
  ///   flutter run --dart-define-from-file=secrets.json
  /// (secrets.json은 .gitignore. 토큰은 Firebase 콘솔 App Check > 앱 > 디버그 토큰 관리에 등록)
  static const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

  static Future<void> _activateAppCheck() async {
    if (_appCheckDebugToken.isEmpty) {
      debugPrint('App Check 디버그 토큰 없음 (--dart-define-from-file=secrets.json)');
      return;
    }
    await FirebaseAppCheck.instance.activate(
      providerWeb: WebDebugProvider(debugToken: _appCheckDebugToken),
      providerAndroid: const AndroidDebugProvider(debugToken: _appCheckDebugToken),
    );
  }

  // ───────────────────────── ① 질문 이해 ─────────────────────────

  static const _understandPrompt = '''
너는 한국 예비부부·신혼부부 결혼 준비 앱의 "질문 이해" 단계다.
사용자의 질문(과 방금 앱이 되물은 항목)을 읽고 정해진 JSON으로만 답한다. 설명 문장은 쓰지 않는다.

- intent: policy(지원 정책·대출·장려금), venue(공공예식장·예식 장소), vendor(드레스·스튜디오·식대 등 업체),
  budget(내 예산 현황·비용), schedule(준비 순서·일정·뭐부터), recommend(전체 추천), help(그 외·인사·잘 모르겠음)
- topic(정책 분야, 정책 질문일 때만): wedding(예식 지원), cash(장려금·축하금), housing(주거·신혼집·전세·대출·이자),
  health(건강·임신), education, etc
- item(업체 항목, 업체 질문일 때만): 질문과 함께 주는 "항목 목록" 중 하나의 영문 이름
- facts: 질문에 **직접 나온 정보만** 채우고 나머지는 null. 추측하지 않는다.
  - sido: 17개 시도 중 하나 (서울, 부산, 대구, 인천, 광주, 대전, 울산, 세종, 경기, 강원, 충북, 충남, 전북, 전남, 경북, 경남, 제주)
  - age/ageMax: 만 나이. "29살"·"스물아홉"이면 age=29, ageMax=null.
    "20대"면 20~29, "N0대 초반"은 N0~N3, "중반"은 N3~N6, "후반"은 N6~N9 (예: 30대 중반 = 33~36)
  - stage: engaged(예비부부·혼인신고 전) 또는 married(혼인신고 함·신혼부부)
  - marriedYears: 혼인 N년차
  - guests: 하객 수, budget: 총예산(만원 단위, "3천만원"=3000)
  - homeless: 무주택이면 true, 집이 있으면 false
- expecting이 주어지면 사용자의 짧은 답("서울", "27", "네")을 그 항목의 값으로 읽는다.
- expecting이 sigungu이면 "강남구", "수원이요" 같은 답은 isAnswer=true (시군구 값은 앱이 직접 읽는다).
  이때 다른 목적의 새 질문이 아니면 intent는 "answer"로 한다.

질문 앞에 "이전 대화"가 주어질 수 있다. 이번 질문을 이해하는 데만 쓴다.
- 질문이 생략된 경우("그럼 부산은?", "200명이면?", "메이크업은?", "신혼부부는?") 이전 대화의
  intent·topic·item을 이어받고, 질문에 새로 나온 값만 facts에 넣는다.
- 질문이 새 목적을 분명히 말하면("드레스 추천해줘", "예산은 어떻게 나눠?", "정책 알려줘") 이전 대화를 이어받지 않는다.
  인사·감사 같은 말은 help.
- facts에는 이번 질문에 나온 값만 넣는다. 단 "처음에 말한 지역"처럼 이전 대화의 값을 직접 가리키면 그 값을 넣는다.
- refIndex: 이전 답변 목록의 몇 번째 항목을 가리키는지(1부터). "두 번째 거"→2, "마지막"→그 목록의 마지막 번호,
  "거기/그거/그 정책"처럼 하나를 가리키면 1. 여러 목록이 있으면 질문이 가리키는 목록을 고르고, intent도 그 목록의
  목적으로 한다(예식장 목록이면 venue). 가리키지 않으면 null.
- filter: 이전 결과를 거르는 조건. free(무료), fits_guests(하객이 다 들어가는 곳), cheaper(더 싼 곳),
  has_photo(사진 있는 곳). 없으면 null.
- date: 질문에 예식·예약 날짜가 나오면 YYYY-MM-DD. 연도가 없으면 "오늘" 이후 가장 가까운 그 날짜. 없으면 null.
- 답을 만들 계획도 함께 채운다 (앱이 이 계획대로 데이터 도구를 부른다):
  - kind: list(찾아 줘·추천, 기본), detail(특정 예식장·정책·업체 하나에 대해 묻기, "거기"처럼 이전 목록을 가리키는 것도),
    compare(둘 이상 비교: "A랑 B 중 어디가 나아"), cost(비용 수준·추가금·예산이 충분한지·"보통 얼마"·"일반 웨딩홀보다 싸?"),
    calc(질문에 준 숫자로 계산: "1인 6만5천원에 150명이면"), general(앱 데이터로 답할 질문이 아닌 일반 지식·방법·제도·마음 고민:
    "정찰제가 뭐야", "계약 전에 뭐 물어봐", "혼인신고 서류", "공공예식장 별로라던데", "두 곳 동시에 신청해도 돼?")
  - names: 질문에 나온 예식장·정책·업체 이름 그대로 (없으면 빈 배열)
  - exclude: 빼 달라는 시·군·구 이름 ("강남구 말고" → ["강남구"])
  - needs: 예식장 조건 중 parking(주차), reception(피로연·식사·출장뷔페·케이터링), outdoor(야외)
  - items: 업체 항목이 여러 개면 모두 ("스드메" = studio, dress, makeup). 하나면 item만 써도 된다.
  - itemBudget: 그 항목(들)에 쓸 금액 상한, 만원 ("200만원 안으로" → 200). 총예산이 아니면 facts.budget에 넣지 않는다.
  - calc: kind가 calc면 원 단위 숫자와 + - * / 로 된 식 ("6만5천원에 150명" → "65000*150")
  - monthsLeft: 예식까지 남은 개월 ("6개월 남았는데" → 6)
  - also: 질문이 목적 두 개를 함께 물으면 두 번째 목적 ("부산 예식장이랑 정책 같이" → intent venue, also policy)
- stage: "혼인신고 안 했/전"이면 engaged.
- unsupported: 질문에 나온 조건 중 앱 데이터로 확인할 수 없는 것을 짧은 말로(최대 3개). 없으면 빈 배열.
  주차·피로연·야외·날짜·비용·비교·계산은 앱이 확인하므로 넣지 않는다.
  앱이 아는 것: 지역·시군구, 하객 수·정원, 대관료·무료 여부, 사진 유무, 예식 가능일(일부 예식장의 원문), 예약 방식,
  업체 항목·가격대·평점, 정책 대상 조건(지역·나이·혼인·무주택), 내 예산·할 일.
  예: "역에서 가까운", "주차 넓은", "야외 정원", "후기 좋은 예식장", "당일 날씨" → unsupported.
  날짜·예약 가능일 조건은 앱이 date로 판단하므로 unsupported에 넣지 않는다.
''';

  static String get _itemList =>
      VendorCategory.values.where((c) => c.budgetShare > 0).map((c) => c.name).join(', ');

  static final _understandSchema = Schema.object(
    properties: {
      'intent': Schema.enumString(enumValues: [...ConsultIntent.values.map((e) => e.name), 'answer']),
      'topic': Schema.enumString(
          enumValues: PolicyCategory.values.map((e) => e.name).toList(), nullable: true),
      'item': Schema.string(nullable: true),
      'refIndex': Schema.integer(nullable: true),
      'filter': Schema.enumString(enumValues: kResultFilters, nullable: true),
      'date': Schema.string(nullable: true),
      'unsupported': Schema.array(items: Schema.string()),
      'kind': Schema.enumString(enumValues: AskKind.values.map((e) => e.name).toList()),
      'names': Schema.array(items: Schema.string()),
      'exclude': Schema.array(items: Schema.string()),
      'needs': Schema.array(items: Schema.enumString(enumValues: kVenueNeeds)),
      'items': Schema.array(items: Schema.string()),
      'itemBudget': Schema.integer(nullable: true),
      'calc': Schema.string(nullable: true),
      'monthsLeft': Schema.integer(nullable: true),
      'also': Schema.enumString(enumValues: ConsultIntent.values.map((e) => e.name).toList(), nullable: true),
      'facts': Schema.object(
        properties: {
          'sido': Schema.enumString(enumValues: kSidoList, nullable: true),
          'age': Schema.integer(nullable: true),
          'ageMax': Schema.integer(nullable: true),
          'stage': Schema.enumString(enumValues: ['engaged', 'married'], nullable: true),
          'marriedYears': Schema.integer(nullable: true),
          'guests': Schema.integer(nullable: true),
          'budget': Schema.integer(nullable: true),
          'homeless': Schema.boolean(nullable: true),
        },
        optionalProperties: [
          'sido', 'age', 'ageMax', 'stage', 'marriedYears', 'guests', 'budget', 'homeless'
        ],
      ),
    },
    optionalProperties: [
      'topic', 'item', 'refIndex', 'filter', 'date', 'unsupported',
      'kind', 'names', 'exclude', 'needs', 'items', 'itemBudget', 'calc', 'monthsLeft', 'also',
    ],
  );

  /// 질문을 이해해 [Understanding]으로 돌려준다. intent가 "answer"면 [Understanding.intent]는
  /// [ConsultIntent.help]로 두고 [isAnswer]를 true로 한다. 실패하면 null.
  /// [context]: 이전 대화 (원문 몇 턴 또는 요약 상태). 개인정보 형태는 가려서 보낸다.
  Future<({Understanding u, bool isAnswer})?> understand(String text,
      {Slot? expecting, String? context, Duration? timeout}) async {
    try {
      final now = DateTime.now();
      final prompt = [
        '오늘: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        '항목 목록: $_itemList',
        if (context != null && context.isNotEmpty) '이전 대화:\n${maskPersonalInfo(context)}\n',
        if (expecting != null) 'expecting: ${expecting.name}',
        '질문: ${maskPersonalInfo(text)}',
      ].join('\n');
      final res = await _call(_understandModel, prompt, timeout ?? _timeout);
      final raw = res.text;
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return parseUnderstanding(json);
    } catch (e) {
      debugPrint('Gemini 질문 이해 실패: $e');
      return null;
    }
  }

  /// Gemini가 돌려준 JSON을 검사해서 [Understanding]으로 바꾼다. 범위를 벗어난 값은 버린다.
  @visibleForTesting
  static ({Understanding u, bool isAnswer})? parseUnderstanding(Map<String, dynamic> json) {
    final intentName = json['intent'];
    final isAnswer = intentName == 'answer';
    final intent = ConsultIntent.values.where((e) => e.name == intentName).firstOrNull;
    if (intent == null && !isAnswer) return null;

    final f = (json['facts'] as Map?)?.cast<String, dynamic>() ?? const {};
    int? intIn(String k, int min, int max) {
      final v = f[k];
      final n = v is num ? v.round() : null;
      return n != null && n >= min && n <= max ? n : null;
    }

    final sido = f['sido'];
    var age = intIn('age', 15, 70);
    var ageMax = intIn('ageMax', 15, 70);
    if (age == null || (ageMax != null && ageMax < age)) ageMax = null;
    if (ageMax == age) ageMax = null;
    final stage = switch (f['stage']) {
      'engaged' => MarriageStage.engaged,
      'married' => MarriageStage.married,
      _ => null,
    };
    final homeless = f['homeless'];

    return (
      isAnswer: isAnswer,
      u: Understanding(
        intent: intent ?? ConsultIntent.help,
        topic: PolicyCategory.values.where((e) => e.name == json['topic']).firstOrNull,
        item: VendorCategory.values
            .where((e) => e.name == json['item'] && e.budgetShare > 0)
            .firstOrNull,
        refIndex: switch (json['refIndex']) {
          final num n when n >= 1 && n <= 10 => n.toInt(),
          _ => null,
        },
        filter: kResultFilters.contains(json['filter']) ? json['filter'] as String : null,
        date: _validDate(json['date']),
        kind: AskKind.values.where((e) => e.name == json['kind']).firstOrNull ?? AskKind.list,
        names: _strings(json['names'], max: 4),
        exclude: _strings(json['exclude'], max: 3),
        needs: [for (final x in _strings(json['needs'], max: 3)) if (kVenueNeeds.contains(x)) x],
        items: [
          for (final x in _strings(json['items'], max: 5))
            ...VendorCategory.values.where((e) => e.name == x && e.budgetShare > 0),
        ],
        itemBudget: switch (json['itemBudget']) { final num n when n >= 1 && n <= 100000 => n.toInt(), _ => null },
        calc: json['calc'] is String && RegExp(r'^[\d\s.+\-*/()]{3,60}$').hasMatch(json['calc'] as String)
            ? json['calc'] as String
            : null,
        monthsLeft: switch (json['monthsLeft']) { final num n when n >= 0 && n <= 60 => n.toInt(), _ => null },
        also: ConsultIntent.values.where((e) => e.name == json['also'] && e.name != intentName).firstOrNull,
        unsupported: [
          for (final x in (json['unsupported'] as List?) ?? const [])
            if (x is String && x.trim().isNotEmpty && x.length <= 30) x.trim(),
        ].take(3).toList(),
        facts: UserProfile(
          sido: sido is String && kSidoList.contains(sido) ? sido : null,
          age: age,
          ageMax: ageMax,
          stage: stage,
          marriedYears: intIn('marriedYears', 0, 30),
          guests: intIn('guests', 10, 2000),
          budget: intIn('budget', 100, 100000),
          homeless: homeless is bool ? homeless : null,
        ),
      ),
    );
  }

  static List<String> _strings(Object? v, {required int max}) => [
        for (final x in (v as List?) ?? const [])
          if (x is String && x.trim().isNotEmpty && x.length <= 40) x.trim(),
      ].take(max).toList();

  /// 무료 사용량(분당 요청 수)을 넘으면 잠깐 쉬고 한 번만 다시 묻는다
  static Future<GenerateContentResponse> _call(GenerativeModel model, String prompt, Duration timeout) async {
    try {
      return await model.generateContent([Content.text(prompt)]).timeout(timeout);
    } catch (e) {
      final m = '$e'.toLowerCase();
      if (!(m.contains('quota') || m.contains('429') || m.contains('exhausted') || m.contains('rate'))) rethrow;
      debugPrint('Gemini 사용량 초과 → 3초 뒤 다시 시도');
      await Future<void>.delayed(const Duration(seconds: 3));
      return model.generateContent([Content.text(prompt)]).timeout(timeout);
    }
  }

  /// 'YYYY-MM-DD' → 날짜 (오늘부터 3년 안만)
  static DateTime? _validDate(Object? v) {
    if (v is! String) return null;
    final d = DateTime.tryParse(v);
    if (d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today) || d.isAfter(today.add(const Duration(days: 365 * 3))) ? null : d;
  }

  // ───────────────────────── 예식장 날짜 판단 ─────────────────────────

  static const _datePrompt = '''
너는 결혼 준비 앱의 "예식 날짜 판단" 단계다. 날짜 하나와 예식장 목록(각각 id와 날짜 관련 원문)을 받는다.
각 예식장에서 그 날짜에 예식을 할 수 있는지 **원문만 보고** 판단해 JSON 배열로 답한다.
- possible: 원문의 예식 가능 기간·요일에 그 날짜가 들어가고, 불가일에 해당하지 않음
- impossible: 그 날짜가 기간 밖이거나, 그 요일엔 예식이 없거나, 불가일에 해당함
- unknown: 원문만으로 판단할 수 없음 (지정일 별도 공지, "문의", 정보 부족 등). 추측하지 않는다.
  "상시운영"·"09:00~18:00" 같은 시설 운영 안내만 있고 예식 가능 기간·요일 안내가 없으면 unknown.
- reason: 판단 근거를 원문에서 따와 20자 이내로 (예: "토·일만 예식", "추석 연휴 불가", "3~12월 운영")
이미 예약이 찼는지는 알 수 없으므로 판단에 넣지 않는다.
''';

  static final _dateSchema = Schema.array(
    items: Schema.object(properties: {
      'id': Schema.string(),
      'status': Schema.enumString(enumValues: ['possible', 'impossible', 'unknown']),
      'reason': Schema.string(),
    }),
  );

  GenerativeModel? _dateModelCache;
  GenerativeModel get _dateModel => _dateModelCache ??= FirebaseAI.googleAI().generativeModel(
        model: modelName,
        systemInstruction: Content.system(_datePrompt),
        generationConfig: GenerationConfig(
          temperature: 0,
          responseMimeType: 'application/json',
          responseSchema: _dateSchema,
          thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.low),
        ),
      );

  /// 날짜 [date]에 각 예식장([items]: id → 원문)에서 예식이 가능한지 Gemini가 원문을 읽고 판단.
  /// 형식이 틀리거나 목록에 없는 id는 버린다. 실패하면 null.
  Future<Map<String, ({String status, String reason})>?> judgeDates(DateTime date, Map<String, String> items) async {
    if (items.isEmpty) return const {};
    // 같은 날짜·예식장은 한 번 판단한 값을 그대로 (같은 질문에 답이 바뀌지 않게)
    final key = '${date.year}-${date.month}-${date.day}';
    final cache = _dateCache.putIfAbsent(key, () => {});
    final todo = {for (final e in items.entries) if (!cache.containsKey(e.key)) e.key: e.value};
    // 한 번에 묻는다 (나눠서 동시에 부르면 분당 사용량을 금방 넘음)
    final keys = todo.keys.toList();
    final parts = [
      for (var i = 0; i < keys.length; i += 80)
        await _judgeBatch(date, {for (final k in keys.skip(i).take(80)) k: todo[k]!}),
    ];
    if (parts.isNotEmpty && parts.every((p) => p == null)) return null;
    for (final p in parts) {
      if (p != null) cache.addAll(p);
    }
    return {for (final k in items.keys) if (cache[k] != null) k: cache[k]!};
  }

  final _dateCache = <String, Map<String, ({String status, String reason})>>{};

  Future<Map<String, ({String status, String reason})>?> _judgeBatch(DateTime date, Map<String, String> items) async {
    try {
      const wd = ['월', '화', '수', '목', '금', '토', '일'];
      final prompt = [
        '날짜: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} (${wd[date.weekday - 1]}요일)',
        for (final e in items.entries) '- id ${e.key}: ${e.value}',
      ].join('\n');
      final res = await _call(_dateModel, prompt, const Duration(seconds: 30));
      final raw = res.text;
      if (raw == null) return null;
      final out = <String, ({String status, String reason})>{};
      for (final x in (jsonDecode(raw) as List).cast<Map>()) {
        final id = x['id'], st = x['status'], why = x['reason'];
        if (id is String && items.containsKey(id) && st is String && ['possible', 'impossible', 'unknown'].contains(st)) {
          final r = why is String ? why.trim() : '';
          out[id] = (status: st, reason: r.length > 30 ? '${r.substring(0, 30)}…' : r);
        }
      }
      return out;
    } catch (e) {
      debugPrint('Gemini 날짜 판단 실패: $e');
      return null;
    }
  }

  // ───────────────────────── ⑤ 답변 문장 ─────────────────────────

  static const _writePrompt = '''
너는 결혼 준비 앱의 상담사다. 앱이 데이터에서 찾은 "조회 결과"를 받아
사용자의 질문에 맞게 친절하고 짧게(5~10줄) 다시 설명한다. 조회 결과를 다시 쓰는 것이지 새 정보를 더하는 것이 아니다.

반드시 지킬 것:
- 조회 결과에 있는 정책명·예식장명·업체명·숫자(금액·인원·나이·건수·날짜)만 쓴다. 새 숫자나 이름을 만들지 않는다.
- 건수는 조회 결과 문장의 숫자를 그대로 쓴다. 목록에 보인 개수를 찾은 전체 건수처럼 말하지 않는다.
- 결과에 없는 자격 조건·혜택·가격을 추측하지 않는다.
- 주의 문구는 조회 결과에 있는 것만 그대로 옮긴다 ("확인할 것: …", 데이터 성격에 대한 안내, 기관 확인 안내 등).
  조회 결과에 없는 주의 문구나 데이터 성격에 대한 말을 새로 붙이지 않는다.
- 사용자를 "예비부부님" 같은 호칭으로 부르지 않는다. 사용자의 상황은 "기준"에 적힌 그대로만 말한다.
- 인사말 없이 바로 답한다.
- 항목은 "• "로 시작하는 목록으로 쓴다. 마크다운 굵게(**)·표·제목(#)은 쓰지 않는다.
- 존댓말(해요체)로 쓴다.
''';

  static const _helpPrompt = '''
조회 결과가 없는 일반 질문이다. 결혼 준비에 대한 일반적인 안내만 2~4줄로 하고,
구체적인 금액·정책명·자격 조건은 말하지 않는다. 이 앱에서 물어볼 수 있는 것
(받을 수 있는 정책, 공공예식장 추천, 업체 추천, 예산 배분, 준비 순서)을 안내한다.
''';

  static const _generalPrompt = '''
너는 결혼 준비 앱의 상담사다. 아래 질문은 앱 데이터(예식장·정책·업체 목록)로 답할 질문이 아니라 일반 지식·방법·제도·고민에 대한 질문이다.
- 일반적으로 알려진 내용을 4~7줄로, "• " 목록 위주로 답한다. 존댓말(해요체), 인사말 없이.
- 특정 업체명·예식장명·정책명, 구체적인 금액·날짜·비율·법 조항 번호는 쓰지 않는다 (앱 데이터가 아니라 틀릴 수 있음).
- 제도·법·계약처럼 바뀔 수 있는 내용은 마지막 줄에 "정확한 내용은 공식 안내(기관·계약서)에서 확인해 주세요."를 붙인다.
- 고민·감정 질문이면 먼저 짧게 공감하고, 할 수 있는 일을 제안한다. 이때는 공식 안내 문장을 붙이지 않는다.
- 이 앱이 할 수 있는 일을 지어내지 않는다. 앱은 대신 연락·예약·신청을 해 주지 않고, 전화번호를 받지 않는다.
  앱에서 할 수 있는 것은 정책 찾기, 공공예식장 찾기, 업체 비교·상담 신청(시연), 예산·할 일 정리뿐이다.
- 마크다운 굵게(**)·제목(#)·표는 쓰지 않는다.
''';

  /// 앱 데이터가 아닌 일반 지식 질문 → Gemini 일반 안내 (숫자가 섞이면 버림). 실패하면 null
  Future<String?> general(String question) async {
    try {
      final res = await _call(_writeModel, '$_generalPrompt\n질문: ${maskPersonalInfo(question)}', _timeout);
      final text = res.text?.trim();
      if (text == null || text.isEmpty) return null;
      if (RegExp(r'\d{2,}').hasMatch(text)) return null;
      return text.replaceAll('**', '');
    } catch (e) {
      debugPrint('Gemini 일반 지식 답변 실패: $e');
      return null;
    }
  }

  /// Gemini가 쓴 원래 문장 (검사 전). 평가용으로도 쓴다. 실패하면 null.
  Future<String?> rewriteRaw({required String question, required String draft}) async {
    final res = await _call(_writeModel, '질문: ${maskPersonalInfo(question)}\n\n조회 결과:\n$draft', _timeout);
    final text = res.text?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// [draft](앱이 만든 답변)를 질문에 맞게 다시 쓴다. 검사를 통과하지 못하면 null.
  Future<String?> rewrite({required String question, required String draft}) async {
    try {
      final text = await rewriteRaw(question: question, draft: draft);
      if (text == null) {
        lastRewriteNote = 'Gemini 응답 없음 → 앱이 만든 문장 사용';
        return null;
      }
      if (!numbersAreGrounded(text, draft)) {
        lastRewriteNote = 'Gemini 문장에 조회 결과에 없는 숫자가 있어 버림 → 앱이 만든 문장 사용';
        return null;
      }
      if (!termsAreGrounded(text, draft)) {
        lastRewriteNote = "Gemini 문장에 조회 결과에 없는 표시어('시연용' 등)가 있어 버림 → 앱이 만든 문장 사용";
        return null;
      }
      lastRewriteNote = 'Gemini가 조회 결과만 보고 다시 씀 · 숫자 검사 통과 · 표시어 검사 통과';
      return text.replaceAll('**', '');
    } catch (e) {
      debugPrint('Gemini 답변 작성 실패: $e');
      lastRewriteNote = 'Gemini 연결 오류 → 앱이 만든 문장 사용';
      return null;
    }
  }

  /// 마지막 [rewrite] 결과 설명 ("왜 이렇게 답했나요?"에 표시)
  String lastRewriteNote = '';

  /// 데이터 조회가 필요 없는 일반 질문에 대한 짧은 안내. 실패하면 null.
  Future<String?> chat(String question) async {
    try {
      final res = await _call(_writeModel, '$_helpPrompt\n질문: ${maskPersonalInfo(question)}', _timeout);
      final text = res.text?.trim();
      if (text == null || text.isEmpty) return null;
      // 일반 안내에는 숫자를 쓰지 않게 했으므로 숫자가 섞이면 쓰지 않는다
      if (RegExp(r'\d{2,}').hasMatch(text)) return null;
      return text.replaceAll('**', '');
    } catch (e) {
      debugPrint('Gemini 일반 안내 실패: $e');
      return null;
    }
  }

  // ───────────────────────── 안전장치 ─────────────────────────

  /// 전화번호·이메일·주민번호 형태를 가린다 (외부 AI로 개인정보를 보내지 않기 위해)
  static String maskPersonalInfo(String text) => text
      .replaceAll(RegExp(r'\d{6}\s*-\s*[1-4]\d{6}'), '[주민번호]')
      .replaceAll(RegExp(r'01[016789][\s-]?\d{3,4}[\s-]?\d{4}'), '[전화번호]')
      .replaceAll(RegExp(r'0\d{1,2}[\s-]\d{3,4}[\s-]\d{4}'), '[전화번호]')
      .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '[이메일]');

  /// 데이터 성격·사용자 상황을 나타내는 말. 조회 결과에 없는데 답변에 나오면 잘못된 정보다
  /// (예: 실제 예식장 데이터에 "시연용"을 붙임, 신혼부부에게 "예비부부"라고 함).
  static const guardedTerms = ['시연용', '가상', '예비부부', '신혼부부', '기관'];

  /// [text]에 나온 표시어가 모두 [source]에도 있는지 검사한다
  static bool termsAreGrounded(String text, String source) =>
      guardedTerms.where(text.contains).every(source.contains);

  /// [text]의 모든 숫자가 [source]에도 있는지 검사한다 (AI가 숫자를 지어내지 않았는지)
  static bool numbersAreGrounded(String text, String source) {
    Set<String> nums(String s) => RegExp(r'\d+(?:\.\d+)?')
        .allMatches(s.replaceAll(',', ''))
        .map((m) => m.group(0)!)
        .toSet();
    return nums(source).containsAll(nums(text));
  }
}
