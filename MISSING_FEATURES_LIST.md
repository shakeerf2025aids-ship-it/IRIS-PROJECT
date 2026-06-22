# IRIS Glaucoma MVP - Missing Features List

**Date:** June 16, 2026  
**Audit Status:** Complete  
**Total Missing Features:** 3

---

## Missing Features (Not Implemented)

### 1. User Profile Screen ❌ CRITICAL

**Priority:** 🔴 CRITICAL - Blocks User Functionality  
**File Location:** Should be `lib/features/profile/profile_screen.dart`  
**Current State:** Placeholder in `lib/features/dashboard/dashboard_screen.dart` (line 31)

**Current Implementation:**
```dart
const Center(child: Text('Profile')),
```

**Required Implementation:**

#### Screen Components Needed:
1. **User Information Display**
   - Full name (from Firebase Auth)
   - Email address
   - Account creation date
   - Last login date
   - Profile picture (optional)

2. **Profile Edit Form**
   - Edit full name field
   - Edit email field (if supported)
   - Save changes button
   - Cancel button

3. **Account Actions**
   - Logout button
   - Delete account (optional for v1)
   - Change password (via forgot password flow)
   - Settings (optional)

4. **Statistics Summary**
   - Total scans
   - Last scan date
   - Average risk score

#### Code Template:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

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
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // User info display
                  CircleAvatar(
                    radius: 50,
                    child: Text(user.email?.substring(0, 1).toUpperCase() ?? 'U'),
                  ),
                  const SizedBox(height: 24),
                  
                  // User details
                  Text(user.displayName ?? 'User', style: Theme.of(context).textTheme.headlineSmall),
                  Text(user.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
                  
                  const SizedBox(height: 32),
                  
                  // Edit form
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  ElevatedButton(
                    onPressed: _handleLogout,
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
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

**Affected Feature Checklist:**
- ❌ User information display
- ❌ Profile updates
- ❌ Logout from profile screen
- ✅ User profile access (Firebase Auth provides this)
- ✅ Profile data persistence (Firebase Auth handles)

**Estimated Implementation Time:** 60-90 minutes  
**Complexity:** Medium  
**Dependencies:** None (uses existing Firebase Auth)

**Testing Required:**
- [ ] User info displays correctly
- [ ] Edit functionality updates Firebase
- [ ] Logout works from profile
- [ ] Profile loads on app restart
- [ ] Theme switching works

---

### 2. PDF Report Generation ❌ OPTIONAL

**Priority:** 🟡 MEDIUM - Enhancement Feature  
**File Location:** Should extend `lib/features/report/report_screen.dart`  
**Current State:** Button shows snackbar instead of generating PDF

**Current Implementation:**
```dart
void _generatePdf(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('PDF Generated successfully!')),
  );
}
```

**Required Implementation:**

#### Dependencies Needed:
```yaml
pdf: ^3.10.0
printing: ^5.11.0
path_provider: ^2.1.0
```

#### Functionality:
1. Generate PDF with user data
2. Include scan results
3. Include risk assessment
4. Add recommendations
5. Save to local file
6. Share or download

#### Code Example:
```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> _generatePdf() async {
  final pdf = pw.Document();
  
  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Text('Glaucoma Risk Assessment Report'),
            pw.SizedBox(height: 20),
            pw.Text('Patient Name: ${user.displayName}'),
            pw.Text('Date: ${DateTime.now()}'),
            pw.SizedBox(height: 20),
            pw.Text('Risk Status: High Risk'),
            pw.Text('Confidence: 82%'),
          ],
        );
      },
    ),
  );
  
  // Save or share
  final bytes = await pdf.save();
  // Use path_provider to save
  // Or use printing to share
}
```

**Estimated Implementation Time:** 1-2 hours  
**Complexity:** Medium  
**Recommendation:** Include in v1.1, not required for MVP

---

### 3. Report Share Functionality ❌ OPTIONAL

**Priority:** 🟡 MEDIUM - Enhancement Feature  
**File Location:** Should extend `lib/features/report/report_screen.dart`  
**Current State:** Button shows snackbar instead of sharing

**Current Implementation:**
```dart
void _shareReport(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Report Shared!')),
  );
}
```

**Required Implementation:**

#### Dependencies Needed:
```yaml
share_plus: ^7.2.0
```

#### Functionality:
1. Format report as text/PDF
2. Share via email
3. Share via messaging apps
4. Share via social media (optional)
5. Copy to clipboard (optional)

#### Code Example:
```dart
import 'package:share_plus/share_plus.dart';

Future<void> _shareReport() async {
  final report = '''
Glaucoma Risk Assessment Report
Patient: ${user.displayName}
Date: ${DateTime.now()}

Risk Status: High Risk
Confidence: 82%

Recommendation: Consult with an ophthalmologist
  ''';

  await Share.share(
    report,
    subject: 'Glaucoma Risk Assessment Report',
  );
}
```

**Estimated Implementation Time:** 30 minutes  
**Complexity:** Low  
**Recommendation:** Include in v1.1, not required for MVP

---

## Missing Features Summary Table

| Feature | Severity | Impact | Time | Blocker |
|---------|----------|--------|------|---------|
| Profile Screen | CRITICAL | Users can't view/edit profile | 90 min | YES |
| PDF Generation | MEDIUM | Can't download reports | 2 hours | NO |
| Report Share | MEDIUM | Can't share results | 30 min | NO |

---

## Implementation Roadmap

### Sprint 1 (MVP - Now)
- ✅ Authentication
- ✅ Image capture and upload
- ✅ Prediction pipeline
- ✅ Firestore integration
- ✅ History display
- ⚠️ **Profile Screen (ADD THIS)**

### Sprint 2 (v1.1)
- 🟡 PDF generation
- 🟡 Report sharing
- 🟡 Advanced statistics
- 🟡 Export history

### Sprint 3 (v1.2)
- 📋 Email notifications
- 📋 Multiple accounts
- 📋 Doctor integration
- 📋 Appointment booking

---

## Blocking Analysis

### For MVP Release:
**MUST IMPLEMENT:**
- ❌ Profile Screen (Blocks v1.0)

**NICE TO HAVE:**
- 🟡 PDF Generation (Can wait for v1.1)
- 🟡 Report Share (Can wait for v1.1)

### Cumulative Impact

**With Only Missing Features:**
- Users cannot access/edit their profile
- Reports cannot be downloaded (can still be viewed)
- Reports cannot be shared (users must manually share via screenshot)

**User Experience Impact:** Moderate (affects about 30% of expected features)

---

## Recommendation

1. **Immediately implement Profile Screen** - Required for MVP
2. **Plan PDF generation for v1.1** - Not critical but expected feature
3. **Plan Report sharing for v1.1** - Enhancement feature

**MVP cannot release without Profile Screen implementation.**

---

**Status:** 3/50 features missing = 94% complete  
**Critical Missing:** 1 (Profile)  
**Optional Missing:** 2 (PDF, Share)
