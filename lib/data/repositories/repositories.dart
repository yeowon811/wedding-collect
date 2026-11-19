import 'booking_repository.dart';
import 'policy_repository.dart';
import 'vendor_repository.dart';
import 'venue_repository.dart';

/// 앱 전체에서 같이 쓰는 저장소 (한 번 읽은 데이터를 다시 읽지 않도록 하나만 만든다)
class Repos {
  Repos._();

  static final venue = VenueRepository();
  static final policy = PolicyRepository();
  static final vendor = VendorRepository();
  static final booking = BookingRepository();
}
