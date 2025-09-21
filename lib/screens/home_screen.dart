import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../providers/pulse_provider.dart';
import '../models/pulse.dart';
import '../models/venue.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserPulses();
    });
  }

  void _loadUserPulses() {
    final authProvider = context.read<app_auth.AuthProvider>();
    final pulseProvider = context.read<PulseProvider>();

    if (authProvider.user != null) {
      pulseProvider.loadUserPulses(authProvider.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pulses'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadUserPulses,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer2<app_auth.AuthProvider, PulseProvider>(
        builder: (context, authProvider, pulseProvider, child) {
          if (authProvider.user == null) {
            return const Center(
              child: Text('Please log in to see your Pulses'),
            );
          }

          if (pulseProvider.isLoadingUserPulses) {
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
                    onPressed: _loadUserPulses,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (pulseProvider.userPulses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Pulses yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Go to Discover to find venues and share your first Pulse!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final groupedPulses = _groupPulsesByDay(pulseProvider.userPulses);

          final sections = <Widget>[];
          for (final group in groupedPulses) {
            sections.add(
              _PulseDayHeader(
                label: _formatGroupLabel(group.date),
                count: group.pulses.length,
              ),
            );
            sections.add(const SizedBox(height: 12));
            for (final pulse in group.pulses) {
              sections.add(PulseCard(pulse: pulse));
            }
            sections.add(const SizedBox(height: 24));
          }
          if (sections.isNotEmpty) {
            sections.removeLast();
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadUserPulses();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: sections.isEmpty ? [const SizedBox.shrink()] : sections,
            ),
          );
        },
      ),
    );
  }

  List<_PulseGroup> _groupPulsesByDay(List<Pulse> pulses) {
    if (pulses.isEmpty) {
      return const [];
    }

    final sorted = [...pulses]
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    final Map<DateTime, List<Pulse>> bucket = {};
    for (final pulse in sorted) {
      final createdAt = pulse.createdAt ?? DateTime.now();
      final dayKey = DateTime(createdAt.year, createdAt.month, createdAt.day);
      bucket.putIfAbsent(dayKey, () => []).add(pulse);
    }

    final entries = bucket.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return entries
        .map((entry) => _PulseGroup(date: entry.key, pulses: entry.value))
        .toList(growable: false);
  }

  String _formatGroupLabel(DateTime date) {
    const weekdayNames = <String>[
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    const monthNames = <String>[
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    final today = DateUtils.dateOnly(DateTime.now());
    final target = DateUtils.dateOnly(date);
    final difference = today.difference(target).inDays;

    if (difference == 0) {
      return 'Bugün';
    }
    if (difference == 1) {
      return 'Dün';
    }
    if (difference >= 0 && difference < 7) {
      return weekdayNames[target.weekday - 1];
    }

    final monthName = monthNames[target.month - 1];
    if (target.year == today.year) {
      return '${target.day} $monthName';
    }

    return '${target.day} $monthName ${target.year}';
  }
}

class PulseCard extends StatelessWidget {
  const PulseCard({super.key, required this.pulse});

  final Pulse pulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final moodLabel = pulse.mood.trim().isNotEmpty ? pulse.mood.trim() : 'Mood';
    final initials = moodLabel.length >= 2
        ? moodLabel.substring(0, 2).toUpperCase()
        : moodLabel.toUpperCase();
    final createdAt = pulse.createdAt;
    final gradient = [
      Color.alphaBlend(
        colorScheme.primary.withValues(alpha: 0.18),
        colorScheme.surface,
      ),
      Color.alphaBlend(
        colorScheme.secondary.withValues(alpha: 0.08),
        colorScheme.surface,
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 16),
            blurRadius: 32,
            spreadRadius: -18,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.35),
                          colorScheme.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(
                      initials,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moodLabel,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (createdAt != null)
                          Text(
                            _formatTime(createdAt),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
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
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _visibilityIcon(pulse.visibility),
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pulse.visibility == 'public'
                              ? 'Herkese Açık'
                              : pulse.visibility == 'friends'
                              ? 'Arkadaşlar'
                              : 'Sadece Ben',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FutureBuilder<Venue?>(
                future: FirestoreService().getVenue(pulse.venueId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final venue = snapshot.data!;
                    return _buildVenueTile(
                      context,
                      title: venue.name,
                      subtitle: _shortAddress(venue),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildVenueTile(
                      context,
                      title: 'Mekan yükleniyor',
                      subtitle: 'Konum detayı getiriliyor...',
                    );
                  }

                  return _buildVenueTile(
                    context,
                    title: 'Mekan bilinmiyor',
                    subtitle: 'Bu Pulse için konum bulunamadı',
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
                  ),
                ),
              ],
              if (pulse.mediaRefs.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pulse.mediaRefs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
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
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStatChip(
                    context,
                    icon: Icons.favorite_outline,
                    label: '${pulse.likesCount} beğeni',
                    color: colorScheme.primary,
                  ),
                  _buildStatChip(
                    context,
                    icon: Icons.mode_comment_outlined,
                    label: '${pulse.commentCount} yorum',
                    color: colorScheme.secondary,
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
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.08),
          colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
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

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _visibilityIcon(String visibility) {
    switch (visibility) {
      case 'public':
        return Icons.public;
      case 'friends':
        return Icons.people_alt_outlined;
      default:
        return Icons.lock_outline;
    }
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} sa önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class _PulseDayHeader extends StatelessWidget {
  const _PulseDayHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Row(
      children: [
        Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            count.toString().padLeft(2, '0'),
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.28),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseGroup {
  const _PulseGroup({required this.date, required this.pulses});

  final DateTime date;
  final List<Pulse> pulses;
}
