# 颜色系统架构文档

## 概述

本项目使用统一的颜色管理系统，所有颜色定义和主题配置都在 `app_colors.dart` 中集中管理，确保设计一致性和维护便利性。

## 文件结构

```
lib/theme/
├── app_colors.dart    # 🎨 统一颜色系统（包含所有颜色定义和ColorScheme构建器）
├── app_theme.dart     # 🎨 主题配置（使用AppColors构建完整ThemeData）
└── README.md          # 📚 本文档
```

## 核心设计原则

### 1. **单一数据源 (Single Source of Truth)**
- 所有颜色定义集中在 `AppColors` 类中
- 消除重复的颜色常量定义
- 确保整个应用使用一致的颜色值

### 2. **语义化设计 (Semantic Design)**
- 按功能和用途对颜色进行分类
- 提供语义化的颜色名称（如 `success`、`warning`、`error`）
- 支持主题感知的颜色选择

### 3. **可扩展性 (Extensibility)**
- 结构化的颜色分组，易于添加新颜色
- 灵活的工具方法支持动态颜色选择
- 主题感知的颜色访问器

## 颜色系统架构

### 🎯 核心科技色彩
```dart
static const Color techBlue = Color(0xFF3B82F6);    // 科技蓝 - 主色调
static const Color techCyan = Color(0xFF06B6D4);    // 赛博青 - 辅助色
static const Color techPurple = Color(0xFF8B5CF6);  // 未来紫 - 强调色
```

### 🌈 语义化颜色系统
```dart
// 成功色系
static const Color success = Color(0xFF10B981);
static const Color successLight = Color(0xFFD1FAE5);
static const Color successDark = Color(0xFF065F46);

// 警告色系
static const Color warning = Color(0xFFF59E0B);
// ... 更多语义化颜色
```

### 🌅 主题颜色方案
- **浅色主题**: `AppColors.lightColorScheme`
- **深色主题**: `AppColors.darkColorScheme`
- **自动构建**: 完整的 Material Design 3 颜色方案

### 🛠️ 工具方法
```dart
// 获取语言标签颜色
AppColors.getLanguageColor('en')  // 返回对应语言的颜色

// 获取主题感知渐变
AppColors.getTechGradient(brightness)  // 根据明暗主题返回合适的渐变

// 获取加载动画颜色
AppColors.getShimmerColors(brightness)  // 返回当前主题的加载动画颜色
```

## 使用方法

### 📱 在 Widget 中使用

#### 1. 直接使用颜色常量
```dart
Container(
  color: AppColors.techBlue,  // 使用核心科技蓝
  child: Text('Hello'),
)
```

#### 2. 使用语义化颜色
```dart
Icon(
  Icons.check,
  color: AppColors.success,  // 使用成功色
)
```

#### 3. 使用主题感知颜色
```dart
Container(
  color: context.colors.cardBackground,  // 自动适应主题的卡片背景色
  child: Text('Card Content'),
)
```

#### 4. 使用工具方法
```dart
Container(
  decoration: BoxDecoration(
    gradient: AppColors.getTechGradient(
      Theme.of(context).brightness
    ),
  ),
  child: Text('Gradient Background'),
)
```

### 🎨 主题配置

主题配置自动使用统一的颜色系统：

```dart
MaterialApp(
  theme: AppTheme.lightTheme(),      // 浅色主题
  darkTheme: AppTheme.darkTheme(),   // 深色主题
  home: MyHomePage(),
)
```

## 主题感知颜色访问器

通过 `BuildContext` 扩展，可以方便地访问适应当前主题的颜色：

```dart
// 在任何 Widget 中使用
Widget build(BuildContext context) {
  return Container(
    color: context.colors.cardBackground,        // 主题感知的卡片背景
    decoration: BoxDecoration(
      gradient: context.colors.techGradient,     // 主题感知的科技渐变
    ),
    child: Icon(
      Icons.language,
      color: context.colors.globeIconColor,      // 主题感知的图标颜色
    ),
  );
}
```

