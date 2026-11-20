import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/login_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/info_badge.dart';
import '../../data/app_state.dart';
import '../../data/models/user_profile.dart';
import 'agent/consult_agent.dart';
import 'agent/gemini_client.dart';
import 'answer/answer_blocks.dart';
import 'answer/answer_view.dart';
import '../../core/widgets/inputs.dart';
import 'chat_agent.dart';
import 'chat_card_link.dart';
import 'profile_setup_view.dart';

/// AI 상담: 내 정보 입력 → 첫 추천 → 질문 → (필요하면 되묻기) → 답변
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 대화는 AppState에 두어 계정에 저장한다. 에이전트는 대화가 새로 시작될 때(chatEpoch)마다 새로 만든다.
  static ChatAgent _agent = ConsultAgent(llm: GeminiClient.instance);
  static int _agentEpoch = -1;

  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  bool _editingProfile = false;

  AppState get _app => AppState.instance;
  bool get _needsProfile => !_app.profileDone && !_app.profileSkipped;
  List<ChatMessage> get _messages => _app.chat;

  /// 대화가 새로 시작됐으면(로그아웃·새 상담·다른 계정 불러오기) 에이전트도 새로
  void _syncAgent() {
    if (_agentEpoch != _app.chatEpoch) {
      _agent = ConsultAgent(llm: GeminiClient.instance);
      _agentEpoch = _app.chatEpoch;
      // 이미 대화가 있으면(이어서 하기·다시 들어옴) 최근 대화 기억을 되살린다
      if (_app.chat.isNotEmpty) _agent.restore(_app.chat);
    }
  }


  @override
  void initState() {
    super.initState();
    _syncAgent();
    if (!_needsProfile && _messages.isEmpty && !_app.chatFromSaved) _begin();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<ChatMessage> Function() task, {ChatMessage? userMessage}) async {
    if (_busy) return;
    if (userMessage != null) _app.addChat(userMessage);
    setState(() => _busy = true);
    _scrollDown();
    final answer = await task();
    _agent.step.value = null;
    if (!mounted) return;
    _app.addChat(answer);
    setState(() => _busy = false);
    _scrollDown();
  }

  /// 상담 시작 (내 정보가 있으면 첫 추천)
  void _begin() {
    _agent = ConsultAgent(llm: GeminiClient.instance);
    _agentEpoch = _app.chatEpoch;
    _run(_agent.start);
  }

  /// 새 상담: 지난 대화를 지우고 처음부터
  Future<void> _newChat() async {
    if (_messages.length > 1) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('새 상담을 시작할까요?'),
          content: const Text('지금까지의 대화는 지워져요. 내 정보는 그대로 남아요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새로 시작')),
          ],
        ),
      );
      if (ok != true) return;
    }
    _app.clearChat();
    if (!_needsProfile) _begin();
  }

  /// 키보드 엔터: 한글 조합 중(마지막 글자가 아직 확정 전)이면 보내지 않는다 (중복 전송·글자 잘림 방지)
  void _submitFromKeyboard(String text) {
    if (!_input.value.composing.isCollapsed) return;
    _send(text);
  }

  void _send(String text) {
    final q = text.trim();
    if (q.isEmpty) return;
    _input.clear();
    _run(() => _agent.reply(q), userMessage: ChatMessage(fromUser: true, text: q));
  }

  Future<void> _choose(QuickReply r) async {
    if (r.action == 'input') {
      final filled = await _askInput(r.slot!);
      if (filled == null || !mounted) return;
      r = filled;
    }
    _run(() => _agent.choose(r), userMessage: ChatMessage(fromUser: true, text: r.label));
  }

  /// 되묻기의 [직접 입력]·[날짜 고르기]: 값을 받아 선택 버튼처럼 넘긴다
  Future<QuickReply?> _askInput(String slot) async {
    if (slot == 'weddingDate') {
      final today = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: today.add(const Duration(days: 180)),
        firstDate: today,
        lastDate: today.add(const Duration(days: 365 * 3)),
        helpText: '예식일을 골라 주세요',
      );
      if (picked == null) return null;
      final days = DateTime(picked.year, picked.month, picked.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      return QuickReply('예식일 ${formatDate(picked)}', slot: slot, value: days);
    }
    final (title, unit, min, max) = switch (slot) {
      'age' => ('만 나이', '세', 19, 60),
      'guests' => ('하객 수', '명', 10, 2000),
      'budget' => ('총예산', '만원', 100, 100000),
      _ => ('혼인 연차', '년', 1, 30),
    };
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: unit, hintText: '$min~$max'),
          onSubmitted: (_) => Navigator.pop(d, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('확인')),
        ],
      ),
    );
    final n = int.tryParse(c.text);
    if (ok != true || n == null) return null;
    final v = n.clamp(min, max);
    return switch (slot) {
      'age' => QuickReply('만 $v세', slot: slot, value: [v]),
      'budget' => QuickReply(formatManwon(v), slot: slot, value: v),
      'marriedYears' => QuickReply('혼인 $v년차', slot: slot, value: v),
      _ => QuickReply('$v$unit', slot: slot, value: v),
    };
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
    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) {
        final setup = _needsProfile || _editingProfile;
        final resume = !setup && _app.chatFromSaved;
        _syncAgent();
        // 다른 계정을 불러와 대화가 비었으면 새로 시작
        if (!setup && !resume && !_busy && _messages.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_busy && _messages.isEmpty && !_needsProfile) _begin();
          });
        }
        return Scaffold(
          // 대화 영역은 아주 연한 회색 위에 흰 말풍선 (시안 A)
          backgroundColor: setup ? null : const Color(0xFFF9FAFB),
          appBar: AppBar(
            title: const Text('AI 상담'),
            // 헤더 오른쪽: 새 상담 · 내 계정 (내 정보는 아래 조건 줄의 [수정]으로, 2026-11-20 Red Team P0)
            actions: [
              if (!setup && !resume)
                IconButton(
                  tooltip: '새 상담 시작',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _newChat,
                ),
              const AccountButton(),
              if (_editingProfile)
                IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _editingProfile = false),
                ),
            ],
          ),
          body: setup ? _setupView() : (resume ? _resumeView() : _chatView()),
        );
      },
    );
  }

  Widget _setupView() => ProfileSetupView(
        editing: _editingProfile,
        onDone: () {
          // 처음 입력할 때는 인사말만, 대화 중에 고쳤을 때만 저장 안내를 남긴다
          if (_editingProfile) {
            _app.addChat(const ChatMessage(fromUser: false, text: '내 정보를 저장했어요. 바뀐 정보로 답해 드릴게요.'));
          }
          setState(() => _editingProfile = false);
          _begin();
        },
        onSkip: _editingProfile
            ? null
            : () {
                _app.skipProfile();
                _begin();
              },
      );

  /// 저장된 대화가 있을 때: 이어서 하기 / 새로 시작하기
  Widget _resumeView() {
    final at = _app.chatUpdatedAt;
    final lastQuestion = _messages.lastWhere((m) => m.fromUser, orElse: () => _messages.last).text;
    final when = at == null ? '' : '${at.month}월 ${at.day}일 ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Text('지난 상담이 있어요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('이어서 하거나 새로 시작할 수 있어요.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${when.isEmpty ? '' : '$when · '}메시지 ${_messages.length}개',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('"$lastQuestion"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textPrimary)),
              ]),
            ),
          ],
        ),
      ),
      BottomActionBar(children: [
        ActionPair(
          secondary: OutlinedButton(
            onPressed: () {
              _app.clearChat();
              _begin();
            },
            child: const Text('새로 시작하기'),
          ),
          primary: FilledButton(
            onPressed: () {
              _app.resumeChat();
              _agent.restore(_app.chat);
              _app.addChat(const ChatMessage(
                fromUser: false,
                text: '지난 상담을 이어서 할게요. 궁금한 걸 물어보세요.',
              ));
              _scrollDown();
            },
            child: const Text('이어서 하기'),
          ),
        ),
      ]),
    ]);
  }

  Widget _chatView() {
    // 데스크톱에서도 읽기 편한 폭 (넓은 화면은 가운데 760px, 2026-11-20 Red Team P0)
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _chatColumn(),
      ),
    );
  }

  Widget _chatColumn() {
    return Column(
      children: [
        // 지금 상담 기준이 되는 내 정보: 대화에서 반영한 값도 바로 보이는 조건 칩 (✕로 하나씩 지움)
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: ProfileChipsBar(
            onEdit: () => setState(() => _editingProfile = true),
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            // 아래 여유: 마지막 답의 후속 칩·펼친 기록이 입력창에 붙지 않게
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: _messages.length + (_busy ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length) return _ProgressSteps(step: _agent.step);
              final m = _messages[i];
              final isLast = i == _messages.length - 1;
              return Column(
                crossAxisAlignment: m.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _Bubble(
                    message: m,
                    interactive: isLast && !_busy,
                    onRefine: (set, remove, label) => _choose(QuickReply(label,
                        action: 'refine', value: <String, Object?>{'set': set, 'remove': remove})),
                  ),
                  if (isLast && !m.fromUser && m.quickReplies.isNotEmpty && !_busy)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final r in m.quickReplies)
                            ActionChip(
                              label: Text(r.label),
                              avatar: switch (r.action) {
                                'save_profile' => Icon(Icons.bookmark_add_outlined, size: 16, color: AppColors.primary),
                                'more' => Icon(Icons.expand_more, size: 16, color: AppColors.primary),
                                'input' => Icon(
                                    r.slot == 'weddingDate' ? Icons.calendar_month_outlined : Icons.edit_outlined,
                                    size: 16,
                                    color: AppColors.primary),
                                _ => null,
                              },
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFD1D6DB)),
                              labelStyle: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
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
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _submitFromKeyboard,
                      decoration: const InputDecoration(
                        hintText: '궁금한 걸 물어보세요 (이름·연락처는 적지 마세요)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: FilledButton(
                      onPressed: () => _send(_input.text),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(46, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, size: 22, semanticLabel: '보내기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 예전 글 답의 복사용 글 (블록이 없는 저장된 대화)
String _plainOld(ChatMessage m) => [
      m.text,
      for (final c in m.cards) '${c.title} — ${c.subtitle}${c.badge == null ? '' : ' (${c.badge})'}',
      if (m.sources.isNotEmpty) '출처: ${m.sources.join(' · ')}',
    ].where((l) => l.trim().isNotEmpty).join('\n');

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.interactive = false, this.onRefine});

  final ChatMessage message;
  final bool interactive;
  final void Function(Map<String, Object?> set, List<String> remove, String label)? onRefine;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final user = m.fromUser;
    final width = MediaQuery.of(context).size.width;
    if (user) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: SelectionArea(
              child: Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5))),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width * 0.88),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: m.isQuestion ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        // 답 내용을 끌어서(데스크톱)·길게 눌러서(휴대폰) 고르고 복사할 수 있게 (2026-11-20)
        child: SelectionArea(
            child: m.blocks.isNotEmpty
            ? AnswerView(
                blocks: m.blocks,
                interactive: interactive,
                onRefine: onRefine,
                footer: CopyAnswerButton(text: m.blocks.copyText),
              )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.isQuestion || m.aiWritten)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoBadge(
                  label: m.isQuestion ? '정보 확인' : 'Gemini가 앱 데이터로 작성',
                  color: AppColors.primary,
                  background: AppColors.primarySoft,
                ),
              ),
            if (m.basis != null && m.basis!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(m.isQuestion ? m.basis! : '기준 · ${m.basis}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            Text(m.text, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.6)),
            for (final c in m.cards) ...[
              const SizedBox(height: 8),
              _ResultCard(card: c),
            ],
            if (m.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('출처 · ${m.sources.join(' · ')}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            if (m.trace.isNotEmpty) _WhyThisAnswer(trace: m.trace),
            Align(alignment: Alignment.centerRight, child: CopyAnswerButton(text: _plainOld(m))),
          ],
        )),
      ),
    );
  }
}

