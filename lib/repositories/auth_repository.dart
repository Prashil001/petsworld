import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:shop/models/app_user_model.dart';

abstract class AuthRepository {
  Future<AppUserModel?> getCurrentUser();
  Future<AppUserModel> signIn({
    required String email,
    required String password,
  });
  Future<AppUserModel> signUp({
    required String email,
    required String password,
    required String name,
  });
  Future<PhoneAuthRequestResult> requestPhoneOtp({
    required String phoneNumber,
    int? forceResendingToken,
  });
  Future<AppUserModel> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    String? preferredName,
  });
  Future<void> sendEmailVerification({
    required String email,
    required String password,
  });
  Future<void> sendPasswordResetEmail(String email);
  Future<AppUserModel> updateProfile({required String name});
  Future<void> deleteAccount();
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  static const Duration _authOperationTimeout = Duration(seconds: 25);
  static const Duration _profileOperationTimeout = Duration(seconds: 20);
  static const Duration _secondaryOperationTimeout = Duration(seconds: 10);

  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth,
       _firestore = firestore;

  final FirebaseAuth? _firebaseAuth;
  final FirebaseFirestore? _firestore;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  bool get _isReady => Firebase.apps.isNotEmpty;

  @override
  Future<AppUserModel?> getCurrentUser() async {
    if (!_isReady) return null;

    var user = _auth.currentUser;
    if (user == null) return null;
    if (_requiresEmailVerification(user)) {
      await user.reload();
      user = _auth.currentUser;
      if (user == null || !user.emailVerified) {
        await _auth.signOut();
        return null;
      }
    }

    return _loadUserProfile(user);
  }

  @override
  Future<AppUserModel> signIn({
    required String email,
    required String password,
  }) async {
    _ensureReady();

    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    var user = credential.user!;
    if (_requiresEmailVerification(user)) {
      await user.reload();
      user = _auth.currentUser ?? user;
      if (!user.emailVerified) {
        try {
          await user.sendEmailVerification();
        } catch (_) {}
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message:
              'Your email is not verified yet. A verification email was sent to ${user.email ?? email.trim()}. Please check inbox/spam and try again.',
        );
      }
    }

    return _loadUserProfile(user);
  }

  @override
  Future<AppUserModel> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _ensureReady();

    final trimmedEmail = email.trim();
    final trimmedName = name.trim();

    User? createdUser;
    var shouldSignOut = false;

    try {
      final credential = await _auth
          .createUserWithEmailAndPassword(
            email: trimmedEmail,
            password: password,
          )
          .timeout(_authOperationTimeout);

      final user = credential.user;
      if (user == null) {
        throw StateError('Account creation did not return a user session.');
      }

      createdUser = user;
      shouldSignOut = true;

      await user.updateDisplayName(trimmedName).timeout(
        _secondaryOperationTimeout,
        onTimeout: () {},
      );

      final appUser = AppUserModel(
        uid: user.uid,
        email: user.email ?? trimmedEmail,
        name: trimmedName,
        role: AppUserRole.user,
        createdAt: DateTime.now(),
      );

      await _db
          .collection('users')
          .doc(user.uid)
          .set(appUser.toMap(), SetOptions(merge: true))
          .timeout(_profileOperationTimeout);

      try {
        await user.sendEmailVerification().timeout(
          _secondaryOperationTimeout,
        );
      } catch (error) {
        if (kDebugMode) debugPrint('Unable to send verification email: $error');
      }

      return appUser;
    } on TimeoutException catch (_) {
      if (createdUser != null) {
        try {
          await _db.collection('users').doc(createdUser.uid).set(
            <String, dynamic>{
              'uid': createdUser.uid,
              'email': createdUser.email ?? trimmedEmail,
              'name': trimmedName,
              'role': AppUserRole.user.name,
              'createdAt': DateTime.now().toIso8601String(),
            },
            SetOptions(merge: true),
          ).timeout(_secondaryOperationTimeout);
        } catch (_) {}
      }
      throw StateError(
        'Signup is taking too long. Please check your connection and try logging in after a moment.',
      );
    } finally {
      if (shouldSignOut) {
        try {
          await _auth.signOut().timeout(
            _secondaryOperationTimeout,
            onTimeout: () {},
          );
        } catch (_) {}
      }
    }
  }

  @override
  Future<PhoneAuthRequestResult> requestPhoneOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    _ensureReady();

    final completer = Completer<PhoneAuthRequestResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      forceResendingToken: forceResendingToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (completer.isCompleted) return;
        try {
          final userCredential = await _auth.signInWithCredential(credential);
          final appUser = await _loadUserProfile(userCredential.user!);
          completer.complete(
            PhoneAuthRequestResult.autoVerified(user: appUser),
          );
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      },
      verificationFailed: (FirebaseAuthException exception) {
        if (kDebugMode) {
          debugPrint(
            'Phone auth failed [${exception.code}]: ${exception.message}',
          );
        }
        if (completer.isCompleted) return;
        completer.completeError(exception);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (kDebugMode) debugPrint('Phone auth code sent');
        if (completer.isCompleted) return;
        completer.complete(
          PhoneAuthRequestResult.codeSent(
            verificationId: verificationId,
            resendToken: resendToken,
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (kDebugMode) debugPrint('Phone auth auto retrieval timed out');
        if (completer.isCompleted) return;
        completer.complete(
          PhoneAuthRequestResult.codeSent(verificationId: verificationId),
        );
      },
    );

    return completer.future;
  }

  @override
  Future<AppUserModel> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    String? preferredName,
  }) async {
    _ensureReady();

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    final trimmedName = preferredName?.trim() ?? '';
    if (trimmedName.isNotEmpty && (user.displayName ?? '').trim().isEmpty) {
      await user.updateDisplayName(trimmedName);
    }

    return _loadUserProfile(user, preferredName: trimmedName);
  }

  @override
  Future<void> sendEmailVerification({
    required String email,
    required String password,
  }) async {
    _ensureReady();

    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    try {
      await user.reload();
      final refreshedUser = _auth.currentUser ?? user;
      if (refreshedUser.emailVerified) {
        throw FirebaseAuthException(
          code: 'email-already-verified',
          message: 'This email address is already verified.',
        );
      }

      await refreshedUser.sendEmailVerification();
    } finally {
      await _auth.signOut();
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    _ensureReady();
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<AppUserModel> updateProfile({required String name}) async {
    _ensureReady();
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in to update profile.');
    }

    final trimmedName = name.trim();

    await user.updateDisplayName(trimmedName);
    await _db.collection('users').doc(user.uid).set(<String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? '',
      'name': trimmedName,
      'phoneNumber': user.phoneNumber,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    return _loadUserProfile(user);
  }

  @override
  Future<void> deleteAccount() async {
    _ensureReady();

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in to delete your account.');
    }

    final lastSignIn = user.metadata.lastSignInTime;
    final needsFreshLogin =
        lastSignIn == null ||
        DateTime.now().difference(lastSignIn) > const Duration(minutes: 10);
    if (needsFreshLogin) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message:
            'For security, please log out and log back in before deleting your account.',
      );
    }

    final userId = user.uid;
    await _deleteUserData(userId);
    await user.delete();
  }

  @override
  Future<void> signOut() async {
    if (!_isReady) return;
    await _auth.signOut();
  }

  Future<AppUserModel> _loadUserProfile(
    User user, {
    String? preferredName,
  }) async {
    final doc = await _db.collection('users').doc(user.uid).get();

    if (doc.exists && doc.data() != null) {
      return AppUserModel.fromMap(user.uid, doc.data()!);
    }

    final fallbackUser = AppUserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: _buildBestUserName(user: user, preferredName: preferredName),
      phoneNumber: user.phoneNumber,
      role: AppUserRole.user,
      createdAt: DateTime.now(),
    );

    await _db
        .collection('users')
        .doc(user.uid)
        .set(fallbackUser.toMap(), SetOptions(merge: true));

    return fallbackUser;
  }

  String _nameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return 'Pet Parent';
    return email.split('@').first;
  }

  String _buildBestUserName({required User user, String? preferredName}) {
    final trimmedPreferredName = preferredName?.trim() ?? '';
    if (trimmedPreferredName.isNotEmpty) return trimmedPreferredName;

    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;

    final byEmail = _nameFromEmail(user.email);
    if (byEmail != 'Pet Parent') return byEmail;

    final phone = user.phoneNumber ?? '';
    if (phone.length >= 4) {
      return 'Pet Parent ${phone.substring(phone.length - 4)}';
    }
    return 'Pet Parent';
  }

  bool _requiresEmailVerification(User user) {
    final hasEmail = (user.email ?? '').trim().isNotEmpty;
    if (!hasEmail) return false;
    return user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  void _ensureReady() {
    if (!_isReady) {
      throw StateError(
        'Firebase is not configured yet. Run flutterfire configure and add '
        'the platform config files before using authentication.',
      );
    }
  }

  Future<void> _deleteUserData(String userId) async {
    final userRef = _db.collection('users').doc(userId);

    await _deleteCollection(userRef.collection('cartItems'));
    await _deleteCollection(userRef.collection('savedItems'));
    await _deleteCollection(userRef.collection('addresses'));

    final ordersSnapshot = await _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .get();
    if (ordersSnapshot.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in ordersSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await userRef.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

class PhoneAuthRequestResult {
  const PhoneAuthRequestResult._({
    required this.codeSent,
    this.verificationId,
    this.resendToken,
    this.user,
  });

  factory PhoneAuthRequestResult.codeSent({
    required String verificationId,
    int? resendToken,
  }) {
    return PhoneAuthRequestResult._(
      codeSent: true,
      verificationId: verificationId,
      resendToken: resendToken,
    );
  }

  factory PhoneAuthRequestResult.autoVerified({required AppUserModel user}) {
    return PhoneAuthRequestResult._(codeSent: false, user: user);
  }

  final bool codeSent;
  final String? verificationId;
  final int? resendToken;
  final AppUserModel? user;
}
