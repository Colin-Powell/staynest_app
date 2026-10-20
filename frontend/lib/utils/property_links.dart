import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:property_app/widgets/property_image.dart';

enum _PropertyShareAction { copy, share }

class PropertyLinks {
  static String forProperty(String propertyId) {
    final configuredUrl = dotenv.env['FRONTEND_URL']?.trim();
    if (configuredUrl == null || configuredUrl.isEmpty) {
      throw StateError('FRONTEND_URL is not configured');
    }

    final baseUri = Uri.parse(configuredUrl);
    if (!{'http', 'https'}.contains(baseUri.scheme) || baseUri.host.isEmpty) {
      throw const FormatException(
          'FRONTEND_URL must be an absolute HTTP(S) URL');
    }

    return baseUri.replace(
      pathSegments: [
        ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        'properties',
        propertyId,
      ],
      query: null,
      fragment: null,
    ).toString();
  }

  static Future<bool> showShareOptions(
    BuildContext context, {
    required String propertyId,
    required String propertyName,
    required String imagePath,
    required String shareText,
  }) async {
    final link = forProperty(propertyId);
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final action = isDesktop
        ? await showDialog<_PropertyShareAction>(
            context: context,
            builder: (dialogContext) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 460,
                child: _buildShareContent(
                  dialogContext,
                  link: link,
                  propertyName: propertyName,
                  imagePath: imagePath,
                  isDesktop: true,
                ),
              ),
            ),
          )
        : await showModalBottomSheet<_PropertyShareAction>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: _buildShareContent(
                sheetContext,
                link: link,
                propertyName: propertyName,
                imagePath: imagePath,
                isDesktop: false,
              ),
            ),
          );

    if (!context.mounted || action == null) return false;
    if (action == _PropertyShareAction.copy) {
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property link copied')),
        );
      }
      return true;
    }

    await Share.share('$shareText: $link');
    return true;
  }

  static Widget _buildShareContent(
    BuildContext context, {
    required String link,
    required String propertyName,
    required String imagePath,
    required bool isDesktop,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isDesktop ? 20 : 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: buildPropertyImage(
                  imagePath,
                  width: 72,
                  height: 72,
                  errorPlaceholder: Container(
                    width: 72,
                    height: 72,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.home_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share property',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      propertyName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            link,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: const Text('Copy link'),
            onTap: () => Navigator.pop(context, _PropertyShareAction.copy),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ios_share),
            title: const Text('Share…'),
            onTap: () => Navigator.pop(context, _PropertyShareAction.share),
          ),
        ],
      ),
    );
  }
}
