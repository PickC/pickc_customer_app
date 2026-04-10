# PickC Customer App — API Implementation Document

> **Base URL:** `https://<your-api-host>/api`
> **Auth:** All endpoints except Login, OTP, and Register require `Authorization: Bearer <access_token>` header.
> **Content-Type:** `application/json`

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Customer Profile](#2-customer-profile)
3. [Saved Addresses](#3-saved-addresses)
4. [Lookup / Reference Data](#4-lookup--reference-data)
5. [Booking](#5-booking)
6. [Trip Tracking](#6-trip-tracking)
7. [Invoice & Billing](#7-invoice--billing)
8. [Booking Status Reference](#8-booking-status-reference)
9. [Implementation Flow](#9-implementation-flow)

---

## 1. Authentication

### 1.1 Send OTP

**POST** `/auth/otp/send`
Auth: **Not required**

**Request:**
```json
{
  "mobileNo": "9876543210",
  "userType": "CUSTOMER"
}
```

**Response 200:**
```json
{
  "message": "OTP sent successfully"
}
```

**Response 400:**
```json
{
  "message": "Failed to send OTP"
}
```

---

### 1.2 Verify OTP

**POST** `/auth/otp/verify`
Auth: **Not required**

**Request:**
```json
{
  "mobileNo": "9876543210",
  "otp": "123456",
  "userType": "CUSTOMER"
}
```

**Response 200:**
```json
{
  "message": "OTP verification endpoint ready",
  "verified": true
}
```

---

### 1.3 Customer Login

**POST** `/auth/customer/login`
Auth: **Not required**

**Request:**
```json
{
  "mobileNo": "9876543210",
  "password": "MyPassword@123"
}
```

**Response 200:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...",
  "expiresIn": 3600,
  "userType": "CUSTOMER",
  "userId": "9876543210"
}
```

**Response 401:**
```json
{
  "message": "Invalid credentials"
}
```

> Store `accessToken`, `refreshToken`, and `userId` (mobileNo) securely in local storage.

---

### 1.4 Refresh Token

**POST** `/auth/refresh`
Auth: **Not required**

**Request:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4..."
}
```

**Response 200:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...(new)",
  "refreshToken": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...(new)",
  "expiresIn": 3600,
  "userType": "CUSTOMER",
  "userId": "9876543210"
}
```

**Response 401:**
```json
{
  "message": "Invalid or expired refresh token"
}
```

---

### 1.5 Logout

**POST** `/auth/logout`
Auth: **Required**

**Request body:** _(empty)_

**Response 200:**
```json
{
  "message": "Logged out successfully"
}
```

---

## 2. Customer Profile

### 2.1 Register Customer

**POST** `/master/customers`
Auth: **Required** *(call after OTP verification, using a temp token or allow anon for registration)*

**Request:**
```json
{
  "mobileNo": "9876543210",
  "password": "MyPassword@123",
  "name": "Rajesh Kumar",
  "emailID": "rajesh.kumar@example.com",
  "deviceID": "FCM_TOKEN_OR_DEVICE_ID_HERE"
}
```

**Response 200:**
```json
{
  "message": "Customer saved successfully"
}
```

**Response 400:**
```json
{}
```

---

### 2.2 Get Customer Profile

**GET** `/master/customers/{mobileNo}`
Auth: **Required**

**Example:** `GET /master/customers/9876543210`

**Response 200:**
```json
{
  "mobileNo": "9876543210",
  "name": "Rajesh Kumar",
  "emailID": "rajesh.kumar@example.com",
  "deviceID": "FCM_TOKEN_OR_DEVICE_ID_HERE",
  "createdOn": "2026-01-15T10:30:00Z"
}
```

---

### 2.3 Update Device ID (FCM Token)

**PUT** `/master/customers/device`
Auth: **Required**

> Call this every time the app starts or FCM token refreshes.

**Request:**
```json
{
  "mobileNo": "9876543210",
  "deviceID": "NEW_FCM_TOKEN_HERE"
}
```

**Response 200:**
```json
{
  "message": "Device updated"
}
```

**Response 404:** Customer not found.

---

### 2.4 Update Password

**PUT** `/master/customers/password`
Auth: **Required**

**Request:**
```json
{
  "mobileNo": "9876543210",
  "newPassword": "NewPassword@456"
}
```

**Response 200:**
```json
{
  "message": "Password updated"
}
```

---

## 3. Saved Addresses

### 3.1 Get Addresses by Customer

**GET** `/master/addresses/{linkId}`
Auth: **Required**

> `linkId` = customer's `mobileNo`

**Example:** `GET /master/addresses/9876543210`

**Response 200:**
```json
[
  {
    "addressId": 1,
    "addressLinkID": "9876543210",
    "seqNo": 1,
    "addressType": "HOME",
    "address1": "12, MG Road",
    "address2": "Near City Mall",
    "cityName": "Bangalore",
    "stateName": "Karnataka",
    "zipCode": "560001",
    "mobileNo": "9876543210",
    "contact": "Rajesh Kumar",
    "email": "rajesh@example.com",
    "fullAddress": "12, MG Road, Near City Mall, Bangalore - 560001"
  }
]
```

---

### 3.2 Save Address

**POST** `/master/addresses`
Auth: **Required**

**Request:**
```json
{
  "addressId": 0,
  "addressLinkID": "9876543210",
  "seqNo": 1,
  "addressType": "HOME",
  "address1": "12, MG Road",
  "address2": "Near City Mall",
  "address3": null,
  "address4": null,
  "cityName": "Bangalore",
  "stateName": "Karnataka",
  "countryCode": "IN",
  "zipCode": "560001",
  "telNo": null,
  "mobileNo": "9876543210",
  "contact": "Rajesh Kumar",
  "email": "rajesh@example.com"
}
```

> Set `addressId: 0` for new address; set existing `addressId` to update.

**Response 200:**
```json
{
  "message": "Address saved"
}
```

---

### 3.3 Delete Address

**DELETE** `/master/addresses/{id}`
Auth: **Required**

**Example:** `DELETE /master/addresses/1`

**Response 200:**
```json
{
  "message": "Address deleted"
}
```

---

## 4. Lookup / Reference Data

> Fetch these once on app startup and cache locally.

### 4.1 Get Vehicle Types

**GET** `/master/lookups/vehicle-types`
Auth: **Required**

**Response 200:**
```json
[
  {
    "lookupID": 1,
    "lookupCode": "MINI_TRUCK",
    "lookupDescription": "Mini Truck (< 1 Ton)",
    "lookupCategory": "VehicleType",
    "image": "vehicle_mini_truck.png"
  },
  {
    "lookupID": 2,
    "lookupCode": "TRUCK_1_TON",
    "lookupDescription": "1 Ton Truck",
    "lookupCategory": "VehicleType",
    "image": "vehicle_1ton.png"
  },
  {
    "lookupID": 3,
    "lookupCode": "TRUCK_3_TON",
    "lookupDescription": "3 Ton Truck",
    "lookupCategory": "VehicleType",
    "image": "vehicle_3ton.png"
  }
]
```

---

### 4.2 Get Vehicle Groups

**GET** `/master/lookups/vehicle-groups`
Auth: **Required**

**Response 200:**
```json
[
  {
    "lookupID": 10,
    "lookupCode": "OPEN",
    "lookupDescription": "Open Body",
    "lookupCategory": "VehicleGroup",
    "image": null
  },
  {
    "lookupID": 11,
    "lookupCode": "CLOSED",
    "lookupDescription": "Closed Body",
    "lookupCategory": "VehicleGroup",
    "image": null
  }
]
```

---

### 4.3 Get Cargo Types

**GET** `/master/lookups/cargo-types`
Auth: **Required**

**Response 200:**
```json
[
  {
    "lookupID": 20,
    "lookupCode": "HOUSEHOLD",
    "lookupDescription": "Household Goods",
    "lookupCategory": "CargoType",
    "image": null
  },
  {
    "lookupID": 21,
    "lookupCode": "COMMERCIAL",
    "lookupDescription": "Commercial Goods",
    "lookupCategory": "CargoType",
    "image": null
  },
  {
    "lookupID": 22,
    "lookupCode": "FRAGILE",
    "lookupDescription": "Fragile Items",
    "lookupCategory": "CargoType",
    "image": null
  }
]
```

---

### 4.4 Get Loading/Unloading Types

**GET** `/master/lookups/loading-types`
Auth: **Required**

**Response 200:**
```json
[
  {
    "lookupID": 30,
    "lookupCode": "SELF",
    "lookupDescription": "Self Loading/Unloading",
    "lookupCategory": "LoadingUnLoading",
    "image": null
  },
  {
    "lookupID": 31,
    "lookupCode": "ASSISTED",
    "lookupDescription": "Driver Assisted",
    "lookupCategory": "LoadingUnLoading",
    "image": null
  }
]
```

---

## 5. Booking

### 5.1 Create Booking

**POST** `/booking/bookings`
Auth: **Required**

**Request:**
```json
{
  "bookingNo": "",
  "customerID": "9876543210",
  "requiredDate": "2026-04-10T09:00:00Z",
  "locationFrom": "12, MG Road, Bangalore",
  "locationTo": "45, Church Street, Bangalore",
  "cargoDescription": "2-seater sofa and 4 boxes",
  "vehicleType": 1,
  "vehicleGroup": 10,
  "cargoType": "HOUSEHOLD",
  "payLoad": "500 KG",
  "loadingUnLoading": 31,
  "remarks": "Handle with care",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "toLatitude": 12.9352,
  "toLongitude": 77.6245,
  "receiverMobileNo": "9123456780",
  "status": 0
}
```

> Leave `bookingNo` as empty string — the server generates it.
> `status: 0` = New booking.

**Response 200:**
```json
{
  "message": "Booking saved successfully"
}
```

**Response 400:**
```json
{}
```

---

### 5.2 Get Booking by Booking Number

**GET** `/booking/bookings/{bookingNo}`
Auth: **Required**

**Example:** `GET /booking/bookings/BK20260407001`

**Response 200:**
```json
{
  "bookingNo": "BK20260407001",
  "bookingDate": "2026-04-07T08:15:00Z",
  "customerID": "9876543210",
  "requiredDate": "2026-04-10T09:00:00Z",
  "locationFrom": "12, MG Road, Bangalore",
  "locationTo": "45, Church Street, Bangalore",
  "cargoDescription": "2-seater sofa and 4 boxes",
  "vehicleType": 1,
  "vehicleGroup": 10,
  "cargoType": "HOUSEHOLD",
  "payLoad": "500 KG",
  "loadingUnLoading": 31,
  "remarks": "Handle with care",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "toLatitude": 12.9352,
  "toLongitude": 77.6245,
  "receiverMobileNo": "9123456780",
  "isConfirm": true,
  "confirmDate": "2026-04-07T08:45:00Z",
  "driverID": "DRV001",
  "vehicleNo": "KA01AB1234",
  "isCancel": false,
  "cancelTime": null,
  "cancelRemarks": "",
  "isCancelByDriver": false,
  "driverCancelDateTime": null,
  "isComplete": false,
  "completeTime": null,
  "isReachPickUp": false,
  "pickupReachDateTime": null,
  "isReachDestination": false,
  "destinationReachDateTime": null,
  "status": 1
}
```

---

### 5.3 Get My Bookings

**GET** `/booking/bookings/customer/{customerId}`
Auth: **Required**

**Example:** `GET /booking/bookings/customer/9876543210`

**Response 200:** _(array of BookingDto — same structure as 5.2)_
```json
[
  {
    "bookingNo": "BK20260407001",
    "bookingDate": "2026-04-07T08:15:00Z",
    "customerID": "9876543210",
    "locationFrom": "12, MG Road, Bangalore",
    "locationTo": "45, Church Street, Bangalore",
    "isConfirm": true,
    "isComplete": false,
    "isCancel": false,
    "status": 1
  }
]
```

---

### 5.4 Cancel Booking

**PUT** `/booking/bookings/cancel`
Auth: **Required**

**Request:**
```json
{
  "bookingNo": "BK20260407001",
  "cancelRemarks": "Changed plans"
}
```

**Response 200:**
```json
{
  "message": "Booking cancelled"
}
```

**Response 400:**
```json
{
  "message": "Booking cannot be cancelled"
}
```

---

### 5.5 Search Bookings

**GET** `/booking/search?fromDate=&toDate=&status=&customerID=`
Auth: **Required**

**Query Parameters:**

| Parameter  | Type     | Description                      |
|------------|----------|----------------------------------|
| fromDate   | datetime | Filter from date (ISO 8601)      |
| toDate     | datetime | Filter to date (ISO 8601)        |
| status     | int      | Booking status (see §8)          |
| customerID | string   | Filter by customer mobile number |

**Example:** `GET /booking/search?customerID=9876543210&status=1`

**Response 200:** _(array of BookingDto)_

---

### 5.6 Get Today's Bookings

**GET** `/booking/search/today`
Auth: **Required**

**Response 200:** _(array of BookingDto for today)_

---

## 6. Trip Tracking

### 6.1 Get Current Active Trip

**GET** `/trip/trips/customer/{customerMobile}/current`
Auth: **Required**

**Example:** `GET /trip/trips/customer/9876543210/current`

**Response 200:**
```json
{
  "tripID": "TRP20260407001",
  "tripDate": "2026-04-07T10:00:00Z",
  "customerMobile": "9876543210",
  "driverID": "DRV001",
  "vehicleNo": "KA01AB1234",
  "vehicleType": 1,
  "vehicleGroup": 10,
  "locationFrom": "12, MG Road, Bangalore",
  "locationTo": "45, Church Street, Bangalore",
  "distance": 8.5,
  "startTime": "2026-04-07T10:00:00Z",
  "endTime": null,
  "tripMinutes": 0,
  "waitingMinutes": 0,
  "totalWeight": "500 KG",
  "cargoDescription": "2-seater sofa and 4 boxes",
  "remarks": "Handle with care",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "tripEndLat": null,
  "tripEndLong": null,
  "distanceTravelled": 2.3,
  "bookingNo": "BK20260407001"
}
```

**Response 404:**
```json
{
  "message": "No active trip found"
}
```

---

### 6.2 Get Trip by Booking Number

**GET** `/trip/trips/booking/{bookingNo}`
Auth: **Required**

**Example:** `GET /trip/trips/booking/BK20260407001`

**Response 200:** _(TripDto — same structure as 6.1)_

---

### 6.3 Get Driver Live Location (Trip Monitor)

**GET** `/trip/monitors/trip/{tripId}`
Auth: **Required**

**Example:** `GET /trip/monitors/trip/TRP20260407001`

> Poll this endpoint every 10–15 seconds during an active trip to show driver location on the map.

**Response 200:**
```json
[
  {
    "driverID": "DRV001",
    "tripID": "TRP20260407001",
    "vehicleNo": "KA01AB1234",
    "refreshDate": "2026-04-07T10:12:35Z",
    "latitude": 12.9620,
    "longitude": 77.5980,
    "tripType": 1
  }
]
```

---

## 7. Invoice & Billing

### 7.1 Get Invoice by Booking Number

**GET** `/billing/invoices/booking/{bookingNo}`
Auth: **Required**

**Example:** `GET /billing/invoices/booking/BK20260407001`

**Response 200:**
```json
{
  "invoiceNo": "INV20260407001",
  "tripID": "TRP20260407001",
  "invoiceDate": "2026-04-07T13:00:00Z",
  "tripAmount": 450.00,
  "taxAmount": 45.00,
  "tipAmount": 20.00,
  "totalAmount": 515.00,
  "paymentType": 1,
  "paidAmount": 515.00,
  "createdOn": "2026-04-07T13:00:00Z",
  "isMailSent": false,
  "bookingNo": "BK20260407001",
  "isPaid": true,
  "paidDate": "2026-04-07T13:15:00Z"
}
```

**Response 404:** Invoice not found.

---

### 7.2 Get Invoice by Trip ID

**GET** `/billing/invoices/trip/{tripId}`
Auth: **Required**

**Example:** `GET /billing/invoices/trip/TRP20260407001`

**Response 200:** _(array of InvoiceDto — same structure as 7.1)_

---

## 8. Booking Status Reference

| Status | Meaning               |
|--------|-----------------------|
| 0      | New / Pending         |
| 1      | Confirmed (Driver assigned) |
| 2      | Driver at Pickup      |
| 3      | In Transit            |
| 4      | Delivered             |
| 5      | Completed             |
| 6      | Cancelled by Customer |
| 7      | Cancelled by Driver   |

---

## 9. Implementation Flow

### New User Registration Flow
```
1. POST /auth/otp/send          → Send OTP to mobile
2. POST /auth/otp/verify        → Verify OTP
3. POST /master/customers       → Register account
4. POST /auth/customer/login    → Login & get tokens
5. PUT  /master/customers/device → Register FCM token
```

### Create a Booking Flow
```
1. GET  /master/lookups/vehicle-types   → Load dropdown data
2. GET  /master/lookups/cargo-types     → Load dropdown data
3. GET  /master/lookups/loading-types   → Load dropdown data
4. POST /booking/bookings               → Submit booking request
5. GET  /booking/bookings/{bookingNo}   → Poll until isConfirm = true
```

### Track Active Trip Flow
```
1. GET  /trip/trips/customer/{mobile}/current     → Get active trip
2. GET  /trip/monitors/trip/{tripId}              → Poll driver GPS (every 10s)
3. GET  /booking/bookings/{bookingNo}             → Check booking status
4. GET  /billing/invoices/booking/{bookingNo}     → Fetch invoice after completion
```

### Token Refresh Flow
```
1. On 401 Unauthorized response:
2. POST /auth/refresh  → Get new tokens
3. Retry original request with new accessToken
4. If refresh also fails → redirect to Login screen
```

---

*Last Updated: 2026-04-07*
*Generated from PickC Core API — src/Modules/*
