import 'package:flutter/material.dart';
import 'package:chat_app/services/chat_service.dart';
import 'package:chat_app/models/chat_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() {
      _isSending = true;
    });

    try {
      await _chatService.addMessage(widget.chatId, message, true);
      
      final userId = _auth.currentUser?.uid ?? '';
      
      final encodedMessage = Uri.encodeComponent(message);
      final url = Uri.parse(
        'https://webhookn8ntest.ubicuo.mx/webhook/ubiIA?message=$encodedMessage&user_id=$userId'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final aiResponse = jsonResponse['output'] as String;
        
        await _chatService.addMessage(
          widget.chatId,
          aiResponse,
          false,
        );
      } else {
        print('Error del servicio de agente inteligente: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        await _chatService.addMessage(
          widget.chatId,
          "Lo siento, tengo problemas para conectarme a mi cerebro ahora mismo. Inténtalo de nuevo más tarde.",
          false,
        );
      }
    } catch (e) {
      print('Excepción al llamar al servicio de agente inteligente: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enviando el mensaje: ${e.toString()}')),
        );
      }
      
      await _chatService.addMessage(
        widget.chatId,
        "Lo siento, se produjo un error. Inténtalo de nuevo más tarde.",
        false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  final errorMessage = snapshot.error.toString();
                  if (errorMessage.contains('El index se está construyendo')) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Configurando tu chat...',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Esto puede tardar unos minutos. Espere o inténtelo de nuevo más tarde.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  
                  // For other errors
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Sin mensajes aún...'),
                  );
                }
                
                _scrollToBottom();
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message.content,
                      isUser: message.isUser,
                      timestamp: message.timestamp,
                    );
                  },
                );
              },
            ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isSending ? null : _sendMessage,
                  mini: true,
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  const _MessageBubble({
    required this.message,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: isUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
                children: _parseMessage(message, isUser, context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: isUser
                    ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                    : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  List<TextSpan> _parseMessage(String message, bool isUser, BuildContext context) {
    final defaultStyle = TextStyle(
      color: isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 16,
    );

    final boldStyle = defaultStyle.copyWith(fontWeight: FontWeight.bold);
    final italicStyle = defaultStyle.copyWith(fontStyle: FontStyle.italic);
    final titleStyle = defaultStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600);

    List<TextSpan> spans = [];

    final lines = message.split('\n');

    for (var line in lines) {
      if (line.trim().isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      if (line.startsWith('### ')) {
        spans.add(TextSpan(text: '${line.substring(4)}\n', style: titleStyle));
        continue;
      }

      final regex = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*)');
      final matches = regex.allMatches(line);

      int lastEnd = 0;
      for (final match in matches) {
        if (match.start > lastEnd) {
          spans.add(TextSpan(
            text: line.substring(lastEnd, match.start),
            style: defaultStyle,
          ));
        }

        if (match.group(2) != null) {
          spans.add(TextSpan(text: match.group(2), style: boldStyle));
        }
        else if (match.group(3) != null) {
          spans.add(TextSpan(text: match.group(3), style: italicStyle));
        }

        lastEnd = match.end;
      }

      if (lastEnd < line.length) {
        spans.add(TextSpan(text: line.substring(lastEnd), style: defaultStyle));
      }

      spans.add(const TextSpan(text: '\n'));
    }

    return spans;
  }
}
