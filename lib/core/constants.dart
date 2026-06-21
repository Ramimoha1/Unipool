class AppCollections {
  static const users = 'users';
  static const carpoolRequests = 'carpool_requests';
  static const carpoolApplicants = 'carpool_applicants';
  static const carpoolGroups = 'carpool_groups';
  static const ridePayments = 'ride_payments';
  static const rideReports = 'ride_reports';

  // Delivery
  static const deliveryJobs = 'delivery_jobs';
  static const deliveryDisputes = 'delivery_disputes';
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

  // Carpool request fields
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
  static const updatedAt = 'updated_at';
  static const fare = 'fare';

  // Carpool applicant fields
  static const requestId = 'request_id';
  static const userId = 'user_id';
  static const applicantRole = 'applicant_role';
  static const appliedAt = 'applied_at';
  static const applicantStatus = 'status';

  // Carpool group fields
  static const adminId = 'admin_id';
  static const driverId = 'driver_id';
  static const memberIds = 'member_ids';

  // Chat fields (shared)
  static const senderId = 'sender_id';
  static const senderName = 'sender_name';
  static const content = 'content';
  static const sentAt = 'sent_at';
  static const messageType = 'message_type';
  static const text = 'text';
  static const mediaUrl = 'media_url';

  // Payment fields
  static const bookedByUserId = 'booked_by_user_id';
  static const qrCodeUrl = 'qr_code_url';
  static const totalAmount = 'total_amount';
  static const splitAmount = 'split_amount';
  static const paymentStatus = 'status';
  static const confirmedBy = 'confirmed_by';

  // Bank details fields (nested map on user doc)
  static const bankDetails = 'bankDetails';
  static const bankName = 'bankName';
  static const accountHolderName = 'accountHolderName';
  static const accountNumber = 'accountNumber';

  // Report fields
  static const reportedBy = 'reported_by';
  static const targetUserId = 'target_user_id';
  static const reason = 'reason';
  static const description = 'description';

  // Delivery job fields
  static const sellerId = 'seller_id';
  static const title = 'title';
  static const pickupLabel = 'pickup_label';
  static const pickupLat = 'pickup_lat';
  static const pickupLng = 'pickup_lng';
  static const deliveryStops = 'delivery_stops';
  static const deliveryTime = 'delivery_time';
  static const timeWindowStart = 'time_window_start';
  static const timeWindowEnd = 'time_window_end';
  static const items = 'items';
  static const quantity = 'quantity';
  static const price = 'price';
  static const allowedDrivers = 'allowed_drivers';
  static const jobStatus = 'job_status';
  static const assignedDriverId = 'assigned_driver_id';
  static const sellerApprovedDriverId = 'seller_approved_driver_id';

  // Delivery stop sub-fields
  static const stopLabel = 'label';
  static const stopLat = 'lat';
  static const stopLng = 'lng';

  // Delivery item sub-fields
  static const itemName = 'name';
  static const itemDescription = 'description';

  // Delivery application fields
  static const notes = 'notes';

  // Delivery proof fields
  static const stopIndex = 'stop_index';
  static const photoUrls = 'photo_urls';
  static const reviewedBy = 'reviewed_by';
  static const reviewedAt = 'reviewed_at';

  // Delivery dispute fields
  static const jobId = 'job_id';
  static const evidenceUrls = 'evidence_urls';
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
  static const awaitingPayment = 'awaiting_payment';
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

// ── Delivery constants ──────────────────────────────────────────────────

class DeliveryJobStatuses {
  static const open = 'open';
  static const applicationsOpen = 'applications_open';
  static const driverAssigned = 'driver_assigned';
  static const inProgress = 'in_progress';
  static const proofPending = 'proof_pending';
  static const awaitingPayment = 'awaiting_payment';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const disputed = 'disputed';
}

class DeliveryApplicationStatuses {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const withdrawn = 'withdrawn';
}

class DeliveryProofStatuses {
  static const submitted = 'submitted';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

class DeliveryDisputeStatuses {
  static const open = 'open';
  static const underReview = 'under_review';
  static const resolved = 'resolved';
}

class DeliveryAllowedDrivers {
  static const verifiedOnly = 'verified_only';
  static const verifiedAndUnverified = 'verified_and_unverified';
}

class ChatMessageTypes {
  static const text = 'text';
  static const image = 'image';
}