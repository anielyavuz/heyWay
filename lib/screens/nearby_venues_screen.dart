import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/venue.dart';
import '../providers/venue_search_provider.dart';
import '../utils/debug_logger.dart';
import 'pulse_composer_screen.dart';

class NearbyVenuesScreen extends StatefulWidget {
  const NearbyVenuesScreen({super.key});

  @override
  State<NearbyVenuesScreen> createState() => _NearbyVenuesScreenState();
}

class _NearbyVenuesScreenState extends State<NearbyVenuesScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNearbyVenues();
  }

  Future<void> _loadNearbyVenues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      DebugLogger.info(
        'Loading nearby venues for pulse creation',
        'NearbyVenuesScreen',
      );

      final venueSearchProvider = context.read<VenueSearchProvider>();

      // Update location and load nearby popular venues
      await venueSearchProvider.getCurrentLocationAndUpdate();
      await venueSearchProvider.loadNearbyPopularVenues(
        limit: 15,
        keywordFilters: const [
          'cafe',
          'coffee',
          'kafe',
          'restaurant',
          'restoran',
          'bar',
          'nightlife',
          'entertainment',
          'social',
          'sosyal',
          'market',
          'shopping',
        ],
      );

      setState(() {
        _isLoading = false;
      });

      DebugLogger.info(
        'Loaded ${venueSearchProvider.results.length} nearby venues',
        'NearbyVenuesScreen',
      );
    } catch (e) {
      DebugLogger.error(
        'Failed to load nearby venues: $e',
        'NearbyVenuesScreen',
      );
      setState(() {
        _error = 'Failed to load nearby venues: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSearch() async {
    final venueSearchProvider = context.read<VenueSearchProvider>();

    final selectedVenue = await showSearch<Venue?>(
      context: context,
      delegate: VenueSearchDelegate(
        onManualVenueRequested: (searchContext, query) async {
          try {
            return await venueSearchProvider.createManualVenue(query);
          } catch (error) {
            if (searchContext.mounted) {
              ScaffoldMessenger.of(searchContext).showSnackBar(
                SnackBar(content: Text('Mekan eklenemedi: $error')),
              );
            }
            return null;
          }
        },
      ),
    );

    if (!mounted || selectedVenue == null) {
      return;
    }

    await _openComposer(selectedVenue);
  }

  Future<void> _openComposer(Venue venue) async {
    if (!mounted) return;

    DebugLogger.info(
      'Creating pulse for venue: ${venue.name}',
      'NearbyVenuesScreen',
    );

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PulseComposerScreen(venue: venue),
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _getVenueEmoji(String category) {
    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('cafe') || lowerCategory.contains('coffee')) {
      return '☕️';
    } else if (lowerCategory.contains('restaurant') ||
        lowerCategory.contains('food')) {
      return '🍽️';
    } else if (lowerCategory.contains('bar') ||
        lowerCategory.contains('nightlife')) {
      return '🍻';
    } else if (lowerCategory.contains('hotel') ||
        lowerCategory.contains('lodging')) {
      return '🏨';
    } else if (lowerCategory.contains('shop') ||
        lowerCategory.contains('store')) {
      return '🛍️';
    } else if (lowerCategory.contains('park') ||
        lowerCategory.contains('recreation')) {
      return '🌳';
    } else if (lowerCategory.contains('gym') ||
        lowerCategory.contains('fitness')) {
      return '💪';
    } else if (lowerCategory.contains('entertainment') ||
        lowerCategory.contains('arts')) {
      return '🎭';
    } else if (lowerCategory.contains('health') ||
        lowerCategory.contains('medical')) {
      return '🏥';
    } else if (lowerCategory.contains('gas') ||
        lowerCategory.contains('automotive')) {
      return '⛽️';
    } else {
      return '📍';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Venues'),
        actions: [
          IconButton(
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: _loadNearbyVenues,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<VenueSearchProvider>(
        builder: (context, searchProvider, child) {
          if (_isLoading || searchProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadNearbyVenues,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final venues = searchProvider.results;

          if (venues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No venues found nearby',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try refreshing or check your location permissions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: venues.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final venue = venues[index];

              return NearbyVenueCard(
                venue: venue,
                emoji: _getVenueEmoji(venue.category),
                onPulseTap: () => _openComposer(venue),
              );
            },
          );
        },
      ),
    );
  }
}

class NearbyVenueCard extends StatelessWidget {
  const NearbyVenueCard({
    super.key,
    required this.venue,
    required this.emoji,
    required this.onPulseTap,
  });

  final Venue venue;
  final String emoji;
  final VoidCallback onPulseTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red[50],
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          venue.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              venue.category,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.red[400]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    venue.addressSummary,
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.red[600],
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            onPressed: onPulseTap,
            icon: const Icon(Icons.favorite, color: Colors.white, size: 20),
            tooltip: 'Create Pulse',
          ),
        ),
        onTap: onPulseTap,
      ),
    );
  }
}
