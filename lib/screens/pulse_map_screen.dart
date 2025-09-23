import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/pulse.dart';
import '../models/venue.dart';
import '../services/location_service.dart';

typedef CompactRelativeTimeFormatter = String? Function(DateTime dateTime);
typedef ClockTimeFormatter = String Function(DateTime dateTime);

typedef MarkerColorResolver = Color Function(ColorScheme colorScheme);
typedef MarkerTextColorResolver = Color Function(ColorScheme colorScheme);
typedef MarkerLabelBuilder =
    String Function(PulseMapEntry entry, String? relativeTime);

class PulseMapEntry {
  const PulseMapEntry({
    required this.pulse,
    required this.venue,
    this.userLabel,
  });

  final Pulse pulse;
  final Venue venue;
  final String? userLabel;
}

class PulseMapScreen extends StatefulWidget {
  const PulseMapScreen({
    super.key,
    required this.title,
    required this.entries,
    this.relativeTimeFormatter,
    this.clockTimeFormatter,
    this.markerColorResolver,
    this.markerTextColorResolver,
    this.markerLabelBuilder,
    this.markerScale = 1.0,
  });

  final String title;
  final List<PulseMapEntry> entries;
  final CompactRelativeTimeFormatter? relativeTimeFormatter;
  final ClockTimeFormatter? clockTimeFormatter;
  final MarkerColorResolver? markerColorResolver;
  final MarkerTextColorResolver? markerTextColorResolver;
  final MarkerLabelBuilder? markerLabelBuilder;
  final double markerScale;

  @override
  State<PulseMapScreen> createState() => _PulseMapScreenState();
}

