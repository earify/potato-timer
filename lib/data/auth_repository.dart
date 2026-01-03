import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as official;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
    as all_platforms;
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class AuthRepository {
  FirebaseAuth get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      dev.log('FirebaseAuth instance access failed: $e');
      throw Exception(
        'Firebase is not initialized. Please run flutterfire configure.',
      );
    }
  }

  static const List<String> scopes = [
    'email',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  // TODO: Move these to environment variables or secure storage
  // For now, using placeholder values - configure properly before use
  static const String _webClientId = 'YOUR_GOOGLE_CLIENT_ID_HERE';

  static const String _webClientSecret = 'YOUR_GOOGLE_CLIENT_SECRET_HERE';

  final official.GoogleSignIn _googleSignIn = official.GoogleSignIn(
    scopes: scopes,
  );

  // Initialize for desktop/other platforms
  final all_platforms.GoogleSignIn
  _googleSignInAll = all_platforms.GoogleSignIn(
    params: all_platforms.GoogleSignInParams(
      clientId: _webClientId,
      clientSecret: _webClientSecret,
      scopes: scopes,
      // Redirect URI is required for some platforms, but for Windows local it's often handled.
    ),
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get _isWindows => !kIsWeb && Platform.isWindows;

  Future<dynamic> get authenticatedUser async {
    if (_isWindows) {
      // For now, Windows doesn't support silent sign-in in this package.
      return null;
    }
    if (await _googleSignIn.isSignedIn()) {
      return _googleSignIn.currentUser;
    }
    return _googleSignIn.signInSilently();
  }

  Future<http.Client?> get authenticatedClient async {
    final user = await authenticatedUser;
    if (user == null) return null;

    Map<String, String> headers;
    if (_isWindows) {
      // In google_sign_in_all_platforms, the 'user' is all_platforms.GoogleSignInCredentials
      final creds = user as all_platforms.GoogleSignInCredentials;
      headers = {'Authorization': 'Bearer ${creds.accessToken}'};
    } else {
      headers = await (user as official.GoogleSignInAccount).authHeaders;
    }
    return GoogleAuthClient(headers);
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (_isWindows) {
        final all_platforms.GoogleSignInCredentials? creds =
            await _googleSignInAll.signIn();
        if (creds == null) return null;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: creds.accessToken,
          idToken: creds.idToken,
        );
        return await _auth.signInWithCredential(credential);
      } else {
        final official.GoogleSignInAccount? googleUser = await _googleSignIn
            .signIn();
        if (googleUser == null) return null;

        final official.GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      dev.log('Error signing in with Google: $e');
      if (e.toString().contains('Firebase')) {
        throw Exception(
          'Firebase initialization error. Please run "flutterfire configure" first.',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (_isWindows) {
        await _googleSignInAll.signOut();
      } else {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
      }
    } catch (_) {}
    await _auth.signOut();
  }
}
