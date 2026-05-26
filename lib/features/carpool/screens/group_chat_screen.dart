import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../models/chat_message_model.dart';
import '../services/carpool_service.dart';
import '../services/chat_service.dart';
import '../services/payment_service.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/payment_banner.dart';
import '../widgets/ride_status_badge.dart';
import 'payment_screen.dart';
import 'report_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key, required this.requestId, required this.groupId});

  final String requestId;
  final String groupId;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _chatService = ChatService();
  final _paymentService = PaymentService();
  final _carpoolService = CarpoolService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().subscribeToGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    final currentUser = FirebaseAuth.instance.currentUser!;
    await _chatService.sendMessage(
      widget.groupId,
      ChatMessageModel(
        id: '',
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'User',
        content: content,
        sentAt: DateTime.now(),
      ),
    );
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Chat')),
      body: FutureBuilder(
        future: _carpoolService.getRequestById(widget.requestId).first,
        builder: (context, requestSnapshot) {
          if (!requestSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final request = requestSnapshot.data!;
          final isAdmin = request.creatorId == currentUid;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${request.originLabel} -> ${request.destinationLabel}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                        RideStatusBadge(status: request.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const PaymentBanner(message: 'Ride group chat is active.'),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<ChatProvider>(
                  builder: (context, chatProvider, _) {
                    if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: chatProvider.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatProvider.messages[index];
                        return MessageBubble(message: message, isMine: message.senderId == currentUid);
                      },
                    );
                  },
                ),
              ),
              if (request.status == CarpoolRequestStatuses.inProgress && isAdmin)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await _paymentService.triggerPayment(widget.requestId);
                      await _carpoolService.updateRequestStatus(widget.requestId, CarpoolRequestStatuses.completed);
                      if (mounted) {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(requestId: widget.requestId),
                          ),
                        );
                      }
                    },
                    child: const Text('Mark as Complete'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(hintText: 'Type a message...'),
                      ),
                    ),
                    IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send)),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ReportScreen(requestId: widget.requestId, groupId: widget.groupId)),
                      ),
                      child: const Text('Report'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}