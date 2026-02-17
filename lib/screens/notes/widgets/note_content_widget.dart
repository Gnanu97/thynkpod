// lib/screens/notes/widgets/note_content_widget.dart - COMPLETE FILE
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/note_data.dart';

class NoteContentWidget extends StatelessWidget {
  final NoteData note;
  final String searchQuery;

  const NoteContentWidget({
    Key? key,
    required this.note,
    this.searchQuery = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE9ECEF), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTranscriptSection(context),
          const SizedBox(height: 24),
          _buildSummarySection(context),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'Full Transcript',
          Icons.text_snippet, // ✅ FIXED: Use text_snippet instead
          onCopy: () => _copyToClipboard(context, note.transcript, 'Transcript'),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE9ECEF),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Character count
              Text(
                '${note.transcript.length} characters',
                style: const TextStyle(
                  color: Color(0xFF737373),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Transcript content with search highlighting
              _buildHighlightedText(
                note.transcript.isEmpty
                    ? 'No transcript available'
                    : note.transcript,
                style: TextStyle(
                  color: note.transcript.isEmpty
                      ? const Color(0xFF737373)
                      : Colors.black87,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'AI Analysis & Summary',
          Icons.psychology,
          onCopy: () => _copyToClipboard(context, note.summary, 'AI Summary'),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF0F8FF),
                const Color(0xFFF0F8FF).withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFB3D9FF).withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI badge and info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: const Color(0xFF1976D2),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'AI Generated',
                          style: TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${note.summary.length} characters',
                    style: const TextStyle(
                      color: Color(0xFF737373),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Summary content with search highlighting
              _buildHighlightedText(
                note.summary.isEmpty
                    ? 'No AI analysis available'
                    : note.summary,
                style: TextStyle(
                  color: note.summary.isEmpty
                      ? const Color(0xFF737373)
                      : Colors.black87,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
      BuildContext context,
      String title,
      IconData icon, {
        VoidCallback? onCopy,
      }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF737373),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (onCopy != null) ...[
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.copy,
                    size: 14,
                    color: Color(0xFF737373),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Copy',
                    style: TextStyle(
                      color: Color(0xFF737373),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHighlightedText(String text, {required TextStyle style}) {
    if (searchQuery.isEmpty || !text.toLowerCase().contains(searchQuery.toLowerCase())) {
      return SelectableText(
        text,
        style: style,
      );
    }

    // Highlight search query
    final query = searchQuery.toLowerCase();
    final textLower = text.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;
    while (true) {
      final index = textLower.indexOf(query, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: const Color(0xFFFFEB3B).withOpacity(0.4),
          fontWeight: FontWeight.w700,
        ),
      ));

      start = index + query.length;
    }

    return SelectableText.rich(
      TextSpan(
        style: style,
        children: spans,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String type) {
    if (text.isEmpty) {
      _showSnackBar(context, 'No $type content to copy', isError: true);
      return;
    }

    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar(context, '$type copied to clipboard');
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(milliseconds: isError ? 3000 : 2000),
      ),
    );
  }
}