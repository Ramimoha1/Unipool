class AppCollections {
  static const users = 'users';
  static const carpoolRequests = 'carpool_requests';
  static const carpoolApplicants = 'carpool_applicants';
  static const carpoolGroups = 'carpool_groups';
  static const ridePayments = 'ride_payments';
  static const rideReports = 'ride_reports';
}

class AppFields {
  static const id = 'id';

  static const userUid = 'uid';
  static const userFullName = 'fullName';
  static const userEmail = 'email';
  static const userPhoneNumber = 'phoneNumber';
  static const userType = 'userType';
  static const userRoles = 'roles';
  static const userQrCodeUrl = 'qrCodeUrl';
  static const userQrCodeUrlSnake = 'qr_code_url';
  static const userProfilePhotoUrl = 'profilePhotoUrl';
  static const userVerificationStatus = 'verificationStatus';
  static const userIsActive = 'isActive';
  static const userFcmToken = 'fcm_token';
  static const userRole = 'role';

  static const creatorId = 'creator_id';
  static const originLabel = 'origin_label';
  static const originLat = 'origin_lat';
  static const originLng = 'origin_lng';
  static const destinationLabel = 'destination_label';
  static const destinationLat = 'destination_lat';
  static const destinationLng = 'destination_lng';
  static const scheduledAt = 'scheduled_at';
  static const totalSeats = 'total_seats';
  static const availableSeats = 'available_seats';
  static const rideType = 'ride_type';
  static const allowUnverifiedDriver = 'allow_unverified_driver';
  static const joinMode = 'join_mode';
  static const status = 'status';
  static const createdAt = 'created_at';

  static const requestId = 'request_id';
  static const userId = 'user_id';
  static const applicantRole = 'applicant_role';
  static const appliedAt = 'applied_at';
  static const applicantStatus = 'status';

  static const adminId = 'admin_id';
  static const driverId = 'driver_id';
  static const memberIds = 'member_ids';

  static const senderId = 'sender_id';
  static const senderName = 'sender_name';
  static const content = 'content';
  static const sentAt = 'sent_at';

  static const bookedByUserId = 'booked_by_user_id';
  static const qrCodeUrl = 'qr_code_url';
  static const totalAmount = 'total_amount';
  static const splitAmount = 'split_amount';
  static const paymentStatus = 'status';
  static const confirmedBy = 'confirmed_by';

  static const reportedBy = 'reported_by';
  static const targetUserId = 'target_user_id';
  static const reason = 'reason';
  static const description = 'description';
}

class CarpoolRideTypes {
  static const grab = 'grab';
  static const studentDriver = 'student_driver';
}

class CarpoolRequestStatuses {
  static const open = 'open';
  static const confirmed = 'confirmed';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

class CarpoolApplicantRoles {
  static const passenger = 'passenger';
  static const driver = 'driver';
}

class CarpoolApplicantStatuses {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
}

class CarpoolPaymentStatuses {
  static const pending = 'pending';
  static const settled = 'settled';
}

class CarpoolReportReasons {
  static const didNotPay = 'did_not_pay';
  static const unsafeDriver = 'unsafe_driver';
  static const noShow = 'no_show';
  static const other = 'other';
}

class CarpoolReportStatuses {
  static const open = 'open';
  static const resolved = 'resolved';
}

class FirebaseFunctionNames {
  static const sendFcmNotification = 'sendFCMNotification';
}

class CarpoolJoinModes {
  static const open = 'open';
  static const approval = 'approval';
}