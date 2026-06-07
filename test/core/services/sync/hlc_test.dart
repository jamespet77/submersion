import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/hlc.dart';

/// Unit tests for the Hybrid Logical Clock value type. Pure, no DB.
void main() {
  group('Hlc', () {
    test('parse(toString()) round-trips all components', () {
      final hlc = Hlc(1700000000000, 7, 'device-abc');
      final parsed = Hlc.parse(hlc.toString());
      expect(parsed.physicalTime, 1700000000000);
      expect(parsed.counter, 7);
      expect(parsed.nodeId, 'device-abc');
    });

    test('parse preserves a nodeId that itself contains the separator', () {
      final hlc = Hlc(1700000000000, 0, 'a:b:c');
      final parsed = Hlc.parse(hlc.toString());
      expect(parsed.nodeId, 'a:b:c');
    });

    test('orders by physical time first', () {
      final older = Hlc(1000, 999, 'z');
      final newer = Hlc(2000, 0, 'a');
      expect(older.compareTo(newer), lessThan(0));
      expect(newer.compareTo(older), greaterThan(0));
    });

    test('breaks ties on counter when physical times are equal', () {
      final lo = Hlc(1000, 1, 'z');
      final hi = Hlc(1000, 2, 'a');
      expect(lo.compareTo(hi), lessThan(0));
    });

    test('breaks ties on nodeId when physical and counter are equal', () {
      final a = Hlc(1000, 1, 'aaa');
      final b = Hlc(1000, 1, 'bbb');
      expect(a.compareTo(b), lessThan(0));
      expect(a.compareTo(Hlc(1000, 1, 'aaa')), 0);
    });

    group('increment (local event)', () {
      test('advances physical time and resets counter when wall clock moved '
          'forward', () {
        final clock = Hlc(1000, 5, 'node');
        final next = clock.increment(2000);
        expect(next.physicalTime, 2000);
        expect(next.counter, 0);
        expect(next.nodeId, 'node');
      });

      test('keeps physical time and bumps counter when wall clock has not '
          'advanced (skew or same millisecond)', () {
        final clock = Hlc(2000, 5, 'node');
        final next = clock.increment(1900); // wall clock is behind
        expect(next.physicalTime, 2000);
        expect(next.counter, 6);
      });
    });

    group('merge (receive event)', () {
      test('adopts a higher remote physical time and follows its counter '
          '(the clock-skew fix)', () {
        // Local wall clock is behind; a remote HLC carries a higher physical
        // time. After merge our clock must jump forward so our next local
        // write is ordered after the remote event.
        final local = Hlc(1000, 0, 'me');
        final remote = Hlc(5000, 3, 'other');
        final merged = local.merge(remote, 1100); // wall clock still ~1100
        expect(merged.physicalTime, 5000);
        expect(merged.counter, 4); // remote.counter + 1
        expect(merged.nodeId, 'me'); // identity stays ours
      });

      test('uses wall clock when it exceeds both sides', () {
        final local = Hlc(1000, 2, 'me');
        final remote = Hlc(2000, 9, 'other');
        final merged = local.merge(remote, 9000);
        expect(merged.physicalTime, 9000);
        expect(merged.counter, 0);
      });

      test('bumps max counter when all three physical times are equal', () {
        final local = Hlc(3000, 4, 'me');
        final remote = Hlc(3000, 6, 'other');
        final merged = local.merge(remote, 3000);
        expect(merged.physicalTime, 3000);
        expect(merged.counter, 7); // max(4, 6) + 1
      });
    });
  });
}
