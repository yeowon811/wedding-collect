import 'package:flutter/material.dart' show Icons, IconData;

import '../features/chat/agent/gemini_client.dart';
import '../features/chat/chat_agent.dart';
import 'app_state.dart';
import 'models/review.dart';
import 'models/user_profile.dart';
import 'models/vendor.dart';
import 'models/wedding_plan.dart';

/// 계정별로 저장하는 내 정보 ↔ 저장용 Map (Firestore 문서) 변환.
/// 이메일 같은 계정 정보는 넣지 않는다 (로그인 정보는 Firebase 인증에만 있음).
class UserDataCodec {
  UserDataCodec._();

  static const version = 1;

  static String? _date(DateTime? d) => d?.toIso8601String();
  static DateTime? _parseDate(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
  static int? _int(Object? v) => v is num ? v.toInt() : null;

  static Map<String, Object?> encode(AppState s) => {
    'version': version,
    'profileDone': s.profileDone,
    'profile': {
      'sido': s.profile.sido,
      'age': s.profile.age,
      'ageMax': s.profile.ageMax,
      'stage': s.profile.stage?.name,
      'marriedYears': s.profile.marriedYears,
      'weddingDate': _date(s.profile.weddingDate),
      'weddingUndecided': s.profile.weddingUndecided,
      'guests': s.profile.guests,
      'budget': s.profile.budget,
      'homeless': s.profile.homeless,
    },
    'plan': {
      'weddingDate': _date(s.plan.weddingDate),
      'sido': s.plan.sido,
      'budget': s.plan.budget,
      'guests': s.plan.guests,
    },
    'items': [
      for (final i in s.items)
        {
          'id': i.id,
          'name': i.name,
          'category': i.category?.name,
          'status': i.status.name,
          'amount': i.amount,
          'vendorName': i.vendorName,
        },
    ],
    'tasks': [
      for (final t in s.tasks)
        {
          'id': t.id,
          'dMinus': t.dMinus,
          'title': t.title,
          'category': t.category?.name,
          'tab': t.tab,
        },
    ],
    'doneTasks': s.doneTasks.toList(),
    'consultations': [
      for (final c in s.consultations)
        {
          'vendorId': c.vendor.id,
          'dateTime': _date(c.dateTime),
          'memo': c.memo,
        },
    ],
    'contracts': {
      for (final e in s.contracts.entries)
        e.key.name: {'vendorId': e.value.$1.id, 'price': e.value.$2},
    },
    'myReviews': [
      for (final r in s.myReviews)
        {
          'id': r.id,
          'vendorId': r.vendorId,
          'author': r.author,
          'rating': r.rating,
          'date': _date(r.date),
          'text': r.text,
          'tags': r.tags,
          'context': r.context,
        },
    ],
    'chatUpdatedAt': _date(s.chatUpdatedAt),
    'chat': [
      for (var k = 0; k < s.chat.length; k++)
        _encodeMessage(s.chat[k], last: k == s.chat.length - 1),
    ],
  };

  /// 대화 메시지 1개. 사용자 문장의 전화번호·이메일은 가려서 저장한다.
  /// 선택 버튼은 마지막 메시지의 "질문으로 보내는 버튼"만 남긴다 (되묻기 상태는 저장하지 않음).
  static Map<String, Object?> _encodeMessage(ChatMessage m, {required bool last}) => {
        'u': m.fromUser,
        'text': m.fromUser ? GeminiClient.maskPersonalInfo(m.text) : m.text,
        if (m.basis != null) 'basis': m.basis,
        if (m.sources.isNotEmpty) 'sources': m.sources,
        if (m.aiWritten) 'ai': true,
        if (m.isQuestion) 'q': true,
        if (m.trace.isNotEmpty) 'trace': m.trace,
        if (m.cards.isNotEmpty)
          'cards': [
            for (final c in m.cards)
              {'title': c.title, 'subtitle': c.subtitle, 'badge': c.badge, 'ref': c.ref},
          ],
        if (last)
          'replies': [
            for (final r in m.quickReplies)
              if (r.text != null && r.slot == null && r.action == null) {'label': r.label, 'text': r.text},
          ],
      };

  static IconData _iconFor(String? ref) => switch (ref?.split(':').first) {
        'venue' => Icons.location_city,
        'policy' => Icons.volunteer_activism,
        'vendor' => Icons.storefront_outlined,
        _ => Icons.description_outlined,
      };

  static ChatMessage _decodeMessage(Map m) => ChatMessage(
        fromUser: m['u'] == true,
        text: m['text'] as String? ?? '',
        basis: m['basis'] as String?,
        sources: ((m['sources'] as List?) ?? const []).cast<String>(),
        aiWritten: m['ai'] == true,
        isQuestion: m['q'] == true,
        trace: ((m['trace'] as List?) ?? const []).cast<String>(),
        cards: [
          for (final c in ((m['cards'] as List?) ?? const []).cast<Map>())
            ChatCard(
              title: c['title'] as String? ?? '',
              subtitle: c['subtitle'] as String? ?? '',
              badge: c['badge'] as String?,
              ref: c['ref'] as String?,
              icon: _iconFor(c['ref'] as String?),
            ),
        ],
        quickReplies: [
          for (final r in ((m['replies'] as List?) ?? const []).cast<Map>())
            QuickReply(r['label'] as String, text: r['text'] as String),
        ],
      );

  /// 저장된 Map을 앱 상태에 적용한다. 시연용 업체는 ID로 다시 찾는다 (없어진 업체는 건너뜀).
  static void apply(
    AppState s,
    Map<String, dynamic> d,
    List<DemoVendor> vendors,
  ) {
    final byId = {for (final v in vendors) v.id: v};
    VendorCategory? cat(Object? name) =>
        VendorCategory.values.where((c) => c.name == name).firstOrNull;

    final p = (d['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    final profile = UserProfile(
      sido: p['sido'] as String?,
      age: _int(p['age']),
      ageMax: _int(p['ageMax']),
      stage: MarriageStage.values
          .where((m) => m.name == p['stage'])
          .firstOrNull,
      marriedYears: _int(p['marriedYears']),
      weddingDate: _parseDate(p['weddingDate']),
      weddingUndecided: p['weddingUndecided'] == true,
      guests: _int(p['guests']),
      budget: _int(p['budget']),
      homeless: p['homeless'] as bool?,
    );

    final pl = (d['plan'] as Map?)?.cast<String, dynamic>() ?? const {};
    final plan = WeddingPlan(
      weddingDate: _parseDate(pl['weddingDate']) ?? s.plan.weddingDate,
      sido: pl['sido'] as String? ?? s.plan.sido,
      budget: _int(pl['budget']) ?? s.plan.budget,
      guests: _int(pl['guests']) ?? s.plan.guests,
    );

    final items = [
      for (final m in (d['items'] as List? ?? const []).cast<Map>())
        PlanItem(
          id: m['id'] as String,
          name: m['name'] as String,
          category: cat(m['category']),
          status:
              ItemStatus.values
                  .where((x) => x.name == m['status'])
                  .firstOrNull ??
              ItemStatus.todo,
          amount: _int(m['amount']),
          vendorName: m['vendorName'] as String?,
        ),
    ];

    final tasks = [
      for (final m in (d['tasks'] as List? ?? const []).cast<Map>())
        ChecklistTask(
          m['id'] as String,
          _int(m['dMinus']) ?? 0,
          m['title'] as String,
          category: cat(m['category']),
          tab: m['tab'] as String?,
        ),
    ];

    final consultations = [
      for (final m in (d['consultations'] as List? ?? const []).cast<Map>())
        if (byId[m['vendorId']] != null && _parseDate(m['dateTime']) != null)
          Consultation(
            vendor: byId[m['vendorId']]!,
            dateTime: _parseDate(m['dateTime'])!,
            memo: m['memo'] as String? ?? '',
          ),
    ];

    final contracts = <VendorCategory, (DemoVendor, int)>{};
    ((d['contracts'] as Map?) ?? const {}).forEach((k, v) {
      final c = cat(k);
      final vendor = byId[(v as Map)['vendorId']];
      if (c != null && vendor != null)
        contracts[c] = (vendor, _int(v['price']) ?? 0);
    });

    final reviews = [
      for (final m in (d['myReviews'] as List? ?? const []).cast<Map>())
        Review(
          id: m['id'] as String,
          vendorId: m['vendorId'] as String,
          author: m['author'] as String? ?? '나',
          rating: _int(m['rating']) ?? 5,
          date: _parseDate(m['date']) ?? DateTime.now(),
          text: m['text'] as String? ?? '',
          tags: ((m['tags'] as List?) ?? const []).cast<String>(),
          context: m['context'] as String? ?? '',
          helpful: 0,
          mine: true,
        ),
    ];

    s.replaceAll(
      profile: profile,
      profileDone: d['profileDone'] == true,
      plan: plan,
      items: items.isEmpty ? null : items,
      tasks: tasks.isEmpty ? null : tasks,
      doneTasks: ((d['doneTasks'] as List?) ?? const []).cast<String>().toSet(),
      consultations: consultations,
      contracts: contracts,
      myReviews: reviews,
      chat: [
        for (final m in ((d['chat'] as List?) ?? const []).cast<Map>()) _decodeMessage(m),
      ],
      chatUpdatedAt: _parseDate(d['chatUpdatedAt']),
    );
  }
}
