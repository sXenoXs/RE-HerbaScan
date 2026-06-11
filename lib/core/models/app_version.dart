/// AppVersion — data model for OTA update records from the `app_versions` table.
///
/// Used by [OtaAppUpdateService] to compare the latest available version
/// against the current installed build number and drive the update dialog.
class AppVersion {
  /// Human-readable version string, e.g. "1.0.28".
  final String versionName;

  /// Monotonically increasing integer build number, e.g. 26.
  /// Compared against [PackageInfo.buildNumber] to detect newer releases.
  final int versionCode;

  /// Target platform for this release, e.g. "android".
  final String platform;

  /// Publicly accessible download URL for the APK hosted on Supabase Storage.
  final String downloadUrl;

  /// Optional human-readable release notes shown in the update dialog.
  final String releaseNotes;

  /// When true, the update dialog cannot be dismissed — navigation is blocked
  /// until the user downloads and installs the update.
  final bool isMandatory;

  /// Whether this version record is active. Inactive records are skipped.
  final bool isActive;

  const AppVersion({
    required this.versionName,
    required this.versionCode,
    required this.platform,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isMandatory,
    required this.isActive,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      versionName:  json['version_name']  as String? ?? '',
      versionCode:  (json['version_code'] as num?)?.toInt() ?? 0,
      platform:     json['platform']      as String? ?? 'android',
      downloadUrl:  json['download_url']  as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      isMandatory:  json['is_mandatory']  as bool?   ?? false,
      isActive:     json['is_active']     as bool?   ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'version_name':  versionName,
    'version_code':  versionCode,
    'platform':      platform,
    'download_url':  downloadUrl,
    'release_notes': releaseNotes,
    'is_mandatory':  isMandatory,
    'is_active':     isActive,
  };
}
