import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String code, message;
  ApiException(this.status, this.code, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  final http.Client client;
  final String baseUrl;
  String? token;
  void Function()? onUnauthorized;
  ApiClient({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:5194/api',
    ),
  }) : client = client ?? http.Client();

  Future<Map<String, dynamic>> send(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
    final headers = <String, String>{
      if (authenticated && token != null) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    http.Response response;
    try {
      response =
          await (method == 'POST'
                  ? client.post(
                      uri,
                      headers: headers,
                      body: body == null ? null : jsonEncode(body),
                    )
                  : client.get(uri, headers: headers))
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
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      /* Non-JSON error responses are handled below. */
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && authenticated) onUnauthorized?.call();
      final error = data['error'] as Map<String, dynamic>?;
      throw ApiException(
        response.statusCode,
        error?['code'] ?? 'REQUEST_FAILED',
        error?['message'] ?? 'Request failed (${response.statusCode}).',
      );
    }
    return data;
  }
}
