import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/difficulty_badge.dart';
import '../../data/models/problem_model.dart';
import '../../data/models/tag_model.dart';
import '../../data/repositories/providers.dart';
import '../../services/gemini_service.dart';

// ── Problem Detail Screen (shell) ─────────────────────────────────────────────

class ProblemDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  final int initialTab;

  const ProblemDetailScreen({
    super.key,
    required this.slug,
    this.initialTab = 0,
  });

  @override
  ConsumerState<ProblemDetailScreen> createState() =>
      _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends ConsumerState<ProblemDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  ProblemModel? _problem;
  List<TagModel> _tags = [];
  bool _loading = true;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadProblem();
  }

  Future<void> _loadProblem() async {
    final repo = ref.read(localRepositoryProvider);
    final problem = await repo.getProblemBySlug(widget.slug);
    final tags = problem != null ? await repo.getTagsForProblem(problem.id) : <TagModel>[];

    final bookmarkedIds =
        ref.read(bookmarksProvider).value ?? [];

    if (mounted) {
      setState(() {
        _problem = problem;
        _tags = tags;
        _loading = false;
        _isBookmarked = bookmarkedIds.contains(problem?.id);
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_problem == null) return;
    AppHaptics.light();
    setState(() => _isBookmarked = !_isBookmarked);
    try {
      final authAsync = ref.read(authStateProvider);
      final user = authAsync.value;
      if (user != null) {
        final fs = ref.read(firestoreServiceProvider);
        await fs.toggleBookmark(user.uid, _problem!.id, _isBookmarked);
      }
    } catch (_) {
      setState(() => _isBookmarked = !_isBookmarked);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _Header(
              problem: _problem,
              tags: _tags,
              loading: _loading,
              isBookmarked: _isBookmarked,
              onBack: () => context.pop(),
              onBookmark: _toggleBookmark,
            ),

            // Tab bar
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTextStyles.label
                    .copyWith(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Statement'),
                  Tab(text: 'AI Tutor'),
                  Tab(text: 'Notes'),
                ],
              ),
            ),

            // Tab views
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : _problem == null
                      ? _ProblemNotFound(slug: widget.slug)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            StatementTab(problem: _problem!, tags: _tags),
                            AiTutorTab(
                              problem: _problem!,
                              tags: _tags,
                            ),
                            NotesTab(problem: _problem!),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final ProblemModel? problem;
  final List<TagModel> tags;
  final bool loading;
  final bool isBookmarked;
  final VoidCallback onBack;
  final VoidCallback onBookmark;

  const _Header({
    required this.problem,
    required this.tags,
    required this.loading,
    required this.isBookmarked,
    required this.onBack,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title + bookmark
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary, size: 20),
                onPressed: onBack,
                padding: const EdgeInsets.all(8),
              ),
              Expanded(
                child: loading
                    ? const SizedBox.shrink()
                    : Text(
                        problem != null
                            ? '#${problem!.id} · ${problem!.title}'
                            : '',
                        style: AppTextStyles.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
              ),
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked ? AppColors.amber : AppColors.textMuted,
                  size: 20,
                ),
                onPressed: onBookmark,
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),

          // Tag row
          if (!loading && problem != null && tags.isNotEmpty)
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  DifficultyBadge.fromString(problem!.difficulty),
                  const SizedBox(width: 6),
                  ...tags.take(6).map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _TagChip(name: tag.name),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String name;
  const _TagChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        name,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ProblemNotFound extends StatelessWidget {
  final String slug;
  const _ProblemNotFound({required this.slug});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('Problem "$slug" not found.', style: AppTextStyles.cardTitle),
          const SizedBox(height: 8),
          Text('The database may not be populated yet.',
              style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — STATEMENT
// ─────────────────────────────────────────────────────────────────────────────

class StatementTab extends StatelessWidget {
  final ProblemModel problem;
  final List<TagModel> tags;

  const StatementTab({super.key, required this.problem, required this.tags});

  @override
  Widget build(BuildContext context) {
    final statement = problem.statement;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statement != null && statement.isNotEmpty)
                  MarkdownBody(
                    data: statement,
                    styleSheet: _markdownStyle(),
                    selectable: true,
                  )
                else
                  Text(
                    'Statement not available.',
                    style: AppTextStyles.bodySecondary,
                  ),

                // Hints section
                if (problem.hints.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _HintsSection(hints: problem.hints),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Sticky footer
        _StatementFooter(problem: problem),
      ],
    );
  }

  MarkdownStyleSheet _markdownStyle() {
    return MarkdownStyleSheet(
      p: AppTextStyles.body.copyWith(color: AppColors.textPrimary, height: 1.6),
      h1: AppTextStyles.screenTitle,
      h2: AppTextStyles.sectionHeader,
      h3: AppTextStyles.cardTitle,
      code: AppTextStyles.codeInline.copyWith(
        backgroundColor: AppColors.surfaceRaised,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      blockquoteDecoration: BoxDecoration(
        border: const Border(
            left: BorderSide(color: AppColors.primary, width: 3)),
        color: AppColors.primaryMuted,
      ),
      listBullet: AppTextStyles.body.copyWith(color: AppColors.primary),
      strong: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      em: AppTextStyles.body.copyWith(
          fontStyle: FontStyle.italic, color: AppColors.textSecondary),
    );
  }
}

class _HintsSection extends StatefulWidget {
  final List<String> hints;
  const _HintsSection({required this.hints});

  @override
  State<_HintsSection> createState() => _HintsSectionState();
}

class _HintsSectionState extends State<_HintsSection> {
  int _revealed = 0;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              const Text('💡 ', style: TextStyle(fontSize: 16)),
              Text(
                'Hints available (${widget.hints.length})',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.amber),
              ),
              const Spacer(),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          ...List.generate(_revealed, (i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amberMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Hint ${i + 1}: ${widget.hints[i]}',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textPrimary),
              ),
            );
          }),
          if (_revealed < widget.hints.length)
            TextButton(
              onPressed: () => setState(() => _revealed++),
              child: Text(
                _revealed == 0 ? 'Reveal hint 1' : 'Reveal next hint',
                style: AppTextStyles.body.copyWith(color: AppColors.amber),
              ),
            ),
        ],
      ],
    );
  }
}

