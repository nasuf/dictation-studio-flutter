import 'package:flutter/material.dart';

/// 完整的应用颜色系统 - 包含所有颜色定义和主题构建
/// 统一管理浅色、深色主题的颜色方案以及自定义颜色
class AppColors {
  AppColors._(); // 私有构造函数，防止实例化

  // ======================== 核心科技色彩系统 ========================
  
  /// 科技蓝 - 主色调
  static const Color techBlue = Color(0xFF3B82F6);
  
  /// 赛博青 - 辅助色
  static const Color techCyan = Color(0xFF06B6D4);
  
  /// 未来紫 - 强调色
  static const Color techPurple = Color(0xFF8B5CF6);

  // ======================== 浅色主题颜色定义 ========================
  
  static const Color _lightPrimary = techBlue;                    // 主色：科技蓝
  static const Color _lightPrimaryContainer = Color(0xFFF0F7FF);  // 主色容器：超浅蓝
  static const Color _lightSecondary = techCyan;                  // 辅助色：赛博青
  static const Color _lightSecondaryContainer = Color(0xFFECFEFF); // 辅助色容器：浅青
  static const Color _lightTertiary = techPurple;                 // 第三色：未来紫
  static const Color _lightTertiaryContainer = Color(0xFFF3F0FF); // 第三色容器：浅紫
  static const Color _lightSurface = Color(0xFFFAFBFC);           // 表面：冷白
  static const Color _lightSurfaceContainer = Color(0xFFF8FAFC);  // 表面容器：极浅灰
  static const Color _lightSurfaceContainerHighest = Color(0xFFF1F5F9); // 最高表面容器：浅灰
  static const Color _lightOnSurface = Color(0xFF1E293B);         // 表面文字：深蓝灰
  static const Color _lightOnSurfaceVariant = Color(0xFF64748B);  // 表面变体文字：中灰
  static const Color _lightOutline = Color(0xFF94A3B8);           // 边框：浅灰
  static const Color _lightOutlineVariant = Color(0xFFCBD5E1);    // 边框变体：更浅灰

  // ======================== 深色主题颜色定义 ========================
  
  static const Color _darkPrimary = Color(0xFF60A5FA);            // 主色：明亮蓝
  static const Color _darkPrimaryContainer = Color(0xFF1E3A8A);   // 主色容器：深蓝
  static const Color _darkSecondary = Color(0xFF22D3EE);          // 辅助色：明亮青
  static const Color _darkSecondaryContainer = Color(0xFF155E75); // 辅助色容器：深青
  static const Color _darkTertiary = Color(0xFFA78BFA);           // 第三色：明亮紫
  static const Color _darkTertiaryContainer = Color(0xFF581C87);  // 第三色容器：深紫
  static const Color _darkSurface = Color(0xFF0F172A);            // 表面：深蓝黑
  static const Color _darkSurfaceContainer = Color(0xFF1E293B);   // 表面容器：深蓝灰
  static const Color _darkSurfaceContainerHighest = Color(0xFF334155); // 最高表面容器：中深灰
  static const Color _darkOnSurface = Color(0xFFF1F5F9);          // 表面文字：浅灰白
  static const Color _darkOnSurfaceVariant = Color(0xFF94A3B8);   // 表面变体文字：中灰
  static const Color _darkOutline = Color(0xFF64748B);            // 边框：深灰
  static const Color _darkOutlineVariant = Color(0xFF475569);     // 边框变体：更深灰

  // ======================== 语义化颜色系统 ========================
  
  /// 成功色系
  static const Color success = Color(0xFF10B981);      // 成功绿
  static const Color successLight = Color(0xFFD1FAE5); // 浅成功绿
  static const Color successDark = Color(0xFF065F46);  // 深成功绿

  /// 警告色系
  static const Color warning = Color(0xFFF59E0B);      // 警告橙
  static const Color warningLight = Color(0xFFFEF3C7); // 浅警告橙
  static const Color warningDark = Color(0xFF92400E);  // 深警告橙

  /// 错误色系
  static const Color error = Color(0xFFEF4444);        // 错误红
  static const Color errorLight = Color(0xFFFEE2E2);   // 浅错误红
  static const Color errorDark = Color(0xFF991B1B);    // 深错误红

  /// 信息色系
  static const Color info = techBlue;                  // 信息蓝（使用科技蓝）
  static const Color infoLight = Color(0xFFDBEAFE);    // 浅信息蓝
  static const Color infoDark = Color(0xFF1E3A8A);     // 深信息蓝

  // ======================== 专用颜色系统 ========================
  
