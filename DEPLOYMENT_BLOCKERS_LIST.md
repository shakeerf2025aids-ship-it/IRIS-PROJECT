# IRIS Glaucoma MVP - Deployment Blockers List

**Date:** June 16, 2026  
**Audit Status:** Complete  
**Total Blockers:** 3 CRITICAL + 2 IMPORTANT

---

## Deployment Readiness Status

| Status | Count | Description |
|--------|-------|-------------|
| 🔴 Blocking Production | 3 | Must fix before any deployment |
| 🟡 Important to Fix | 2 | Should fix before first release |
| 🟢 Can Defer | 0 | All identified issues should be addressed |

---

## 🔴 CRITICAL BLOCKERS (Must Fix)

### BLOCKER #1: Camera Permissions Not Declared

**Status:** 🔴 BLOCKING DEPLOYMENT  
**Severity:** CRITICAL  
**Component:** Android Native  
**File:** `android/app/src/main/AndroidManifest.xml`

**Issue:**
Camera permission is NOT declared in AndroidManifest.xml. Android requires permission declaration even though Flutter's image_picker requests runtime permissions. Without this, the app will crash with SecurityException when user tries to use camera.

**Impact:**
- ✅ Affects: ~50% of user base (Android users)
- ✅ Severity: **Complete feature failure** (app crash)
- ✅ Reproducibility: **100% reproducible**

**Current Code (BROKEN):**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <!-- App configuration -->
    </application>
    <!-- MISSING: Camera permissions -->
</manifest>
```

**What Happens When User Tries Camera:**
1. User opens scan screen ✅
2. User clicks "Capture Image" button ✅
3. App requests permission ✅
4. User grants permission ✅
5. **App CRASHES** ❌
6. Error: `SecurityException: Permission denied (errno 1)`

**Required Fix:**
Add permissions to `<manifest>` tag (NOT inside `<application>`):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add these lines INSIDE manifest but OUTSIDE application -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    
    <application>
        <!-- App configuration -->
    </application>
</manifest>
```

**Fix Verification:**
```
1. Edit: android/app/src/main/AndroidManifest.xml
2. Add 4 permission lines
3. Build: flutter build apk --release
4. Install on Android device/emulator
5. Go to scan screen
6. Click "Capture Image"
7. Verify camera opens WITHOUT crash
```

**Estimated Fix Time:** 5 minutes  
**Complexity:** Trivial  
**Risk:** None (adding standard permissions)

**Why This Must Be Fixed:**
- ✅ Blocks entire camera feature on Android (50% of users)
- ✅ App will crash (unrecoverable)
- ✅ Users will give 1-star reviews
- ✅ Simple 5-minute fix

**Fix Priority:** 🔴 DO IMMEDIATELY

---

### BLOCKER #2: Profile Screen Not Implemented

**Status:** 🔴 BLOCKING DEPLOYMENT  
**Severity:** CRITICAL  
**Component:** Flutter UI  
**File:** `lib/features/dashboard/dashboard_screen.dart` (line 31)

**Issue:**
Profile screen is just a placeholder text widget. Users cannot:
- View their account information
- Edit their profile
- Logout from the app (no button)
- Manage their account

**Impact:**
- ✅ Affects: **100% of users**
- ✅ Severity: **Missing core feature**
- ✅ Reproducibility: **100% reproducible**

**Current Code (BROKEN):**
```dart
// In lib/features/dashboard/dashboard_screen.dart, line 31
const Center(child: Text('Profile')),  // Just placeholder text!
```

**What User Sees:**
1. Login successfully ✅
2. Go to Dashboard ✅
3. Click Profile tab (bottom navigation) ✅
4. See "Profile" text only ❌
5. No way to view/edit profile ❌
6. No logout button ❌

**User Expectations NOT MET:**
- ❌ Can't see their name
- ❌ Can't see their email
- ❌ Can't edit profile
- ❌ Can't see account statistics
- ❌ Can't logout (must close app)

**Required Implementation:**
Must create complete ProfileScreen file: `lib/features/profile/profile_screen.dart`

**Minimum Requirements:**
1. Display user name (from Firebase Auth)
2. Display email address
3. Display account creation date
4. Edit name button
5. **Logout button** (required - currently no way to logout!)
6. Professional UI matching app design