class _PulseMapScreenState extends State<PulseMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final LocationService _locationService = const LocationService();
  Set<Marker> _markers = const <Marker>{};
  bool _markersReady = false;
  bool _locationPermissionGranted = false;
  bool _isFetchingLocation = false;
  bool _hasCenteredOnUser = false;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateMarkers();
      _initializeUserLocation();
    });
  }

  CameraPosition get _initialCameraPosition {
    if (_userLocation != null) {
      return CameraPosition(target: _userLocation!, zoom: 15);
    }
    if (widget.entries.isNotEmpty) {
      final firstEntry = widget.entries.first;
      final geo = firstEntry.venue.location.geoPoint!;
      return CameraPosition(
        target: LatLng(geo.latitude, geo.longitude),
        zoom: 13,
      );
    }
    return const CameraPosition(target: LatLng(39.925533, 32.866287), zoom: 5);
  }

  LatLngBounds? get _bounds {
    if (widget.entries.length <= 1) {
      return null;
    }
    double? minLat, maxLat, minLng, maxLng;
    for (final entry in widget.entries) {
      final geo = entry.venue.location.geoPoint!;
      minLat = minLat == null
          ? geo.latitude
          : (geo.latitude < minLat ? geo.latitude : minLat);
      maxLat = maxLat == null
          ? geo.latitude
          : (geo.latitude > maxLat ? geo.latitude : maxLat);
      minLng = minLng == null
          ? geo.longitude
          : (geo.longitude < minLng ? geo.longitude : minLng);
      maxLng = maxLng == null
          ? geo.longitude
          : (geo.longitude > maxLng ? geo.longitude : maxLng);
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return null;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _generateMarkers() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final markerColor =
        widget.markerColorResolver?.call(colorScheme) ?? colorScheme.primary;
    final markerTextColor =
        widget.markerTextColorResolver?.call(colorScheme) ??
        colorScheme.onPrimary;

    final markers = <Marker>{};
    for (final entry in widget.entries) {
      final geo = entry.venue.location.geoPoint!;
      final position = LatLng(geo.latitude, geo.longitude);
      final pulseTime = entry.pulse.createdAt;
      final mood = entry.pulse.mood.trim();
      final relativeTime = pulseTime != null
          ? widget.relativeTimeFormatter?.call(pulseTime) ??
                _defaultCompactRelativeTime(pulseTime)
          : null;

      final clock = pulseTime != null
          ? widget.clockTimeFormatter?.call(pulseTime) ??
                _defaultClockTime(pulseTime)
          : null;

      final snippetPieces = <String>[];
      if (relativeTime != null && relativeTime.isNotEmpty) {
        snippetPieces.add(relativeTime);
      }
      if (clock != null) {
        snippetPieces.add(clock);
      }
      if (mood.isNotEmpty) {
        snippetPieces.add(mood);
      }

      final markerLabel =
          widget.markerLabelBuilder?.call(entry, relativeTime) ??
          _defaultMarkerLabel(entry, relativeTime);

      final icon = await _createMarkerIcon(
        text: markerLabel,
        backgroundColor: markerColor,
        textColor: markerTextColor,
        maxWidth: 220 * widget.markerScale,
        scale: widget.markerScale,
      );

      markers.add(
        Marker(
          markerId: MarkerId(entry.pulse.id),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(
            title: entry.venue.name,
            snippet: snippetPieces.isEmpty ? null : snippetPieces.join(' • '),
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _markersReady = true;
    });

    if (_mapController.isCompleted) {
      Future<void>.microtask(_showAllInfoWindows);
    }
  }

  Future<void> _showAllInfoWindows() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    for (final entry in widget.entries) {
      controller.showMarkerInfoWindow(MarkerId(entry.pulse.id));
    }
  }

  Future<void> _initializeUserLocation({bool showErrorMessages = false}) async {
    if (_isFetchingLocation) return;

    if (mounted) {
      setState(() {
        _isFetchingLocation = true;
      });
    } else {
      _isFetchingLocation = true;
    }

    try {
      final serviceEnabled = await _locationService.isServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
          });
        } else {
          _locationPermissionGranted = false;
        }
        if (showErrorMessages && mounted) {
          _showSnackBar('Konum servisi kapalı. Lütfen etkinleştirin.');
        }
        return;
      }

      var permission = await _locationService.currentPermission();
      if (permission == LocationPermission.denied) {
        permission = await _locationService.requestPermission();
      }

      final permissionGranted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      if (!permissionGranted) {
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
          });
        } else {
          _locationPermissionGranted = false;
        }
        if (showErrorMessages && mounted) {
          _showSnackBar(
            'Konum iznine ihtiyaç var. Lütfen ayarlardan izin verin.',
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _locationPermissionGranted = true;
        });
      } else {
        _locationPermissionGranted = true;
      }

      final position = await _locationService.getCurrentPosition();
      final userLocation = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        _userLocation = userLocation;
        _hasCenteredOnUser = true;
        return;
      }

      setState(() {
        _userLocation = userLocation;
      });

      await _moveCameraToUser();
    } catch (error) {
      if (showErrorMessages && mounted) {
        _showSnackBar('Konum alınamadı. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      } else {
        _isFetchingLocation = false;
      }
    }
  }

  Future<void> _centerOnUser({bool showErrorMessages = false}) async {
    if (_userLocation != null) {
      await _moveCameraToUser();
      return;
    }
    await _initializeUserLocation(showErrorMessages: showErrorMessages);
  }

  Future<void> _moveCameraToUser() async {
    final target = _userLocation;
    if (target == null) return;
    if (!_mapController.isCompleted) {
      _hasCenteredOnUser = true;
      return;
    }

    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 15)),
    );

    if (mounted) {
      setState(() {
        _hasCenteredOnUser = true;
      });
    } else {
      _hasCenteredOnUser = true;
    }
  }

  Future<void> _animateCamera(CameraUpdate update) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    await controller.animateCamera(update);
  }

  Future<void> _zoomIn() async {
    await _animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    await _animateCamera(CameraUpdate.zoomOut());
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool showProgress = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tooltip(
        message: tooltip,
        child: FloatingActionButton.small(
          heroTag: null,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          onPressed: showProgress ? null : onPressed,
          child: showProgress
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) async {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
              final bounds = _bounds;
              if (bounds != null) {
                await Future<void>.delayed(const Duration(milliseconds: 300));
                if (mounted && !_hasCenteredOnUser) {
                  await controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 60),
                  );
                }
              }
              if (_markersReady) {
                await Future<void>.delayed(const Duration(milliseconds: 120));
                if (mounted) {
                  _showAllInfoWindows();
                }
              }
              if (_userLocation != null) {
                await _moveCameraToUser();
              }
            },
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControlButton(
                    icon: Icons.add,
                    tooltip: 'Yakınlaştır',
                    onPressed: () => _zoomIn(),
                  ),
                  _buildControlButton(
                    icon: Icons.remove,
                    tooltip: 'Uzaklaştır',
                    onPressed: () => _zoomOut(),
                  ),
                  _buildControlButton(
                    icon: Icons.my_location,
                    tooltip: 'Konumuma git',
                    onPressed: _isFetchingLocation
                        ? null
                        : () => _centerOnUser(showErrorMessages: true),
                    showProgress: _isFetchingLocation,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<BitmapDescriptor> _createMarkerIcon({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required double maxWidth,
    required double scale,
  }) async {
    final effectiveScale = scale.clamp(0.6, 4.0);
    final double padding = 16 * effectiveScale;
    final double height = 44 * effectiveScale;
    final double fontScale = 1.0 + (effectiveScale - 1) * 0.6;

    final style = TextStyle(
      color: textColor,
      fontWeight: FontWeight.w600,
      fontSize: 14 * fontScale,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth - padding * 1.2);

    final double width = textPainter.width + padding * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      const Radius.circular(999),
    );

    final paint = Paint()..color = backgroundColor;
    canvas.drawRRect(rRect, paint);

    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (height - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  String _defaultClockTime(DateTime dateTime) {
    final hours = dateTime.hour.toString().padLeft(2, '0');
    final minutes = dateTime.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String _defaultMarkerLabel(PulseMapEntry entry, String? relativeTime) {
    final pieces = <String>[entry.venue.name];
    if (relativeTime != null && relativeTime.isNotEmpty) {
      pieces.add(relativeTime);
    }
    return pieces.join(' • ');
  }

  String _defaultCompactRelativeTime(DateTime dateTime) {
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
}