  /// 加载动画颜色
  static const Color shimmerBase = Color(0xFFE2E8F0);        // 浅色加载底色
  static const Color shimmerHighlight = Color(0xFFF8FAFC);   // 浅色加载高光
  static const Color shimmerBaseDark = Color(0xFF334155);    // 深色加载底色
  static const Color shimmerHighlightDark = Color(0xFF475569); // 深色加载高光

  /// 遮罩颜色
  static const Color modalOverlay = Color(0x80000000);       // 模态遮罩
  static const Color loadingOverlay = Color(0x40000000);     // 加载遮罩

  /// 状态颜色
  static const Color visibilityPublic = techBlue;           // 公开状态
  static const Color visibilityPrivate = Color(0xFF64748B); // 私有状态
  static const Color visibilityHidden = Color(0xFF94A3B8);  // 隐藏状态
  static const Color refinedTrue = success;                 // 已精炼
  static const Color refinedFalse = warning;                // 未精炼
  static const Color connected = success;                   // 已连接
  static const Color disconnected = error;                  // 已断开
  static const Color connecting = warning;                  // 连接中

  // ======================== 语言标签颜色映射 ========================
  
  /// 各语言对应的标签颜色
  static const Map<String, Color> languageColors = {
    'en': techBlue,                    // 英语 - 科技蓝
    'zh': techCyan,                    // 中文 - 赛博青
    'es': techPurple,                  // 西班牙语 - 未来紫
    'fr': Color(0xFF8B5CF6),           // 法语 - 紫色
    'de': Color(0xFF06B6D4),           // 德语 - 青色
    'ja': Color(0xFF3B82F6),           // 日语 - 蓝色
    'ko': Color(0xFF8B5CF6),           // 韩语 - 紫色
    'it': Color(0xFF06B6D4),           // 意大利语 - 青色
    'pt': Color(0xFF3B82F6),           // 葡萄牙语 - 蓝色
    'ru': Color(0xFF8B5CF6),           // 俄语 - 紫色
    'ar': Color(0xFF06B6D4),           // 阿拉伯语 - 青色
    'hi': Color(0xFF3B82F6),           // 印地语 - 蓝色
    'all': Color(0xFF64748B),          // 全部语言 - 中性灰
  };

  // ======================== 渐变色定义 ========================
  
  /// 科技渐变（浅色主题）
  static const LinearGradient techGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [techBlue, techCyan],
  );

  /// 科技渐变（深色主题）
  static const LinearGradient techGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF155E75)],
  );

  /// 微妙渐变（用于卡片背景等）
  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFAFBFC), Color(0xFFF1F5F9)],
  );

  /// 深色微妙渐变
  static const LinearGradient subtleGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  // ======================== 颜色方案构建器 ========================
  
  /// 构建浅色主题颜色方案
  static ColorScheme get lightColorScheme => ColorScheme.light(
    // 主要颜色
    primary: _lightPrimary,
    primaryContainer: _lightPrimaryContainer,
    onPrimary: Colors.white,
    onPrimaryContainer: Color(0xFF1E3A8A),
    
    // 辅助颜色
    secondary: _lightSecondary,
    secondaryContainer: _lightSecondaryContainer,
    onSecondary: Colors.white,
    onSecondaryContainer: Color(0xFF155E75),
    
    // 第三色
    tertiary: _lightTertiary,
    tertiaryContainer: _lightTertiaryContainer,
    onTertiary: Colors.white,
    onTertiaryContainer: Color(0xFF581C87),
    
    // 表面颜色
    surface: _lightSurface,
    surfaceContainer: _lightSurfaceContainer,
    surfaceContainerHighest: _lightSurfaceContainerHighest,
    onSurface: _lightOnSurface,
    onSurfaceVariant: _lightOnSurfaceVariant,
    
    // 语义颜色
    error: error,
    onError: Colors.white,
    errorContainer: errorLight,
    onErrorContainer: errorDark,
    
    // 边框和分割线
    outline: _lightOutline,
    outlineVariant: _lightOutlineVariant,
    
    // 反色和阴影
    inverseSurface: _darkSurface,
    onInverseSurface: _darkOnSurface,
    inversePrimary: _darkPrimary,
    shadow: Colors.black.withValues(alpha: 0.1),
    scrim: Colors.black.withValues(alpha: 0.8),
  );

  /// 构建深色主题颜色方案
  static ColorScheme get darkColorScheme => ColorScheme.dark(
    // 主要颜色
    primary: _darkPrimary,
    primaryContainer: _darkPrimaryContainer,
    onPrimary: Color(0xFF1E3A8A),
    onPrimaryContainer: Color(0xFFDEEAFF),
    
    // 辅助颜色
    secondary: _darkSecondary,
    secondaryContainer: _darkSecondaryContainer,
    onSecondary: Color(0xFF155E75),
    onSecondaryContainer: Color(0xFFCFFAFE),
    
    // 第三色
    tertiary: _darkTertiary,
    tertiaryContainer: _darkTertiaryContainer,
    onTertiary: Color(0xFF581C87),
    onTertiaryContainer: Color(0xFFF3F0FF),
    
    // 表面颜色
    surface: _darkSurface,
    surfaceContainer: _darkSurfaceContainer,
    surfaceContainerHighest: _darkSurfaceContainerHighest,
    onSurface: _darkOnSurface,
    onSurfaceVariant: _darkOnSurfaceVariant,
    
    // 语义颜色
    error: Color(0xFFFF8A80),
    onError: Colors.black,
    errorContainer: errorDark,
    onErrorContainer: errorLight,
    
    // 边框和分割线
    outline: _darkOutline,
    outlineVariant: _darkOutlineVariant,
    
    // 反色和阴影
    inverseSurface: _lightSurface,
    onInverseSurface: _lightOnSurface,
    inversePrimary: _lightPrimary,
    shadow: Colors.black.withValues(alpha: 0.3),
    scrim: Colors.black.withValues(alpha: 0.9),
  );

  // ======================== 工具方法 ========================
  
  /// 根据语言代码获取对应颜色
  static Color getLanguageColor(String? languageCode) {
    return languageColors[languageCode?.toLowerCase()] ?? languageColors['all']!;
  }

  /// 根据主题明暗获取加载动画颜色
  static List<Color> getShimmerColors(Brightness brightness) {
    return brightness == Brightness.dark
        ? [shimmerBaseDark, shimmerHighlightDark]
        : [shimmerBase, shimmerHighlight];
  }

  /// 根据主题明暗获取科技渐变
  static LinearGradient getTechGradient(Brightness brightness) {
    return brightness == Brightness.dark ? techGradientDark : techGradient;
  }

  /// 根据主题明暗获取微妙渐变
  static LinearGradient getSubtleGradient(Brightness brightness) {
    return brightness == Brightness.dark ? subtleGradientDark : subtleGradient;
  }
}

