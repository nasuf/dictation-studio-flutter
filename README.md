# Dictation Studio Flutter

A Flutter mobile application for dictation learning, converted from the React UI project. This app provides a mobile-friendly interface for browsing language learning channels and videos.

## 🌟 Features

- **Channel List**: Browse learning channels organized by language (English, Chinese, Japanese, Korean)
- **Video List**: View videos with progress tracking and thumbnails
- **Progress Tracking**: Visual progress indicators for each video
- **Language Filtering**: Filter channels by language
- **Responsive Design**: Optimized for mobile devices with modern Material Design 3
- **Error Handling**: Comprehensive error states and retry mechanisms
- **Loading States**: Beautiful loading animations using SpinKit

## 📱 Screenshots

The app features:

- Grid-based channel and video layouts
- Language badges with color coding
- Progress bars and completion indicators
- Responsive design for different screen sizes
- Material Design 3 theme with modern styling

## 🏗️ Architecture

### Project Structure

```
lib/
├── models/          # Data models (Channel, Video, Progress)
├── services/        # API service layer
├── providers/       # State management using Provider pattern
├── screens/         # UI screens
├── widgets/         # Reusable UI components
└── utils/           # Constants and utilities
```

### Key Components

- **Models**: JSON-serializable data models for Channel, Video, and Progress
- **API Service**: HTTP client for backend communication
- **Providers**: State management for channels and videos with loading/error states
- **Screens**: Channel list and video list screens with modern UI
- **Widgets**: Reusable channel and video cards with animations

## 🔧 Dependencies

Key packages used:

- `provider` - State management
- `http` - HTTP client for API calls
- `go_router` - Navigation and routing
- `cached_network_image` - Image caching
- `flutter_staggered_grid_view` - Grid layouts
- `flutter_spinkit` - Loading animations
- `percent_indicator` - Progress indicators
- `json_annotation` & `json_serializable` - JSON serialization

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio / VS Code
- Android emulator or physical device

### Installation

1. **Clone the repository**

   ```bash
   cd dictation_studio_flutter
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Generate JSON serialization code**

   ```bash
   flutter packages pub run build_runner build
   ```

4. **Run the app**

   ```bash
   # For Android
   flutter run

   # For specific device
   flutter run -d <device_id>
   ```

### Configuration

The app is configured to use the production HTTPS endpoint by default:

#### Production Environment (Default)

- **All Platforms**: `https://www.dictationstudio.com/ds`

#### Development Environment (Optional)

- **Android Emulator**: `http://10.0.2.2:4001/dictation-studio`
- **iOS Simulator**: `http://localhost:4001/dictation-studio`
- **Physical Device**: `http://YOUR_LOCAL_IP:4001/dictation-studio`

#### Switching API Endpoints (Development Only)

You can easily switch between different development endpoints:

```dart
// In your app initialization or anywhere in debug mode
import 'utils/dev_tools.dart';

// Use Android emulator (default)
DevTools.useAndroidEmulator();

// Use iOS simulator
DevTools.useIOSSimulator();

// Use physical device with your local IP
DevTools.usePhysicalDevice("192.168.1.100");

// Use custom URL
DevTools.useCustomUrl("http://your-custom-url:4001/dictation-studio");

// Reset to default
DevTools.resetToDefault();

// Print current configuration
DevTools.printCurrentConfig();
```

The environment configuration:

- **All builds** → Production environment (HTTPS)
- **Development testing** → Use DevTools to switch to local endpoints

## 📋 API Integration

The app integrates with the dictation studio backend API:

- `GET /service/channel` - Fetch channels list
- `GET /service/video-list/{channelId}` - Fetch videos for a channel
- `GET /user/progress/channel` - Get progress for all videos in a channel
- `POST /user/progress` - Save user progress
- `GET /user/dictation_quota` - Check dictation quota

## 🎨 Design Highlights

### Mobile-First Design

- Responsive grid layouts that adapt to screen size
- Touch-friendly interface with appropriate button sizes
- Smooth animations and transitions

### Visual Elements

- Language color coding (Blue: English, Red: Chinese, Pink: Japanese, Purple: Korean)
- Progress indicators with color-coded completion levels
- Modern card-based layout with rounded corners and shadows
- Skeleton loading screens for better UX

### Accessibility

- Semantic widgets for screen readers
- High contrast colors
- Descriptive labels and tooltips

## 🔄 State Management

Using Provider pattern for clean state management:

- **ChannelProvider**: Manages channel list, filtering, and loading states
- **VideoProvider**: Handles video list, progress tracking, and error states

## 📱 Supported Platforms

- ✅ Android
- ✅ iOS (requires additional setup)
- ⚠️ Web (limited support)

## 🔮 Future Enhancements

- [ ] Video player integration
- [ ] Offline support with local storage
- [ ] Push notifications for progress reminders
- [ ] Dark mode theme
- [ ] User authentication
- [ ] Advanced filtering and search
- [ ] Achievement system
- [ ] Social features (sharing progress)

## 🐛 Known Issues

- API requires authentication for some features (placeholder UI shown)
- Video playback not yet implemented (shows dialog)
- Some iOS-specific styling may need adjustment

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on multiple devices
5. Submit a pull request

## 📄 License

This project is part of the Dictation Studio suite. Please refer to the main project license.

## 🙏 Acknowledgments

- Converted from the original React UI project
- Built with Flutter's modern Material Design 3
- API integration based on the existing dictation studio backend
