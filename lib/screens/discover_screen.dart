import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/venue.dart';
import '../providers/location_provider.dart';
import '../providers/venue_search_provider.dart';

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
  bool _useStaticLocation = false;
  bool _realtimeSearch =
      false; // Control real-time vs on-submit search (default OFF to save API limits)
  bool _isMapMode =
      true; // Toggle between text list and map view (default map mode)

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

  double _getVenueHue(String category) {
    switch (category.toLowerCase()) {
      case 'café':
      case 'cafe':
      case 'coffee shop':
        return BitmapDescriptor.hueOrange; // Brown/Orange for cafes
      case 'restaurant':
      case 'food':
        return BitmapDescriptor.hueRed; // Red for restaurants
      case 'bar':
      case 'nightlife':
        return BitmapDescriptor.hueViolet; // Purple for bars
      case 'hotel':
      case 'lodging':
        return BitmapDescriptor.hueBlue; // Blue for hotels
      case 'shop':
      case 'shopping':
        return BitmapDescriptor.hueRose; // Pink for shops
      case 'entertainment':
      case 'arts':
        return BitmapDescriptor.hueYellow; // Yellow for entertainment
      default:
        return BitmapDescriptor.hueGreen; // Green for others
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMapSection(context, locationProvider, venues),
          const SizedBox(height: 16),
          _buildSearchField(searchProvider),
          const SizedBox(height: 8),
          _buildSearchInfo(searchProvider),
          const SizedBox(height: 8),
          _buildVenueList(venues),
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.search, color: Colors.white, size: 28),
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
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${venues.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Search field
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSearchField(searchProvider),
              ),
              // Search info
              if (searchProvider.isLoading ||
                  searchProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSearchInfo(searchProvider),
                ),
              // Results list
              Expanded(
                child: venues.isEmpty
                    ? const Center(
                        child: Text(
                          'Search for cafes, restaurants, or entertainment venues nearby.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: venues.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final venue = venues[index];
                          return _VenueTile(venue: venue);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(VenueSearchProvider searchProvider) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        return TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _realtimeSearch
              ? (value) => searchProvider.updateQuery(value)
              : null,
          onSubmitted: (value) => searchProvider.updateQuery(value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: 'Search venues',
            hintText: _realtimeSearch
                ? 'Type to search live...'
                : 'Type and press enter to search...',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      searchProvider.updateQuery('');
                    },
                  ),
                if (!_realtimeSearch)
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () =>
                        searchProvider.updateQuery(_controller.text),
                  ),
              ],
            ),
            border: const OutlineInputBorder(),
          ),
        );
      },
    );
  }

  Widget _buildSearchInfo(VenueSearchProvider searchProvider) {
    return Column(
      children: [
        if (!searchProvider.isRemoteEnabled)
          Text(
            'Provider: ${searchProvider.providerName}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        if (searchProvider.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (searchProvider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              searchProvider.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildVenueList(List<Venue> venues) {
    return SizedBox(
      height: 400,
      child: venues.isEmpty
          ? const Center(
              child: Text(
                'No venues found. Search for cafes, restaurants, or entertainment venues.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              itemCount: venues.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final venue = venues[index];
                return _VenueTile(venue: venue);
              },
            ),
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

  Widget _buildMapSection(
    BuildContext context,
    LocationProvider provider,
    List<Venue> venues,
  ) {
    debugPrint('_buildMapSection called with status: ${provider.status}');
    final position = _getEffectivePosition(provider);
    debugPrint('_buildMapSection position: $position');

    if (!((provider.status == LocationStatus.granted &&
            provider.position != null) ||
        _useStaticLocation)) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade200,
        ),
        alignment: Alignment.center,
        child: const Text(
          'Allow location access to preview nearby venues on the map.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: Stack(
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
              myLocationEnabled:
                  false, // Disable for now to avoid permission issues
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Column(
                children: [
                  _MapControlButton(
                    icon: Icons.add,
                    onPressed: _zoomIn,
                    tooltip: 'Zoom In',
                  ),
                  const SizedBox(height: 4),
                  _MapControlButton(
                    icon: Icons.remove,
                    onPressed: _zoomOut,
                    tooltip: 'Zoom Out',
                  ),
                  const SizedBox(height: 4),
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
              top: 8,
              right: 8,
              child: _MapTypeSelector(onTypeChanged: _changeMapType),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(venue.category),
          child: Text(
            venue.category.isNotEmpty ? venue.category[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          venue.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${venue.category} • ${venue.addressSummary}'),
            const SizedBox(height: 4),
            Row(
              children: [
                if (venue.rating.average > 0) ...[
                  Icon(Icons.star, size: 16, color: Colors.amber[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${venue.rating.average.toStringAsFixed(1)} (${venue.rating.count})',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                ],
                if (venue.trendingScore > 0) ...[
                  Icon(Icons.trending_up, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${(venue.trendingScore * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            if (venue.amenities.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: venue.amenities
                    .take(3)
                    .map(
                      (amenity) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          amenity,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'coffee':
      case 'coffee shop':
        return Colors.brown;
      case 'restaurant':
      case 'food':
        return Colors.orange;
      case 'bar':
      case 'nightlife':
        return Colors.purple;
      case 'hotel':
      case 'lodging':
        return Colors.blue;
      case 'shopping':
      case 'retail':
        return Colors.green;
      case 'entertainment':
      case 'arts':
        return Colors.red;
      case 'fitness':
      case 'gym':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
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
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
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
              child: Icon(icon, size: 18, color: Colors.grey[700]),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<MapType>(
        icon: Icon(Icons.layers, size: 18, color: Colors.grey[700]),
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
