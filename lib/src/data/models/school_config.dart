/// Mirrors GET /api/v1/school/config/ — the server-driven branding + feature
/// flags. Changing a school in the backend DB re-themes the app with NO rebuild.
class SchoolConfig {
  SchoolConfig({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.primaryColorDark,
    this.logo = '',
    this.favicon = '',
    this.mascot = '',
    this.missionStatement = '',
    this.isPlatform = false,
    this.features = const {},
  });

  final int id;
  final String name;
  final String primaryColor; // #RRGGBB
  final String primaryColorDark;
  final String logo;
  final String favicon;
  final String mascot;
  final String missionStatement;
  final bool isPlatform;
  final Map<String, bool> features;

  bool feature(String key) => features[key] ?? false;

  factory SchoolConfig.fromJson(Map<String, dynamic> j) {
    final rawFeatures = (j['features'] as Map?) ?? {};
    return SchoolConfig(
      id: j['id'] as int,
      name: (j['name'] ?? '') as String,
      primaryColor: (j['primary_color'] ?? '#2563eb') as String,
      primaryColorDark: (j['primary_color_dark'] ?? '#1d4ed8') as String,
      logo: (j['logo'] ?? '') as String,
      favicon: (j['favicon'] ?? '') as String,
      mascot: (j['mascot'] ?? '') as String,
      missionStatement: (j['mission_statement'] ?? '') as String,
      isPlatform: (j['is_platform'] ?? false) as bool,
      features: rawFeatures.map((k, v) => MapEntry(k.toString(), v == true)),
    );
  }
}
