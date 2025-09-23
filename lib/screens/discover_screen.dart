import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/venue.dart';
import '../providers/location_provider.dart';
import '../providers/venue_search_provider.dart';
import '../utils/distance_utils.dart';
import 'pulse_composer_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  final bool _useStaticLocation = false;
  bool _realtimeSearch =
      false; // Control real-time vs on-submit search (default OFF to save API limits)
  bool _isMapMode =
      false; // Toggle between text list and map view (default text mode)

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  // Static location for testing (Istanbul center)
  Position get _staticPosition => Position(
    latitude: 41.0082,
    longitude: 28.9784,
    timestamp: DateTime.now(),
    accuracy: 10.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );

  Position? _getEffectivePosition(LocationProvider provider) {
    return _useStaticLocation ? _staticPosition : provider.position;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _centerOnUser() {
    final locationProvider = context.read<LocationProvider>();
    final position = _getEffectivePosition(locationProvider);

    if (position != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    }
  }

  void _changeMapType(MapType type) {
    if (_currentMapType == type) return;

    setState(() {
      _currentMapType = type;
    });
  }

  Future<void> _sharePulse(BuildContext context, Venue venue) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PulseComposerScreen(venue: venue),
      ),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Pulse paylaşıldı!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Set<Marker> _buildMarkers(List<Venue> venues, Position? userPosition) {
    final markers = <Marker>{};

    // Add venue markers
    for (int i = 0; i < venues.length; i++) {
      final venue = venues[i];
      final point = venue.location.geoPoint;
      if (point == null) continue;

      final emoji = _getVenueEmoji(venue.category);
      final shortName = venue.name.length > 15
          ? '${venue.name.substring(0, 15)}...'
          : venue.name;

      markers.add(
        Marker(
          markerId: MarkerId('venue_$i'),
          position: LatLng(point.latitude, point.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getVenueHue(venue.category),
          ),
          infoWindow: InfoWindow(
            title: '$emoji $shortName',
            snippet: '${venue.category} • ${venue.addressSummary}',
          ),
        ),
      );
    }

    // Add user location marker
    if (userPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(userPosition.latitude, userPosition.longitude),
          infoWindow: const InfoWindow(title: '📍 Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final searchProvider = context.watch<VenueSearchProvider>();

    // Debug guards
    debugPrint(
      'DiscoverScreen build - locationProvider.status: ${locationProvider.status}',
    );
    debugPrint(
      'DiscoverScreen build - _useStaticLocation: $_useStaticLocation',
    );

    if (_controller.text != searchProvider.query) {
      _controller.value = TextEditingValue(
        text: searchProvider.query,
        selection: TextSelection.collapsed(offset: searchProvider.query.length),
      );
    }

    // Update location when first available
    final effectivePosition = _getEffectivePosition(locationProvider);
    if (effectivePosition != null && searchProvider.results.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          searchProvider.updateLocation(effectivePosition);
        }
      });
    }

    final venues = searchProvider.results;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Allow resizing when keyboard appears
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View Mode Toggle - Text/Map
              Icon(
                _isMapMode ? Icons.map : Icons.list,
                size: 16,
                color: Colors.blue,
              ),
              const SizedBox(width: 4),
              Text(
                _isMapMode ? 'Map' : 'Text',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _isMapMode,
                  onChanged: (value) {
                    setState(() {
                      _isMapMode = value;
                    });
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 120,
        title: const Text('Discover'),
        centerTitle: true,
        actions: [
          // Live Search Toggle
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flash_on,
                  size: 16,
                  color: _realtimeSearch ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 12,
                    color: _realtimeSearch ? Colors.blue : Colors.grey,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _realtimeSearch,
                    onChanged: (value) {
                      setState(() {
                        _realtimeSearch = value;
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isMapMode
          ? _buildFullScreenMapMode(
              context,
              locationProvider,
              venues,
              searchProvider,
            )
          : _buildTextMode(context, locationProvider, venues, searchProvider),
    );
  }

  Widget _buildTextMode(
    BuildContext context,
    LocationProvider locationProvider,
    List<Venue> venues,
    VenueSearchProvider searchProvider,
  ) {
    final userPosition = _getEffectivePosition(locationProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _DiscoverSearchPanel(
            searchProvider: searchProvider,
            resultCount: venues.length,
            useStaticLocation: _useStaticLocation,
            isRealtimeSearch: _realtimeSearch,
            buildSearchField: () => _buildSearchField(context, searchProvider),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: venues.isEmpty
                ? const _DiscoverEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: venues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final venue = venues[index];
                      return _VenueCard(
                        venue: venue,
                        userPosition: userPosition,
                        onSharePulse: () => _sharePulse(context, venue),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenMapMode(
    BuildContext context,
    LocationProvider locationProvider,
    List<Venue> venues,
    VenueSearchProvider searchProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Full screen map
          _buildFullScreenMap(context, locationProvider, venues),
          // Search button to open bottom modal
          Positioned(
            top: 50,
            left: 16,
            child: GestureDetector(
              onTap: () => _showSearchModal(context, searchProvider, venues),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.search_rounded,
                        color: colorScheme.onPrimary,
                        size: 28,
                      ),
                    ),
                    if (venues.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${venues.length}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onError,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchModal(
    BuildContext context,
    VenueSearchProvider searchProvider,
    List<Venue> venues,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 16),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSearchField(context, searchProvider),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: _buildSearchInfo(context, searchProvider),
                ),
                Expanded(
                  child: venues.isEmpty
                      ? const _DiscoverEmptyState()
                      : Builder(
                          builder: (context) {
                            final locationProvider = context
                                .watch<LocationProvider>();
                            final userPosition = _getEffectivePosition(
                              locationProvider,
                            );

                            return ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: venues.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final venue = venues[index];
                                return _VenueCard(
                                  venue: venue,
                                  userPosition: userPosition,
                                  onSharePulse: () =>
                                      _sharePulse(context, venue),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(
    BuildContext context,
    VenueSearchProvider searchProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: colorScheme.surface,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 12),
                spreadRadius: -12,
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _realtimeSearch
                ? (text) => searchProvider.updateQuery(text)
                : null,
            onSubmitted: (text) {
              searchProvider.updateQuery(text, immediate: true);
              FocusScope.of(context).unfocus();
            },
            textInputAction: TextInputAction.search,
            style: textTheme.bodyMedium,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              prefixIcon: Icon(Icons.search, color: colorScheme.primary),
              hintText: _realtimeSearch
                  ? 'Yakındaki mekanları canlı ara...'
                  : 'Mekan ara ve enter’a bas...',
              border: InputBorder.none,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Temizle',
                      onPressed: () {
                        _controller.clear();
                        searchProvider.updateQuery('');
                      },
                    ),
                  if (!_realtimeSearch)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          searchProvider.updateQuery(
                            _controller.text,
                            immediate: true,
                          );
                          FocusScope.of(context).unfocus();
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          foregroundColor: colorScheme.onPrimary,
                          backgroundColor: colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Ara'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchInfo(
    BuildContext context,
    VenueSearchProvider searchProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final infoWidgets = <Widget>[];

    infoWidgets.add(
      Row(
        children: [
          _InfoChip(
            icon: Icons.public,
            label: searchProvider.providerName,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            foregroundColor: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          _InfoChip(
            icon: Icons.flash_on,
            label: _realtimeSearch ? 'Canlı arama' : 'Manuel arama',
            backgroundColor: colorScheme.secondary.withValues(alpha: 0.12),
            foregroundColor: colorScheme.secondary,
          ),
        ],
      ),
    );

    if (searchProvider.isLoading) {
      infoWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(
            minHeight: 4,
            color: colorScheme.primary,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
      );
    }

    if (searchProvider.errorMessage != null) {
      infoWidgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 16, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  searchProvider.errorMessage!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infoWidgets,
    );
  }

  Widget _buildFullScreenMap(
    BuildContext context,
    LocationProvider provider,
    List<Venue> venues,
  ) {
    debugPrint('_buildFullScreenMap called with status: ${provider.status}');
    final position = _getEffectivePosition(provider);
    debugPrint('_buildFullScreenMap position: $position');

    if (!((provider.status == LocationStatus.granted &&
            provider.position != null) ||
        _useStaticLocation)) {
      return Container(
        decoration: BoxDecoration(color: Colors.grey.shade200),
        alignment: Alignment.center,
        child: const Text(
          'Allow location access to preview nearby venues on the map.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(position!.latitude, position.longitude),
            zoom: 15.0,
          ),
          mapType: _currentMapType,
          markers: _buildMarkers(venues, position),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        // Map controls
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              _MapControlButton(
                icon: Icons.add,
                onPressed: _zoomIn,
                tooltip: 'Zoom In',
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.remove,
                onPressed: _zoomOut,
                tooltip: 'Zoom Out',
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.my_location,
                onPressed: _centerOnUser,
                tooltip: 'Center on Location',
              ),
            ],
          ),
        ),
        // Map type selector
        Positioned(
          right: 16,
          top: 120,
          child: _MapTypeSelector(onTypeChanged: _changeMapType),
        ),
      ],
    );
  }
}

class _DiscoverSearchPanel extends StatelessWidget {
  const _DiscoverSearchPanel({
    required this.searchProvider,
    required this.resultCount,
    required this.useStaticLocation,
    required this.isRealtimeSearch,
    required this.buildSearchField,
  });

  final VenueSearchProvider searchProvider;
  final int resultCount;
  final bool useStaticLocation;
  final bool isRealtimeSearch;
  final Widget Function() buildSearchField;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.95),
            colorScheme.secondary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 18),
            spreadRadius: -18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yeni yerler keşfet',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Yakınındaki kafeler, restoranlar ve eğlence mekanlarını ara.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: colorScheme.copyWith(surface: colorScheme.surface),
            ),
            child: buildSearchField(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.place,
                label: useStaticLocation ? 'Demo konum' : 'Canlı konum',
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.12),
                foregroundColor: colorScheme.onPrimary,
              ),
              if (searchProvider.query.isNotEmpty)
                _InfoChip(
                  icon: Icons.check_circle_outline,
                  label: '$resultCount sonuç',
                  backgroundColor: colorScheme.onPrimary.withValues(
                    alpha: 0.12,
                  ),
                  foregroundColor: colorScheme.onPrimary,
                ),
              _InfoChip(
                icon: Icons.explore,
                label: isRealtimeSearch
                    ? 'Canlı arama açık'
                    : 'Canlı arama kapalı',
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.12),
                foregroundColor: colorScheme.onPrimary,
              ),
            ],
          ),
          if (searchProvider.isLoading || searchProvider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (searchProvider.isLoading)
                    LinearProgressIndicator(
                      minHeight: 4,
                      color: colorScheme.onPrimary,
                      backgroundColor: colorScheme.onPrimary.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  if (searchProvider.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              searchProvider.errorMessage!,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscoverEmptyState extends StatelessWidget {
  const _DiscoverEmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: colorScheme.surface,
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore, size: 48, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Aramaya başla',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kafeler, restoranlar veya eğlence mekanlarını arayarak yeni yerler keşfet. '
              'Haritaya geçerek yakınındaki önerileri görebilirsin.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.onSharePulse,
    this.userPosition,
  });

  final Venue venue;
  final VoidCallback onSharePulse;
  final Position? userPosition;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final emoji = _getVenueEmoji(venue.category);
    final address = _formatVenueAddress(venue);
    final distanceLabel = formatVenueDistance(userPosition, venue);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              colorScheme.primary.withValues(alpha: 0.16),
              colorScheme.surface,
            ),
            Color.alphaBlend(
              colorScheme.secondary.withValues(alpha: 0.08),
              colorScheme.surface,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 18),
            spreadRadius: -16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (venue.coverPhotoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  venue.coverPhotoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
                            colorScheme.primary.withValues(alpha: 0.32),
                            colorScheme.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            venue.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${venue.category} • $address',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (venue.rating.average > 0)
                          _VenueMetricChip(
                            icon: Icons.star_rounded,
                            label: venue.rating.average.toStringAsFixed(1),
                            caption: '(${venue.rating.count})',
                            color: Colors.amber[600]!,
                          ),
                        if (venue.trendingScore > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _VenueMetricChip(
                              icon: Icons.trending_up,
                              label: '${(venue.trendingScore * 100).toInt()}%',
                              caption: 'Trend',
                              color: Colors.green[500]!,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (venue.amenities.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: venue.amenities
                        .take(4)
                        .map((amenity) => _AmenityChip(label: amenity))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onSharePulse,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: Icon(
                      Icons.favorite_border,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    label: Text(
                      'Pulse paylaş',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueMetricChip extends StatelessWidget {
  const _VenueMetricChip({
    required this.icon,
    required this.label,
    this.caption,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(width: 4),
            Text(caption!, style: textTheme.labelSmall?.copyWith(color: color)),
          ],
        ],
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatVenueAddress(Venue venue) {
  final addressParts = venue.addressSummary
      .split(',')
      .map((part) => part.trim())
      .where((part) {
        if (part.isEmpty) {
          return false;
        }
        final normalized = part.replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.length >= 5) {
          return false;
        }
        return true;
      })
      .toList();

  if (addressParts.length >= 2) {
    return '${addressParts[addressParts.length - 2]}, ${addressParts.last}';
  }

  return addressParts.isNotEmpty ? addressParts.last : venue.addressSummary;
}

double _getVenueHue(String category) {
  switch (category.toLowerCase()) {
    case 'café':
    case 'cafe':
    case 'coffee shop':
      return BitmapDescriptor.hueOrange;
    case 'restaurant':
    case 'food':
      return BitmapDescriptor.hueRed;
    case 'bar':
    case 'nightlife':
      return BitmapDescriptor.hueViolet;
    case 'hotel':
    case 'lodging':
      return BitmapDescriptor.hueBlue;
    case 'shop':
    case 'shopping':
      return BitmapDescriptor.hueRose;
    case 'entertainment':
    case 'arts':
      return BitmapDescriptor.hueYellow;
    default:
      return BitmapDescriptor.hueGreen;
  }
}

String _getVenueEmoji(String category) {
  switch (category.toLowerCase()) {
    case 'café':
    case 'cafe':
    case 'coffee shop':
      return '☕️';
    case 'restaurant':
    case 'food':
      return '🍽️';
    case 'bar':
    case 'nightlife':
    case 'night_club':
      return '🍺';
    case 'hotel':
    case 'lodging':
      return '🏨';
    case 'shop':
    case 'shopping':
      return '🛍️';
    case 'entertainment':
    case 'arts':
    case 'tourist_attraction':
      return '🎭';
    case 'gym':
    case 'fitness':
      return '💪';
    case 'hospital':
    case 'health':
      return '🏥';
    case 'bank':
      return '🏦';
    case 'gas_station':
      return '⛽';
    case 'parking':
      return '🅿️';
    default:
      return '📍';
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 18, color: colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapTypeSelector extends StatelessWidget {
  const _MapTypeSelector({required this.onTypeChanged});

  final Function(MapType) onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: PopupMenuButton<MapType>(
        icon: Icon(Icons.layers, size: 18, color: colorScheme.onSurface),
        tooltip: 'Change Map Type',
        onSelected: onTypeChanged,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: MapType.normal,
            child: Row(
              children: [
                Icon(Icons.map, size: 16),
                SizedBox(width: 8),
                Text('Normal'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: MapType.satellite,
            child: Row(
              children: [
                Icon(Icons.satellite, size: 16),
                SizedBox(width: 8),
                Text('Satellite'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: MapType.terrain,
            child: Row(
              children: [
                Icon(Icons.terrain, size: 16),
                SizedBox(width: 8),
                Text('Terrain'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: MapType.hybrid,
            child: Row(
              children: [
                Icon(Icons.layers, size: 16),
                SizedBox(width: 8),
                Text('Hybrid'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
