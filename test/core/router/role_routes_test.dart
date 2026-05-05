import 'package:flutter_test/flutter_test.dart';
import 'package:ghanaclass_school_management/core/router/role_routes.dart';

void main() {
  group('homeRouteForRoleName', () {
    test('maps known roles to correct home routes', () {
      expect(homeRouteForRoleName('admin'), '/dashboard');
      expect(homeRouteForRoleName('director'), '/director');
      expect(homeRouteForRoleName('teacher'), '/teacher');
      expect(homeRouteForRoleName('accountant'), '/accountant');
      expect(homeRouteForRoleName('shop'), '/shop/dashboard');
      expect(homeRouteForRoleName('headmaster'), '/dashboard');
      expect(homeRouteForRoleName('headmistress'), '/dashboard');
      // Legacy/removed portal roles now fall back to dashboard.
      expect(homeRouteForRoleName('secretary'), '/dashboard');
      expect(homeRouteForRoleName('security'), '/dashboard');
      expect(homeRouteForRoleName('library'), '/dashboard');
      expect(homeRouteForRoleName('infirmary'), '/dashboard');
      expect(homeRouteForRoleName('chef'), '/dashboard');
      expect(homeRouteForRoleName('ictlab'), '/dashboard');
      expect(homeRouteForRoleName('sciencelab'), '/dashboard');
      expect(homeRouteForRoleName('parent'), '/dashboard');
    });

    test('normalizes role tokens with spaces/punctuation', () {
      expect(homeRouteForRoleName('School Director'), '/director');
      expect(homeRouteForRoleName('HEAD-MISTRESS'), '/dashboard');
      expect(homeRouteForRoleName('ICT-Lab'), '/dashboard');
    });

    test('falls back to dashboard for unknown roles', () {
      expect(homeRouteForRoleName('unknown_role'), '/dashboard');
      expect(homeRouteForRoleName(''), '/dashboard');
    });
  });
}
