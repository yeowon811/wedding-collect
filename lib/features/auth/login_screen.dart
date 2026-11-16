import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/inputs.dart';
import '../../data/account_service.dart';

/// 첫 화면: 로그인 / 회원가입 / 로그인 없이 둘러보기
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                children: [
                  Text(
                    '결혼 준비,\n한 곳에서 정리해요',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '공공예식장·지원 정책·업체를 찾고, 준비 항목과 예산을 기록해요.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),
                  ChoiceRow<bool>(
                    options: const [(false, '로그인'), (true, '회원가입')],
                    value: _signUp,
                    onChanged: (v) => setState(() {
                      _signUp = v;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 24),
                  FormSection(
                    title: '이메일',
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        hintText: 'name@example.com',
                      ),
                    ),
                  ),
                  FormSection(
                    title: '비밀번호',
                    child: TextField(
                      controller: _password,
                      obscureText: _hide,
                      decoration: InputDecoration(
                        hintText: '6자 이상',
                        suffixIcon: IconButton(
                          tooltip: _hide ? '비밀번호 보기' : '비밀번호 숨기기',
                          icon: Icon(
                            _hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      onSubmitted: (_) => _signUp ? null : _submit(),
                    ),
                  ),
                  if (_signUp) ...[
                    FormSection(
                      title: '비밀번호 확인',
                      child: TextField(
                        controller: _confirm,
                        obscureText: _hide,
                        decoration: const InputDecoration(hintText: '한 번 더 입력'),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _agree = !_agree),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agree,
                            onChanged: (v) =>
                                setState(() => _agree = v ?? false),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                '개인정보 수집·이용 동의 (필수)\n'
                                '이메일과 앱에 입력한 결혼 준비 정보를 계정 저장에만 써요. '
                                'AI에는 이메일·이름을 보내지 않아요.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppColors.textBody,
                                ),
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
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                  if (!_signUp)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _reset,
                        child: const Text('비밀번호를 잊으셨나요?'),
                      ),
                    ),
                ],
              ),
            ),
            BottomActionBar(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_signUp ? '가입하고 시작하기' : '로그인'),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _account.continueAsGuest,
                  child: const Text('로그인 없이 둘러보기'),
                ),
              ],
            ),
          ],
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
