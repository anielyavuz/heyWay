import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timelines/timelines.dart';
import '../providers/pulse_provider.dart';
import '../models/pulse.dart';
import '../models/venue.dart';
import '../models/app_user.dart';
import 'pulse_map_screen.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  String? _selectedCountry;
  String? _selectedCity;
  String? _selectedDistrict;
  String? _selectedUserId;
  bool _showFilters = false;

  static const Set<String> _knownCountryNames = {
    'turkey',
    'türkiye',
    'turkiye',
    'united states',
    'usa',
    'united kingdom',
    'uk',
    'germany',
    'france',
    'italy',
    'spain',
    'canada',
    'australia',
    'brazil',
    'mexico',
    'japan',
    'south korea',
    'korea',
    'russia',
    'netherlands',
    'belgium',
    'sweden',
    'norway',
    'denmark',
    'finland',
    'poland',
    'portugal',
    'greece',
    'hungary',
    'czechia',
    'czech republic',
    'romania',
    'bulgaria',
    'austria',
    'switzerland',
    'ireland',
    'new zealand',
    'argentina',
    'chile',
    'colombia',
    'peru',
    'china',
    'india',
    'pakistan',
    'united arab emirates',
    'uae',
    'qatar',
    'saudi arabia',
    'kuwait',
  };

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
        leading: IconButton(
          onPressed: _openFeedMap,
          icon: const Icon(Icons.map_outlined),
          tooltip: 'Haritada göster',
        ),
        title: const Text('Activity Feed'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            icon: Icon(
              _showFilters || _hasActiveFilters
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            tooltip: _showFilters ? 'Filtreleri gizle' : 'Filtreleri göster',
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

          final pulses = pulseProvider.publicPulses;
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          final filterData = _collectFilterData(pulseProvider, currentUserId);
          final countries = _buildSortedList(filterData.location.countries);
          final cities = _buildAvailableCities(filterData.location);
          final districts = _buildAvailableDistricts(filterData.location);
          final userOptions = _buildUserOptions(filterData.userLabels);

          _ensureSelectionValidity(countries, cities, districts, userOptions);

          final filteredPulses = _applyFilters(pulses, pulseProvider);
          final uniqueVenueIds = pulses
              .map((pulse) => pulse.venueId)
              .where((id) => id.isNotEmpty)
              .toSet();
          final isVenueLoading =
              uniqueVenueIds.isNotEmpty &&
              uniqueVenueIds.any(
                (id) => !pulseProvider.cachedVenues.containsKey(id),
              );

          final uniqueUserIds = pulses
              .map((pulse) => pulse.userId)
              .where((id) => id.isNotEmpty)
              .toSet();
          final isUserLoading =
              uniqueUserIds.isNotEmpty &&
              uniqueUserIds.any((id) => pulseProvider.getUserById(id) == null);

          final children = <Widget>[];
          Widget? filterCard;
          if (_showFilters) {
            filterCard = _buildCompactFilterCard(
              hasPulses: pulses.isNotEmpty,
              isVenueLoading: isVenueLoading,
              isUserLoading: isUserLoading,
              countries: countries,
              cities: cities,
              districts: districts,
              userOptions: userOptions,
            );

            children.add(
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child:
                    filterCard ??
                    const SizedBox.shrink(key: ValueKey('feed-filter-empty')),
              ),
            );
            if (filterCard != null) {
              children.add(const SizedBox(height: 12));
            }
          }

          if (filteredPulses.isEmpty) {
            children.add(_buildFilteredEmptyState());
          } else {
            children.add(
              _FeedTimeline(
                pulses: filteredPulses,
                currentUserId: currentUserId,
                pulseProvider: pulseProvider,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadPublicPulses();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
              physics: const AlwaysScrollableScrollPhysics(),
              children: children,
            ),
          );
        },
      ),
    );
  }

  _FeedFilterData _collectFilterData(
    PulseProvider provider,
    String? currentUserId,
  ) {
    final countries = <String>{};
    final citiesByCountry = <String, Set<String>>{};
    final districtsByCountryCity = <String, Map<String, Set<String>>>{};
    final userLabels = <String, String>{};

    for (final pulse in provider.publicPulses) {
      final venue = provider.getVenueById(pulse.venueId);
      final location = _parseLocation(venue);
      if (location != null) {
        countries.add(location.country);

        final city = location.city;
        if (city != null && city.isNotEmpty) {
          final citySet = citiesByCountry.putIfAbsent(
            location.country,
            () => <String>{},
          );
          citySet.add(city);

          final district = location.district;
          if (district != null && district.isNotEmpty) {
            final districtMap = districtsByCountryCity.putIfAbsent(
              location.country,
              () => <String, Set<String>>{},
            );
            final districtSet = districtMap.putIfAbsent(city, () => <String>{});
            districtSet.add(district);
          }
        }
      }

      final isOwnPost = currentUserId != null && currentUserId == pulse.userId;
      final user = provider.getUserById(pulse.userId);
      userLabels[pulse.userId] = _userDisplayName(
        user,
        pulse.userId,
        isOwnPost: isOwnPost,
      );
    }

    return _FeedFilterData(
      location: _LocationFilterData(
        countries: countries,
        citiesByCountry: citiesByCountry,
        districtsByCountryCity: districtsByCountryCity,
      ),
      userLabels: userLabels,
    );
  }

  List<String> _buildSortedList(Iterable<String> values) {
    final set = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      set.add(trimmed);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> _buildAvailableCities(_LocationFilterData data) {
    final set = <String>{};
    if (_selectedCountry != null) {
      set.addAll(data.citiesByCountry[_selectedCountry] ?? const <String>{});
    } else {
      for (final cities in data.citiesByCountry.values) {
        set.addAll(cities);
      }
    }
    return _buildSortedList(set);
  }

  List<String> _buildAvailableDistricts(_LocationFilterData data) {
    final set = <String>{};
    final Iterable<String> countryKeys = _selectedCountry != null
        ? <String>[_selectedCountry!]
        : data.districtsByCountryCity.keys;

    for (final country in countryKeys) {
      final cityMap = data.districtsByCountryCity[country];
      if (cityMap == null) continue;

      if (_selectedCity != null) {
        set.addAll(cityMap[_selectedCity!] ?? const <String>{});
      } else {
        for (final districts in cityMap.values) {
          set.addAll(districts);
        }
      }
    }

    return _buildSortedList(set);
  }

  List<_UserOption> _buildUserOptions(Map<String, String> userLabels) {
    final options = userLabels.entries
        .map((entry) => _UserOption(id: entry.key, label: entry.value))
        .toList();
    options.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return options;
  }

  void _ensureSelectionValidity(
    List<String> countries,
    List<String> cities,
    List<String> districts,
    List<_UserOption> userOptions,
  ) {
    var newCountry = _selectedCountry;
    var newCity = _selectedCity;
    var newDistrict = _selectedDistrict;
    var newUserId = _selectedUserId;

    if (newCountry != null && !countries.contains(newCountry)) {
      newCountry = null;
      newCity = null;
      newDistrict = null;
    }

    if (newCity != null && !cities.contains(newCity)) {
      newCity = null;
      newDistrict = null;
    }

    if (newDistrict != null && !districts.contains(newDistrict)) {
      newDistrict = null;
    }

    final userIds = userOptions.map((option) => option.id).toSet();
    if (newUserId != null && !userIds.contains(newUserId)) {
      newUserId = null;
    }

    if (newCountry != _selectedCountry ||
        newCity != _selectedCity ||
        newDistrict != _selectedDistrict ||
        newUserId != _selectedUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedCountry = newCountry;
          _selectedCity = newCity;
          _selectedDistrict = newDistrict;
          _selectedUserId = newUserId;
        });
      });
    }
  }

  Widget? _buildCompactFilterCard({
    required bool hasPulses,
    required bool isVenueLoading,
    required bool isUserLoading,
    required List<String> countries,
    required List<String> cities,
    required List<String> districts,
    required List<_UserOption> userOptions,
  }) {
    if (!hasPulses) {
      return null;
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final loading = isVenueLoading || isUserLoading;
    final hasActiveFilters = _hasActiveFilters;
    final hasLocationData =
        countries.isNotEmpty || cities.isNotEmpty || districts.isNotEmpty;
    final hasUserOptions = userOptions.isNotEmpty;

    if (!hasLocationData && !hasUserOptions && !loading) {
      return null;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final calculatedWidth = (screenWidth - 16 * 2 - 16) / 2;
    final fieldWidth = calculatedWidth.clamp(150.0, 220.0);

    final fields = <Widget>[];

    if (countries.isNotEmpty || _selectedCountry != null) {
      fields.add(
        _buildCompactDropdown(
          label: 'Ülke',
          value: _selectedCountry,
          options: countries,
          onChanged: (value) {
            setState(() {
              _selectedCountry = value;
              _selectedCity = null;
              _selectedDistrict = null;
            });
          },
          width: fieldWidth,
          textTheme: textTheme,
        ),
      );
    }

    if (cities.isNotEmpty || _selectedCity != null) {
      fields.add(
        _buildCompactDropdown(
          label: 'Şehir',
          value: _selectedCity,
          options: cities,
          onChanged: cities.isEmpty
              ? null
              : (value) {
                  setState(() {
                    _selectedCity = value;
                    _selectedDistrict = null;
                  });
                },
          width: fieldWidth,
          textTheme: textTheme,
        ),
      );
    }

    if (districts.isNotEmpty || _selectedDistrict != null) {
      fields.add(
        _buildCompactDropdown(
          label: 'İlçe',
          value: _selectedDistrict,
          options: districts,
          onChanged: districts.isEmpty
              ? null
              : (value) {
                  setState(() {
                    _selectedDistrict = value;
                  });
                },
          width: fieldWidth,
          textTheme: textTheme,
        ),
      );
    }

    if (userOptions.isNotEmpty) {
      final items = <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Kişi (Tümü)'),
        ),
        ...userOptions.map(
          (option) => DropdownMenuItem<String?>(
            value: option.id,
            child: Text(option.label),
          ),
        ),
      ];

      final selectedUser =
          userOptions.any((option) => option.id == _selectedUserId)
          ? _selectedUserId
          : null;

      fields.add(
        SizedBox(
          width: fieldWidth,
          child: DropdownButtonFormField<String?>(
            value: selectedUser,
            items: items,
            onChanged: (value) {
              setState(() {
                _selectedUserId = value;
              });
            },
            isExpanded: true,
            isDense: true,
            decoration: InputDecoration(
              labelText: 'Kişi',
              labelStyle: textTheme.bodySmall,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            style: textTheme.bodySmall,
            dropdownColor: colorScheme.surface,
            icon: const Icon(Icons.person, size: 18),
          ),
        ),
      );
    }

    return Card(
      key: const ValueKey('feed-filter-card'),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Filtreler',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (loading)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                if (hasActiveFilters)
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Temizle'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: fields),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?>? onChanged,
    required double width,
    required TextTheme textTheme,
  }) {
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(value: null, child: Text('$label (Tümü)')),
      ...options.map(
        (option) =>
            DropdownMenuItem<String?>(value: option, child: Text(option)),
      ),
    ];

    final dropdownValue = value != null && options.contains(value)
        ? value
        : null;

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        value: dropdownValue,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: textTheme.bodySmall,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        style: textTheme.bodySmall,
        dropdownColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  void _openFeedMap() {
    final pulseProvider = context.read<PulseProvider>();
    final pulses = _applyFilters(
      pulseProvider.publicPulses,
      pulseProvider,
    );

    final entries = <PulseMapEntry>[];
    for (final pulse in pulses) {
      final venue = pulseProvider.getVenueById(pulse.venueId);
      final geo = venue?.location.geoPoint;
      if (venue == null || geo == null) {
        continue;
      }
      final isOwnPost = FirebaseAuth.instance.currentUser?.uid == pulse.userId;
      final user = pulseProvider.getUserById(pulse.userId);
      final userLabel = _userDisplayName(
        user,
        pulse.userId,
        isOwnPost: isOwnPost,
      );
      entries.add(
        PulseMapEntry(
          pulse: pulse,
          venue: venue,
          userLabel: userLabel,
        ),
      );
    }

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Haritada gösterilecek konum bulunamadı.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PulseMapScreen(
          title: 'Feed Haritası',
          entries: entries,
          markerScale: 3.0,
          markerLabelBuilder: (entry, relativeTime) {
            final pieces = <String>[];
            if (entry.userLabel != null && entry.userLabel!.trim().isNotEmpty) {
              pieces.add(entry.userLabel!.trim());
            }
            pieces.add(entry.venue.name);
            if (relativeTime != null && relativeTime.isNotEmpty) {
              pieces.add(relativeTime);
            }
            return pieces.join(' • ');
          },
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedCountry = null;
      _selectedCity = null;
      _selectedDistrict = null;
      _selectedUserId = null;
    });
  }

  bool get _hasActiveFilters =>
      _selectedCountry != null ||
      _selectedCity != null ||
      _selectedDistrict != null ||
      _selectedUserId != null;

  List<Pulse> _applyFilters(List<Pulse> pulses, PulseProvider provider) {
    if (!_hasActiveFilters) {
      return pulses;
    }

    return pulses.where((pulse) {
      if (_selectedUserId != null && pulse.userId != _selectedUserId) {
        return false;
      }

      final location = _parseLocation(provider.getVenueById(pulse.venueId));
      if (_selectedCountry != null &&
          (location == null || location.country != _selectedCountry)) {
        return false;
      }
      if (_selectedCity != null &&
          (location == null || location.city != _selectedCity)) {
        return false;
      }
      if (_selectedDistrict != null &&
          (location == null || location.district != _selectedDistrict)) {
        return false;
      }
      return true;
    }).toList();
  }

  _LocationParts? _parseLocation(Venue? venue) {
    if (venue == null) return null;
    final summary = venue.addressSummary.trim();
    if (summary.isEmpty) return null;

    final parts = summary
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    final normalizedParts = List<String>.from(parts);

    String? country;
    if (normalizedParts.isNotEmpty) {
      final lastPart = normalizedParts.last.toLowerCase();
      if (_knownCountryNames.contains(lastPart)) {
        country = normalizedParts.removeLast();
      }
    }

    if (country == null && normalizedParts.length >= 3) {
      country = 'Türkiye';
    }

    country ??= 'Bilinmiyor';

    String? city;
    if (normalizedParts.isNotEmpty) {
      city = _normalizeLocationValue(normalizedParts.removeLast());
    }

    String? district;
    if (normalizedParts.isNotEmpty) {
      district = _normalizeLocationValue(normalizedParts.removeLast());
    }

    return _LocationParts(
      country: _normalizeLocationValue(country),
      city: city,
      district: district,
    );
  }

  String _normalizeLocationValue(String value) => value.trim();

  Widget _buildFilteredEmptyState() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_off,
            size: 40,
            color: colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            'Bu filtreyle eşleşen bir Pulse yok',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Filtreleri temizle'),
            ),
        ],
      ),
    );
  }
}

