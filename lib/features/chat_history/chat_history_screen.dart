import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/providers.dart';

// ── Filter chips ──────────────────────────────────────────────────────────────

enum _ChatFilter {
  all('All'),
  solved('Solved'),
  unsolved('Unsolved'),
  thisWeek('This week'),
  bookmarked('Bookmarked'),
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  final String label;
  const _ChatFilter(this.label);
}

// ── Chat item model ───────────────────────────────────────────────────────────

class _ChatItem {
  final String problemId;
  final String title;
  final String difficulty;
  final List<String> tags;
  final String lastMessage;
  final bool lastMessageIsAI;
  final DateTime lastActive;
  final bool isSolved;
  final bool isBookmarked;

  const _ChatItem({
    required this.problemId,
    required this.title,
    required this.difficulty,
    required this.tags,
    required this.lastMessage,
    required this.lastMessageIsAI,
    required this.lastActive,
    required this.isSolved,
    required this.isBookmarked,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  final Set<_ChatFilter> _activeFilters = {_ChatFilter.all};
  bool _searchMode = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Pending deletions for undo support
  final Map<String, _ChatItem> _pendingDeletions = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  Color _difficultyColor(String d) {
    switch (d.toLowerCase()) {
      case 'easy':
        return AppColors.easy;
      case 'medium':
        return AppColors.medium;
      default:
        return AppColors.hard;
    }
  }

  List<_ChatItem> _applyFilters(List<_ChatItem> items) {
    var filtered = items;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((i) =>
              i.title.toLowerCase().contains(q) ||
              i.tags.any((t) => t.toLowerCase().contains(q)) ||
              i.lastMessage.toLowerCase().contains(q))
          .toList();
      return filtered;
    }

    if (!_activeFilters.contains(_ChatFilter.all)) {
      if (_activeFilters.contains(_ChatFilter.solved)) {
        filtered = filtered.where((i) => i.isSolved).toList();
      }
      if (_activeFilters.contains(_ChatFilter.unsolved)) {
        filtered = filtered.where((i) => !i.isSolved).toList();
      }
      if (_activeFilters.contains(_ChatFilter.bookmarked)) {
        filtered = filtered.where((i) => i.isBookmarked).toList();
      }
      if (_activeFilters.contains(_ChatFilter.thisWeek)) {
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        filtered = filtered.where((i) => i.lastActive.isAfter(cutoff)).toList();
      }
      if (_activeFilters.contains(_ChatFilter.easy)) {
        filtered = filtered
            .where((i) => i.difficulty.toLowerCase() == 'easy')
            .toList();
      }
      if (_activeFilters.contains(_ChatFilter.medium)) {
        filtered = filtered
            .where((i) => i.difficulty.toLowerCase() == 'medium')
            .toList();
      }
      if (_activeFilters.contains(_ChatFilter.hard)) {
        filtered = filtered
            .where((i) => i.difficulty.toLowerCase() == 'hard')
            .toList();
      }
    }

    return filtered;
  }

  void _toggleFilter(_ChatFilter filter) {
    setState(() {
      if (filter == _ChatFilter.all) {
        _activeFilters
          ..clear()
          ..add(_ChatFilter.all);
      } else {
        _activeFilters.remove(_ChatFilter.all);
        if (_activeFilters.contains(filter)) {
          _activeFilters.remove(filter);
          if (_activeFilters.isEmpty) _activeFilters.add(_ChatFilter.all);
        } else {
          _activeFilters.add(filter);
        }
      }
    });
  }

  void _deleteChat(BuildContext ctx, _ChatItem item) {
    setState(() => _pendingDeletions[item.problemId] = item);

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('Chat deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _pendingDeletions.remove(item.problemId));
          },
        ),
        duration: const Duration(seconds: 5),
        onVisible: () {
          Future.delayed(const Duration(seconds: 5), () {
            final uid = ref.read(authStateProvider).value?.uid;
            if (uid != null && _pendingDeletions.containsKey(item.problemId)) {
              _pendingDeletions.remove(item.problemId);
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('chats')
                  .doc(item.problemId)
                  .delete();
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final uid = authAsync.value?.uid;
    final solvedSet =
        ref.watch(solvedProblemsProvider).value?.toSet() ?? {};
    final bookmarksSet =
        ref.watch(bookmarksProvider).value?.toSet() ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _searchMode
          ? _buildSearchAppBar()
          : _buildNormalAppBar(),
      body: uid == null
          ? const Center(
              child: Text('Not signed in.', style: AppTextStyles.bodySecondary))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('chats')
                  .orderBy('lastMessageAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }

                final docs = snap.data?.docs ?? [];
                final allItems = docs
                    .map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final ts = d['lastMessageAt'];
                      DateTime lastActive = DateTime.now();
                      if (ts is Timestamp) lastActive = ts.toDate();
                      final problemId = doc.id;
                      final problemIdInt = int.tryParse(problemId) ?? 0;
                      return _ChatItem(
                        problemId: problemId,
                        title: d['title'] as String? ?? 'Problem #$problemId',
                        difficulty: d['difficulty'] as String? ?? 'Medium',
                        tags: List<String>.from(d['tags'] ?? []),
                        lastMessage:
                            d['lastMessage'] as String? ?? '…',
                        lastMessageIsAI: d['lastMessageIsAI'] as bool? ?? true,
                        lastActive: lastActive,
                        isSolved: solvedSet.contains(problemIdInt),
                        isBookmarked: bookmarksSet.contains(problemIdInt),
                      );
                    })
                    .where((i) => !_pendingDeletions.containsKey(i.problemId))
                    .toList();

                final filtered = _applyFilters(allItems);

                return Column(
                  children: [
                    if (!_searchMode) _buildFilterChips(),
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState(allItems.isEmpty)
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final item = filtered[i];
                                return _ChatListItem(
                                  item: item,
                                  searchQuery: _searchQuery,
                                  difficultyColor:
                                      _difficultyColor(item.difficulty),
                                  relativeTime: _relativeTime(item.lastActive),
                                  onTap: () =>
                                      context.push('/problem/${item.problemId}/chat'),
                                  onDelete: () => _deleteChat(context, item),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: const Text('Chat History', style: AppTextStyles.screenTitle),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded,
              color: AppColors.textSecondary),
          onPressed: () => setState(() => _searchMode = true),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search problems, concepts…',
          hintStyle:
              AppTextStyles.body.copyWith(color: AppColors.textMuted),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _searchController.clear();
            setState(() {
              _searchMode = false;
              _searchQuery = '';
            });
          },
          child: Text('Cancel',
              style:
                  AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: _ChatFilter.values.map((f) {
          final isActive = _activeFilters.contains(f);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.label,
                  style: AppTextStyles.caption.copyWith(
                      color: isActive
                          ? AppColors.background
                          : AppColors.textSecondary)),
              selected: isActive,
              onSelected: (_) => _toggleFilter(f),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                  color:
                      isActive ? AppColors.primary : AppColors.border),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(bool noChatsAtAll) {
    if (noChatsAtAll) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text('No conversations yet.',
                  style: AppTextStyles.sectionHeader),
              const SizedBox(height: 8),
              Text(
                'Start chatting with the AI Tutor on any problem.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/discover'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                ),
                child: const Text('Find a problem →'),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("No results for '$_searchQuery'",
                style: AppTextStyles.bodySecondary),
            const SizedBox(height: 8),
            const Text('Try a different keyword or concept name.',
                style: AppTextStyles.bodySecondary),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No conversations match these filters.',
              style: AppTextStyles.bodySecondary),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                setState(() => _activeFilters
                  ..clear()
                  ..add(_ChatFilter.all)),
            child: const Text('Clear filters',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ── Chat List Item ────────────────────────────────────────────────────────────

class _ChatListItem extends StatelessWidget {
  final _ChatItem item;
  final String searchQuery;
  final Color difficultyColor;
  final String relativeTime;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatListItem({
    required this.item,
    required this.searchQuery,
    required this.difficultyColor,
    required this.relativeTime,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.problemId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion ourselves with undo
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Difficulty dot
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: difficultyColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isSolved)
                          const Icon(Icons.check_circle_rounded,
                              size: 14, color: AppColors.primary),
                      ],
                    ),
                    if (item.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: item.tags.take(2).map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceRaised,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(t,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 10)),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      item.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(relativeTime,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded,
                    color: AppColors.textSecondary),
                title: const Text('Open AI Tutor',
                    style: AppTextStyles.bodySecondary),
                onTap: () {
                  Navigator.pop(context);
                  onTap();
                },
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined,
                    color: AppColors.textSecondary),
                title: const Text('View problem statement',
                    style: AppTextStyles.bodySecondary),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/problem/${item.problemId}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                title: Text('Delete chat history',
                    style: AppTextStyles.bodySecondary
                        .copyWith(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
