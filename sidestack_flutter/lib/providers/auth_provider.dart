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

// Sentinel used inside Firestore transactions to signal "username taken"
// without conflating it with other exceptions.
class _UsernameTakenException implements Exception {}

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = true;
  bool _needsUsernameSetup = false;
  String? _error;

  // ── Account linking (same email, different provider) ────────────────────────
  // Set when Apple/Google sign-in detects an existing email/password account
  // with the same email address. The app shows a linking UI until resolved.
  AuthCredential? _pendingOAuthCredential;
  String? _pendingLinkEmail;
  bool _needsAccountLink = false;

  User? get user => _user;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  String? get userName => _user?.displayName;
  bool get isSignedIn => _user != null;
  bool get isLoading => _isLoading;
  bool get needsUsernameSetup => _needsUsernameSetup;
  bool get needsAccountLink => _needsAccountLink;
  String? get pendingLinkEmail => _pendingLinkEmail;
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
      // OAuth user: see if they already have a username doc by UID.
      final snap = await _db
          .collection('usernames')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // No username for this UID — check if same email exists under a
        // different UID (i.e. user has an existing email/password account).
        final email = user.email;
        if (email != null) {
          final emailSnap = await _db
              .collection('usernames')
              .where('email', isEqualTo: email.toLowerCase())
              .limit(2)
              .get();
          final otherAccount = emailSnap.docs
              .where((d) => d.data()['uid'] != user.uid)
              .toList();
          if (otherAccount.isNotEmpty) {
            // Existing account with same email found — needs linking.
            // We'll prompt the user to enter their password; that sign-in
            // will migrate them back to their original UID automatically
            // once we link the OAuth credential.
            _pendingLinkEmail = email;
            _needsAccountLink = true;
            _needsUsernameSetup = false;
            _isLoading = false;
            notifyListeners();
            return;
          }
        }
        _needsUsernameSetup = true;
      } else {
        _needsUsernameSetup = false;
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Username helpers ───────────────────────────────────────────────────────

  /// Pure local format check — no Firestore round-trip.
  String? _validateUsernameFormat(String username) {
    final trimmed = username.trim();
    if (trimmed.length < 3) return 'Username must be at least 3 characters.';
    if (trimmed.length > 20) return 'Username must be 20 characters or less.';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Only letters, numbers, and underscores allowed.';
    }
    return null;
  }

  /// Returns null if available, or an error message if taken/invalid.
  /// Safe for real-time UI feedback, but NOT safe for final submission —
  /// two users could both pass this check simultaneously.
  /// The actual claim always uses [_atomicReserveUsername].
  Future<String?> checkUsername(String username) async {
    final formatError = _validateUsernameFormat(username);
    if (formatError != null) return formatError;
    final doc = await _db
        .collection('usernames')
        .doc(username.trim().toLowerCase())
        .get();
    if (doc.exists) return 'That username is already taken.';
    return null;
  }

  /// Atomically checks availability and reserves the username in a single
  /// Firestore transaction, eliminating the TOCTOU race condition.
  /// Returns null on success, or an error string on failure.
  Future<String?> _atomicReserveUsername(
      String username, String uid, String email) async {
    final formatError = _validateUsernameFormat(username);
    if (formatError != null) return formatError;

    final docRef =
        _db.collection('usernames').doc(username.trim().toLowerCase());
    try {
      await _db.runTransaction((txn) async {
        final snap = await txn.get(docRef);
        if (snap.exists) throw _UsernameTakenException();
        txn.set(docRef, {
          'uid': uid,
          'email': email,
          'username': username.trim(),
        });
      });
      return null; // success
    } on _UsernameTakenException {
      return 'That username is already taken.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
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

      // Fast local format check before touching Firebase
      final formatError = _validateUsernameFormat(username);
      if (formatError != null) {
        _error = formatError;
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
        // Atomic reserve — if it fails (e.g. race condition), roll back the
        // newly-created auth account so the user doesn't end up account-less.
        final reserveError = await _atomicReserveUsername(
            username, cred.user!.uid, normalizedEmail);
        if (reserveError != null) {
          await cred.user?.delete();
          _error = reserveError;
          notifyListeners();
          return false;
        }
        // Persist display name to Firestore so it's always available,
        // even when signing in with Apple/Google using the same email.
        final fullName = '$firstName $lastName'.trim();
        if (fullName.isNotEmpty) {
          try {
            await _db.collection('users').doc(cred.user!.uid).set(
              {'displayName': fullName},
              SetOptions(merge: true),
            );
          } catch (_) {}
        }
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      notifyListeners();
      return false;
    }
  }

  /// Called after an OAuth sign-in when the user hasn't set a username yet.
  /// Atomically reserves the username and clears [needsUsernameSetup].
  Future<bool> completeOAuthSetup(String username) async {
    try {
      _error = null;
      if (_user == null) return false;
      final email = (_user!.email ?? '').toLowerCase();
      final reserveError =
          await _atomicReserveUsername(username, _user!.uid, email);
      if (reserveError != null) {
        _error = reserveError;
        notifyListeners();
        return false;
      }
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

      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          final email = e.email ?? googleUser.email;
          if (email.isNotEmpty) {
            _pendingOAuthCredential = credential;
            _pendingLinkEmail = email;
            _needsAccountLink = true;
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
        rethrow;
      }

      final signedInUser = userCredential.user;
      final email = signedInUser?.email;

      // Persist display name to Firestore so it loads even after re-login.
      if (signedInUser != null) {
        final nameToStore = signedInUser.displayName;
        if (nameToStore != null && nameToStore.isNotEmpty) {
          try {
            await _db.collection('users').doc(signedInUser.uid).set(
              {'displayName': nameToStore},
              SetOptions(merge: true),
            );
          } catch (_) {}
        }
      }

      // Detect existing email/password account with same email.
      if (email != null) {
        final emailSnap = await _db
            .collection('usernames')
            .where('email', isEqualTo: email.toLowerCase())
            .limit(2)
            .get();
        final otherAccount = emailSnap.docs
            .where((d) => d.data()['uid'] != signedInUser!.uid)
            .toList();
        if (otherAccount.isNotEmpty) {
          _pendingOAuthCredential = credential;
          _pendingLinkEmail = email;
          _needsAccountLink = true;
          await _auth.signOut();
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

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

      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithCredential(oauthCredential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          // Firebase one-account-per-email mode: existing account found.
          final email = e.email ?? appleCredential.email ?? '';
          if (email.isNotEmpty) {
            _pendingOAuthCredential = oauthCredential;
            _pendingLinkEmail = email;
            _needsAccountLink = true;
            _isLoading = false;
            notifyListeners();
            return true; // Not an error — handled by linking UI
          }
        }
        rethrow;
      }

      final signedInUser = userCredential.user;
      final email = signedInUser?.email;

      // Build the display name from Apple's response (only provided on first auth).
      final fullName = appleCredential.givenName != null
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
          : null;
      if (fullName != null && fullName.isNotEmpty &&
          (signedInUser?.displayName == null ||
              signedInUser!.displayName!.isEmpty)) {
        await signedInUser?.updateDisplayName(fullName);
      }

      // Persist display name to Firestore so it survives sign-out / re-login
      // (Apple only sends the name on the very first authorisation).
      if (signedInUser != null) {
        final nameToStore = signedInUser.displayName ?? fullName;
        if (nameToStore != null && nameToStore.isNotEmpty) {
          try {
            await _db.collection('users').doc(signedInUser.uid).set(
              {'displayName': nameToStore},
              SetOptions(merge: true),
            );
          } catch (_) {}
        }
      }

      // Multiple-accounts-per-email mode: detect if this email already exists
      // under a different UID (existing email/password account).
      if (email != null) {
        final emailSnap = await _db
            .collection('usernames')
            .where('email', isEqualTo: email.toLowerCase())
            .limit(2)
            .get();
        final otherAccount = emailSnap.docs
            .where((d) => d.data()['uid'] != signedInUser!.uid)
            .toList();
        if (otherAccount.isNotEmpty) {
          // Store the credential for linking after the user enters their password.
          _pendingOAuthCredential = oauthCredential;
          _pendingLinkEmail = email;
          _needsAccountLink = true;
          // Sign out the freshly-created OAuth account — it will be abandoned
          // once the user links via their email/password.
          await _auth.signOut();
          _isLoading = false;
          notifyListeners();
          return true; // Handled by linking UI
        }
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

  // ── Profile edits ──────────────────────────────────────────────────────────

  /// Updates the Firebase Auth display name (first + last name) and mirrors
  /// it to Firestore so it's visible across all sign-in providers.
  Future<String?> changeDisplayName(String name) async {
    try {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return 'Name cannot be empty.';
      await _user?.updateDisplayName(trimmed);
      // Mirror to Firestore so Apple/Google sign-ins can read it back.
      if (_user != null) {
        try {
          await _db.collection('users').doc(_user!.uid).set(
            {'displayName': trimmed},
            SetOptions(merge: true),
          );
        } catch (_) {}
      }
      // Force a reload so _user.displayName reflects the update immediately.
      await _user?.reload();
      _user = _auth.currentUser;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  /// Atomically swaps the user's username: creates the new doc, deletes the
  /// old one, and updates the local AppProvider cache via [onSuccess].
  Future<String?> changeUsername(String newUsername) async {
    final formatError = _validateUsernameFormat(newUsername);
    if (formatError != null) return formatError;

    if (_user == null) return 'Not signed in.';

    // Find the current username doc BEFORE starting the transaction (queries
    // can't run inside Firestore transactions).
    final existing = await _db
        .collection('usernames')
        .where('uid', isEqualTo: _user!.uid)
        .limit(1)
        .get();

    final newKey = newUsername.trim().toLowerCase();
    final newDocRef = _db.collection('usernames').doc(newKey);

    try {
      await _db.runTransaction((txn) async {
        final newSnap = await txn.get(newDocRef);
        // Allow if doc doesn't exist OR already belongs to this user (no-op rename)
        if (newSnap.exists && newSnap.data()?['uid'] != _user!.uid) {
          throw _UsernameTakenException();
        }
        txn.set(newDocRef, {
          'uid': _user!.uid,
          'email': (_user!.email ?? '').toLowerCase(),
          'username': newUsername.trim(),
        });
        // Delete the old doc(s) — skip if it's the same key (case-only rename)
        for (final doc in existing.docs) {
          if (doc.id != newKey) txn.delete(doc.reference);
        }
      });
      notifyListeners();
      return null;
    } on _UsernameTakenException {
      return 'That username is already taken.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
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

  /// Deletes the Firebase Auth account. Firestore cleanup is handled server-side
  /// by the deleteUserData Cloud Function triggered on auth.user().onDelete().
  Future<String?> deleteAccount() async {
    try {
      await _user?.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    }
  }

  /// Links the pending Apple/Google credential to an existing email/password
  /// account. Call this when the user enters their email account password
  /// after signing in with Apple/Google and we detected an existing account.
  ///
  /// After success: the Firebase user is the email account (same UID as before)
  /// with the OAuth provider now linked → all existing Firestore data is intact.
  Future<String?> linkAccountWithEmailPassword(String password) async {
    try {
      _error = null;
      if (_pendingOAuthCredential == null || _pendingLinkEmail == null) {
        return 'Nothing to link.';
      }
      // Sign in with the email/password account (their "real" account).
      final emailUserCred = await _auth.signInWithEmailAndPassword(
        email: _pendingLinkEmail!,
        password: password,
      );
      // Link the OAuth provider to this account so future OAuth sign-ins
      // will arrive at the same UID.
      try {
        await emailUserCred.user?.linkWithCredential(_pendingOAuthCredential!);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'provider-already-linked' &&
            e.code != 'credential-already-in-use') {
          rethrow;
        }
        // Already linked — still a success
      }
      _pendingOAuthCredential = null;
      _pendingLinkEmail = null;
      _needsAccountLink = false;
      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Cancels the pending account link (user chose to sign in normally instead).
  void cancelAccountLink() {
    _pendingOAuthCredential = null;
    _pendingLinkEmail = null;
    _needsAccountLink = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _pendingOAuthCredential = null;
    _pendingLinkEmail = null;
    _needsAccountLink = false;
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
