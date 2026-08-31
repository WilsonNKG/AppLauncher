import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

const _logisticsMacBundle = String.fromEnvironment(
  'NKG_LOGISTICS_MAC_BUNDLE',
  defaultValue: 'com.example.flutTutor',
);
const _waterparkMacBundle = String.fromEnvironment(
  'NKG_WATERPARK_MAC_BUNDLE',
  defaultValue: 'com.example.waterpark',
);
const _logisticsMacPath = String.fromEnvironment(
  'NKG_LOGISTICS_MAC_PATH',
  defaultValue:
      '/Users/wilsonmehaga/Documents/Programming Projects/NKG_APP/nkg_logis_real/build/macos/Build/Products/Release/logistik_nkg.app',
);
const _waterparkMacPath = String.fromEnvironment(
  'NKG_WATERPARK_MAC_PATH',
  defaultValue:
      '/Users/wilsonmehaga/Documents/Programming Projects/NKG_APP/waterpark/build/macos/Build/Products/Release/waterpark.app',
);

Future<bool> launchLocalApp({
  required String appId,
  required String webUrl,
}) async {
  // Only these two apps currently have local desktop builds. All other
  // launcher applications open their configured web deployment.
  if (appId != 'logistics' && appId != 'waterpark') {
    return launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
  }

  if (Platform.isMacOS) {
    final bundle = appId == 'waterpark'
        ? _waterparkMacBundle
        : _logisticsMacBundle;
    final bundleResult = await Process.run('/usr/bin/open', ['-b', bundle]);
    if (bundleResult.exitCode == 0) return true;

    final path = appId == 'waterpark' ? _waterparkMacPath : _logisticsMacPath;
    if (File(path).existsSync()) {
      final pathResult = await Process.run('/usr/bin/open', [path]);
      if (pathResult.exitCode == 0) return true;
    }
  }

  if (Platform.isWindows) {
    final path = String.fromEnvironment(
      appId == 'waterpark'
          ? 'NKG_WATERPARK_WINDOWS_EXE'
          : 'NKG_LOGISTICS_WINDOWS_EXE',
    );
    if (path.isNotEmpty && File(path).existsSync()) {
      await Process.start(path, [], mode: ProcessStartMode.detached);
      return true;
    }
  }

  return launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
}
