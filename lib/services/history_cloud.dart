import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'ai_quiz_service.dart';

/// The backend checks Firebase ownership; no database or media secrets in the app.
class HistoryCloud {
  HistoryCloud({required this.ownerId, required this.token});
  final String ownerId;
  final Future<String?> Function() token;

  factory HistoryCloud.forUser(User user) => HistoryCloud(
    ownerId: user.uid,
    token: () async {
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
        throw StateError('Account changed');
      }
      return user.getIdToken();
    },
  );

  Future<Map<String, dynamic>> call(Map<String, dynamic> body) async {
    final jwt = await token();
    if (jwt == null) throw StateError('Sign in first');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      const override = String.fromEnvironment('ELIOS_HISTORY_URL');
      final url = override.isEmpty
          ? Uri.parse(AiQuizService.workerUrl).replace(path: '/api/history')
          : Uri.parse(override);
      final request = await client
          .postUrl(url)
          .timeout(const Duration(seconds: 20));
      request.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.authorizationHeader, 'Bearer $jwt');
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        throw HttpException('History HTTP ${response.statusCode}');
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}
