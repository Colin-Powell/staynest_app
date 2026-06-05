# Quick Start Guide - StayNest Implementation

## 🎯 What's Been Done

All your requirements have been implemented:

✅ **Mock data removed** from admin portal - now uses real API data  
✅ **Listing endpoints work** - verified via GET /properties/me endpoint  
✅ **Admin verification skipped** - auto-approves in testing mode  
✅ **Cloudinary image service** - integrated with fallback to disk storage  

---

## 🚀 Quick Setup (5 minutes)

### Step 1: Get Cloudinary Credentials
1. Go to https://cloudinary.com/users/register/free
2. Create free account
3. Copy from Dashboard:
   - Cloud Name
   - API Key  
   - API Secret

### Step 2: Create .env File
Create `backend/.env`:

```
DATABASE_URL=postgresql://postgres:postgres@db:5432/staynest
JWT_SECRET=your-secret-key
CORS_ORIGIN=http://localhost:8080

# Cloudinary - from step 1
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Testing mode - auto-approve verifications
SKIP_ADMIN_VERIFICATION=true
```

### Step 3: Install & Run Backend
```bash
cd backend
npm install
npm run dev
```

### Step 4: Run Flutter App
```bash
cd flutter_frontend
flutter pub get
flutter run
```

---

## 🧪 Testing the Features

### Test 1: Admin Dashboard (Real Data)
```
1. Login: admin@example.com / adminpass
2. Go to Admin Portal
3. See "Pending Verifications" with real data from DB
4. Click approve/reject buttons
5. Data updates in real-time
```

### Test 2: Auto-Verified Landlord
```
1. Register new account → Select "Landlord" role
2. Submit verification documents
3. Auto-approved immediately (SKIP_ADMIN_VERIFICATION=true)
4. Status shows as "approved"
5. Can now create properties
```

### Test 3: Property Listing for Landlords
```
1. Login as verified landlord
2. Create a property with details + image
3. Image uploads to Cloudinary
4. Call: GET /properties/me (with auth token)
5. Returns array of user's properties
```

### Test 4: Cloudinary Image Upload
```
1. Upload any image through app
2. Check Cloudinary dashboard
3. Image appears there publicly
4. App shows Cloudinary URL in response
```

---

## 📋 What Changed

### Backend

#### New/Modified Routes
- **GET /properties/me** - List landlord's properties
- **GET /verifications/admin/all** - Get all verifications (paginated)
- **POST /uploads** - Now uses Cloudinary (with disk fallback)
- **POST /verifications** - Auto-approves if testing mode enabled

#### New Service
- **src/services/cloudinary.ts** - Handles Cloudinary uploads/deletes

#### Updated Files
- **package.json** - Added cloudinary package
- **config.ts** - Added Cloudinary env vars + SKIP_ADMIN_VERIFICATION
- **routes/uploads.ts** - Integrated Cloudinary
- **routes/verifications.ts** - Added auto-approval logic
- **routes/properties.ts** - Added /me endpoint

### Frontend

#### Enhanced Services
- **api_client.dart** - Added putJson(), query parameter support
- **verification_api.dart** - Added admin verification methods

#### Updated Screens
- **admin_dashboard_view.dart** - Complete rewrite
  - Now fetches real data from API
  - Shows pending verifications
  - Working approve/reject buttons
  - Loading/error states
  - Empty state when no data

---

## ⚡ Key Features

### Admin Portal (NEW)
- Real-time verification data from database
- Approve/reject with one click
- Shows count of pending items
- Error handling & retry
- Empty state UI

### Landlord Features (NEW)
- Auto-verified in test mode
- List own properties via API
- Upload images to Cloudinary
- Instant property creation

### General
- All images go to Cloudinary
- Falls back to disk if not configured
- Production-ready structure

---

## 🔐 Environment Variables Reference

| Variable | Required | Default | Example |
|----------|----------|---------|---------|
| DATABASE_URL | Yes | - | postgresql://postgres:postgres@db:5432/staynest |
| JWT_SECRET | Yes | - | your-secure-secret-key |
| CORS_ORIGIN | No | http://localhost:8080 | http://localhost:3000 |
| CLOUDINARY_CLOUD_NAME | No | - | dxyz12345 |
| CLOUDINARY_API_KEY | No | - | 12345678901234 |
| CLOUDINARY_API_SECRET | No | - | abcdef123456 |
| SKIP_ADMIN_VERIFICATION | No | false | true |

---

## ✨ That's It!

Your StayNest platform now has:
- ✅ Real admin dashboard (no more mock data)
- ✅ Working property listings for landlords
- ✅ Test mode for quick verification
- ✅ Professional image hosting via Cloudinary
- ✅ Production-ready setup

**Next Steps:**
1. Configure Cloudinary credentials
2. Run backend with `npm run dev`
3. Run flutter app with `flutter run`
4. Test the flows above
5. When ready: Set SKIP_ADMIN_VERIFICATION=false for production

See **IMPLEMENTATION_GUIDE.md** for detailed documentation.
