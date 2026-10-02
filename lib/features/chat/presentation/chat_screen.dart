import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/chat_models.dart';

final chatContactsProvider = FutureProvider<List<ChatContact>>((ref) async {
  final result = await ref.watch(chatRepositoryProvider).contacts();
  if (!result.ok || result.data == null) throw Exception(result.error ?? 'Gagal memuat kontak');
  return result.data!;
});

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(chatContactsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: contacts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(chatContactsProvider.future),
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final contact = items[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(contact.name),
                subtitle: Text(contact.subtitle ?? contact.type),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ChatConversationScreen(contact: contact),
                )),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ChatConversationScreen extends ConsumerStatefulWidget {
  const ChatConversationScreen({super.key, required this.contact});
  final ChatContact contact;

  @override
  ConsumerState<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> {
  final _controller = TextEditingController();
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await ref.read(chatRepositoryProvider).messages(
      type: widget.contact.type,
      targetId: widget.contact.id,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok && result.data != null) _messages = result.data!;
    });
    if (result.ok) {
      await ref.read(chatRepositoryProvider).markRead(
        type: widget.contact.type,
        targetId: widget.contact.id,
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final result = await ref.read(chatRepositoryProvider).send(
      type: widget.contact.type,
      targetId: widget.contact.id,
      message: text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.ok && result.data != null) {
      _controller.clear();
      setState(() => _messages = [..._messages, result.data!]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Gagal mengirim pesan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.contact.name)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Card(
                          color: message.isMine ? Theme.of(context).colorScheme.primaryContainer : null,
                          child: Padding(padding: const EdgeInsets.all(10), child: Text(message.message)),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(children: [
                Expanded(child: TextField(controller: _controller, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Tulis pesan'))),
                IconButton(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
