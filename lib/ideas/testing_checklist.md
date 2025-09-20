# Testing Checklist - Pulse App

## 📱 Manual Testing Guide

### Pre-Testing Setup
```bash
# 1. Ensure clean environment
flutter clean
flutter pub get

# 2. Run on fresh simulator/device
flutter run --debug

# 3. Check Firebase console is accessible
# Visit: https://console.firebase.google.com
```

---

## 🔍 Feature Testing

### Authentication System
**Test Steps:**
1. Launch app → Should see login screen or auto-login
2. Test anonymous authentication
3. Navigate to Profile tab
4. Verify user data loads correctly

**Expected Results:**
- ✅ Clean authentication flow
- ✅ User profile displays
- ✅ No crashes on auth state changes

---

### Profile Management
**Test Steps:**
1. Navigate to Profile tab
2. Tap "Edit Profile" button
3. Update display name
4. Test avatar upload:
   - Tap avatar → Select Camera
   - Tap avatar → Select Gallery
5. Change privacy settings
6. Save profile
7. Restart app → Verify changes persist

**Expected Results:**
- ✅ Profile editing UI works
- ✅ Image picker opens correctly
- ✅ Avatar uploads to Firebase Storage
- ✅ Privacy settings save
- ✅ Data persists after restart

**Firebase Verification:**
- Check `users/{uid}` document updated
- Check Storage for new avatar file

---

### Venue Search & Caching
**Test Steps:**
1. Navigate to Discover tab
2. Toggle "Static Location" ON
3. Search for "coffee"
4. Wait for results
5. Search again (should be faster)
6. Turn OFF wifi/data
7. Search "coffee" again
8. Turn ON wifi/data
9. Search "restaurant" (new query)

**Expected Results:**
- ✅ Initial search returns Foursquare results
- ✅ Second search is faster (uses cache)
- ✅ Offline search shows cached results
- ✅ New search hits API again

**Firebase Verification:**
- Check `venues` collection for cached data
- Verify venue documents have correct structure

---

### Map Functionality
**Test Steps:**
1. Navigate to Discover tab
2. Test map interactions:
   - Zoom in/out
   - Pan around
   - Switch map styles
3. Verify markers display
4. Test location toggle

**Expected Results:**
- ✅ Map renders without errors
- ✅ All map styles work
- ✅ Markers show venue locations
- ✅ Location toggle functions

---

### Navigation & UI
**Test Steps:**
1. Navigate between all tabs
2. Test theme switching (if available)
3. Test back navigation
4. Test deep state preservation

**Expected Results:**
- ✅ Smooth tab navigation
- ✅ No state loss between tabs
- ✅ Consistent UI across screens

---

## 🧪 Automated Testing

### Unit Tests
```bash
flutter test

# Expected output:
# ✅ All model tests pass
# ✅ Service layer tests pass
# ✅ No test failures
```

### Code Quality
```bash
flutter analyze

# Expected output:
# "No issues found!"
```

---

## 🔧 Debugging Common Issues

### Authentication Problems
```dart
// Check provider state
Consumer<AuthProvider>(
  builder: (context, auth, child) {
    print('User: ${auth.user?.uid}');
    print('AppUser: ${auth.appUser?.displayName}');
    return child!;
  },
)
```

### Firestore Connection Issues
```bash
# Check Firebase console logs
# Verify internet connectivity
# Check Firebase project settings
```

### Map Not Loading
```bash
# Check tile URLs in map_styles.dart
# Verify internet for tile downloads
# Test different map styles
```

### Image Upload Failures
```bash
# Check Firebase Storage rules
# Verify file permissions
# Test with smaller images
```

---

## 📊 Performance Testing

### Memory Usage
```bash
# Run with memory profiling
flutter run --profile
# Monitor memory in DevTools
```

### App Startup Time
```bash
# Cold start test
flutter run --release
# Measure time to first paint
```

### Network Efficiency
```bash
# Monitor Foursquare API calls
# Check cache hit rates
# Verify offline functionality
```

---

## 🚀 Release Testing

### Pre-Release Checklist
- [ ] All automated tests pass
- [ ] Manual testing completed
- [ ] Firebase console shows correct data
- [ ] No analyzer warnings
- [ ] Performance acceptable
- [ ] Works on multiple devices

### Build Testing
```bash
# Test release build
flutter build apk --release
flutter build ios --release

# Install and test on real devices
```

---

## 📝 After Each Feature Implementation

### 1. Immediate Testing (2-3 minutes)
```bash
# Quick smoke test
flutter run
# Navigate to new feature
# Test happy path
# Check for crashes
```

### 2. Integration Testing (5-10 minutes)
- Test feature with existing functionality
- Verify data flows correctly
- Check Firebase console
- Test error scenarios

### 3. Regression Testing (10-15 minutes)
- Test previously working features
- Verify no breaking changes
- Check authentication still works
- Confirm navigation still functions

### 4. Documentation Update
- Update implementation_notes.md
- Add new test cases to checklist
- Note any known issues

This systematic approach ensures each feature is thoroughly tested before moving to the next implementation phase.