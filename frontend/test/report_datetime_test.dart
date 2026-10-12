import 'package:flutter_test/flutter_test.dart';
import 'package:pianoscope/src/report.dart';

/// `reportDatetime()` must stay byte-identical to what Rust writes, see
/// `now_rfc3339` in `backend/src/report.rs`. The Rust side is pinned by
/// `crash_report_new_stamps_rfc3339_seconds`.
void main() {
  test('reportDatetime is RFC 3339 UTC with second precision', () {
    final value = reportDatetime();

    expect(value, hasLength(20));
    expect(value, endsWith('Z'));
    expect(value.substring(4, 5), '-');
    expect(value.substring(7, 8), '-');
    expect(value.substring(10, 11), 'T');
    expect(value.substring(13, 14), ':');
    expect(value.substring(16, 17), ':');
    expect(
      int.tryParse(value.substring(0, 4)),
      isNotNull,
      reason: 'four digit year',
    );
  });
}
