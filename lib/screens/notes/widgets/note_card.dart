// lib/screens/notes/widgets/note_card.dart - COMPLETE FINAL VERSION
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../models/note_data.dart';
import '../../../services/audio_player_service.dart';

class NoteCard extends StatefulWidget {
  final NoteData note;
  final String searchQuery;

  const NoteCard({
    Key? key,
    required this.note,
    this.searchQuery = '',
  }) : super(key: key);

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isExpanded = false;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCollapsedHeader(),
            if (_isExpanded) ...[
              _buildEmbeddedAudioPlayer(),
              _buildTranscriptSection(),
              _buildSummarySection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: Color(0xFF737373),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.note.formattedDate} • ${widget.note.formattedTime}',
                style: const TextStyle(
                  color: Color(0xFF737373),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.note.formattedFileSize} • ${widget.note.formattedDuration}',
                  style: const TextStyle(
                    color: Color(0xFF737373),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            widget.note.title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA0A0A0), Color(0xFF737373)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.audiotrack,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.note.filename,
                  style: const TextStyle(
                    color: Color(0xFF737373),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: const Color(0xFF737373),
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedAudioPlayer() {
    return Consumer<AudioPlayerService>(
      builder: (context, audioService, child) {
        final isCurrentFile = audioService.currentlyPlayingFile == widget.note.filePath;
        final isPlaying = isCurrentFile && audioService.isPlaying;

        final currentPosition = isCurrentFile ? audioService.position : Duration.zero;
        final totalDuration = isCurrentFile ? audioService.duration : Duration(seconds: widget.note.durationSeconds?.round() ?? 0);

        final progress = totalDuration.inMilliseconds > 0
            ? (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFA0A0A0), Color(0xFF737373)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                height: 6,
                margin: const EdgeInsets.only(bottom: 12),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: Colors.white,
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                    overlayColor: Colors.white.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: _isDragging ? _dragValue : progress,
                    onChanged: isCurrentFile ? (value) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = value;
                      });
                    } : null,
                    onChangeStart: isCurrentFile ? (value) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = value;
                      });
                    } : null,
                    onChangeEnd: isCurrentFile ? (value) {
                      if (totalDuration.inMilliseconds > 0) {
                        final newPosition = Duration(
                          milliseconds: (totalDuration.inMilliseconds * value).round(),
                        );
                        audioService.seekTo(newPosition);
                      }
                      setState(() {
                        _isDragging = false;
                      });
                    } : null,
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.audiotrack, color: Colors.white, size: 16),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.note.filename,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${audioService.formattedPosition} / ${audioService.formattedDuration}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      GestureDetector(
                        onTap: isCurrentFile
                            ? () => audioService.skipBackward(Duration(seconds: 5))
                            : null,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(isCurrentFile ? 0.15 : 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              Icons.replay_5,
                              color: Colors.white.withOpacity(isCurrentFile ? 1.0 : 0.5),
                              size: 16
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          try {
                            if (isCurrentFile && audioService.isPlaying) {
                              await audioService.pause();
                            } else {
                              await audioService.play(widget.note.filePath);
                            }
                          } catch (e) {
                            debugPrint('Audio error: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Audio playback failed')),
                            );
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: isCurrentFile
                            ? () => audioService.skipForward(Duration(seconds: 5))
                            : null,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(isCurrentFile ? 0.15 : 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              Icons.forward_5,
                              color: Colors.white.withOpacity(isCurrentFile ? 1.0 : 0.5),
                              size: 16
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscriptSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text(
                  'Transcript',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.note.transcript.isEmpty
                ? 'No transcript available'
                : widget.note.transcript,
            style: TextStyle(
              color: widget.note.transcript.isEmpty
                  ? const Color(0xFF737373)
                  : Colors.black87,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final summary = _extractSummaryFromAnalysis(widget.note.summary);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                Text(
                  'AI Summary',
                  style: TextStyle(
                    color: const Color(0xFF1976D2),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summary.isEmpty ? 'No summary available' : summary,
            style: TextStyle(
              color: summary.isEmpty ? const Color(0xFF737373) : Colors.black87,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  String _extractSummaryFromAnalysis(String aiAnalysis) {
    if (aiAnalysis.isEmpty) return '';

    final patterns = [
      RegExp(r'\*\*📝 EXECUTIVE SUMMARY:\*\*\s*\n(.*?)(?=\n\*\*|$)', dotAll: true),
      RegExp(r'\*\*EXECUTIVE SUMMARY:\*\*\s*\n(.*?)(?=\n\*\*|$)', dotAll: true),
      RegExp(r'EXECUTIVE SUMMARY:?\s*\n(.*?)(?=\n[A-Z]|\n\*\*|$)', dotAll: true),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(aiAnalysis);
      if (match != null) {
        String summary = match.group(1) ?? '';
        summary = summary
            .replaceAll(RegExp(r'^[•\-\*]\s*', multiLine: true), '')
            .replaceAll(RegExp(r'\n+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return summary.isNotEmpty ? summary : 'Summary not available';
      }
    }

    final lines = aiAnalysis.split('\n');
    final meaningfulLines = lines
        .where((line) =>
    line.trim().isNotEmpty &&
        !line.startsWith('**') &&
        !line.startsWith('•') &&
        !line.startsWith('#') &&
        line.length > 30)
        .take(2)
        .join(' ')
        .trim();

    return meaningfulLines.isNotEmpty ? meaningfulLines : 'Summary not available';
  }
}