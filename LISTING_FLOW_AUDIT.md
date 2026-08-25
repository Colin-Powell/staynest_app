# StayNest Listing Flow Audit Report
**Date:** 2026-08-25  
**Scope:** Listing creation flow, draft session management, and image upload integration

---

## Executive Summary

The listing flow has **significant architectural gaps** affecting reliability, scalability, and user experience. While the core flow functions, there are missing backend integrations, inconsistent state management, and critical scalability limitations.

**Critical Issues:** 5 (added: draft visibility enforcement)  
**High Issues:** 10 (added: draft filtering, form state preservation)  
**Medium Issues:** 6  

---

## 1. DRAFT SESSION MANAGEMENT

### 1.1 🔴 CRITICAL: No Persistent Backend Draft Storage

**Issue:** Draft listings are stored ONLY in device local storage (`SharedPreferences`), not in the database.

**Current Implementation:**
- Frontend: [listing_flow.dart](listing_flow.dart#L300-L340) saves drafts to `SharedPreferences` with key `listing_draft`
- Backend: NO draft table in schema ([init-db.sql](backend/scripts/init-db.sql))
- No `/api/drafts` endpoint exists

**Problems:**
1. **Data Loss:** Uninstall app → all drafts lost
2. **Multi-Device:** Landlord can't access draft on different device
3. **Account Deletion:** If landlord deletes their profile, all drafts vanish
4. **Backup:** No automatic backups or recovery mechanism
5. **Concurrent Edits:** Two devices creating same draft simultaneously causes conflicts

**Affected Code:**
- [listing_flow.dart#L227-L276](listing_flow.dart#L227-L276) — `_saveDraft()` only writes to SharedPreferences
- [listing_flow.dart#L183-L226](listing_flow.dart#L183-L226) — `_loadDraft()` only reads from SharedPreferences

**Impact:** Medium-to-high risk of user frustration and lost work.

**Recommendation:**
```sql
-- Add to init-db.sql
CREATE TABLE IF NOT EXISTS property_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  landlord_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text,
  description text,
  category text,
  city text,
  address text,
  price numeric,
  bedrooms integer,
  bathrooms integer,
  area integer,
  image_url text,
  images jsonb DEFAULT '[]'::jsonb,
  amenities jsonb DEFAULT '[]'::jsonb,
  lat numeric,
  lng numeric,
  additional_data jsonb DEFAULT '{}'::jsonb,
  saved_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_drafts_landlord ON property_drafts(landlord_id, updated_at DESC);
```

### 1.2 🟠 HIGH: Automatic Draft Expiration Not Implemented

**Issue:** Drafts have unlimited lifetime.

**Problems:**
- Old drafts clutter database and UI
- No cleanup process for abandoned drafts
- Storage costs grow unbounded

**Recommendation:** Add 30/60/90-day expiration with soft-delete flag.

### 1.3 🔴 CRITICAL: Draft Properties Are Publicly Exposed

**Issue:** Draft properties should NEVER be visible to tenants, but there is no backend enforcement.

**Current Implementation:**
- Backend: All properties with `status = 'pending_review'` are treated the same whether draft or submitted
- API: [properties.ts#L108-L115](backend/src/routes/properties.ts) filters by `COALESCE(p.status, 'pending_review') = 'approved'` for public listing
- **BUT:** No distinction between draft and submitted-for-review properties

**Problems:**
1. **No Draft Status:** Database schema has no `is_draft` or `draft_status` column
2. **Privacy Violation:** Landlord testing property can accidentally be public if status changes
3. **Unreviewed Content:** Admin can't see draft properties to understand what's pending review
4. **No Draft Visibility Control:** Landlord has no dashboard to see their own drafts

**Affected Code:**
- [init-db.sql#L25-L50](backend/scripts/init-db.sql) — Properties table missing draft/submission distinction
- [properties.ts#L90-L120](backend/src/routes/properties.ts) — No draft filtering in GET endpoints
- [properties.ts#L800-L850](backend/src/routes/properties.ts) — No draft column checked before creating property

**Recommendation:**

**1. Update Database Schema:**
```sql
ALTER TABLE properties ADD COLUMN IF NOT EXISTS is_draft boolean DEFAULT true;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS submitted_for_review boolean DEFAULT false;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS submitted_at timestamptz;

-- Old properties are not drafts (assume submitted)
UPDATE properties SET is_draft = false WHERE is_draft IS NULL;

-- Add index for draft queries
CREATE INDEX IF NOT EXISTS idx_properties_landlord_draft 
  ON properties(landlord_id, is_draft, updated_at DESC);
```

**2. Backend API Endpoints:**

**GET /api/properties** (Public listing - should NEVER return drafts)
```typescript
router.get('/', routeCache(300), async (req, res, next) => {
  try {
    const conditions: string[] = [];
    // ... existing filters ...
    
    // ✅ ALWAYS exclude drafts from public
    conditions.push(`COALESCE(p.status, 'pending_review') = 'approved'`);
    conditions.push(`p.is_draft = false`);  // ← NEW
    
    // ... rest of query ...
  }
});
```

**GET /api/properties/me** (Landlord's own properties - should include drafts)
```typescript
router.get('/me', requireAuth, authorize('landlord', 'host'), 
  async (req, res, next) => {
    try {
      const result = await query(
        `SELECT ${PROPERTY_SELECT},
                p.is_draft,
                p.submitted_for_review,
                p.submitted_at,
                CASE 
                  WHEN p.is_draft THEN 'draft'
                  WHEN p.submitted_for_review AND p.status = 'pending_review' THEN 'pending_approval'
                  WHEN p.status = 'approved' THEN 'live'
                  ELSE COALESCE(p.status, 'unknown')
                END as display_status
         FROM properties p
         LEFT JOIN users u ON u.id = p.landlord_id
         WHERE p.landlord_id = $1
         ORDER BY 
           CASE WHEN p.is_draft THEN 0 ELSE 1 END,
           p.updated_at DESC`,
        [req.auth?.id],
      );

      res.json({
        data: result.rows.map(row => ({
          ...normalizePropertyRow(row),
          is_draft: row.is_draft,
          submitted_for_review: row.submitted_for_review,
          submitted_at: row.submitted_at,
          display_status: row.display_status,
        })),
      });
    } catch (error) {
      next(error);
    }
  }
);
```

**GET /api/properties/me/drafts** (Only drafts for landlord)
```typescript
router.get('/me/drafts', requireAuth, authorize('landlord', 'host'), 
  async (req, res, next) => {
    try {
      const result = await query(
        `SELECT ${PROPERTY_SELECT}, p.is_draft, p.updated_at
         FROM properties p
         LEFT JOIN users u ON u.id = p.landlord_id
         WHERE p.landlord_id = $1 AND p.is_draft = true
         ORDER BY p.updated_at DESC`,
        [req.auth?.id],
      );

      res.json({
        data: result.rows.map(row => normalizePropertyRow(row)),
        count: result.rows.length,
      });
    } catch (error) {
      next(error);
    }
  }
);
```

**POST /api/properties/from-listing** (Create new draft)
```typescript
router.post('/from-listing', requireAuth, authorize('landlord', 'host'), 
  async (req, res, next) => {
    try {
      const body = req.body as Record<string, unknown>;
      
      // Determine if this is a draft or submission
      const isDraft = body.__isDraft !== false;  // Default to draft
      
      const result = await query(
        `INSERT INTO properties (
          title, description, category, city, address, price,
          bedrooms, bathrooms, area, image_url, images, amenities,
          lat, lng, landlord_id, status, is_draft, submitted_for_review, submitted_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12::jsonb, 
                $13, $14, $15, $16, $17, $18, $19)
        RETURNING *`,
        [
          body.title, body.description, body.category, body.city, body.address,
          body.price, body.bedrooms, body.bathrooms, body.area,
          body.image_url, 
          JSON.stringify(Array.isArray(body.images) ? body.images : [body.image_url]),
          JSON.stringify(Array.isArray(body.amenities) ? body.amenities : []),
          body.lat, body.lng, req.auth?.id,
          isDraft ? 'draft' : 'pending_review',  // Status
          isDraft,           // is_draft
          !isDraft,          // submitted_for_review
          !isDraft ? new Date().toISOString() : null,  // submitted_at
        ],
      );

      clearCachePattern('properties.');
      res.status(201).json({ data: normalizePropertyRow(result.rows[0]) });
    } catch (error) {
      next(error);
    }
  }
);
```

**PATCH /api/properties/:id/submit** (Convert draft to submitted for review)
```typescript
router.patch('/:id/submit', requireAuth, authorize('landlord', 'host'), 
  async (req, res, next) => {
    try {
      const propertyId = req.params.id;
      const userId = req.auth?.id;

      // Verify ownership and is draft
      const propRes = await query(
        `SELECT is_draft, submitted_for_review FROM properties 
         WHERE id = $1 AND landlord_id = $2`,
        [propertyId, userId],
      );

      if (!propRes.rows[0]) {
        return res.status(404).json({ error: 'Property not found or access denied.' });
      }

      if (!propRes.rows[0].is_draft) {
        return res.status(400).json({ 
          error: 'Property is not a draft or already submitted.' 
        });
      }

      const result = await query(
        `UPDATE properties 
         SET is_draft = false, 
             submitted_for_review = true,
             submitted_at = now(),
             status = 'pending_review'
         WHERE id = $1 AND landlord_id = $2
         RETURNING *`,
        [propertyId, userId],
      );

      clearCachePattern('properties.');
      res.json({ data: normalizePropertyRow(result.rows[0]) });
    } catch (error) {
      next(error);
    }
  }
);
```

### 1.4 🟠 HIGH: Landlord Dashboard Missing Draft Status Filter

**Issue:** Landlord view doesn't show draft status or allow filtering by draft/live/pending.

**Problems:**
1. No way to see which properties are drafts vs. submitted
2. No visual indicator of property status
3. Can't find abandoned drafts
4. No bulk actions on drafts (delete, publish multiple)

**Recommendation (Frontend):**

```dart
// Add to AddListingFlow or create new DraftsManagementScreen
class PropertyStatusFilter extends StatefulWidget {
  final Function(String? status) onStatusChanged;
  
  const PropertyStatusFilter({required this.onStatusChanged});

  @override
  State<PropertyStatusFilter> createState() => _PropertyStatusFilterState();
}

class _PropertyStatusFilterState extends State<PropertyStatusFilter> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _buildStatusChip('All', null),
        _buildStatusChip('Drafts', 'draft'),
        _buildStatusChip('Pending Review', 'pending_approval'),
        _buildStatusChip('Live', 'live'),
      ],
    );
  }

  Widget _buildStatusChip(String label, String? status) {
    final isSelected = status == _selectedStatus;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedStatus = status);
        widget.onStatusChanged(status);
      },
      backgroundColor: isSelected ? AppColors.primary : AppColors.white,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.white : AppColors.gray900,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

// In landlord properties view:
class LandlordPropertiesView extends StatefulWidget {
  @override
  State<LandlordPropertiesView> createState() => _LandlordPropertiesViewState();
}

class _LandlordPropertiesViewState extends State<LandlordPropertiesView> {
  String? _selectedStatus;
  List<Map<String, dynamic>> _properties = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => _loading = true);
    try {
      final repo = RemoteDatabaseRepository();
      final allProperties = await repo.loadPropertiesForUser(AppSession.currentUserId!);
      
      final filtered = _selectedStatus == null
        ? allProperties
        : allProperties.where((p) => p['display_status'] == _selectedStatus).toList();
      
      setState(() => _properties = filtered);
    } catch (e) {
      ModalUtils.showError(context, 'Error', 'Failed to load properties: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Listings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: PropertyStatusFilter(
              onStatusChanged: (status) {
                setState(() => _selectedStatus = status);
                _loadProperties();
              },
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _properties.isEmpty
                ? Center(
                    child: Text(
                      _selectedStatus == null
                        ? 'No properties yet'
                        : 'No $_selectedStatus properties',
                    ),
                  )
                : ListView.builder(
                    itemCount: _properties.length,
                    itemBuilder: (ctx, idx) {
                      final prop = _properties[idx];
                      final status = prop['display_status'] ?? 'unknown';
                      final isDraft = status == 'draft';
                      
                      return PropertyCard(
                        property: prop,
                        statusBadge: _buildStatusBadge(status),
                        trailing: isDraft
                          ? PopupMenuButton(
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  child: const Text('Edit'),
                                  onTap: () => _editProperty(prop),
                                ),
                                PopupMenuItem(
                                  child: const Text('Publish'),
                                  onTap: () => _publishDraft(prop),
                                ),
                                PopupMenuItem(
                                  child: const Text('Delete'),
                                  onTap: () => _deleteDraft(prop),
                                ),
                              ],
                            )
                          : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final (color, label) = switch (status) {
      'draft' => (Colors.grey[300], 'DRAFT'),
      'pending_approval' => (Colors.orange[300], 'PENDING'),
      'live' => (Colors.green[300], 'LIVE'),
      _ => (Colors.grey[300], status.toUpperCase()),
    };
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _editProperty(Map<String, dynamic> property) async {
    final result = await Navigator.pushNamed(
      context,
      '/listing_flow',
      arguments: property,
    );
    if (result != null) {
      _loadProperties();
    }
  }

  Future<void> _publishDraft(Map<String, dynamic> property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish Draft?'),
        content: Text('Ready to submit "${property['title']}" for review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final repo = RemoteDatabaseRepository();
        await repo.submitPropertyForReview(propertyId: property['id']);
        _loadProperties();
        ModalUtils.showSuccess(
          context,
          'Draft Published',
          'Your property has been submitted for admin review.',
        );
      } catch (e) {
        ModalUtils.showError(context, 'Error', 'Failed to publish: $e');
      }
    }
  }

  Future<void> _deleteDraft(Map<String, dynamic> property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final repo = RemoteDatabaseRepository();
        await repo.deleteProperty(propertyId: property['id']);
        _loadProperties();
        ModalUtils.showSuccess(context, 'Draft Deleted', 'Your draft has been removed.');
      } catch (e) {
        ModalUtils.showError(context, 'Error', 'Failed to delete: $e');
      }
    }
  }
}
```

### 1.5 🟠 HIGH: Draft Form State Not Preserved During Editing

**Issue:** When landlord saves draft and returns to edit, filled inputs might be lost if app restarts.

**Problems:**
1. Edited draft loses unsaved changes if user kills app
2. Images selected might not persist across edit sessions
3. User must re-enter all data if they navigate away
4. No auto-save during form editing (only manual save)

**Current Code:**
- [listing_flow.dart#L290-L310](listing_flow.dart#L290-L310) — `_saveDraft()` saves but only on explicit call
- [listing_flow.dart#L183-L226](listing_flow.dart#L183-L226) — `_loadDraft()` loads but only once in `initState()`

**Recommendation:**

**1. Auto-Save Draft on Form Changes:**
```dart
class _AddListingFlowState extends State<AddListingFlow> {
  Timer? _autoSaveTimer;
  static const Duration _autoSaveDebounceDuration = Duration(seconds: 2);

  void _onFormChanged() {
    // Debounce: don't save every keystroke, wait 2s of inactivity
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDebounceDuration, () {
      _saveDraft(showConfirmation: false);  // Silent save
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
    
    // Listen for form changes
    _title.addListener(_onFormChanged);
    _description.addListener(_onFormChanged);
    _neighborhood.addListener(_onFormChanged);
    _street.addListener(_onFormChanged);
    _building.addListener(_onFormChanged);
    _zip.addListener(_onFormChanged);
    _rentPrice.addListener(_onFormChanged);
    _serviceCharges.addListener(_onFormChanged);
    _securityDeposit.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _title.removeListener(_onFormChanged);
    _description.removeListener(_onFormChanged);
    // ... remove all listeners ...
    super.dispose();
  }
}
```

**2. Preserve Images Across Sessions:**
```dart
// When loading draft, also restore image URLs
Future<void> _loadDraft() async {
  final existing = widget.property;
  if (existing != null && existing.isNotEmpty) {
    // ... load from API property ...
    final existingImages = existing['images'];
    if (existingImages is List) {
      for (final image in existingImages) {
        final url = image?.toString();
        if (url != null && url.isNotEmpty) {
          // Preserve existing images
          _pickedPhotos.add(PickedPhoto(File(''), url: url, progress: 1.0));
        }
      }
    }
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_draftKey);
  if (raw != null) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      
      // Restore form state
      _propertyType = data['type'] ?? 'Apartment';
      _title.text = data['title'] ?? '';
      _description.text = data['description'] ?? '';
      // ... restore all fields ...

      // Restore picked photos (URLs only, files are temporary)
      final savedPhotos = data['saved_photos'] as List<dynamic>? ?? [];
      for (final photoUrl in savedPhotos) {
        if (photoUrl is String && photoUrl.isNotEmpty) {
          _pickedPhotos.add(
            PickedPhoto(File(''), url: photoUrl, progress: 1.0),
          );
        }
      }
    } catch (_) {}
  }
  
  if (mounted) setState(() => _loadingDraft = false);
}

Future<void> _saveDraft({bool showConfirmation = true}) async {
  final prefs = await SharedPreferences.getInstance();
  final photoUrls = _pickedPhotos
    .where((p) => p.url != null)
    .map((p) => p.url)
    .toList();

  await prefs.setString(
    _draftKey,
    jsonEncode({
      'type': _propertyType,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'country': _selectedCountry,
      'city': _selectedCity,
      'neighborhood': _neighborhood.text.trim(),
      'street': _street.text.trim(),
      'building': _building.text.trim(),
      'locationSearch': _locationSearch.text.trim(),
      'latitude': _selectedLatitude,
      'longitude': _selectedLongitude,
      'rentPrice': _rentPrice.text.trim(),
      'serviceCharges': _serviceCharges.text.trim(),
      'securityDeposit': _securityDeposit.text.trim(),
      'minimumStay': _minimumStay,
      'availableFrom': _availableFrom?.toIso8601String(),
      'amenities': _amenities,
      'saved_photos': photoUrls,  // ← NEW: persist image URLs
    }),
  );
  
  if (mounted && showConfirmation) {
    ModalUtils.showSuccess(context, "Draft Saved!",
        "Your progress has been safely tucked away. You can resume anytime.");
  }
}
```

**3. Show Draft Indicator While Editing:**
```dart
@override
Widget build(BuildContext context) {
  if (_loadingDraft) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  return Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: GestureDetector(
        onTap: _previousStep,
        child: const Icon(Icons.arrow_back, size: 28),
      ),
      title: Row(
        children: [
          Text('Add New Listing',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (widget.isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('DRAFT', style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              )),
            ),
        ],
      ),
      actions: [
        // Add "Save Draft" button to header
        TextButton.icon(
          onPressed: () => _saveDraft(showConfirmation: true),
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    ),
    body: // ... rest of UI ...
  );
}
```

---

## 2. LISTING CREATION FLOW

### 2.1 🔴 CRITICAL: Image Upload Race Condition

**Issue:** Property can be created BEFORE images finish uploading.

**Current Flow:**
```
1. Frontend compresses images locally
2. Frontend: POST to /uploads/async → returns jobId
3. Frontend: starts polling /uploads/job/{id}
4. Frontend: User clicks "Publish" before job completes
5. Backend: Property created with incomplete image URLs
6. Background: Image still processing
```

**Code Evidence:**
- [listing_flow.dart#L462-L530](listing_flow.dart#L462-L530) — Publishing checks `_pickedPhotos.any((p) => p.isUploading)` but this only checks initial upload, NOT async job completion
- [uploads.dart#L99-L160](uploads.dart#L99-L160) — Polling waits for job completion but frontend can still submit before polling finishes
- [uploads.ts#L67-L88](backend/src/routes/uploads.ts) — Returns jobId immediately, property creation doesn't wait

**Problems:**
1. Property created with `images: []` or partial URLs
2. Tenants see incomplete listings
3. Image processing failure silently ignored
4. No retry mechanism for failed images

**Reproducible Scenario:**
```
1. Landlord selects 5 images
2. Uploads async: takes 30 seconds per image
3. After 2 images upload, user clicks "Publish"
4. Property created with 2 images
5. Remaining 3 images still processing but not linked
```

**Code Timeline:**

[listing_flow.dart#L495-L515]:
```dart
// Guard: must be logged in
final token = AppSession.apiToken;
if (token == null) {
  ModalUtils.showError(context, "Session Expired",
      "Please log out and log back in, then try again.");
  return;
}

setState(() {
  _submitting = true;
  _isUploadingImages = true;
  _uploadProgress = 1.0;
});

try {
  // 1) Verify all photos are uploaded
  if (_pickedPhotos.any((p) => p.isUploading)) {
    throw Exception('Please wait for all photos to finish uploading.');
  }
  // ❌ BUG: Doesn't wait for async job completion!
  // Images may still be processing on server
```

**Recommendation:**

Option A (Synchronous):
```dart
// Wait for all async jobs before publishing
final uploadedUrls = <String>[];
for (final photo in _pickedPhotos) {
  if (photo.url == null) {
    throw Exception('Image #${_pickedPhotos.indexOf(photo)} failed to upload.');
  }
  uploadedUrls.add(photo.url!);
}
```

Option B (Server-side validation):
```typescript
// In properties.ts POST handler
const result = await query(
  `INSERT INTO properties (...)
   VALUES (...) 
   RETURNING *`,
  insertArgs,
);

// Verify all images are actually available
for (const imageUrl of imageList) {
  const isComplete = await verifyImageIsAccessible(imageUrl);
  if (!isComplete) {
    await query('DELETE FROM properties WHERE id = $1', [result.rows[0].id]);
    throw new Error(`Image not ready: ${imageUrl}`);
  }
}
```

### 2.2 🟠 HIGH: No Status Transition Validation

**Issue:** Properties created in `pending_review` status but no workflow prevents transitioning to `approved` without proper verification.

**Current Status Flow:**
```
pending_review → (admin approval)
                ↓
              approved → available / rented / maintenance
```

**Problem:**
- [properties.ts#L495-L510](backend/src/routes/properties.ts) allows ANY landlord to PATCH `/properties/:id/status` with ANY status
- No validation that property completed verification
- No admin-only gate for `pending_review → approved`

**Code Evidence:**
```typescript
// properties.ts line 495+
const allowedStatuses = ['available', 'pending_booking', 'fully_booked', 'rented', 'maintenance'];
if (typeof status !== 'string' || !allowedStatuses.includes(status)) {
  return res.status(400).json({ error: `Status must be one of: ${allowedStatuses.join(', ')}.` });
}
// ❌ Missing: Verify `status` in ['available', ...] ONLY if current status is NOT 'pending_review'
// ❌ Missing: Verify verification completed
```

**Recommendation:**
```typescript
const verificationRes = await query(
  `SELECT status FROM verifications WHERE user_id = $1 AND status = 'approved' LIMIT 1`,
  [req.auth?.id],
);

if (!verificationRes.rows[0]) {
  return res.status(403).json({ error: 'Verification not yet approved by admin.' });
}

// Only allow transitioning FROM approved statuses, not FROM pending_review
const currentProp = await query(`SELECT status FROM properties WHERE id = $1`, [propertyId]);
if (currentProp.rows[0].status === 'pending_review') {
  return res.status(403).json({ error: 'Property not yet approved for listing.' });
}
```

### 2.3 🟠 HIGH: No Idempotency on Property Creation

**Issue:** Network timeout on property creation can result in duplicate submissions.

**Scenario:**
1. Landlord POSTs property with 5 images
2. Request times out after 29s (while mediaWorker still processing)
3. Frontend retries (or user retries manually)
4. Two identical properties created

**Evidence:**
- [uploads.dart#L99-L110](uploads.dart#L99-L110) — No `Idempotency-Key` sent to `/properties/from-listing`
- [properties.ts#L830-L850](backend/src/routes/properties.ts) — No idempotency check on POST

**Recommendation:**
```dart
// listing_flow.dart
final idempotencyKey = 'listing_${DateTime.now().millisecondsSinceEpoch}_${AppSession.currentUserId}';
final propertyPayload = {
  ...payload,
  '__idempotency_key': idempotencyKey,  // Backend will ignore but can use for deduplication
};
```

Backend:
```typescript
router.post('/from-listing', requireAuth, async (req, res, next) => {
  const idempotencyKey = req.body.__idempotency_key || req.headers['idempotency-key'];
  
  if (idempotencyKey) {
    const existing = await redis.get(`idempotency:${idempotencyKey}`);
    if (existing) {
      return res.status(201).json({ data: JSON.parse(existing), cached: true });
    }
  }
  
  // ... create property ...
  
  if (idempotencyKey) {
    await redis.setex(`idempotency:${idempotencyKey}`, 3600, JSON.stringify(result));
  }
});
```

---

## 3. IMAGE UPLOAD SYSTEM

### 3.1 🔴 CRITICAL: Async Job Polling Has No Timeout

**Issue:** Frontend polls indefinitely if job hangs on server.

**Code:**
```dart
// uploads.dart lines 110-145
while (!isCancelled) {
  await Future.delayed(const Duration(seconds: 2));  // Poll every 2s
  if (isCancelled) break;
  
  final jobRes = await client.get(
    Uri.parse('$base/uploads/job/$jobId'),
    headers: {'Authorization': 'Bearer ${token ?? AppSession.apiToken}'}
  );
  
  if (jobRes.statusCode == 200) {
    final jobData = jsonDecode(jobRes.body)['data'];
    final status = jobData['status'];
    
    if (status == 'completed') {
       finalUrl = jobData['result']['url'] ?? jobData['result']['secure_url'];
       break;  // ✅ Success
    } else if (status == 'failed') {
       throw Exception('Background processing failed: ${jobData['error']}');  // ✅ Failure
    } else {
       // 🔄 Still processing...
    }
  }
  // ❌ NO TIMEOUT! Will loop forever if job never completes
}
```

**Problems:**
1. Job crash on server → frontend hangs forever
2. User leaves app open → battery drain, network usage
3. No error reporting to landlord

**Recommendation:**
```dart
const Duration maxWaitTime = Duration(minutes: 10);
final startTime = DateTime.now();

while (!isCancelled) {
  if (DateTime.now().difference(startTime) > maxWaitTime) {
    throw TimeoutException('Image processing took too long. Please try again.');
  }
  
  await Future.delayed(const Duration(seconds: 2));
  // ... polling code ...
}
```

### 3.2 🟠 HIGH: Image Compression Quality Loss Not Disclosed

**Issue:** Images compressed to WebP 80% quality without user consent.

**Frontend Compression:**
- [image_upload_service.dart#L47-L60](image_upload_service.dart#L47-L60):
```dart
final xfile = await FlutterImageCompress.compressAndGetFile(
  input.absolute.path,
  targetPath,
  quality: 82,           // ← 82% quality
  format: CompressFormat.webp,  // ← Converts to WebP
  minWidth: 1280,
  minHeight: 720,
);
```

**Backend Compression:**
- [mediaWorker.ts#L40-L50](backend/src/workers/mediaWorker.ts):
```typescript
if (isImage) {
  processedBuffer = await sharp(filePath)
    .resize(1920, 1080, { fit: 'inside', withoutEnlargement: true })
    .webp({ quality: 80 })  // ← Another 80% compression
    .toBuffer();
```

**Problem:**
- Double compression (frontend + backend) = quality degradation
- Users may not understand why their photos look worse
- No option to use lossless format
- Professional photographers lose detail

**Recommendation:**
```dart
// Show dialog before compression
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Image Optimization'),
    content: const Text('Images will be compressed to WebP format (80% quality) for faster uploads.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      TextButton(
        onPressed: () {
          Navigator.pop(ctx);
          _uploadPickedPhoto(photo);  // Proceed with compression
        },
        child: const Text('Proceed'),
      ),
    ],
  ),
);
```

Or add quality selector:
```dart
int _imageQuality = 82;  // User-configurable

final xfile = await FlutterImageCompress.compressAndGetFile(
  input.absolute.path,
  targetPath,
  quality: _imageQuality,  // ← Configurable
  format: CompressFormat.webp,
);
```

### 3.3 🟠 HIGH: No Upload Resumption on Network Failure

**Issue:** Network interruption = entire image re-upload from scratch.

**Problem:**
- Large images (50+ MB) on slow connections fail frequently
- No chunked/resumable upload support
- User frustration with repeated failures

**Code:**
- [uploads.dart#L60-L90](uploads.dart#L60-L90) — Streams entire file, no checkpointing
- [uploads.ts#L45-L65](backend/src/routes/uploads.ts) — Accepts file in single request

**Recommendation:** Use TUS protocol for resumable uploads.
```typescript
// Backend: Support range requests
router.post('/upload-chunk', requireAuth, async (req, res) => {
  const { uploadId, chunkIndex, totalChunks } = req.body;
  const chunk = req.file.buffer;
  
  // Store chunk
  await storeChunk(uploadId, chunkIndex, chunk);
  
  // Check if all chunks received
  const received = await getChunkCount(uploadId);
  if (received === totalChunks) {
    const assembled = await assembleChunks(uploadId);
    const result = await uploadToCloudinary(assembled);
    await cleanupChunks(uploadId);
    res.json({ result });
  } else {
    res.json({ status: 'chunk_received', received, total: totalChunks });
  }
});
```

### 3.4 🟠 HIGH: Image URL Validation Incomplete

**Issue:** URLs stored without verification that image is actually accessible.

**Code:**
- [properties.ts#L845-L860](backend/src/routes/properties.ts) — Creates property immediately after receiving URL list
- No validation that URLs return HTTP 200 before property goes live

**Problems:**
1. Cloudinary upload returns success but image still processing
2. Temporary URLs expire before tenant views property
3. Dead links in property listings

**Recommendation:**
```typescript
async function verifyImageAccessibility(url: string, retries = 3): Promise<boolean> {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, { method: 'HEAD', timeout: 5000 });
      if (res.status === 200) return true;
      
      if (attempt < retries) {
        await new Promise(r => setTimeout(r, 1000 * attempt));  // Exponential backoff
      }
    } catch (error) {
      console.error(`Image verification attempt ${attempt}/${retries} failed for ${url}`, error);
    }
  }
  return false;
}

// In property creation:
const imageList = Array.isArray(body.images) ? body.images : [body.image_url];
for (const imageUrl of imageList) {
  const isAccessible = await verifyImageAccessibility(imageUrl);
  if (!isAccessible) {
    return res.status(400).json({ 
      error: 'One or more images are not yet available. Please wait and try again.' 
    });
  }
}
```

### 3.5 🟠 HIGH: Missing Image Metadata Validation

**Issue:** No validation of image dimensions, file size, or metadata before uploading.

**Current:**
```dart
// image_upload_service.dart
const int _maxConcurrentUploads = 4;  // ← Only limits concurrency, not size
```

**Problems:**
1. Extremely large files (1GB video) can be selected
2. No user feedback before attempting upload
3. Memory exhaustion on low-end phones
4. Excessive Cloudinary storage usage

**Recommendation:**
```dart
// Before upload:
const int maxFileSizeBytes = 100 * 1024 * 1024;  // 100 MB
const double maxPixelsForImage = 100000000;  // 100 megapixels

for (final file in selectedFiles) {
  final fileSize = await file.length();
  if (fileSize > maxFileSizeBytes) {
    throw Exception('File too large: ${fileSize ~/ 1024 / 1024}MB (max: 100MB)');
  }
  
  if (file.path.toLowerCase().endsWith(RegExp(r'\.(jpg|png|webp|jpeg)$'))) {
    final image = img.decodeImage(file.readAsBytesSync());
    if (image != null) {
      final pixels = image.width * image.height;
      if (pixels > maxPixelsForImage) {
        throw Exception('Image too high resolution: $pixels pixels');
      }
    }
  }
}
```

### 3.6 🟡 MEDIUM: Image Cleanup on Property Deletion Incomplete

**Issue:** Deleting property doesn't clean up Cloudinary images.

**Code:**
- [properties.ts#L490-L510](backend/src/routes/properties.ts) — DELETE removes DB row only
- [delete-all-properties-with-images.js](backend/scripts/delete-all-properties-with-images.js) — Bulk cleanup exists but not integrated into normal deletion

**Problems:**
1. Orphaned images in Cloudinary
2. Storage cost accumulates
3. Manual cleanup required
4. GDPR violation: images not deleted with property

**Recommendation:**
```typescript
router.delete('/:id', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
  try {
    // Get property details including images
    const propRes = await query(
      'SELECT image_url, images FROM properties WHERE id = $1 AND landlord_id = $2',
      [req.params.id, req.auth?.id],
    );
    
    if (propRes.rowCount === 0) {
      return res.status(404).json({ error: 'Property not found or access denied.' });
    }
    
    const { image_url, images } = propRes.rows[0];
    const imagesToDelete = new Set<string>();
    
    if (image_url) imagesToDelete.add(image_url);
    if (Array.isArray(images)) {
      images.forEach(url => imagesToDelete.add(url));
    }
    
    // Delete from Cloudinary (in background)
    for (const imageUrl of imagesToDelete) {
      const publicId = extractPublicIdFromUrl(imageUrl);
      if (publicId) {
        deleteFromCloudinary(publicId).catch(err => 
          console.error(`Failed to delete Cloudinary image ${publicId}:`, err)
        );
      }
    }
    
    // Delete from DB
    const result = await query(
      'DELETE FROM properties WHERE id = $1 AND landlord_id = $2 RETURNING id',
      [req.params.id, req.auth?.id],
    );
    
    clearCachePattern('properties.');
    res.json({ data: { id: result.rows[0].id, deleted: true } });
  } catch (error) {
    next(error);
  }
});
```

---

## 4. SCALABILITY ISSUES

### 4.1 🟠 HIGH: Cache Invalidation Creates Race Condition

**Issue:** Properties cache cleared on every create/update, causing cache stampedes.

**Code:**
- [properties.ts#L810](backend/src/routes/properties.ts): `clearCachePattern('properties.');`
- [properties.ts#L850](backend/src/routes/properties.ts): `clearCachePattern('properties.');`

**Scenario:**
1. 100 tenants viewing property list (all cached)
2. Landlord updates property
3. Cache cleared → ALL 100 requests miss cache
4. All 100 hit DB simultaneously
5. Database overload

**Problem:**
- Linear scaling: N updates = N cache clears
- No selective invalidation (e.g., only clear affected properties)
- No stale-while-revalidate header on write

**Recommendation:**
```typescript
// Selective invalidation
async function invalidatePropertyCache(propertyId: string) {
  await cache.del(`cache:properties.byId:${propertyId}`);
  
  // Soft invalidate list queries (they'll revalidate in background)
  await cache.del(`cache:properties.list:*`);
}

// Use stale-while-revalidate
const existingCache = await getCache(cacheKey);
if (existingCache && Date.now() - existingCache.timestamp < CACHE_TTL) {
  res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=300');
  return res.json({ data: existingCache.rows, cached: true });
}
```

### 4.2 🟠 HIGH: Media Queue Has No Dead Letter Handling

**Issue:** Failed image processing jobs are lost or cause memory leaks.

**Code:**
- [queue.ts](backend/src/services/queue.ts) — Just creates queue, no error handling
- [mediaWorker.ts#L35-L95](backend/src/workers/mediaWorker.ts) — Only logs failures

**Problems:**
1. Failed jobs accumulate in Redis
2. No retry exponential backoff configured
3. No dead letter queue for permanent failures
4. User left wondering what happened to their upload

**Recommendation:**
```typescript
export const mediaQueue = new Queue('media-processing', {
  connection,
  defaultJobOptions: {
    attempts: 5,  // ← Retry up to 5 times
    backoff: {
      type: 'exponential',
      delay: 2000,  // Start at 2s, then 4s, 8s, etc.
    },
    removeOnComplete: {
      age: 3600,  // Remove successful jobs after 1 hour
    },
    removeOnFail: {
      age: 86400,  // Keep failed jobs for 24 hours for debugging
    },
  },
});

// Add dead letter queue processor
const deadLetterQueue = new Queue('media-processing-dlq', { connection });

mediaQueue.on('failed', async (job, err) => {
  if (job.attemptsMade >= job.opts.attempts) {
    // Move to DLQ
    await deadLetterQueue.add('failed-job', {
      originalJob: job.data,
      error: err.message,
      attemptsMade: job.attemptsMade,
    });
    
    // Notify landlord
    const userId = job.data.ownerId;
    await sendNotification(userId, {
      title: 'Image Upload Failed',
      body: 'Your image processing failed after multiple retries. Please try uploading again.',
    });
  }
});
```

### 4.3 🟠 HIGH: No Rate Limiting on Image Uploads

**Issue:** Single user can overwhelm Cloudinary with massive uploads.

**Problems:**
1. Denial of service: User uploads 1000 images, saturates Cloudinary quota
2. Cost explosion: Unexpected Cloudinary bills
3. Other users blocked: Shared resource exhausted

**Recommendation:**
```typescript
import rateLimit from 'express-rate-limit';

const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,  // Max 100 uploads per 15 min
  keyGenerator: (req) => req.auth?.id,  // Per-user limit
  message: 'Too many uploads. Please wait before trying again.',
});

router.post('/async', uploadLimiter, requireAuth, async (req, res, next) => {
  // ... existing code ...
});
```

### 4.4 🟡 MEDIUM: No Listing Publishing Rate Limit

**Issue:** Landlord can spam create properties endpoint.

**Problems:**
1. Listings database fills with spam
2. Tenant search results polluted
3. Admin moderation backlog

**Recommendation:**
```typescript
const createPropertyLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,  // 1 hour
  max: 10,  // Max 10 properties per hour per landlord
  keyGenerator: (req) => req.auth?.id,
  message: 'You have created too many properties. Please wait before creating more.',
});

router.post('/', createPropertyLimiter, requireAuth, authorize('landlord'), async (req, res) => {
  // ...
});
```

---

## 5. VERIFICATION & LISTING LIFECYCLE

### 5.1 🟡 MEDIUM: Verification Workflow Not Enforced

**Issue:** Landlord can list properties before verification is approved.

**Code:**
- [listing_flow.dart#L404-L440](listing_flow.dart#L404-L440) — Shows warning if `currentUserVerified != true` but doesn't prevent submission
- [properties.ts#L810-L850](backend/src/routes/properties.ts) — Creates property regardless of verification status

**Problems:**
1. Unverified landlords can publish immediately
2. Backend doesn't check verification before creating property
3. Properties appear live even though landlord unverified

**Current Code (Frontend):**
```dart
if (AppSession.currentUserVerified != true) {
  await _saveDraft(showConfirmation: false);
  if (!mounted) return;
  showDialog(
    context: context,
    // ... shows warning dialog ...
  );
  return;  // ✅ Stops submission
}
```

**BUT Backend doesn't validate!**

**Recommendation (Backend):**
```typescript
async function handleCreateProperty(req, res, next) {
  const userId = req.auth?.id;
  
  // Verify user is approved
  const verRes = await query(
    `SELECT status FROM verifications 
     WHERE user_id = $1 AND status = 'approved' 
     LIMIT 1`,
    [userId],
  );
  
  if (!verRes.rows[0]) {
    return res.status(403).json({ 
      error: 'Your account is not yet verified. Complete verification to publish listings.' 
    });
  }
  
  // ... continue with property creation ...
}
```

### 5.2 🟡 MEDIUM: No Listing Expiration Policy

**Issue:** Properties can stay listed indefinitely without activity.

**Problems:**
1. Stale listings clutter search results
2. Landlord forgets property exists, property no longer available
3. Tenant wastes time on dead listings
4. No data cleanup

**Recommendation:**
```sql
ALTER TABLE properties ADD COLUMN IF NOT EXISTS last_activity_at timestamptz DEFAULT now();
ALTER TABLE properties ADD COLUMN IF NOT EXISTS expires_at timestamptz;

-- Mark property as expired if no bookings/activity for 6 months
UPDATE properties 
SET status = 'expired'
WHERE COALESCE(p.status, 'pending_review') = 'approved'
  AND last_activity_at < now() - INTERVAL '6 months';
```

---

## 6. API & DATA VALIDATION ISSUES

### 6.1 🟡 MEDIUM: No Request Body Size Limits

**Issue:** POST to `/properties` accepts unlimited JSON payload.

**Problems:**
1. Memory exhaustion if client sends 1GB JSON
2. Database buffer overflow
3. DoS vulnerability

**Recommendation:**
```typescript
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb' }));
```

### 6.2 🟡 MEDIUM: Amenities Array Not Validated

**Issue:** Frontend sends amenities array but backend accepts any values.

**Code:**
```dart
// listing_flow.dart — valid amenities defined
final Map<String, bool> _amenities = {
  'Wifi': false,
  'Water included': false,
  'Parking': false,
  // ... 14 more ...
};
```

**But Backend:**
```typescript
// properties.ts — accepts ANY amenities
const amenityList = Array.isArray(body.amenities) ? body.amenities : [];
// No validation that amenities are in predefined list
```

**Problem:**
- Inconsistent data in database
- Frontend dropdown may show "Free Margaritas" if attacker sends it
- Search filters broken (can't find by exact amenity)

**Recommendation:**
```typescript
const VALID_AMENITIES = [
  'Wifi',
  'Water included',
  'Electricity included',
  'Heating',
  'Air Conditioning',
  'Hot Water',
  'Parking',
  'Security',
  'CCTV',
  // ... etc
];

const validateAmenities = (amenities: any): string[] => {
  if (!Array.isArray(amenities)) return [];
  return amenities.filter(a => VALID_AMENITIES.includes(a));
};

// In handler:
const amenityList = validateAmenities(body.amenities);
```

### 6.3 🟡 MEDIUM: No Input Sanitization for Descriptions

**Issue:** Long descriptions stored without truncation/validation.

**Problems:**
1. XSS vulnerability if text displayed unsanitized
2. Database bloat (PostgreSQL TOAST)
3. Mobile rendering broken (description too long)

**Recommendation:**
```typescript
const MAX_TITLE_LENGTH = 200;
const MAX_DESCRIPTION_LENGTH = 5000;

if (body.title?.length > MAX_TITLE_LENGTH) {
  return res.status(400).json({ 
    error: `Title must be ${MAX_TITLE_LENGTH} chars or less` 
  });
}

if (body.description?.length > MAX_DESCRIPTION_LENGTH) {
  return res.status(400).json({ 
    error: `Description must be ${MAX_DESCRIPTION_LENGTH} chars or less` 
  });
}

// Sanitize for XSS
import sanitizeHtml from 'sanitize-html';
const sanitizedDescription = sanitizeHtml(body.description, {
  allowedTags: [],  // Strip all HTML
  allowedAttributes: {},
});
```

---

## 7. MISSING INTEGRATIONS

### 7.1 🟡 MEDIUM: No Analytics on Listing Creation

**Issue:** No tracking of:
- How many users start vs. complete listing
- Where users drop off (which step)
- How long property takes to publish
- Image upload success rate

**Code:**
- [listing_flow.dart#L510-L560](listing_flow.dart#L510-L560) — Calls `AnalyticsService.logEvent()` only AFTER success
- No intermediate tracking

**Recommendation:**
```dart
@override
void initState() {
  super.initState();
  AnalyticsService.logEvent(
    eventType: 'listing_flow_started',
    propertyType: _propertyType,
    isEditing: widget.isEditing,
  );
}

void _nextStep() {
  if (_currentStep < _totalSteps) {
    AnalyticsService.logEvent(
      eventType: 'listing_flow_step_completed',
      step: _currentStep,
      currentStep: _currentStep + 1,
    );
    // ... navigate ...
  }
}

// On error:
catch (e) {
  AnalyticsService.logEvent(
    eventType: 'listing_flow_error',
    step: _currentStep,
    error: e.toString(),
  );
}
```

### 7.2 🟡 MEDIUM: No Webhook for Image Processing Completion

**Issue:** Frontend polls status indefinitely; should use webhooks.

**Current:**
- Frontend polls `/uploads/job/{id}` every 2 seconds
- Inefficient: 60 wasted requests if 2-min job

**Better:**
```typescript
// mediaWorker.ts — call webhook when complete
mediaWorker.on('completed', async (job) => {
  const ownerId = job.data.ownerId;
  const imageUrl = job.returnvalue.secure_url;
  
  // POST to landlord's webhook URL or Firebase FCM
  await notifyLandlordImageReady(ownerId, imageUrl);
});

// Frontend: subscribe to real-time events
AppSession.realtimeConnection.subscribe(
  'image_upload:${sessionId}',
  (event) => {
    if (event.type === 'completed') {
      setState(() {
        _imageUrls.add(event.data.url);
      });
    }
  }
);
```

### 7.3 🟡 MEDIUM: No Integration with Tenant Profile Preferences

**Issue:** Listing doesn't consider tenant profile budget/preferences during creation.

**Recommendation:**
```dart
// After publishing, show matching tenants
if (publishedProperty != null) {
  final matchingTenants = await repo.findMatchingTenants(
    budget: _rentPrice,
    category: _propertyType,
    city: _selectedCity,
  );
  
  if (matchingTenants.isNotEmpty) {
    ModalUtils.showInfo(
      context,
      'Potential Tenants Found',
      'We found ${matchingTenants.length} tenants looking for properties like yours!',
    );
  }
}
```

---

## 8. SUMMARY TABLE

| Category | ID | Severity | Issue | Status |
|----------|----|-----------|----|--------|
| Drafts | 1.1 | 🔴 CRITICAL | No persistent backend draft storage | NOT IMPLEMENTED |
| Drafts | 1.2 | 🟠 HIGH | No automatic draft expiration | NOT IMPLEMENTED |
| Drafts | 1.3 | 🔴 CRITICAL | Draft properties publicly exposed | NOT IMPLEMENTED |
| Drafts | 1.4 | 🟠 HIGH | Landlord dashboard missing draft status filter | NOT IMPLEMENTED |
| Drafts | 1.5 | 🟠 HIGH | Draft form state not preserved during editing | NEEDS FIX |
| **Creation Flow** | 2.1 | 🔴 CRITICAL | Image upload race condition | NEEDS FIX |
| Creation Flow | 2.2 | 🟠 HIGH | No status transition validation | NEEDS FIX |
| Creation Flow | 2.3 | 🟠 HIGH | No idempotency on property creation | NEEDS FIX |
| **Image Upload** | 3.1 | 🔴 CRITICAL | Async job polling has no timeout | NEEDS FIX |
| Image Upload | 3.2 | 🟠 HIGH | Double compression (frontend + backend) | NEEDS FIX |
| Image Upload | 3.3 | 🟠 HIGH | No resumable upload on network failure | NOT IMPLEMENTED |
| Image Upload | 3.4 | 🟠 HIGH | No image URL validation after upload | NEEDS FIX |
| Image Upload | 3.5 | 🟠 HIGH | Missing image metadata validation | NEEDS FIX |
| Image Upload | 3.6 | 🟡 MEDIUM | Image cleanup on deletion incomplete | NEEDS FIX |
| **Scalability** | 4.1 | 🟠 HIGH | Cache invalidation race condition | NEEDS REFACTOR |
| Scalability | 4.2 | 🟠 HIGH | Media queue missing error handling | NEEDS IMPLEMENTATION |
| Scalability | 4.3 | 🟠 HIGH | No rate limiting on uploads | NEEDS IMPLEMENTATION |
| Scalability | 4.4 | 🟡 MEDIUM | No listing creation rate limit | NEEDS IMPLEMENTATION |
| **Verification** | 5.1 | 🟡 MEDIUM | Verification workflow not enforced backend | NEEDS FIX |
| Verification | 5.2 | 🟡 MEDIUM | No listing expiration policy | NOT IMPLEMENTED |
| **API/Data** | 6.1 | 🟡 MEDIUM | No request body size limits | NEEDS IMPLEMENTATION |
| API/Data | 6.2 | 🟡 MEDIUM | Amenities array not validated | NEEDS IMPLEMENTATION |
| API/Data | 6.3 | 🟡 MEDIUM | No input sanitization | NEEDS IMPLEMENTATION |
| **Integration** | 7.1 | 🟡 MEDIUM | No analytics on listing creation | NEEDS IMPLEMENTATION |
| Integration | 7.2 | 🟡 MEDIUM | No webhook for image processing | NEEDS IMPLEMENTATION |
| Integration | 7.3 | 🟡 MEDIUM | No integration with tenant preferences | NEEDS IMPLEMENTATION |

---

## 9. RECOMMENDED FIX PRIORITY

### Phase 1: Critical Fixes (Security & Data Loss) — Week 1
1. **1.3** Enforce draft visibility at backend → Never expose drafts to public
2. **2.1** Fix image upload race condition → Add timeout to async job polling
3. **3.1** Add timeout to media queue polling → Prevent infinite loops
4. **1.1** Implement persistent draft storage → Database table + API endpoints

### Phase 2: High Priority Fixes (Data Integrity & UX) — Week 2
1. **1.4** Implement landlord dashboard with draft filtering → Show status and allow bulk actions
2. **1.5** Auto-save draft form state → Preserve inputs and images across sessions
3. **2.2** Enforce status transition validation → Backend verification check
4. **2.3** Add idempotency to property creation → Prevent duplicate listings
5. **3.4** Validate image URLs before listing → HEAD request check
6. **4.2** Implement dead letter queue → Proper job failure handling

### Phase 3: Medium Priority (Scalability) — Week 3-4
1. **4.1** Fix cache invalidation → Selective invalidation + stale-while-revalidate
2. **4.3** Rate limiting on uploads → Per-user limits
3. **5.1** Backend verification enforcement → Reject unverified landlords
4. **3.5** Image metadata validation → Size/dimension checks
5. **1.2** Draft expiration policy → Auto-cleanup after 60 days

### Phase 4: Nice-to-Have (Features) — Week 5+
1. **7.1** Analytics tracking → Listing flow funnel
2. **7.2** Webhook notifications → Real-time image processing
3. **3.3** Resumable uploads → TUS protocol
4. **1.2** Draft expiration → Cron job cleanup

---

## 10. TESTING RECOMMENDATIONS

**Scenarios to test:**
1. **Network Failure:** Kill network during image upload → Should queue and retry, not hang
2. **Slow Upload:** Upload 100MB video on 1Mbps connection → Should support resumption
3. **Concurrent Edits:** Open listing on 2 devices, edit simultaneously → Last write wins or conflict error
4. **Server Crash:** Crash mediaWorker while processing → Jobs should retry, not disappear
5. **Spam Property Creation:** Create 100 properties in 1 minute → Should be rate-limited
6. **Malicious Input:** Send 1GB description → Should be rejected
7. **Unverified Landlord:** Try to publish before verification → Should fail at backend

---

## Conclusion

The listing flow has **fundamental architectural gaps** that compromise data integrity and scalability. The most critical issue is the **image upload race condition** (2.1), which allows properties to be published before images finish uploading. This must be fixed immediately.

Additionally, **zero persistent backend draft storage** (1.1) means users lose all progress on app uninstall, and **missing async job timeout** (3.1) can cause UI hangs indefinitely.

With the fixes outlined above, the system will be:
- ✅ Reliable (no data loss, proper error handling)
- ✅ Scalable (rate limiting, selective caching)
- ✅ Verified (enforcement of verification workflow)
- ✅ Fast (optimized image handling, webhooks)
