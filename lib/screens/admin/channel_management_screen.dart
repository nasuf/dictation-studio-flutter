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

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChannels();
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _idController.dispose();
    _imageUrlController.dispose();
    _linkController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
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
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Consumer<ChannelProvider>(
            builder: (context, channelProvider, child) {
              final filteredChannels = _getFilteredChannels(
                channelProvider.channels,
              );

              return Column(
                children: [
                  _buildSearchAndFilters(),
                  Expanded(
                    child: channelProvider.isLoading
                        ? _buildLoadingState()
                        : _buildChannelList(filteredChannels, channelProvider),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: (_isAddModalOpen || _isEditModalOpen)
          ? null
          : _buildFloatingActionButton(),
      bottomSheet: (_isAddModalOpen || _isEditModalOpen)
          ? _buildChannelFormModal()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 2,
      shadowColor: theme.colorScheme.shadow,
      title: Row(
        children: [
          const SizedBox(width: 12),
          Text(
            'Channel Management',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Consumer<ChannelProvider>(
            builder: (context, provider, child) {
              return GestureDetector(
                onTap: provider.isLoading ? null : _loadChannels,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: provider.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.refresh,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3), width: 1),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search channels by name or ID...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filters
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Language',
                  _selectedLanguage,
                  AppConstants.languageOptions,
                  (value) {
                    setState(() {
                      _selectedLanguage = value;
                    });
                    _loadChannels();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'Visibility',
                  _selectedVisibility,
                  AppConstants.visibilityOptions,
                  (value) {
                    setState(() {
                      _selectedVisibility = value;
                    });
                    _loadChannels();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    Map<String, String> options,
    Function(String) onChanged,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
          style: TextStyle(color: theme.colorScheme.onSurface),
          dropdownColor: theme.colorScheme.surface,
          icon: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.onSurfaceVariant),
          items: options.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.value,
              child: Text(
                entry.key,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            );
          }).toList(),
        ),
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3), width: 1),
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 64,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No channels found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _buildChannelCard(channel, provider);
      },
    );
  }

  Widget _buildChannelCard(Channel channel, ChannelProvider provider) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Channel Image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  channel.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.video_library,
                        color: theme.colorScheme.onPrimary,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Channel Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${channel.id}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Videos: ${channel.videoCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tags
                  Row(
                    children: [
                      _buildTag(
                        channel.displayLanguage,
                        theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      _buildTag(
                        channel.isPublic ? 'PUBLIC' : 'PRIVATE',
                        channel.isPublic
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                _buildActionButton(
                  Icons.edit,
                  'Edit',
                  () => _showEditChannelModal(channel),
                  const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  Icons.open_in_new,
                  'View',
                  () => _openChannelLink(channel.link),
                  theme.colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _showAddChannelModal,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary, size: 24),
      ),
    );
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
