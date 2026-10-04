import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/chat_repository.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late Future<List<ChatContact>> _contacts;

  @override
  void initState() {
    super.initState();
    _contacts = _loadContacts();
  }

  Future<List<ChatContact>> _loadContacts() async {
    final result = await ref.read(chatRepositoryProvider).contacts();
    if (!result.ok || result.data == null) throw Exception(result.error ?? 'Gagal memuat kontak');
    return result.data!;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: FutureBuilder<List<ChatContact>>(
          future: _contacts,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: FilledButton.tonal(
                  onPressed: () => setState(() => _contacts = _loadContacts()),
                  child: const Text('Coba lagi'),
                ),
              );
            }
            final contacts = snapshot.data ?? const <ChatContact>[];
            if (contacts.isEmpty) return const Center(child: Text('Belum ada kontak chat.'));
            return ListView.separated(
              itemCount: contacts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(contact.name),
                  subtitle: Text(contact.subtitle ?? 'Chat'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChatConversationScreen(contact: contact)),
                  ),
                );
              },
            );
          },
        ),
      );
}

class ChatConversationScreen extends ConsumerStatefulWidget {
  const ChatConversationScreen({required this.contact, super.key});
  final ChatContact contact;

  @override
  ConsumerState<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> {
  final _controller = TextEditingController();
  late Future<List<ChatMessage>> _messages;

  @override
  void initState() {
    super.initState();
    _messages = _loadMessages();
    Future.microtask(() => ref.read(chatRepositoryProvider).markRead(widget.contact));
  }

  Future<List<ChatMessage>> _loadMessages() async {
    final result = await ref.read(chatRepositoryProvider).messages(widget.contact);
    if (!result.ok || result.data == null) throw Exception(result.error ?? 'Gagal memuat pesan');
    return result.data!;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final result = await ref.read(chatRepositoryProvider).send(widget.contact, text);
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Pesan gagal dikirim')));
      return;
    }
    _controller.clear();
    setState(() => _messages = _loadMessages());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.contact.name)),
        body: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<ChatMessage>>(
                future: _messages,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) return const Center(child: Text('Pesan belum dapat dimuat.'));
                  final messages = snapshot.data ?? const <ChatMessage>[];
                  if (messages.isEmpty) return const Center(child: Text('Belum ada pesan.'));
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final message = messages[index];
                      return Align(
                        alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Card(
                          color: message.isMine ? Theme.of(context).colorScheme.primaryContainer : null,
                          child: Padding(padding: const EdgeInsets.all(10), child: Text(message.message)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: _controller, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Tulis pesan...'))),
                    IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
