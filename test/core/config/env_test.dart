import 'package:atompay_mobile/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flavor.parse', () {
    test('parses known flavours', () {
      expect(Flavor.parse('dev'), Flavor.dev);
      expect(Flavor.parse('staging'), Flavor.staging);
      expect(Flavor.parse('prod'), Flavor.prod);
    });

    test('falls back to dev for unknown values', () {
      expect(Flavor.parse('nope'), Flavor.dev);
    });
  });
}
