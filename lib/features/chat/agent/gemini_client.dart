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
  budget(예산 배분·비용), schedule(준비 순서·일정·뭐부터), recommend(전체 추천), help(그 외·인사·잘 모르겠음)
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
  이때 다른 목적의 새 질문이 아니면 intent는 "answer"로 한다.
''';

  static String get _itemList =>
      VendorCategory.values.where((c) => c.budgetShare > 0).map((c) => c.name).join(', ');

  static final _understandSchema = Schema.object(
    properties: {
      'intent': Schema.enumString(enumValues: [...ConsultIntent.values.map((e) => e.name), 'answer']),
      'topic': Schema.enumString(
          enumValues: PolicyCategory.values.map((e) => e.name).toList(), nullable: true),
      'item': Schema.string(nullable: true),
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
    optionalProperties: ['topic', 'item'],
  );

  /// 질문을 이해해 [Understanding]으로 돌려준다. intent가 "answer"면 [Understanding.intent]는
  /// [ConsultIntent.help]로 두고 [isAnswer]를 true로 한다. 실패하면 null.
  Future<({Understanding u, bool isAnswer})?> understand(String text, {Slot? expecting}) async {
    try {
      final prompt = [
        '항목 목록: $_itemList',
        if (expecting != null) 'expecting: ${expecting.name}',
        '질문: ${maskPersonalInfo(text)}',
      ].join('\n');
      final res = await _understandModel
          .generateContent([Content.text(prompt)]).timeout(_timeout);
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

  /// Gemini가 쓴 원래 문장 (검사 전). 평가용으로도 쓴다. 실패하면 null.
  Future<String?> rewriteRaw({required String question, required String draft}) async {
    final res = await _writeModel.generateContent([
      Content.text('질문: ${maskPersonalInfo(question)}\n\n조회 결과:\n$draft'),
    ]).timeout(_timeout);
    final text = res.text?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// [draft](앱이 만든 답변)를 질문에 맞게 다시 쓴다. 검사를 통과하지 못하면 null.
  Future<String?> rewrite({required String question, required String draft}) async {
    try {
      final text = await rewriteRaw(question: question, draft: draft);
      if (text == null) return null;
      if (!numbersAreGrounded(text, draft)) {
        debugPrint('Gemini 답변에 조회 결과에 없는 숫자가 있어 원래 문장을 사용');
        return null;
      }
      if (!termsAreGrounded(text, draft)) {
        debugPrint('Gemini 답변에 조회 결과에 없는 표시어가 있어 원래 문장을 사용');
        return null;
      }
      return text.replaceAll('**', '');
    } catch (e) {
      debugPrint('Gemini 답변 작성 실패: $e');
      return null;
    }
  }

  /// 데이터 조회가 필요 없는 일반 질문에 대한 짧은 안내. 실패하면 null.
  Future<String?> chat(String question) async {
    try {
      final res = await _writeModel.generateContent([
        Content.text('$_helpPrompt\n질문: ${maskPersonalInfo(question)}'),
      ]).timeout(_timeout);
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
