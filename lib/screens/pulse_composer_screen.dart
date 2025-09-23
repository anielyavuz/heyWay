import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../models/venue.dart';
import '../models/pulse.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../providers/location_provider.dart';
import '../providers/venue_search_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/pulse_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/distance_utils.dart';
import '../utils/debug_logger.dart';

class PulseComposerScreen extends StatefulWidget {
  const PulseComposerScreen({super.key, this.venue});

  final Venue? venue;

  @override
  State<PulseComposerScreen> createState() => _PulseComposerScreenState();
}

class _PulseComposerScreenState extends State<PulseComposerScreen> {
  final _captionController = TextEditingController();
  final _focusNode = FocusNode();

  Venue? _selectedVenue;
  String _selectedMood = '😊';
  String _selectedVisibility = 'public';
  List<File> _selectedImages = [];
  bool _isSubmitting = false;
  List<AppUser> _selectedCollaborators = [];

  final List<String> _moods = [
    '😊', // happy
    '😍', // love
    '🤩', // excited
    '😎', // cool
    '🤔', // thinking
    '😋', // tasty
    '🥳', // party
    '😌', // relaxed
    '🤗', // grateful
    '🙌', // celebration
  ];

  final Map<String, String> _moodLabels = {
    '😊': 'Happy',
    '😍': 'Love it',
    '🤩': 'Excited',
    '😎': 'Cool',
    '🤔': 'Thinking',
    '😋': 'Tasty',
    '🥳': 'Party time',
    '😌': 'Relaxed',
    '🤗': 'Grateful',
    '🙌': 'Celebrating',
  };

