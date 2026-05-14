# Firebase Schema for Hustly

This document describes the suggested Firebase structure for the Hustly application.

## Firebase Services

- Firebase Authentication for account creation and sign-in.
- Cloud Firestore for application data.
- Firebase Storage for images, ID documents, delivery proof, and QR assets.
- Firebase Cloud Messaging for notifications.

## User Types

| User type | Description |
|-----------|-------------|
| Student requester | Creates a ride-pooling request and can act as trip admin |
| Student passenger | Joins an open ride request |
| Driver candidate | Applies to drive a trip or delivery job |
| Verified driver | Approved by admin after document review |
| Seller | Creates delivery requests and approves delivery proof |
| Admin / Moderator | Verifies drivers, handles disputes, and moderates users |

## Top-Level Collections

### `users`

Stores every account in the system.

Fields:

- `uid` string
- `fullName` string
- `email` string
- `phoneNumber` string
- `roles` array  ← single source of truth for user roles
- `studentIdNumber` string optional
- `matricNumber` string optional
- `driverLicenseNumber` string optional
- `qrCodeUrl` string optional
- `profilePhotoUrl` string optional
- `verificationStatus` string
- `isActive` bool
- `createdAt` timestamp
- `updatedAt` timestamp

Suggested `roles` values (a user can have multiple):

- `student`
- `driver_candidate`
- `verified_driver`
- `seller`
- `admin`

### `driverApplications`

Stores requests to become a verified driver.

Fields:

- `userId` string
- `status` string
- `studentCardUrl` string optional
- `driverLicenseUrl` string optional
- `vehicleInfo` map optional
  - `vehicleType` string (`car` or `motorcycle`)
  - `brand` string (e.g. `Toyota`)
  - `model` string (e.g. `Vios`)
  - `year` number (e.g. `2021`)
  - `color` string (e.g. `White`)
  - `plateNumber` string (e.g. `ABC 1234`)
- `notes` string optional
- `reviewedBy` string optional
- `reviewedAt` timestamp optional
- `createdAt` timestamp

Suggested `status` values:

- `pending`
- `approved`
- `rejected`

### `rideRequests`

Stores ride-pooling requests created by students.

Fields:

- `createdBy` string
- `requestAdminId` string
- `title` string
- `fromLocation` map
- `toLocation` map
- `pickupTime` timestamp
- `seatCountNeeded` number
- `allowedDrivers` string
- `requestType` string
- `tripStatus` string
- `qrEnabled` bool
- `isVisibleOnMap` bool
- `assignedDriverId` string optional
- `bookedByUserId` string optional
- `bookedProvider` string optional
- `fareAmount` number optional
- `createdAt` timestamp
- `updatedAt` timestamp

Suggested `requestType` values:

- `carpool`
- `grab_booking`
- `driver_assignment`

Suggested `allowedDrivers` values:

- `verified_only`
- `verified_and_unverified`

Suggested `tripStatus` values:

- `open`
- `applications_open`
- `driver_assigned`
- `booked`
- `in_progress`
- `completed`
- `cancelled`
- `disputed`

### `rideRequests/{rideRequestId}/applications`

Stores student and driver applications for a specific request.

Fields:

- `userId` string
- `appliedAs` string
- `status` string
- `message` string optional
- `createdAt` timestamp
- `updatedAt` timestamp optional

Suggested `appliedAs` values:

- `passenger`
- `driver`

Suggested `status` values:

- `pending`
- `accepted`
- `rejected`
- `withdrawn`

### `rideRequests/{rideRequestId}/messages`

Chat thread for a ride request.

Fields:

- `senderId` string
- `messageType` string
- `text` string optional
- `mediaUrl` string optional
- `createdAt` timestamp

### `rideReports`

Stores issues reported after a ride.

Fields:

- `rideRequestId` string
- `reportedBy` string
- `reportedUserId` string optional
- `reportType` string
- `description` string
- `evidenceUrls` array optional
- `status` string
- `reviewedBy` string optional
- `createdAt` timestamp
- `updatedAt` timestamp optional

### `deliveryJobs`

Stores delivery requests created by sellers.

Fields:

- `createdBy` string
- `sellerId` string
- `title` string
- `pickupLocation` map
- `deliveryStops` array
- `deliveryTime` timestamp
- `items` array
- `quantity` number
- `price` number
- `allowedDrivers` string
- `jobStatus` string
- `assignedDriverId` string optional
- `sellerApprovedDriverId` string optional
- `createdAt` timestamp
- `updatedAt` timestamp

Suggested `jobStatus` values:

- `open`
- `applications_open`
- `driver_assigned`
- `in_progress`
- `proof_pending`
- `awaiting_payment`
- `completed`
- `cancelled`
- `disputed`

### `deliveryJobs/{jobId}/applications`

Stores driver applications for a delivery job.

Fields:

- `driverId` string
- `status` string
- `notes` string optional
- `createdAt` timestamp
- `updatedAt` timestamp optional

Suggested `status` values:

- `pending`
- `approved`
- `rejected`
- `withdrawn`

### `deliveryJobs/{jobId}/messages`

Chat thread for a delivery job.

Fields:

- `senderId` string
- `messageType` string
- `text` string optional
- `mediaUrl` string optional
- `createdAt` timestamp

### `deliveryJobs/{jobId}/proofs`

Stores delivery evidence uploaded by the driver.

Fields:

- `driverId` string
- `stopIndex` number optional
- `photoUrls` array
- `notes` string optional
- `status` string
- `reviewedBy` string optional
- `reviewedAt` timestamp optional
- `createdAt` timestamp

Suggested `status` values:

- `submitted`
- `approved`
- `rejected`

### `deliveryDisputes`

Stores delivery complaints filed by sellers or admins.

Fields:

- `jobId` string
- `sellerId` string
- `driverId` string optional
- `reason` string
- `description` string
- `evidenceUrls` array optional
- `status` string
- `reviewedBy` string optional
- `createdAt` timestamp
- `updatedAt` timestamp optional

### `notifications`

Stores in-app notification records.

Fields:

- `recipientId` string
- `type` string
- `title` string
- `body` string
- `referenceId` string optional
- `isRead` bool
- `createdAt` timestamp

## Storage Paths

Suggested Firebase Storage folders:

- `profile_photos/{uid}/...`
- `verification_docs/{uid}/...`
- `ride_qr/{rideRequestId}/...`
- `delivery_proofs/{jobId}/...`
- `report_evidence/{reportId}/...`

## Admin Workflow Summary

1. A student or seller creates a request.
2. Drivers or students apply depending on the module.
3. The request owner accepts a driver or participant.
4. The chat room opens for the accepted participants.
5. The trip or delivery is completed and proof is submitted.
6. Admin reviews disputes, reports, and driver verification requests.

## Notes

- Keep request status changes atomic and driven by Firestore transactions or Cloud Functions later.
- Firestore security rules should enforce who can read open requests, who can write chat messages, and who can moderate reports.