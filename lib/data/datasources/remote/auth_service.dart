import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService shared = AuthService._();
  AuthService._();

  bool _isAuthenticated = false;
  String? _userId;
  String? _displayName;
  String? _givenName;
  String? _email;
  String? _photoURL;
  String? _surname;
  String? _phone;
  bool _isLoading = false;
  String? _error;
  // Guards against double-registration of the Firebase auth listener.
  bool _initCalled = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get displayName => _displayName;
  /// First name only — use for personalisation ("What is God working on in your life, Lance?").
  /// Apple provides this directly on first sign-in; Google derives it from displayName.
  String? get givenName => _givenName;
  String? get email => _email;
  String? get photoURL => _photoURL;
  String? get surname => _surname;
  String? get phone => _phone;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True when the device should use Apple Sign In (iOS), false for Google (Android).
  static bool get isApplePlatform => Platform.isIOS || Platform.isMacOS;

  Future<void> init() async {
    if (_initCalled) return;
    _initCalled = true;

    // Restore profile fields from local storage
    final prefs = await SharedPreferences.getInstance();
    _displayName = prefs.getString('tribute_display_name');
    _givenName = prefs.getString('tribute_given_name');
    _email = prefs.getString('tribute_email');
    _photoURL = prefs.getString('tribute_photo_url');
    _surname = prefs.getString('tribute_surname');
    _phone = prefs.getString('tribute_phone');

    // On reinstall the SharedPreferences cache is empty but FirebaseAuth
    // still has the session (stored in the platform keychain/keystore).
    // Fall back to the Firebase Auth profile so givenName is never null
    // after a reinstall — personalisation copy depends on it.
    final cached = FirebaseAuth.instance.currentUser;
    if (cached != null) {
      _displayName ??= cached.displayName;
      _email ??= cached.email;
      _photoURL ??= cached.photoURL;
      if (_displayName != null && _givenName == null) {
        _givenName = _displayName!.split(' ').first;
      }
    }

    // Listen for Firebase Auth state changes and keep APIService token in sync
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        _userId = user.uid;
        _isAuthenticated = true;
        final token = await user.getIdToken();
        APIService.shared.setFirebaseToken(token, userId: user.uid);
      } else {
        _userId = null;
        _isAuthenticated = false;
        APIService.shared.setFirebaseToken(null);
      }
      notifyListeners();
    });

    // Set initial state synchronously from current user
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      _userId = current.uid;
      _isAuthenticated = true;
      final token = await current.getIdToken();
      APIService.shared.setFirebaseToken(token, userId: current.uid);
      notifyListeners();
    }
  }

  // ── Platform-aware sign-in entry point ───────────────────────────────────

  /// Signs in using Apple on iOS/macOS and Google on Android.
  Future<void> signIn() async {
    if (isApplePlatform) {
      await signInWithApple();
    } else {
      await signInWithGoogle();
    }
  }

  // ── Apple Sign In ─────────────────────────────────────────────────────────

  Future<void> signInWithApple() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256OfString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) {
        throw StateError('Apple sign-in did not return an identity token');
      }

      final oAuthCredential = AppleAuthProvider.credentialWithIDToken(
        identityToken,
        rawNonce,
        AppleFullPersonName(
          givenName: credential.givenName,
          familyName: credential.familyName,
        ),
      );

      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithCredential(oAuthCredential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential' && e.email != null) {
          await _linkViaGoogle(
            pendingAppleCredential: oAuthCredential,
            conflictEmail: e.email!,
          );
          _isLoading = false;
          notifyListeners();
          return;
        }
        rethrow;
      }

      final user = userCredential.user;
      if (user == null) throw StateError('Apple sign-in completed but Firebase returned a null user');

      // Apple only provides name on the very first sign-in
      String? displayName;
      if (credential.givenName != null) {
        displayName = [credential.givenName, credential.familyName]
            .whereType<String>()
            .join(' ')
            .trim();
        if (displayName.isEmpty) displayName = null;
      }

      final givenName = (credential.givenName?.isNotEmpty ?? false)
          ? credential.givenName
          : null;

      final email = _isPrivateRelayEmail(credential.email) ? null : credential.email;
      final photoURL = user.photoURL;

      await _finalizeSignIn(
        user,
        displayName: displayName,
        givenName: givenName,
        email: email,
        photoURL: photoURL,
        providers: ['apple.com'],
      );
    } on FirebaseAuthException catch (e) {
      _error = _friendlyAuthError(e);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Google Sign In ────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the sign-in flow — not an error.
        _isLoading = false;
        notifyListeners();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final oAuthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithCredential(oAuthCredential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential' && e.email != null) {
          await _linkViaApple(
            pendingGoogleCredential: oAuthCredential,
            conflictEmail: e.email!,
          );
          _isLoading = false;
          notifyListeners();
          return;
        }
        rethrow;
      }

      final user = userCredential.user;
      if (user == null) throw StateError('Google sign-in completed but Firebase returned a null user');

      final displayName = googleUser.displayName;
      final givenName = displayName?.split(' ').firstOrNull;
      final email = _isPrivateRelayEmail(googleUser.email) ? null : googleUser.email;
      final photoURL = googleUser.photoUrl;

      await _finalizeSignIn(
        user,
        displayName: displayName,
        givenName: givenName?.isNotEmpty == true ? givenName : null,
        email: email?.isNotEmpty == true ? email : null,
        photoURL: photoURL,
        providers: ['google.com'],
      );
    } on FirebaseAuthException catch (e) {
      _error = _friendlyAuthError(e);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!isApplePlatform) {
      await GoogleSignIn().signOut();
    }
    APIService.shared.setFirebaseToken(null);
    _userId = null;
    _isAuthenticated = false;
    _displayName = null;
    _givenName = null;
    _email = null;
    _photoURL = null;
    _surname = null;
    _phone = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tribute_display_name');
    await prefs.remove('tribute_given_name');
    await prefs.remove('tribute_email');
    await prefs.remove('tribute_photo_url');
    await prefs.remove('tribute_surname');
    await prefs.remove('tribute_phone');
    notifyListeners();
  }

  // ── Delete account ───────────────────────────────────────────────────────

  /// Calls the `deleteAccount` Cloud Function, which permanently deletes all
  /// Firestore data, Storage files, and the Firebase Auth account server-side
  /// (no re-authentication required). Clears local state on success.
  Future<void> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'us-central1');
      await fn.httpsCallable('deleteAccount').call<void>();
      // Auth account is now deleted server-side — clear the local session.
      await FirebaseAuth.instance.signOut();
      if (!isApplePlatform) await GoogleSignIn().signOut();
      APIService.shared.setFirebaseToken(null);
      _userId = null;
      _isAuthenticated = false;
      _displayName = null;
      _givenName = null;
      _email = null;
      _photoURL = null;
      _surname = null;
      _phone = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Account deletion failed. Please try again.';
    } catch (e) {
      _error = 'Account deletion failed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Profile update ────────────────────────────────────────────────────────

  Future<void> updateProfile({
    String? firstName,
    String? surname,
    String? displayName,
    String? email,
    String? phone,
  }) async {
    if (firstName != null && firstName.isNotEmpty) _givenName = firstName;
    if (surname != null) _surname = surname;
    if (displayName != null && displayName.isNotEmpty) _displayName = displayName;
    if (email != null) _email = email.isEmpty ? null : email;
    if (phone != null) _phone = phone.isEmpty ? null : phone;

    final prefs = await SharedPreferences.getInstance();
    if (_givenName != null) await prefs.setString('tribute_given_name', _givenName!);
    if (_surname != null) {
      await prefs.setString('tribute_surname', _surname!);
    } else {
      await prefs.remove('tribute_surname');
    }
    if (_displayName != null) await prefs.setString('tribute_display_name', _displayName!);
    if (_email != null) {
      await prefs.setString('tribute_email', _email!);
    } else {
      await prefs.remove('tribute_email');
    }
    if (_phone != null) {
      await prefs.setString('tribute_phone', _phone!);
    } else {
      await prefs.remove('tribute_phone');
    }

    final uid = _userId;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(<String, dynamic>{
          if (_givenName != null) 'firstName': _givenName,
          if (_surname != null) 'surname': _surname,
          if (_displayName != null) 'displayName': _displayName,
          if (_email != null) 'email': _email,
          'phone': _phone,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    notifyListeners();
  }

  // ── Shared post-sign-in finalization ─────────────────────────────────────

  Future<void> _finalizeSignIn(
    User user, {
    String? displayName,
    String? givenName,
    String? email,
    String? photoURL,
    required List<String> providers,
  }) async {
    // Merge with existing in-memory values (first sign-in data takes priority for name)
    _displayName = displayName ?? user.displayName ?? _displayName;
    if (givenName != null) _givenName = givenName;
    if (email != null) _email = email;
    if (photoURL != null) _photoURL = photoURL;

    final idToken = await user.getIdToken();
    APIService.shared.setFirebaseToken(idToken, userId: user.uid);
    _userId = user.uid;
    _isAuthenticated = true;

    final prefs = await SharedPreferences.getInstance();
    if (_displayName != null) await prefs.setString('tribute_display_name', _displayName!);
    if (_givenName != null) await prefs.setString('tribute_given_name', _givenName!);
    if (_email != null) await prefs.setString('tribute_email', _email!);
    if (_photoURL != null) await prefs.setString('tribute_photo_url', _photoURL!);

    await _saveProfileToFirestore(
      uid: user.uid,
      email: email,
      photoURL: photoURL,
      displayName: displayName ?? user.displayName,
      providers: providers,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  // ── Firestore profile save ────────────────────────────────────────────────

  Future<void> _saveProfileToFirestore({
    required String uid,
    String? email,
    String? photoURL,
    String? displayName,
    required List<String> providers,
    required DateTime createdAt,
  }) async {
    try {
      final data = <String, dynamic>{
        'createdAt': Timestamp.fromDate(createdAt),
        'providers': FieldValue.arrayUnion(providers),
        'lastSignInAt': FieldValue.serverTimestamp(),
        'email': ?email,
        'photoURL': ?photoURL,
        'displayName': ?displayName,
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal — profile data will be saved on next sign-in
    }
  }

  // ── Cross-provider account linking ───────────────────────────────────────

  /// Called when Apple sign-in fails because the email already has a Google account.
  /// Signs in via Google then links the pending Apple credential to the same UID.
  Future<void> _linkViaGoogle({
    required OAuthCredential pendingAppleCredential,
    required String conflictEmail,
  }) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      _error = 'Sign-in was cancelled.';
      return;
    }

    final googleAuth = await googleUser.authentication;
    final googleCredential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(googleCredential);
    final user = userCredential.user;
    if (user == null) return;

    // Link Apple credential to the existing Google account
    await user.linkWithCredential(pendingAppleCredential);

    final displayName = googleUser.displayName;
    final givenName = displayName?.split(' ').firstOrNull;
    final email = _isPrivateRelayEmail(googleUser.email) ? null : googleUser.email;

    await _finalizeSignIn(
      user,
      displayName: displayName,
      givenName: givenName?.isNotEmpty == true ? givenName : null,
      email: email?.isNotEmpty == true ? email : null,
      photoURL: googleUser.photoUrl,
      providers: ['google.com', 'apple.com'],
    );
  }

  /// Called when Google sign-in fails because the email already has an Apple account.
  /// Signs in via Apple then links the pending Google credential to the same UID.
  Future<void> _linkViaApple({
    required OAuthCredential pendingGoogleCredential,
    required String conflictEmail,
  }) async {
    final rawNonce = _generateNonce();
    final nonce = _sha256OfString(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: nonce,
    );

    final identityToken = credential.identityToken;
    if (identityToken == null) {
      throw StateError('Apple sign-in did not return an identity token');
    }

    final appleCredential = AppleAuthProvider.credentialWithIDToken(
      identityToken,
      rawNonce,
      AppleFullPersonName(
        givenName: credential.givenName,
        familyName: credential.familyName,
      ),
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(appleCredential);
    final user = userCredential.user;
    if (user == null) return;

    // Link Google credential to the existing Apple account
    await user.linkWithCredential(pendingGoogleCredential);

    String? displayName;
    if (credential.givenName != null) {
      displayName = [credential.givenName, credential.familyName]
          .whereType<String>()
          .join(' ')
          .trim();
      if (displayName.isEmpty) displayName = null;
    }

    final givenName = (credential.givenName?.isNotEmpty ?? false) ? credential.givenName : null;
    final email = _isPrivateRelayEmail(credential.email) ? null : credential.email;

    await _finalizeSignIn(
      user,
      displayName: displayName,
      givenName: givenName,
      email: email,
      photoURL: user.photoURL,
      providers: ['apple.com', 'google.com'],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isPrivateRelayEmail(String? email) =>
      email != null && email.endsWith('@privaterelay.appleid.com');

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'Sign-in is not available right now. Please try again later.';
      default:
        return e.message ?? 'Sign-in failed. Please try again.';
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
