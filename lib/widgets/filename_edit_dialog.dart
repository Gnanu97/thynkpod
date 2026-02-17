// lib/widgets/filename_edit_dialog.dart - FIXED VERSION
import 'package:flutter/material.dart';
import '../models/audio_file_data.dart';

class FilenameEditDialog extends StatefulWidget {
  final AudioFileData audioFile;
  final Function(String) onSave;

  const FilenameEditDialog({
    Key? key,
    required this.audioFile,
    required this.onSave,
  }) : super(key: key);

  @override
  State<FilenameEditDialog> createState() => _FilenameEditDialogState();
}

class _FilenameEditDialogState extends State<FilenameEditDialog> {
  late TextEditingController _controller;
  bool _isValid = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.audioFile.effectiveDisplayName);
    _controller.addListener(_validateInput);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateInput() {
    final text = _controller.text.trim();
    setState(() {
      if (text.isEmpty) {
        _isValid = false;
        _errorMessage = 'Name cannot be empty';
      } else if (text.length > 100) {
        _isValid = false;
        _errorMessage = 'Name too long (max 100 characters)';
      } else if (text.contains(RegExp(r'[<>:"/\\|?*]'))) {
        _isValid = false;
        _errorMessage = 'Name contains invalid characters';
      } else {
        _isValid = true;
        _errorMessage = '';
      }
    });
  }

  void _save() {
    final newName = _controller.text.trim();
    if (_isValid && newName.isNotEmpty) {
      widget.onSave(newName);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA0A0A0), Color(0xFF3A3A3A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rename Audio File',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Edit the display name for this recording',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // File info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Original filename:', widget.audioFile.filename),
                    const SizedBox(height: 8),
                    _buildInfoRow('File size:', widget.audioFile.formattedFileSize),
                    if (widget.audioFile.durationSeconds != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Duration:', widget.audioFile.formattedDuration),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Input field
              Text(
                'Display Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Enter a friendly name for this recording',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF737373), width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  prefixIcon: const Icon(
                    Icons.drive_file_rename_outline,
                    color: Color(0xFF737373),
                  ),
                  counterText: '',
                  errorText: _isValid ? null : _errorMessage,
                ),
                onSubmitted: (_) => _save(),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isValid ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isValid ? const Color(0xFF737373) : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isValid ? 2 : 0,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

// Helper function to show the dialog
Future<void> showFilenameEditDialog({
  required BuildContext context,
  required AudioFileData audioFile,
  required Function(String) onSave,
}) {
  return showDialog(
    context: context,
    builder: (context) => FilenameEditDialog(
      audioFile: audioFile,
      onSave: onSave,
    ),
  );
}