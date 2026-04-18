import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../data/repositories/providers.dart';

// ── Badge count provider ──────────────────────────────────────────────────────

final unreadNotifCountProvider = StreamProvider<int>((ref) async* {
  final auth = await ref.watch(authStateProvider.future);
  if (auth == null) {
    yield 0;
    return;
  }
  yield* FirebaseFirestore.instance
      .collection('users')
      .doc(auth.uid)
      .collection('notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});

// ── Notification Bell Button ──────────────────────────────────────────────────

/// A bell icon button that shows an unread badge and opens the notification drawer.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadNotifCountProvider);
    final unread = unreadAsync.value ?? 0;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AppColors.textSecondary),
          onPressed: () => _openDrawer(context),
        ),
        if (unread > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NotificationDrawer(),
    );
  }
}

// ── Notification Drawer ───────────────────────────────────────────────────────

class _NotificationDrawer extends ConsumerWidget {
  const _NotificationDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final uid = authAsync.value?.uid;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text('Notifications',
                      style: AppTextStyles.sectionHeader
                          .copyWith(color: AppColors.textPrimary)),
                  const Spacer(),
                  if (uid != null)
                    TextButton(
                      onPressed: () => _markAllRead(uid),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero),
                      child: const Text('Mark all read',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontFamily: 'Inter')),
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Notification list
            Expanded(
              child: uid == null
                  ? const Center(
                      child: Text('Sign in to see notifications.',
                          style: AppTextStyles.bodySecondary))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('notifications')
                          .orderBy('createdAt', descending: true)
                          .limit(50)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary));
                        }

                        final docs = snap.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return _buildEmpty();
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: docs.length,
                          itemBuilder: (ctx, i) {
                            final d = docs[i].data()
                                as Map<String, dynamic>;
                            return _NotifItem(
                              docId: docs[i].id,
                              uid: uid,
                              data: d,
                              onTap: () {
                                Navigator.pop(context);
                                _handleTap(context, uid,
                                    docs[i].id, d);
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('No notifications yet.',
              style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }

  void _markAllRead(String uid) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get()
        .then((snap) {
      for (final doc in snap.docs) {
        doc.reference.update({'read': true});
      }
    });
  }

  void _handleTap(
      BuildContext context, String uid, String docId, Map<String, dynamic> d) {
    // Mark read
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(docId)
        .update({'read': true});

    // Navigate to deep link
    final deepLink = d['deepLink'] as String?;
    if (deepLink != null && deepLink.isNotEmpty) {
      context.push(deepLink);
    }
  }
}

// ── Notification Item ─────────────────────────────────────────────────────────

class _NotifItem extends StatelessWidget {
  final String docId;
  final String uid;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _NotifItem({
    required this.docId,
    required this.uid,
    required this.data,
    required this.onTap,
  });

  String _relativeTime(dynamic ts) {
    if (ts is! Timestamp) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(ts.toDate());
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'daily_problem':
        return Icons.psychology_outlined;
      case 'streak':
        return Icons.local_fire_department_outlined;
      case 'level_up':
        return Icons.emoji_events_outlined;
      case 'duel':
        return Icons.sports_kabaddi_rounded;
      case 'friend':
        return Icons.person_add_outlined;
      case 'recruiter':
        return Icons.work_outline_rounded;
      case 'sync':
        return Icons.sync_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final isRead = data['read'] as bool? ?? false;
    final type = data['type'] as String?;
    final ts = data['createdAt'];

    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForType(type),
                color: isRead ? AppColors.textMuted : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.label.copyWith(
                          color: isRead
                              ? AppColors.textSecondary
                              : AppColors.textPrimary)),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right side: time + unread dot
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_relativeTime(ts),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted)),
                if (!isRead)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
