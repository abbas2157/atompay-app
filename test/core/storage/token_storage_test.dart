import 'package:atompay_mobile/core/storage/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('clearSessionAfterReinstall', () {
    test(
      'wipes a Keychain session left over from a previous install',
      () async {
        FlutterSecureStorage.setMockInitialValues({'auth.token': 'old'});
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await clearSessionAfterReinstall(prefs);

        expect(await secureStorage.read(key: 'auth.token'), isNull);
        expect(prefs.getBool('app.installed'), isTrue);
      },
    );

    test('leaves the session alone on later launches', () async {
      FlutterSecureStorage.setMockInitialValues({'auth.token': 'current'});
      SharedPreferences.setMockInitialValues({'app.installed': true});
      final prefs = await SharedPreferences.getInstance();

      await clearSessionAfterReinstall(prefs);

      expect(await secureStorage.read(key: 'auth.token'), 'current');
    });
  });
}
