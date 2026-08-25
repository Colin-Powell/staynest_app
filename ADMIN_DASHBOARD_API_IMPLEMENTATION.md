# Admin Dashboard API Implementation Guide

## Overview
This document covers the complete admin dashboard API wiring, including backend endpoints, frontend service integration, and metadata fetching for properties, users, and KYC verifications.

---

## 1. Backend API Endpoints (Node.js/TypeScript)

### File: `backend/src/routes/admin.ts`

#### 1.1 GET /admin/overview
**Purpose:** Fetch dashboard analytics and summary metrics

**Query Parameters:**
- None

**Response:**
```json
{
  "success": true,
  "data": {
    "totalUsers": 150,
    "totalProperties": 45,
    "pendingVerifications": 8,
    "totalBookings": 230,
    "totalRevenue": 2500000,
    "monthlyRevenue": 450000,
    "chartData": [...],
    "verificationData": [...],
    "retentionData": [...],
    "cohortData": [...],
    "topLocations": [...],
    "kycRejections": [...],
    "keyEvents": [...],
    "backlogData": [...]
  }
}
```

---

#### 1.2 GET /admin/users
**Purpose:** List all users with comprehensive metadata

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `limit` | int | Results per page (default: 10) |
| `offset` | int | Pagination offset (default: 0) |
| `search` | string | Search by name, email, or phone |
| `role` | string | Filter by role: `tenant`, `landlord`, `admin` |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "John Doe",
      "email": "john@example.com",
      "phone": "+254712345678",
      "role": "landlord",
      "verified": true,
      "status": "active",
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-08-25T14:20:00Z",
      "property_count": 5,
      "active_property_count": 4,
      "booking_count_as_landlord": 25,
      "booking_count_as_tenant": 3,
      "total_revenue": 1250000,
      "last_active_at": "2024-08-25T09:00:00Z"
    }
  ]
}
```

**Metadata Included:**
- User profile (name, email, phone, role)
- Account status (verified, suspended)
- Property statistics (count, active count)
- Booking history (as landlord/tenant)
- Revenue generation (for landlords)
- Last activity timestamp

---

#### 1.3 GET /admin/properties
**Purpose:** List properties with full listing metadata for moderation

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `limit` | int | Results per page (default: 10) |
| `offset` | int | Pagination offset (default: 0) |
| `status` | string | Filter by: `pending_review`, `approved`, `rejected`, `available`, `rented`, `maintenance` |
| `search` | string | Search by title, city, or address |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "title": "Cozy Apartment in Westlands",
      "description": "Modern 2BR apartment...",
      "category": "apartment",
      "city": "Nairobi",
      "address": "123 Main St, Westlands",
      "lat": -1.2921,
      "lng": 36.8219,
      "price": 45000,
      "bedrooms": 2,
      "bathrooms": 1,
      "area": 120,
      "amenities": ["WiFi", "Parking", "Security"],
      "image_url": "https://example.com/img1.jpg",
      "images": ["https://example.com/img1.jpg", "https://example.com/img2.jpg"],
      "image_count": 5,
      "booking_count": 12,
      "total_revenue": 540000,
      "status": "approved",
      "created_at": "2024-08-20T10:00:00Z",
      "updated_at": "2024-08-25T14:00:00Z",
      "landlord_id": "uuid",
      "landlord_name": "John Doe",
      "landlord_email": "john@example.com",
      "landlord_verified": true
    }
  ]
}
```

**Metadata Included:**
- Full listing details (title, description, category, pricing)
- Location information (address, city, lat/lng)
- Property specs (bedrooms, bathrooms, area)
- Amenities (as array)
- Images (count and URLs)
- Booking performance (count, revenue)
- Landlord information (name, email, verification status)
- Status tracking (created, updated dates)

---

#### 1.4 GET /admin/kyc
**Purpose:** List KYC verifications for review and approval

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `limit` | int | Results per page (default: 10) |
| `offset` | int | Pagination offset (default: 0) |
| `status` | string | Filter by: `submitted`, `under_review`, `approved`, `rejected` |
| `search` | string | Search by user name or email |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "name": "Jane Smith",
      "email": "jane@example.com",
      "phone": "+254787654321",
      "role": "landlord",
      "document_type": "national_id",
      "document_url": "https://cloudinary.example.com/document.jpg",
      "document_number": "ID12345678",
      "selfie_url": "https://cloudinary.example.com/selfie.jpg",
      "status": "under_review",
      "admin_notes": "Verification pending document verification",
      "property_count": 2,
      "created_at": "2024-08-24T11:00:00Z",
      "updated_at": "2024-08-25T10:30:00Z"
    }
  ]
}
```

**Metadata Included:**
- User identification (name, email, phone, role)
- Document information (type, URL, number)
- Verification status
- Admin notes for review comments
- User's property count
- Submission and review timestamps

---

#### 1.5 PATCH /admin/kyc/:id
**Purpose:** Update KYC verification status (approve/reject/review)

**Request Body:**
```json
{
  "status": "approved",
  "admin_notes": "Document verified successfully"
}
```

**Valid Status Values:**
- `submitted` - Initial submission
- `under_review` - Currently being reviewed
- `approved` - KYC verified
- `rejected` - KYC rejected with reason in admin_notes

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "status": "approved",
    "admin_notes": "Document verified successfully",
    "updated_at": "2024-08-25T15:00:00Z"
  }
}
```

