// lib/screens/notes/notes_screen.dart - CORRECTED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_database_service.dart';
import '../../services/title_generation_service.dart';
import '../../models/audio_file_data.dart';
import '../../models/note_data.dart';
import 'widgets/note_card.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({Key? key}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<NoteData> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late AudioDatabaseService _audioDatabase;
  late TitleGenerationService _titleService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _audioDatabase = AudioDatabaseService();
    _titleService = TitleGenerationService();
    await _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);

    try {
      final audioFiles = await _audioDatabase.getAllAudioFiles();
      final processedFiles = audioFiles
          .where((file) => file.hasTranscript && file.hasAIAnalysis)
          .toList();

      List<NoteData> notes = [];
      for (final audioFile in processedFiles) {
        String title = audioFile.title ?? '';

        if (title.isEmpty && audioFile.aiAnalysis != null) {
          title = await _titleService.generateFromSummary(audioFile.aiAnalysis!);

          // Update the database with the generated title
          if (title.isNotEmpty) {
            await _audioDatabase.updateNoteTitle(audioFile.filename, title);
          }
        }

        final noteData = NoteData.fromAudioFile(audioFile, title);
        notes.add(noteData);
      }

      setState(() {
        _notes = notes;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error loading notes: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFA0A0A0), Color(0xFF3A3A3A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _buildNotesList(),
              ),
            ],
          ),
        ),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'My Notes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${_notes.length} notes',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _loadNotes,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.white.withOpacity(0.7), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search notes, transcripts, or summaries...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    final filteredNotes = _notes.where((note) {
      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      return note.title.toLowerCase().contains(query) ||
          note.transcript.toLowerCase().contains(query) ||
          note.summary.toLowerCase().contains(query);
    }).toList();

    if (filteredNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.note_alt_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No notes found matching "$_searchQuery"'
                  : 'No notes available',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Record some audio to see your notes here',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filteredNotes.length,
      itemBuilder: (context, index) {
        final note = filteredNotes[index];
        return NoteCard(
          note: note,
          searchQuery: _searchQuery,
        );
      },
    );
  }

  void _openNote(NoteData note) {
    // Navigate to note detail screen
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (context) => NoteDetailScreen(note: note),
    // ));
    debugPrint('Opening note: ${note.title}');
  }
}