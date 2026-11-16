import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_state.dart';
import '../../data/models/vendor.dart';
import '../../data/repositories/review_repository.dart';
import 'widgets/review_widgets.dart';
import 'write_review_sheet.dart';

enum ReviewSort {
  latest('최신순'),
  high('평점 높은순'),
  low('평점 낮은순'),
  helpful('도움돼요순');

  const ReviewSort(this.label);
  final String label;
}

/// 후기 전체 보기: 정렬, 별점 필터, 후기 쓰기
class ReviewListScreen extends StatefulWidget {
  const ReviewListScreen({super.key, required this.vendor});

  final DemoVendor vendor;

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  ReviewSort _sort = ReviewSort.latest;
  int? _star; // null = 전체

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final v = widget.vendor;
    return Scaffold(
      appBar: AppBar(title: const Text('후기')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final summary = ReviewRepository.summaryFor(v);
          final all = ReviewRepository.reviewsFor(v);
          final list = all.where((r) => _star == null || r.rating == _star).toList();
          switch (_sort) {
            case ReviewSort.latest:
              list.sort((a, b) => b.date.compareTo(a.date));
            case ReviewSort.high:
              list.sort((a, b) => b.rating.compareTo(a.rating));
            case ReviewSort.low:
              list.sort((a, b) => a.rating.compareTo(b.rating));
            case ReviewSort.helpful:
              list.sort((a, b) => b.helpful.compareTo(a.helpful));
          }
          // 내 후기는 정렬과 관계없이 맨 위
          list.sort((a, b) => (b.mine ? 1 : 0) - (a.mine ? 1 : 0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(v.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              RatingSummaryView(summary: summary),
              const SizedBox(height: 12),
              if (state.canReview(v))
                OutlinedButton(
                  onPressed: () => showWriteReviewSheet(context, v),
                  child: const Text('후기 쓰기'),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip('전체', _star == null, () => setState(() => _star = null)),
                    for (var s = 5; s >= 1; s--)
                      _chip('$s점 ${all.where((r) => r.rating == s).length}', _star == s,
                          () => setState(() => _star = _star == s ? null : s)),
                  ],
                ),
              ),
              Row(
                children: [
                  Text('${list.length}개',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  DropdownButton<ReviewSort>(
                    value: _sort,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final s in ReviewSort.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (s) => setState(() => _sort = s!),
                  ),
                ],
              ),
              for (final r in list) ReviewTile(review: r),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('이 별점의 후기가 아직 없어요')),
                ),
              const SizedBox(height: 12),
              Text(
                '시연용 가상 후기예요. 전체 ${summary.count}개 중 최근 ${ReviewRepository.sampleSize}개를 보여줘요.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        ),
      );
}
