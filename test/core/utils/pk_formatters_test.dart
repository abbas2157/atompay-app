import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/utils/pk_formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _type(TextInputFormatter f, String text) =>
    f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

void main() {
  // The tables in handbook §9.1 must pass exactly.
  group('Pk.normalizeMobile', () {
    const cases = {
      '0300 1234567': '03001234567',
      '+92 300 1234567': '03001234567',
      '0092-300-1234567': '03001234567',
      '923001234567': '03001234567',
      '3001234567': '03001234567',
      '021 34567890': '',
      '': '',
    };
    cases.forEach((input, expected) {
      test('"$input" → "$expected"', () {
        expect(Pk.normalizeMobile(input), expected);
      });
    });
  });

  group('Pk.isValidCnic', () {
    const cases = {
      '42101-7654321-9': true,
      '4210176543219': true,
      '8210176543219': false,
      '0000000000000': false,
      '421017654321': false,
    };
    cases.forEach((input, expected) {
      test('"$input" → $expected', () {
        expect(Pk.isValidCnic(input), expected);
      });
    });
  });

  test('formatCnic and formatMobile', () {
    expect(Pk.formatCnic('4210176543219'), '42101-7654321-9');
    expect(Pk.formatCnic('123'), '123');
    expect(Pk.formatMobile('+923001234567'), '0300 1234567');
    expect(Pk.formatMobile('abc'), 'abc');
  });

  test('isEmail and looksLikeMobile', () {
    expect(Pk.isEmail('ayesha@example.com'), isTrue);
    expect(Pk.isEmail('ayesha@example'), isFalse);
    expect(Pk.looksLikeMobile('+92 300-1234567'), isTrue);
    expect(Pk.looksLikeMobile('ayesha@'), isFalse);
  });

  test('isAdult is exact to the day', () {
    final now = DateTime(2026, 9, 27);
    expect(isAdult(DateTime(2008, 9, 27), now: now), isTrue);
    expect(isAdult(DateTime(2008, 9, 28), now: now), isFalse);
  });

  test('pkr formats whole rupees', () {
    expect(pkr(45000), 'PKR 45,000');
    expect(pkr(0), 'PKR 0');
    expect(pkr(1234567), 'PKR 1,234,567');
  });

  group('input formatters', () {
    test('CNIC masks and caps at 13 digits', () {
      final f = CnicInputFormatter();
      expect(_type(f, '42101').text, '42101');
      expect(_type(f, '421017').text, '42101-7');
      expect(_type(f, '42101765432199999').text, '42101-7654321-9');
    });

    test('mobile masks and normalises a pasted +92', () {
      final f = MobileInputFormatter();
      expect(_type(f, '0300').text, '0300');
      expect(_type(f, '03001').text, '0300 1');
      expect(_type(f, '+92 300 1234567').text, '0300 1234567');
    });

    test('login field leaves emails alone and formats mobiles', () {
      final f = LoginInputFormatter();
      expect(_type(f, 'ayesha@example.com').text, 'ayesha@example.com');
      expect(_type(f, '03001234567').text, '0300 1234567');
      expect(_type(f, '+92 30').text, '+92 30');
    });
  });
}
