
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
            body: Center(child: Text('Please sign in to view profile')),
          );
        }

        return StreamBuilder<AppUser>(
          stream: FirestoreService().userStream(authProvider.user!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error: ${snapshot.error}')),
              );
            }

            final appUser = snapshot.data;
            if (appUser == null) {
              return const Scaffold(
                body: Center(child: Text('User data not found')),
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
    final colorScheme = Theme.of(context).colorScheme;

    final actions = <_ProfileAction>[
      _ProfileAction(
        icon: Icons.people_outline,
        title: 'Arkadaşlar',
        subtitle: 'Bağlantılarını yönet',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FriendsScreen()),
          );
        },
      ),
      _ProfileAction(
        icon: Icons.timeline_outlined,
        title: 'Pulse geçmişi',
        subtitle: 'Paylaşımlarının kaydını gör',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogsScreen()),
          );
        },
      ),
      _ProfileAction(
        icon: Icons.edit_outlined,
        title: 'Profili düzenle',
        subtitle: 'Görünüm ve bilgilerini güncelle',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditProfileScreen(user: user),
            ),
          );
        },
      ),
      _ProfileAction(
        icon: Icons.logout,
        title: 'Çıkış yap',
        subtitle: 'Hesabından güvenle ayrıl',
        isDestructive: true,
        onTap: () => _showSignOutDialog(context),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.settings_outlined),
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeroCard(
              user: user,
              onCopyId: () => _copyUserIdToClipboard(context, user.id),
            ),
            const SizedBox(height: 24),
            _ProfileStatsRow(user: user),
            const SizedBox(height: 24),
            _PrivacySettingsCard(user: user),
            const SizedBox(height: 24),
            _ProfileActionsSection(actions: actions),
            const SizedBox(height: 20),
            _AccountMetaFooter(color: colorScheme),
          ],
        ),
      ),
    );
  }

  void _copyUserIdToClipboard(BuildContext context, String userId) {
    Clipboard.setData(ClipboardData(text: userId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kullanıcı ID kopyalandı'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış yap'),
        content: const Text('Hesabından çıkış yapmak istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
            },
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.user, required this.onCopyId});

  final AppUser user;
  final VoidCallback onCopyId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lastActiveText = user.lastActive != null
        ? _formatRelative(user.lastActive!)
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.95),
            colorScheme.secondary.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 24),
            spreadRadius: -22,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.onPrimary.withValues(alpha: 0.3),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundImage: user.avatarUrl.isNotEmpty
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.1),
                  child: user.avatarUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 42,
                          color: colorScheme.onPrimary,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@${user.username}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: onCopyId,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy,
                              size: 14,
                              color: colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user.id.length > 12
                                  ? '${user.id.substring(0, 12)}...'
                                  : user.id,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (lastActiveText != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.watch_later_outlined,
                    color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Son aktif: $lastActiveText',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatTileData(
        label: 'Pulses',
        value: user.stats.pulseCount,
        icon: Icons.favorite_outline,
      ),
      _StatTileData(
        label: 'Friends',
        value: user.stats.friendCount,
        icon: Icons.people_alt_outlined,
      ),
      _StatTileData(
        label: 'Badges',
        value: user.stats.badgeCount,
        icon: Icons.emoji_events_outlined,
      ),
    ];

    return Row(
      children: [
        for (final data in stats) Expanded(child: _StatTile(data: data)),
      ],
    );
  }
}

class _PrivacySettingsCard extends StatelessWidget {
  const _PrivacySettingsCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.08),
          colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gizlilik',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _PrivacyRow(
            icon: Icons.badge_outlined,
            label: 'Profil',
            value: user.privacy.profile,
          ),
          _PrivacyRow(
            icon: Icons.favorite_outline,
            label: 'Pulses',
            value: user.privacy.pulses,
          ),
          _PrivacyToggleRow(
            label: 'Konum paylaşımı',
            value: user.privacy.locationSharing,
          ),
        ],
      ),
    );
  }
}

class _ProfileActionsSection extends StatelessWidget {
  const _ProfileActionsSection({required this.actions});

  final List<_ProfileAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final action in actions) ...[
          _ProfileActionTile(action: action),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AccountMetaFooter extends StatelessWidget {
  const _AccountMetaFooter({required this.color});

  final ColorScheme color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Text(
        'heyway © ${DateTime.now().year}',
        style: textTheme.labelSmall?.copyWith(
          color: color.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({required this.action});

  final _ProfileAction action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentColor = action.isDestructive
        ? colorScheme.error
        : colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 12),
                spreadRadius: -14,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.14),
                ),
                child: Icon(action.icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTileData {
  const _StatTileData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final _StatTileData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 12),
            spreadRadius: -16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            data.value.toString(),
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyToggleRow extends StatelessWidget {
  const _PrivacyToggleRow({required this.label, required this.value});

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.secondary.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.radar, size: 18, color: colorScheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            ),
          ),
          Switch.adaptive(value: value, onChanged: null),
        ],
      ),
    );
  }
}

String _formatRelative(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 1) {
    return 'şimdi';
  } else if (diff.inHours < 1) {
    return '${diff.inMinutes} dk önce';
  } else if (diff.inDays < 1) {
    return '${diff.inHours} sa önce';
  } else if (diff.inDays < 7) {
    return '${diff.inDays} gün önce';
  } else {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