---

#### 1.6 PATCH /admin/properties/:id/status
**Purpose:** Update property approval status

**Request Body:**
```json
{
  "status": "approved"
}
```

**Valid Status Values:**
- `pending_review` - Awaiting admin review
- `approved` - Approved for listing
- `rejected` - Rejected (landlord must resubmit)
- `available` - Live and available for booking
- `rented` - Currently rented
- `maintenance` - Temporarily unavailable

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "status": "approved",
    "updated_at": "2024-08-25T15:15:00Z"
  }
}
```

---

## 2. Frontend Service Integration (Dart/Flutter)

### File: `frontend/lib/services/super_admin_service.dart`

#### 2.1 Updated Service Methods

All methods now support search, filtering, and pagination:

```dart
// Fetch users with filtering
final users = await SuperAdminService.fetchUsers(
  limit: 20,
  offset: 0,
  search: 'John',
  role: 'landlord',
);

// Fetch properties with filtering
final properties = await SuperAdminService.fetchProperties(
  limit: 20,
  offset: 0,
  status: 'pending_review',
  search: 'Westlands',
);

// Fetch KYC verifications with filtering
final kycList = await SuperAdminService.fetchKyc(
  limit: 20,
  offset: 0,
  status: 'submitted',
  search: 'Jane',
);
```

#### 2.2 Helper Methods

**Currency Formatting:**
```dart
String formatted = SuperAdminService.formatCurrency(1250000);
// Output: "KSh 1250000"
```

**Date Formatting:**
```dart
String date = SuperAdminService.formatDate('2024-08-25T14:20:00Z');
// Output: "25/8/2024"

String dateTime = SuperAdminService.formatDateTime('2024-08-25T14:20:00Z');
// Output: "25/8/2024 14:20"
```

**Status Badge Text:**
```dart
String badgeText = SuperAdminService.getStatusBadgeText('pending_review');
// Output: "PENDING REVIEW"
```

---

## 3. UI Implementation in Flutter

### 3.1 Property Cards Enhancement

Update `frontend/lib/screens/super_admin/super_admin_properties.dart` to display new metadata:

```dart
// New metadata fields to display in property cards:
Text('Images: ${property['image_count']} photos'),
Text('Bookings: ${property['booking_count']}'),
Text('Revenue: ${SuperAdminService.formatCurrency(property['total_revenue'])}'),
Text('Landlord: ${property['landlord_name']} ${property['landlord_verified'] ? '✓' : ''}'),
Text('Created: ${SuperAdminService.formatDate(property['created_at'])}'),
```

### 3.2 User List Enhancement

Update `frontend/lib/screens/super_admin/super_admin_users.dart`:

```dart
// New metadata in user cards:
Text('Properties: ${user['property_count']} (${user['active_property_count']} active)'),
Text('Bookings: ${user['booking_count_as_landlord']} as landlord, ${user['booking_count_as_tenant']} as tenant'),
Text('Total Revenue: ${SuperAdminService.formatCurrency(user['total_revenue'])}'),
Text('Last Active: ${SuperAdminService.formatDateTime(user['last_active_at'])}'),
```

### 3.3 Analytics Enhancements

The dashboard now includes:
- User metadata (property count, revenue, activity)
- Property metadata (bookings, revenue, landlord info)
- KYC verification metrics (property count, document status)

---

## 4. Search & Filtering Implementation

### 4.1 Search Examples

```dart
// Search for user by name/email/phone
final users = await SuperAdminService.fetchUsers(
  search: 'john@example.com',
);

// Filter landlords only
final landlords = await SuperAdminService.fetchUsers(
  role: 'landlord',
  limit: 50,
);

// Search properties by location
final westlandsProperties = await SuperAdminService.fetchProperties(
  search: 'Westlands',
);

// Filter pending verifications
final pendingKyc = await SuperAdminService.fetchKyc(
  status: 'submitted',
);
```

### 4.2 Pagination Implementation

```dart
// Page 1 (first 20 items)
final page1 = await SuperAdminService.fetchUsers(
  limit: 20,
  offset: 0,
);

// Page 2 (next 20 items)
final page2 = await SuperAdminService.fetchUsers(
  limit: 20,
  offset: 20,
);

