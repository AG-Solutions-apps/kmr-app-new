/// Application API Constants & Base Config
class ApiConstants {
  ApiConstants._();

  /// Base API URL
  static const String baseUrl = 'https://kmrlive.in/crmapi/public/api/';

  /// Request Timeout Duration (in seconds)
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// Default Headers
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Helper to generate headers with Auth Bearer Token
  static Map<String, String> authHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };

  static const String appCategory = 'app-category';
  static const String appHomeSlider = 'app-home-slider';
  static const String appNotification = 'app-notification';
  static const String appCheckMobile = 'app-check-mobile';
  static const String appLogin = 'app-login';
  static const String login = 'login';
  static const String register = 'register';
  static const String signup = 'signup';
  static const String userProfile = 'profile';
  static const String appFetchProfile = 'app-fetch-profile';
  static const String appUpdateProfile = 'app-update-profile';
  static const String appDeleteProfile = 'app-delete-profile';
  static const String appLive = 'app-live';
  static const String appRate = 'app-rate';
  static const String appSpot = 'app-spot';
  static const String appNews = 'app-news';
  static const String appLogout = 'app-logout';
  static const String appCategorySlider = 'app-category-slider';

  /// Utility method to format full API endpoints safely
  static String getUrl(String endpoint) {
    if (endpoint.startsWith('/')) {
      return '$baseUrl${endpoint.substring(1)}';
    }
    return '$baseUrl$endpoint';
  }
}
