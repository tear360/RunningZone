class AppConfig {
  // Change this to your deployed backend URL.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://run.chorizo.dpdns.org',
  );

  // GitHub repo used for auto-update checks (owner/repo).
  static const String githubRepo = String.fromEnvironment(
    'GITHUB_REPO',
    defaultValue: 'YOUR_GITHUB_USER/RunningZone',
  );

  static const String appName = 'RunningZone';

  // Metropolitan France + Corsica bounds.
  static const double franceMinLat = 41.0;
  static const double franceMaxLat = 51.5;
  static const double franceMinLng = -5.5;
  static const double franceMaxLng = 10.0;
  static const double franceCenterLat = 46.6;
  static const double franceCenterLng = 2.4;
}
