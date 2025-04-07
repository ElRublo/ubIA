import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_app/models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();
  
  // Get user's chats
  Stream<List<Chat>> getUserChats() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('chats')
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Chat.fromMap(doc.data())).toList();
    });
  }
  
  // Create a new chat
  Future<Chat> createChat(String initialMessage) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw 'User not authenticated';
    }
    
    final chatId = _uuid.v4();
    final now = DateTime.now();
    
    final chat = Chat(
      id: chatId,
      title: initialMessage.length > 30 
          ? '${initialMessage.substring(0, 30)}...' 
          : initialMessage,
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );
    
    await _firestore.collection('chats').doc(chatId).set(chat.toMap());
    
    // Add initial user message
    await addMessage(chatId, initialMessage, true);
    
    // Add AI response (in a real app, this would come from your AI service)
    await addMessage(
      chatId, 
      "Hello! I'm your AI assistant. How can I help you today?", 
      false
    );
    
    return chat;
  }
  
  // Get messages for a specific chat
  Stream<List<Message>> getChatMessages(String chatId) {
    return _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList();
    });
  }
  
  // Add a message to a chat
  Future<Message> addMessage(String chatId, String content, bool isUser) async {
    final messageId = _uuid.v4();
    final now = DateTime.now();
    
    final message = Message(
      id: messageId,
      chatId: chatId,
      content: content,
      isUser: isUser,
      timestamp: now,
    );
    
    await _firestore.collection('messages').doc(messageId).set(message.toMap());
    
    // Update the chat's updatedAt timestamp
    await _firestore.collection('chats').doc(chatId).update({
      'updatedAt': Timestamp.fromDate(now),
    });
    
    return message;
  }
  
  // Delete a chat and its messages
  Future<void> deleteChat(String chatId) async {
    // Delete the chat document
    await _firestore.collection('chats').doc(chatId).delete();
    
    // Delete all messages in the chat
    final messagesQuery = await _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in messagesQuery.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }
}

