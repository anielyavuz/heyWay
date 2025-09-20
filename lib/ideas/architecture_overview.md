# Architecture Overview - Pulse App

## 🏗️ Project Structure

```
lib/
├── config/           # API keys, configuration
├── data/            # Sample data, constants
├── ideas/           # Documentation, planning
├── models/          # Data models (User, Venue, Pulse)
├── providers/       # State management (Provider pattern)
├── screens/         # UI screens/pages
├── services/        # Business logic, API calls
└── theme/           # App theming, styles
```

## 🔄 Data Flow Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   UI Layer      │    │  Provider Layer │    │ Service Layer   │
│                 │    │                 │    │                 │
│ - Screens       │◄──►│ - AuthProvider  │◄──►│ - FirestoreService
│ - Widgets       │    │ - VenueProvider │    │ - StorageService
│ - Navigation    │    │ - ThemeProvider │    │ - CacheService  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                  ▲                      ▲
                                  │                      │
                                  ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Model Layer    │    │ External APIs   │    │   Firebase      │
│                 │    │                 │    │                 │
│ - AppUser       │    │ - Foursquare    │    │ - Firestore     │
│ - Venue         │    │ - POI Providers │    │ - Storage       │
│ - Pulse         │    │ - Future APIs   │    │ - Auth          │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🧩 Key Components

### Models (Data Layer)
- **AppUser**: User profile, preferences, stats
- **Venue**: Location data, ratings, amenities
- **Pulse**: User check-ins, mood, media
- **Privacy Settings**: Granular privacy controls

### Providers (State Management)
- **AuthProvider**: Authentication state, user management
- **VenueSearchProvider**: Venue search with caching
- **LocationProvider**: GPS location services
- **ThemeProvider**: Dark/light mode persistence

### Services (Business Logic)
- **FirestoreService**: Database CRUD operations
- **StorageService**: File upload/download
- **VenueCacheService**: Smart API caching
- **PoiProviderManager**: External API abstraction

### Screens (UI Layer)
- **DiscoverScreen**: Map, venue search, exploration
- **ProfileScreen**: User profile display
- **EditProfileScreen**: Profile editing, avatar upload
- **HomeScreen**: Activity feed (future)

## 🔐 Security Model

### Authentication
```
Anonymous Auth → Email/Password → Profile Creation
     ↓               ↓                    ↓
Basic Access → Full Access → Personalized Experience
```

### Privacy Levels
- **Public**: Visible to everyone
- **Friends**: Visible to connections only
- **Private**: Visible to user only

### Data Access Rules
```
Users Collection:
  - Own profile: Read/Write
  - Others: Read (based on privacy)

Venues Collection:
  - All users: Read
  - Verified users: Write

Pulses Collection:
  - Own pulses: Read/Write
  - Others: Read (based on visibility)
```

## 🚀 Performance Optimizations

### Caching Strategy
```
API Request → Check Cache → Return Cached Data
     ↓             ↓              ↑
Cache Miss → Fetch Fresh → Update Cache
```

### Database Efficiency
- **Compound Queries**: Optimized Firestore indexes
- **Pagination**: Limit results, load more on demand
- **Real-time Streams**: Only where necessary
- **Batch Operations**: Atomic updates

### Image Handling
- **Compression**: Automatic image optimization
- **Progressive Loading**: Thumbnails first
- **Caching**: Local image cache
- **CDN**: Firebase Storage CDN

## 📱 Platform Integration

### iOS Specific
- **Permissions**: Location, camera, photo library
- **App Store**: Compliance with guidelines
- **Privacy**: App Tracking Transparency

### Android Specific
- **Permissions**: Location, storage, camera
- **Play Store**: Compliance with policies
- **Background**: Location services optimization

### Cross-Platform
- **Firebase**: Unified backend services
- **Flutter**: Single codebase
- **Provider**: State management pattern

## 🔧 Development Workflow

### Feature Development
```
1. Update steps.txt ─┐
2. Plan architecture ├─► Design Phase
3. Write tests      ─┘

4. Implement models ─┐
5. Create services  ├─► Implementation
6. Build UI        ─┘

7. Unit testing    ─┐
8. Integration test ├─► Testing Phase
9. Manual testing  ─┘

10. Update docs    ─┐
11. Code review    ├─► Documentation
12. Deploy        ─┘
```

### Code Quality Gates
- **Analyzer**: No warnings/errors
- **Tests**: 100% passing
- **Manual**: Full feature testing
- **Performance**: No regressions

## 🔄 State Management Patterns

### Provider Pattern
```dart
// Global state
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => VenueSearchProvider()),
  ],
  child: App(),
)

// Consuming state
Consumer<AuthProvider>(
  builder: (context, auth, child) {
    return auth.isSignedIn ? MainScreen() : LoginScreen();
  },
)
```

### Local State
- **StatefulWidget**: Component-specific state
- **useState**: Simple boolean/string states
- **Controllers**: Form inputs, animations

## 📊 Analytics & Monitoring

### User Analytics
- **Authentication**: Sign-up, sign-in rates
- **Engagement**: Screen time, feature usage
- **Content**: Pulse creation, venue searches

### Performance Monitoring
- **Crash Reporting**: Firebase Crashlytics
- **Performance**: App startup, network calls
- **Storage**: Cache hit rates, file sizes

### Business Metrics
- **Growth**: User acquisition, retention
- **Content**: Venue coverage, user-generated content
- **Revenue**: Premium features usage (future)

## 🛠️ Testing Strategy

### Pyramid Structure
```
      ┌─────────────┐
      │  E2E Tests  │ ←─ User journeys
      └─────────────┘
    ┌─────────────────┐
    │Integration Tests│ ←─ Feature testing
    └─────────────────┘
  ┌─────────────────────┐
  │    Unit Tests       │ ←─ Component testing
  └─────────────────────┘
```

### Coverage Goals
- **Unit**: 80%+ code coverage
- **Integration**: Key user flows
- **E2E**: Critical business paths
- **Manual**: UI/UX validation

This architecture ensures scalability, maintainability, and excellent user experience while following Flutter and Firebase best practices.