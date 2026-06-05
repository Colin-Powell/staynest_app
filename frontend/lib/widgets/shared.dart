import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:property_app/widgets/property_image.dart';

class CircleIconButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  final Widget child;

  const CircleIconButton({
    super.key,
    this.size = 46,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String url;
  final String name;
  final double size;
  final bool online;

  const Avatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 48,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use the project's image builder to provide consistent placeholder/error handling
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        ClipOval(
          child: buildPropertyImage(
            url.isEmpty ? '' : url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorPlaceholder: Container(
              width: size,
              height: size,
              color: AppColors.gray100,
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '',
                  style: TextStyle(
                    color: AppColors.gray900,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.4,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (online)
          Container(
            width: size * 0.24,
            height: size * 0.24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const StatusBadge({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class PropertyPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const PropertyPill({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.only(left: 6, right: 18, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: selected ? primary : AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
              color: selected ? primary : Colors.transparent, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon,
                  size: 14,
                  color: selected
                      ? primary
                      : AppTheme.primary.withValues(alpha: 179)),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  final double size;
  final Color color;

  const VerifiedBadge({
    super.key,
    this.size = 24,
    this.color = AppTheme.green,
  });

  static const String _svg =
      '''<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 256 256"><path d="M225.86,102.82c-3.77-3.94-7.67-8-9.14-11.57-1.36-3.27-1.44-8.69-1.52-13.94-.15-9.76-.31-20.82-8-28.51s-18.75-7.85-28.51-8c-5.25-.08-10.67-.16-13.94-1.52-3.56-1.47-7.63-5.37-11.57-9.14C146.28,23.51,138.44,16,128,16s-18.27,7.51-25.18,14.14c-3.94,3.77-8,7.67-11.57,9.14C88,40.64,82.56,40.72,77.31,40.8c-9.76.15-20.82.31-28.51,8S41,67.55,40.8,77.31c-.08,5.25-.16,10.67-1.52,13.94-1.47,3.56-5.37,7.63-9.14,11.57C23.51,109.72,16,117.56,16,128s7.51,18.27,14.14,25.18c3.77,3.94,7.67,8,9.14,11.57,1.36,3.27,1.44,8.69,1.52,13.94.15,9.76.31,20.82,8,28.51s18.75,7.85,28.51,8c5.25.08,10.67.16,13.94,1.52,3.56,1.47,7.63,5.37,11.57,9.14C109.72,232.49,117.56,240,128,240s18.27-7.51,25.18-14.14c3.94-3.77,8-7.67,11.57-9.14,3.27-1.36,8.69-1.44,13.94-1.52,9.76-.15,20.82-.31,28.51-8s7.85-18.75,8-28.51c.08-5.25.16-10.67,1.52-13.94,1.47-3.56,5.37-7.63,9.14-11.57C232.49,146.28,240,138.44,240,128S232.49,109.73,225.86,102.82Zm-52.2,6.84-56,56a8,8,0,0,1-11.32,0l-24-24a8,8,0,0,1,11.32-11.32L112,148.69l50.34-50.35a8,8,0,0,1,11.32,11.32Z"></path></svg>''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
