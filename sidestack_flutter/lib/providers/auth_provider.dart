import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthProvider
//
// Username login strategy:
//   • Firestore collection "usernames/{lowercaseUsername}" → { uid, email, username }
//   • signInWithEmail accepts either an email address or a username.
//   • OAuth users (Google/Apple) are shown a username setup screen on first
//     sign-in via needsUsernameSetup / completeOAuthSetup.
// ─────────────────────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = true;
  bool _needsUsernameSetup = false;
  String? _error;

  User? get user => _user;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  String? get userName => _user?.displayName;
  bool get isSignedIn => _user != null;
  bool get isLoading => _isLoading;
  bool get needsUsernameSetup => _needsUsernameSetup;
  String? get error => _error;

  /// Returns 'Google', 'Apple', 'email', or 'unknown'.
  String get signInProvider {
    if (_user == null) return 'unknown';
    final providers = _user!.providerData.map((p) => p.providerId).toList();
    if (providers.contains('google.com')) return 'Google';
    if (providers.contains('apple.com')) return 'Apple';
    if (providers.contains('password')) return 'email';
    return 'unknown';
  }

  bool get isEmailUser =>
      _user?.providerData.any((p) => p.providerId == 'password') ?? false;

  AuthProvider() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      if (user == null) {
        _isLoading = false;
        _needsUsernameSetup = false;
        notifyListeners();
      } else {
        // Keep isLoading = true until we've checked username setup.
        _checkNeedsUsernameSetup(user);
      }
    });
  }

  // ── Username setup check ───────────────────────────────────────────────────

  Future<void> _checkNeedsUsernameSetup(User user) async {
    // Email users always set a username at sign-up — skip the Firestore check.
    final isEmail = user.providerData.any((p) => p.providerId == 'password');
    if (isEmail) {
      _needsUsernameSetup = false;
    } else {
      // OAuth user: see if they already have a username doc.
      final snap = await _db
          .collection('usernames')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      _needsUsernameSetup = snap.docs.isEmpty;
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Username helpers ───────────────────────────────────────────────────────

  /// Returns null if available, or an error message if taken/invalid.
  Future<String?> checkUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.length < 3) return 'Username must be at least 3 characters.';
    if (trimmed.length > 20) return 'Username must be 20 characters or less.';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Only letters, numbers, and underscores allowed.';
    }
    final doc = await _db
        .collection('usernames')
        .doc(trimmed.toLowerCase())
        .get();
    if (doc.exists) return 'That username is already taken.';
    return null;
  }

  Future<void> _reserveUsername(String username, String uid, String email) {
    return _db.collection('usernames').doc(username.toLowerCase()).set({
      'uid': uid,
      'email': email,
      'username': username.trim(),
    });
  }

  /// Resolves a username to its email. Returns null if not found.
  Future<String?> _emailForUsername(String username) async {
    final doc = await _db
        .collection('usernames')
        .doc(username.toLowerCase().trim())
        .get();
    if (!doc.exists) return null;
    return doc.data()?['email'] as String?;
  }

  /// Looks up the username for a given email address.
  /// Returns the username string, or null if no account is linked to that email.
  Future<String?> lookupUsernameByEmail(String email) async {
    final trimmed = email.trim().toLowerCase();
    final snap = await _db
        .collection('usernames')
        .where('email', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['username'] as String?;
  }

  // ── Sign up ────────────────────────────────────────────────────────────────

  Future<bool> signUpWithEmail(
      String email, String password, String firstName, String lastName,
      String username) async {
    try {
      _error = null;
      final usernameError = await checkUsername(username);
      if (usernameError != null) {
        _error = usernameError;
        notifyListeners();
        return false;
      }
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fullName = '$firstName $lastName'.trim();
      await cred.user?.updateDisplayName(fullName);
      if (cred.user != null) {
        // Use Firebase-normalised email (always lowercase) for consistent lookup.
        final normalizedEmail = cred.user!.email ?? email.trim().toLowerCase();
        await _reserveUsername(username, cred.user!.uid, normalizedEmail);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      notifyListeners();
      return false;
    }
  }

  /// Called after an OAuth sign-in when the user hasn't set a username yet.
  /// Validates, reserves, and clears [needsUsernameSetup].
  Future<bool> completeOAuthSetup(String username) async {
    try {
      _error = null;
      final usernameError = await checkUsername(username);
      if (usernameError != null) {
        _error = usernameError;
        notifyListeners();
        return false;
      }
      if (_user == null) return false;
      final email = (_user!.email ?? '').toLowerCase();
      await _reserveUsername(username, _user!.uid, email);
      _needsUsernameSetup = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Sign in (email or username) ────────────────────────────────────────────

  Future<bool> signInWithEmail(String emailOrUsername, String password) async {
    try {
      _error = null;
      String email;
      if (emailOrUsername.contains('@')) {
        email = emailOrUsername.trim();
      } else {
        final resolved = await _emailForUsername(emailOrUsername);
        if (resolved == null) {
          _error = 'No account found with that username.';
          notifyListeners();
          return false;
        }
        email = resolved;
      }
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      notifyListeners();
      return false;
    }
  }

  // ── Google ─────────────────────────────────────────────────────────────────

  Future<bool> signInWithGoogle() async {
    try {
      _error = null;
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Google sign-in failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Apple ──────────────────────────────────────────────────────────────────

  Future<bool> signInWithApple() async {
    try {
      _error = null;
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final fullName = appleCredential.givenName != null
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
          : null;
      if (fullName != null && fullName.isNotEmpty &&
          (userCredential.user?.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        await userCredential.user?.updateDisplayName(fullName);
      }
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return false;
      _error = 'Apple sign-in failed. Please try again.';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Apple sign-in failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Password reset ─────────────────────────────────────────────────────────

  Future<bool> resetPassword(String emailOrUsername) async {
    try {
      _error = null;
      String email;
      if (emailOrUsername.contains('@')) {
        email = emailOrUsername.trim();
      } else {
        final resolved = await _emailForUsername(emailOrUsername);
        if (resolved == null) {
          _error = 'No account found with that username.';
          notifyListeners();
          return false;
        }
        email = resolved;
      }
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      notifyListeners();
      return false;
    }
  }

  // ── Account management ─────────────────────────────────────────────────────

  Future<String?> reauthenticateWithEmail(String password) async {
    try {
      final cred = EmailAuthProvider.credential(
          email: _user?.email ?? '', password: password);
      await _user?.reauthenticateWithCredential(cred);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  Future<String?> changePassword(String newPassword) async {
    try {
      await _user?.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  Future<String?> deleteAccount() async {
    try {
      await _user?.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Friendly errors ────────────────────────────────────────────────────────

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found. Check your email or username.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
