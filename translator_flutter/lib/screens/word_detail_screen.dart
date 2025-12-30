import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/word.dart';
import '../providers/providers.dart';
import '../providers/word_book_notifier.dart';

/// Detail screen for viewing a single word
class WordDetailScreen extends ConsumerWidget {
  const WordDetailScreen({
    super.key,
    required this.wordId,
  });

  final String wordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wordBookProvider);
    final words = state.wordsOrNull ?? [];
    final word = words.where((w) => w.id == wordId).firstOrNull;

    if (word == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Word not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyToClipboard(context, word),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(context, ref, word),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original text
            _SectionCard(
              title: 'Original',
              child: SelectableText(
                word.text,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 16),

            // Translation
            _SectionCard(
              title: 'Translation',
              child: SelectableText(
                word.translation,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
            ),
            const SizedBox(height: 16),

            // Metadata
            _SectionCard(
              title: 'Details',
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.source,
                    label: 'Source',
                    value: word.source,
                  ),
                  if (word.sourceURL != null) ...[
                    const Divider(),
                    _DetailRow(
                      icon: Icons.link,
                      label: 'URL',
                      value: word.sourceURL!,
                      isUrl: true,
                    ),
                  ],
                  const Divider(),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Created',
                    value: _formatDateTime(word.createdAt),
                  ),
                  if (word.syncedAt != null) ...[
                    const Divider(),
                    _DetailRow(
                      icon: Icons.sync,
                      label: 'Synced',
                      value: _formatDateTime(word.syncedAt!),
                    ),
                  ],
                ],
              ),
            ),

            // Tags
            if (word.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Tags',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: word.tags
                      .map((tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Colors.blue[50],
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, Word word) {
    final text = '${word.text}\n${word.translation}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Word word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text('Are you sure you want to delete "${word.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(wordBookProvider.notifier).deleteWord(word.id);
              Navigator.of(context).pop(); // Go back to list
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isUrl = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUrl ? Colors.blue : null,
                  ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
