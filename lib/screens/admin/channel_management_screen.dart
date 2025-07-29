import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/channel.dart';
import '../../providers/channel_provider.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

class ChannelManagementScreen extends StatefulWidget {
  const ChannelManagementScreen({super.key});

  @override
  State<ChannelManagementScreen> createState() =>
      _ChannelManagementScreenState();
}

class _ChannelManagementScreenState extends State<ChannelManagementScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  String _selectedLanguage = AppConstants.languageAll;
  String _selectedVisibility = AppConstants.visibilityAll;
  String _searchQuery = '';
  bool _isAddModalOpen = false;
  bool _isEditModalOpen = false;
  Channel? _editingChannel;

  // Form controllers for add/edit
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _linkController = TextEditingController();
  String _formLanguage = 'en';
  String _formVisibility = 'public';

  // Tab controller for unified design
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChannels();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _idController.dispose();
    _imageUrlController.dispose();
    _linkController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      await context.read<ChannelProvider>().fetchChannels(
        language: _selectedLanguage,
        visibility: _selectedVisibility,
      );
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load channels: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  List<Channel> _getFilteredChannels(List<Channel> channels) {
    return channels.where((channel) {
      // Only apply search filter in UI since language and visibility are already filtered at API level
      final matchesSearch =
          _searchQuery.isEmpty ||
          channel.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          channel.id.toLowerCase().contains(_searchQuery.toLowerCase());

      // Language and visibility filters are already applied at API level
      // so we don't need to filter them again in UI
      return matchesSearch;
    }).toList();
  }

  void _showAddChannelModal() {
    _clearForm();
    setState(() {
      _isAddModalOpen = true;
    });
  }

  void _showEditChannelModal(Channel channel) {
    _fillFormWithChannel(channel);
    setState(() {
      _editingChannel = channel;
      _isEditModalOpen = true;
    });
  }

  void _clearForm() {
    _nameController.clear();
    _idController.clear();
    _imageUrlController.clear();
    _linkController.clear();
    _formLanguage = 'en';
    _formVisibility = 'public';
  }

  void _fillFormWithChannel(Channel channel) {
    _nameController.text = channel.name;
    _idController.text = channel.id;
    _imageUrlController.text = channel.imageUrl;
    _linkController.text = channel.link;
    _formLanguage = channel.language;
    _formVisibility = channel.visibility;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Channel Management'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Channels', icon: Icon(Icons.video_library)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'Settings', icon: Icon(Icons.settings)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChannels,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChannelsTab(),
          _buildAnalyticsTab(),
          _buildSettingsTab(),
        ],
      ),
      floatingActionButton: (_isAddModalOpen || _isEditModalOpen)
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddChannelModal,
              icon: const Icon(Icons.add),
              label: const Text('Add Channel'),
            ),
      bottomSheet: (_isAddModalOpen || _isEditModalOpen)
          ? _buildChannelFormModal()
          : null,
    );
  }

  // Build channels tab
  Widget _buildChannelsTab() {
    return Consumer<ChannelProvider>(
      builder: (context, channelProvider, child) {
        final filteredChannels = _getFilteredChannels(
          channelProvider.channels,
        );

        return Column(
          children: [
            // Filters section
            _buildFiltersSection(),
            
            // Content area
            Expanded(
              child: channelProvider.isLoading
                  ? _buildLoadingState()
                  : _buildChannelList(filteredChannels, channelProvider),
            ),
          ],
        );
      },
    );
  }

  // Build analytics tab (placeholder)
  Widget _buildAnalyticsTab() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          const Text('Analytics feature coming soon'),
        ],
      ),
    );
  }

  // Build settings tab (placeholder)
  Widget _buildSettingsTab() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          const Text('Settings feature coming soon'),
        ],
      ),
    );
  }

  // Build filters section
  Widget _buildFiltersSection() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Language and visibility selection row
          Row(
            children: [
              // Language dropdown
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: AppConstants.languageOptions.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.value,
                          child: Text(
                            entry.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLanguage = value;
                      });
                      _loadChannels();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Visibility dropdown
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedVisibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibility',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: AppConstants.visibilityOptions.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.value,
                          child: Text(
                            entry.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedVisibility = value;
                      });
                      _loadChannels();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search bar
          SizedBox(
            width: double.infinity,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search channels...',
                hintText: 'Enter channel name or ID',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading channels...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList(List<Channel> channels, ChannelProvider provider) {
    final theme = Theme.of(context);
    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined, 
              size: 48, 
              color: theme.colorScheme.outline
            ),
            const SizedBox(height: 16),
            const Text('No channels found'),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _buildChannelCard(channel);
      },
    );
  }

  Widget _buildChannelCard(Channel channel) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channel name and actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${channel.id}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleChannelAction(channel, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit Channel'),
                        ],
                      ),
                    ),
                    if (channel.link.isNotEmpty)
                      const PopupMenuItem(
                        value: 'open_link',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new),
                            SizedBox(width: 8),
                            Text('Open Link'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Channel metadata
            Row(
              children: [
                Chip(
                  label: Text(
                    channel.displayLanguage.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    channel.isPublic ? 'PUBLIC' : 'PRIVATE',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: channel.isPublic
                      ? theme.colorScheme.primary.withOpacity(0.2)
                      : theme.colorScheme.secondary.withOpacity(0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    '${channel.videoCount} videos',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                  side: BorderSide(color: theme.colorScheme.outline),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Handle channel actions
  void _handleChannelAction(Channel channel, String action) {
    switch (action) {
      case 'edit':
        _showEditChannelModal(channel);
        break;
      case 'open_link':
        if (channel.link.isNotEmpty) {
          _openChannelLink(channel.link);
        }
        break;
    }
  }

  void _openChannelLink(String link) async {
    if (link.isEmpty) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No link available for this channel'),
            backgroundColor: theme.colorScheme.secondary,
          ),
        );
      }
      return;
    }

    AppLogger.info('Opening channel link: $link');

    try {
      // Parse the URL
      final Uri uri = Uri.parse(link);

      // Check if URL has a valid scheme
      if (!uri.hasScheme) {
        // Try to add https scheme if missing
        final Uri httpsUri = Uri.parse('https://$link');
        if (mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Open Link'),
              content: Text('Open this link in browser?\n$httpsUri'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Open'),
                ),
              ],
            ),
          );

          if (shouldOpen == true) {
            await _launchUrl(httpsUri);
          }
        }
        return;
      }

      // Show confirmation dialog for external links
      if (mounted) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Open External Link'),
            content: Text(
              'This will open the following link in your browser:\n$uri',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Open in Browser'),
              ),
            ],
          ),
        );

        if (shouldOpen == true) {
          await _launchUrl(uri);
        }
      }
    } catch (e) {
      AppLogger.error('Error parsing channel link: $e');
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid URL format: $link'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(Uri uri) async {
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Failed to launch URL');
      }

      AppLogger.info('Successfully opened URL: $uri');
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening link in browser...'),
            backgroundColor: theme.colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error launching URL: $e');
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open link: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveChannel() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final channelProvider = context.read<ChannelProvider>();

      if (_isEditModalOpen && _editingChannel != null) {
        // Update existing channel
        await channelProvider.updateChannel(
          _editingChannel!.id,
          name: _nameController.text.trim(),
          imageUrl: _imageUrlController.text.trim(),
          link: _linkController.text.trim(),
          language: _formLanguage,
          visibility: _formVisibility,
        );

        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Channel updated successfully'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        }

        setState(() {
          _isEditModalOpen = false;
          _editingChannel = null;
        });
      } else {
        // Add new channel
        final newChannel = Channel(
          id: _idController.text.trim(),
          name: _nameController.text.trim(),
          imageUrl: _imageUrlController.text.trim(),
          link: _linkController.text.trim(),
          language: _formLanguage,
          visibility: _formVisibility,
          videos: [],
        );

        await channelProvider.addChannel(newChannel);

        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Channel added successfully'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        }

        setState(() {
          _isAddModalOpen = false;
        });
      }

      _clearForm();
      await _loadChannels();
    } catch (e) {
      AppLogger.error('Error saving channel: $e');
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save channel: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildChannelFormModal() {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Modal Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEditModalOpen ? 'Edit Channel' : 'Add Channel',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isAddModalOpen = false;
                    _isEditModalOpen = false;
                    _editingChannel = null;
                  });
                  _clearForm();
                },
              ),
            ],
          ),
          const Divider(),

          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Channel Name *',
                        hintText: 'Enter channel name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Channel name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: 'Channel ID *',
                        hintText: 'Enter YouTube channel ID',
                      ),
                      enabled: !_isEditModalOpen, // Disable editing ID
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Channel ID is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL *',
                        hintText: 'Enter channel image URL',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Image URL is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _linkController,
                      decoration: const InputDecoration(
                        labelText: 'Channel Link',
                        hintText: 'Enter YouTube channel URL',
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final uri = Uri.tryParse(value);
                          if (uri == null || !uri.hasScheme) {
                            return 'Please enter a valid URL';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _formLanguage,
                            decoration: const InputDecoration(
                              labelText: 'Language *',
                            ),
                            items: AppConstants.languageOptions.entries
                                .where(
                                  (entry) =>
                                      entry.value != AppConstants.languageAll,
                                )
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.value,
                                    child: Text(entry.key),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _formLanguage = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _formVisibility,
                            decoration: const InputDecoration(
                              labelText: 'Visibility *',
                            ),
                            items: AppConstants.visibilityOptions.entries
                                .where(
                                  (entry) =>
                                      entry.value != AppConstants.visibilityAll,
                                )
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.value,
                                    child: Text(entry.key),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _formVisibility = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action Buttons
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isAddModalOpen = false;
                      _isEditModalOpen = false;
                      _editingChannel = null;
                    });
                    _clearForm();
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveChannel,
                  child: Text(_isEditModalOpen ? 'Update' : 'Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