class _FeedTimeline extends StatelessWidget {
  const _FeedTimeline({
    required this.pulses,
    required this.currentUserId,
    required this.pulseProvider,
  });

  final List<Pulse> pulses;
  final String? currentUserId;
  final PulseProvider pulseProvider;

  @override
  Widget build(BuildContext context) {
    if (pulses.isEmpty) {
      return const SizedBox.shrink();
    }

    final groups = _groupPulsesByDay(pulses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          _FeedDayHeader(
            label: _formatGroupLabel(group.date),
            pulseCount: group.pulses.length,
          ),
          const SizedBox(height: 12),
          _FeedGroupedTimeline(
            pulses: group.pulses,
            currentUserId: currentUserId,
            pulseProvider: pulseProvider,
          ),
          const SizedBox(height: 28),
        ],
      ],
    );
  }
}

class _FeedGroupedTimeline extends StatelessWidget {
  const _FeedGroupedTimeline({
    required this.pulses,
    required this.currentUserId,
    required this.pulseProvider,
  });

  final List<Pulse> pulses;
  final String? currentUserId;
  final PulseProvider pulseProvider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FixedTimeline.tileBuilder(
      theme: TimelineThemeData(
        nodePosition: 0.08,
        connectorTheme: ConnectorThemeData(
          thickness: 3,
          color: colorScheme.outline.withValues(alpha: 0.18),
        ),
        indicatorTheme: IndicatorThemeData(
          size: 18,
          color: colorScheme.primary,
        ),
      ),
      builder: TimelineTileBuilder.connected(
        connectionDirection: ConnectionDirection.before,
        itemCount: pulses.length,
        contentsBuilder: (context, index) {
          final pulse = pulses[index];
          final color = _timelineColorForPulse(context, pulse, currentUserId);
          final isOwnPost = currentUserId == pulse.userId;
          final bottomPadding = index == pulses.length - 1 ? 0.0 : 24.0;

          return Padding(
            padding: EdgeInsets.only(left: 12, bottom: bottomPadding),
            child: _FeedTimelineTile(
              pulse: pulse,
              lineColor: color,
              isOwnPost: isOwnPost,
              pulseProvider: pulseProvider,
            ),
          );
        },
        indicatorBuilder: (context, index) {
          final color = _timelineColorForPulse(
            context,
            pulses[index],
            currentUserId,
          );
          final isLatest = index == 0;
          return DotIndicator(
            color: isLatest ? color : color.withValues(alpha: 0.75),
            size: isLatest ? 18 : 14,
          );
        },
        connectorBuilder: (context, index, type) {
          final color = _timelineColorForPulse(
            context,
            pulses[index],
            currentUserId,
          ).withValues(alpha: type == ConnectorType.start ? 0.28 : 0.18);
          return SolidLineConnector(color: color, thickness: 3);
        },
      ),
    );
  }
}

