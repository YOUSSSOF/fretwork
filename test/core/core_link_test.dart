import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fretwork/core/widgets/core_link.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/harness.dart';

/// Records what the widget asked the platform to open, and can refuse — a
/// device with no browser is the case the fallback exists for.
class _FakeLauncher extends UrlLauncherPlatform {
  _FakeLauncher({this.succeeds = true});

  final bool succeeds;
  final List<String> launched = [];

  /// Only meaningful on web, where a real Link widget wraps an anchor tag.
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => succeeds;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return succeeds;
  }
}

void main() {
  group('CoreLink', () {
    late _FakeLauncher launcher;

    setUp(() {
      launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
    });

    testWidgets('shows the label rather than the raw URL', (tester) async {
      await tester.pumpWidget(
        harness(
          const CoreLink(url: 'https://youdexsof.ir', label: 'youdexsof.ir'),
        ),
      );

      expect(find.text('youdexsof.ir'), findsOneWidget);
      expect(find.text('https://youdexsof.ir'), findsNothing);
    });

    testWidgets('opens the URL externally when tapped', (tester) async {
      await tester.pumpWidget(
        harness(
          const CoreLink(url: 'https://youdexsof.ir', label: 'youdexsof.ir'),
        ),
      );

      await tester.tap(find.text('youdexsof.ir'));
      await tester.pumpAndSettle();

      expect(launcher.launched, ['https://youdexsof.ir']);
    });

    testWidgets('a bare host is launched over https, not as a relative path', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const CoreLink(url: 'youdexsof.ir')));

      await tester.tap(find.text('youdexsof.ir'));
      await tester.pumpAndSettle();

      expect(launcher.launched, ['https://youdexsof.ir']);
    });

    testWidgets('copies the URL when nothing can open it', (tester) async {
      UrlLauncherPlatform.instance = _FakeLauncher(succeeds: false);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(harness(const CoreLink(url: 'youdexsof.ir')));
      await tester.tap(find.text('youdexsof.ir'));
      await tester.pumpAndSettle();

      expect(
        copied,
        'youdexsof.ir',
        reason: 'a link that does nothing at all reads as a bug',
      );
      expect(find.textContaining('copied instead'), findsOneWidget);
    });
  });
}
