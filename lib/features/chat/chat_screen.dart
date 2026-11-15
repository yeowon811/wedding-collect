import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/info_badge.dart';
import 'chat_agent.dart';
import 'local_data_agent.dart';

/// AI 상담: 질문 → 에이전트가 앱 데이터를 조회해 정리 → 결과 카드와 출처
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 시안을 바꿔 화면이 새로 만들어져도 대화가 남도록 보관
  static final List<ChatMessage> _messages = [];
  final ChatAgent _agent = LocalDataAgent();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  static const _suggestions = [
    '뭐부터 해야 해?',
    '공공예식장 알려줘',
    '받을 수 있는 정책 있어?',
    '예산 안에서 드레스 추천해줘',
    '예산 어떻게 나누면 돼?',
  ];

  @override
  void initState() {
    super.initState();
    if (_messages.isEmpty) {
      _messages.add(const ChatMessage(
        fromUser: false,
        text: '안녕하세요! 결혼 준비를 도와드릴게요.\n'
            '예식장, 지원 정책, 업체, 예산, 일정에 대해 물어보세요.',
      ));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: q));
      _busy = true;
    });
    _scrollDown();
    final answer = await _agent.reply(q);
    if (!mounted) return;
    setState(() {
      _messages.add(answer);
      _busy = false;
    });
    _scrollDown();
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 상담'),
        actions: const [PaletteButton()],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.placeholder.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '현재: ${_agent.name}. 앱에 등록된 데이터로만 답해요. 생성형 AI 연결은 다음 단계예요.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                      child: SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }
                return _Bubble(message: _messages[i]);
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(label: Text(s), onPressed: () => _send(s)),
                  ),
              ],
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
                        hintText: '예: 서울 공공예식장 알려줘',
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
                    onPressed: () => _send(_input.text),
                    icon: Icon(Icons.send_rounded, color: AppColors.primaryDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: user ? AppColors.primary : AppColors.surface,
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
              Text(m.text,
                  style: TextStyle(color: user ? Colors.white : AppColors.textPrimary, height: 1.45)),
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
                    trailing: c.badge == null
                        ? null
                        : InfoBadge(label: c.badge!, color: AppColors.primaryDark),
                    onTap: c.open == null
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => c.open!())),
                  ),
                ),
              ],
              if (m.sources.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('근거: ${m.sources.join(' · ')}',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