class _StatementFooter extends StatelessWidget {
  final ProblemModel problem;
  const _StatementFooter({required this.problem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _openOnLeetCode(context, problem.leetcodeUrl),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Open on LeetCode'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showAttemptSheet(context, problem),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Attempt →'),
            ),
          ),
        ],
      ),
    );
  }

  void _openOnLeetCode(BuildContext context, String url) {
    // In a real app, launch url_launcher or webview
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: $url',
            style: AppTextStyles.body.copyWith(color: AppColors.background)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAttemptSheet(BuildContext context, ProblemModel problem) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AttemptSheet(problem: problem),
    );
  }
}

class _AttemptSheet extends StatelessWidget {
  final ProblemModel problem;
  const _AttemptSheet({required this.problem});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opening LeetCode. Good luck.',
                style: AppTextStyles.sectionHeader),
            const SizedBox(height: 8),
            Text('Your chat here will be saved.',
                style: AppTextStyles.bodySecondary),
            Text('Come back to share what you learned.',
                style: AppTextStyles.bodySecondary),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: launch LeetCode URL in webview
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Let's go →"),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Not yet',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — AI TUTOR
// ─────────────────────────────────────────────────────────────────────────────

class AiTutorTab extends ConsumerStatefulWidget {
  final ProblemModel problem;
  final List<TagModel> tags;

  const AiTutorTab({super.key, required this.problem, required this.tags});

  @override
  ConsumerState<AiTutorTab> createState() => _AiTutorTabState();
}

class _AiTutorTabState extends ConsumerState<AiTutorTab> {
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _gemini = GeminiService();

  bool _aiThinking = false;
  int _hintsUsed = 0;
  static const int _totalHints = 3;

  @override
  void initState() {
    super.initState();
    _initGemini();
  }

  void _initGemini() {
    _gemini.initialize(
      problemTitle: widget.problem.title,
      problemStatement: widget.problem.statement,
      conceptTags: widget.tags.map((t) => t.name).toList(),
      learntConcepts: [],
      history: _messages,
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _gemini.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text,
      {MessageType type = MessageType.standard}) async {
    if (text.trim().isEmpty || _aiThinking) return;

    final userMsg = ChatMessage(
      role: ChatRole.user,
      text: text.trim(),
      type: MessageType.standard,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMsg);
      _aiThinking = true;
      _inputController.clear();
    });
    _scrollToBottom();

