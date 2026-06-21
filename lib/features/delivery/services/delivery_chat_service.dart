import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';
import '../models/delivery_chat_message_model.dart';

class DeliveryChatService {
  DeliveryChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String jobId) {
    return _firestore
        .collection(AppCollections.deliveryJobs)
        .doc(jobId)
        .collection('messages');
  }

  /// Streams all chat messages for a delivery job ordered by send time.
  Stream<List<DeliveryChatMessageModel>> getMessages(String jobId) {
    try {
      return _messages(jobId)
          .orderBy(AppFields.sentAt)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) =>
                    DeliveryChatMessageModel.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (error) {
      throw Exception('Failed to load delivery messages: $error');
    }
  }

  /// Sends a new message to the delivery job chat.
  Future<void> sendMessage(
    String jobId,
    DeliveryChatMessageModel message,
  ) async {
    try {
      await _messages(jobId)
          .doc(message.id.isEmpty ? _messages(jobId).doc().id : message.id)
          .set(message.toMap());
    } catch (error) {
      throw Exception('Failed to send delivery message: $error');
    }
  }
}
