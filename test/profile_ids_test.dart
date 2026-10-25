import 'package:flutter_test/flutter_test.dart';
import 'package:way/core/parser.dart';
import 'package:way/core/profile.dart';

void main() {
  group('LinkParser.genId', () {
    test('never collides in a tight loop (subscription import regression)', () {
      // The old timestamp-only id collided when many lines were parsed faster
      // than the system clock ticked (notably on Windows), which made several
      // servers share one id and highlight together.
      final ids = List.generate(20000, (_) => LinkParser.genId());
      expect(ids.toSet().length, ids.length, reason: 'all ids must be unique');
    });

    test('ids are non-empty and reasonably short', () {
      final id = LinkParser.genId();
      expect(id.isEmpty, isFalse);
      expect(id.length, lessThan(64));
    });
  });

  group('ProfileIds.repair', () {
    test('reassigns duplicate ids and reports the change count', () {
      final dup = 'same-id';
      final profiles = [
        Profile(id: dup, name: 'a', protocol: 'vless', server: 'a', port: 1),
        Profile(id: dup, name: 'b', protocol: 'vless', server: 'b', port: 2),
        Profile(id: dup, name: 'c', protocol: 'vless', server: 'c', port: 3),
        Profile(id: 'unique', name: 'd', protocol: 'vless', server: 'd', port: 4),
      ];
      final changed = ProfileIds.repair(profiles);
      expect(changed, 2);
      expect(profiles[0].id, dup, reason: 'first occurrence keeps its id');
      final ids = profiles.map((p) => p.id).toSet();
      expect(ids.length, profiles.length);
    });

    test('repairs empty ids too', () {
      final profiles = [
        Profile(id: '', name: 'a', protocol: 'vless', server: 'a', port: 1),
      ];
      expect(ProfileIds.repair(profiles), 1);
      expect(profiles.first.id.isNotEmpty, isTrue);
    });

    test('no-op on clean data', () {
      final profiles = [
        Profile(id: 'x', name: 'a', protocol: 'vless', server: 'a', port: 1),
        Profile(id: 'y', name: 'b', protocol: 'vless', server: 'b', port: 2),
      ];
      expect(ProfileIds.repair(profiles), 0);
      expect(profiles.map((p) => p.id), ['x', 'y']);
    });
  });

  group('ProfileIds.ensureUnique', () {
    test('regenerates ids that clash with existing profiles', () {
      final incoming = [
        Profile(id: 'clash', name: 'a', protocol: 'vless', server: 'a', port: 1),
        Profile(id: 'fresh', name: 'b', protocol: 'vless', server: 'b', port: 2),
      ];
      ProfileIds.ensureUnique(incoming, existingIds: {'clash'});
      expect(incoming[0].id, isNot('clash'));
      expect(incoming[1].id, 'fresh');
    });

    test('deduplicates within the incoming batch itself', () {
      final incoming = [
        Profile(id: 'dup', name: 'a', protocol: 'vless', server: 'a', port: 1),
        Profile(id: 'dup', name: 'b', protocol: 'vless', server: 'b', port: 2),
      ];
      ProfileIds.ensureUnique(incoming);
      expect(incoming[0].id, isNot(incoming[1].id));
    });
  });
}
