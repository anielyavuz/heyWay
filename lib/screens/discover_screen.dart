import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
import 'package:provider/provider.dart';
import '../models/venue.dart';
import '../providers/location_provider.dart';
import '../providers/venue_search_provider.dart';
import '../theme/map_styles.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final TextEditingController _controller;
  MaplibreMapController? _mapController;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLocationAction(BuildContext context) async {
    final provider = context.read<LocationProvider>();
    final status = provider.status;

    String title;
    String message;
    Future<void> Function()? positiveAction;
    String positiveLabel;

    if (status == LocationStatus.disabled) {
      title = 'Enable Location Services';
      message =
          'Location services are turned off. Open your device settings to view nearby Pulses.';
      positiveAction = () async {
        await provider.openLocationSettings();
        await provider.initialize();
      };
      positiveLabel = 'Open Settings';
    } else if (provider.isDeniedForever) {
      title = 'Allow Location Access';
      message =
          'Location permission is permanently denied. Open app settings to let Pulse access your location.';
      positiveAction = () => provider.openAppSettings();
      positiveLabel = 'Open Settings';
    } else {
      title = 'Allow Location Access';
      message =
          'Pulse needs your location to highlight nearby venues and Pulses. Do you want to enable it now?';
      positiveAction = () => provider.requestPermissionAndFetch();
      positiveLabel = 'Enable';
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await positiveAction?.call();
              },
              child: Text(positiveLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _zoomIn() async {
    final controller = _mapController;
    if (_mapReady && controller != null) {
      await controller.animateCamera(CameraUpdate.zoomIn());
    }
  }

  Future<void> _zoomOut() async {
    final controller = _mapController;
    if (_mapReady && controller != null) {
      await controller.animateCamera(CameraUpdate.zoomOut());
    }
  }

  Future<void> _refreshMap(
    List<Venue> venues,
    LocationProvider locationProvider,
  ) async {
    final controller = _mapController;
    if (!_mapReady || controller == null) return;

    await controller.clearSymbols();

    for (final venue in venues) {
      final point = venue.location.geoPoint;
      if (point == null) continue;
      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(point.latitude, point.longitude),
          iconImage: 'marker-15',
          iconSize: 1.2,
          textField: venue.name,
          textOffset: const Offset(0, 1.4),
          textSize: 12,
        ),
      );
    }

    final position = locationProvider.position;
    if (position != null) {
      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(position.latitude, position.longitude),
          iconImage: 'marker-15',
          iconColor: '#2F80ED',
          textField: 'You',
          textOffset: const Offset(0, 1.4),
          textSize: 11,
        ),
      );
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          13,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final searchProvider = context.watch<VenueSearchProvider>();

    if (_controller.text != searchProvider.query) {
      _controller.value = TextEditingValue(
        text: searchProvider.query,
        selection: TextSelection.collapsed(offset: searchProvider.query.length),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshMap(searchProvider.results, locationProvider);
    });

    final locationSection = _buildLocationSection(locationProvider);
    final venues = searchProvider.results;

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: locationSection,
              ),
            ),
            const SizedBox(height: 16),
            _buildMapSection(context, locationProvider, venues),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              onChanged: searchProvider.updateQuery,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search venues',
                hintText: 'Try cafe, rooftop, or vegan',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: venues.isEmpty
                  ? const Center(
                      child: Text(
                        'No venues match your search yet. Try a different keyword.',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(LocationProvider provider) {
    final status = provider.status;

    if (provider.isRequesting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == LocationStatus.granted && provider.position != null) {
      final position = provider.position!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location locked in!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Latitude: ${position.latitude.toStringAsFixed(4)}'),
          Text('Longitude: ${position.longitude.toStringAsFixed(4)}'),
          if (provider.error != null) ...[
            const SizedBox(height: 12),
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 12),
          const Text(
            'MapLibre will use this position to highlight nearby Pulses and venues.',
          ),
        ],
      );
    }

    String message;
    switch (status) {
      case LocationStatus.disabled:
        message =
            'Location services are turned off. Enable them to see nearby Pulses.';
        break;
      case LocationStatus.denied:
        message = provider.canRequestPermission
            ? 'Pulse needs location access to surface nearby venues. Please grant permission.'
            : 'Location access is denied. Use the button below to open settings and grant location access.';
        break;
      case LocationStatus.unknown:
      case LocationStatus.granted:
        message =
            'Discover Pulses around you. Allow location access to start finding nearby venues.';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (provider.error != null) ...[
          const SizedBox(height: 12),
          Text(provider.error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: provider.isRequesting
              ? null
              : () => _handleLocationAction(context),
          icon: Icon(
            status == LocationStatus.disabled
                ? Icons.settings
                : Icons.my_location,
          ),
          label: Text(
            status == LocationStatus.disabled
                ? 'Enable location services'
                : provider.canRequestPermission
                ? 'Enable location'
                : 'Open settings',
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection(
    BuildContext context,
    LocationProvider provider,
    List<Venue> venues,
  ) {
    final position = provider.position;
    if (!(provider.status == LocationStatus.granted && position != null)) {
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
            MaplibreMap(
              styleString: MapStyles.styleForBrightness(
                Theme.of(context).brightness,
              ),
              initialCameraPosition: CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 13,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _mapReady = false;
              },
              onStyleLoadedCallback: () {
                _mapReady = true;
                _refreshMap(venues, provider);
              },
              myLocationEnabled: false,
              compassEnabled: true,
              rotateGesturesEnabled: true,
              minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Column(
                children: [
                  _MapZoomButton(icon: Icons.add, onPressed: _zoomIn),
                  const SizedBox(height: 8),
                  _MapZoomButton(icon: Icons.remove, onPressed: _zoomOut),
                ],
              ),
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
    return ListTile(
      leading: CircleAvatar(
        child: Text(venue.category.characters.first.toUpperCase()),
      ),
      title: Text(venue.name),
      subtitle: Text('${venue.category} • ${venue.addressSummary}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${venue.rating.average.toStringAsFixed(1)} ★'),
          Text('${venue.rating.count} reviews'),
        ],
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Material(
        color: Colors.white.withOpacity(0.9),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20)),
        ),
      ),
    );
  }
}
