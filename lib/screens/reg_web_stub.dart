// Stub file for web platform - Google Sign-In is not available on web
// Web uses Firebase Auth's signInWithPopup directly
// These classes are never actually used on web, but needed for type compatibility

class GoogleSignIn {
  GoogleSignIn({List<String>? scopes});
  Future<GoogleSignInAccount?> signIn() async => null;
  Future<void> signOut() async {}
}

class GoogleSignInAccount {
  String? get displayName => null;
  String? get photoUrl => null;
  Future<GoogleSignInAuthentication> get authentication async => GoogleSignInAuthentication();
}

class GoogleSignInAuthentication {
  String? get idToken => null;
  String? get accessToken => null;
}