**Code Template:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
  }

  Future<void> _handleLogout() async {
    final authService = AuthService();
    await authService.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: user == null 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              // User Avatar
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      user.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(fontSize: 32, color: Colors.white),
                    ),
                  ),
                ),
              ),
              
              // User Info Card
              Card(
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${user.displayName ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Email: ${user.email}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Joined: ${user.metadata.creationTime?.toLocal() ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Logout Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
```

**Then Update Dashboard:**
```dart
// In lib/features/dashboard/dashboard_screen.dart, line 31
// CHANGE FROM:
const Center(child: Text('Profile')),

// CHANGE TO:
const ProfileScreen(),  // And import the new file
```

**Testing Checklist Before Deployment:**
- [ ] Profile screen loads without errors
- [ ] User name displays correctly
- [ ] Email displays correctly
- [ ] Account creation date shows
- [ ] Logout button works
- [ ] User is returned to login after logout
- [ ] Theme toggle works on profile
- [ ] Navigation back works

**Estimated Fix Time:** 60-90 minutes  
**Complexity:** Medium  
**Risk:** Low (using only existing Firebase Auth)

**Why This Must Be Fixed:**
- ✅ Blocks user profile management (100% of users affected)
- ✅ No way to logout (critical UX issue)
- ✅ Missing essential feature
- ✅ Can't test multi-user scenarios without logout

**Fix Priority:** 🔴 DO IMMEDIATELY (after camera permissions)

---

### BLOCKER #3: Backend Firebase Token Verification Missing

**Status:** 🔴 BLOCKING PRODUCTION  
**Severity:** HIGH (Security Vulnerability)  
**Component:** Backend API  
**File:** `backend/main_production.py` (line 261)

**Issue:**
Backend has TODO comment. Firebase token verification not implemented. In production mode, backend accepts ANY non-empty token without validating it against Firebase. This is a **security vulnerability**.

**Impact:**
- ✅ Affects: Production security (all users)
- ✅ Severity: **Security vulnerability**
- ✅ Risk: Attackers could impersonate users

**Current Code (VULNERABLE):**
```python
# Line 261 in backend/main_production.py
if settings.auth_provider == "firebase":
    # TODO: Implement Firebase token verification
    if not token or token == "invalid":
        raise HTTPException(status_code=401, ...)
    return token  # Accepts ANY other token! WRONG!
```

**What Happens:**
```
Frontend sends token to backend:
  - Valid Firebase token ✅ Accepted
  - Expired Firebase token ✅ Also accepted (WRONG!)
  - Forged token ✅ Also accepted (SECURITY HOLE!)
  - Random string ✅ Also accepted (BUG!)
  - Empty token ❌ Rejected
  - Literal "invalid" ❌ Rejected
```

**Security Risk:**
- Attacker can forge a token to impersonate any user
- Attacker can make predictions for other users' accounts
- Attacker can read other users' scan history
- No authentication really happening!

**Required Fix:**
Implement proper Firebase JWT verification:

```python
from firebase_admin import auth
import firebase_admin
from firebase_admin import credentials

# Initialize Firebase Admin (add to startup)
# Note: Firebase should auto-initialize from environment
if not firebase_admin._apps:
    firebase_admin.initialize_app()

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)) -> str:
    """Verify Firebase authentication token"""
    
    if not settings.auth_enabled:
        return "anonymous"
    
    token = credentials.credentials
    
    if settings.environment == "development":
        # Development mode: accept any non-empty token
        if not token or token == "invalid":
            raise HTTPException(
                status_code=401,
                detail="Invalid or missing authentication token"
            )
        return token
    
    # Production mode: verify Firebase JWT
    if settings.auth_provider == "firebase":
        try:
            # Verify Firebase ID token
            decoded_token = auth.verify_id_token(token)
            uid = decoded_token['uid']
            logger.info(f"Token verified for user: {uid}")
            return uid
            
        except auth.InvalidIdTokenError:
            logger.warning(f"Invalid ID token: {token}")
            raise HTTPException(
                status_code=401,
                detail="Invalid authentication token"
            )
        except auth.ExpiredIdTokenError:
            logger.warning("Expired ID token")
            raise HTTPException(
                status_code=401,
                detail="Authentication token expired"
            )
        except auth.InvalidIdTokenError:
            logger.error("Failed to verify token")
            raise HTTPException(
                status_code=401,
                detail="Authentication failed"
            )
        except Exception as e:
            logger.error(f"Token verification error: {e}", exc_info=True)
            raise HTTPException(
                status_code=401,
                detail="Authentication failed"
            )
    
    raise HTTPException(status_code=401, detail="Auth provider not configured")
```

**Dependencies Needed:**
```
firebase_admin
```

Already in `backend/requirements.txt`? Check:
```bash
grep firebase_admin backend/requirements.txt
```

If not present, add:
```
firebase_admin>=6.2.0
```

**Testing After Fix:**
```python
# Test with valid Firebase token
curl -H "Authorization: Bearer <VALID_FIREBASE_TOKEN>" \
  http://localhost:8000/predict

# Test with expired token (should reject)
curl -H "Authorization: Bearer <EXPIRED_TOKEN>" \
  http://localhost:8000/predict  # Should return 401

# Test with forged token (should reject)
curl -H "Authorization: Bearer forged123" \
  http://localhost:8000/predict  # Should return 401

# Test with no token (should reject)
curl http://localhost:8000/predict  # Should return 401
```

**Estimated Fix Time:** 30 minutes  
**Complexity:** Low-Medium  
**Risk:** Low (improving security)

**Why This Must Be Fixed:**
- ✅ Production security vulnerability
- ✅ Allows token forgery
- ✅ Violates authentication requirements
- ✅ Simple to fix (30 minutes)

**Fix Priority:** 🔴 DO BEFORE PRODUCTION RELEASE

---

## 🟡 IMPORTANT BLOCKERS (Should Fix)

### BLOCKER #4: Permission Error Messages Not Shown to User

**Status:** 🟡 SHOULD FIX  
**Severity:** MEDIUM (UX Issue)  
**Component:** Flutter UI  
**File:** `lib/features/scan/new_scan_screen.dart` (line 31-32)

**Issue:**
When user denies camera or gallery permission, error is only logged to debug console. User sees nothing and thinks app is broken. Silent failures make the app look buggy.

**Current Code (POOR UX):**
```dart
catch (e) {
  debugPrint('Error picking image: $e');  // Only logs, user doesn't see!
}
```

**User Experience (BAD):**
1. User clicks "Capture Image" ✅
2. Permission prompt appears ✅
3. User denies permission (oops!) ✅
4. Nothing happens ❌
5. User thinks app is broken ❌
6. User closes app ❌

**Required Fix:**
Show snackbar error to user:

```dart
catch (e) {
  if (!mounted) return;
  
  String message = 'Failed to access camera/gallery';
  
  // Differentiate error types
  final errorStr = e.toString().toLowerCase();
  if (errorStr.contains('permission') || 
      errorStr.contains('denied')) {
    message = 'Permission denied. Please enable in settings.';
  } else if (errorStr.contains('cancel') || 
             errorStr.contains('user cancel')) {
    return;  // User intentionally cancelled, don't show error
  }
  
  // Show error to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () {},
      ),
    ),
  );
}
```

**Testing:**
- [ ] Allow permission - works
- [ ] Deny permission - shows error snackbar
- [ ] User cancels - no error shown
- [ ] Snackbar dismissible

**Estimated Fix Time:** 15 minutes  
**Complexity:** Low  
**Priority:** 🟡 SHOULD FIX

---

### BLOCKER #5: API Token Configuration Not Production-Ready

**Status:** 🟡 SHOULD FIX  
**Severity:** LOW (Dev Issue)  
**Component:** Flutter Config  
**File:** `lib/services/api_config.dart` (line 58)

**Issue:**
API token retrieval has TODO comment. Currently returns hardcoded "valid_token_for_test" which works for development but won't work in production.

**Current Code (DEV ONLY):**
```dart
static String getToken() {
  // TODO: Replace with actual Firebase token retrieval
  return _defaultToken;  // 'valid_token_for_test'
}
```

**Problem in Production:**
- Development backend accepts any token ✅
- Production backend validates Firebase JWT ❌
- Hardcoded token won't validate ❌

**Required Fix for Production:**
```dart
static Future<String> getToken() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    // Get fresh Firebase ID token
    final token = await user.getIdToken();
    
    if (token == null) {
      throw Exception('Failed to get ID token');
    }
    
    return token;
  } catch (e) {
    debugPrint('Error getting Firebase token: $e');
    // Fall back to default (only works in dev)
    return _defaultToken;
  }
}
```

**Note:** Make method async, update all call sites in PredictionService.

**Update PredictionService:**
```dart
static Future<PredictionResult> predict(
  String imagePath, {
  String? customUrl,
  bool isProduction = false,
}) async {
  final baseUrl = getBaseUrl(customUrl: customUrl, isProduction: isProduction);
  final token = await ApiService.getToken();  // Await the future
  
  final uri = Uri.parse('$baseUrl/predict');
  // ... rest of code
}
```

**Estimated Fix Time:** 15 minutes  
**Complexity:** Low  
**Priority:** 🟡 SHOULD FIX (before production release)

---

## Blocker Summary

### By Impact Level

| Level | Count | Blockers |
|-------|-------|----------|
| 🔴 CRITICAL (Block release) | 3 | Cameras, Profile, Backend Auth |
| 🟡 IMPORTANT (Should fix) | 2 | Permission UI, API Token |
| 🟢 NICE TO HAVE | 0 | None |

### By Time to Fix

| Time | Blockers |
|------|----------|
| < 30 min | Camera permissions (5), Permission UI (15), API Token (15) |
| 30-120 min | Backend Auth (30), Profile Screen (90) |
| **Total** | **~155 minutes (2.5 hours)** |

### By Component

| Component | Blockers |
|-----------|----------|
| Android Native | Camera permissions |
| Flutter UI | Profile screen, Permission UI, API Token |
| Backend | Firebase token verification |

---

## Deployment Decision Matrix

```
Can Deploy To Staging?
├─ NO (Blockers #1, #2, #3 prevent any deployment)
└─ Yes, if blockers are fixed

Can Deploy To Production?
├─ NO (Blockers #1, #2 prevent production)
├─ CRITICAL but risky (Blocker #3 is security issue)
└─ Yes, only after ALL THREE critical blockers fixed

Can Deploy to Beta (TestFlight)?
├─ NO (Blockers #1, #2 prevent any user testing)
└─ Yes, if blockers are fixed

Timeline for Release?
├─ With blockers: Cannot ship
├─ Fix Critical Only (2 hrs): Can ship MVP
├─ Fix All (2.5 hrs): Fully production-ready
└─ Recommended: Fix all before any public release
```

---

## Fix Priority Checklist

### MUST DO (Blocks Everything)
- [ ] **Fix #1:** Add camera permissions (5 min)
- [ ] **Fix #2:** Implement profile screen (90 min)
- [ ] **Fix #3:** Backend token verification (30 min)

### SHOULD DO (Before Release)
- [ ] **Fix #4:** Permission error UI (15 min)
- [ ] **Fix #5:** API token config (15 min)

### Verification Before Deployment
- [ ] Camera works on Android
- [ ] Camera works on iOS
- [ ] Profile screen loads and functions
- [ ] Logout works
- [ ] Backend auth validates tokens
- [ ] Permission errors show to user
- [ ] Full auth flow tested (signup → scan → logout)

---

## Recommendation

**DO NOT deploy to any environment until:**

1. ✅ Camera permissions declared in AndroidManifest.xml
2. ✅ Profile screen implemented with logout button
3. ✅ Backend Firebase token verification implemented

**RECOMMENDED to also fix before release:**
4. ✅ Permission error messages shown to user
5. ✅ API token configuration for production

**Estimated time to production-ready: 2.5 hours**

---

**Status:** 5 blockers identified, 3 are CRITICAL, 2 are IMPORTANT  
**Current State:** NOT READY FOR DEPLOYMENT  
**Action Required:** Fix all critical blockers before any release  
**Estimated Time to Fix:** 2.5 hours  
**Timeline:** Can be production-ready same day if prioritized
