# Landlord/Agent Registration & Verification - Audit Report

## Summary
✅ **Core Infrastructure**: 70% Complete
- Registration accepts landlord role
- Verification UI for document collection (ID, selfie, property docs)
- Upload service working
- Backend verification endpoints exist

❌ **Critical Gaps**: 30% Complete
- No admin approval/rejection endpoints
- No landlord dashboard/home screen after login
- No verification status checks
- Properties not linked to landlord_id during listing
- Missing landlord-specific fields in registration
- No email/SMS phone verification
- No role-based access control

---

## WHAT'S WORKING

### Backend
✅ **Registration** (`auth.ts`)
- POST /auth/register accepts name, email, phone, password, role
- Accepts role: 'tenant' | 'landlord' | 'host'
- Returns JWT with role embedded

✅ **User Verification** (`verifications.ts`)
- POST /verifications - Submit documents + property data
- GET /verifications/me - Get current user's verification status
- Stores documents as JSONB in database

✅ **File Uploads** (`uploads.ts`)
- POST /uploads - Upload file (images only, max 10MB)
- Returns public URL to uploaded file
- Requires authentication

✅ **Database Schema** (`init-db.sql`)
- `users` table: id, name, email, phone, role, verified
- `verifications` table: id, user_id, status, documents, property_data, admin_notes
- `properties` table: includes landlord_id (FK to users)

### Frontend
✅ **Registration** (`register_view.dart`)
- Text inputs: name, email, phone, password
- Role selection (via RoleSelectionView)
- Calls RemoteDatabaseRepository.register(name, phone, email, password, role)

✅ **Role Selection** (`role_selection_view.dart`)
- Shows Tenant vs Landlord/Agent options
- Stores selected role in AppSession.currentRole

✅ **Verification Flow** (`verification_flow.dart`)
- VerificationCenter - Entry point explaining benefits
- VerificationRequirementHub - Shows 3 requirement sections
- VerificationStepFlow - Captures documents:
  - Identity: ID front, ID back, selfie (3 docs)
  - Property: Utility bill, lease agreement, property photos (3 docs)
  - Business: Reserved for future
- Document upload with progress tracking
- Error display if admin rejects
- Submission via VerificationApi.submitVerification()

✅ **Listing Flow** (`listing_flow.dart`)
- 6-step form for property details, location, photos, pricing
- Saves property to backend

✅ **Services**
- UploadsService: Multi-file upload with progress
- VerificationApi: submitVerification(payload) POST to /verifications endpoint

---

## WHAT'S MISSING - CRITICAL

### Tier 1 - MVP Blockers

1. **Admin Verification Endpoints** ⚠️
   ```
   Missing:
   - GET /verifications/all?status=submitted - List all pending
   - PUT /verifications/:id - Approve/reject with admin notes
   - GET /verifications/admin/:id - View specific verification
   ```
   Current state: No way for admins to review submissions

2. **Landlord Dashboard** ⚠️
   ```
   Missing: Main screen after landlord login showing:
   - Verification status + progress
   - My properties (list, add new)
   - Inquiries from tenants
   - Earnings/bookings
   - Settings
   ```
   Current state: After registration, landlord directed to tenant home screen

3. **Verification Status Check After Login** ⚠️
   ```
   Missing:
   - Check if user role is 'landlord' and verified = false
   - If unverified, redirect to VerificationCenter
   - If verified, show landlord dashboard
   - If rejected, show rejection reasons + resubmit option
   ```
   Current state: No routing logic for post-login navigation based on status