## 颜色分类说明

### 1. **核心科技色彩** (`techBlue`, `techCyan`, `techPurple`)
- 应用的品牌色彩
- 用于主要UI元素、按钮、图标等

### 2. **语义化颜色** (`success`, `warning`, `error`, `info`)
- 表示状态和反馈的颜色
- 每个语义色都有浅色和深色变体

### 3. **主题颜色** (私有 `_light*`, `_dark*`)
- Material Design 3 色彩系统
- 自动构建完整的 ColorScheme

### 4. **专用颜色**
- **加载动画色**: `shimmerBase`, `shimmerHighlight`
- **遮罩色**: `modalOverlay`, `loadingOverlay`
- **状态色**: `visibilityPublic`, `refinedTrue` 等

### 5. **语言标签色** (`languageColors` Map)
- 为不同语言分配不同的标识色
- 基于科技色彩系统进行分配

## 添加新颜色

### 1. 添加基础颜色常量
```dart
// 在 AppColors 类中添加
static const Color newFeatureColor = Color(0xFF...");
```

### 2. 添加到相应的颜色方案
```dart
// 在 lightColorScheme 或 darkColorScheme 中使用
primary: newFeatureColor,
```

### 3. 添加工具方法（如需要）
```dart
static Color getFeatureColor(String featureType) {
  // 实现获取功能颜色的逻辑
}
```

### 4. 添加主题感知访问器（如需要）
```dart
// 在 AppColorsThemeAware 类中添加
Color get featureColor => brightness == Brightness.dark
    ? AppColors.darkFeatureColor
    : AppColors.lightFeatureColor;
```

## 迁移指南

如果需要从旧的颜色系统迁移：

1. **查找硬编码颜色**: 搜索 `Color(0xFF...)` 或 `Colors.green` 等
2. **替换为语义化颜色**: 使用 `AppColors.success` 而不是 `Colors.green`
3. **使用主题感知颜色**: 优先使用 `context.colors.*` 访问器
4. **更新导入**: 添加 `import '../theme/app_colors.dart';`

## 最佳实践

### ✅ 推荐做法
- 使用 `AppColors.*` 常量而不是硬编码颜色值
- 优先使用语义化颜色名称（`success` vs `green`）
- 使用主题感知的颜色访问器 `context.colors.*`
- 为新功能添加专门的颜色定义

### ❌ 避免做法
- 不要在代码中硬编码 `Color(0xFF...)` 值
- 不要使用 `Colors.green` 等 Flutter 默认颜色
- 不要在多个文件中重复定义相同的颜色常量
- 不要绕过颜色系统直接设置颜色

## 调试和维护

### 1. **颜色一致性检查**
```bash
# 搜索可能的硬编码颜色
grep -r "Color(0x" lib/
grep -r "Colors\." lib/
```

### 2. **主题测试**
- 在浅色和深色主题间切换测试
- 确保所有颜色在两种主题下都有良好的对比度
- 验证语义化颜色的表现是否符合预期

### 3. **新颜色添加检查清单**
- [ ] 颜色值符合设计规范
- [ ] 在浅色和深色主题下都测试过
- [ ] 提供了合适的语义化命名
- [ ] 更新了相关文档
- [ ] 添加了必要的工具方法

## 技术细节

### ColorScheme 构建
- 使用 Material Design 3 规范
- 自动计算 `onPrimary`, `onSecondary` 等颜色
- 支持完整的色彩角色体系

### 性能考虑
- 所有颜色常量都是编译时常量
- 主题感知访问器使用工厂模式，避免重复计算
- 渐变和复杂颜色对象使用懒加载

### 兼容性
- 支持 Material Design 3
- 兼容 Flutter 3.0+
- 支持深色主题和高对比度模式

---

**维护者**: Dictation Studio 开发团队  
**最后更新**: 2024年8月