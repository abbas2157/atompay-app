import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/format/pk.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('money', () {
    test('formats as on the site', () {
      expect(rs(157999), 'Rs. 157,999');
      expect(rs(0), 'Rs. 0');
      expect(rsSpoken(15666), 'Rupees 15,666');
    });

    test('parses typed amounts', () {
      expect(parseRupees('1,20,000'), 120000);
      expect(parseRupees(''), isNull);
    });
  });

  group('CNIC and mobile', () {
    test('CNIC is 13 digits starting 1–7', () {
      expect(Pk.isCnic('35201-1234567-1'), isTrue);
      expect(Pk.isCnic('8520112345671'), isFalse);
      expect(Pk.isCnic('352011234567'), isFalse);
      expect(Pk.formatCnic('3520112345671'), '35201-1234567-1');
    });

    test('mobile accepts the common forms', () {
      for (final m in [
        '0300 1234567',
        '+92 300 1234567',
        '923001234567',
        '3001234567',
      ]) {
        expect(Pk.normaliseMobile(m), '03001234567', reason: m);
      }
      expect(Pk.isMobile('021 1234567'), isFalse);
      expect(Pk.formatMobile('03001234567'), '0300 1234567');
    });

    test('18 or older', () {
      final today = DateTime(2026, 11, 10);
      expect(Pk.isAdult(DateTime(2008, 11, 10), today: today), isTrue);
      expect(Pk.isAdult(DateTime(2008, 11, 11), today: today), isFalse);
    });
  });

  group('dates', () {
    test('countdown', () {
      expect(countdown(const Duration(seconds: 48)), '0:48');
      expect(countdown(const Duration(minutes: 2, seconds: 5)), '2:05');
    });

    test('relative', () {
      final now = DateTime(2026, 11, 10, 12);
      expect(
        relative(now.subtract(const Duration(minutes: 5)), now: now),
        '5 min ago',
      );
      expect(relative(DateTime(2026, 11, 9, 9), now: now), 'Yesterday');
      expect(relative(DateTime(2026, 10, 2), now: now), '2 Oct');
    });
  });

  group('version gate', () {
    test('compares major.minor.patch only', () {
      expect(isBelow('1.0.0-dev', '1.0.1'), isTrue);
      expect(isBelow('1.0.0-dev', '1.0.0'), isFalse);
      expect(isBelow('1.2.0', '1.10.0'), isTrue);
      expect(isBelow('2.0.0', '1.9.9'), isFalse);
    });
  });
}
