import 'dart:typed_data';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Ambil Base URL dari environment variables (.env)
  static String get baseUrl => dotenv.get('API_BASE_URL', fallback: 'http://127.0.0.1:5000/api/v1');

  factory DioClient() {
    return _instance;
  }

  DioClient._internal() {
    print("DIO_DEBUG: Initializing with BaseURL: $baseUrl");
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30), // Tingkatkan timeout
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) {
        return status! < 500; // Terima status < 500 agar bisa handle 401, 403, dll manual
      },
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Use refresh token for /auth/refresh, access token for others
        final String? token = options.path.contains('/auth/refresh')
            ? await _storage.read(key: 'refresh_token')
            : await _storage.read(key: 'access_token');

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        print("DIO_ERROR: ${e.type} - ${e.message}");
        if (e.response != null) {
          print("DIO_RESPONSE_DATA: ${e.response?.data}");
          print("DIO_RESPONSE_STATUS: ${e.response?.statusCode}");
        }
        if (e.response?.statusCode == 401 &&
            !e.requestOptions.path.contains('/auth/login') &&
            !e.requestOptions.path.contains('/auth/refresh')) {
          // Attempt to refresh token
          try {
            final response = await refreshToken();
            if (response != null) {
              // Retry the original request
              final String newToken = response.data['access_token'];
              e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retryResponse = await _dio.fetch(e.requestOptions);
              return handler.resolve(retryResponse);
            }
          } catch (refreshError) {
            // Logout user or handle session expiration
          }
        }
        return handler.next(e);
      },
    ));
  }

  // --- AUTH API ---
  Future<Response> login(String username, String password) async {
    print("Attempting login to: ${baseUrl}/auth/login with $username");
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      print("Login response: ${response.statusCode} - ${response.data}");
      
      if (response.statusCode == 200) {
        await _storage.write(key: 'access_token', value: response.data['access_token']);
        await _storage.write(key: 'refresh_token', value: response.data['refresh_token']);
        await _storage.write(key: 'user_role', value: response.data['role']);
      }
      return response;
    } catch (e) {
      print("Login exception: $e");
      rethrow;
    }
  }

  Future<Response?> refreshToken() async {
    try {
      final response = await _dio.post('/auth/refresh');
      if (response.statusCode == 200) {
        await _storage.write(key: 'access_token', value: response.data['access_token']);
        return response;
      }
    } catch (e) {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
    }
    return null;
  }

  Future<Response> registerUser(String username, String password, String role) async {
    return await _dio.post('/auth/register', data: {
      'username': username,
      'password': password,
      'role': role,
    });
  }

  // --- ADMIN API ---
  Future<Response> getAllIdCards() async {
    return await _dio.get('/admin/id-cards');
  }

  /// Mendaftarkan data ID Card yang sudah ada ke database (Admin Only)
  Future<Response> adminRegisterId({
    required String fullname,
    required String nip,
    required String jobTitle,
    required String qrCode,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    FormData formData = FormData.fromMap({
      'fullname': fullname,
      'nip': nip,
      'job_title': jobTitle,
      'qr_code': qrCode,
      'id_card_photo': MultipartFile.fromBytes(
        imageBytes,
        filename: fileName,
      ),
    });

    return await _dio.post('/admin/register-id', data: formData);
  }

  // --- HISTORY API ---
  Future<Response> getHistoryLogs({int page = 1, int perPage = 10}) async {
    return await _dio.get('/history/logs', queryParameters: {
      'page': page,
      'per_page': perPage,
    });
  }

  // --- VERIFICATION API ---
  Future<Response> verifyScan(String qrCode, Uint8List imageBytes, String fileName) async {
    FormData formData = FormData.fromMap({
      'qr_code': qrCode,
      'scanned_image': MultipartFile.fromBytes(
        imageBytes,
        filename: fileName,
      ),
    });
    return await _dio.post('/verify/scan', data: formData);
  }
}
