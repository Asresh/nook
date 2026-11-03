import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _defaultApiKey = 'devkey';
const _defaultApiSecret = 'secret';
const _defaultPort = 8787;

Future<void> main() async {
  final apiKey = Platform.environment['LIVEKIT_API_KEY'] ?? _defaultApiKey;
  final apiSecret =
      Platform.environment['LIVEKIT_API_SECRET'] ?? _defaultApiSecret;
  final port =
      int.tryParse(Platform.environment['PORT'] ?? '') ?? _defaultPort;
  final livekitUrl =
      Platform.environment['LIVEKIT_URL'] ?? 'ws://127.0.0.1:7880';

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Nook dev token server listening on http://127.0.0.1:$port');
  stdout.writeln('LiveKit URL: $livekitUrl');
  stdout.writeln('Using API key: $apiKey');

  await for (final request in server) {
    await _handleRequest(request, apiKey, apiSecret, livekitUrl);
  }
}

Future<void> _handleRequest(
  HttpRequest request,
  String apiKey,
  String apiSecret,
  String livekitUrl,
) async {
  final response = request.response;
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization',
  );
  response.headers.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');

  if (request.method == 'OPTIONS') {
    response.statusCode = HttpStatus.noContent;
    await response.close();
    return;
  }

  if (request.method == 'GET' && request.uri.path == '/health') {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'ok': true}));
    await response.close();
    return;
  }

  if (request.method != 'POST' || request.uri.path != '/token') {
    response.statusCode = HttpStatus.notFound;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'error': 'Use POST /token'}));
    await response.close();
    return;
  }

  try {
    final body = jsonDecode(await utf8.decoder.bind(request).join());
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }

    final room = (body['room'] as String?)?.trim();
    final identity = (body['identity'] as String?)?.trim();
    final name = (body['name'] as String?)?.trim() ?? identity;

    if (room == null || room.isEmpty) {
      throw const FormatException('room is required.');
    }
    if (identity == null || identity.isEmpty) {
      throw const FormatException('identity is required.');
    }

    final token = _createToken(
      apiKey: apiKey,
      apiSecret: apiSecret,
      room: room,
      identity: identity,
      name: name ?? identity,
    );

    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'token': token, 'url': livekitUrl}));
  } catch (error) {
    response.statusCode = HttpStatus.badRequest;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'error': error.toString()}));
  }

  await response.close();
}

String _createToken({
  required String apiKey,
  required String apiSecret,
  required String room,
  required String identity,
  required String name,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = {'alg': 'HS256', 'typ': 'JWT'};
  final payload = {
    'iss': apiKey,
    'sub': identity,
    'name': name,
    'nbf': now - 10,
    'exp': now + 60 * 60 * 6,
    'video': {
      'room': room,
      'roomJoin': true,
      'canPublish': true,
      'canSubscribe': true,
      'canPublishData': true,
    },
  };

  final signingInput = '${_base64Json(header)}.${_base64Json(payload)}';
  final signature = Hmac(
    sha256,
    utf8.encode(apiSecret),
  ).convert(utf8.encode(signingInput));

  return '$signingInput.${_base64Url(signature.bytes)}';
}

String _base64Json(Map<String, Object?> value) {
  return _base64Url(utf8.encode(jsonEncode(value)));
}

String _base64Url(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}
