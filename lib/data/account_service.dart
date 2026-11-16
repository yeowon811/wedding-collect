import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app_state.dart';
import 'repositories/repositories.dart';
import 'user_data_codec.dart';

/// 지금 계정 상태
enum AccountMode {
  unavailable, // Firebase 연결 안 됨 (테스트·오프라인) → 로그인 없이 바로 사용
  signedOut, // 첫 화면에서 로그인/둘러보기를 골라야 함
  guest, // 로그인 없이 둘러보기 (저장 안 됨)
  signedIn, // 로그인: 내 정보가 계정에 자동 저장
}

/// 회원가입·로그인(Firebase 이메일 인증)과 내 정보 저장(Firestore `users/{uid}`).
/// 문서는 본인만 읽고 쓸 수 있다 (firestore.rules). 이메일은 문서에 넣지 않는다.
class AccountService extends ChangeNotifier {
  AccountService._();

  static final instance = AccountService._();

  AccountMode mode = AccountMode.unavailable;
  User? user;
  DateTime? lastSaved;
  String? syncError; // 저장·불러오기 실패 안내

  bool get _ready => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Timer? _saveTimer;
  bool _applying = false; // 불러온 값을 적용하는 동안에는 저장하지 않음
  StreamSubscription<User?>? _sub;

  /// 앱 시작 때 한 번. Firebase가 없으면 계정 기능 없이 진행.
  Future<void> init({bool startAsGuest = false}) async {
    if (!_ready) {
      mode = AccountMode.unavailable;
      return;
    }
    user = _auth.currentUser;
    mode = user != null
        ? AccountMode.signedIn
        : (startAsGuest ? AccountMode.guest : AccountMode.signedOut);
    if (user != null) await _load(user!);
    AppState.instance.addListener(_scheduleSave);
    _sub = _auth.authStateChanges().listen((u) async {
      if (u?.uid == user?.uid) return;
      user = u;
      if (u != null) {
        mode = AccountMode.signedIn;
        await _load(u);
      } else if (mode == AccountMode.signedIn) {
        mode = AccountMode.signedOut;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void continueAsGuest() {
    mode = AccountMode.guest;
    notifyListeners();
  }

  /// 둘러보기 중에 로그인 화면으로
  void showLogin() {
    mode = AccountMode.signedOut;
    notifyListeners();
  }

  Future<String?> signUp(String email, String password) => _run(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    user = cred.user;
    mode = AccountMode.signedIn;
    await _save(); // 둘러보며 입력한 내용을 새 계정에 담는다
  });

  Future<String?> signIn(String email, String password) => _run(() async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    user = cred.user;
    mode = AccountMode.signedIn;
    await _load(user!);
  });

  Future<String?> resetPassword(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() async {
    _saveTimer?.cancel();
    await _save();
    await _auth.signOut();
    user = null;
    mode = AccountMode.signedOut;
    lastSaved = null;
    _applying = true;
    AppState.instance.resetAll(); // 다음 사람이 이전 정보를 보지 않게
    _applying = false;
    notifyListeners();
  }

  /// 실패하면 사용자에게 보여줄 문장, 성공하면 null
  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e.code);
    } catch (e) {
      debugPrint('계정 처리 실패: $e');
      return '잠시 후 다시 시도해 주세요. (네트워크 또는 서버 오류)';
    }
  }

  static String _authMessage(String code) => switch (code) {
    'invalid-email' => '이메일 형식이 올바르지 않아요.',
    'email-already-in-use' => '이미 가입된 이메일이에요. 로그인해 주세요.',
    'weak-password' => '비밀번호는 6자 이상으로 정해 주세요.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => '이메일 또는 비밀번호가 맞지 않아요.',
    'too-many-requests' => '시도가 너무 많아요. 잠시 후 다시 해 주세요.',
    'network-request-failed' => '인터넷 연결을 확인해 주세요.',
    'operation-not-allowed' => '이메일 로그인이 아직 켜져 있지 않아요. (관리자 설정 필요)',
    _ => '로그인에 실패했어요. ($code)',
  };

  Future<void> _load(User u) async {
    try {
      final snap = await _doc(u.uid).get();
      final data = snap.data();
      if (data == null) {
        await _save(); // 처음 로그인: 지금 내용으로 새로 만든다
        return;
      }
      final vendors = await Repos.vendor.demoVendors();
      _applying = true;
      UserDataCodec.apply(AppState.instance, data, vendors);
      _applying = false;
      syncError = null;
    } catch (e) {
      _applying = false;
      debugPrint('내 정보 불러오기 실패: $e');
      syncError = '저장된 정보를 불러오지 못했어요.';
    }
    notifyListeners();
  }

  void _scheduleSave() {
    if (_applying || mode != AccountMode.signedIn) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    final u = user;
    if (u == null) return;
    try {
      await _doc(u.uid).set({
        ...UserDataCodec.encode(AppState.instance),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      lastSaved = DateTime.now();
      syncError = null;
    } catch (e) {
      debugPrint('내 정보 저장 실패: $e');
      syncError = '저장하지 못했어요. 인터넷 연결을 확인해 주세요.';
    }
    notifyListeners();
  }
}
