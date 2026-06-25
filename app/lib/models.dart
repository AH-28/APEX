class Quest {
  final String id;
  final String date;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final int xpReward;
  final int estMinutes;
  final bool requiresPhoto;
  final String status;
  final String? completedAt;
  final String? photoPath;

  Quest({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.xpReward,
    required this.estMinutes,
    required this.requiresPhoto,
    required this.status,
    this.completedAt,
    this.photoPath,
  });

  /// Parses a `quests` table row (snake_case, as returned by Supabase).
  factory Quest.fromRow(Map<String, dynamic> r) => Quest(
        id: r['id'] as String,
        date: r['quest_date'] as String,
        title: r['title'] as String,
        description: r['description'] as String,
        category: r['category'] as String,
        difficulty: r['difficulty'] as String,
        xpReward: r['xp_reward'] as int,
        estMinutes: r['est_minutes'] as int,
        requiresPhoto: r['requires_photo'] as bool,
        status: r['status'] as String,
        completedAt: r['completed_at'] as String?,
        photoPath: r['photo_path'] as String?,
      );

  bool get isCompleted => status == 'completed';
}

class UserProfile {
  static const xpPerLevel = 500; // mirrors the complete_quest RPC

  final String email;
  final String? displayName;
  final int xp;
  final int level;
  final int coins;
  final List<String> interests;
  final String difficulty;
  final String? location;
  final String? ageRange;
  final Map<String, dynamic> avatar;
  final bool competeOptOut;
  final String themePreset;
  final String themeMode;

  UserProfile({
    required this.email,
    required this.displayName,
    required this.xp,
    required this.level,
    required this.coins,
    required this.interests,
    required this.difficulty,
    required this.location,
    required this.ageRange,
    required this.avatar,
    required this.competeOptOut,
    required this.themePreset,
    required this.themeMode,
  });

  /// Parses a `profiles` table row; email comes from the auth user.
  factory UserProfile.fromRow(Map<String, dynamic> r, {required String email}) =>
      UserProfile(
        email: email,
        displayName: r['display_name'] as String?,
        xp: r['xp'] as int,
        level: r['level'] as int,
        coins: r['coins'] as int? ?? 0,
        interests: (r['interests'] as List<dynamic>).cast<String>(),
        difficulty: r['difficulty'] as String,
        location: r['location'] as String?,
        ageRange: r['age_range'] as String?,
        avatar: (r['avatar'] as Map<String, dynamic>?) ?? {},
        competeOptOut: r['compete_opt_out'] as bool? ?? false,
        themePreset: r['theme_preset'] as String? ?? 'Nebula',
        themeMode: r['theme_mode'] as String? ?? 'dark',
      );

  double get levelProgress => (xp % xpPerLevel) / xpPerLevel;
}

class FriendEntry {
  FriendEntry({
    required this.friendshipId,
    required this.friendId,
    required this.displayName,
    required this.level,
    required this.xp,
    required this.avatar,
    required this.status,
    required this.incoming,
  });

  final String friendshipId;
  final String friendId;
  final String displayName;
  final int level;
  final int xp;
  final Map<String, dynamic> avatar;
  final String status; // pending | accepted
  final bool incoming;

  factory FriendEntry.fromRow(Map<String, dynamic> r) => FriendEntry(
        friendshipId: r['friendship_id'] as String,
        friendId: r['friend_id'] as String,
        displayName: r['display_name'] as String,
        level: r['level'] as int,
        xp: r['xp'] as int,
        avatar: (r['avatar'] as Map<String, dynamic>?) ?? {},
        status: r['status'] as String,
        incoming: r['incoming'] as bool,
      );

  bool get isFriend => status == 'accepted';
}

/// A 5-day shared habit challenge between two friends.
class DuoChallenge {
  DuoChallenge({
    required this.id,
    required this.status,
    required this.title,
    required this.description,
    required this.category,
    required this.days,
    required this.friendId,
    required this.friendName,
    required this.friendAvatar,
    required this.incoming,
    required this.myDays,
    required this.friendDays,
    required this.myCheckinDays,
    required this.friendCheckinDays,
    required this.checkedInToday,
    required this.dayInWindow,
    required this.windowEnded,
    this.startDate,
    this.myReward,
  });

  final String id;
  final String status; // pending | active | completed
  final String title;
  final String description;
  final String category;
  final int days;
  final String friendId;
  final String friendName;
  final Map<String, dynamic> friendAvatar;
  final bool incoming; // a pending request waiting for me to accept
  final int myDays;
  final int friendDays;
  final List<String> myCheckinDays; // ISO dates
  final List<String> friendCheckinDays;
  final bool checkedInToday;
  final int dayInWindow; // 1..days, or 0 if outside the window
  final bool windowEnded;
  final String? startDate;
  final int? myReward;

