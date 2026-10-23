import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const stayNestAndroidDownloadUrl =
    'https://github.com/Colin-Powell/staynest_app/releases/latest/download/Staynest.apk';
const stayNestHostRegistrationUrl = 'https://staynestapp-web.vercel.app';

Future<void> launchAndroidAppDownload(BuildContext context) async {
  final opened = await launchUrl(Uri.parse(stayNestAndroidDownloadUrl));
  if (opened || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open the Android download.')),
  );
}

Future<void> launchHostRegistrationFromWeb(BuildContext context) async {
  final opened = await launchUrl(
    Uri.parse(stayNestHostRegistrationUrl),
    mode: LaunchMode.externalApplication,
  );
  if (opened || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open the host registration flow.')),
  );
}
