import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../providers/location_provider.dart';
import '../providers/pulse_provider.dart';
import '../models/pulse.dart';
import '../models/venue.dart';
import '../services/firestore_service.dart';
import '../utils/distance_utils.dart';
import 'pulse_map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _currentUserId;
  String? _selectedCountry;
  String? _selectedCity;
  String? _selectedDistrict;
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
      _loadUserPulses();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authProvider = context.watch<app_auth.AuthProvider>();
    final userId = authProvider.user?.uid;

    if (userId != _currentUserId) {
      _currentUserId = userId;

      if (mounted) {
        setState(() {
          _selectedCountry = null;
          _selectedCity = null;
          _selectedDistrict = null;
          _showFilters = false;
        });
      }

      if (userId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<PulseProvider>().loadUserPulses(userId);
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<PulseProvider>().clear();
        });
      }
    }
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
        leading: IconButton(
          onPressed: _openPulsesMap,
          icon: const Icon(Icons.map_outlined),
          tooltip: 'Haritada göster',
        ),
        title: const Text('My Pulses'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            icon: Icon(
              _showFilters || _hasActiveLocationFilters
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            tooltip: _showFilters ? 'Filtreleri gizle' : 'Filtreleri göster',
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

          final filterData = _collectLocationFilterData(pulseProvider);
          final countries = _buildSortedList(filterData.countries);
          final cities = _buildAvailableCities(filterData);
          final districts = _buildAvailableDistricts(filterData);

          _ensureSelectionValidity(countries, cities, districts);

          final filteredPulses = _applyLocationFilters(
            pulseProvider.userPulses,
            pulseProvider,
          );
          final groupedPulses = _groupPulsesByDay(filteredPulses);

          final uniqueVenueIds = pulseProvider.userPulses
              .map((pulse) => pulse.venueId)
              .where((id) => id.isNotEmpty)
              .toSet();
          final cachedVenues = pulseProvider.cachedVenues;
          final isVenueLoading =
              uniqueVenueIds.isNotEmpty &&
              uniqueVenueIds.any((id) => !cachedVenues.containsKey(id));

          final sections = <Widget>[];
          if (_showFilters) {
            final filterCard = _buildLocationFilterCard(
              hasPulses: pulseProvider.userPulses.isNotEmpty,
              isLoading: isVenueLoading,
              countries: countries,
              cities: cities,
              districts: districts,
            );

            sections.add(
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child:
                    filterCard ??
                    const SizedBox.shrink(key: ValueKey('home-filter-empty')),
              ),
            );
            if (filterCard != null) {
              sections.add(const SizedBox(height: 12));
            }
          }

          final groupWidgets = <Widget>[];
          for (final group in groupedPulses) {
            groupWidgets.add(
              _PulseDayHeader(
                label: _formatGroupLabel(group.date),
                count: group.pulses.length,
              ),
            );
            groupWidgets.add(const SizedBox(height: 12));
            groupWidgets.add(_PulseTimelineGroup(group: group));
            groupWidgets.add(const SizedBox(height: 32));
          }
          if (groupWidgets.isNotEmpty) {
            groupWidgets.removeLast();
          }

          if (groupWidgets.isEmpty) {
            sections.add(_buildFilteredEmptyState());
          } else {
            sections.addAll(groupWidgets);
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadUserPulses();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
              physics: const AlwaysScrollableScrollPhysics(),
              children: sections.isEmpty ? [const SizedBox.shrink()] : sections,
            ),
          );
        },
      ),
    );
  }

  _LocationFilterData _collectLocationFilterData(PulseProvider provider) {
    final countries = <String>{};
    final citiesByCountry = <String, Set<String>>{};
    final districtsByCountryCity = <String, Map<String, Set<String>>>{};

    for (final pulse in provider.userPulses) {
      final venue = provider.getVenueById(pulse.venueId);
      final location = _parseLocation(venue);
      if (location == null) continue;

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
          final countryMap = districtsByCountryCity.putIfAbsent(
            location.country,
            () => <String, Set<String>>{},
          );
          final districtSet = countryMap.putIfAbsent(city, () => <String>{});
          districtSet.add(district);
        }
      }
    }

    return _LocationFilterData(
      countries: countries,
      citiesByCountry: citiesByCountry,
      districtsByCountryCity: districtsByCountryCity,
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

  void _ensureSelectionValidity(
    List<String> countries,
    List<String> cities,
    List<String> districts,
  ) {
    var newCountry = _selectedCountry;
    var newCity = _selectedCity;
    var newDistrict = _selectedDistrict;

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

    if (newCountry != _selectedCountry ||
        newCity != _selectedCity ||
        newDistrict != _selectedDistrict) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedCountry = newCountry;
          _selectedCity = newCity;
          _selectedDistrict = newDistrict;
        });
      });
    }
  }

  Widget? _buildLocationFilterCard({
    required bool hasPulses,
    required bool isLoading,
    required List<String> countries,
    required List<String> cities,
    required List<String> districts,
  }) {
    if (!hasPulses) {
      return null;
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final hasLocationData =
        countries.isNotEmpty || cities.isNotEmpty || districts.isNotEmpty;

    if (!hasLocationData && !isLoading) {
      return null;
    }

    if (!hasLocationData && isLoading) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mekan bilgileri yükleniyor…',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final calculatedWidth = (screenWidth - 32 - 16) / 3;
    final fieldWidth = calculatedWidth.clamp(150.0, 220.0);

    final fields = <Widget>[];
    if (countries.isNotEmpty || _selectedCountry != null) {
      fields.add(
        _buildDropdownField(
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
          dense: true,
        ),
      );
    }

    if (cities.isNotEmpty || _selectedCity != null) {
      fields.add(
        _buildDropdownField(
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
          dense: true,
        ),
      );
    }

    if (districts.isNotEmpty || _selectedDistrict != null) {
      fields.add(
        _buildDropdownField(
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
          dense: true,
        ),
      );
    }

    if (fields.isEmpty) {
      return null;
    }

    return Card(
      key: const ValueKey('home-filter-card'),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Konuma göre filtrele',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isLoading)
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
                if (_hasActiveLocationFilters)
                  TextButton(
                    onPressed: _resetLocationFilters,
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

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?>? onChanged,
    double? width,
    bool dense = false,
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

    final dropdown = DropdownButtonFormField<String?>(
      value: dropdownValue,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      isDense: dense,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: dense ? Theme.of(context).textTheme.bodySmall : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: dense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: dense ? Theme.of(context).textTheme.bodySmall : null,
      dropdownColor: Theme.of(context).colorScheme.surface,
    );

    if (width != null) {
      return SizedBox(width: width, child: dropdown);
    }

    return dropdown;
  }

  void _resetLocationFilters() {
    setState(() {
      _selectedCountry = null;
      _selectedCity = null;
      _selectedDistrict = null;
    });
  }

  void _openPulsesMap() {
    final pulseProvider = context.read<PulseProvider>();
    final pulses = _applyLocationFilters(
      pulseProvider.userPulses,
      pulseProvider,
    );

    final entries = <PulseMapEntry>[];
    for (final pulse in pulses) {
      final venue = pulseProvider.getVenueById(pulse.venueId);
      final geo = venue?.location.geoPoint;
      if (venue == null || geo == null) {
        continue;
      }
      entries.add(PulseMapEntry(pulse: pulse, venue: venue));
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
          title: 'Pulse Haritası',
          entries: entries,
          relativeTimeFormatter: formatCompactRelativeTime,
          clockTimeFormatter: formatClockTime,
        ),
      ),
    );
  }

  bool get _hasActiveLocationFilters =>
      _selectedCountry != null ||
      _selectedCity != null ||
      _selectedDistrict != null;

  List<Pulse> _applyLocationFilters(
    List<Pulse> pulses,
    PulseProvider provider,
  ) {
    if (!_hasActiveLocationFilters) {
      return pulses;
    }

    return pulses.where((pulse) {
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.travel_explore_outlined,
            size: 48,
            color: colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            _hasActiveLocationFilters
                ? 'Bu filtreyle eşleşen Pulse bulunamadı'
                : 'Henüz Pulse bulunamadı',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (_hasActiveLocationFilters) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _resetLocationFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Filtreleri temizle'),
            ),
          ],
        ],
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

class _PulseTimelineGroup extends StatelessWidget {
  const _PulseTimelineGroup({required this.group});

  final _PulseGroup group;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var index = 0; index < group.pulses.length; index++) {
      final pulse = group.pulses[index];
      children.add(
        _PulseTimelineRow(
          pulse: pulse,
          isFirst: index == 0,
          isLast: index == group.pulses.length - 1,
          isLatest: index == 0,
        ),
      );
      if (index != group.pulses.length - 1) {
        children.add(const SizedBox(height: 24));
      }
    }

    return Column(children: children);
  }
}

