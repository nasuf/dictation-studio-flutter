import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/channel_provider.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../generated/app_localizations.dart';

class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({super.key});

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen>
    with TickerProviderStateMixin {
  String _selectedLanguage = AppConstants.languageAll;
  bool _hasInitialized = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRefreshing = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized) {
        _hasInitialized = true;
        context.read<ChannelProvider>().fetchChannels();
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.info('ChannelListScreen build called');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0B)
          : theme.colorScheme.surface,
      body: Column(
        children: [
          // Header section - enhanced for dark mode
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 4,
              16,
              12,
            ),
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1A1A1D), // Darker at top
                        Color(0xFF16161A), // Slightly lighter at bottom
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.8,
                        ),
                      ],
                    ),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF2A2A2F).withValues(alpha: 0.5)
                      : theme.colorScheme.outline.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              boxShadow: isDark
                  ? [
                      const BoxShadow(
                        color: Color(0xFF000000),
                        offset: Offset(0, 2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title and Actions Row - more compact
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dictation Studio',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFE8E8EA)
                                  : theme.colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Consumer<ChannelProvider>(
                            builder: (context, provider, child) {
                              final totalChannels = provider.channels.length;
                              return Text(
                                AppLocalizations.of(
                                  context,
                                )!.channelsCount(totalChannels),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? const Color(0xFF9E9EA3)
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildActionButtons(theme),
                  ],
                ),

                const SizedBox(height: 8),

                // Search Bar
                _buildSearchBar(theme),

                // Language Filter (only show if selected)
                if (_selectedLanguage != AppConstants.languageAll) ...[
                  const SizedBox(height: 6),
                  _buildLanguageFilter(theme),
                ],
              ],
            ),
          ),

          // Main Content - takes remaining space with SafeArea for bottom only
          Expanded(
            child: SafeArea(
              top:
                  false, // Don't add safe area at top since we handle it manually
              child: _buildChannelContent(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.language_outlined,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          onPressed: () => _showLanguageFilter(context),
          tooltip: AppLocalizations.of(context)!.languageFilter,
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: Icon(
            Icons.refresh_outlined,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          onPressed: () async {
            setState(() {
              _isRefreshing = true;
            });
            try {
              await context.read<ChannelProvider>().fetchChannels(
                forceRefresh: true,
              );
            } finally {
              if (mounted) {
                setState(() {
                  _isRefreshing = false;
                });
              }
            }
            HapticFeedback.lightImpact();
          },
          tooltip: AppLocalizations.of(context)!.refresh,
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A2A2F), Color(0xFF1F1F24)],
              )
            : null,
        color: isDark
            ? null
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3A3A3F).withValues(alpha: 0.8)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: isDark
            ? [
                const BoxShadow(
                  color: Color(0xFF000000),
                  offset: Offset(0, 1),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchChannels,
          hintStyle: TextStyle(
            color: isDark
                ? const Color(0xFF8E8E93)
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_outlined,
            color: isDark
                ? const Color(0xFF007AFF).withValues(alpha: 0.8)
                : theme.colorScheme.primary.withValues(alpha: 0.7),
            size: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark
                        ? const Color(0xFF8E8E93)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 16,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
        style: TextStyle(
          color: isDark ? const Color(0xFFE8E8EA) : theme.colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildLanguageFilter(ThemeData theme) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getLocalizedLanguageName(context, _selectedLanguage),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedLanguage = AppConstants.languageAll;
                    });
                    context.read<ChannelProvider>().setLanguageFilter(
                      AppConstants.languageAll,
                    );
                  },
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelContent(ThemeData theme) {
    return Consumer<ChannelProvider>(
      builder: (context, channelProvider, child) {
        if ((channelProvider.isLoading && channelProvider.channels.isEmpty) ||
            _isRefreshing) {
          return _buildLoadingState(theme);
        }

        if (channelProvider.error != null) {
          return RefreshIndicator(
            onRefresh: () async {
              AppLogger.info('User initiated refresh from error state');
              await channelProvider.refreshChannels();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: _buildErrorState(theme, channelProvider.error!),
              ),
            ),
          );
        }

        if (channelProvider.channels.isEmpty) {
          return _buildEmptyState(theme);
        }

        // Filter channels by selected language and search query
        // Also ensure only public channels are shown (additional safety layer)
        final filteredChannels = channelProvider.channels.where((channel) {
          final isPublic = channel.visibility == AppConstants.visibilityPublic;
          final matchesLanguage =
              _selectedLanguage == AppConstants.languageAll ||
              channel.language == _selectedLanguage;
          final matchesSearch =
              _searchQuery.isEmpty ||
              channel.name.toLowerCase().contains(_searchQuery.toLowerCase());
          return isPublic && matchesLanguage && matchesSearch;
        }).toList();

        if (filteredChannels.isEmpty) {
          // If only search query is active, show "No results found"
          // If only language filter or both are active, show "No channels available"
          if (_searchQuery.isNotEmpty &&
              _selectedLanguage == AppConstants.languageAll) {
            return _buildNoResultsState(theme);
          } else {
            return _buildEmptyState(theme);
          }
        }

        return RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('User initiated refresh');
            await channelProvider.refreshChannels();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive grid based on screen width
              int crossAxisCount = 2;
              
              if (constraints.maxWidth > 900) {
                // Large tablets and desktops
                crossAxisCount = 3;
              } else if (constraints.maxWidth > 600) {
                // iPad and medium tablets
                crossAxisCount = 2;
              }
              
              return MasonryGridView.count(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                itemCount: filteredChannels.length,
                itemBuilder: (context, index) {
                  final channel = filteredChannels[index];
                  return _buildChannelCard(channel, index, theme);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChannelCard(dynamic channel, int index, ThemeData theme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animationValue = Tween<double>(begin: 0.0, end: 1.0)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  (index * 0.05).clamp(0.0, 0.8),
                  ((index * 0.05) + 0.2).clamp(0.2, 1.0),
                  curve: Curves.easeOut,
                ),
              ),
            )
            .value
            .clamp(0.0, 1.0);

        return Transform.scale(
          scale: (animationValue * 0.2 + 0.8).clamp(0.8, 1.0),
          child: Opacity(
            opacity: animationValue.clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(
                  '/videos/${channel.id}',
                  extra: {'channelName': channel.name},
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: theme.brightness == Brightness.dark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
                        )
                      : null,
                  color: theme.brightness == Brightness.dark
                      ? null
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF3A3A3F).withValues(alpha: 0.4)
                        : theme.colorScheme.outline.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                  boxShadow: theme.brightness == Brightness.dark
                      ? [
                          const BoxShadow(
                            color: Color(0xFF000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                            spreadRadius: 0,
                          ),
                          const BoxShadow(
                            color: Color(0xFF000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                            spreadRadius: 0,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(
                              alpha: 0.08,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel Image
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Responsive height based on card width
                        double imageHeight = constraints.maxWidth * 0.75; // 75% of card width
                        imageHeight = imageHeight.clamp(120.0, 180.0); // Min 120, max 180
                        
                        return Container(
                          height: imageHeight,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _getLanguageColor(
                                  channel.language,
                                ).withValues(alpha: 0.8),
                                _getLanguageColor(
                                  channel.language,
                                ).withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            child: Stack(
                              children: [
                                // Channel Image
                                if (channel.imageUrl?.isNotEmpty == true)
                                  CachedNetworkImage(
                                    imageUrl: channel.imageUrl!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: _getLanguageColor(
                                        channel.language,
                                      ).withValues(alpha: 0.3),
                                    ),
                                    errorWidget: (context, error, stackTrace) =>
                                        Container(
                                          color: _getLanguageColor(
                                            channel.language,
                                          ).withValues(alpha: 0.3),
                                        ),
                                  ),

                                // Gradient Overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.3),
                                      ],
                                    ),
                                  ),
                                ),

                                // Video Count Badge
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${channel.videoCount}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),

                                // Language Badge
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getLanguageColor(channel.language),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      channel.displayLanguage,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Channel Info
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        channel.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFFE8E8EA)
                              : theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitPulse(
            color: isDark ? const Color(0xFF007AFF) : theme.colorScheme.primary,
            size: 50,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingChannels,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark
                  ? const Color(0xFF9E9EA3)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.unableToLoadChannels,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.read<ChannelProvider>().fetchChannels(),
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noChannelsAvailable,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.checkBackLater,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noResultsFound,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.tryAdjustingSearch,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedLanguage = AppConstants.languageAll;
                });
                context.read<ChannelProvider>().setLanguageFilter(
                  AppConstants.languageAll,
                );
              },
              child: Text(AppLocalizations.of(context)!.clearFilters),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.filterByLanguage,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // All Languages option
                    _buildLanguageOption(
                      context,
                      theme,
                      AppLocalizations.of(context)!.allLanguages,
                      AppConstants.languageAll,
                      Icons.all_inclusive,
                      theme.colorScheme.primary,
                    ),

                    // Language options
                    ...LanguageHelper.getSupportedLanguages().map(
                      (language) => _buildLanguageOption(
                        context,
                        theme,
                        _getLocalizedLanguageName(context, language),
                        language,
                        Icons.language,
                        _getLanguageColor(language),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedLanguage == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLanguage = value;
          });
          context.read<ChannelProvider>().setLanguageFilter(value);
          Navigator.pop(context);
          HapticFeedback.lightImpact();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? theme.colorScheme.primary : color,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Get localized language name
  String _getLocalizedLanguageName(BuildContext context, String language) {
    switch (language) {
      case AppConstants.languageEnglish:
        return AppLocalizations.of(context)!.english;
      case AppConstants.languageChinese:
        return AppLocalizations.of(context)!.chinese;
      case AppConstants.languageJapanese:
        return AppLocalizations.of(context)!.japanese;
      case AppConstants.languageKorean:
        return AppLocalizations.of(context)!.korean;
      default:
        return language.toUpperCase();
    }
  }

  // Get language color for visual distinction with green theme
  Color _getLanguageColor(String language) {
    switch (language) {
      case AppConstants.languageEnglish:
        return const Color(0xFF4CAF50); // Green for English
      case AppConstants.languageChinese:
        return const Color(0xFF66BB6A); // Light green for Chinese
      case AppConstants.languageJapanese:
        return const Color(0xFF81C784); // Soft green for Japanese
      case AppConstants.languageKorean:
        return const Color(0xFF009688); // Teal for Korean
      default:
        return const Color(0xFF8BC34A); // Lime green for others
    }
  }
}

// Helper class for language display
class LanguageHelper {
  static String getLanguageName(String languageCode) {
    switch (languageCode) {
      case AppConstants.languageAll:
        return 'All Languages';
      case AppConstants.languageEnglish:
        return 'English';
      case AppConstants.languageChinese:
        return 'Chinese';
      case AppConstants.languageJapanese:
        return 'Japanese';
      case AppConstants.languageKorean:
        return 'Korean';
      default:
        return languageCode.toUpperCase();
    }
  }

  static List<String> getSupportedLanguages() {
    return [
      AppConstants.languageEnglish,
      AppConstants.languageChinese,
      AppConstants.languageJapanese,
      AppConstants.languageKorean,
    ];
  }
}
