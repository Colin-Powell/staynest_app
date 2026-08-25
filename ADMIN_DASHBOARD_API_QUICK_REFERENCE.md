# Admin Dashboard API - Quick Reference

## Backend Endpoints (Node.js/TypeScript)

### Overview Analytics
```bash
GET /admin/overview
# Returns: totalUsers, totalProperties, pendingVerifications, totalBookings, 
#          totalRevenue, monthlyRevenue, chartData, retentionData, cohortData, etc.
```

### User Management
```bash
GET /admin/users?limit=20&offset=0&search=john&role=landlord
# Returns: [{ id, name, email, phone, role, verified, status, property_count,
#            active_property_count, booking_count_as_landlord, booking_count_as_tenant,
#            total_revenue, last_active_at }]
```

### Property Moderation
```bash
GET /admin/properties?limit=20&offset=0&status=pending_review&search=apartment
# Returns: [{ id, title, city, price, bedrooms, bathrooms, amenities, images,
#            image_count, booking_count, total_revenue, landlord_name, 
#            landlord_email, landlord_verified, status }]
```

### KYC Verification
```bash
GET /admin/kyc?limit=20&offset=0&status=submitted&search=jane
# Returns: [{ id, user_id, name, email, phone, role, document_type, 
#            document_url, document_number, selfie_url, status, admin_notes, 
#            property_count }]

PATCH /admin/kyc/:id
# Body: { status: 'approved'|'rejected'|'under_review', admin_notes?: string }
```

### Property Status Update
```bash
PATCH /admin/properties/:id/status
# Body: { status: 'pending_review'|'approved'|'rejected'|'available'|'rented'|'maintenance' }
```

---

## Frontend Service Usage (Flutter)

### Import
```dart
import 'package:property_app/services/super_admin_service.dart';
```

### Fetch Users
```dart
final users = await SuperAdminService.fetchUsers(
  limit: 20,
  offset: 0,
  search: 'john',  // optional
  role: 'landlord',  // optional
);

// users[0] contains: id, name, email, phone, role, verified, status,
//                    property_count, active_property_count, booking_count_as_landlord,
//                    booking_count_as_tenant, total_revenue, last_active_at
```

### Fetch Properties
```dart
final properties = await SuperAdminService.fetchProperties(
  limit: 20,
  offset: 0,
  status: 'pending_review',  // optional
  search: 'westlands',  // optional
);

// properties[0] contains: id, title, city, address, price, bedrooms, bathrooms,
//                         amenities, images, image_count, booking_count, 
//                         total_revenue, landlord_name, landlord_email,
//                         landlord_verified, status
```

### Fetch KYC Verifications
```dart
final kycs = await SuperAdminService.fetchKyc(
  limit: 20,
  offset: 0,
  status: 'submitted',  // optional
  search: 'jane',  // optional
);

// kycs[0] contains: id, user_id, name, email, phone, role, document_type,
//                   document_url, document_number, selfie_url, status,
//                   admin_notes, property_count
```

### Update KYC Status
```dart
await SuperAdminService.updateKycStatus(
  'kyc-id-123',
  status: 'approved',
  adminNotes: 'Document verified',
);
```

### Update Property Status
```dart
await SuperAdminService.updatePropertyStatus(
  'property-id-456',
  status: 'approved',
);
```

### Helper Methods
```dart
String currency = SuperAdminService.formatCurrency(1250000);
// Output: "KSh 1250000"

String date = SuperAdminService.formatDate('2024-08-25T14:20:00Z');
// Output: "25/8/2024"

String dateTime = SuperAdminService.formatDateTime('2024-08-25T14:20:00Z');
// Output: "25/8/2024 14:20"

String badge = SuperAdminService.getStatusBadgeText('pending_review');
// Output: "PENDING REVIEW"
```

---

## Common Use Cases

### 1. Display User Dashboard
```dart
// Load overview
final overview = await SuperAdminService.fetchOverview();
// Display: totalUsers, totalProperties, totalRevenue, charts

// Load recent users with metadata
final users = await SuperAdminService.fetchUsers(limit: 10);
// Display: name, email, property_count, total_revenue, last_active_at
```

### 2. Moderate Properties
```dart
// Load pending properties
final pending = await SuperAdminService.fetchProperties(
  status: 'pending_review',
  limit: 20,
);
// Display: title, landlord info, images, bookings, revenue

// Approve property
await SuperAdminService.updatePropertyStatus(id, status: 'approved');
```

### 3. Review KYC Documents
```dart
// Load submitted verifications
final submissions = await SuperAdminService.fetchKyc(
  status: 'submitted',
  limit: 20,
);
// Display: user info, documents, property count

// Approve verification
await SuperAdminService.updateKycStatus(id, status: 'approved');
```

### 4. Search & Filter
```dart
// Search for specific user
final results = await SuperAdminService.fetchUsers(
  search: 'john@example.com',
);

// Filter by role
final landlords = await SuperAdminService.fetchUsers(role: 'landlord');

// Filter properties by status
final rejected = await SuperAdminService.fetchProperties(
  status: 'rejected',
);

// Search KYC by user name
final kyc = await SuperAdminService.fetchKyc(search: 'Jane');
```

### 5. Pagination
```dart
// Page 1
final page1 = await SuperAdminService.fetchUsers(limit: 20, offset: 0);

// Page 2
final page2 = await SuperAdminService.fetchUsers(limit: 20, offset: 20);

// Load next page
int nextOffset = previousOffset + previousLimit;
final nextPage = await SuperAdminService.fetchUsers(
  limit: 20,
  offset: nextOffset,
);
```

---

## Key Metadata Fields

| Data Type | Fields | Use Case |
|-----------|--------|----------|
| **Users** | property_count, active_property_count | Assess landlord activity |
| | booking_count_as_landlord, total_revenue | Track landlord performance |
| | booking_count_as_tenant | Identify active tenants |
| | last_active_at, verified | Engagement & security |
| **Properties** | landlord_name, landlord_verified | Verify landlord legitimacy |
| | image_count, booking_count | Quality assessment |
| | total_revenue | Popularity & performance |
| | created_at, status | Moderation tracking |
| **KYC** | document_url, selfie_url | Verification review |
| | property_count | Risk assessment |
| | admin_notes, status | Review tracking |

---

## Error Handling

All methods throw exceptions on error. Wrap in try-catch:

```dart
try {
  final users = await SuperAdminService.fetchUsers();
} on Exception catch (e) {
  print('Error fetching users: $e');
  // Show error message to admin
}
```

Common errors:
- **401 Unauthorized** - Invalid/missing JWT token
- **403 Forbidden** - User is not an admin
- **400 Bad Request** - Invalid query parameters
- **404 Not Found** - Resource not found
- **500 Server Error** - Database or server issue

---

## Performance Tips

1. **Use pagination:** Always use `limit` to avoid loading too much data
2. **Narrow search:** Include search terms to filter results server-side
3. **Cache results:** Store data locally if displaying same page repeatedly
4. **Lazy load:** Load data as needed, not all at startup
5. **Batch updates:** Group multiple status updates into single requests if possible

---

## Files to Check

- **Backend:** `backend/src/routes/admin.ts`
- **Frontend:** `frontend/lib/services/super_admin_service.dart`
- **Documentation:** 
  - `ADMIN_DASHBOARD_API_IMPLEMENTATION.md` (full spec)
  - `ADMIN_DASHBOARD_CHANGES_SUMMARY.md` (change log)
  - `ADMIN_DASHBOARD_API_QUICK_REFERENCE.md` (this file)

---

**Last Updated:** August 25, 2024
**Status:** ✅ Ready for use
