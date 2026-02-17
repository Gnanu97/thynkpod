// lib/widgets/global_mini_player.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart';

class GlobalMiniPlayer extends StatefulWidget {
  const GlobalMiniPlayer({Key? key}) : super(key: key);

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioService, child) {
        if (!audioService.hasAudio || audioService.state == AudioPlayerState.stopped) {
          return SizedBox.shrink();
        }

        return GestureDetector(
          onPanUpdate: (details) {
            if (details.delta.dy > 5) {
              // FIXED: Use correct method name from AudioPlayerService
              audioService.stopAudio();
            }
          },
          child: Container(
            height: 90,
            margin:EdgeInsets.only(bottom: 20, left: 20, right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA0A0A0), Color(0xFF737373)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  // Seekable slider at top
                  Container(
                    height: 6,
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        value: _isDragging
                            ? _dragValue
                            : audioService.progress.clamp(0.0, 1.0),
                        onChanged: (value) {
                          setState(() {
                            _isDragging = true;
                            _dragValue = value;
                          });
                        },
                        onChangeStart: (value) {
                          setState(() {
                            _isDragging = true;
                            _dragValue = value;
                          });
                        },
                        onChangeEnd: (value) {
                          if (audioService.duration.inMilliseconds > 0) {
                            final newPosition = Duration(
                              milliseconds: (audioService.duration.inMilliseconds * value).round(),
                            );
                            audioService.seekTo(newPosition);
                          }
                          setState(() {
                            _isDragging = false;
                          });
                        },
                      ),
                    ),
                  ),

                  // Center-aligned content like in Image 2
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Audio icon
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.audiotrack, color: Colors.white, size: 16),
                          ),

                          SizedBox(width: 16),

                          // File info - centered
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  audioService.currentFileName ?? 'Unknown',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  '${audioService.formattedPosition} / ${audioService.formattedDuration}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 16),

                          // Control buttons - centered
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => audioService.skipBackward(Duration(seconds: 5)),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.replay_5, color: Colors.white, size: 18),
                                ),
                              ),
                              SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => audioService.togglePlayPause(),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: _buildPlayPauseIcon(audioService),
                                ),
                              ),
                              SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => audioService.skipForward(Duration(seconds: 5)),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.forward_5, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayPauseIcon(AudioPlayerService audioService) {
    switch (audioService.state) {
      case AudioPlayerState.loading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
      case AudioPlayerState.playing:
        return Icon(Icons.pause, color: Colors.white, size: 24);
      case AudioPlayerState.paused:
        return Icon(Icons.play_arrow, color: Colors.white, size: 24);
      case AudioPlayerState.error:
        return Icon(Icons.error_outline, color: Colors.red[300], size: 20);
      default:
        return Icon(Icons.play_arrow, color: Colors.white, size: 24);
    }
  }
}