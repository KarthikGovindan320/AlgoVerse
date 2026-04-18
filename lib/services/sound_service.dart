import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages all in-app sound effects.
///
/// Respects the system silent switch and the in-app sound toggle stored
/// in SharedPreferences under key 'sound_effects'.
///
/// Sound files must be placed in `assets/sounds/` and declared in pubspec.yaml.
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  final _player = AudioPlayer();
  bool _enabled = true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('sound_effects') ?? true;
    await _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_effects', value);
  }

  bool get isEnabled => _enabled;

  Future<void> _play(String asset) async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Silently fail if asset not found (placeholder during dev)
    }
  }

  // ── Sound triggers ─────────────────────────────────────────────────────────

  /// Played when a concept chip is tapped in onboarding or discover.
  Future<void> chipSelect() => _play('sounds/chip_select.mp3');

  /// Played when a problem is bookmarked.
  Future<void> bookmark() => _play('sounds/bookmark.mp3');

  /// Played when the user sends a chat message.
  Future<void> messageSend() => _play('sounds/message_send.mp3');

  /// Played when the AI starts responding (streaming begins).
  Future<void> aiTyping() => _play('sounds/ai_typing.mp3');

  /// Played when a problem is marked solved.
  Future<void> problemSolved() => _play('sounds/problem_solved.mp3');

  /// Played when a concept is marked as learnt (unlocks problems).
  Future<void> conceptLearnt() => _play('sounds/concept_learnt.mp3');

  /// Played on level up.
  Future<void> levelUp() => _play('sounds/level_up.mp3');

  /// Played when a streak milestone is reached (7, 14, 30 days, etc.).
  Future<void> streakMilestone() => _play('sounds/streak_milestone.mp3');

  /// Played when the daily problem card is tapped.
  Future<void> dailyProblemOpen() => _play('sounds/daily_open.mp3');

  /// Played when a duel challenge is received.
  Future<void> duelChallenge() => _play('sounds/duel_challenge.mp3');

  /// Played on duel completion (positive result).
  Future<void> duelComplete() => _play('sounds/duel_complete.mp3');
}
