import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

typedef TodayQuests = ({List<Quest> quests, int rerollsLeft});

/// Data layer backed by Supabase.
///
/// Auth, database (with row-level security), photo storage, and the
/// `generate-quests` Edge Function all live in the `apex` Supabase project.
class ApiClient {
  SupabaseClient get _sb => Supabase.instance.client;

  bool get isAuthed => _sb.auth.currentSession != null;

  /// Fires whenever the user signs in or out.
  Stream<AuthState> get authChanges => _sb.auth.onAuthStateChange;

  /// Returns true when the account is ready to use, false when the project
  /// has email confirmation turned on and the user must confirm first.
  ///
  /// The optional preferences travel as auth metadata; a database trigger
  /// copies them into the new profile, so they apply even when the account
  /// still awaits email confirmation.
  Future<bool> signup(
    String email,
    String password, {
    String? displayName,
    List<String>? interests,
    String? ageRange,
    String? location,
    Map<String, dynamic>? avatar,
  }) async {
    final res = await _sb.auth.signUp(
      email: email,
      password: password,
      data: {
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
        if (interests != null && interests.isNotEmpty) 'interests': interests,
        'age_range': ?ageRange,
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        'avatar': ?avatar,
      },
    );
    return res.session != null;
  }

  Future<void> login(String email, String password) async {
    try {
      await _sb.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      // Supabase returns invalid_credentials for both wrong email and wrong
      // password — surface one friendly, non-revealing message.
      final code = e.code ?? '';
      if (code == 'invalid_credentials' ||
          e.message.toLowerCase().contains('invalid login')) {
        throw ApiException('Your email or password are incorrect.');
      }
      if (code == 'email_not_confirmed') {
        throw ApiException(
            'Please confirm your email first — check your inbox.');
      }
      throw ApiException(e.message);
    }
  }

  Future<void> logout() => _sb.auth.signOut();

  /// Starts an email change. Supabase sends confirmation links (by default
  /// to both the old and new address); the change applies once confirmed.
  Future<void> changeEmail(String newEmail) async {
    await _sb.auth.updateUser(UserAttributes(email: newEmail.trim()));
  }

