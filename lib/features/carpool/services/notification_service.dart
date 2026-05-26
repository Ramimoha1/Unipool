import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:unipool/core/constants.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
  _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Sends a push notification to a single user through a callable Cloud Function.
  Future<void> sendFCMToUser(String userId, String title, String body) async {
    try {
      final userDoc = await _firestore.collection(AppCollections.users).doc(userId).get();
      final data = userDoc.data();
      final token = data?[AppFields.userFcmToken] as String?;
      if (token == null || token.isEmpty) {
        return;
      }

      await _functions.httpsCallable(FirebaseFunctionNames.sendFcmNotification).call(<String, dynamic>{
        'userId': userId,
        'title': title,
        'body': body,
      });
    } catch (error) {
      throw Exception('Failed to send notification: $error');
    }
  }
}