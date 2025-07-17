# 🌤️ Weather App

A beautiful Flutter weather application with animated effects and immersive sound experience.

## ✨ Features

- �️ **Real-time weather data** from OpenWeatherMap API
- 🎵 **Weather-appropriate sound effects** (rain sounds, birds chirping)
- 🌧️ **Animated rain effects** for rainy weather
- ☀️ **Sun animations** for clear weather
- ☁️ **Moving cloud animations** for cloudy weather
- 🌍 **Multiple city support** with search functionality
- ⭐ **Favorite cities** quick access
- 📍 **Location-based weather** using GPS
- 🕐 **Hourly forecast** for next 24 hours
- 📅 **5-day weather forecast**
- 🌅 **Sunrise/sunset times**
- � **Wind speed, humidity, pressure data**
- 🌿 **Air quality index (AQI)**
- ⚠️ **Weather alerts** and warnings
- �📱 **Responsive design** for all screen sizes

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/weather-app.git
   cd weather-app
   ```

2. **Setup API Key**
   - Copy `.env.example` to `.env`
   - Get your free API key from [OpenWeatherMap](https://openweathermap.org/api)
   - Add your API key to the `.env` file:
     ```
     OPENWEATHER_API_KEY=your_api_key_here
     ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 📦 Dependencies

- **flutter_dotenv**: Environment variables management
- **http**: API calls to weather services
- **geolocator**: Location services for GPS-based weather
- **geocoding**: Convert coordinates to city names
- **audioplayers**: Weather sound effects

## 📱 Screenshots

*Add screenshots of your app here*

## 🛠️ Technical Details

### Architecture
- **State Management**: StatefulWidget with setState
- **API Integration**: OpenWeatherMap API v2.5
- **Platform Support**: iOS, Android, Web, Windows, macOS, Linux

### APIs Used
- Current Weather API
- 5-Day Forecast API
- One Call API (UV Index, Weather Alerts)
- Air Pollution API

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Weather data provided by [OpenWeatherMap](https://openweathermap.org/)
- Sound effects from Flutter assets
- Icons from Flutter's Material Design icons

---

## 🔧 Development Setup

### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio / VS Code
- Android SDK / Xcode (for mobile development)

### Running Tests
```bash
flutter test
```

### Building for Production
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```
