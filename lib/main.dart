import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/location_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/venue_search_provider.dart';
import 'providers/pulse_provider.dart';
import 'providers/friends_provider.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/activity_feed_screen.dart';
import 'screens/login_screen.dart';
import 'screens/nearby_venues_screen.dart';
import 'firebase_options.dart';
import 'utils/debug_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize debug logger
  await DebugLogger.initialize();
  DebugLogger.info('Application starting up', 'Main');
  
  // Enable Firestore offline persistence for better caching
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  DebugLogger.info('Firebase and Firestore initialized', 'Main');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..loadThemePreference(),
        ),
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => VenueSearchProvider()),
        ChangeNotifierProvider(create: (_) => PulseProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Pulse',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkTheme
                ? ThemeMode.dark
                : ThemeMode.light,
            home: themeProvider.isInitialized
                ? const AuthGate()
                : const ThemeLoadingScreen(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    ActivityFeedScreen(),
    DiscoverScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'Feed'),
          BottomNavigationBarItem(
            icon: Icon(Icons.travel_explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const NearbyVenuesScreen(),
            ),
          );
        },
        backgroundColor: Colors.red[600],
        child: const Icon(
          Icons.favorite,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class ThemeLoadingScreen extends StatelessWidget {
  const ThemeLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
