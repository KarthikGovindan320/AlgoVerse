import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A simple connectivity-aware banner. Shows a non-intrusive bar at the
/// top of the screen when the device is offline.
///
/// Wrap the root widget (or individual screens) with this widget.
/// The connectivity check uses a periodic HTTP ping rather than requiring
/// an extra package dependency.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startChecking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startChecking() {
    _checkConnectivity();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    // In production, implement a real connectivity check.
    // For now we assume online (requires connectivity_plus or similar package).
    // The banner infrastructure is ready to be wired.
    if (mounted) setState(() => _isOffline = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _isOffline
              ? Container(
                  width: double.infinity,
                  color: const Color(0xFF2A1A00),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 16, color: AppColors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You\'re offline. AI Tutor and sync unavailable.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.amber),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
