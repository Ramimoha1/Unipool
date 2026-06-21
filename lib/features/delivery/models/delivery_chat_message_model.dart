import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unipool/core/constants.dart';

class DeliveryChatMessageModel {
  const DeliveryChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime sentAt;

  factory DeliveryChatMessageModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return DeliveryChatMessageModel(
      id: id,
      senderId: map[AppFields.senderId] as String? ?? '',
      senderName: map[AppFields.senderName] as String? ?? '',
      content: map[AppFields.content] as String? ?? '',
      sentAt:
          (map[AppFields.sentAt] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      AppFields.senderId: senderId,
      AppFields.senderName: senderName,
      AppFields.content: content,
      AppFields.sentAt: Timestamp.fromDate(sentAt),
    };
  }

  DeliveryChatMessageModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? sentAt,
  }) {
    return DeliveryChatMessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}
