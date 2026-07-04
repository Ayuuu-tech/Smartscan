import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ------------------------------------------------------------------
// App User Model
// ------------------------------------------------------------------
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
  });

  factory AppUser.fromFirebaseUser(User user) {
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName:
          user.displayName ?? user.email?.split('@')[0] ?? 'User',
      photoURL: user.photoURL,
    );
  }
}

// ------------------------------------------------------------------
// Auth Stream Provider (reactive to Firebase auth state)
// ------------------------------------------------------------------
final firebaseAuthUserProvider = StreamProvider<User?>((ref) {
  // userChanges() also emits on profile updates (e.g. display-name edits),
  // not just sign-in/out, so the UI reflects Edit Profile immediately.
  return FirebaseAuth.instance.userChanges();
});

// Derived provider: AppUser? from Firebase User
final authStateProvider = Provider<AppUser?>((ref) {
  final asyncUser = ref.watch(firebaseAuthUserProvider);
  return asyncUser.when(
    data: (user) => user != null ? AppUser.fromFirebaseUser(user) : null,
    loading: () => null,
    error: (_, _) => null,
  );
});

// ------------------------------------------------------------------
// Auth Service (actions: sign-in, sign-up, sign-out)
// ------------------------------------------------------------------
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // Web OAuth client id from google-services.json (oauth_client, client_type 3).
  // Required as serverClientId so the Google id token is minted for Firebase.
  static const String _serverClientId =
      '350277273215-2772qf14pmmijlisk51tcr2nqlfqb6u2.apps.googleusercontent.com';

  static bool _googleReady = false;

  /// The most recent Google account signed in this session — used by
  /// DriveService to authorize Drive scopes without re-prompting.
  static GoogleSignInAccount? lastGoogleAccount;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleReady) return;
    // google_sign_in v7 requires an explicit initialize() before use.
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _googleReady = true;
  }

  // ----------------------------------------------------------------
  // Email & Password Sign-In
  // ----------------------------------------------------------------
  Future<String?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ----------------------------------------------------------------
  // Email & Password Sign-Up
  // ----------------------------------------------------------------
  Future<String?> signUpWithEmailAndPassword(
      String email, String password, String displayName) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.updateDisplayName(displayName.trim());
      await cred.user?.reload();
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  // ----------------------------------------------------------------
  // Google Sign-In
  // ----------------------------------------------------------------
  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
        return null;
      }

      await _ensureGoogleInitialized();

      // authenticate() throws GoogleSignInException on cancel/failure.
      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      lastGoogleAccount = googleUser;

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        return 'Google Sign-In failed: no ID token returned.';
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // user dismissed the picker — not an error
      }
      return 'Google Sign-In failed: ${e.description ?? e.code.name}';
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      return 'Google Sign-In failed: $e';
    }
  }

  // ----------------------------------------------------------------
  // Update display name
  // ----------------------------------------------------------------
  Future<String?> updateDisplayName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name.trim());
      await _auth.currentUser?.reload();
      return null;
    } catch (e) {
      return 'Could not update profile. Please try again.';
    }
  }

  // ----------------------------------------------------------------
  // Sign Out
  // ----------------------------------------------------------------
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
      lastGoogleAccount = null;
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  // ----------------------------------------------------------------
  // Password Reset Email
  // ----------------------------------------------------------------
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      return 'Failed to send email. Please try again.';
    }
  }

  // ----------------------------------------------------------------
  // Firebase error codes → English messages
  // ----------------------------------------------------------------
  String _errorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return 'Error: $code';
    }
  }
}
