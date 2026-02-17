// lib/screens/files/files_screen.dart - COMPLETE VERSION WITH ALL FIXES
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/speech_to_text_service.dart';
import '../../services/groq_ai_service.dart';
import '../../services/audio_database_service.dart';
import '../../models/audio_file_data.dart';
import '../../widgets/filename_edit_dialog.dart';
import '../../widgets/global_mini_player.dart';
import '../../finance_tracking/providers/finance_provider.dart';
import '../../finance_tracking/screens/finance_dashboard_screen.dart';

class AudioFile {
  final String name;
  final String size;
  final String duration;
  final DateTime dateAdded;
  final String? localPath;

  AudioFile(this.name, this.size, this.duration, this.dateAdded, {this.localPath});
}

class FilesScreen extends StatefulWidget {
  const FilesScreen({Key? key}) : super(key: key);

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _selectedFilter = 'All';
  String _sortBy = 'Date';
  List<AudioFile> _audioFiles = [];
  bool _isLoading = true;
  Set<String> _expandedFiles = {};
  Map<String, bool> _isProcessing = {};

  final SpeechToTextService _speechService = SpeechToTextService();
  final GroqAIService _aiService = GroqAIService();
  late AudioDatabaseService _audioDatabase;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _audioDatabase = AudioDatabaseService();
    await _loadDownloadedFiles();
    _audioDatabase.addListener(_onDatabaseChanged);
  }

  @override
  void dispose() {
    _audioDatabase.removeListener(_onDatabaseChanged);
    super.dispose();
  }

  void _onDatabaseChanged() {
    if (mounted) _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    setState(() => _isLoading = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/downloads');
      final recordingsDir = Directory('${directory.path}/recordings');

      final List<Directory> sourceDirs = [];
      if (await downloadsDir.exists()) sourceDirs.add(downloadsDir);
      if (await recordingsDir.exists()) sourceDirs.add(recordingsDir);

      final List<AudioFile> audioFiles = [];

      for (final dir in sourceDirs) {
        final files = dir.listSync().whereType<File>();

        for (final file in files) {
          final fileName = file.path.split('/').last;
          if (!_isAudioFile(fileName)) continue;

          final fileStats = await file.stat();
          final durationSeconds = await _getActualDuration(file.path);

          // Sync into SQLite if not already present
          final exists = await _audioDatabase.fileExists(fileName);
          if (!exists) {
            final audioFileData = AudioFileData.fromFileInfo(
              filename: fileName,
              filePath: file.path,
              fileSizeBytes: fileStats.size,
              durationSeconds: durationSeconds,
            );

            // Decide source based on folder
            final source = dir.path.endsWith('recordings') ? 'phone' : 'esp32';
            await _audioDatabase.saveAudioFile(audioFileData, source: source);
          }

          audioFiles.add(
            AudioFile(
              fileName,
              _formatFileSize(fileStats.size),
              _formatDuration(durationSeconds),
              fileStats.modified,
              localPath: file.path,
            ),
          );
        }
      }

      setState(() => _audioFiles = audioFiles);
    } catch (e) {
      debugPrint('Error loading files: $e');
      setState(() => _audioFiles = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isAudioFile(String fileName) {
    const audioExtensions = ['.mp3', '.wav', '.flac', '.aac', '.m4a'];
    return audioExtensions.any((ext) => fileName.toLowerCase().endsWith(ext));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // FIXED: Proper duration calculation for ESP32 recordings
  Future<double> _getActualDuration(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();

      // ESP32 records at 16kHz, 16-bit, mono
      // Calculate actual duration: (file_size - WAV_header) / (sample_rate * bytes_per_sample)
      final audioDataSize = fileSize - 44; // WAV header is 44 bytes
      final bytesPerSecond = 16000 * 2; // 16kHz * 2 bytes per sample
      return audioDataSize / bytesPerSecond;
    } catch (e) {
      debugPrint('Error calculating duration: $e');
      return 0.0;
    }
  }

  String _formatDuration(double durationSeconds) {
    final duration = Duration(seconds: durationSeconds.round());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  List<AudioFile> get _filteredFiles {
    List<AudioFile> filtered = List.from(_audioFiles);

    if (_selectedFilter != 'All') {
      filtered = filtered.where((file) {
        final daysDiff = DateTime.now().difference(file.dateAdded).inDays;
        switch (_selectedFilter) {
          case 'Today': return daysDiff == 0;
          case 'This Week': return daysDiff <= 7;
          case 'This Month': return daysDiff <= 30;
          default: return true;
        }
      }).toList();
    }

    // FIXED: Proper sorting implementation
    switch (_sortBy) {
      case 'Date':
        filtered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case 'Name':
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'Size':
        filtered.sort((a, b) => _getSizeInBytes(b.size).compareTo(_getSizeInBytes(a.size)));
        break;
      case 'Duration':
        filtered.sort((a, b) => _getDurationInSeconds(b.duration).compareTo(_getDurationInSeconds(a.duration)));
        break;
    }
    return filtered;
  }

  int _getSizeInBytes(String size) {
    final parts = size.split(' ');
    final value = double.parse(parts[0]);
    final unit = parts[1].toLowerCase();
    switch (unit) {
      case 'b': return value.round();
      case 'kb': return (value * 1024).round();
      case 'mb': return (value * 1024 * 1024).round();
      case 'gb': return (value * 1024 * 1024 * 1024).round();
      default: return value.round();
    }
  }

  int _getDurationInSeconds(String duration) {
    final parts = duration.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return minutes * 60 + seconds;
    }
    return 0;
  }

  // FIXED: Proper audio processing with finance integration
  Future<void> _processAudio(AudioFile file) async {
    if (_isProcessing[file.name] == true) return;

    setState(() => _isProcessing[file.name] = true);

    try {
      final dbFile = await _audioDatabase.getAudioFile(file.name);
      if (dbFile == null) return;

      if (dbFile.hasTranscript && dbFile.hasAIAnalysis) {
        _showSnackBar('Already processed!', Icons.check_circle, Colors.green);
        return;
      }

      if (!dbFile.hasTranscript) {
        _showSnackBar('Generating transcript...', Icons.mic, const Color(0xFF737373));

        final transcript = await _speechService.transcribe(file.localPath!);
        if (transcript.isNotEmpty) {
          await _audioDatabase.saveTranscript(file.name, transcript);
          _showSnackBar('Transcript generated!', Icons.check_circle, Colors.green);
        } else {
          _showSnackBar('Transcript generation failed', Icons.error, Colors.red);
          return;
        }
      }

      if (!dbFile.hasAIAnalysis) {
        _showSnackBar('Generating AI analysis...', Icons.psychology, const Color(0xFF737373));

        final updatedFile = await _audioDatabase.getAudioFile(file.name);
        if (updatedFile?.transcript != null) {
          final analysis = await _aiService.analyze(updatedFile!.transcript!);
          if (analysis.isNotEmpty) {
            await _audioDatabase.saveAIAnalysis(file.name, analysis);
            _showSnackBar('AI analysis complete!', Icons.check_circle, Colors.green);

            // FIXED: Finance transaction processing with database
            final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
            final detectedTransactions = await financeProvider.processVoiceTransaction(updatedFile.transcript!, file.name);

            if (detectedTransactions.isNotEmpty) {
              final totalAmount = detectedTransactions.fold(0.0, (sum, t) => sum + t.amount);
              final categories = detectedTransactions.map((t) => t.category).toSet().join(', ');
              _showFinanceDetectedSnackBar(totalAmount, categories, detectedTransactions.length);
            }
          } else {
            _showSnackBar('AI analysis failed', Icons.error, Colors.red);
          }
        }
      }

    } catch (e) {
      debugPrint('Error processing audio: $e');
      _showSnackBar('Processing failed: $e', Icons.error, Colors.red);
    } finally {
      setState(() => _isProcessing[file.name] = false);
    }
  }

  Future<void> _editFileName(AudioFile file) async {
    final dbFile = await _audioDatabase.getAudioFile(file.name);
    if (dbFile == null) return;

    await showFilenameEditDialog(
      context: context,
      audioFile: dbFile,
      onSave: (newName) async {
        try {
          await _audioDatabase.updateDisplayName(file.name, newName);
          _showSnackBar('Name updated successfully!', Icons.check_circle, Colors.green);
        } catch (e) {
          _showSnackBar('Failed to update name: $e', Icons.error, Colors.red);
        }
      },
    );
  }

  Future<void> _deleteFile(AudioFile file) async {
    final confirm = await _showConfirmDialog(
      'Delete File',
      'Are you sure you want to delete "${file.name}"?\n\nThis action cannot be undone.',
      Icons.delete,
      Colors.red,
      'Delete',
    );

    if (confirm == true) {
      try {
        if (file.localPath != null) {
          final fileToDelete = File(file.localPath!);
          if (await fileToDelete.exists()) {
            await fileToDelete.delete();
          }
        }

        await _audioDatabase.deleteAudioFile(file.name);

        setState(() {
          _isProcessing.remove(file.name);
          _expandedFiles.remove(file.name);
        });

        await _loadDownloadedFiles();
        _showSnackBar('${file.name} deleted successfully', Icons.check_circle, Colors.green);
      } catch (e) {
        _showSnackBar('Failed to delete file: $e', Icons.error, Colors.red);
      }
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showFinanceDetectedSnackBar(double totalAmount, String categories, int transactionCount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Added ₹${totalAmount.toInt()} across $transactionCount transaction${transactionCount > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Categories: $categories',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FinanceDashboardScreen())),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content, IconData icon, Color color, String actionText) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFA0A0A0), Color(0xFF3A3A3A)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildFilters(),
                  _buildCacheActions(),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: _isLoading
                          ? _buildLoadingState()
                          : _filteredFiles.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                        onRefresh: _loadDownloadedFiles,
                        child: ListView.builder(
                          itemCount: _filteredFiles.length,
                          itemBuilder: (context, index) => _buildFileItem(_filteredFiles[index]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(bottom: 0, left: 0, right: 0, child: GlobalMiniPlayer()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Text(
              'Downloaded Files',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: _loadDownloadedFiles,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Flexible(flex: 2, child: _buildFilterDropdown()),
          const SizedBox(width: 8),
          Flexible(flex: 2, child: _buildSortDropdown()),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15)
            ),
            child: Text(
                '${_filteredFiles.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return GestureDetector(
      onTap: () => _showBottomSheet('Filter Files', ['All', 'Today', 'This Week', 'This Month'], _selectedFilter, (value) => setState(() => _selectedFilter = value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(25)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(_selectedFilter, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return GestureDetector(
      onTap: () => _showBottomSheet('Sort Files', ['Date', 'Name', 'Size', 'Duration'], _sortBy, (value) => setState(() => _sortBy = value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(25)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(_sortBy, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(child: _buildActionButton('Transcript & AI', Icons.psychology, [const Color(0xFF2196F3), const Color(0xFF1976D2)], _bulkProcessAllFiles)),
          const SizedBox(width: 12),
          Expanded(child: _buildActionButton('Clear Data', Icons.clear_all, [Colors.red[400]!, Colors.red[600]!], () async {
            final confirm = await _showConfirmDialog('Clear All Data', 'This will delete all cached transcripts and AI analysis for all files.\n\nYou\'ll need to regenerate them if needed. This action cannot be undone.', Icons.clear_all, Colors.red, 'Clear All');
            if (confirm == true) {
              await _audioDatabase.clearAllData();
              _showSnackBar('Data cleared successfully!', Icons.check_circle, Colors.green);
            }
          })),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, List<Color> gradientColors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: gradientColors[0].withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkProcessAllFiles() async {
    final unprocessedFiles = <AudioFile>[];

    for (final file in _audioFiles) {
      final dbFile = await _audioDatabase.getAudioFile(file.name);
      if (dbFile != null && !dbFile.isFullyProcessed) {
        unprocessedFiles.add(file);
      }
    }

    if (unprocessedFiles.isEmpty) {
      _showSnackBar('All files are already processed!', Icons.check_circle, Colors.green);
      return;
    }

    final confirm = await _showConfirmDialog(
      'Process All Files',
      'This will generate transcripts and AI analysis for ${unprocessedFiles.length} files.\n\nThis may take several minutes.',
      Icons.psychology,
      const Color(0xFF737373),
      'Process All',
    );

    if (confirm == true) {
      for (final file in unprocessedFiles) {
        await _processAudio(file);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
          SizedBox(height: 20),
          Text('Loading downloaded files...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_outlined, size: 80, color: Colors.white70),
          SizedBox(height: 20),
          Text('No downloaded files', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          Text('Download files from ESP32 Recordings\nto see them here', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showBottomSheet(String title, List<String> options, String selected, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.black87)),
            const SizedBox(height: 20),
            ...options.map((option) => _buildOption(option, selected == option, () {
              onSelect(option);
              Navigator.pop(context);
            })).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F0F0) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFD9D9D9) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFF737373) : Colors.grey[400], size: 20),
            const SizedBox(width: 15),
            Text(text, style: TextStyle(color: isSelected ? Colors.black87 : Colors.grey[700], fontSize: 16, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // FIXED: Kebab menu with rename and delete options
  void _showFileOptions(AudioFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(file.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF2196F3), size: 22),
              title: const Text('Rename', style: TextStyle(color: Color(0xFF2196F3), fontSize: 16, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _editFileName(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red, size: 22),
              title: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _deleteFile(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildFileItem(AudioFile file) {
    final isExpanded = _expandedFiles.contains(file.name);

    return Consumer<AudioPlayerService>(
      builder: (context, audioService, child) {
        final isCurrentFile = audioService.isActiveFile(file.localPath ?? '');
        final isPlaying = isCurrentFile && audioService.isPlaying;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCurrentFile ? const Color(0xFFF0F8FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isCurrentFile
                ? [BoxShadow(color: const Color(0xFFA0A0A0).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  isExpanded ? _expandedFiles.remove(file.name) : _expandedFiles.add(file.name);
                }),
                child: _buildFileHeader(file, isCurrentFile, isPlaying, audioService),
              ),
              if (isExpanded) _buildExpandableContent(file),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileHeader(AudioFile file, bool isCurrentFile, bool isPlaying, AudioPlayerService audioService) {
    return FutureBuilder<AudioFileData?>(
      future: _audioDatabase.getAudioFile(file.name),
      builder: (context, snapshot) {
        final dbFile = snapshot.data;
        final isProcessing = _isProcessing[file.name] == true;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: isCurrentFile ? const Color(0xFF4CAF50) : const Color(0xFFA0A0A0),
                    shape: BoxShape.circle
                ),
                child: const Icon(Icons.audiotrack, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildFileInfo(file, dbFile, isCurrentFile, audioService)),
              _buildFileControls(file, isCurrentFile, isPlaying, isProcessing, audioService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileInfo(AudioFile file, AudioFileData? dbFile, bool isCurrentFile, AudioPlayerService audioService) {
    final displayName = dbFile?.effectiveDisplayName ?? file.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            displayName,
            style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            Text(
                _formatDateTime(file.dateAdded),
                style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 10)
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 10, color: Colors.black.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(file.duration, style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 10)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(8)),
              child: Text(file.size, style: const TextStyle(color: Color(0xFF737373), fontSize: 9, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        if (isCurrentFile && audioService.hasAudio)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              value: audioService.progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA0A0A0)),
              minHeight: 3,
            ),
          ),
      ],
    );
  }

  Widget _buildFileControls(AudioFile file, bool isCurrentFile, bool isPlaying, bool isProcessing, AudioPlayerService audioService) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (file.localPath == null) {
              _showSnackBar('File path not found', Icons.error, Colors.red);
              return;
            }
            audioService.playAudio(file.localPath!, file.name);
          },
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
                color: isCurrentFile ? const Color(0xFF4CAF50) : const Color(0xFFA0A0A0),
                shape: BoxShape.circle
            ),
            child: audioService.isLoading && isCurrentFile
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showFileOptions(file),
          child: Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(color: Color(0xFFA0A0A0), shape: BoxShape.circle),
            child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: const Color(0xFFA0A0A0).withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(_expandedFiles.contains(file.name) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFFA0A0A0), size: 20),
        ),
      ],
    );
  }

  Widget _buildExpandableContent(AudioFile file) {
    return FutureBuilder<AudioFileData?>(
      future: _audioDatabase.getAudioFile(file.name),
      builder: (context, snapshot) {
        final dbFile = snapshot.data;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 1, color: Colors.grey[300]),
              const SizedBox(height: 16),
              _buildProcessButton(file),
              const SizedBox(height: 16),
              if (dbFile?.hasTranscript == true && dbFile!.transcript != null)
                _buildContentCard('Transcript', dbFile.transcript!, Icons.transcribe, const Color(0xFF4CAF50), const Color(0xFFF0F8F0)),
              if (dbFile?.hasAIAnalysis == true && dbFile!.aiAnalysis != null) ...[
                const SizedBox(height: 12),
                _buildContentCard('AI Analysis', dbFile.aiAnalysis!, Icons.psychology, const Color(0xFFA0A0A0), const Color(0xFFF5F5F5)),
              ] else if (dbFile?.hasTranscript == true) ...[
                const SizedBox(height: 12),
                _buildWarningCard(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProcessButton(AudioFile file) {
    final isProcessing = _isProcessing[file.name] == true;

    return GestureDetector(
      onTap: () => _processAudio(file),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isProcessing)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            else
              const Icon(Icons.psychology, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isProcessing ? 'Processing...' : 'Transcription & AI',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCard(String title, String content, IconData icon, Color iconColor, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: iconColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: iconColor == const Color(0xFF4CAF50)
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF424242),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: _buildFormattedContent(content, iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedContent(String content, Color accentColor) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('**') && line.endsWith('**')) {
        widgets.add(_buildSectionHeader(line.replaceAll('*', ''), accentColor));
      } else if (line.startsWith('•') || line.startsWith('-')) {
        widgets.add(_buildBulletPoint(line.substring(1).trim()));
      } else if (line.contains(':') && line.length < 100) {
        final parts = line.split(':');
        if (parts.length == 2) {
          widgets.add(_buildKeyValuePair(parts[0].trim(), parts[1].trim(), accentColor));
        } else {
          widgets.add(_buildRegularText(line));
        }
      } else {
        widgets.add(_buildRegularText(line));
      }

      if (i < lines.length - 1) {
        widgets.add(const SizedBox(height: 8));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSectionHeader(String text, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: accentColor == const Color(0xFF4CAF50)
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF424242),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF737373),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValuePair(String key, String value, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            key + ':',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildRegularText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Transcript available but AI analysis pending. Tap "Process" to generate AI insights.',
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            ),
          ),
        ],
      ),
    );
  }
}