// ======================== 主题感知颜色扩展 ========================

/// BuildContext 扩展，方便获取主题感知的颜色
extension AppColorsExtension on BuildContext {
  /// 获取适应当前主题的颜色访问器
  AppColorsThemeAware get colors => AppColorsThemeAware.of(this);
}

/// 主题感知颜色访问器 - 根据当前主题自动选择合适的颜色
class AppColorsThemeAware {
  final Brightness brightness;
  final ColorScheme colorScheme;

  const AppColorsThemeAware._(this.brightness, this.colorScheme);

  /// 从 BuildContext 创建主题感知颜色访问器
  factory AppColorsThemeAware.of(BuildContext context) {
    final theme = Theme.of(context);
    return AppColorsThemeAware._(theme.brightness, theme.colorScheme);
  }

  // ======================== 动态颜色属性 ========================
  
  /// 当前主题的加载动画颜色
  List<Color> get shimmerColors => AppColors.getShimmerColors(brightness);

  /// 当前主题的科技渐变
  LinearGradient get techGradient => AppColors.getTechGradient(brightness);

  /// 当前主题的微妙渐变
  LinearGradient get subtleGradient => AppColors.getSubtleGradient(brightness);

  /// 卡片背景色（主题适应）
  Color get cardBackground => brightness == Brightness.dark 
      ? colorScheme.surfaceContainer 
      : const Color(0xFFF8FAFC);

  /// 加载卡片背景色
  Color get loadingCardBackground => brightness == Brightness.dark
      ? AppColors.shimmerBaseDark
      : AppColors.shimmerBase;

  /// 语言图标颜色
  Color get languageIconColor => colorScheme.primary;

  /// 地球图标颜色（语言选择器中使用）
  Color get globeIconColor => colorScheme.primary;

  /// 成功色（主题适应）
  Color get success => brightness == Brightness.dark
      ? AppColors.success
      : AppColors.success;

  /// 警告色（主题适应）
  Color get warning => brightness == Brightness.dark
      ? AppColors.warning
      : AppColors.warning;

  /// 错误色（主题适应）
  Color get error => brightness == Brightness.dark
      ? const Color(0xFFFF8A80)
      : AppColors.error;

  /// 信息色（主题适应）
  Color get info => brightness == Brightness.dark
      ? AppColors._darkPrimary
      : AppColors.info;
}