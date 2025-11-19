import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Firebase Authentication service
/// Handles user authentication operations
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  void _log(String message) {
    debugPrint('🔍 [AuthService] $message');
  }

  void _logError(String message, Object error, StackTrace? stackTrace) {
    debugPrint('❌ [AuthService] $message -> $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('✅ User signed in: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Sign in error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected sign in error: $e');
      rethrow;
    }
  }

  /// Create account with email and password
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('✅ User created: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Sign up error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected sign up error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('✅ User signed out');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('✅ Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Password reset error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected password reset error: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    _log('Google sign-in triggered');

    // Retry logic to handle plugin type casting errors
    for (int attempt = 0; attempt < 3; attempt++) {
      UserCredential? lastSuccessfulCredential;

      try {
        if (attempt > 0) {
          _log('Retrying Google Sign-In (attempt ${attempt + 1}/3)');
          // Wait a bit before retry
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }

        // Always sign out first to force account picker (user must choose account)
        _log('Signing out to force account selection');
        try {
          await _googleSignIn.signOut();
          _log('Successfully signed out, account picker will be shown');
        } catch (e) {
          // Ignore sign-out errors, but log them
          _log('Sign-out failed but continuing (may already be signed out): $e');
        }

        // Trigger the authentication flow
        _log('Launching Google account picker');
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          // User canceled the sign-in
          _log('User dismissed Google sign-in UI');
          return null;
        }

        _log('Google returned account: ${googleUser.email}');

        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        if (googleAuth.idToken == null) {
          _log('Google auth returned null idToken. Cannot continue.');
          throw FirebaseAuthException(
            code: 'invalid-google-token',
            message: 'Google did not return an idToken. Please try again.',
          );
        }

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credential
        lastSuccessfulCredential = await _auth.signInWithCredential(credential);
        _log('Firebase sign-in (interactive) succeeded for ${lastSuccessfulCredential.user?.email}');
        return lastSuccessfulCredential;
      } on FirebaseAuthException catch (e) {
        _log('FirebaseAuthException during Google sign-in: ${e.code} - ${e.message}');
        // Don't retry Firebase Auth errors
        rethrow;
      } catch (e, stack) {
        // Handle PlatformException for Google Sign-In errors
        if (e.toString().contains('ApiException: 10')) {
          _log('Google sign-in developer configuration error (missing SHA).');
          throw FirebaseAuthException(
            code: 'developer-error',
            message: 'SHA-1 certificate not configured. Please add your SHA-1 fingerprint to Firebase Console.',
          );
        }
        
        // Handle type casting error in google_sign_in plugin
        if (e.toString().contains('PigeonUserDetails') ||
            e.toString().contains('is not a subtype of type')) {
          _logError(
            'Google sign-in plugin type casting error during attempt ${attempt + 1}',
            e,
            stack,
          );

          if (lastSuccessfulCredential != null) {
            _log('Plugin errored after Firebase sign-in. Returning successful credential.');
            return lastSuccessfulCredential;
          }

          // If this is the last attempt, throw the error
          if (attempt == 2) {
            _log('All Google sign-in retry attempts failed.');
            throw FirebaseAuthException(
              code: 'plugin-error',
              message: 'Google Sign-In encountered an error. Please try again later or use email/password sign-in.',
            );
          }
          
          // Otherwise, continue to retry
          continue;
        }
        
        // For other errors, rethrow immediately
        _logError('Unexpected Google sign-in error', e, stack);
        rethrow;
      }
    }
    
    // Should never reach here, but just in case
    throw FirebaseAuthException(
      code: 'plugin-error',
      message: 'Google Sign-In failed after multiple attempts.',
    );
  }

  /// Update user display name
  Future<void> updateDisplayName(String displayName) async {
    try {
      await currentUser?.updateDisplayName(displayName);
      await currentUser?.reload();
      debugPrint('✅ Display name updated: $displayName');
    } catch (e) {
      debugPrint('❌ Update display name error: $e');
      rethrow;
    }
  }

  /// Get user-friendly error message
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired.';
      case 'developer-error':
        return 'Google Sign-In is not properly configured. Please contact support.';
      case 'plugin-error':
        return 'Google Sign-In encountered an error. Please try again or use email/password.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}