/// 답변 안의 결과 카드 (정책·예식장·업체). 누르면 상세 화면
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.card});

  final ChatCard card;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final likely = c.badge == '해당 가능성 높음' || c.badge == '하객 수용' || c.badge == '예산 안';
    return Material(
      color: AppColors.fill.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: c.open == null && c.ref == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => c.open?.call() ?? ChatCardLink(ref: c.ref!))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(c.icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(c.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (c.badge != null) ...[
                const SizedBox(width: 8),
                InfoBadge(
                  label: c.badge!,
                  color: likely ? AppColors.success : AppColors.textBody,
                  background: likely ? AppColors.successSoft : Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 답변을 만드는 동안 보여주는 진행 단계: 질문 이해 → 데이터 조회 → 답변 작성
class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.step});

  final ValueNotifier<AgentStep?> step;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AgentStep?>(
      valueListenable: step,
      builder: (context, current, _) {
        final now = current ?? AgentStep.understand;
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in AgentStep.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: s.index < now.index
                            ? Icon(Icons.check_circle, size: 16, color: AppColors.success)
                            : s == now
                                ? CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
                                : Icon(Icons.circle_outlined, size: 16, color: AppColors.border),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: s == now ? FontWeight.w700 : FontWeight.w500,
                          color: s.index > now.index ? AppColors.textHint : AppColors.textPrimary,
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "왜 이렇게 답했나요?" — 눌러서 질문 이해·사용한 정보·데이터 조회·답변 작성 과정을 펼친다
class _WhyThisAnswer extends StatefulWidget {
  const _WhyThisAnswer({required this.trace});

  final List<String> trace;

  @override
  State<_WhyThisAnswer> createState() => _WhyThisAnswerState();
}

class _WhyThisAnswerState extends State<_WhyThisAnswer> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.manage_search_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text('왜 이렇게 답했나요?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
              Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.primary),
            ]),
          ),
        ),
        if (_open)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.trace.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == widget.trace.length - 1 ? 0 : 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(widget.trace[i],
                            style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textBody)),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// AI 상담 위쪽 조건 줄: 지금 상담에 쓰는 내 정보를 칩으로 (대화·버튼으로 반영한 값도 바로 보임).
