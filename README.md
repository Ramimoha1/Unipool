# Unipool

Unipool is a multi-service platform that connects **customers**, **drivers**, **students**, and **sellers** for ride-sharing and delivery services, all in one app!

---

## Table of Contents

- [Overview](#overview)
- [User Roles](#user-roles)
- [Features](#features)
- [Sprint Roadmap](#sprint-roadmap)

---

## Overview

Unipool enables:
- **Ride-hailing** — customers request rides, drivers accept and fulfill them
- **Shared rides** — students coordinate group rides with a shared admin model
- **Delivery** — sellers post delivery jobs, drivers apply and complete them with photo proof

---

## User Roles

| Role | Description |
|------|-------------|
| **Customer** | Books rides, tracks drivers, manages ride history |
| **Driver** | Accepts rides, posts route offers, applies for delivery jobs |
| **Student** | Joins or initiates shared ride groups |
| **Student Admin** | Manages group bookings and payments on behalf of students |
| **Seller** | Posts delivery jobs, reviews driver applications, approves deliveries |
| **Admin** | Manages platform, verifies drivers, handles disputes |

---

## Features

### Authentication & Profiles
- Register with student email or as a driver with vehicle info
- Log in / log out securely with email and password
- Reset password via email
- View and update profile information
- Driver verification via driving licence and student card submission
- Admin review and approval/rejection of driver verification documents
- Driver notified when verification is approved or rejected

### Ride-Hailing
- Customers request rides by entering pickup and drop-off location
- Browse ride offers matching origin and destination
- Book a seat on a driver's posted ride offer
- Drivers post ride offers with route, departure time, and available seats
- Drivers edit or cancel posted ride offers before any passenger joins
- Drivers accept or decline incoming ride requests
- Drivers update availability status (online/offline)
- Drivers view the list of students who booked seats
- View available drivers on a map
- Cancel a ride request before a driver accepts it

### Shared Rides
- Students initiate a shared ride request and become the group admin
- Students join an existing shared ride group as a passenger
- View average rating of other students before joining a group
- Student Admin confirms the final shared ride booking on behalf of the group
- Student Admin pays the full fare to the driver on behalf of the group
- Drivers view all passengers and their respective drop-off stops
- Students rate other students in the group after the trip ends

### Delivery
- Sellers create delivery jobs with location, time, items, quantity, and price
- Drivers browse open delivery jobs and apply as verified or unverified
- Sellers review driver applications and approve or reject them
- Driver receives notification when their delivery application is approved
- Drivers and sellers can chat after approval
- Drivers submit photo evidence at each delivery stop (multi-stop supported)
- Sellers view and approve photo proof for each delivery stop
- Sellers transfer payment to the driver after all deliveries are approved

### History & Earnings
- Drivers view a summary report of completed trips and total earnings
- Customers view complete ride and delivery history with dates and fares

### Disputes & Moderation
- Sellers open a dispute against a driver and report them to admin
- Admins receive and review dispute reports filed by sellers against drivers
- Admins view a list of all reported users
- Admins ban a driver or customer who has violated platform rules

---

## Sprint Roadmap

| Sprint | Dates | Focus |
|--------|-------|-------|
| Sprint 1 | 30 Apr – 13 May | Auth, driver verification, Shared rides |
| Sprint 2 | 14 May – 27 May | Ride hailing |
| Sprint 3 | 28 May – 10 Jun | Delivery workflow |
| Sprint 4 | 11 Jun – 24 Jun | Earnings, disputes, admin moderation, history |

---

*Project tracked on Jira under the HUS board.*