class _FeedTimelineTile extends StatelessWidget {
  const _FeedTimelineTile({
    required this.pulse,
    required this.lineColor,
    required this.isOwnPost,
    required this.pulseProvider,
  });

  final Pulse pulse;
  final Color lineColor;
  final bool isOwnPost;
  final PulseProvider pulseProvider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final author = pulseProvider.getUserById(pulse.userId);
    final venue = pulseProvider.getVenueById(pulse.venueId);
    final displayName = _userDisplayName(
      author,
      pulse.userId,
      isOwnPost: isOwnPost,
    );
    final initials = _userInitials(author, pulse.userId, isOwnPost: isOwnPost);
    final timeLabel = pulse.createdAt != null
        ? _formatTime(pulse.createdAt!)
        : 'Az önce';
    final moodLabel = pulse.mood.trim().isNotEmpty ? pulse.mood.trim() : 'Mood';
    final background = Color.alphaBlend(
      lineColor.withValues(alpha: 0.12),
      colorScheme.surface,
    );
    final borderColor = lineColor.withValues(alpha: 0.25);

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              background,
              Color.alphaBlend(lineColor.withValues(alpha: 0.05), background),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 26,
              offset: const Offset(0, 16),
              spreadRadius: -18,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [lineColor.withValues(alpha: 0.35), lineColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(
                      initials,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
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
                  _VisibilityBadge(
                    visibility: pulse.visibility,
                    isOwnPost: isOwnPost,
                    color: lineColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FeedVenueSummary(venue: venue, accentColor: lineColor),
              if (moodLabel.isNotEmpty) ...[
                const SizedBox(height: 14),
                _MoodChip(label: moodLabel, color: lineColor),
              ],
              if (pulse.caption.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  pulse.caption.trim(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.82),
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (pulse.mediaRefs.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pulse.mediaRefs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          pulse.mediaRefs[index],
                          width: 150,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 150,
                                height: 120,
                                color: colorScheme.surfaceContainerHighest,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    PublicPulseCard(pulse: pulse),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeedVenueSummary extends StatelessWidget {
  const _FeedVenueSummary({required this.venue, required this.accentColor});

  final Venue? venue;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final title = venue?.name ?? 'Mekan yükleniyor';
    final subtitle = venue != null
        ? _formatVenueAddressSummary(venue!)
        : 'Konum bilgisi getiriliyor…';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.18),
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 18,
              color: accentColor,
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedFilterData {
  const _FeedFilterData({required this.location, required this.userLabels});

  final _LocationFilterData location;
  final Map<String, String> userLabels;
}

class _LocationFilterData {
  const _LocationFilterData({
    required this.countries,
    required this.citiesByCountry,
    required this.districtsByCountryCity,
  });

  final Set<String> countries;
  final Map<String, Set<String>> citiesByCountry;
  final Map<String, Map<String, Set<String>>> districtsByCountryCity;
}

class _LocationParts {
  const _LocationParts({required this.country, this.city, this.district});

  final String country;
  final String? city;
  final String? district;
}

class _UserOption {
  const _UserOption({required this.id, required this.label});

  final String id;
  final String label;
}

String _userDisplayName(
  AppUser? user,
  String userId, {
  required bool isOwnPost,
}) {
  if (isOwnPost) {
    return 'Sen';
  }

  if (user != null) {
    if (user.displayName.trim().isNotEmpty) {
      return user.displayName.trim();
    }
    if (user.username.trim().isNotEmpty) {
      return user.username.trim();
    }
  }

  return 'User ${userId.length > 6 ? '${userId.substring(0, 6)}…' : userId}';
}

String _userInitials(AppUser? user, String userId, {required bool isOwnPost}) {
  if (isOwnPost) {
    return 'ME';
  }

  final source = user?.displayName.isNotEmpty == true
      ? user!.displayName
      : user?.username.isNotEmpty == true
      ? user!.username
      : userId;

  final words = source
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return userId.isNotEmpty ? userId.substring(0, 1).toUpperCase() : '?';
  }
  if (words.length == 1) {
    return words.first.substring(0, 1).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

String _formatVenueAddressSummary(Venue venue) {
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

String _venueSubtitle(Venue? venue) {
  if (venue == null) {
    return 'Konum bilgisi getiriliyor…';
  }
  return _formatVenueAddressSummary(venue);
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({
    required this.visibility,
    required this.isOwnPost,
    required this.color,
  });

  final String visibility;
  final bool isOwnPost;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = isOwnPost
        ? 'Ben'
        : visibility == 'friends'
        ? 'Arkadaşlar'
        : 'Herkese Açık';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
    final pulseProvider = context.watch<PulseProvider>();
    final author = pulseProvider.getUserById(pulse.userId);

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
    final displayName = _userDisplayName(
      author,
      pulse.userId,
      isOwnPost: isOwnPost,
    );
    final timeLabel = pulse.createdAt != null
        ? _formatTime(pulse.createdAt!)
        : 'Moments ago';
    final moodLabel = pulse.mood.trim().isNotEmpty
        ? pulse.mood.trim()
        : 'No mood';
    final initials = _userInitials(author, pulse.userId, isOwnPost: isOwnPost);
    final venue = pulseProvider.getVenueById(pulse.venueId);
    final venueTitle = venue?.name ?? 'Fetching venue details';
    final venueSubtitle = _venueSubtitle(venue);

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
              _buildVenueTile(
                context,
                title: venueTitle,
                subtitle: venueSubtitle,
                surfaceTint: surfaceTint,
                isOwnPost: isOwnPost,
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
}

class _FeedDayHeader extends StatelessWidget {
  const _FeedDayHeader({required this.label, required this.pulseCount});

  final String label;
  final int pulseCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

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
            pulseCount.toString().padLeft(2, '0'),
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

class _FeedGroup {
  const _FeedGroup({required this.date, required this.pulses});

  final DateTime date;
  final List<Pulse> pulses;
}

List<_FeedGroup> _groupPulsesByDay(List<Pulse> pulses) {
  if (pulses.isEmpty) {
    return const [];
  }

  final sorted = [...pulses]
    ..sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

  final map = <DateTime, List<Pulse>>{};
  for (final pulse in sorted) {
    final createdAt = pulse.createdAt ?? DateTime.now();
    final dayKey = DateTime(createdAt.year, createdAt.month, createdAt.day);
    map.putIfAbsent(dayKey, () => <Pulse>[]).add(pulse);
  }

  final entries = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

  return entries
      .map((entry) => _FeedGroup(date: entry.key, pulses: entry.value))
      .toList(growable: false);
}

String _formatGroupLabel(DateTime date) {
  const weekdays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  const months = [
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
    return weekdays[target.weekday - 1];
  }

  final monthName = months[target.month - 1];
  if (target.year == today.year) {
    return '${target.day} $monthName';
  }

  return '${target.day} $monthName ${target.year}';
}

Color _timelineColorForPulse(
  BuildContext context,
  Pulse pulse,
  String? currentUserId,
) {
  final colorScheme = Theme.of(context).colorScheme;

  if (pulse.userId == currentUserId) {
    return colorScheme.primary;
  }

  switch (pulse.visibility) {
    case 'friends':
      return colorScheme.secondary;
    case 'public':
      return colorScheme.tertiary;
    default:
      return colorScheme.surfaceTint;
  }
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
