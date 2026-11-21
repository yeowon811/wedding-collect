import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/account_service.dart';

/// 첫 화면: 로그인 / 회원가입 / 로그인 없이 둘러보기 (11-21 시안 배치: 위 로고 · 이메일 아이디로 로그인 · 칸 2개 · 채우면 켜지는 로그인 버튼 · 회원가입 링크 · 비밀번호 찾기 · 둘러보기)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _signUp = false;
  bool _agree = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  AccountService get _account => AccountService.instance;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _check() {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) return '이메일을 입력해 주세요.';
    if (_password.text.length < 6) return '비밀번호는 6자 이상이에요.';
    if (_signUp && _password.text != _confirm.text) return '비밀번호 확인이 맞지 않아요.';
    if (_signUp && !_agree) return '개인정보 수집·이용에 동의해 주세요.';
    return null;
  }

  Future<void> _submit() async {
    final problem = _check();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = _signUp
        ? await _account.signUp(_email.text, _password.text)
        : await _account.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '비밀번호를 재설정할 이메일을 먼저 입력해 주세요.');
      return;
    }
    final err = await _account.resetPassword(email);
    if (!mounted) return;
    setState(() => _error = err);
    if (err == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$email 로 비밀번호 재설정 메일을 보냈어요.')));
    }
  }

  /// 로그인 칸 (시안: 흰 바탕 + 연한 테두리, 이름표 없이 안내 글자만)
  InputDecoration _box(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
        ),
      );

  /// 가운데 글자 + 양옆 선 ("이메일 아이디로 로그인")
  Widget _dividerTitle(String text) => Row(children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(text, style: TextStyle(fontSize: 15, color: AppColors.textBody)),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ]);

  /// 밑줄 친 작은 글자 버튼 (비밀번호 찾기 · 로그인 없이 둘러보기)
  Widget _underlined(String text, VoidCallback? onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        child: Text(text,
            style: TextStyle(
              fontSize: 14,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.textSecondary,
              color: AppColors.textSecondary,
            )),
      );

  @override
  Widget build(BuildContext context) {
    // 로그인 버튼은 두 칸을 다 채우면 켠다 (시안처럼 비어 있으면 회색)
    final filled = _email.text.trim().isNotEmpty && _password.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        // 왼쪽 위 집 = 로그인 없이 둘러보기 (첫 화면이라 뒤로 갈 곳이 없음)
        leading: IconButton(
          tooltip: '로그인 없이 둘러보기',
          icon: const Icon(Icons.home_outlined),
          onPressed: _busy ? null : _account.continueAsGuest,
        ),
        title: Text(_signUp ? '회원가입' : '로그인'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                // 로고 (앱 링 로고 + 이름)
                Center(
                  child: Image.asset('assets/images/brand/rings_rose.png',
                      height: 64, errorBuilder: (_, _, _) => const SizedBox(height: 64)),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text('We Connect',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.primary)),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('청년 결혼지원 통합플랫폼', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 40),
                _dividerTitle(_signUp ? '이메일로 회원가입' : '이메일 아이디로 로그인'),
                const SizedBox(height: 20),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onChanged: (_) => setState(() {}),
                  decoration: _box('아이디(이메일)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _hide,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _signUp ? null : _submit(),
                  decoration: _box(
                    _signUp ? '비밀번호 (6자 이상)' : '비밀번호',
                    suffix: IconButton(
                      tooltip: _hide ? '비밀번호 보기' : '비밀번호 숨기기',
                      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                if (_signUp) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: _hide,
                    decoration: _box('비밀번호 확인'),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _agree = !_agree),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(value: _agree, onChanged: (v) => setState(() => _agree = v ?? false)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '개인정보 수집·이용 동의 (필수)\n'
                              '이메일과 앱에 입력한 결혼 준비 정보를 계정 저장에만 써요. '
                              'AI에는 이메일·이름을 보내지 않아요.',
                              style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textBody),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(fontSize: 14, color: AppColors.warning)),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _busy || !filled ? null : _submit,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: AppColors.fill,
                      disabledForegroundColor: AppColors.textHint,
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_signUp ? '가입하고 시작하기' : '로그인'),
                  ),
                ),
                const SizedBox(height: 24),
                // 로그인 <-> 회원가입 전환 (시안: "처음 오셨나요? 회원가입")
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(_signUp ? '이미 계정이 있나요?' : 'We Connect에 처음 오셨나요?',
                        style: TextStyle(fontSize: 15, color: AppColors.textBody)),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _signUp = !_signUp;
                                _error = null;
                              }),
                      child: Text(_signUp ? '로그인' : '회원가입',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                            color: AppColors.primary,
                          )),
                    ),
                  ],
                ),
                if (!_signUp) Center(child: _underlined('비밀번호 찾기', _busy ? null : _reset)),
                Center(child: _underlined('로그인 없이 둘러보기', _busy ? null : _account.continueAsGuest)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 계정 버튼 (각 탭 오른쪽 위). 로그인 상태·저장 시각·로그아웃, 둘러보기 중이면 로그인 안내.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountService.instance;
    if (account.mode == AccountMode.unavailable) return const SizedBox.shrink();
    return IconButton(
      tooltip: '내 계정',
      // 아이콘 위치는 예전(48px 칸 가운데)과 같게 두고 왼쪽 빈칸만 없앤다: 칸 36px = 아이콘 24 + 오른쪽 12px.
      // 왼쪽의 하트·종은 각각 오른쪽 8px를 두어 아이콘 사이가 8px (11-21 사용자 요청: 계정 기준 간격)
      padding: const EdgeInsets.only(right: 12),
      constraints: const BoxConstraints(minWidth: 36, maxWidth: 36, minHeight: 48),
      // 휴대폰(안드로이드·iOS)은 테마가 버튼을 최소 48px로 넓힌다(padded tap target) → 이 줄로 끔.
      // 끄지 않으면 폰에서만 간격이 다시 넓어진다 (11-21 폰 확인)
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.standard),
      icon: const Icon(Icons.account_circle_outlined),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => ListenableBuilder(
          listenable: account,
          builder: (ctx, _) {
            final signedIn = account.mode == AccountMode.signedIn;
            final saved = account.lastSaved;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    signedIn ? '내 계정' : '둘러보는 중',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    signedIn
                        ? '${account.user?.email ?? ''}\n입력한 정보가 계정에 자동으로 저장돼요.'
                              '${saved == null ? '' : ' (마지막 저장 ${saved.hour.toString().padLeft(2, '0')}:${saved.minute.toString().padLeft(2, '0')})'}'
                        : '지금 입력한 내용은 앱을 끄면 사라져요.\n로그인하면 계정에 저장되고, 다른 기기에서도 이어서 볼 수 있어요.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textBody,
                    ),
                  ),
                  if (account.syncError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      account.syncError!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (signedIn)
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await account.signOut();
                      },
                      child: const Text('로그아웃'),
                    )
                  else
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        account.showLogin();
                      },
                      child: const Text('로그인 · 회원가입'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
