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
    this.websiteUrl = '',
    this.facebookUrl = '',
    this.twitterUrl = '',
    this.linkedinUrl = '',
    this.instagramUrl = '',
    this.socialMedia = const [],
    this.googleClientId = '',
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
  // Admin-configured social handles (shown under Community). Empty = not set.
  final String websiteUrl;
  final String facebookUrl;
  final String twitterUrl;
  final String linkedinUrl;
  final String instagramUrl;
  // "Connect With Us" links from the web Community Hub (community_data.social_media).
  // Each: {name, url, icon (FontAwesome class), color}. The richest source.
  final List<SocialLink> socialMedia;
  // The school's OWN Google Web OAuth client id (BYOK). Empty → the app uses the
  // build's GOOGLE_SERVER_CLIENT_ID (the platform owner's client), so the
  // platform/MindSpan school works immediately with no admin config.
  final String googleClientId;

  bool feature(String key) => features[key] ?? false;

  /// True if the school has any "Connect With Us" links. Prefers the rich
  /// community_data list; falls back to the legacy individual URL fields.
  bool get hasSocialLinks =>
      socialMedia.isNotEmpty ||
      websiteUrl.isNotEmpty || facebookUrl.isNotEmpty || twitterUrl.isNotEmpty ||
      linkedinUrl.isNotEmpty || instagramUrl.isNotEmpty;

  /// The effective social links to render: the rich community_data list when
  /// present, else built from the legacy individual URL fields.
  List<SocialLink> get effectiveSocialLinks {
    if (socialMedia.isNotEmpty) return socialMedia;
    return [
      if (instagramUrl.isNotEmpty) SocialLink(name: 'Instagram', url: instagramUrl, icon: 'fab fa-instagram'),
      if (facebookUrl.isNotEmpty) SocialLink(name: 'Facebook', url: facebookUrl, icon: 'fab fa-facebook-f'),
      if (twitterUrl.isNotEmpty) SocialLink(name: 'X', url: twitterUrl, icon: 'fab fa-twitter'),
      if (linkedinUrl.isNotEmpty) SocialLink(name: 'LinkedIn', url: linkedinUrl, icon: 'fab fa-linkedin-in'),
      if (websiteUrl.isNotEmpty) SocialLink(name: 'Website', url: websiteUrl, icon: 'fas fa-globe'),
    ];
  }

  factory SchoolConfig.fromJson(Map<String, dynamic> j) {
    final rawFeatures = (j['features'] as Map?) ?? {};
    String s(String k) => (j[k] ?? '').toString();
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
      websiteUrl: s('website_url'),
      facebookUrl: s('fb_url'),
      twitterUrl: s('twitter_url'),
      linkedinUrl: s('linked_in_url'),
      instagramUrl: s('insta_url'),
      socialMedia: ((j['social_media'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SocialLink.fromJson(Map<String, dynamic>.from(e)))
          .where((l) => l.url.isNotEmpty)
          .toList(),
      googleClientId: s('google_oauth_client_id'),
    );
  }
}

/// One "Connect With Us" link (from community_data.social_media on the web).
class SocialLink {
  SocialLink({required this.name, required this.url, this.icon = '', this.color = ''});
  final String name;
  final String url;
  final String icon;  // FontAwesome class from the web, e.g. 'fab fa-youtube'
  final String color; // hex like '#FF0000'

  factory SocialLink.fromJson(Map<String, dynamic> j) => SocialLink(
        name: (j['name'] ?? '').toString(),
        url: (j['url'] ?? '').toString().trim(),
        icon: (j['icon'] ?? '').toString(),
        color: (j['color'] ?? '').toString(),
      );
}
