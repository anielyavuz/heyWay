import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/friends_provider.dart';
import '../models/friendship.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<FriendsProvider>().initializeForUser(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends', icon: Icon(Icons.people)),
            Tab(text: 'Requests', icon: Icon(Icons.person_add)),
            Tab(text: 'Sent', icon: Icon(Icons.send)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showAddFriendDialog,
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Friend',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildRequestsTab(),
          _buildSentRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, child) {
        if (friendsProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (friendsProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  friendsProvider.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (friendsProvider.friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No friends yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add friends to see them here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showAddFriendDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Friend'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friendsProvider.friends.length,
          itemBuilder: (context, index) {
            final friendship = friendsProvider.friends[index];
            return FriendCard(
              friendship: friendship,
              onRemove: () => _showRemoveFriendDialog(friendship),
              onBlock: () => _showBlockUserDialog(friendship),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, child) {
        if (friendsProvider.pendingRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No friend requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Friend requests will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friendsProvider.pendingRequests.length,
          itemBuilder: (context, index) {
            final friendship = friendsProvider.pendingRequests[index];
            return FriendRequestCard(
              friendship: friendship,
              onAccept: () => _acceptFriendRequest(friendship),
              onDecline: () => _declineFriendRequest(friendship),
            );
          },
        );
      },
    );
  }

  Widget _buildSentRequestsTab() {
    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, child) {
        if (friendsProvider.sentRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No sent requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sent friend requests will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friendsProvider.sentRequests.length,
          itemBuilder: (context, index) {
            final friendship = friendsProvider.sentRequests[index];
            return SentRequestCard(
              friendship: friendship,
              onCancel: () => _cancelFriendRequest(friendship),
            );
          },
        );
      },
    );
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AddFriendDialog(
        onSendRequest: (userId) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            context.read<FriendsProvider>().sendFriendRequest(currentUser.uid, userId);
          }
        },
      ),
    );
  }

  void _acceptFriendRequest(Friendship friendship) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final otherUserId = friendship.getOtherUserId(currentUser.uid);
      context.read<FriendsProvider>().acceptFriendRequest(currentUser.uid, otherUserId);
    }
  }

  void _declineFriendRequest(Friendship friendship) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final otherUserId = friendship.getOtherUserId(currentUser.uid);
      context.read<FriendsProvider>().declineFriendRequest(currentUser.uid, otherUserId);
    }
  }

  void _cancelFriendRequest(Friendship friendship) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final otherUserId = friendship.getOtherUserId(currentUser.uid);
      context.read<FriendsProvider>().cancelFriendRequest(currentUser.uid, otherUserId);
    }
  }

  void _showRemoveFriendDialog(Friendship friendship) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final otherUserId = friendship.getOtherUserId(currentUser.uid);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<FriendsProvider>().removeFriend(currentUser.uid, otherUserId);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog(Friendship friendship) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final otherUserId = friendship.getOtherUserId(currentUser.uid);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text('Are you sure you want to block this user? They will not be able to send you friend requests.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<FriendsProvider>().blockUser(currentUser.uid, otherUserId);
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class FriendCard extends StatelessWidget {
  const FriendCard({
    super.key,
    required this.friendship,
    required this.onRemove,
    required this.onBlock,
  });

  final Friendship friendship;
  final VoidCallback onRemove;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final otherUserId = friendship.getOtherUserId(currentUser.uid);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            (otherUserId.length >= 2 ? otherUserId.substring(0, 2) : otherUserId).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text('User ${otherUserId.length > 8 ? otherUserId.substring(0, 8) : otherUserId}...'),
        subtitle: Text('Friends since ${_formatDate(friendship.respondedAt ?? friendship.requestedAt)}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'remove':
                onRemove();
                break;
              case 'block':
                onBlock();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Remove Friend'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Block User'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class FriendRequestCard extends StatelessWidget {
  const FriendRequestCard({
    super.key,
    required this.friendship,
    required this.onAccept,
    required this.onDecline,
  });

  final Friendship friendship;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final otherUserId = friendship.getOtherUserId(currentUser.uid);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            (otherUserId.length >= 2 ? otherUserId.substring(0, 2) : otherUserId).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text('User ${otherUserId.length > 8 ? otherUserId.substring(0, 8) : otherUserId}...'),
        subtitle: Text('Sent ${_formatTimeAgo(friendship.requestedAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onDecline,
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Decline',
            ),
            IconButton(
              onPressed: onAccept,
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Accept',
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class SentRequestCard extends StatelessWidget {
  const SentRequestCard({
    super.key,
    required this.friendship,
    required this.onCancel,
  });

  final Friendship friendship;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final otherUserId = friendship.getOtherUserId(currentUser.uid);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[400],
          child: Text(
            (otherUserId.length >= 2 ? otherUserId.substring(0, 2) : otherUserId).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text('User ${otherUserId.length > 8 ? otherUserId.substring(0, 8) : otherUserId}...'),
        subtitle: Text('Sent ${_formatTimeAgo(friendship.requestedAt)} • Pending'),
        trailing: IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.cancel_outlined, color: Colors.orange),
          tooltip: 'Cancel Request',
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class AddFriendDialog extends StatefulWidget {
  const AddFriendDialog({super.key, required this.onSendRequest});

  final Function(String userId) onSendRequest;

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Friend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter the user ID of the person you want to add as a friend:'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'Enter user ID...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendRequest,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Request'),
        ),
      ],
    );
  }

  void _sendRequest() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a user ID')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      widget.onSendRequest(_controller.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}