// Page 3
final page3 = await SuperAdminService.fetchUsers(
  limit: 20,
  offset: 40,
);
```

---

## 5. Error Handling

All endpoints return structured error responses:

```json
{
  "success": false,
  "error": "Invalid status. Must be approved, rejected, under_review, or submitted"
}
```

Common HTTP status codes:
- `200 OK` - Success
- `400 Bad Request` - Invalid parameters
- `401 Unauthorized` - Missing or invalid token
- `403 Forbidden` - Insufficient permissions (not admin)
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error

---

## 6. Performance Considerations

### Database Queries Optimization

1. **Aggregation Queries:** All counts (bookings, revenue, properties) are calculated in the database using PostgreSQL aggregation functions (`COUNT`, `SUM`, `MAX`)

2. **Indexed Columns Used:**
   - `users.id` (PK)
   - `properties.landlord_id` (FK)
   - `properties.status`
   - `verifications.user_id` (FK)
   - `verifications.status`
   - `bookings.property_id`, `bookings.landlord_id`, `bookings.tenant_id`
   - `bookings.status`

3. **GROUP BY Optimization:** Results are grouped at database level to minimize data transfer

### Recommended Indexes for Admin Queries

```sql
-- If not already present, add these indexes:
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_verified ON users(verified);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_properties_status ON properties(status);
CREATE INDEX IF NOT EXISTS idx_properties_landlord_id ON properties(landlord_id);
CREATE INDEX IF NOT EXISTS idx_verifications_status ON verifications(status);
CREATE INDEX IF NOT EXISTS idx_verifications_user_id ON verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_landlord_id ON bookings(landlord_id);
CREATE INDEX IF NOT EXISTS idx_bookings_property_id ON bookings(property_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
```

---

## 7. Testing Checklist

- [ ] **Overview Endpoint**
  - [ ] Returns all analytics metrics
  - [ ] Chart data for 7-day period
  - [ ] Retention metrics for 35-day window
  - [ ] Cohort analysis

- [ ] **Users Endpoint**
  - [ ] Fetch all users with pagination
  - [ ] Search by name, email, phone
  - [ ] Filter by role
  - [ ] Verify metadata (property count, revenue, last activity)
  - [ ] Pagination works correctly

- [ ] **Properties Endpoint**
  - [ ] Fetch all properties with pagination
  - [ ] Filter by status
  - [ ] Search by title, city, address
  - [ ] Verify metadata (landlord info, bookings, revenue, images)
  - [ ] Image count calculated correctly

- [ ] **KYC Endpoint**
  - [ ] Fetch all KYC submissions
  - [ ] Filter by status
  - [ ] Search by user name/email
  - [ ] Verify document information included
  - [ ] Property count for user shown

- [ ] **KYC Status Update**
  - [ ] Update status to approved
  - [ ] Update status to rejected with notes
  - [ ] Verify admin_notes saved
  - [ ] Timestamp updated correctly

- [ ] **Property Status Update**
  - [ ] Update status to approved
  - [ ] Update status to rejected
  - [ ] Verify invalid status rejected
  - [ ] Timestamp updated correctly

- [ ] **Frontend Integration**
  - [ ] Service methods accept all parameters
  - [ ] Helper formatting methods work correctly
  - [ ] UI displays all metadata fields
  - [ ] Search/filter results update UI
  - [ ] Pagination works in UI

---

## 8. Deployment Checklist

- [ ] Database indexes created
- [ ] Backend routes compiled and tested
- [ ] Frontend service updated and compiled
- [ ] UI components updated to display new metadata
- [ ] Admin credentials configured with proper permissions
- [ ] API token authorization verified
- [ ] Rate limiting configured if needed
- [ ] Monitoring/logging for admin operations enabled

---

## 9. Future Enhancements

1. **Bulk Actions:** Approve/reject multiple items at once
2. **Export:** Export user/property/KYC data to CSV
3. **Advanced Filtering:** Multiple filters combined
4. **Sorting:** Sort by any column (name, revenue, date, etc.)
5. **Activity Audit Log:** Track all admin actions
6. **Webhook Notifications:** Alert admins on pending reviews
7. **Report Generation:** Scheduled reports to admin email
8. **Performance Metrics:** Track admin dashboard load times

---

## Summary of Changes

| Component | File | Changes |
|-----------|------|---------|
| Backend | `backend/src/routes/admin.ts` | Added 5 new endpoints: `/users`, `/properties`, `/kyc`, `PATCH /kyc/:id`, `PATCH /properties/:id/status` |
| Frontend | `frontend/lib/services/super_admin_service.dart` | Enhanced 3 methods with search/filter/pagination; added 4 helper formatting methods |
| UI | Property/User Cards | Display new metadata: image counts, bookings, revenue, landlord info, activity timestamps |
| Database | PostgreSQL | Optimized aggregation queries; recommended indexes for performance |

---

**Last Updated:** August 25, 2024
**Status:** Implementation Complete ✅