  final List<Map<String, dynamic>> _visibilityOptions = [
    {
      'value': 'public',
      'label': 'Public',
      'icon': Icons.public,
      'description': 'Everyone can see this Pulse',
    },
    {
      'value': 'friends',
      'label': 'Friends',
      'icon': Icons.people,
      'description': 'Only your friends can see this Pulse',
    },
    {
      'value': 'private',
      'label': 'Private',
      'icon': Icons.lock,
      'description': 'Only you can see this Pulse',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedVenue = widget.venue;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1200,
                  maxHeight: 1200,
                  imageQuality: 85,
                );
                if (image != null) {
                  setState(() {
                    _selectedImages.add(File(image.path));
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile> images = await picker.pickMultiImage(
                  maxWidth: 1200,
                  maxHeight: 1200,
                  imageQuality: 85,
                );
                if (images.isNotEmpty) {
                  setState(() {
                    _selectedImages.addAll(images.map((img) => File(img.path)));
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _selectVenue() async {
    final result = await showModalBottomSheet<Venue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) =>
            VenueSelectionModal(scrollController: scrollController),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedVenue = result;
      });
    }
  }

  Future<void> _submitPulse() async {
    if (_selectedVenue == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a venue')));
      return;
    }

    // Caption is now optional - no validation required

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = context.read<app_auth.AuthProvider>();
      final user = authProvider.user;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload images to Storage
      List<String> mediaRefs = [];
      if (_selectedImages.isNotEmpty) {
        final storageService = StorageService();

        for (int i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];
          final pulseId = DateTime.now().millisecondsSinceEpoch.toString();
          final fileName = 'pulse_${pulseId}_$i.jpg';

          final mediaRef = await storageService.uploadPulseMedia(
            file: file,
            pulseId: pulseId,
            fileName: fileName,
          );

          if (mediaRef != null) {
            mediaRefs.add(mediaRef);
          }
        }
      }

      // Create Pulse document
      final pulse = Pulse(
        id: '', // Firestore will generate this
        userId: user.uid,
        venueId: _selectedVenue!.id,
        caption: _captionController.text.trim(),
        mood: _selectedMood,
        visibility: _selectedVisibility,
        mediaRefs: mediaRefs,
        badgeUnlocks: [], // Will be calculated by Cloud Functions
        likesCount: 0,
        commentCount: 0,
        createdAt: DateTime.now(),
        collaborators: _selectedCollaborators.map((user) => user.id).toList(),
      );

      // Save to Firestore
      final firestoreService = FirestoreService();
      await firestoreService.addPulse(pulse);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Pulse shared successfully!')),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing Pulse: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share a Pulse'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitPulse,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Share'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Venue Selection
            _buildVenueSection(),
            const SizedBox(height: 24),

            // Mood Selection
            _buildMoodSection(),
            const SizedBox(height: 24),

            // Caption Input
            _buildCaptionSection(),
            const SizedBox(height: 24),

            // Photo Selection
            _buildPhotoSection(),
            const SizedBox(height: 24),

            // Collaborators Selection
            _buildCollaboratorsSection(),
            const SizedBox(height: 24),

            // Privacy Selection
            _buildPrivacySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_selectedVenue == null)
              InkWell(
                onTap: _selectVenue,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_location, color: Colors.grey),
                      SizedBox(width: 12),
                      Text(
                        'Select a venue',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedVenue!.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _selectedVenue!.addressSummary,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _selectVenue,
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How are you feeling?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moods.map((mood) {
                final isSelected = _selectedMood == mood;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = mood;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mood, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          _moodLabels[mood]!,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What\'s happening?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              focusNode: _focusNode,
              maxLines: 4,
              maxLength: 280,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selectedImages.length < 5 ? _pickImages : null,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Who can see this?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._visibilityOptions.map((option) {
              final isSelected = _selectedVisibility == option['value'];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedVisibility = option['value'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          option['icon'],
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option['label'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                              Text(
                                option['description'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCollaboratorsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Friends Pulse',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_selectedCollaborators.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedCollaborators.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Share this pulse with your friends',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            
            // Selected collaborators chips
            if (_selectedCollaborators.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedCollaborators.map((user) => Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      user.displayName.isNotEmpty 
                          ? user.displayName[0].toUpperCase()
                          : user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    user.displayName.isNotEmpty ? user.displayName : user.username,
                  ),
                  onDeleted: () {
                    setState(() {
                      _selectedCollaborators.remove(user);
                    });
                  },
                )).toList(),
              ),
            
            const SizedBox(height: 12),
            
            // Add collaborators button
            OutlinedButton.icon(
              onPressed: _showFriendsSelector,
              icon: const Icon(Icons.person_add),
              label: Text(_selectedCollaborators.isEmpty 
                  ? 'Add Friends' 
                  : 'Add More Friends'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFriendsSelector() async {
    final result = await showModalBottomSheet<List<AppUser>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FriendsSelectorModal(
        selectedCollaborators: _selectedCollaborators,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedCollaborators = result;
      });
    }
  }
}

class VenueSelectionModal extends StatefulWidget {
  const VenueSelectionModal({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<VenueSelectionModal> createState() => _VenueSelectionModalState();
}

class _VenueSelectionModalState extends State<VenueSelectionModal> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load nearby venues when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VenueSearchProvider>();
      provider.getCurrentLocationAndUpdate().then((_) {
        provider.loadNearbyPopularVenues();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select Venue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Search Icon Button
                    IconButton(
                      onPressed: () {
                        final provider = context.read<VenueSearchProvider>();
                        showSearch(
                          context: context,
                          delegate: VenueSearchDelegate(
                            onManualVenueRequested:
                                (searchContext, manualQuery) async {
                                  try {
                                    return await provider.createManualVenue(
                                      manualQuery,
                                    );
                                  } catch (error) {
                                    if (searchContext.mounted) {
                                      ScaffoldMessenger.of(
                                        searchContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Mekan eklenemedi: $error',
                                          ),
                                        ),
                                      );
                                    }
                                    return null;
                                  }
                                },
                          ),
                        ).then((venue) {
                          if (venue != null && context.mounted) {
                            Navigator.pop(context, venue);
                          }
                        });
                      },
                      icon: const Icon(Icons.search),
                      tooltip: 'Search venues',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nearby venues',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Venue List
          Expanded(
            child: Consumer<VenueSearchProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text('Loading nearby venues...'),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () async {
                            await provider.getCurrentLocationAndUpdate();
                            provider.loadNearbyPopularVenues();
                          },
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: provider.results.length + 1, // +1 for load more
                  itemBuilder: (context, index) {
                    if (index == provider.results.length) {
                      // Load more button
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextButton(
                          onPressed: () async {
                            // Load more venues with higher limit
                            final provider = context
                                .read<VenueSearchProvider>();
                            await provider.loadMoreNearbyVenues();
                          },
                          child: const Text('Load more venues'),
                        ),
                      );
                    }

                    final venue = provider.results[index];

                    // Extract district and city from address (skip postal codes)
                    final addressParts = venue.addressSummary
                        .split(',')
                        .map((part) => part.trim())
                        .where(
                          (part) =>
                              part.isNotEmpty &&
                              !RegExp(r'^\d{5}').hasMatch(part),
                        )
                        .toList();
                    final shortAddress = addressParts.length >= 2
                        ? '${addressParts[addressParts.length - 2]}, ${addressParts.last}'
                        : addressParts.isNotEmpty
                        ? addressParts.last
                        : venue.addressSummary;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        radius: 20,
                        child: Text(
                          venue.category.isNotEmpty
                              ? venue.category[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      title: Text(
                        venue.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        shortAddress,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).pop(venue);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

class VenueSearchDelegate extends SearchDelegate<Venue?> {
  VenueSearchDelegate({this.onManualVenueRequested});

  final Future<Venue?> Function(BuildContext context, String query)?
  onManualVenueRequested;

  @override
  void showResults(BuildContext context) {
    context.read<VenueSearchProvider>().updateQuery(query, immediate: true);
    FocusScope.of(context).unfocus();
    super.showResults(context);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return Consumer<VenueSearchProvider>(
      builder: (context, provider, child) {
        final trimmedQuery = query.trim();
        final locationProvider = context.watch<LocationProvider>();
        final position = locationProvider.status == LocationStatus.granted
            ? locationProvider.position
            : null;

        // Trigger search when query changes with debounce
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (trimmedQuery.isEmpty) {
            if (provider.query.isNotEmpty) {
              provider.updateQuery('');
            }
          } else if (provider.query != trimmedQuery) {
            provider.updateQuery(trimmedQuery);
          }
        });

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (trimmedQuery.isEmpty) {
          return const Center(
            child: Text('Start typing to search for venues...'),
          );
        }

        final venues = provider.results;
        final showManualOption =
            onManualVenueRequested != null && trimmedQuery.isNotEmpty;

        final tiles = <Widget>[];

        if (venues.isEmpty) {
          tiles.add(
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('No venues found nearby'),
              subtitle: const Text('Add it manually so others can see it.'),
            ),
          );
        } else {
          for (final venue in venues) {
            final addressParts = venue.addressSummary
                .split(',')
                .map((part) => part.trim())
                .where(
                  (part) =>
                      part.isNotEmpty && !RegExp(r'^\d{5}').hasMatch(part),
                )
                .toList();
            final shortAddress = addressParts.length >= 2
                ? '${addressParts[addressParts.length - 2]}, ${addressParts.last}'
                : addressParts.isNotEmpty
                ? addressParts.last
                : venue.addressSummary;
            final distanceLabel = formatVenueDistance(position, venue);

            tiles.add(
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    venue.category.isNotEmpty
                        ? venue.category[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(venue.name),
                subtitle: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortAddress),
                    if (distanceLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        distanceLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  close(context, venue);
                },
              ),
            );
          }
        }

        if (showManualOption) {
          if (tiles.isNotEmpty) {
            tiles.add(const Divider(height: 0));
          }
          tiles.add(_buildManualCreationTile(context, trimmedQuery));
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: tiles,
        );
      },
    );
  }

  Widget _buildManualCreationTile(BuildContext context, String name) {
    return ListTile(
      leading: const Icon(Icons.add_location_alt_outlined),
      title: Text('"$name" mekanını ekle'),
      subtitle: const Text('Bu mekanı manuel olarak kaydet'),
      onTap: () async {
        final venue = await _handleManualVenueCreation(context, name);
        if (venue != null && context.mounted) {
          close(context, venue);
        }
      },
    );
  }

  Future<Venue?> _handleManualVenueCreation(
    BuildContext context,
    String name,
  ) async {
    if (onManualVenueRequested == null) {
      return null;
    }

    var dialogShown = false;
    if (context.mounted) {
      dialogShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final venue = await onManualVenueRequested!(context, name);
      return venue;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Mekan eklenemedi: $error')));
      }
      return null;
    } finally {
      if (dialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

}

class _FriendsSelectorModal extends StatefulWidget {
  const _FriendsSelectorModal({
    required this.selectedCollaborators,
  });

  final List<AppUser> selectedCollaborators;

  @override
  State<_FriendsSelectorModal> createState() => _FriendsSelectorModalState();
}

class _FriendsSelectorModalState extends State<_FriendsSelectorModal> {
  late List<AppUser> _tempSelectedCollaborators;
  String _searchQuery = '';
  Map<String, AppUser> _friendUsers = {};
  bool _loadingFriends = true;

  @override
  void initState() {
    super.initState();
    _tempSelectedCollaborators = List.from(widget.selectedCollaborators);
    // Defer loading friends to after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriendUsers();
    });
  }

  Future<void> _loadFriendUsers() async {
    final currentUserId = context.read<app_auth.AuthProvider>().user?.uid;
    if (currentUserId == null) {
      DebugLogger.error('No current user ID found', 'FriendsSelectorModal');
      if (mounted) {
        setState(() => _loadingFriends = false);
      }
      return;
    }

    final friendsProvider = context.read<FriendsProvider>();
    
    // Initialize friends provider if not already initialized
    friendsProvider.initializeForUser(currentUserId);
    
    // Wait for friends to load with multiple attempts
    int attempts = 0;
    while (attempts < 10 && friendsProvider.friends.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }
    
    DebugLogger.info('Friends count after $attempts attempts: ${friendsProvider.friends.length}', 'FriendsSelectorModal');
    
    final firestoreService = FirestoreService();
    final Map<String, AppUser> friendUsers = {};
    
    for (final friendship in friendsProvider.friends) {
      final friendId = friendship.getOtherUserId(currentUserId);
      DebugLogger.info('Loading friend user: $friendId', 'FriendsSelectorModal');
      try {
        final user = await firestoreService.getUser(friendId);
        if (user != null) {
          friendUsers[friendId] = user;
          DebugLogger.info('Loaded friend: ${user.displayName}', 'FriendsSelectorModal');
        }
      } catch (e) {
        DebugLogger.error('Failed to load friend user $friendId: $e', 'FriendsSelectorModal');
      }
    }
    
    DebugLogger.info('Total friend users loaded: ${friendUsers.length}', 'FriendsSelectorModal');
    
    if (mounted) {
      setState(() {
        _friendUsers = friendUsers;
        _loadingFriends = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Text(
                      'Select Friends',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context, _tempSelectedCollaborators),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search friends...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              
              // Friends list
              Expanded(
                child: _loadingFriends
                    ? const Center(child: CircularProgressIndicator())
                    : Consumer<FriendsProvider>(
                        builder: (context, friendsProvider, child) {
                          final friends = friendsProvider.friends;
                          
                          final filteredFriends = friends.where((friendship) {
                            final currentUserId = context.read<app_auth.AuthProvider>().user?.uid;
                            if (currentUserId == null) return false;
                            
                            final friendId = friendship.getOtherUserId(currentUserId);
                            final friendUser = _friendUsers[friendId];
                            
                            if (friendUser == null) return false;
                            
                            if (_searchQuery.isEmpty) return true;
                            
                            return friendUser.displayName.toLowerCase().contains(_searchQuery) ||
                                   friendUser.username.toLowerCase().contains(_searchQuery);
                          }).toList();

                          if (filteredFriends.isEmpty) {
                            return const Center(
                              child: Text('No friends found'),
                            );
                          }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredFriends.length,
                      itemBuilder: (context, index) {
                        final friendship = filteredFriends[index];
                        final currentUserId = context.read<app_auth.AuthProvider>().user?.uid;
                        final friendId = friendship.getOtherUserId(currentUserId!);
                        final friendUser = _friendUsers[friendId];
                        
                        if (friendUser == null) {
                          return const SizedBox.shrink();
                        }
                        
                        final isSelected = _tempSelectedCollaborators.any((u) => u.id == friendUser.id);
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            child: Text(
                              friendUser.displayName.isNotEmpty 
                                  ? friendUser.displayName[0].toUpperCase()
                                  : friendUser.username.isNotEmpty
                                      ? friendUser.username[0].toUpperCase()
                                      : '?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            friendUser.displayName.isNotEmpty ? friendUser.displayName : friendUser.username,
                          ),
                          subtitle: friendUser.displayName.isNotEmpty 
                              ? Text('@${friendUser.username}')
                              : null,
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  if (!_tempSelectedCollaborators.any((u) => u.id == friendUser.id)) {
                                    _tempSelectedCollaborators.add(friendUser);
                                  }
                                } else {
                                  _tempSelectedCollaborators.removeWhere((u) => u.id == friendUser.id);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _tempSelectedCollaborators.removeWhere((u) => u.id == friendUser.id);
                              } else {
                                if (!_tempSelectedCollaborators.any((u) => u.id == friendUser.id)) {
                                  _tempSelectedCollaborators.add(friendUser);
                                }
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
