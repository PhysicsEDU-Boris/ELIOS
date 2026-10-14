// M2b: warmUp() is called when the live-scan control screen opens, so the
// first quiz doesn't show "Memuat model Gemma ke memori...". What's
// testable here without the real ~2.6 GB model (proven instead by the
// manual checklist and integration_test/live_scan_real_test.dart) is that a
// second call never starts a second, overlapping load, and that a failed
// preload (no platform plugin registered in a plain `flutter test`) never
// throws.
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ensureReady (what warmUp calls) is single-flight: a second call while one is '
      'pending does not itself start a second, overlapping load', () async {
    final service = GemmaQuizService.instance;
    var installingCount = 0;
    void onProgress() {
      if (service.progress.value.status == GemmaStatus.installing) installingCount++;
    }

    service.progress.addListener(onProgress);
    addTearDown(() => service.progress.removeListener(onProgress));

    // No await between these two: the second call must see the first's
    // in-flight future and await it, not call _install()/_initialize() of
    // its own. Checked right here, before either resolves: once there's no
    // real model (as in this test run) and the load fails, a caller that was
    // only *waiting* on someone else's load is allowed to retry on its own
    // once that failure comes back — reasonable for production (a transient
    // failure shouldn't strand a second caller), but it means installingCount
    // can still reach 2 once both calls have *settled*, so that's not what's
    // asserted here.
    final f1 = service.ensureReady();
    final f2 = service.ensureReady();
    expect(installingCount, 1, reason: 'the second call must not start its own install while the first is pending');

    await Future.wait([f1, f2]); // let both settle so this test doesn't leak state into another file
  });

  test('warmUp does not throw (a failed preload must not crash the app)', () async {
    expect(() => GemmaQuizService.instance.warmUp(), returnsNormally);
    // Let the fire-and-forget load settle (it fails fast: no platform
    // plugin is registered outside a real app) so it doesn't leak into
    // another test file's run.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
}
