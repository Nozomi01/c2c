import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// マイページの表示モード: 購入者向け / 出品者向け。
enum ProfileMode {
  buyer,
  seller,
}

final profileModeProvider =
    NotifierProvider<ProfileModeNotifier, ProfileMode>(ProfileModeNotifier.new);

class ProfileModeNotifier extends Notifier<ProfileMode> {
  static const _prefsKey = 'profile_mode_v1';

  @override
  ProfileMode build() {
    // SharedPreferences must not run before the Android/iOS plugin channel is ready.
    // Future.microtask was too early → PlatformException(channel-error) on Pigeon.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _restoreFromPrefs();
    });
    return ProfileMode.buyer;
  }

  Future<void> _restoreFromPrefs() async {
    try {
      // One extra tick after first frame so the platform plugin can attach.
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_prefsKey);
      if (name == ProfileMode.seller.name) {
        state = ProfileMode.seller;
      }
    } catch (e, st) {
      debugPrint('profile_mode restore skipped: $e\n$st');
    }
  }

  Future<void> setMode(ProfileMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (e, st) {
      debugPrint('profile_mode persist failed: $e\n$st');
    }
  }
}
