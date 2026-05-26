import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';
import '../models/chat_message_model.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String groupId) {
    return _firestore.collection(AppCollections.carpoolGroups).doc(groupId).collection('messages');
  }

  /// Streams all chat messages for a carpool group ordered by send time.
  Stream<List<ChatMessageModel>> getMessages(String groupId) {
    try {
      return _messages(groupId).orderBy(AppFields.sentAt).snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (error) {
      throw Exception('Failed to load messages: $error');
    }
  }

  /// Sends a new message to the group chat.
  Future<void> sendMessage(String groupId, ChatMessageModel message) async {
    try {
      await _messages(groupId).doc(message.id.isEmpty ? _messages(groupId).doc().id : message.id).set(message.toMap());
    } catch (error) {
      throw Exception('Failed to send message: $error');
    }
  }
}