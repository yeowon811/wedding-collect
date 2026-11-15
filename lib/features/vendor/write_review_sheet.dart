import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/app_state.dart';
import '../../data/models/review.dart';
import '../../data/models/vendor.dart';
import 'widgets/review_widgets.dart';

const _tagOptions = [
  '친절해요', '가격이 합리적이에요', '결과물이 좋아요', '일정 조율이 쉬워요', '추가금이 없어요', '꼼꼼해요',
  '연락이 느려요', '옵션 추가금이 있어요',
];

/// 후기 쓰기: 별점 → 키워드 → 내용
Future<void> showWriteReviewSheet(BuildContext context, DemoVendor vendor) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _WriteReviewSheet(vendor: vendor),
  );
}

class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet({required this.vendor});

  final DemoVendor vendor;

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  int _rating = 0;
  final Set<String> _tags = {};
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _valid => _rating > 0 && _text.text.trim().length >= 10;

  void _submit() {
    final state = AppState.instance;
    state.addReview(Review(
      id: 'MY-${DateTime.now().microsecondsSinceEpoch}',
      vendorId: widget.vendor.id,
      author: '나',
      rating: _rating,
      date: DateTime.now(),
      text: _text.text.trim(),
      tags: _tags.toList(),
      context: '하객 ${state.plan.guests}명',
      helpful: 0,
      mine: true,
    ));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('후기를 등록했어요 (이 기기에서만 보여요)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('후기 쓰기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(widget.vendor.name, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i점',
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(
                      _rating >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 36,
                      color: kStarColor,
                    ),
                  ),
              ],
            ),
            Text(_rating == 0 ? '별점을 골라 주세요' : '$_rating점',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _tagOptions)
                  FilterChip(
                    label: Text(t),
                    selected: _tags.contains(t),
                    showCheckmark: false,
                    onSelected: (on) => setState(() => on ? _tags.add(t) : _tags.remove(t)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              maxLines: 4,
              maxLength: 300,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '상담·계약하면서 좋았던 점, 아쉬웠던 점을 10자 이상 적어 주세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _valid ? _submit : null,
              child: const Text('등록하기'),
            ),
          ],
        ),
      ),
    );
  }
}
