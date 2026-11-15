import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/venue.dart';

/// 예약 유형별 아이콘과 색
extension BookingTypeStyle on BookingType {
  IconData get icon => switch (this) {
        BookingType.online => Icons.language,
        BookingType.form => Icons.description_outlined,
        BookingType.phoneVisit => Icons.call_outlined,
        BookingType.center => Icons.apartment,
      };

  Color get color => switch (this) {
        BookingType.online => AppColors.primaryDark,
        BookingType.form => const Color(0xFF5B7FD6),
        BookingType.phoneVisit => const Color(0xFFB0753A),
        BookingType.center => const Color(0xFF8A62C4),
      };
}
