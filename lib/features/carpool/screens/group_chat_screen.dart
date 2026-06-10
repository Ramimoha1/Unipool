import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:unipool/core/constants.dart';
import '../models/carpool_request_model.dart';
import '../models/carpool_group_model.dart';
import '../models/chat_message_model.dart';
import '../models/ride_payment_model.dart';
import '../providers/chat_provider.dart';
import '../services/carpool_service.dart';
import '../services/chat_service.dart';
import '../services/payment_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/payment_banner.dart';
import '../widgets/ride_status_badge.dart';
import 'payment_screen.dart';
import 'report_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.requestId,
    required this.groupId,
  });

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
  bool _uploadingQr = false;
  bool _endingRide = false;

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
    final senderName = await _resolveSenderName(
      currentUser.uid,
      currentUser.displayName,
      currentUser.email,
    );
    await _chatService.sendMessage(
      widget.groupId,
      ChatMessageModel(
        id: '',
        senderId: currentUser.uid,
        senderName: senderName,
        content: content,
        sentAt: DateTime.now(),
      ),
    );
    _messageController.clear();
  }

  Future<_RideQrInfo> _loadRideQrInfo(
    CarpoolGroupModel? group,
    String creatorId,
  ) async {
    final bookedByUserId =
        (group?.driverId.isNotEmpty ?? false) ? group!.driverId : creatorId;

    final userDoc = await FirebaseFirestore.instance
        .collection(AppCollections.users)
        .doc(bookedByUserId)
        .get();
    final userData = userDoc.data();
    final qrCodeUrl =
        (userData?[AppFields.userQrCodeUrl] as String?) ??
        (userData?[AppFields.userQrCodeUrlSnake] as String?) ??
        '';
    return _RideQrInfo(bookedByUserId: bookedByUserId, qrCodeUrl: qrCodeUrl);
  }

  Future<void> _uploadQrCode() async {
    if (_uploadingQr) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _uploadingQr = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storageRef = FirebaseStorage.instance.ref().child(
        'user_qr_codes/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await storageRef.putData(bytes);
      } else {
        await storageRef.putFile(io.File(picked.path));
      }
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection(AppCollections.users)
          .doc(uid)
          .update({AppFields.userQrCodeUrlSnake: downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code updated.')),
        );
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingQr = false);
      }
    }
  }

  Future<String> _resolveSenderName(
    String userId,
    String? displayName,
    String? email,
  ) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(AppCollections.users)
          .doc(userId)
          .get();
      final userData = userDoc.data();
      final fullName = (userData?[AppFields.userFullName] as String?)?.trim();
      if (fullName != null && fullName.isNotEmpty) {
        return fullName;
      }
    } catch (_) {
      // Fall back to auth data when the profile document is unavailable.
    }

    final authName = displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      return authName;
    }

    final emailName = email?.trim();
    if (emailName != null && emailName.isNotEmpty) {
      return emailName;
    }

    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Chat')),
      body: FutureBuilder<CarpoolRequestModel>(
        future: _carpoolService.getRequestById(widget.requestId).first,
        builder: (context, requestSnapshot) {
          if (!requestSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final request = requestSnapshot.data!;
          final isAdmin = request.creatorId == currentUid;

          return FutureBuilder<CarpoolGroupModel?>(
            future: _carpoolService.getGroupByRequestId(widget.requestId),
            builder: (context, groupSnapshot) {
              final group = groupSnapshot.data;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${request.originLabel} -> ${request.destinationLabel}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            RideStatusBadge(status: request.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const PaymentBanner(
                          message: 'Ride group chat is active.',
                        ),
                        FutureBuilder<_RideQrInfo>(
                          future: _loadRideQrInfo(group, request.creatorId),
                          builder: (context, qrSnapshot) {
                            if (qrSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }

                            final qrInfo = qrSnapshot.data;
                            if (qrInfo == null) {
                              return const SizedBox.shrink();
                            }

                            final canUpload =
                                currentUid == request.creatorId ||
                                currentUid == qrInfo.bookedByUserId;
                            final hasQr = qrInfo.qrCodeUrl.isNotEmpty;

                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Card(
                                elevation: 0,
                                color: const Color(0xFFF8FBFF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ride QR Code',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        group?.driverId.isNotEmpty == true
                                            ? 'Uploaded by driver'
                                            : 'Uploaded by creator',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const SizedBox(height: 8),
                                      if (hasQr)
                                        Image.network(
                                          qrInfo.qrCodeUrl,
                                          height: 180,
                                          fit: BoxFit.contain,
                                        )
                                      else
                                        const Text('No QR code uploaded yet.'),
                                      if (canUpload) ...[
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: _uploadingQr
                                              ? null
                                              : _uploadQrCode,
                                          icon: _uploadingQr
                                              ? const SizedBox(
                                                  height: 16,
                                                  width: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(Icons.upload),
                                          label: Text(
                                            hasQr ? 'Update QR' : 'Add QR',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        FutureBuilder<RidePaymentModel?>(
                          future: _paymentService.getPayment(widget.requestId),
                          builder: (context, paymentSnapshot) {
                            final payment = paymentSnapshot.data;
                            if (payment == null || payment.qrCodeUrl.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Card(
                                elevation: 0,
                                color: const Color(0xFFF8FBFF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ride Payment QR',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Image.network(
                                        payment.qrCodeUrl,
                                        height: 180,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Scan this code to complete the ride payment.',
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (request.status == CarpoolRequestStatuses.inProgress &&
                            isAdmin) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _endingRide
                                  ? null
                                  : () async {
                                      setState(() => _endingRide = true);
                                      try {
                                        await _paymentService.triggerPayment(
                                          widget.requestId,
                                        );
                                        await _carpoolService.updateRequestStatus(
                                          widget.requestId,
                                          CarpoolRequestStatuses.completed,
                                        );
                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PaymentScreen(
                                              requestId: widget.requestId,
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _endingRide = false);
                                        }
                                      }
                                    },
                              child: _endingRide
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('End Ride'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        if (chatProvider.isLoading &&
                            chatProvider.messages.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: chatProvider.messages.length,
                          itemBuilder: (context, index) {
                            final message = chatProvider.messages[index];
                            return MessageBubble(
                              message: message,
                              isMine: message.senderId == currentUid,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReportScreen(
                                requestId: widget.requestId,
                                groupId: widget.groupId,
                              ),
                            ),
                          ),
                          child: const Text('Report'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _RideQrInfo {
  const _RideQrInfo({required this.bookedByUserId, required this.qrCodeUrl});

  final String bookedByUserId;
  final String qrCodeUrl;
}
