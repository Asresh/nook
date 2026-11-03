import 'dart:convert';

import 'package:http/http.dart' as http;

class VoiceCredentials {
  const VoiceCredentials({required this.token, required this.url});

  final String token;
  final String url;
}

class TokenService {
  const TokenService(this.endpoint);

  final String endpoint;

  Future<VoiceCredentials> fetch({
    required String room,
    required String identity,
    required String name,
    required String fallbackUrl,
  }) async {
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'room': room,
            'identity': identity,
            'name': name,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Token server returned ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Token server did not return a token.');
    }

    final url = (data['url'] as String?)?.trim();
    return VoiceCredentials(
      token: token,
      url: url == null || url.isEmpty ? fallbackUrl : url,
    );
  }
}
