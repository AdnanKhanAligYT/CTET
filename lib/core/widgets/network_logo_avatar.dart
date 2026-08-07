import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A small rounded-square logo/icon for list rows — shows [url] if set,
/// else a flat-colored fallback tile with [fallbackIcon]. Used wherever
/// an admin-uploaded logo (exam, paper, or named test) might or might not
/// be set, so a list never has a mix of real logos and blank gaps, and
/// never shows blank space while a real logo is still loading.
class NetworkLogoAvatar extends StatelessWidget {
  const NetworkLogoAvatar({
    super.key,
    required this.url,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 44,
  });

  final String? url;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(fallbackIcon, color: Colors.white, size: size * 0.5),
    );

    final logoUrl = url;
    if (logoUrl == null || logoUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, _) => fallback,
        errorWidget: (context, _, _) => fallback,
      ),
    );
  }
}
