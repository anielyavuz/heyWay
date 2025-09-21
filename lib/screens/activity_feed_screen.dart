import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/pulse_provider.dart';
import '../models/pulse.dart';
import '../models/venue.dart';
import '../services/firestore_service.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPublicPulses();
    });
  }

  void _loadPublicPulses() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print(
        '🔵 ActivityFeed: Loading feed pulses for user: ${currentUser.uid}',
      );
      final pulseProvider = context.read<PulseProvider>();
      pulseProvider.loadFeedPulses(currentUser.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Feed'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadPublicPulses,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<PulseProvider>(
        builder: (context, pulseProvider, child) {
          if (pulseProvider.isLoadingPublicPulses) {
            return const Center(child: CircularProgressIndicator());
          }

          if (pulseProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    pulseProvider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPublicPulses,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (pulseProvider.publicPulses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No public Pulses yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Be the first to share a public Pulse!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadPublicPulses();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pulseProvider.publicPulses.length,
              itemBuilder: (context, index) {
                final pulse = pulseProvider.publicPulses[index];
                return PublicPulseCard(pulse: pulse);
              },
            ),
          );
        },
      ),
    );
  }
}

class PublicPulseCard extends StatelessWidget {
  const PublicPulseCard({super.key, required this.pulse});

  final Pulse pulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnPost = currentUser?.uid == pulse.userId;

    final surfaceTint = isOwnPost ? colorScheme.primary : colorScheme.secondary;
    final gradientColors = isOwnPost
        ? [
            colorScheme.primaryContainer.withValues(alpha: 0.55),
            colorScheme.surface,
          ]
        : [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            colorScheme.surface,
          ];
    final borderColor = isOwnPost
        ? surfaceTint.withValues(alpha: 0.28)
        : colorScheme.outlineVariant.withValues(alpha: 0.28);
    final truncatedUserId = pulse.userId.length > 6
        ? '${pulse.userId.substring(0, 6)}...'
        : pulse.userId;
    final displayName = isOwnPost ? 'You' : 'User $truncatedUserId';
    final timeLabel = pulse.createdAt != null
        ? _formatTime(pulse.createdAt!)
        : 'Moments ago';
    final moodLabel = pulse.mood.trim().isNotEmpty
        ? pulse.mood.trim()
        : 'No mood';
    final initials = isOwnPost ? 'ME' : _buildInitials(pulse.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 20),
            blurRadius: 45,
            spreadRadius: -20,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          surfaceTint.withValues(alpha: 0.55),
                          surfaceTint,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: colorScheme.surface,
                      child: Text(
                        initials,
                        style: textTheme.labelLarge?.copyWith(
                          color: surfaceTint.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeLabel,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceTint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: surfaceTint.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      moodLabel,
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: surfaceTint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<Venue?>(
                future: FirestoreService().getVenue(pulse.venueId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final venue = snapshot.data!;
                    return _buildVenueTile(
                      context,
                      title: venue.name,
                      subtitle: _shortAddress(venue),
                      surfaceTint: surfaceTint,
                      isOwnPost: isOwnPost,
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildVenueTile(
                      context,
                      title: 'Fetching venue details',
                      subtitle: 'Hang tight while we fetch the venue',
                      surfaceTint: surfaceTint,
                      isOwnPost: isOwnPost,
                    );
                  }

                  return _buildVenueTile(
                    context,
                    title: 'Location unavailable',
                    subtitle: 'This venue could not be loaded right now',
                    surfaceTint: surfaceTint,
                    isOwnPost: isOwnPost,
                  );
                },
              ),
              if (pulse.caption.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  pulse.caption.trim(),
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.82),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (pulse.mediaRefs.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pulse.mediaRefs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            pulse.mediaRefs[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colorScheme.surfaceContainerHighest,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildActionButton(
                    context: context,
                    icon: Icons.favorite_outline,
                    label: '${pulse.likesCount}',
                    color: Colors.pinkAccent,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Likes will be available soon!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    context: context,
                    icon: Icons.mode_comment_outlined,
                    label: '${pulse.commentCount}',
                    color: colorScheme.secondary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Comments will be available soon!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  Icon(
                    pulse.visibility == 'public'
                        ? Icons.public
                        : pulse.visibility == 'friends'
                        ? Icons.people_alt_outlined
                        : Icons.lock_outline,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVenueTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Color surfaceTint,
    required bool isOwnPost,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final blendedBackground = Color.alphaBlend(
      surfaceTint.withValues(alpha: isOwnPost ? 0.14 : 0.08),
      colorScheme.surface,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: blendedBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: surfaceTint.withValues(alpha: isOwnPost ? 0.22 : 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceTint.withValues(alpha: isOwnPost ? 0.24 : 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 18,
              color: surfaceTint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortAddress(Venue venue) {
    final addressParts = venue.addressSummary
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && !RegExp(r'^\d{5}').hasMatch(part))
        .toList();

    if (addressParts.length >= 2) {
      return '${addressParts[addressParts.length - 2]}, ${addressParts.last}';
    }

    return addressParts.isNotEmpty ? addressParts.last : venue.addressSummary;
  }

  String _buildInitials(String userId) {
    if (userId.isEmpty) {
      return '??';
    }

    return userId.length >= 2
        ? userId.substring(0, 2).toUpperCase()
        : userId.toUpperCase();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
