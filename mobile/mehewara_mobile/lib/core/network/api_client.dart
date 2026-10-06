import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class ApiException implements Exception {
  final int status;
  final String? code;
  final String message;

  int get statusCode => status;

  ApiException(this.status, this.code, this.message);

  ApiException.named({
    required this.message,
    this.code,
    required int statusCode,
  }) : status = statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;
  final String baseUrl;
  String? token;
  void Function()? onUnauthorized;

  ApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ApiConstants.baseUrl;

  http.Client get client => _client;

  Future<Map<String, String>> _buildHeaders({bool isJson = true, bool authenticated = true}) async {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }

    final storedToken = authenticated ? (token ?? await TokenStorage.getToken()) : null;
    if (authenticated && storedToken != null && storedToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $storedToken';
    }

    return headers;
  }

  dynamic _handleResponse(http.Response response, {bool authenticated = true}) {
    dynamic body;
    try {
      if (response.body.isNotEmpty) {
        body = jsonDecode(response.body);
      }
    } catch (_) {
      // Body is not json
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 401 && authenticated) {
      onUnauthorized?.call();
    }

    String message = 'Request failed with status: ${response.statusCode}';
    String? code;

    if (body is Map<String, dynamic>) {
      if (body.containsKey('error') && body['error'] is Map<String, dynamic>) {
        final err = body['error'] as Map<String, dynamic>;
        message = err['message'] ?? message;
        code = err['code'];
      } else if (body.containsKey('message')) {
        message = body['message'];
      }
    }

    throw ApiException.named(
      message: message,
      code: code,
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> send(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
    final headers = await _buildHeaders(isJson: body != null, authenticated: authenticated);
    http.Response response;
    try {
      response = await (method == 'POST'
              ? _client.post(
                  uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body),
                )
              : _client.get(uri, headers: headers))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(
        0,
        'TIMEOUT',
        'The request timed out. Refresh the job before trying again.',
      );
    } on http.ClientException {
      throw ApiException(
        0,
        'CONNECTION_FAILED',
        'Cannot connect. Check your connection and try again.',
      );
    }
    return (_handleResponse(response, authenticated: authenticated) as Map<String, dynamic>?) ?? {};
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$endpoint').replace(
      queryParameters: queryParams,
    );
    final headers = await _buildHeaders();
    final response = await _client.get(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$endpoint');
    final headers = await _buildHeaders();
    final response = await _client.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$endpoint');
    final headers = await _buildHeaders();
    final response = await _client.patch(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$endpoint');
    final headers = await _buildHeaders();
    final response = await _client.delete(uri, headers: headers);
    return _handleResponse(response);
  }
}