4. **Landlord/Property Linkage in Listing Flow** ⚠️
   ```
   Current code: AddListingFlow doesn't capture landlord_id
   Need: POST /properties should receive landlord_id from logged-in user
   
   Backend fix:
   ```typescript
   router.post('/', requireAuth, async (req, res) => {
     const { title, description, ... } = req.body;
     await query(
       `INSERT INTO properties (..., landlord_id) 
        VALUES (..., $n)`,
       [..., req.auth!.id]
     );
   });
   ```
   
   Frontend fix: RemoteDatabaseRepository.createProperty() should auto-inject landlord_id

5. **Role-Based Access Control** ⚠️
   ```
   Missing:
   - Protect /landlord/* routes from tenant access
   - Hide landlord-only buttons from tenants
   - Show verification status UI to landlords only
   - Prevent adding properties if not verified
   ```
   Current state: No role checks in UI or routes

6. **Email/SMS Phone Verification** ⚠️
   ```
   Current: Hardcoded OTP code '624108' in auth.ts
   Missing:
   - Actually send SMS to phone with OTP
   - Validate OTP against sent code
   - Mark phone as verified in database
   - Add phone_verified boolean to users table
   ```

### Tier 2 - Important for UX

7. **Enhanced Registration Form** ⚠️
   ```
   Missing for landlords:
   - Business name
   - Business type (Individual, Company, Partnership)
   - Tax ID / Company registration number
   - Years in business
   - Business description/bio
   - Bank account for payouts (optional)
   
   Current: Only captures name, email, phone, password
   ```

8. **Property Ownership Verification** ⚠️
   ```
   Missing:
   - Link properties to verification ID during listing
   - Show verified badge only on properties owned by verified landlord
   - Prevent listing under someone else's account
   
   Current: Anyone can add properties
   ```

9. **Landlord Profile Page** ⚠️
   ```
   Missing:
   - View tenant inquiries/messages
   - Respond to inquiries
   - Track booking inquiries
   - View response rate/rating
   
   Current: No landlord-specific dashboard
   ```

10. **Property Listing Status** ⚠️
    ```
    Missing fields in properties table:
    - status (draft | pending_approval | approved | rejected | unlisted)
    - admin_notes (for rejection reasons)
    - verified_at (when approved)
    
    Missing logic:
    - Show only approved properties to tenants
    - Show rejection reasons to landlord
    - Allow resubmit if rejected
    ```

### Tier 3 - Polish

11. **Verification Rejection Workflow**
    - Show specific rejection reasons to landlord
    - Allow document resubmission with corrections
    - Track rejection history

12. **Analytics for Landlords**
    - View impressions, clicks, inquiries
    - Property performance metrics
    - Pricing recommendations

13. **Communication Center**
    - Notifications for verification status changes
    - Reminders for incomplete applications
    - Tenant inquiry notifications

---

## Database Schema Updates Needed

```sql
-- Add fields to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified boolean DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS business_name text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS business_type text; -- individual | company | partnership
ALTER TABLE users ADD COLUMN IF NOT EXISTS business_description text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS tax_id text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS years_in_business integer;

-- Add fields to verifications table
ALTER TABLE verifications ADD COLUMN IF NOT EXISTS rejection_reasons jsonb;

-- Add fields to properties table
ALTER TABLE properties ADD COLUMN IF NOT EXISTS status text DEFAULT 'draft'; -- draft | pending | approved | rejected
ALTER TABLE properties ADD COLUMN IF NOT EXISTS admin_notes text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS verified_at timestamptz;

-- Ensure landlord_id is NOT NULL when creating properties
ALTER TABLE properties ALTER COLUMN landlord_id SET NOT NULL;
```

---

## Implementation Roadmap

### Phase 1: Core Registration & Verification (12-15 hours)
- [ ] Add landlord-specific registration fields
- [ ] Add landlord dashboard entry point
- [ ] Add verification status check after login
- [ ] Implement admin verification endpoints (GET /all, PUT /:id)
- [ ] Add landlord dashboard UI
- [ ] Add role-based routing

### Phase 2: Property Linkage & Listing Control (8-10 hours)
- [ ] Link properties to landlord_id on creation
- [ ] Add property status field (draft/pending/approved/rejected)
- [ ] Add approval UI for admins
- [ ] Show only approved properties to tenants
- [ ] Add property status display to landlord dashboard

### Phase 3: Real Verification (Email/SMS) (6-8 hours)
- [ ] Integrate SMS provider (Twilio or similar)
- [ ] Send actual OTP on registration
- [ ] Validate OTP before marking verified
- [ ] Add phone_verified tracking

### Phase 4: Landlord Dashboard & Profile (10-12 hours)
- [ ] Build main landlord dashboard
- [ ] Show properties list
- [ ] Show verification status
- [ ] Show inquiries/messages
- [ ] Add profile page

---

## Files to Create/Modify

### Backend
- [ ] `routes/verifications.ts` - Add admin endpoints (GET all, PUT approve/reject)
- [ ] `routes/properties.ts` - Auto-inject landlord_id, add status field
- [ ] `routes/admin.ts` - NEW: Admin dashboard endpoints
- [ ] `init-db.sql` - Add new columns to users, properties, verifications

### Frontend
- [ ] `lib/screens/landlord/dashboard.dart` - NEW: Main landlord home
- [ ] `lib/screens/auth/register_view.dart` - Add landlord-specific fields
- [ ] `lib/screens/landlord/landlord_profile.dart` - NEW: Landlord profile
- [ ] `lib/screens/landlord/property_management.dart` - NEW: Manage properties
- [ ] `lib/screens/landlord/verification_status_view.dart` - ENHANCE: Show full status
- [ ] `lib/services/landlord_service.dart` - NEW: Fetch landlord data
- [ ] `lib/main.dart` - Add post-login role-based routing
- [ ] `lib/repository/remote_database_repository.dart` - Add landlord-specific methods

---

## Testing Checklist

- [ ] Register as landlord, redirected to verification
- [ ] Submit verification documents
- [ ] Admin can view pending verifications
- [ ] Admin can approve and landlord sees verified status
- [ ] Admin can reject with reasons, landlord sees why
- [ ] Can add properties only after verified
- [ ] Added properties linked to landlord_id in database
- [ ] Properties show landlord info to tenants
- [ ] Cannot access landlord dashboard as tenant
- [ ] Phone verification code sent via SMS
- [ ] Login after verification shows landlord dashboard
- [ ] Unverified landlord redirected to verification on login

---

## Priority Implementation Order

1. **Add admin verification endpoints** (2-3 hours) - Unblocks admin workflow
2. **Add landlord dashboard** (3-4 hours) - Unblocks landlord post-registration flow
3. **Add post-login routing** (1-2 hours) - Directs users correctly after login
4. **Enhance registration for landlords** (2 hours) - Captures business info
5. **Link properties to landlord_id** (2 hours) - Ensures data consistency
6. **Add property status tracking** (2-3 hours) - Prevents unapproved listing visibility
7. **Real phone verification** (4-5 hours) - Actual OTP delivery