  factory DuoChallenge.fromRow(Map<String, dynamic> r) => DuoChallenge(
        id: r['id'] as String,
        status: r['status'] as String,
        title: r['title'] as String,
        description: r['description'] as String,
        category: r['category'] as String,
        days: r['days'] as int,
        friendId: r['friend_id'] as String,
        friendName: r['friend_name'] as String,
        friendAvatar: (r['friend_avatar'] as Map<String, dynamic>?) ?? {},
        incoming: r['incoming'] as bool,
        myDays: r['my_days'] as int,
        friendDays: r['friend_days'] as int,
        myCheckinDays:
            ((r['my_checkin_days'] as List<dynamic>?) ?? []).cast<String>(),
        friendCheckinDays:
            ((r['friend_checkin_days'] as List<dynamic>?) ?? []).cast<String>(),
        checkedInToday: r['checked_in_today'] as bool,
        dayInWindow: r['day_in_window'] as int,
        windowEnded: r['window_ended'] as bool,
        startDate: r['start_date'] as String?,
        myReward: r['my_reward'] as int?,
      );

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
}

class JournalStats {
  JournalStats({
    required this.soloCompleted,
    required this.thisWeek,
    required this.activeDays,
    required this.duoCompleted,
    required this.lockinMinutes,
    required this.lockinSessions,
    required this.lockinMinutesWeek,
    required this.byCategory,
    required this.weekActivity,
  });

  final int soloCompleted;
  final int thisWeek;
  final int activeDays;
  final int duoCompleted;
  final int lockinMinutes;
  final int lockinSessions;
  final int lockinMinutesWeek;
  final Map<String, int> byCategory;
  final List<int> weekActivity; // last 7 days, oldest → today

  factory JournalStats.fromJson(Map<String, dynamic> j) => JournalStats(
        soloCompleted: j['solo_completed'] as int? ?? 0,
        thisWeek: j['this_week'] as int? ?? 0,
        activeDays: j['active_days'] as int? ?? 0,
        duoCompleted: j['duo_completed'] as int? ?? 0,
        lockinMinutes: (j['lockin_minutes'] as num?)?.toInt() ?? 0,
        lockinSessions: (j['lockin_sessions'] as num?)?.toInt() ?? 0,
        lockinMinutesWeek: (j['lockin_minutes_week'] as num?)?.toInt() ?? 0,
        byCategory: ((j['by_category'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        weekActivity: ((j['week_activity'] as List<dynamic>?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      );

  /// "2h 35m" style formatting of total focus time.
  String get lockinTimeLabel {
    final h = lockinMinutes ~/ 60;
    final m = lockinMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class StudyItem {
  StudyItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.colorFee,
    required this.colors,
  });

  final String id;
  final String name;
  final String category;
  final int price;
  final int colorFee;
  final List<String> colors;

  factory StudyItem.fromRow(Map<String, dynamic> r) => StudyItem(
        id: r['id'] as String,
        name: r['name'] as String,
        category: r['category'] as String,
        price: r['price'] as int,
        colorFee: r['color_fee'] as int,
        colors: (r['colors'] as List<dynamic>).cast<String>(),
      );
}

class League {
  League({required this.id, required this.name, required this.code});

  final String id;
  final String name;
  final String code;

  factory League.fromRow(Map<String, dynamic> r) => League(
        id: r['id'] as String,
        name: r['name'] as String,
        code: r['code'] as String,
      );
}

class Standing {
  Standing({
    required this.userId,
    required this.displayName,
    required this.minutes,
    required this.rank,
  });

  final String userId;
  final String displayName;
  final int minutes;
  final int rank;

  factory Standing.fromRow(Map<String, dynamic> r) => Standing(
        userId: r['user_id'] as String,
        displayName: r['display_name'] as String,
        minutes: (r['minutes'] as num).toInt(),
        rank: (r['rank'] as num).toInt(),
      );
}

class OutfitInfo {
  OutfitInfo({required this.id, required this.name, required this.priceXp});

  final String id;
  final String name;
  final int priceXp;

  factory OutfitInfo.fromRow(Map<String, dynamic> r) => OutfitInfo(
        id: r['id'] as String,
        name: r['name'] as String,
        priceXp: r['price_xp'] as int,
      );

  bool get isFree => priceXp == 0;
}