    // Persist user message to Firestore
    await _persistMessage(userMsg);

    // Start streaming AI response
    final aiMsg = ChatMessage(
      role: ChatRole.model,
      text: '',
      type: type,
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(aiMsg));

    final stream = switch (type) {
      MessageType.hint => _gemini.requestHint(_hintsUsed + 1),
      MessageType.eli5 => _gemini.requestEli5(),
      MessageType.evaluate => _gemini.evaluateApproach(text),
      _ => _gemini.sendMessage(text),
    };

    String accumulated = '';
    await for (final chunk in stream) {
      accumulated += chunk;
      setState(() {
        _messages[_messages.length - 1] =
            _messages.last.copyWith(text: accumulated);
      });
      _scrollToBottom();
    }

    if (type == MessageType.hint) _hintsUsed++;

    await _persistMessage(_messages.last);
    if (mounted) setState(() => _aiThinking = false);
  }

  Future<void> _persistMessage(ChatMessage msg) async {
    try {
      final authAsync = ref.read(authStateProvider);
      final user = authAsync.value;
      if (user == null) return;
      final fs = ref.read(firestoreServiceProvider);
      await fs.sendMessage(user.uid, widget.problem.id.toString(), {
        'role': msg.role == ChatRole.user ? 'user' : 'model',
        'text': msg.text,
        'type': msg.type.name,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasMessages = _messages.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _WelcomeCard(
                  onQuickStart: (text) => _sendMessage(text),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    return _ChatBubble(message: _messages[i]);
                  },
                ),
        ),

        // Action buttons + input
        _TutorInputArea(
          controller: _inputController,
          thinking: _aiThinking,
          hasMessages: hasMessages,
          hintsRemaining: _totalHints - _hintsUsed,
          onSend: (text) => _sendMessage(text),
          onHint: () => _sendMessage('Give me a hint.', type: MessageType.hint),
          onEli5: () => _sendMessage('Explain this simply.', type: MessageType.eli5),
          onEvaluate: hasMessages
              ? () {
                  final last = _messages.lastWhere(
                    (m) => m.role == ChatRole.user,
                    orElse: () => ChatMessage(
                      role: ChatRole.user,
                      text: 'my current approach',
                      timestamp: DateTime.now(),
                    ),
                  );
                  _sendMessage(last.text, type: MessageType.evaluate);
                }
              : null,
        ),

        // Attempt button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showAttemptSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Attempt →'),
            ),
          ),
        ),
      ],
    );
  }

  void _showAttemptSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AttemptSheet(problem: widget.problem),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final ValueChanged<String> onQuickStart;
  const _WelcomeCard({required this.onQuickStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text('✦', style: TextStyle(fontSize: 24, color: AppColors.primary)),
                const SizedBox(height: 12),
                Text(
                  'Before you attempt this problem,\ntalk through it here.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Describe what you see. What does this problem remind you of? What\'s your first instinct?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _QuickStartChip(
                text: 'I have no idea where to start',
                onTap: onQuickStart,
              ),
              _QuickStartChip(
                text: 'I think I see the approach',
                onTap: onQuickStart,
              ),
              _QuickStartChip(
                text: 'Explain the core concept first',
                onTap: onQuickStart,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStartChip extends StatelessWidget {
  final String text;
  final ValueChanged<String> onTap;
  const _QuickStartChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(text,
            style: AppTextStyles.label
                .copyWith(color: AppColors.primary)),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(message.text,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textMuted)),
        ),
      );
    }

    Color bubbleBg = isUser ? AppColors.surfaceRaised : AppColors.surface;
    if (message.type == MessageType.hint) {
      bubbleBg = AppColors.amberMuted;
    } else if (message.type == MessageType.eli5) {
      bubbleBg = const Color(0xFF1E2530);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Type label for special AI messages
          if (!isUser && message.type != MessageType.standard) ...[
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 2),
              child: Text(
                _typeLabel(message.type),
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],

          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryMuted,
                  ),
                  child: const Text('✦',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.primary)),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: MarkdownBody(
                    data: message.text.isEmpty ? '...' : message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary, height: 1.5),
                      code: AppTextStyles.codeInline.copyWith(
                          backgroundColor: AppColors.surfaceRaised),
                      strong: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(MessageType type) => switch (type) {
        MessageType.socratic => '🤔 Guiding question',
        MessageType.hint => 'Hint',
        MessageType.eli5 => 'Simple Explanation',
        MessageType.evaluate => '📋 Approach Review',
        MessageType.codeReview => '💻 Code Review',
        _ => '',
      };
}

