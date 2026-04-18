import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/providers.dart';

// ── Job model ─────────────────────────────────────────────────────────────────

class _Job {
  final String id;
  final String company;
  final String role;
  final String location;
  final bool remoteOk;
  final List<String> requiredConcepts;
  final String salary;
  final String jobType;
  final DateTime postedAt;
  final String description;
  final String logoUrl;

  const _Job({
    required this.id,
    required this.company,
    required this.role,
    required this.location,
    required this.remoteOk,
    required this.requiredConcepts,
    required this.salary,
    required this.jobType,
    required this.postedAt,
    required this.description,
    required this.logoUrl,
  });

  factory _Job.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['postedAt'];
    return _Job(
      id: doc.id,
      company: d['company'] as String? ?? 'Company',
      role: d['role'] as String? ?? 'Software Engineer',
      location: d['location'] as String? ?? 'Remote',
      remoteOk: d['remoteOk'] as bool? ?? false,
      requiredConcepts:
          List<String>.from(d['requiredConcepts'] ?? []),
      salary: d['salary'] as String? ?? '',
      jobType: d['jobType'] as String? ?? 'Full-time',
      postedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      description: d['description'] as String? ?? '',
      logoUrl: d['logoUrl'] as String? ?? '',
    );
  }

  double matchPercent(Set<String> learntConcepts) {
    if (requiredConcepts.isEmpty) return 1.0;
    final matched =
        requiredConcepts.where((c) => learntConcepts.contains(c)).length;
    return matched / requiredConcepts.length;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class JobsScreen extends ConsumerStatefulWidget {
  final String? jobId;
  const JobsScreen({super.key, this.jobId});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  bool _showFilters = false;
  double _matchThreshold = 0.6;
  String _selectedJobType = 'All';

  @override
  Widget build(BuildContext context) {
    final learntConcepts = ref.watch(learntConceptsProvider).value ?? [];

    // Build a set of learnt concept names from tag IDs
    // (In full implementation this would join with the tag names from SQLite)
    final learntSet = Set<String>.from(
        learntConcepts.map((id) => 'concept_$id'));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jobs For You', style: AppTextStyles.screenTitle),
            const Text('Based on your skill profile',
                style: AppTextStyles.caption),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded,
                color: AppColors.textSecondary),
            onPressed: () =>
                setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters) _buildFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('active', isEqualTo: true)
                  .orderBy('postedAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                final jobs = docs.map(_Job.fromDoc).toList();

                // Find close matches (1–2 concepts away)
                final closeMatchJobs = jobs.where((j) {
                  final unmatched = j.requiredConcepts
                      .where((c) => !learntSet.contains(c))
                      .length;
                  return unmatched > 0 && unmatched <= 2;
                }).take(1).toList();

                final filteredJobs = jobs.where((j) {
                  final match = j.matchPercent(learntSet);
                  if (match < _matchThreshold) return false;
                  if (_selectedJobType != 'All' &&
                      j.jobType != _selectedJobType) {
                    return false;
                  }
                  return true;
                }).toList();

                filteredJobs.sort(
                    (a, b) => b.matchPercent(learntSet)
                        .compareTo(a.matchPercent(learntSet)));

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (closeMatchJobs.isNotEmpty)
                      _CloseMatchNudge(
                          job: closeMatchJobs.first,
                          learntSet: learntSet),
                    ...filteredJobs.map((job) => _JobCard(
                          job: job,
                          learntSet: learntSet,
                          isHighlighted: job.id == widget.jobId,
                          onTap: () => _showJobDetail(context, job, learntSet),
                        )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: ['All', 'Full-time', 'Internship', 'Remote']
                .map((t) {
              final isActive = _selectedJobType == t;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedJobType = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      t,
                      style: AppTextStyles.caption.copyWith(
                          color: isActive
                              ? AppColors.background
                              : AppColors.textSecondary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Min match: ${(_matchThreshold * 100).round()}%',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textMuted),
              ),
              Expanded(
                child: Slider(
                  value: _matchThreshold,
                  min: 0.3,
                  max: 1.0,
                  divisions: 7,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.surfaceRaised,
                  onChanged: (v) =>
                      setState(() => _matchThreshold = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.work_outline_rounded,
              size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('No jobs yet.', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 8),
          const Text(
            'Keep learning to improve your match score.\nRecruiters post new roles regularly.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/discover'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Improve skills →'),
          ),
        ],
      ),
    );
  }

  void _showJobDetail(
      BuildContext context, _Job job, Set<String> learntSet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _JobDetailScreen(job: job, learntSet: learntSet),
      ),
    );
  }
}

// ── Close Match Nudge ─────────────────────────────────────────────────────────

class _CloseMatchNudge extends StatelessWidget {
  final _Job job;
  final Set<String> learntSet;

  const _CloseMatchNudge({required this.job, required this.learntSet});

  @override
  Widget build(BuildContext context) {
    final missing = job.requiredConcepts
        .where((c) => !learntSet.contains(c))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎯 ', style: TextStyle(fontSize: 16)),
              Text("You're close!",
                  style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Learn ${missing.length} more concept${missing.length > 1 ? 's' : ''} to fully match ${job.company}:',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: missing.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.4)),
                ),
                child: Text(c,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.amber)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.go('/discover'),
            child: const Text('Learn these →',
                style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Job Card ──────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final _Job job;
  final Set<String> learntSet;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _JobCard({
    required this.job,
    required this.learntSet,
    required this.isHighlighted,
    required this.onTap,
  });

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d').format(dt);
  }

  Color _matchColor(double pct) {
    if (pct >= 0.8) return AppColors.primary;
    if (pct >= 0.5) return AppColors.amber;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final match = job.matchPercent(learntSet);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.company,
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.primary)),
                      Text(job.role,
                          style: AppTextStyles.sectionHeader
                              .copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 15)),
                      Text(
                        '${job.location}${job.remoteOk ? ' · Remote OK' : ''}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_outline_rounded,
                      color: AppColors.textMuted),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Concept chips
            if (job.requiredConcepts.isNotEmpty) ...[
              const Text('Required concepts:',
                  style: AppTextStyles.caption),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: job.requiredConcepts.take(6).map((c) {
                  final isLearnt = learntSet.contains(c);
                  return _ConceptMatchChip(
                      concept: c, isLearnt: isLearnt, hasProblems: isLearnt);
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Match bar
            Row(
              children: [
                Text(
                  'Match: ${job.requiredConcepts.where((c) => learntSet.contains(c)).length}/${job.requiredConcepts.length}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: match,
                      backgroundColor: AppColors.surfaceRaised,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _matchColor(match)),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(match * 100).round()}%',
                    style: AppTextStyles.caption
                        .copyWith(color: _matchColor(match))),
              ],
            ),
            const SizedBox(height: 8),

            // Footer
            Row(
              children: [
                if (job.salary.isNotEmpty) ...[
                  Text(job.salary,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                  Text(' · ',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted)),
                ],
                Text(job.jobType,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const Spacer(),
                Text(_relativeTime(job.postedAt),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptMatchChip extends StatelessWidget {
  final String concept;
  final bool isLearnt;
  final bool hasProblems;

  const _ConceptMatchChip({
    required this.concept,
    required this.isLearnt,
    required this.hasProblems,
  });

  @override
  Widget build(BuildContext context) {
    final suffix = isLearnt
        ? (hasProblems ? ' ✅' : ' ⚠️')
        : ' 🔒';
    final color = isLearnt
        ? (hasProblems ? AppColors.primary : AppColors.amber)
        : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$concept$suffix',
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}

// ── Job Detail Screen ─────────────────────────────────────────────────────────

class _JobDetailScreen extends StatelessWidget {
  final _Job job;
  final Set<String> learntSet;

  const _JobDetailScreen({required this.job, required this.learntSet});

  @override
  Widget build(BuildContext context) {
    final match = job.matchPercent(learntSet);
    final missing =
        job.requiredConcepts.where((c) => !learntSet.contains(c)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(job.company, style: AppTextStyles.screenTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.role,
                style: AppTextStyles.sectionHeader
                    .copyWith(color: AppColors.textPrimary, fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              '${job.location}${job.remoteOk ? ' · Remote OK' : ''}  ·  ${job.jobType}',
              style:
                  AppTextStyles.bodySecondary.copyWith(color: AppColors.textMuted),
            ),
            if (job.salary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(job.salary, style: AppTextStyles.bodySecondary),
            ],
            const SizedBox(height: 20),

            // Match summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${job.requiredConcepts.where((c) => learntSet.contains(c)).length} of ${job.requiredConcepts.length} required concepts matched',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: match,
                      backgroundColor: AppColors.surfaceRaised,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        match >= 0.8
                            ? AppColors.primary
                            : match >= 0.5
                                ? AppColors.amber
                                : AppColors.error,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: job.requiredConcepts.map((c) {
                      final isLearnt = learntSet.contains(c);
                      return _ConceptMatchChip(
                          concept: c,
                          isLearnt: isLearnt,
                          hasProblems: isLearnt);
                    }).toList(),
                  ),
                ],
              ),
            ),

            if (missing.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learn ${missing.join(', ')} to reach 100% match. Here\'s how →',
                      style: AppTextStyles.bodySecondary
                          .copyWith(color: AppColors.amber),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            if (job.description.isNotEmpty) ...[
              const Text('About this role',
                  style: AppTextStyles.sectionHeader),
              const SizedBox(height: 8),
              Text(job.description, style: AppTextStyles.bodySecondary),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () => _expressInterest(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Express Interest →',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  void _expressInterest(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExpressInterestSheet(job: job),
    );
  }
}

// ── Express Interest Sheet ────────────────────────────────────────────────────

class _ExpressInterestSheet extends StatefulWidget {
  final _Job job;
  const _ExpressInterestSheet({required this.job});

  @override
  State<_ExpressInterestSheet> createState() => _ExpressInterestSheetState();
}

class _ExpressInterestSheetState extends State<_ExpressInterestSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text:
          'Hi, I\'m interested in the ${widget.job.role} position at ${widget.job.company}. '
          'I\'ve been preparing with verified skill data — my profile is attached.',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),
          Text('Express Interest in ${widget.job.company}',
              style: AppTextStyles.sectionHeader
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 5,
            style: AppTextStyles.body
                .copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Your message…',
              hintStyle: AppTextStyles.caption,
              filled: true,
              fillColor: AppColors.surfaceRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Interest sent! Recruiter will be notified.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Send →'),
            ),
          ),
        ],
      ),
    );
  }
}