class _PulseTimelineRow extends StatelessWidget {
  const _PulseTimelineRow({
    required this.pulse,
    required this.isFirst,
    required this.isLast,
    required this.isLatest,
  });

  final Pulse pulse;
  final bool isFirst;
  final bool isLast;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TimelineNode(
            isFirst: isFirst,
            isLast: isLast,
            isLatest: isLatest,
            colorScheme: colorScheme,
          ),
          const SizedBox(width: 12),
          Expanded(child: PulseTimelineTile(pulse: pulse)),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.isFirst,
    required this.isLast,
    required this.isLatest,
    required this.colorScheme,
  });

  final bool isFirst;
  final bool isLast;
  final bool isLatest;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final lineColor = colorScheme.primary.withValues(alpha: 0.28);
    final dotColor = isLatest
        ? colorScheme.primary
        : colorScheme.primary.withValues(alpha: 0.6);
    final dotSize = isLatest ? 18.0 : 14.0;
    const lineWidth = 2.4;

    return SizedBox(
      width: 36,
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: lineWidth,
                margin: EdgeInsets.only(bottom: dotSize / 2),
                decoration: BoxDecoration(
                  color: isFirst ? Colors.transparent : lineColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.surface, width: 2),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: lineWidth,
                margin: EdgeInsets.only(top: dotSize / 2),
                decoration: BoxDecoration(
                  color: isLast ? Colors.transparent : lineColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PulseTimelineTile extends StatelessWidget {
  const PulseTimelineTile({super.key, required this.pulse});

  final Pulse pulse;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locationProvider = context.watch<LocationProvider>();
    final position = locationProvider.status == LocationStatus.granted
        ? locationProvider.position
        : null;
    final timeLabel = pulse.createdAt != null
        ? formatClockTime(pulse.createdAt!)
        : 'Saat bilinmiyor';
    final moodLabel = pulse.mood.trim().isEmpty ? 'Mood' : pulse.mood.trim();

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.06),
            colorScheme.surface,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 12),
              blurRadius: 24,
              spreadRadius: -16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  timeLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    moodLabel,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<Venue?>(
              future: FirestoreService().getVenue(pulse.venueId),
              builder: (context, snapshot) {
                final venue = snapshot.data;
                final title = venue?.name ?? 'Mekan yükleniyor';
                final subtitle = venue != null
                    ? formatVenueAddress(venue)
                    : 'Konum detayı getiriliyor…';
                final distanceLabel = venue != null
                    ? formatVenueDistance(position, venue)
                    : null;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: colorScheme.primary,
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
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (distanceLabel != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                distanceLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
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
        return PulseDetailSheet(pulse: pulse);
      },
    );
  }
}

