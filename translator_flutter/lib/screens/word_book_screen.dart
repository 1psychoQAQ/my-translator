import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../providers/word_book_state.dart';
import '../widgets/search_bar.dart';
import '../widgets/word_card.dart';
import 'word_detail_screen.dart';

/// Main word book screen with list and search
class WordBookScreen extends ConsumerStatefulWidget {
  const WordBookScreen({super.key});

  @override
  ConsumerState<WordBookScreen> createState() => _WordBookScreenState();
}

class _WordBookScreenState extends ConsumerState<WordBookScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wordBookProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(wordBookProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          WordSearchBar(
            onSearch: (query) {
              ref.read(wordBookProvider.notifier).search(query);
            },
          ),
          Expanded(
            child: _buildBody(state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(WordBookState state) {
    return switch (state) {
      WordBookLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      WordBookLoaded(:final words) => words.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () => ref.read(wordBookProvider.notifier).refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: words.length,
                itemBuilder: (context, index) {
                  final word = words[index];
                  return WordCard(
                    word: word,
                    onTap: () => _navigateToDetail(word.id),
                    onDelete: () => _showDeleteDialog(word.id, word.text),
                  );
                },
              ),
            ),
      WordBookError(:final error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                error.message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(wordBookProvider.notifier).refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
    };
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No words yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Words saved from screenshot or web will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(String wordId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordDetailScreen(wordId: wordId),
      ),
    );
  }

  void _showDeleteDialog(String id, String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text('Are you sure you want to delete "$text"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(wordBookProvider.notifier).deleteWord(id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Word deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
