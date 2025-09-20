import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

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

    if (positiveAction == null) return;

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

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final status = locationProvider.status;

    Widget content;

    if (locationProvider.isRequesting) {
      content = const CircularProgressIndicator();
    } else if (status == LocationStatus.granted &&
        locationProvider.position != null) {
      final position = locationProvider.position!;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Location locked in!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text('Latitude: ${position.latitude.toStringAsFixed(4)}'),
          Text('Longitude: ${position.longitude.toStringAsFixed(4)}'),
          if (locationProvider.error != null) ...[
            const SizedBox(height: 16),
            Text(
              locationProvider.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'MapLibre will use this position to highlight nearby Pulses and venues.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      String message;
      switch (status) {
        case LocationStatus.disabled:
          message =
              'Location services are turned off. Enable them to see nearby Pulses.';
          break;
        case LocationStatus.denied:
          message = locationProvider.canRequestPermission
              ? 'Pulse needs location access to surface nearby venues. Please grant permission.'
              : 'Location access is denied. Use the button below to open settings and grant location access.';
          break;
        case LocationStatus.unknown:
        case LocationStatus.granted:
          message =
              'Discover Pulses around you. Allow location access to start finding nearby venues.';
          break;
      }

      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (locationProvider.error != null) ...[
            const SizedBox(height: 12),
            Text(
              locationProvider.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: locationProvider.isRequesting
                ? null
                : () => _handleLocationAction(context),
            icon: const Icon(Icons.my_location),
            label: Text(
              status == LocationStatus.disabled
                  ? 'Enable location services'
                  : locationProvider.canRequestPermission
                  ? 'Enable location'
                  : 'Open settings',
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: content),
      ),
    );
  }
}
