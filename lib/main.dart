// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'rain_effect.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'sun_effect.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  _WeatherHomePageState createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  String city = 'Istanbul';
  List<String> cities = ['Istanbul', 'Ankara', 'Izmir'];
  List<String> favoriteCities = ['Istanbul', 'Ankara'];
  Map<String, dynamic>? currentWeather;
  List<Map<String, dynamic>> hourly = [];
  List<Map<String, dynamic>> daily = [];
  bool isLoading = true;
  AudioPlayer? _audioPlayer;
  String? _currentSound;

  double? uvIndex;
  int? aqi;
  String? weatherAlert;

  @override
  void initState() {
    super.initState();
    fetchWeatherData(city);
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> fetchWeatherData(String city) async {
    setState(() {
      isLoading = true;
    });

    final apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';
    final url =
        'https://api.openweathermap.org/data/2.5/forecast?q=$city&units=metric&appid=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final current = data['list'][0];
        final currentWeatherData = {
          'temp': current['main']['temp'].round(),
          'feels_like': current['main']['feels_like'].round(),
          'description': current['weather'][0]['description'],
          'date': DateTime.parse(current['dt_txt']),
          'icon': current['weather'][0]['icon'],
          'wind_speed': current['wind']['speed'],
          'humidity': current['main']['humidity'],
          'pressure': current['main']['pressure'],
          'sunrise': data['city']['sunrise'],
          'sunset': data['city']['sunset'],
        };
        String? asset;
        final description =
            currentWeatherData['description']?.toLowerCase() ?? '';

        if (description.contains('rain')) {
          asset = 'rain.mp3';
        } else if (description.contains('clear')) {
          asset = 'birds.mp3';
        }
        if (asset != null && asset != _currentSound) {
          await _audioPlayer?.stop();
          _audioPlayer = AudioPlayer();
          await _audioPlayer!.play(AssetSource(asset));
          _currentSound = asset;
        }
        final lat = data['city']['coord']['lat'];
        final lon = data['city']['coord']['lon'];

        final oneCallUrl =
            'https://api.openweathermap.org/data/2.5/onecall?lat=$lat&lon=$lon&exclude=minutely,hourly,daily,alerts&appid=$apiKey';
        final oneCallResponse = await http.get(Uri.parse(oneCallUrl));

        if (oneCallResponse.statusCode == 200) {
          final oneCallData = json.decode(oneCallResponse.body);
          uvIndex = oneCallData['current']['uvi']?.toDouble();
          if (oneCallData['alerts'] != null &&
              oneCallData['alerts'].isNotEmpty) {
            weatherAlert = oneCallData['alerts'][0]['event'] +
                ": " +
                oneCallData['alerts'][0]['description'];
          }
        }
        final aqiUrl =
            'https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey';
        final aqiResponse = await http.get(Uri.parse(aqiUrl));
        if (aqiResponse.statusCode == 200) {
          final aqiData = json.decode(aqiResponse.body);
          aqi = aqiData['list'][0]['main']['aqi'];
        }

        final now = DateTime.now();
        final List<Map<String, dynamic>> hourlyData =
            data['list'].map<Map<String, dynamic>>((item) {
          final itemTime = DateTime.parse(item['dt_txt']);
          return {
            'hour': '${itemTime.hour.toString().padLeft(2, '0')}:00',
            'temp': item['main']['temp'].round(),
            'description': item['weather'][0]['description'] ?? 'clouds',
            'icon': item['weather'][0]['icon'],
            'pop': ((item['pop'] ?? 0.0) * 100).round(),
            'time': itemTime,
          };
        }).where((item) {
          final itemTime = item['time'] as DateTime;
          return itemTime.isAfter(now);
        }).toList();
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var item in data['list']) {
          final itemDate = DateTime.parse(item['dt_txt']);
          final dayKey = '${itemDate.year}-${itemDate.month}-${itemDate.day}';
          grouped.putIfAbsent(dayKey, () => []).add({
            'date': itemDate,
            'temp_min': item['main']['temp_min'],
            'temp_max': item['main']['temp_max'],
            'icon': item['weather'][0]['icon'],
            'description': item['weather'][0]['description'],
          });
        }

        final List<Map<String, dynamic>> dailyData = [];
        grouped.forEach((key, value) {
          final minTemp =
              value.map((e) => e['temp_min']).reduce((a, b) => a < b ? a : b);
          final maxTemp =
              value.map((e) => e['temp_max']).reduce((a, b) => a > b ? a : b);
          final nineAM = value.firstWhere(
            (e) => e['date'].hour == 9,
            orElse: () => value[0],
          );
          dailyData.add({
            'date': nineAM['date'],
            'day': '${nineAM['date'].day}/${nineAM['date'].month}',
            'temp_max': maxTemp.round(),
            'temp_min': minTemp.round(),
            'icon': nineAM['icon'],
            'description': nineAM['description'],
            'details': value,
          });
        });

        setState(() {
          currentWeather = currentWeatherData;
          hourly = hourlyData;
          daily = dailyData;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showCitySelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final allCities = [
          'Berlin',
          'London',
          'Paris',
          'New York',
          'Tokyo',
          'Sydney',
          'Mumbai',
          'Los Angeles',
          'Cape Town',
          'Moscow',
          'Istanbul',
          'Ankara',
          'Izmir',
        ];
        TextEditingController searchController = TextEditingController();
        List<String> filteredCities = List.from(allCities);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (favoriteCities.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favoriler',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: favoriteCities
                              .map(
                                (cityName) => ActionChip(
                                  label: Text(cityName),
                                  onPressed: () {
                                    setState(() {
                                      city = cityName;
                                    });
                                    fetchWeatherData(city);
                                    Navigator.pop(context);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        Divider(color: Colors.white24),
                      ],
                    ),
                  TextField(
                    controller: searchController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Şehir ara...",
                      hintStyle: TextStyle(color: Colors.white54),
                      prefixIcon: Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey[850],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        filteredCities = allCities
                            .where(
                              (c) =>
                                  c.toLowerCase().contains(value.toLowerCase()),
                            )
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCities.length,
                      itemBuilder: (context, index) {
                        final cityName = filteredCities[index];
                        return ListTile(
                          title: Text(
                            cityName,
                            style: TextStyle(color: Colors.white),
                          ),
                          leading: Icon(
                            Icons.location_city,
                            color: Colors.blue[200],
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              favoriteCities.contains(cityName)
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                            ),
                            onPressed: () {
                              setState(() {
                                if (favoriteCities.contains(cityName)) {
                                  favoriteCities.remove(cityName);
                                } else {
                                  favoriteCities.add(cityName);
                                }
                              });
                              setModalState(() {});
                            },
                          ),
                          onTap: () {
                            setState(() {
                              city = cityName;
                            });
                            fetchWeatherData(city);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey[900]!, Colors.blue[700]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            currentWeather != null
                ? _getBackgroundEffect(currentWeather!['description'])
                : Container(color: Colors.blue[100]),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (currentWeather != null && weatherAlert != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  weatherAlert!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (currentWeather != null &&
                        (currentWeather!['temp'] >= 35 ||
                            currentWeather!['temp'] <= 0 ||
                            (hourly.isNotEmpty && hourly[0]['pop'] > 70)))
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  currentWeather!['temp'] >= 35
                                      ? 'Aşırı sıcak! Dikkatli ol.'
                                      : currentWeather!['temp'] <= 0
                                          ? 'Aşırı soğuk! Dikkatli ol.'
                                          : 'Bugün yüksek ihtimalle yağış var!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  city,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.grey[850],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[850],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 2,
                            ),
                            icon: Icon(Icons.search),
                            label: Text("Şehir Değiştir"),
                            onPressed: _showCitySelectionModal,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(Icons.my_location, color: Colors.white),
                            tooltip: "Konumdan Bul",
                            onPressed: () async {
                              bool hasPermission =
                                  await _handleLocationPermission();
                              if (!hasPermission) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Konum izni gerekli!'),
                                  ),
                                );
                                return;
                              }
                              Position pos =
                                  await Geolocator.getCurrentPosition(
                                desiredAccuracy: LocationAccuracy.high,
                              );
                              List<Placemark> placemarks =
                                  await placemarkFromCoordinates(
                                pos.latitude,
                                pos.longitude,
                              );
                              if (placemarks.isNotEmpty) {
                                setState(() {
                                  city = placemarks.first.locality ?? city;
                                });
                                fetchWeatherData(city);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        currentWeather != null
                            ? Image.network(
                                'https://openweathermap.org/img/wn/${currentWeather!['icon']}@4x.png',
                                width: 110,
                                height: 110,
                              )
                            : Icon(Icons.cloud, size: 110, color: Colors.white),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Icon(
                            Icons.brightness_2,
                            size: 40,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentWeather != null
                          ? '${currentWeather!['temp']}°'
                          : 'Loading...',
                      style: TextStyle(
                        fontSize: 60,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentWeather != null
                          ? currentWeather!['description']
                          : 'Loading...',
                      style: TextStyle(fontSize: 20, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentWeather != null
                          ? '${currentWeather!['date'].day}/${currentWeather!['date'].month}/${currentWeather!['date'].year}'
                          : 'Loading...',
                      style: TextStyle(fontSize: 16, color: Colors.white60),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentWeather != null
                          ? 'Hissedilen: ${currentWeather!['feels_like']}°'
                          : '',
                      style: TextStyle(fontSize: 16, color: Colors.white60),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _WeatherInfo(
                              icon: Icons.wb_sunny,
                              value: _formatTime(currentWeather?['sunrise']),
                            ),
                            const SizedBox(width: 28),
                            _WeatherInfo(
                              icon: Icons.nights_stay,
                              value: _formatTime(currentWeather?['sunset']),
                            ),
                            const SizedBox(width: 16),
                            _WeatherInfo(
                              icon: Icons.air,
                              value: '${currentWeather?['wind_speed']} km/h',
                            ),
                            const SizedBox(width: 16),
                            _WeatherInfo(
                              icon: Icons.water_drop,
                              value: '${currentWeather?['humidity']}%',
                            ),
                            const SizedBox(width: 16),
                            _WeatherInfo(
                              icon: Icons.compress,
                              value: '${currentWeather?['pressure']} hPa',
                            ),
                            if (aqi != null) ...[
                              const SizedBox(width: 16),
                              _WeatherInfo(icon: Icons.eco, value: '$aqi'),
                            ],
                            SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Saatlik Forecast',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 160,
                        child: isLoading
                            ? Center(child: CircularProgressIndicator())
                            : ListView.separated(
                                shrinkWrap: true,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: hourly.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, i) {
                                  final h = hourly[i];
                                  return _HourlyWeatherCard(
                                    hour: h['hour'],
                                    temp: h['temp'],
                                    description: h['description'],
                                    icon: h['icon'],
                                    pop: h['pop'],
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '5 Günlük Tahmin',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    isLoading
                        ? Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: daily.length,
                            itemBuilder: (context, index) {
                              final day = daily[index];
                              final date = day['date'] as DateTime;
                              String dayLabel;
                              if (index == 0) {
                                dayLabel = 'Today';
                              } else if (index == 1) {
                                dayLabel = 'Tomorrow';
                              } else {
                                dayLabel = '${[
                                  'Monday',
                                  'Tuesday',
                                  'Wednesday',
                                  'Thursday',
                                  'Friday',
                                  'Saturday',
                                  'Sunday'
                                ][date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
                              }
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                color: Colors.grey[850],
                                child: ListTile(
                                  leading: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Image.network(
                                      'https://openweathermap.org/img/wn/${day['icon']}@2x.png',
                                      width: 40,
                                      height: 40,
                                    ),
                                  ),
                                  title: Text(
                                    dayLabel,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${day['description']}',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  trailing: Text(
                                    '${day['temp_max']}°/${day['temp_min']}°',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DailyDetailPage(day: day),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getBackgroundEffect(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('rain')) {
      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueGrey[900]!,
                  Colors.blueGrey[700]!,
                  Colors.blue[800]!,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned.fill(child: RainEffect()),
        ],
      );
    } else if (desc.contains('clear')) {
      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.yellow[200]!, Colors.orange[300]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(top: -150, left: -150, child: SunEffect()),
        ],
      );
    } else if (desc.contains('cloud')) {
      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey[900]!, Colors.blueGrey[700]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          AnimatedClouds(),
        ],
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[200]!, Colors.blue[400]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }
  }

  Future<bool> _handleLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }
}

class _WeatherInfo extends StatelessWidget {
  final IconData icon;
  final String value;
  const _WeatherInfo({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: icon == Icons.water_drop
              ? AnimatedOpacity(
                  opacity: 1,
                  duration: Duration(seconds: 1),
                  child: Icon(
                    Icons.water_drop,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                )
              : Icon(icon, color: Colors.blueGrey, size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HourlyWeatherCard extends StatelessWidget {
  final String hour;
  final int temp;
  final String description;
  final String icon;
  final int pop;

  const _HourlyWeatherCard({
    required this.hour,
    required this.temp,
    required this.description,
    required this.icon,
    required this.pop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hour,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Image.network(
            'https://openweathermap.org/img/wn/$icon@2x.png',
            width: 40,
            height: 40,
          ),
          const SizedBox(height: 8),
          Text(
            '$temp°',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (pop > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.umbrella, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$pop%',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class DailyDetailPage extends StatelessWidget {
  final Map<String, dynamic> day;
  const DailyDetailPage({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final List details = day['details'] ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(''),
        backgroundColor: const Color.fromARGB(0, 255, 0, 0),
      ),
      body: ListView.builder(
        itemCount: details.length,
        itemBuilder: (context, i) {
          final item = details[i];
          final date = item['date'] as DateTime;
          return Card(
            color: Colors.grey[850],
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Image.network(
                'https://openweathermap.org/img/wn/${item['icon']}@2x.png',
                width: 32,
                height: 32,
              ),
              title: Text(
                '${date.hour.toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${item['description']}',
                style: TextStyle(color: Colors.white70),
              ),
              trailing: Text(
                '${item['temp_max'].round()}°/${item['temp_min'].round()}°',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AnimatedClouds extends StatefulWidget {
  const AnimatedClouds({super.key});

  @override
  State<AnimatedClouds> createState() => _AnimatedCloudsState();
}

class _AnimatedCloudsState extends State<AnimatedClouds>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final width = MediaQuery.of(context).size.width;
        return Stack(
          children: [
            Positioned(
              top: 80,
              left: width * _controller.value - 100,
              child: Icon(
                Icons.cloud,
                size: 100,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            Positioned(
              top: 140,
              left: width * (1 - _controller.value) - 60,
              child: Icon(
                Icons.cloud,
                size: 60,
                color: Colors.white.withOpacity(0.18),
              ),
            ),
          ],
        );
      },
    );
  }
}