/// 칩의 ✕는 그 항목만 지우고, [수정]은 내 정보 화면을 연다. (2026-11-20 Red Team P0)
class ProfileChipsBar extends StatelessWidget {
  const ProfileChipsBar({super.key, required this.onEdit});

  final VoidCallback onEdit;

  /// (지울 때 쓰는 이름, 아이콘, 글자)
  static List<(String, IconData, String)> itemsOf(UserProfile p) => [
        if (p.sido != null) ('region', Icons.place_outlined, p.regionLabel!),
        if (p.age != null) ('age', Icons.person_outline, p.ageLabel),
        if (p.weddingDate != null)
          ('date', Icons.event_outlined, '예식 ${p.weddingDate!.month}/${p.weddingDate!.day}'),
        if (p.guests != null) ('guests', Icons.groups_outlined, '하객 ${p.guests}명'),
        if (p.budget != null) ('budget', Icons.payments_outlined, '총예산 ${formatManwon(p.budget!)}'),
        if (p.homeless != null) ('homeless', Icons.home_outlined, p.homeless! ? '무주택' : '집 있음'),
      ];

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final items = itemsOf(app.profile);
    final edit = ActionChip(
      avatar: Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
      label: Text(items.isEmpty ? '정보 입력' : '수정'),
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
      backgroundColor: Colors.white,
      side: BorderSide(color: AppColors.border),
      visualDensity: VisualDensity.compact,
      onPressed: onEdit,
    );
    if (items.isEmpty) {
      return Row(children: [
        Expanded(
          child: Text('내 정보 없음 · 필요한 정보는 대화 중에 여쭤봐요',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.textBody)),
        ),
        const SizedBox(width: 8),
        edit,
      ]);
    }
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (key, icon, label) in items)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                avatar: Icon(icon, size: 16, color: AppColors.textSecondary),
                label: Text(label),
                labelStyle: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                backgroundColor: AppColors.fill,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                deleteIcon: const Icon(Icons.close, size: 15),
                deleteButtonTooltipMessage: '$label 지우기',
                onDeleted: () => app.clearProfileField(key),
              ),
            ),
          edit,
        ],
      ),
    );
  }
}
