// lib/widgets/download_progress_overlay.dart
import 'package:flutter/material.dart';

class DownloadProgressOverlay extends StatelessWidget {
  final String filename;
  final double progress;
  final String downloadSpeed;
  final String timeRemaining;
  final VoidCallback? onCancel;

  const DownloadProgressOverlay({
    Key? key,
    required this.filename,
    required this.progress,
    required this.downloadSpeed,
    required this.timeRemaining,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Container(
            width: 340,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with ThynkPod gradient
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFA0A0A0),
                        Color(0xFF3A3A3A),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                SizedBox(height: 20),

                // Downloading text
                Text(
                  'Downloading',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 8),

                // Filename
                Text(
                  filename,
                  style: TextStyle(
                    color: Color(0xFF737373),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 24),

                // Progress bar with ThynkPod gradient
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFA0A0A0),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Progress details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        color: Color(0xFF737373),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      downloadSpeed,
                      style: TextStyle(
                        color: Color(0xFF737373),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // Time remaining
                Text(
                  timeRemaining,
                  style: TextStyle(
                    color: Color(0xFF737373),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: 24),

                // Cancel button (optional)
                if (onCancel != null)
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF737373),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}