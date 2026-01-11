import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

class PhotoPicker extends StatelessWidget {
  final File? selectedImage;
  final VoidCallback onTap;
  final String? errorText;
  final bool isRequired;

  const PhotoPicker({
    super.key,
    this.selectedImage,
    required this.onTap,
    this.errorText,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final photoSize = isSmallScreen ? 100.0 : 120.0;
    
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: photoSize,
            height: photoSize,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: errorText != null ? Colors.red : (Colors.grey[300] ?? Colors.grey),
                width: 2,
              ),
            ),
            child: selectedImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          selectedImage ?? File(''),
                          fit: BoxFit.cover,
                          width: photoSize,
                          height: photoSize,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: isSmallScreen ? 32 : 40,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'add_photo'.tr(),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(height: 4),
                        Text(
                          'required'.tr(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText ?? '',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
