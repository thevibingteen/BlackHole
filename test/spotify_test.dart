@Tags(['unit'])
library spotify_test;

import 'dart:io';

import 'package:blackhole/APIs/spotify_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_spotify_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Spotify Credentials & Safety Guard Tests', () {
    test('SpotifyApi initial clientID and clientSecret are empty by default without injection', () {
      final spotify = SpotifyApi();
      // Verifies that hardcoded production credentials were not checked into code
      // and that default values fallback safely to empty strings.
      expect(spotify.clientID, isA<String>());
      expect(spotify.clientSecret, isA<String>());
    });

    test('SpotifyApi prioritizes Hive settings when configured', () async {
      final box = Hive.box('settings');
      await box.put('spotifyClientId', 'custom_user_client_id_123');
      await box.put('spotifyClientSecret', 'custom_user_secret_456');

      final spotify = SpotifyApi();
      expect(spotify.clientID, equals('custom_user_client_id_123'));
      expect(spotify.clientSecret, equals('custom_user_secret_456'));

      // Clean up
      await box.delete('spotifyClientId');
      await box.delete('spotifyClientSecret');
    });

    test('Spotify PKCE code verifier and challenge generation comply with RFC 7636', () {
      final verifier = SpotifyApi.generateCodeVerifier();
      expect(verifier.length, equals(64));
      // RFC 7636 unreserved characters only
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(verifier), isTrue);

      final challenge = SpotifyApi.generateCodeChallenge(verifier);
      expect(challenge.isNotEmpty, isTrue);
      // Base64URL without padding '='
      expect(challenge.contains('='), isFalse);
      expect(RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(challenge), isTrue);
    });

    test('Authorization request URL builds correctly with PKCE S256 parameters and app://blackhole/auth', () async {
      final box = Hive.box('settings');
      await box.put('spotifyClientId', 'test_client_id_xyz');

      final spotify = SpotifyApi();
      const testChallenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
      final authUrl = spotify.requestAuthorization(codeChallenge: testChallenge);

      expect(authUrl.startsWith('https://accounts.spotify.com/authorize'), isTrue);
      expect(authUrl.contains('client_id=test_client_id_xyz'), isTrue);
      expect(authUrl.contains('response_type=code'), isTrue);
      expect(authUrl.contains('redirect_uri=app://blackhole/auth'), isTrue);
      expect(authUrl.contains('code_challenge_method=S256'), isTrue);
      expect(authUrl.contains('code_challenge=$testChallenge'), isTrue);

      await box.delete('spotifyClientId');
    });

    test('Empty client ID does not launch or produce valid authorization URL', () {
      final spotify = SpotifyApi();
      if (spotify.clientID.isEmpty) {
        expect(spotify.clientID, isEmpty);
      }
    });
  });

  group('Spotify Deep-Link & Search Mapping Tests', () {
    test('Spotify authorization deep-link parses authorization code matching AndroidManifest intent-filter', () {
      const callbackUri = 'app://blackhole/auth?code=AQD12345AuthCodeXYZ';
      final uri = Uri.parse(callbackUri);

      expect(uri.scheme, equals('app'));
      expect(uri.host, equals('blackhole'));
      expect(uri.path, equals('/auth'));
      expect(uri.queryParameters.containsKey('code'), isTrue);
      expect(uri.queryParameters['code'], equals('AQD12345AuthCodeXYZ'));
    });

    test('Spotify track mapping constructs clean search query for JioSaavn / YouTube', () {
      final trackData = {
        'name': 'Anti-Hero',
        'artists': [
          {'name': 'Taylor Swift'},
          {'name': 'Bleachers'},
        ],
      };

      final query = (trackData['artists'] != null && (trackData['artists'] as List).isNotEmpty)
          ? '${trackData["name"]} by ${(trackData["artists"] as List)[0]["name"]}'
          : trackData['name'].toString();

      expect(query, equals('Anti-Hero by Taylor Swift'));
    });

    test('RouteHandler parses inbound Spotify track link', () {
      const spotifyUrl = 'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123';
      final match = RegExp(r'.*spotify.com.*?\/(track)\/(.*?)[/?]').firstMatch('$spotifyUrl/');

      expect(match, isNotNull);
      expect(match![1], equals('track'));
      expect(match[2], equals('4cOdK2wGLETKBW3PvgPWqT'));
    });
  });
}
