import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_badge.dart';
import '../chat_card_link.dart';
import 'answer_blocks.dart';

/// 블록 답 화면 (시안 A: 흰 바탕·1px 테두리·파랑 포인트 하나, 그림자 없음).
/// 칩(next·ask 선택지)은 말풍선 아래 기존 선택 버튼 줄이 보여 준다.
class AnswerView extends StatelessWidget {
  const AnswerView({super.key, required this.blocks, this.onRefine, this.interactive = false});

  final List<AnswerBlock> blocks;

  /// 조건 칩 ✕ / + 조건: (바꿀 값, 뺄 조건, 칩 이름)
  final void Function(Map<String, Object?> set, List<String> remove, String label)? onRefine;
  final bool interactive; // 마지막 답일 때만 조건 칩을 누를 수 있음

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final b in blocks) {
      final w = _block(context, b);
      if (w == null) continue;
      if (children.isNotEmpty) children.add(SizedBox(height: b.type == BlockType.text ? 6 : 12));
      children.add(w);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget? _block(BuildContext context, AnswerBlock b) => switch (b.type) {
        BlockType.headline => _Headline(b),
        BlockType.ask => _Headline(b, ask: true),
        BlockType.text => Text(b.text ?? '', style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textBody)),
        BlockType.notice => _Notice(b.text ?? ''),
        BlockType.filters => _Filters(b.filters, onRefine: interactive ? onRefine : null),
        BlockType.cards => Column(children: [
            for (final (i, c) in b.cards.indexed) ...[if (i > 0) const SizedBox(height: 8), AnswerCardView(card: c)],
          ]),
        BlockType.table => _TableView(b),
        BlockType.ranking => _Numbered(b.items),
        BlockType.steps => _Steps(b.items),
        BlockType.budget => _Budget(b),
        BlockType.web => _Web(b),
        BlockType.fold => _Fold(b),
        BlockType.next => null, // 말풍선 아래 선택 버튼 줄
      };
}

Color toneColor(Tone t) => switch (t) {
      Tone.good => AppColors.success,
      Tone.check => AppColors.warning,
      Tone.no => AppColors.unknown,
      Tone.info => AppColors.primary,
    };

Color toneSoft(Tone t) => switch (t) {
      Tone.good => AppColors.successSoft,
      Tone.check => AppColors.warningSoft,
      Tone.no => AppColors.fill,
      Tone.info => AppColors.primarySoft,
    };

class ToneBadge extends StatelessWidget {
  const ToneBadge(this.badge, {super.key});

  final BlockBadge badge;

  @override
  Widget build(BuildContext context) =>
      InfoBadge(label: badge.text, color: toneColor(badge.tone), background: toneSoft(badge.tone));
}

class _Headline extends StatelessWidget {
  const _Headline(this.b, {this.ask = false});

  final AnswerBlock b;
  final bool ask;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(b.title ?? '',
          style: TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      if (b.badges.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final x in b.badges) ToneBadge(x)]),
      ],
    ]);
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.person_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textBody))),
        ]),
      );
}

/// 적용된 조건 칩: ✕ = 그 조건 빼고 다시 찾기, + 조건 = 조건 더하기
class _Filters extends StatelessWidget {
  const _Filters(this.filters, {this.onRefine});

  final List<FilterChipData> filters;
  final void Function(Map<String, Object?> set, List<String> remove, String label)? onRefine;

  static const _more = [
    ('무료만', {'free_only': true}),
    ('주차 되는 곳', {'needs': ['parking']}),
    ('피로연 되는 곳', {'needs': ['reception']}),
    ('야외', {'needs': ['outdoor']}),
    ('정원 큰 순', {'sort': 'capacity_high'}),
    ('대관료 낮은 순', {'sort': 'fee_low'}),
    ('빈 날 많은 순', {'sort': 'open_days'}),
  ];

  @override
  Widget build(BuildContext context) {
    final on = onRefine;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final f in filters)
        _pill(
          context,
          label: f.label,
          trailing: f.remove != null || f.set != null ? Icons.close : null,
          onTap: on == null || (f.remove == null && f.set == null)
              ? null
              : () => on(f.set ?? const {}, [if (f.remove != null) f.remove!], '${f.label} 빼고'),
        ),
      if (on != null)
        _pill(context, label: '조건', leading: Icons.add, outlined: true, onTap: () async {
          final picked = await showModalBottomSheet<(String, Map<String, Object?>)>(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('조건 더하기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (label, set) in _more)
                      ActionChip(
                        label: Text(label),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: AppColors.border),
                        onPressed: () => Navigator.pop(ctx, (label, set)),
                      ),
                  ]),
                ]),
              ),
            ),
          );
          if (picked != null) on(picked.$2, const [], picked.$1);
        }),
    ]);
  }

  Widget _pill(BuildContext context,
      {required String label, IconData? trailing, IconData? leading, bool outlined = false, VoidCallback? onTap}) {
    return Material(
      color: outlined ? Colors.white : AppColors.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: outlined ? BorderSide(color: AppColors.border) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[Icon(leading, size: 14, color: AppColors.primary), const SizedBox(width: 3)],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: outlined ? AppColors.primary : AppColors.textBody)),
            if (trailing != null && onTap != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 14, color: AppColors.textSecondary),
            ],
          ]),
        ),
      ),
    );
  }
}

