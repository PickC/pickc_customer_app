import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../../core/theme/app_colors.dart';

class ZoomImageScreen extends StatelessWidget {
  final String imageUrl;

  const ZoomImageScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: AppColors.textLight),
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: AppColors.accentYellow),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: AppColors.textHint, size: 64),
        ),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
