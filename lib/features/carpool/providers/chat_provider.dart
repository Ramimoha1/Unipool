import 'dart:async';

import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({ChatService? service}) : _service = service ?? ChatService();

  final ChatService _service;
  StreamSubscription<List<ChatMessageModel>>? _subscription;

  List<ChatMessageModel> messages = [];
  bool isLoading = false;
  String? _groupId;

  void subscribeToGroup(String groupId) {
    if (_groupId == groupId) {
      return;
    }

    _groupId = groupId;
    isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _service.getMessages(groupId).listen(
      (items) {
        messages = items;
        isLoading = false;
        notifyListeners();
      },
      onError: (exception) {
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> sendMessage(String groupId, ChatMessageModel message) async {
    await _service.sendMessage(groupId, message);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
