import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import 'edit_profile_screen.dart';
import 'friends_screen.dart';
import 'logs_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.user == null) {
          return const Scaffold(
            body: Center(
              child: Text('Please sign in to view profile'),
            ),
          );
        }

        return StreamBuilder<AppUser>(
          stream: FirestoreService().userStream(authProvider.user!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Error: ${snapshot.error}'),
                ),
              );
            }

            final appUser = snapshot.data;
            if (appUser == null) {
              return const Scaffold(
                body: Center(
                  child: Text('User data not found'),
                ),
              );
            }

            return _ProfileContent(user: appUser);
          },
        );
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(user: user),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildStatsSection(),
            const SizedBox(height: 24),
            _buildPrivacySection(),
            const SizedBox(height: 24),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: user.avatarUrl.isNotEmpty
              ? NetworkImage(user.avatarUrl)
              : null,
          child: user.avatarUrl.isEmpty
              ? const Icon(Icons.person, size: 60)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '@${user.username}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => _copyUserIdToClipboard(context, user.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.copy,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ID: ${user.id.length > 12 ? "${user.id.substring(0, 12)}..." : user.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Pulses', user.stats.pulseCount),
            _buildStatItem('Friends', user.stats.friendCount),
            _buildStatItem('Badges', user.stats.badgeCount),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPrivacyItem('Profile', user.privacy.profile),
            _buildPrivacyItem('Pulses', user.privacy.pulses),
            _buildPrivacySwitch(
              'Location Sharing',
              user.privacy.locationSharing,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Chip(
            label: Text(value.toUpperCase()),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySwitch(String label, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Switch(
          value: value,
          onChanged: null, // Disabled for now, will be enabled in edit screen
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FriendsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.people),
            label: const Text('Friends'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bug_report),
            label: const Text('Debug Logs'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(user: user),
                ),
              );
            },
            child: const Text('Edit Profile'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              _showSignOutDialog(context);
            },
            child: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }

  void _copyUserIdToClipboard(BuildContext context, String userId) {
    Clipboard.setData(ClipboardData(text: userId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User ID copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}