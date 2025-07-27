import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/progress_data.dart' as progress_data;
import '../../models/verification_code.dart';
import '../../utils/logger.dart';
import '../../services/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Filter options
  String _selectedRole = 'All';
  String _selectedMembership = 'All';
  
  // Sorting options
  String _sortBy = 'lastActive'; // lastActive, createdAt, updatedAt, username
  bool _sortAscending = false; // Default to descending for lastActive


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
      AppLogger.info('Loading users from API...');
      
      final response = await apiService.getAllUsers();
      
      // Handle different response formats
      List<dynamic> usersData;
      try {
        // Check if response is a Map containing user data
        final responseMap = response as Map<String, dynamic>?;
        if (responseMap != null) {
          // If response has a 'data' field or 'users' field
          if (responseMap.containsKey('data')) {
            final data = responseMap['data'];
            usersData = data is List ? data : [data];
          } else if (responseMap.containsKey('users')) {
            final users = responseMap['users'];
            usersData = users is List ? users : [users];
          } else {
            // If response is direct user data
            usersData = [responseMap];
          }
        } else {
          // Assume it's already a list
          usersData = response as List<dynamic>;
        }
      } catch (e) {
        AppLogger.error('Failed to parse API response: $e');
        throw Exception('Invalid API response format');
      }
      
      _users = usersData.map((userData) {
        try {
          // Backend already parsed the data, just cast it directly
          final userMap = userData as Map<String, dynamic>;
          return User.fromJson(userMap);
        } catch (e) {
          AppLogger.warning('Failed to parse user data: $userData, error: $e');
          return null;
        }
      }).where((user) => user != null).cast<User>().toList();

      // Sort users by default (last active, descending)
      _sortUsers();
      _applyFilters();

      AppLogger.info('Loaded ${_users.length} users from API');
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

  void _sortUsers() {
    _users.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'lastActive':
          final aTimestamp = a.getLastMeaningfulDictationInputTimestamp();
          final bTimestamp = b.getLastMeaningfulDictationInputTimestamp();
          comparison = aTimestamp.compareTo(bTimestamp);
          break;
        case 'createdAt':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'updatedAt':
          final aUpdated = a.updatedAt ?? 0;
          final bUpdated = b.updatedAt ?? 0;
          comparison = aUpdated.compareTo(bUpdated);
          break;
        case 'username':
          comparison = a.username.toLowerCase().compareTo(b.username.toLowerCase());
          break;
        default:
          return 0;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
  }

  void _applyFilters() {
    _filteredUsers = _users.where((user) {
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

  List<User> _getFilteredUsers() {
    return _filteredUsers;
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

  void _showUserProgress(String userEmail) async {    
    showDialog(
      context: context,
      builder: (context) => _StatefulUserProgressDialog(
        userEmail: userEmail,
      ),
    );
  }

  void _showVerificationCodeModal() async {
    List<VerificationCode> codes = [];
    bool isLoading = true;
    
    showDialog(
      context: context,
      builder: (context) => _VerificationCodeDialog(
        codes: codes,
        isLoading: isLoading,
        users: _users.map((u) => u.email).toList(),
        onClose: () => Navigator.of(context).pop(),
        onRefresh: () {
          Navigator.of(context).pop();
          _showVerificationCodeModal();
        },
      ),
    );

    try {
      final result = await apiService.getAllVerificationCodes();
      codes = result;
      isLoading = false;
      
      // Update dialog if still mounted
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        showDialog(
          context: context,
          builder: (context) => _VerificationCodeDialog(
            codes: codes,
            isLoading: false,
            users: _users.map((u) => u.email).toList(),
            onClose: () => Navigator.of(context).pop(),
            onRefresh: () {
              Navigator.of(context).pop();
              _showVerificationCodeModal();
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load verification codes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            icon: const Icon(Icons.card_membership),
            onPressed: _showVerificationCodeModal,
            tooltip: 'Manage Verification Codes',
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
              color: Theme.of(context).colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
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
                      _applyFilters();
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
                            _applyFilters();
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
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Sort Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: const InputDecoration(
                          labelText: 'Sort by',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'lastActive', child: Text('Last Active')),
                          DropdownMenuItem(value: 'createdAt', child: Text('Created At')),
                          DropdownMenuItem(value: 'updatedAt', child: Text('Updated At')),
                          DropdownMenuItem(value: 'username', child: Text('Username')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value!;
                            _sortUsers();
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        value: _sortAscending,
                        decoration: const InputDecoration(
                          labelText: 'Order',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('Ascending')),
                          DropdownMenuItem(value: false, child: Text('Descending')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _sortAscending = value!;
                            _sortUsers();
                            _applyFilters();
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
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        if (_searchQuery.isNotEmpty ||
                            _selectedRole != 'All' ||
                            _selectedMembership != 'All') ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Theme.of(context).colorScheme.outline),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                CircleAvatar(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'details':
                        _showUserDetails(user);
                        break;
                      case 'progress':
                        _showUserProgress(user.email);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit Details'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'progress',
                      enabled: user.hasDictationInput(),
                      child: const ListTile(
                        leading: Icon(Icons.analytics),
                        title: Text('View Progress'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Chips Row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(user.role, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: user.role == 'Admin'
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                ),
                Chip(
                  label: Text(
                    user.plan.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: _getMembershipColor(user.plan.name, context),
                ),
                if (user.hasDictationInput())
                  Chip(
                    label: const Text('Active', style: TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Details Row
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Last Active', user.getLastActiveDate(), Icons.schedule),
                const SizedBox(height: 4),
                _buildDetailRow('Created', _formatDate(DateTime.fromMillisecondsSinceEpoch(user.createdAt)), Icons.person_add),
                const SizedBox(height: 4),
                _buildDetailRow('Updated', 
                  user.updatedAt != null ? _formatDate(DateTime.fromMillisecondsSinceEpoch(user.updatedAt!)) : 'Never', 
                  Icons.update),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Color _getMembershipColor(String membership, BuildContext context) {
    final theme = Theme.of(context);
    switch (membership) {
      case 'Premium':
        return theme.colorScheme.tertiaryContainer;
      case 'Pro':
        return theme.colorScheme.primaryContainer;
      case 'Free':
      default:
        return theme.colorScheme.surfaceContainerHighest;
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

  void _saveChanges() async {
    try {
      AppLogger.info('Updating user: ${widget.user.email}');
      AppLogger.info('New role: $_role');
      AppLogger.info('New membership: $_membership');
      
      // Update role if changed
      if (_role != widget.user.role) {
        await apiService.updateUserRole([widget.user.email], _role);
        AppLogger.info('User role updated successfully');
      }
      
      // Update membership if changed
      if (_membership != widget.user.plan.name) {
        await apiService.updateUserPlan([widget.user.email], _membership);
        AppLogger.info('User plan updated successfully');
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUserUpdated();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to update user: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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


// Verification Code Dialog
class _VerificationCodeDialog extends StatefulWidget {
  final List<VerificationCode> codes;
  final bool isLoading;
  final List<String> users;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  const _VerificationCodeDialog({
    required this.codes,
    required this.isLoading,
    required this.users,
    required this.onClose,
    required this.onRefresh,
  });

  @override
  State<_VerificationCodeDialog> createState() => _VerificationCodeDialogState();
}

class _VerificationCodeDialogState extends State<_VerificationCodeDialog> {
  String _selectedDuration = '30days';
  int _customDaysValue = 30;
  String _generatedCode = '';
  String _selectedUserEmail = '';
  String _selectedCode = '';
  bool _isGenerating = false;
  bool _isAssigning = false;
  
  final _customDaysController = TextEditingController();
  final _userSearchController = TextEditingController();

  @override
  void dispose() {
    _customDaysController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      Map<String, dynamic> response;
      if (_selectedDuration == 'custom') {
        if (_customDaysValue <= 0) {
          throw Exception('Please enter a valid number of days');
        }
        response = await apiService.generateCustomVerificationCode(_customDaysValue);
      } else {
        response = await apiService.generateVerificationCode(_selectedDuration);
      }
      
      setState(() {
        _generatedCode = response['fullCode'] ?? response['full_code'] ?? '';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      widget.onRefresh(); // Refresh the codes list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate code: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _assignCode() async {
    if (_selectedCode.isEmpty || _selectedUserEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both a code and a user'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAssigning = true;
    });

    try {
      await apiService.assignVerificationCode(_selectedCode, _selectedUserEmail);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code successfully assigned to $_selectedUserEmail'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      widget.onRefresh(); // Refresh the codes list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign code: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isAssigning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Verification Code Management',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              const Divider(),
              
              // Generate Code Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate New Code',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedDuration,
                              decoration: const InputDecoration(
                                labelText: 'Duration',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: '30days', child: Text('30 Days')),
                                DropdownMenuItem(value: '60days', child: Text('60 Days')),
                                DropdownMenuItem(value: '90days', child: Text('90 Days')),
                                DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                                DropdownMenuItem(value: 'custom', child: Text('Custom')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedDuration = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_selectedDuration == 'custom')
                            Expanded(
                              child: TextFormField(
                                controller: _customDaysController,
                                decoration: const InputDecoration(
                                  labelText: 'Custom Days',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _customDaysValue = int.tryParse(value) ?? 30;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _isGenerating ? null : _generateCode,
                            child: _isGenerating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Generate Code'),
                          ),
                          const SizedBox(width: 16),
                          if (_generatedCode.isNotEmpty)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _generatedCode,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () {
                                        // Copy to clipboard logic would go here
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Code copied to clipboard')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Assign Code Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign Code to User',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Use column layout on narrow screens
                          if (constraints.maxWidth < 600) {
                            return Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: DropdownButtonFormField<String>(
                                  value: _selectedCode.isEmpty ? null : _selectedCode,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Code',
                                    border: OutlineInputBorder(),
                                  ),
                                  isExpanded: true,
                                  items: widget.codes
                                      .where((code) => !code.isExpired)
                                      .map((code) => DropdownMenuItem(
                                            value: code.fullCode,
                                            child: Text(
                                              '${code.codePart} (${code.duration})',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCode = value ?? '';
                                    });
                                  },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: DropdownButtonFormField<String>(
                                  value: _selectedUserEmail.isEmpty ? null : _selectedUserEmail,
                                  decoration: const InputDecoration(
                                    labelText: 'Select User',
                                    border: OutlineInputBorder(),
                                  ),
                                  isExpanded: true,
                                  items: widget.users
                                      .map((email) => DropdownMenuItem(
                                            value: email,
                                            child: Text(
                                              email,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedUserEmail = value ?? '';
                                    });
                                  },
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // Use row layout on wider screens
                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCode.isEmpty ? null : _selectedCode,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Code',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: widget.codes
                                        .where((code) => !code.isExpired)
                                        .map((code) => DropdownMenuItem(
                                              value: code.fullCode,
                                              child: Text(
                                                '${code.codePart} (${code.duration})',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCode = value ?? '';
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedUserEmail.isEmpty ? null : _selectedUserEmail,
                                    decoration: const InputDecoration(
                                      labelText: 'Select User',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: widget.users
                                        .map((email) => DropdownMenuItem(
                                              value: email,
                                              child: Text(
                                                email,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedUserEmail = value ?? '';
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      ElevatedButton(
                        onPressed: _isAssigning ? null : _assignCode,
                        child: _isAssigning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Assign Code'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Existing Codes List
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Existing Codes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: widget.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : widget.codes.isEmpty
                              ? const Center(child: Text('No verification codes found.'))
                              : ListView.builder(
                                  itemCount: widget.codes.length,
                                  itemBuilder: (context, index) {
                                    final code = widget.codes[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(
                                          code.codePart,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Duration: ${code.duration}'),
                                            Text('Status: ${code.timeRemaining}'),
                                          ],
                                        ),
                                        trailing: code.isExpired
                                            ? const Chip(
                                                label: Text('Expired'),
                                                backgroundColor: Colors.red,
                                              )
                                            : const Chip(
                                                label: Text('Active'),
                                                backgroundColor: Colors.green,
                                              ),
                                        isThreeLine: true,
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Stateful User Progress Dialog for better state management
class _StatefulUserProgressDialog extends StatefulWidget {
  final String userEmail;

  const _StatefulUserProgressDialog({
    required this.userEmail,
  });

  @override
  State<_StatefulUserProgressDialog> createState() => _StatefulUserProgressDialogState();
}

class _StatefulUserProgressDialogState extends State<_StatefulUserProgressDialog> {
  List<progress_data.ProgressData> _progress = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProgress();
  }

  Future<void> _loadUserProgress() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await apiService.getUserProgressByEmail(widget.userEmail);
      
      if (mounted) {
        setState(() {
          _progress = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Progress for ${widget.userEmail}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load progress data',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadUserProgress,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _progress.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      color: Colors.grey,
                                      size: 48,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No progress data found for this user.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _progress.length,
                                itemBuilder: (context, index) {
                                  final item = _progress[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(
                                        item.videoTitle ?? 'Video ${item.videoId}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Channel: ${item.channelName ?? item.channelId}'),
                                          const SizedBox(height: 8),
                                          LinearProgressIndicator(
                                            value: item.overallCompletion / 100,
                                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('${item.overallCompletion.toStringAsFixed(1)}% complete'),
                                        ],
                                      ),
                                      isThreeLine: true,
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
