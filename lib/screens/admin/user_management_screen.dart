import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../utils/logger.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Filter options
  String _selectedRole = 'All';
  String _selectedMembership = 'All';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement actual API call to get all users
      AppLogger.info('Loading users...');

      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // Mock user data for demonstration
      _users = [
        User(
          id: 'user1',
          email: 'admin@dictationstudio.com',
          username: 'Admin User',
          role: 'Admin',
          avatar: 'https://via.placeholder.com/150',
          language: 'en',
          plan: Plan(name: 'Premium', status: 'active'),
          dictationConfig: DictationConfig(shortcuts: ShortcutKeys()),
          createdAt: DateTime.now()
              .subtract(const Duration(days: 30))
              .millisecondsSinceEpoch,
        ),
        User(
          id: 'user2',
          email: 'user1@example.com',
          username: 'Regular User',
          role: 'User',
          avatar: 'https://via.placeholder.com/150',
          language: 'en',
          plan: Plan(name: 'Free', status: 'active'),
          dictationConfig: DictationConfig(shortcuts: ShortcutKeys()),
          createdAt: DateTime.now()
              .subtract(const Duration(days: 15))
              .millisecondsSinceEpoch,
        ),
        User(
          id: 'user3',
          email: 'premium@example.com',
          username: 'Premium User',
          role: 'User',
          avatar: 'https://via.placeholder.com/150',
          language: 'en',
          plan: Plan(name: 'Premium', status: 'active'),
          dictationConfig: DictationConfig(shortcuts: ShortcutKeys()),
          createdAt: DateTime.now()
              .subtract(const Duration(days: 7))
              .millisecondsSinceEpoch,
        ),
      ];

      AppLogger.info('Loaded ${_users.length} users');
    } catch (e) {
      AppLogger.error('Failed to load users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<User> _getFilteredUsers() {
    return _users.where((user) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.username.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesRole = _selectedRole == 'All' || user.role == _selectedRole;
      final matchesMembership =
          _selectedMembership == 'All' || user.plan.name == _selectedMembership;

      return matchesSearch && matchesRole && matchesMembership;
    }).toList();
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => _UserDetailsDialog(
        user: user,
        onUserUpdated: () {
          _loadUsers();
        },
      ),
    );
  }

  void _showStatistics() {
    showDialog(
      context: context,
      builder: (context) => _UserStatisticsDialog(users: _users),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showStatistics,
            tooltip: 'View Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh Users',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by email or username...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Filter Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: ['All', 'Admin', 'User']
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMembership,
                        decoration: const InputDecoration(
                          labelText: 'Membership',
                          border: OutlineInputBorder(),
                        ),
                        items: ['All', 'Free', 'Premium', 'Pro']
                            .map(
                              (membership) => DropdownMenuItem(
                                value: membership,
                                child: Text(membership),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedMembership = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                        if (_searchQuery.isNotEmpty ||
                            _selectedRole != 'All' ||
                            _selectedMembership != 'All') ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return _buildUserCard(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(user.avatar),
          onBackgroundImageError: (_, __) {},
          child: user.avatar.isEmpty
              ? Text(
                  user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(
          user.username,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(user.role, style: const TextStyle(fontSize: 10)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: user.role == 'Admin'
                      ? Colors.red.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    user.plan.name,
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: _getMembershipColor(user.plan.name),
                ),
                const SizedBox(width: 8),
                Text(
                  'Joined: ${_formatDate(DateTime.fromMillisecondsSinceEpoch(user.createdAt))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showUserDetails(user),
          tooltip: 'View Details',
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getMembershipColor(String membership) {
    switch (membership) {
      case 'Premium':
        return Colors.orange.withOpacity(0.2);
      case 'Pro':
        return Colors.purple.withOpacity(0.2);
      case 'Free':
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _UserDetailsDialog extends StatefulWidget {
  final User user;
  final VoidCallback onUserUpdated;

  const _UserDetailsDialog({required this.user, required this.onUserUpdated});

  @override
  State<_UserDetailsDialog> createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<_UserDetailsDialog> {
  late String _role;
  late String _membership;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _membership = widget.user.plan.name;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('User Details - ${widget.user.username}'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Avatar and Basic Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(widget.user.avatar),
                    onBackgroundImageError: (_, __) {},
                    child: widget.user.avatar.isEmpty
                        ? Text(
                            widget.user.username.isNotEmpty
                                ? widget.user.username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.username,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.user.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Member since: ${_formatDate(DateTime.fromMillisecondsSinceEpoch(widget.user.createdAt))}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Role Management
              const Text(
                'Role Management',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'User Role',
                  border: OutlineInputBorder(),
                ),
                items: ['User', 'Admin']
                    .map(
                      (role) =>
                          DropdownMenuItem(value: role, child: Text(role)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _role = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Membership Management
              const Text(
                'Membership Management',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _membership,
                decoration: const InputDecoration(
                  labelText: 'Membership Type',
                  border: OutlineInputBorder(),
                ),
                items: ['Free', 'Premium', 'Pro']
                    .map(
                      (membership) => DropdownMenuItem(
                        value: membership,
                        child: Text(membership),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _membership = value!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // User Statistics (Mock data)
              const Text(
                'User Activity',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStatRow('Total Sessions', '42'),
                      _buildStatRow('Total Watch Time', '12h 34m'),
                      _buildStatRow('Favorite Language', 'English'),
                      _buildStatRow('Last Active', '2 days ago'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _saveChanges() {
    // TODO: Implement actual API call to update user
    AppLogger.info('Updating user: ${widget.user.id}');
    AppLogger.info('New role: $_role');
    AppLogger.info('New membership: $_membership');

    Navigator.of(context).pop();
    widget.onUserUpdated();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _UserStatisticsDialog extends StatelessWidget {
  final List<User> users;

  const _UserStatisticsDialog({required this.users});

  @override
  Widget build(BuildContext context) {
    final totalUsers = users.length;
    final adminCount = users.where((user) => user.role == 'Admin').length;
    final regularUserCount = users.where((user) => user.role == 'User').length;

    final freeUsers = users.where((user) => user.plan.name == 'Free').length;
    final premiumUsers = users
        .where((user) => user.plan.name == 'Premium')
        .length;
    final proUsers = users.where((user) => user.plan.name == 'Pro').length;

    return AlertDialog(
      title: const Text('User Statistics'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total Users
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Total Users',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      totalUsers.toString(),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Role Distribution
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role Distribution',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow('Administrators', adminCount),
                    _buildStatRow('Regular Users', regularUserCount),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Membership Distribution
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Membership Distribution',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow('Free Users', freeUsers),
                    _buildStatRow('Premium Users', premiumUsers),
                    _buildStatRow('Pro Users', proUsers),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