  /// Changes the password immediately (requires the current session).
  Future<void> changePassword(String newPassword) async {
    await _sb.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Emails a 6-digit recovery code (the recovery email template must surface
  /// `{{ .Token }}`).
  Future<void> requestPasswordReset(String email) async {
    await _sb.auth.resetPasswordForEmail(email.trim());
  }

  /// Verifies the emailed recovery code. On success a recovery session is
  /// created, after which [changePassword] can set the new password — all
  /// without leaving the app.
  Future<void> verifyRecoveryCode(String email, String code) async {
    try {
      await _sb.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim(),
        token: code.trim(),
      );
    } on AuthException catch (e) {
      final c = e.code ?? '';
      if (c == 'otp_expired' ||
          c == 'otp_disabled' ||
          e.message.toLowerCase().contains('expired') ||
          e.message.toLowerCase().contains('invalid')) {
        throw ApiException('That code is invalid or has expired.');
      }
      throw ApiException(e.message);
    }
  }

  Future<UserProfile> me() async {
    final row = await _sb.from('profiles').select().single();
    return UserProfile.fromRow(row, email: _sb.auth.currentUser?.email ?? '');
  }

  Future<void> updateProfile({
    List<String>? interests,
    String? difficulty,
    String? location,
    String? ageRange,
    String? timezone,
  }) async {
    await _sb.from('profiles').update({
      'interests': ?interests,
      'difficulty': ?difficulty,
      'location': ?location,
      'age_range': ?ageRange,
      'timezone': ?timezone,
    }).eq('id', _sb.auth.currentUser!.id);
  }

  /// Today's quests — the Edge Function generates them on the first call
  /// of the user's day and returns the same rows on every later call.
  Future<TodayQuests> todaysQuests() => _invokeGenerate({});

  /// Replaces today's unfinished quests with fresh ones (max 3 per day,
  /// enforced server-side). Completed quests are kept.
  Future<TodayQuests> rerollQuests() => _invokeGenerate({'action': 'reroll'});

  Future<TodayQuests> _invokeGenerate(Map<String, dynamic> body) async {
    final res = await _sb.functions.invoke('generate-quests', body: body);
    final data = res.data as Map<String, dynamic>;
    if (data['error'] != null) throw ApiException(data['error'].toString());
    return (
      quests: (data['quests'] as List<dynamic>)
          .map((q) => Quest.fromRow(q as Map<String, dynamic>))
          .toList(),
      rerollsLeft: data['rerolls_left'] as int? ?? 0,
    );
  }

  /// Completed solo quests within [since] .. [until] (duo challenges live in a
  /// separate table, so they're naturally excluded here).
  Future<List<Quest>> history({DateTime? since, DateTime? until}) async {
    var query =
        _sb.from('quests').select().eq('status', 'completed');
    if (since != null) {
      query = query.gte('completed_at', since.toUtc().toIso8601String());
    }
    if (until != null) {
      query = query.lt('completed_at', until.toUtc().toIso8601String());
    }
    final rows =
        await query.order('completed_at', ascending: false).limit(200);
    return rows.map(Quest.fromRow).toList();
  }

  /// Aggregate stats for the journal dashboard.
  Future<JournalStats> journalStats() async {
    final res = await _sb.rpc('journal_stats') as Map<String, dynamic>;
    return JournalStats.fromJson(res);
  }

  /// Completes a quest; [photoBytes] is the optional proof photo, stored in
  /// the private `proofs` bucket under the user's own folder.
  Future<({int xpAwarded, int totalXp, int level})> completeQuest(
    String questId, {
    List<int>? photoBytes,
  }) async {
    String? photoPath;
    if (photoBytes != null) {
      final uid = _sb.auth.currentUser!.id;
      photoPath = '$uid/$questId.jpg';
      await _sb.storage.from('proofs').uploadBinary(
            photoPath,
            Uint8List.fromList(photoBytes),
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
    }
    final res = await _sb.rpc('complete_quest', params: {
      'p_quest_id': questId,
      'p_photo_path': photoPath,
    }) as Map<String, dynamic>;
    return (
      xpAwarded: res['xp_awarded'] as int,
      totalXp: res['total_xp'] as int,
      level: res['level'] as int,
    );
  }

  Future<void> skipQuest(String questId) async {
    await _sb.rpc('skip_quest', params: {'p_quest_id': questId});
  }

  /// Brings a skipped quest back to the active list.
  Future<void> restoreQuest(String questId) async {
    await _sb.rpc('restore_quest', params: {'p_quest_id': questId});
  }

  /// Reverts a completed quest to active; the RPC claws back the XP.
  Future<({int xpRemoved, int totalXp, int level})> undoQuest(Quest quest) async {
    final res = await _sb.rpc('undo_quest', params: {'p_quest_id': quest.id})
        as Map<String, dynamic>;
    if (quest.photoPath != null) {
      // Best effort — the quest is already reverted either way.
      try {
        await _sb.storage.from('proofs').remove([quest.photoPath!]);
      } catch (_) {}
    }
    return (
      xpRemoved: res['xp_removed'] as int,
      totalXp: res['total_xp'] as int,
      level: res['level'] as int,
    );
  }

  /// Short-lived signed URL for a proof photo in the private bucket.
  Future<String> photoUrl(String photoPath) =>
      _sb.storage.from('proofs').createSignedUrl(photoPath, 3600);

  String get myId => _sb.auth.currentUser!.id;

  // ── Avatar & outfits ──────────────────────────────────────────
  Future<void> saveAvatar(Map<String, dynamic> avatar) async {
    await _sb.from('profiles').update({'avatar': avatar}).eq('id', myId);
  }

  Future<List<OutfitInfo>> outfits() async {
    final rows = await _sb.from('outfits').select().order('sort', ascending: true);
    return rows.map(OutfitInfo.fromRow).toList();
  }

  Future<Set<String>> ownedOutfits() async {
    final rows = await _sb.from('outfit_purchases').select('outfit_id');
    return rows.map((r) => r['outfit_id'] as String).toSet();
  }

  /// Buys an outfit with XP. Returns the remaining XP.
  Future<int> buyOutfit(String outfitId) async {
    final res = await _sb.rpc('buy_outfit', params: {'p_outfit_id': outfitId})
        as Map<String, dynamic>;
    return res['xp'] as int;
  }

  // ── Lock-in ───────────────────────────────────────────────────
  Future<({int coinsEarned, int totalCoins})> completeFocusSession(
      int focusMinutes, int breakMinutes) async {
    final res = await _sb.rpc('complete_focus_session', params: {
      'p_focus_minutes': focusMinutes,
      'p_break_minutes': breakMinutes,
    }) as Map<String, dynamic>;
    return (
      coinsEarned: res['coins_earned'] as int,
      totalCoins: res['total_coins'] as int,
    );
  }

  /// Total focus minutes this week (Monday-based, server time).
  Future<int> weeklyFocusMinutes() async {
    final monday = DateTime.now().toUtc().subtract(
        Duration(days: DateTime.now().toUtc().weekday - 1));
    final start = DateTime.utc(monday.year, monday.month, monday.day);
    final rows = await _sb
        .from('focus_sessions')
        .select('focus_minutes')
        .gte('completed_at', start.toIso8601String());
    return rows.fold<int>(0, (s, r) => s + (r['focus_minutes'] as int));
  }

  // ── Study space ───────────────────────────────────────────────
  Future<List<StudyItem>> studyItems() async {
    final rows = await _sb.from('study_items').select().order('sort', ascending: true);
    return rows.map(StudyItem.fromRow).toList();
  }

  Future<Map<String, String>> studySetup() async {
    final rows = await _sb.from('study_setup').select('item_id, color');
    return {for (final r in rows) r['item_id'] as String: r['color'] as String};
  }

  Future<int> buyStudyItem(String itemId, String color) async {
    final res = await _sb.rpc('buy_study_item',
        params: {'p_item_id': itemId, 'p_color': color}) as Map<String, dynamic>;
    return res['coins'] as int;
  }

  Future<int> recolorStudyItem(String itemId, String color) async {
    final res = await _sb.rpc('recolor_study_item',
        params: {'p_item_id': itemId, 'p_color': color}) as Map<String, dynamic>;
    return res['coins'] as int;
  }

  // ── Friends & duo quests ──────────────────────────────────────
  Future<List<FriendEntry>> friends() async {
    final rows = await _sb.rpc('get_friends') as List<dynamic>;
    return rows
        .map((r) => FriendEntry.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendFriendRequest(String email) async {
    await _sb.rpc('send_friend_request', params: {'p_email': email});
  }

  Future<void> respondFriendRequest(String friendshipId, bool accept) async {
    await _sb.rpc('respond_friend_request',
        params: {'p_id': friendshipId, 'p_accept': accept});
  }

  Future<void> removeFriend(String friendshipId) async {
    await _sb.rpc('remove_friend', params: {'p_id': friendshipId});
  }

  /// Settles any of my finished challenges (awards XP), then returns the
  /// current list of challenges for the Friends page.
  Future<List<DuoChallenge>> duoChallenges() async {
    try {
      await _sb.rpc('settle_my_duo_challenges');
    } catch (_) {/* best effort */}
    final rows = await _sb.rpc('get_duo_challenges') as List<dynamic>;
    return rows
        .map((r) => DuoChallenge.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDuoChallenge(String friendId) async {
    await _sb.rpc('create_duo_challenge', params: {'p_friend': friendId});
  }

  Future<void> respondDuoChallenge(String id, bool accept) async {
    await _sb.rpc('respond_duo_challenge',
        params: {'p_id': id, 'p_accept': accept});
  }

  Future<void> checkinDuoChallenge(String id) async {
    await _sb.rpc('checkin_duo_challenge', params: {'p_id': id});
  }

  // ── Leagues ───────────────────────────────────────────────────
  Future<List<League>> leagues() async {
    final rows = await _sb.from('leagues').select().order('created_at', ascending: true);
    return rows.map(League.fromRow).toList();
  }

  Future<League> createLeague(String name) async {
    final res = await _sb.rpc('create_league', params: {'p_name': name})
        as Map<String, dynamic>;
    return League.fromRow(res);
  }

  Future<void> joinLeague(String code) async {
    await _sb.rpc('join_league', params: {'p_code': code});
  }

  Future<void> leaveLeague(String leagueId) async {
    await _sb.rpc('leave_league', params: {'p_league': leagueId});
  }

  Future<List<Standing>> leagueStandings(String leagueId) async {
    final rows = await _sb.rpc('league_standings',
        params: {'p_league': leagueId}) as List<dynamic>;
    return rows.map((r) => Standing.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> setCompeteOptOut(bool optOut) async {
    await _sb.from('profiles').update({'compete_opt_out': optOut}).eq('id', myId);
  }

  /// Persists the user's chosen theme to their account.
  Future<void> saveTheme(String presetName, String mode) async {
    await _sb
        .from('profiles')
        .update({'theme_preset': presetName, 'theme_mode': mode})
        .eq('id', myId);
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