/// 결과 카드: 1줄 이름 + 배지 / 2줄 핵심 값 / (첫 카드) 이유 / (빈 값) 문의처
class AnswerCardView extends StatelessWidget {
  const AnswerCardView({super.key, required this.card});

  final BlockCard card;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final canOpen = c.ref.contains(':') && !c.ref.startsWith('card:');
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canOpen
            ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatCardLink(ref: c.ref)))
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(c.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              if (c.badge != null) ...[const SizedBox(width: 8), ToneBadge(c.badge!)],
              if (canOpen) Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
            ]),
            if (c.values.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(c.values.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            if (c.reason != null) ...[
              const SizedBox(height: 4),
              Text('✦ ${c.reason}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
            if (c.contact != null) ...[
              const SizedBox(height: 4),
              Text('정보 없음 · 문의 ${c.contact}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.warning)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView(this.b);

  final AnswerBlock b;

  @override
  Widget build(BuildContext context) {
    final head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
    final cell = TextStyle(fontSize: 13, height: 1.35, color: AppColors.textBody);
    final label = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    final cols = b.columns.isEmpty ? (b.rows.firstOrNull?.length ?? 0) : b.columns.length;
    if (cols == 0) return const SizedBox.shrink();
    TableRow row(List<String> r, {bool isHead = false}) => TableRow(
          decoration: BoxDecoration(color: isHead ? AppColors.fill : null),
          children: [
            for (var i = 0; i < cols; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Text(i < r.length ? r[i] : '', style: isHead ? head : (i == 0 ? label : cell)),
              ),
          ],
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Table(
        border: TableBorder.all(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
        columnWidths: {0: const IntrinsicColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [if (b.columns.isNotEmpty) row(b.columns, isHead: true), for (final r in b.rows) row(r)],
      ),
    );
  }
}

class _Numbered extends StatelessWidget {
  const _Numbered(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, x) in items.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: i == 0 ? AppColors.primary : AppColors.fill, shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : AppColors.textBody)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(x, style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary))),
            ]),
          ),
      ]);
}

class _Steps extends StatelessWidget {
  const _Steps(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, x) in items.indexed)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
              if (i < items.length - 1) Container(width: 1.5, height: 18, color: AppColors.border),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(x, style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary)),
              ),
            ),
          ]),
      ]);
}

class _Budget extends StatelessWidget {
  const _Budget(this.b);

  final AnswerBlock b;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          for (final r in b.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(r.first, style: TextStyle(fontSize: 13, color: AppColors.textBody))),
                for (final x in r.skip(1))
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(x, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ),
              ]),
            ),
          if (b.title != null) ...[
            const Divider(height: 12),
            Row(children: [
              Expanded(
                  child: Text(b.title!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
            ]),
          ],
        ]),
      );
}

/// 웹에서 찾은 정보: 주황 '웹 정보' 배지 + 출처 링크 + Google 검색 제안 (검색 그라운딩 이용 조건)
class _Web extends StatelessWidget {
  const _Web(this.b);

  final AnswerBlock b;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ToneBadge(BlockBadge('웹에서 찾은 정보 · 확인 필요', Tone.check)),
          for (final w in b.web) ...[
            const SizedBox(height: 8),
            Text(w.text, style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textPrimary)),
            if (w.url != null)
              InkWell(
                onTap: () => launchUrl(Uri.parse(w.url!), mode: LaunchMode.externalApplication),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('출처 · ${w.source ?? Uri.tryParse(w.url!)?.host ?? w.url}',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
              ),
          ],
          if (b.searchQueries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final q in b.searchQueries.take(2))
                ActionChip(
                  avatar: const Icon(Icons.search, size: 14),
                  label: Text('Google 검색: $q', style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: AppColors.border),
                  onPressed: () => launchUrl(Uri.https('www.google.com', '/search', {'q': q}),
                      mode: LaunchMode.externalApplication),
                ),
            ]),
          ],
        ]),
      );
}

/// 접힌 한 줄: "출처 보기 · 어떻게 찾았나요" (F9, 기본 접힘)
class _Fold extends StatefulWidget {
  const _Fold(this.b);

  final AnswerBlock b;

  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    if (b.sources.isEmpty && b.log.isEmpty && b.detail == null) return const SizedBox.shrink();
    final small = TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textBody);
    final label = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('출처 보기 · 어떻게 찾았나요',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.textSecondary),
          ]),
        ),
      ),
      if (_open)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (b.sources.isNotEmpty) ...[
              Text('출처', style: label),
              const SizedBox(height: 4),
              for (final s in b.sources) Text('· $s', style: small),
              const SizedBox(height: 10),
            ],
            if (b.log.isNotEmpty) ...[
              Text('어떻게 찾았나요', style: label),
              const SizedBox(height: 4),
              for (final (i, s) in b.log.indexed) Text('${i + 1}. $s', style: small),
            ],
            if (b.detail != null) ...[
              const SizedBox(height: 10),
              Text('자세한 설명', style: label),
              const SizedBox(height: 4),
              Text(b.detail!, style: small),
            ],
          ]),
        ),
    ]);
  }
}
