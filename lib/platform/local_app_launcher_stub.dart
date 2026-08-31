import 'package:url_launcher/url_launcher.dart';

Future<bool> launchLocalApp({required String appId, required String webUrl}) {
  return launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
}
