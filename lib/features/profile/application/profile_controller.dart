import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../auth/application/auth_controller.dart';

final _usersCollection = FirebaseFirestore.instance.collection('users');

/// Live Firestore stream of the signed-in student's `/users/{uid}` document.
/// `null` while there's no signed-in user, or once briefly right after
/// signup before the profile document has been created.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);
  return _usersCollection.doc(user.uid).snapshots().map((snap) {
    final data = snap.data();
    if (data == null) return null;
    return UserProfile.fromMap(user.uid, data);
  });
});

final profileControllerProvider =
    NotifierProvider<ProfileController, AsyncValue<void>>(
      ProfileController.new,
    );

/// Creates/updates the student's `/users/{uid}` profile document. Kept
/// separate from AuthController so a Firestore write failure never gets
/// confused with a FirebaseAuth failure in the UI.
class ProfileController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  /// Called right after a brand-new signup (either method) to create the
  /// initial `/users/{uid}` document.
  Future<void> createInitialProfile({
    required String displayName,
    required DisplayNameSource source,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await user.updateDisplayName(displayName);
      final profile = UserProfile(
        uid: user.uid,
        displayName: displayName,
        displayNameSource: source,
        email: user.email,
        phone: user.phoneNumber,
        designation: 'Student',
        passwordSet: user.providerData.any((p) => p.providerId == 'password'),
      );
      await _usersCollection
          .doc(user.uid)
          .set(profile.toMap(isCreate: true), SetOptions(merge: true));
    });
  }

  Future<void> updateProfile(UserProfile profile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _usersCollection
          .doc(profile.uid)
          .set(profile.toMap(), SetOptions(merge: true));
    });
  }

  Future<void> markPasswordSet() async {
    final user = _currentUser;
    if (user == null) return;
    await _usersCollection.doc(user.uid).set({
      'passwordSet': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Play Store policy requires an in-app way to delete one's account. This
  /// removes the profile document; deleting per-user subcollections
  /// (attempts, progress, etc.) at scale belongs in a Cloud Function
  /// trigger, not client code — this call only handles the doc + auth user.
  Future<void> deleteAccount() async {
    final user = _currentUser;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _usersCollection.doc(user.uid).delete();
      await user.delete();
    });
  }
}