class PulseDetailSheet extends StatelessWidget {
  const PulseDetailSheet({super.key, required this.pulse});

  final Pulse pulse;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, -4),
              blurRadius: 24,
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
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                PulseCard(pulse: pulse, margin: EdgeInsets.zero),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PulseCard extends StatelessWidget {
  const PulseCard({super.key, required this.pulse, this.margin});

  final Pulse pulse;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final locationProvider = context.watch<LocationProvider>();
    final position = locationProvider.status == LocationStatus.granted
        ? locationProvider.position
        : null;

    final moodLabel = pulse.mood.trim().isNotEmpty ? pulse.mood.trim() : 'Mood';
    final createdAt = pulse.createdAt;
    final gradient = [
      Color.alphaBlend(
        colorScheme.primary.withValues(alpha: 0.16),
        colorScheme.surface,
      ),
      Color.alphaBlend(
        colorScheme.secondary.withValues(alpha: 0.08),
        colorScheme.surface,
      ),
    ];

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 18),
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
                      moodLabel.length >= 2
                          ? moodLabel.substring(0, 2).toUpperCase()
                          : moodLabel.toUpperCase(),
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
                            formatRelativeTime(createdAt),
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
                      subtitle: formatVenueAddress(venue),
                      distanceLabel: formatVenueDistance(position, venue),
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildVenueTile(
                      context,
                      title: 'Mekan yükleniyor',
                      subtitle: 'Konum detayı getiriliyor...',
                      distanceLabel: null,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    );
                  }

                  return _buildVenueTile(
                    context,
                    title: 'Mekan bilinmiyor',
                    subtitle: 'Bu Pulse için konum bulunamadı',
                    distanceLabel: null,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
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
    String? distanceLabel,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
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
                if (distanceLabel != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      distanceLabel,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
}

class _PulseDayHeader extends StatelessWidget {
  const _PulseDayHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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

String formatRelativeTime(DateTime dateTime) {
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

String formatCompactRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }

  final weeks = difference.inDays ~/ 7;
  if (weeks < 5) {
    return '${weeks}w ago';
  }

  final months = difference.inDays ~/ 30;
  if (months < 12) {
    return '${months}mo ago';
  }

  final years = difference.inDays ~/ 365;
  return '${years}y ago';
}

String formatClockTime(DateTime dateTime) {
  final hours = dateTime.hour.toString().padLeft(2, '0');
  final minutes = dateTime.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

String formatVenueAddress(Venue venue) {
  final addressParts = venue.addressSummary
      .split(',')
      .map((part) => part.trim())
      .where((part) {
        if (part.isEmpty) {
          return false;
        }
        if (part.length >= 5) {
          final potentialZip = part.substring(0, 5);
          if (int.tryParse(potentialZip) != null) {
            return false;
          }
        }
        return true;
      })
      .toList();

  if (addressParts.length >= 2) {
    return '${addressParts[addressParts.length - 2]}, ${addressParts.last}';
  }

  return addressParts.isNotEmpty ? addressParts.last : venue.addressSummary;
}
