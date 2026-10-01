import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

import '../models/category_model.dart';
import '../models/live_rate_model.dart';
import '../models/notification_model.dart';
import '../models/profile_model.dart';
import '../models/slider_model.dart';
import '../models/spot_rate_model.dart';
import '../models/news_model.dart';

/// Service class responsible for network calls using ApiConstants.baseUrl
class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch Categories from app-category endpoint (with optional Bearer token)
  Future<CategoryResponse> fetchCategories({String? token}) async {
    final jsonResponse = await get(ApiConstants.appCategory, token: token);
    if (jsonResponse is Map<String, dynamic>) {
      return CategoryResponse.fromJson(jsonResponse);
    } else if (jsonResponse is Map) {
      return CategoryResponse.fromJson(Map<String, dynamic>.from(jsonResponse));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response format received from categories endpoint',
    );
  }

  /// Fetch Home Sliders from app-home-slider endpoint (with optional Bearer token)
  Future<SliderResponse> fetchHomeSliders({String? token}) async {
    final jsonResponse = await get(ApiConstants.appHomeSlider, token: token);
    if (jsonResponse is Map<String, dynamic>) {
      return SliderResponse.fromJson(jsonResponse);
    } else if (jsonResponse is Map) {
      return SliderResponse.fromJson(Map<String, dynamic>.from(jsonResponse));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response format received from home-slider endpoint',
    );
  }

  /// Fetch Notifications from app-notification endpoint (with optional Bearer token)
  Future<NotificationResponse> fetchNotifications({String? token}) async {
    final jsonResponse = await get(ApiConstants.appNotification, token: token);
    if (jsonResponse is Map<String, dynamic>) {
      return NotificationResponse.fromJson(jsonResponse);
    } else if (jsonResponse is Map) {
      return NotificationResponse.fromJson(Map<String, dynamic>.from(jsonResponse));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response format received from notifications endpoint',
    );
  }

  /// Fetch Live Rates and Subcategories for a specific category ID
  Future<LiveRateResponse> fetchAppLive(int categoryId, {String? token}) async {
    final endpoint = '${ApiConstants.appLive}/$categoryId';
    final jsonResponse = await get(endpoint, token: token);
    if (jsonResponse is Map<String, dynamic>) {
      return LiveRateResponse.fromJson(jsonResponse);
    } else if (jsonResponse is Map) {
      return LiveRateResponse.fromJson(Map<String, dynamic>.from(jsonResponse));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response format received from live rates endpoint',
    );
  }

  /// Fetch Rates and Subcategories for a specific category ID
  Future<LiveRateResponse> fetchAppRate(int categoryId, {String? token}) async {
    final endpoint = '${ApiConstants.appRate}/$categoryId';
    final jsonResponse = await get(endpoint, token: token);
    if (jsonResponse is Map<String, dynamic>) {
      return LiveRateResponse.fromJson(jsonResponse);
    } else if (jsonResponse is Map) {
      return LiveRateResponse.fromJson(Map<String, dynamic>.from(jsonResponse));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response format received from rates endpoint',
    );
  }

  /// Fetch Spot Rates for a specific category ID
  Future<SpotRateResponse> fetchAppSpot(int categoryId, {String? token}) async {
    final endpoint = '${ApiConstants.appSpot}/$categoryId';
    final jsonResponse = await get(endpoint, token: token);
    if (jsonResponse is Map<String, dynamic>) {
      return SpotRateResponse.fromJson(jsonResponse);
    } else if (jsonResponse is Map) {
      return SpotRateResponse.fromJson(Map<String, dynamic>.from(jsonResponse));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response format received from spot rates endpoint',
    );
  }

  /// Fetch News for a specific category ID
  Future<NewsResponse> fetchAppNews(int categoryId, {String? token}) async {
    final endpoint = '${ApiConstants.appNews}/$categoryId';
    final jsonResponse = await get(endpoint, token: token);
    if (jsonResponse is Map<String, dynamic>) {
      return NewsResponse.fromJson(jsonResponse);
    } else if (jsonResponse is Map) {
      return NewsResponse.fromJson(Map<String, dynamic>.from(jsonResponse));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response format received from news endpoint',
    );
  }

  /// Fetch Sliders for a specific category ID
  Future<SliderResponse> fetchCategorySliders(int categoryId, {String? token}) async {
    final endpoint = '${ApiConstants.appCategorySlider}/$categoryId';
    final jsonResponse = await get(endpoint, token: token);
    if (jsonResponse is Map<String, dynamic>) {
      return SliderResponse.fromJson(jsonResponse);
    } else if (jsonResponse is Map) {
      return SliderResponse.fromJson(Map<String, dynamic>.from(jsonResponse));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response format received from category sliders endpoint',
    );
  }

  /// Perform User Logout via app-logout API endpoint
  Future<dynamic> logoutUser({String? token}) async {
    return await post(ApiConstants.appLogout, token: token);
  }

  /// Fetch user profile from app-fetch-profile endpoint
  Future<ProfileResponse> fetchProfile({required String token}) async {
    final jsonResponse = await get(ApiConstants.appFetchProfile, token: token);
    if (jsonResponse is Map<String, dynamic>) {
      return ProfileResponse.fromJson(jsonResponse);
    } else if (jsonResponse is Map) {
      return ProfileResponse.fromJson(Map<String, dynamic>.from(jsonResponse));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response format received from fetch profile endpoint',
    );
  }

  /// Update user profile using app-update-profile endpoint with formdata
  Future<dynamic> updateProfile({
    required String mobile,
    required String email,
    String? city,
    String? address,
    String? name,
    required String token,
  }) async {
    final fields = <String, String>{
      'mobile': mobile,
      'email': email,
      'city': city ?? '',
      'address': address ?? '',
    };
    if (name != null && name.trim().isNotEmpty) {
      fields['name'] = name.trim();
    }
    return await postFormData(ApiConstants.appUpdateProfile, fields: fields, token: token);
  }

  /// Perform User Signup using signup endpoint with formdata (name, mobile, email, city, address)
  Future<dynamic> signupUser({
    required String name,
    required String mobile,
    required String email,
    required String city,
    String? address,
  }) async {
    final fields = <String, String>{
      'name': name.trim(),
      'mobile': mobile.trim(),
      'email': email.trim(),
      'city': city.trim(),
      'address': (address ?? '').trim(),
    };
    return await postFormData(ApiConstants.signup, fields: fields);
  }

  /// Delete user profile using app-delete-profile endpoint
  Future<dynamic> deleteProfile({required String token}) async {
    return await post(ApiConstants.appDeleteProfile, token: token);
  }

  /// Perform a GET request
  /// NOTE: GET requests must NOT send Content-Type header — servers return 406 Not Acceptable.
  /// Only POST/PUT/PATCH requests need Content-Type: application/json.
  Future<dynamic> get(String endpoint, {String? token}) async {
    final uri = Uri.parse(ApiConstants.getUrl(endpoint));
    // GET requests: only Accept header (no Content-Type)
    final Map<String, String> headers = token != null
        ? {'Accept': 'application/json', 'Authorization': 'Bearer $token'}
        : {'Accept': 'application/json'};

    try {
      developer.log('GET request to: $uri', name: 'ApiService');
      final response = await _client
          .get(uri, headers: headers)
          .timeout(ApiConstants.timeoutDuration);
      return _processResponse(response);
    } catch (e) {
      developer.log('GET error: $e', name: 'ApiService', error: e);
      rethrow;
    }
  }

  /// Perform a POST request
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? data, String? token}) async {
    final uri = Uri.parse(ApiConstants.getUrl(endpoint));
    final headers = token != null
        ? ApiConstants.authHeaders(token)
        : ApiConstants.defaultHeaders;

    try {
      developer.log('POST request to: $uri with body: $data', name: 'ApiService');
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(ApiConstants.timeoutDuration);
      return _processResponse(response);
    } catch (e) {
      developer.log('POST error: $e', name: 'ApiService', error: e);
      rethrow;
    }
  }

  /// Perform a POST request sending formdata (multipart/form-data)
  Future<dynamic> postFormData(String endpoint, {required Map<String, String> fields, String? token}) async {
    final uri = Uri.parse(ApiConstants.getUrl(endpoint));
    final request = http.MultipartRequest('POST', uri);
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(fields);

    try {
      developer.log('POST Form-Data to: $uri with fields: $fields', name: 'ApiService');
      final streamedResponse = await request.send().timeout(ApiConstants.timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } catch (e) {
      developer.log('POST Form-Data error: $e', name: 'ApiService', error: e);
      rethrow;
    }
  }

  /// Process HTTP Response and throw exceptions on status errors
  dynamic _processResponse(http.Response response) {
    developer.log('Response Status: ${response.statusCode}', name: 'ApiService');
    
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: body is Map && body.containsKey('message')
            ? body['message']
            : 'Request failed with status: ${response.statusCode}',
        data: body,
      );
    }
  }
}

/// Custom Exception for API Errors
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  ApiException({
    required this.statusCode,
    required this.message,
    this.data,
  });

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}