class _TutorInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool thinking;
  final bool hasMessages;
  final int hintsRemaining;
  final ValueChanged<String> onSend;
  final VoidCallback onHint;
  final VoidCallback onEli5;
  final VoidCallback? onEvaluate;

  const _TutorInputArea({
    required this.controller,
    required this.thinking,
    required this.hasMessages,
    required this.hintsRemaining,
    required this.onSend,
    required this.onHint,
    required this.onEli5,
    required this.onEvaluate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: AppColors.surface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick action buttons
          Row(
            children: [
              _ActionButton(
                icon: Icons.lightbulb_outline,
                label: 'Hint ($hintsRemaining)',
                onTap: hintsRemaining > 0 && !thinking ? onHint : null,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.child_care,
                label: 'ELI5',
                onTap: !thinking ? onEli5 : null,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.rate_review_outlined,
                label: 'Evaluate',
                onTap: hasMessages && !thinking ? onEvaluate : null,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Text input
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !thinking,
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Describe your understanding or approach...',
                    hintStyle: AppTextStyles.body
                        .copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: thinking
                    ? null
                    : () => onSend(controller.text),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: thinking
                        ? AppColors.textMuted
                        : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: thinking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.background),
                          ),
                        )
                      : const Icon(Icons.arrow_upward,
                          color: AppColors.background, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? AppColors.surfaceRaised : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: enabled ? AppColors.textSecondary : AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: enabled ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — NOTES
// ─────────────────────────────────────────────────────────────────────────────

class NotesTab extends StatefulWidget {
  final ProblemModel problem;
  const NotesTab({super.key, required this.problem});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final _notesController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeExpanded = false;
  String _savedIndicator = '';

  @override
  void initState() {
    super.initState();
    _notesController.addListener(_onNotesChanged);
  }

  void _onNotesChanged() {
    // Auto-save: brief flash of "Saved"
    setState(() => _savedIndicator = 'Saving...');
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _savedIndicator = 'Saved');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _savedIndicator = '');
      });
    });
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNotesChanged);
    _notesController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata strip
                _MetadataStrip(problem: widget.problem),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border),
                const SizedBox(height: 12),

                // Notes header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Notes', style: AppTextStyles.sectionHeader),
                    if (_savedIndicator.isNotEmpty)
                      Text(
                        _savedIndicator,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primary),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Notes text editor
                TextField(
                  controller: _notesController,
                  maxLines: null,
                  minLines: 8,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary, height: 1.6),
                  decoration: InputDecoration(
                    hintText: 'Write your approach notes, observations, key insights...\n\nMarkdown supported: **bold**, `code`, - bullet',
                    hintStyle: AppTextStyles.body
                        .copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // My Solution collapsible
                GestureDetector(
                  onTap: () =>
                      setState(() => _codeExpanded = !_codeExpanded),
                  child: Row(
                    children: [
                      Text('My Solution',
                          style: AppTextStyles.sectionHeader),
                      const Spacer(),
                      Icon(
                        _codeExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),

                if (_codeExpanded) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    maxLines: null,
                    minLines: 6,
                    style: AppTextStyles.code
                        .copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Paste your solution here after attempting...',
                      hintStyle: AppTextStyles.code
                          .copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceRaised,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _codeController.text.isEmpty
                          ? null
                          : () {
                              // TODO: switch to AI Tutor tab and send code review
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: const Text('Request Code Review →'),
                    ),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataStrip extends StatelessWidget {
  final ProblemModel problem;
  const _MetadataStrip({required this.problem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetaItem(icon: '📅', label: 'First opened', value: 'Today'),
          _MetaItem(
              icon: '✅',
              label: 'Solved',
              value: problem.insightSummary != null ? '—' : '—'),
          _MetaItem(icon: '💬', label: 'AI messages', value: '0'),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$icon $value',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}
