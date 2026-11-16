import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/info_badge.dart';
import '../../data/app_state.dart';
import 'agent/consult_agent.dart';
import 'agent/gemini_client.dart';
import 'chat_agent.dart';
import 'profile_setup_view.dart';

/// AI 상담: 내 정보 입력 → 첫 추천 → 질문 → (필요하면 되묻기) → 답변
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 시안을 바꿔 화면이 새로 만들어져도 대화가 남도록 보관
  static final List<ChatMessage> _messages = [];
  static ChatAgent _agent = ConsultAgent(llm: GeminiClient.instance);

  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  bool _editingProfile = false;

  AppState get _app => AppState.instance;
  bool get _needsProfile => !_app.profileDone && !_app.profileSkipped;

  /// 테스트에서 대화를 처음부터 시작할 때 사용
  static void resetConversation() {
    _messages.clear();
    _agent = ConsultAgent(llm: GeminiClient.instance);
  }

  @override
  void initState() {
    super.initState();
    if (!_needsProfile && _messages.isEmpty) _begin();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<ChatMessage> Function() task, {ChatMessage? userMessage}) async {
    if (_busy) return;
    setState(() {
      if (userMessage != null) _messages.add(userMessage);
      _busy = true;
    });
    _scrollDown();
    final answer = await task();
    if (!mounted) return;
    setState(() {
      _messages.add(answer);
      _busy = false;
    });
    _scrollDown();
  }

  /// 상담 시작 (내 정보가 있으면 첫 추천)
  void _begin() {
    _agent = ConsultAgent(llm: GeminiClient.instance);
    _run(_agent.start);
  }

  void _send(String text) {
    final q = text.trim();
    if (q.isEmpty) return;
    _input.clear();
    _run(() => _agent.reply(q), userMessage: ChatMessage(fromUser: true, text: q));
  }

  void _choose(QuickReply r) =>
      _run(() => _agent.choose(r), userMessage: ChatMessage(fromUser: true, text: r.label));

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) {
        final setup = _needsProfile || _editingProfile;
        return Scaffold(
          appBar: AppBar(
            title: const Text('AI 상담'),
            actions: [
              if (!setup)
                IconButton(
                  tooltip: '내 정보',
                  icon: Icon(Icons.person_outline, color: AppColors.primaryDark),
                  onPressed: () => setState(() => _editingProfile = true),
                ),
              if (_editingProfile)
                IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _editingProfile = false),
                ),
              const PaletteButton(),
            ],
          ),
          body: setup ? _setupView() : _chatView(),
        );
      },
    );
  }

  Widget _setupView() => ProfileSetupView(
        editing: _editingProfile,
        onDone: () {
          setState(() => _editingProfile = false);
          _messages.add(const ChatMessage(fromUser: false, text: '내 정보를 저장했어요. 새로 추천해 드릴게요.'));
          _begin();
        },
        onSkip: _editingProfile
            ? null
            : () {
                _app.skipProfile();
                _begin();
              },
      );

  Widget _chatView() {
    final summary = _app.profile.summary;
    return Column(
      children: [
        // 지금 상담 기준이 되는 내 정보
        InkWell(
          onTap: () => setState(() => _editingProfile = true),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.person_outline, size: 16, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _app.profileDone && summary.isNotEmpty ? '내 정보: $summary' : '내 정보 없음 · 필요한 정보는 대화 중에 여쭤봐요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.primaryDark),
                ),
              ),
              Text('수정', style: TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            '현재: ${_agent.name} · 숫자·자격은 앱 데이터로만 답해요 · 이름·연락처는 적지 마세요',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _messages.length + (_busy ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              }
              final m = _messages[i];
              final isLast = i == _messages.length - 1;
              return Column(
                crossAxisAlignment: m.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _Bubble(message: m),
                  if (isLast && !m.fromUser && m.quickReplies.isNotEmpty && !_busy)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final r in m.quickReplies)
                            ActionChip(
                              label: Text(r.label),
                              avatar: r.action == 'save_profile'
                                  ? const Icon(Icons.save_outlined, size: 16)
                                  : null,
                              onPressed: () => _choose(r),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: '예: 20대 청년이 신혼생활에 받을 수 있는 정책은?',
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '보내기',
                  onPressed: () => _send(_input.text),
                  icon: Icon(Icons.send_rounded, color: AppColors.primaryDark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final user = m.fromUser;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: user ? AppColors.primary : AppColors.surface,
          border: m.isQuestion ? Border.all(color: AppColors.primary.withValues(alpha: 0.5)) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.isQuestion)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InfoBadge(label: '정보 확인', icon: Icons.help_outline, color: AppColors.primaryDark),
              ),
            if (m.aiWritten)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InfoBadge(
                  label: 'Gemini가 앱 데이터로 작성',
                  icon: Icons.auto_awesome,
                  color: AppColors.primaryDark,
                ),
              ),
            if (m.basis != null && m.basis!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(m.isQuestion ? m.basis! : '기준: ${m.basis}',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
            Text(m.text, style: TextStyle(color: user ? Colors.white : AppColors.textPrimary, height: 1.45)),
            for (final c in m.cards) ...[
              const SizedBox(height: 8),
              Material(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(c.icon, color: AppColors.primaryDark),
                  title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(c.subtitle),
                  trailing: c.badge == null ? null : InfoBadge(label: c.badge!, color: AppColors.primaryDark),
                  onTap: c.open == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => c.open!())),
                ),
              ),
            ],
            if (m.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('근거: ${m.sources.join(' · ')}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
