import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const stayNestAndroidDownloadUrl =
    'https://github.com/Colin-Powell/staynest_app/releases/latest/download/staynest-android.apk';

Future<void> launchAndroidAppDownload(BuildContext context) async {
  final opened = await launchUrl(Uri.parse(stayNestAndroidDownloadUrl));
  if (opened || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open the Android download.')),
  );
}
