import 'dart:async';

import 'package:flutter/material.dart';
import '../models/delivery_chat_message_model.dart';
import '../services/delivery_chat_service.dart';

class DeliveryChatProvider extends ChangeNotifier {
  DeliveryChatProvider({DeliveryChatService? service})
      : _service = service ?? DeliveryChatService();

  final DeliveryChatService _service;
  StreamSubscription<List<DeliveryChatMessageModel>>? _subscription;

  List<DeliveryChatMessageModel> messages = [];
  bool isLoading = false;
  String? _jobId;

  void subscribeToJob(String jobId) {
    if (_jobId == jobId) {
      return;
    }

    _jobId = jobId;
    isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _service.getMessages(jobId).listen((items) {
      messages = items;
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> sendMessage(
    String jobId,
    DeliveryChatMessageModel message,
  ) async {
    await _service.sendMessage(jobId, message);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
