class Territory {
  final int userId;
  final String username;
  final Map<String, dynamic> geometry;
  final double areaM2;
  final String? updatedAt;

  const Territory({
    required this.userId,
    required this.username,
    required this.geometry,
    required this.areaM2,
    this.updatedAt,
  });

  factory Territory.fromJson(Map<String, dynamic> json) {
    return Territory(
      userId: json['userId'] as int,
      username: json['username'] as String,
      geometry: Map<String, dynamic>.from(json['geometry'] as Map),
      areaM2: (json['areaM2'] as num).toDouble(),
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final int userId;
  final String username;
  final double areaM2;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.areaM2,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int,
      userId: json['userId'] as int,
      username: json['username'] as String,
      areaM2: (json['areaM2'] as num).toDouble(),
    );
  }
}
