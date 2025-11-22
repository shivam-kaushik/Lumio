import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../theme/app_theme.dart';
import '../../core/services/home_detection_service.dart';
import '../../core/services/places_service.dart';
import '../../core/utils/reminder_context_status.dart';
import '../../core/services/weather_service.dart';
import '../../data/models/saved_location.dart';
import '../widgets/location_reminder_dialog.dart';
import 'add_reminder_screen.dart';

/// Interactive map view showing location-based reminders with geofences
class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  MapType _mapType = MapType.normal;
  final HomeDetectionService _homeService = HomeDetectionService();
  final PlacesService _placesService = PlacesService();
  final WeatherService _weatherService = WeatherService();
  Map<String, List<Reminder>> _locationReminders = {};
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  List<PlacePrediction> _searchResults = [];
  bool _isSearching = false;
  LatLng? _selectedLocation;
  Marker? _selectedLocationMarker;

  // Weather state
  Map<String, dynamic>? _weather; // Raw weather JSON
  String? _weatherConditionText; // e.g., Rain, Cloudy
  IconData? _weatherIcon;
  double? _weatherTempC;

  // Map initialization state
  bool _mapInitialized = false;
  bool _mapLoadError = false;
  DateTime? _mapLoadStartTime;
  bool _tilesLoaded = false; // Track if map tiles are actually visible

  @override
  void initState() {
    super.initState();
    debugPrint('🗺️ MapViewScreen: initState called');
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    debugPrint('🗺️ MapViewScreen: _initializeMap started');
    try {
      await _updateCurrentLocation();
      debugPrint('🗺️ MapViewScreen: Location updated');
      await _loadLocationReminders();
      debugPrint('🗺️ MapViewScreen: Location reminders loaded: ${_locationReminders.length} groups');
      await _updateMapMarkers();
      await _updateWeather();
      debugPrint('🗺️ MapViewScreen: Map markers updated: ${_markers.length} markers, ${_circles.length} circles');
      await _logMapDiagnostics('initialize-complete');
    } catch (e, stackTrace) {
      debugPrint('❌ MapViewScreen: Error in _initializeMap: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Force map tiles to refresh by briefly switching map type
  Future<void> _forceMapRefresh() async {
    if (_mapController == null) return;
    try {
      debugPrint('🗺️ MapViewScreen: Forcing map tiles refresh by toggling map type');
      setState(() => _mapType = MapType.none);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _mapType = MapType.normal);
      unawaited(_logMapDiagnostics('forceMapRefresh'));
    } catch (e) {
      debugPrint('⚠️ MapViewScreen: Failed to force map refresh: $e');
    }
  }

  Future<void> _logMapDiagnostics(String label) async {
    try {
      debugPrint(
        '🧭 MapDiagnostics[$label]: mapInitialized=$_mapInitialized, '
        'tilesLoaded=$_tilesLoaded, mapLoadError=$_mapLoadError, '
        'mapType=$_mapType, markers=${_markers.length}, circles=${_circles.length}, '
        'currentPosition=$_currentPosition, mapLoadStart=$_mapLoadStartTime',
      );

      if (_mapController == null) {
        debugPrint('🧭 MapDiagnostics[$label]: mapController is null');
        return;
      }

      final zoom = await _mapController!.getZoomLevel();
      final visibleRegion = await _mapController!.getVisibleRegion();
      debugPrint(
        '🧭 MapDiagnostics[$label]: controller ok, zoom=${zoom.toStringAsFixed(2)}, '
        'visibleRegion NE(${visibleRegion.northeast.latitude.toStringAsFixed(5)}, '
        '${visibleRegion.northeast.longitude.toStringAsFixed(5)}) '
        'SW(${visibleRegion.southwest.latitude.toStringAsFixed(5)}, '
        '${visibleRegion.southwest.longitude.toStringAsFixed(5)})',
      );
    } catch (e) {
      debugPrint('⚠️ MapDiagnostics[$label]: Failed to gather diagnostics: $e');
    }
  }

  Future<void> _updateCurrentLocation() async {
    debugPrint('📍 MapViewScreen: _updateCurrentLocation started');
    try {
      final hasPermission = await Geolocator.checkPermission();
      debugPrint('📍 MapViewScreen: Location permission: $hasPermission');
      
      if (hasPermission == LocationPermission.whileInUse ||
          hasPermission == LocationPermission.always) {
        debugPrint('📍 MapViewScreen: Getting current position...');
        final position = await Geolocator.getCurrentPosition();
        debugPrint('📍 MapViewScreen: Got position: lat=${position.latitude}, lng=${position.longitude}');
        
        setState(() {
          _currentPosition = position;
        });

        // Move camera to user location
        if (_mapController != null && _currentPosition != null) {
          debugPrint('📍 MapViewScreen: Moving camera to user location');
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
            ),
          );
        } else {
          debugPrint('⚠️ MapViewScreen: Map controller is null, cannot move camera');
        }
      } else {
        debugPrint('⚠️ MapViewScreen: Location permission not granted');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ MapViewScreen: Error getting location: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadLocationReminders() async {
    debugPrint('📋 MapViewScreen: _loadLocationReminders started');
    try {
      final provider = context.read<ReminderProvider>();
      final allReminders = provider.reminders;
      debugPrint('📋 MapViewScreen: Total reminders: ${allReminders.length}');
      
      final reminders = allReminders
          .where((r) => r.enabled &&
              (r.geofenceId != null || r.geofenceLat != null))
          .toList();
      
      debugPrint('📋 MapViewScreen: Location-based reminders: ${reminders.length}');

      final grouped = <String, List<Reminder>>{};
      for (var reminder in reminders) {
        String locationKey;
        if (reminder.geofenceId == 'home') {
          locationKey = 'Home';
          debugPrint('📋 MapViewScreen: Found home reminder: ${reminder.text}');
        } else if (reminder.geofenceLat != null && reminder.geofenceLng != null) {
          locationKey = 'Custom Location';
          debugPrint('📋 MapViewScreen: Found custom location reminder: ${reminder.text} at (${reminder.geofenceLat}, ${reminder.geofenceLng})');
        } else {
          locationKey = 'Unknown';
        }
        grouped.putIfAbsent(locationKey, () => []).add(reminder);
      }

      debugPrint('📋 MapViewScreen: Grouped reminders: ${grouped.keys.toList()}');
      setState(() {
        _locationReminders = grouped;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ MapViewScreen: Error loading location reminders: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _updateWeather() async {
    if (_currentPosition == null) return;
    try {
      final data = await _weatherService.fetchCurrentWeather(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );
      if (data == null) return;

      // Open-Meteo response format:
      // { "current": { "weather_code": 61, "temperature_2m": 15.5, "precipitation": 0.0 } }
      final current = data['current'] as Map<String, dynamic>?;
      if (current == null) return;

      // Temperature in Celsius
      final tempC = current['temperature_2m'] as num?;
      final temp = tempC?.toDouble();

      // Weather code (WMO codes: 0=Clear, 1-3=Cloudy, 45-48=Fog, 51-67=Rain/Drizzle, 
      // 71-77=Snow, 80-82=Rain showers, 95-99=Thunderstorms)
      final weatherCode = current['weather_code'] as int?;

      // Map WMO weather code → icon + label
      IconData icon = Icons.thermostat_auto_rounded;
      String label = 'Weather';
      
      if (weatherCode != null) {
        if (weatherCode == 0) {
          icon = Icons.wb_sunny_rounded;
          label = 'Clear';
        } else if (weatherCode >= 1 && weatherCode <= 3) {
          icon = Icons.cloud_rounded;
          label = 'Cloudy';
        } else if (weatherCode >= 45 && weatherCode <= 48) {
          icon = Icons.blur_on;
          label = 'Foggy';
        } else if (weatherCode >= 51 && weatherCode <= 67) {
          icon = Icons.umbrella_rounded;
          label = 'Rain';
        } else if (weatherCode >= 71 && weatherCode <= 77) {
          icon = Icons.ac_unit_rounded;
          label = 'Snow';
        } else if (weatherCode >= 80 && weatherCode <= 82) {
          icon = Icons.umbrella_rounded;
          label = 'Rain';
        } else if (weatherCode >= 95 && weatherCode <= 99) {
          icon = Icons.flash_on_rounded;
          label = 'Storm';
        } else {
          icon = Icons.cloud_rounded;
          label = 'Cloudy';
        }
      }

      setState(() {
        _weather = data;
        _weatherConditionText = label;
        _weatherIcon = icon;
        _weatherTempC = temp;
      });
    } catch (e) {
      debugPrint('⚠️ MapViewScreen: Weather fetch error: $e');
    }
  }

  Future<void> _updateMapMarkers() async {
    debugPrint('📍 MapViewScreen: _updateMapMarkers started');
    final markers = <Marker>{};
    final circles = <Circle>{};

    // Add user location marker
    if (_currentPosition != null) {
      debugPrint('📍 MapViewScreen: Adding user location marker');
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'You are here',
            snippet: 'Your current location',
          ),
        ),
      );
    } else {
      debugPrint('⚠️ MapViewScreen: No current position available for user marker');
    }

    // Add home location if available
    try {
      debugPrint('🏠 MapViewScreen: Checking for home location...');
      final homeLocation = await _homeService.getHomeLocation();
      if (homeLocation != null) {
        debugPrint('🏠 MapViewScreen: Home location found: lat=${homeLocation.latitude}, lng=${homeLocation.longitude}, radius=${homeLocation.radius}');
        final homeReminders = _locationReminders['Home'] ?? [];
        debugPrint('🏠 MapViewScreen: Home has ${homeReminders.length} reminders');
        
               // Build detailed info for home with reminders
               final homeInfoSnippet = homeReminders.isEmpty
                   ? 'No reminders'
                   : homeReminders.take(3).map((r) => r.text).join('\n• ') +
                     (homeReminders.length > 3 ? '\n+ ${homeReminders.length - 3} more' : '');
               
               markers.add(
                 Marker(
                   markerId: const MarkerId('home'),
                   position: LatLng(homeLocation.latitude, homeLocation.longitude),
                   icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                   infoWindow: InfoWindow(
                     title: '🏠 Home (${homeReminders.length} reminder${homeReminders.length != 1 ? 's' : ''})',
                     snippet: homeInfoSnippet,
                   ),
                 ),
               );

        circles.add(
          Circle(
            circleId: const CircleId('home_geofence'),
            center: LatLng(homeLocation.latitude, homeLocation.longitude),
            radius: homeLocation.radius,
            fillColor: AppTheme.primaryColor.withOpacity(0.2),
            strokeColor: AppTheme.primaryColor,
            strokeWidth: 2,
          ),
        );
        debugPrint('🏠 MapViewScreen: Added home marker and geofence circle');
      } else {
        debugPrint('ℹ️ MapViewScreen: No home location configured');
      }
    } catch (e) {
      debugPrint('❌ MapViewScreen: Error getting home location: $e');
    }

    // Add markers for other location-based reminders
    try {
      debugPrint('📍 MapViewScreen: Checking for custom location reminders...');
      final provider = context.read<ReminderProvider>();
      int customIndex = 0;
      for (var reminder in provider.reminders) {
        if (reminder.enabled &&
            reminder.geofenceLat != null &&
            reminder.geofenceLng != null &&
            reminder.geofenceId != 'home') {
          customIndex++;
          debugPrint('📍 MapViewScreen: Adding custom location marker $customIndex: ${reminder.text} at (${reminder.geofenceLat}, ${reminder.geofenceLng})');
          
          // Build detailed info snippet
          final triggerTypes = <String>[];
          if (reminder.onArriveContext) triggerTypes.add('On Arrive');
          if (reminder.onLeaveContext) triggerTypes.add('On Leave');
          final triggerText = triggerTypes.isNotEmpty 
              ? triggerTypes.join(' • ')
              : 'Location';
          
          markers.add(
            Marker(
              markerId: MarkerId('reminder_${reminder.id}'),
              position: LatLng(
                reminder.geofenceLat!,
                reminder.geofenceLng!,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(
                title: reminder.text,
                snippet: '📍 ${reminder.geofenceId ?? "Custom Location"}\n'
                    'Radius: ${(reminder.geofenceRadius ?? 100).toStringAsFixed(0)}m • $triggerText\n'
                    '${reminder.enabled ? "✅ Active" : "⏸️ Paused"}',
              ),
            ),
          );

          circles.add(
            Circle(
              circleId: CircleId('geofence_$customIndex'),
              center: LatLng(
                reminder.geofenceLat!,
                reminder.geofenceLng!,
              ),
              radius: reminder.geofenceRadius ?? 100.0,
              fillColor: AppTheme.accentColor.withOpacity(0.2),
              strokeColor: AppTheme.accentColor,
              strokeWidth: 2,
            ),
          );
        }
      }
      debugPrint('📍 MapViewScreen: Added $customIndex custom location markers');
    } catch (e) {
      debugPrint('❌ MapViewScreen: Error adding custom location markers: $e');
    }

    debugPrint('📍 MapViewScreen: Total markers: ${markers.length}, Total circles: ${circles.length}');
    setState(() {
      _markers = markers;
      _circles = circles;
    });
    debugPrint('📍 MapViewScreen: State updated with markers and circles');
  }

  /// Handle map tap to select location
  Future<void> _handleMapTap(LatLng position) async {
    debugPrint('📍 MapViewScreen: Handling map tap at ${position.latitude}, ${position.longitude}');
    
    setState(() {
      _selectedLocation = position;
      // Update selected location marker
      _selectedLocationMarker = Marker(
        markerId: const MarkerId('selected_location'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(
          title: 'Selected Location',
          snippet: 'Tap to add reminder',
        ),
      );
      // Update markers to include selected location
      _markers = {..._markers, _selectedLocationMarker!};
    });

    // Get location name from reverse geocoding
    String? locationName;
    try {
      locationName = await _placesService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      debugPrint('📍 MapViewScreen: Reverse geocoded name: $locationName');
    } catch (e) {
      debugPrint('⚠️ MapViewScreen: Error reverse geocoding: $e');
    }

      // Show dialog to create reminder or select location
      // Check if we're being navigated to for location selection
      final isForLocationSelection = ModalRoute.of(context)?.settings.arguments as bool? ?? false;
      
      if (mounted) {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => LocationReminderDialog(
            latitude: position.latitude,
            longitude: position.longitude,
            suggestedName: locationName,
            forLocationSelectionOnly: isForLocationSelection,
          ),
        );

      if (result != null && mounted) {
        // Check if navigated from reminder dialog (no reminder text means it's for location selection)
        if (result['reminderText'] == null || (result['reminderText'] as String).isEmpty) {
          // Return location data to caller (reminder dialog)
          Navigator.of(context).pop({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'radius': result['radius'] ?? 100.0,
            'locationName': result['locationName'],
          });
        } else {
          // Create new reminder from map
          await _createLocationReminder(result);
        }
      } else {
        // Remove selected marker if user cancelled
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'selected_location');
          _selectedLocation = null;
          _selectedLocationMarker = null;
        });
      }
    }
  }

  /// Create reminder from location selection
  Future<void> _createLocationReminder(Map<String, dynamic> data) async {
    debugPrint('📍 MapViewScreen: Creating location reminder');
    debugPrint('   Location: ${data['locationName']}');
    debugPrint('   Coordinates: ${data['latitude']}, ${data['longitude']}');
    debugPrint('   Radius: ${data['radius']}m');

    final provider = context.read<ReminderProvider>();
    
    // Create reminder with location
    final reminder = Reminder(
      text: data['reminderText'] as String,
      geofenceLat: data['latitude'] as double,
      geofenceLng: data['longitude'] as double,
      geofenceRadius: data['radius'] as double,
      geofenceId: data['locationName'] as String, // Store location name as geofenceId
      onArriveContext: data['onArrive'] as bool,
      onLeaveContext: data['onLeave'] as bool,
      enabled: true,
    );

    // Create reminder via provider
    final reminderId = await provider.createReminder(reminder);
    
    if (reminderId != null && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Reminder created for ${data['locationName']}'),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );

      // Reload reminders and update map
      await _loadLocationReminders();
      await _updateMapMarkers();

      // Remove selected marker
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'selected_location');
        _selectedLocation = null;
        _selectedLocationMarker = null;
      });

      debugPrint('✅ MapViewScreen: Location reminder created successfully');
    }
  }

  /// Handle location search
  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    debugPrint('🔍 MapViewScreen: Searching for "$query"');
    final results = await _placesService.searchPlaces(query);
    
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  /// Handle place selection from search
  Future<void> _selectPlace(PlacePrediction prediction) async {
    debugPrint('📍 MapViewScreen: Place selected: ${prediction.description}');
    
    // Get place details with coordinates
    final details = await _placesService.getPlaceDetails(prediction.placeId);
    
    if (details != null) {
      // Move camera to place
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(details.latitude, details.longitude),
            16.0,
          ),
        );
      }

      // Show dialog to create reminder OR return location if navigated from reminder dialog
      final isForLocationSelection = ModalRoute.of(context)?.settings.arguments as bool? ?? false;
      
      if (mounted) {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => LocationReminderDialog(
            latitude: details.latitude,
            longitude: details.longitude,
            suggestedName: details.name,
            forLocationSelectionOnly: isForLocationSelection,
          ),
        );

        if (result != null && mounted) {
          // Check if this is for reminder creation or location selection
          if (result['reminderText'] == null || (result['reminderText'] as String).isEmpty) {
            // Return location data to caller
            Navigator.of(context).pop({
              'latitude': details.latitude,
              'longitude': details.longitude,
              'radius': result['radius'] ?? 100.0,
              'locationName': result['locationName'] ?? details.name,
            });
          } else {
            // Create reminder
            await _createLocationReminder(result);
          }
        }
      }

      // Clear search
      setState(() {
        _searchController.clear();
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold - MainNavigator provides it
    return Column(
      children: [
        // Custom AppBar with search
        Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: AppTheme.spacingLG,
                right: AppTheme.spacingMD,
                bottom: AppTheme.spacingMD,
              ),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Back button when selecting a location for a reminder
                  if ((ModalRoute.of(context)?.settings.arguments as bool? ?? false))
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                    ),
                  Expanded(
                    child: Text(
                      (ModalRoute.of(context)?.settings.arguments as bool? ?? false)
                          ? 'Select Location'
                          : 'Map View',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.my_location_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      if (_mapController != null && _currentPosition != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            15.0,
                          ),
                        );
                      }
                    },
                    tooltip: 'Center on my location',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () async {
                      await _forceMapRefresh(); // refresh tiles first
                      await _updateCurrentLocation();
                      await _loadLocationReminders();
                      await _updateMapMarkers();
                      await _updateWeather();
                    },
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingSM,
              ),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for a place...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchResults = [];
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          borderSide: BorderSide(color: AppTheme.borderColor),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMD,
                          vertical: AppTheme.spacingSM,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.length >= 2) {
                          _searchLocations(value);
                        } else {
                          setState(() {
                            _searchResults = [];
                          });
                        }
                      },
                    ),
                  ),
                  // Search results dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      margin: const EdgeInsets.only(top: AppTheme.spacingXS),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: AppTheme.getElevationShadow(2),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.place_rounded,
                                color: AppTheme.primaryColor,
                              ),
                              title: Text(
                                place.mainText ?? place.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: place.secondaryText != null
                                  ? Text(
                                      place.secondaryText!,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              onTap: () => _selectPlace(place),
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
        // Map view
        Expanded(
          child: Consumer<ReminderProvider>(
            builder: (context, provider, child) {
              debugPrint('🗺️ MapViewScreen: Consumer builder called');
              debugPrint('   Current position: $_currentPosition');
              debugPrint('   Provider reminders: ${provider.reminders.length}');
              
              if (_currentPosition == null) {
                debugPrint('⚠️ MapViewScreen: No position yet, showing loading indicator');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppTheme.spacingMD),
                      Text(
                        'Loading map...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      TextButton(
                        onPressed: () {
                          debugPrint('🗺️ MapViewScreen: Retry button pressed');
                          _updateCurrentLocation();
                        },
                        child: const Text('Retry Location'),
                      ),
                    ],
                  ),
                );
              }

              debugPrint('🗺️ MapViewScreen: Building GoogleMap widget');
              debugPrint('   Current position: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
              debugPrint('   Markers count: ${_markers.length}');
              debugPrint('   Circles count: ${_circles.length}');
              debugPrint('   Map initialized: $_mapInitialized');
              
              // Start timeout timer if not already started
              if (_mapLoadStartTime == null) {
                _mapLoadStartTime = DateTime.now();
                // Set a timeout to detect if map never loads (10 seconds)
                Future.delayed(const Duration(seconds: 10), () {
                  if (mounted && !_mapInitialized) {
                    debugPrint('⚠️ MapViewScreen: Map failed to initialize after 10 seconds');
                    setState(() {
                      _mapLoadError = true;
                    });
                    unawaited(_logMapDiagnostics('timeout-no-init'));
                  }
                });
              }
              
              final isForLocationSelection = ModalRoute.of(context)?.settings.arguments as bool? ?? false;
              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 14.0,
                    ),
                    markers: _markers,
                    circles: _circles,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    mapType: _mapType,
                    onMapCreated: (GoogleMapController controller) async {
                      debugPrint('🗺️ MapViewScreen: onMapCreated called - map is ready!');
                      _mapController = controller;
                      setState(() {
                        _mapInitialized = true;
                        _mapLoadError = false;
                      });
                      unawaited(_logMapDiagnostics('onMapCreated'));
                      debugPrint('🗺️ MapViewScreen: Map controller set, updating markers...');
                      // Update markers after map is ready
                      await _updateMapMarkers();
                      debugPrint('🗺️ MapViewScreen: Markers updated after map creation');
                      // Force a tiles refresh once after creation (helps if tiles are stuck)
                      await _forceMapRefresh();
                      
                      // Check if tiles loaded after a delay (API key validation)
                      Future.delayed(const Duration(seconds: 3), () {
                        if (mounted) {
                          // If map is initialized but we haven't detected tiles, likely API key issue
                          if (_mapInitialized && !_tilesLoaded) {
                            debugPrint('⚠️ MapViewScreen: Map initialized but tiles not detected - possible API key issue');
                            setState(() {
                              _mapLoadError = true;
                            });
                            unawaited(_logMapDiagnostics('tiles-missing-detected'));
                          }
                        }
                      });
                    },
                    onCameraIdle: () {
                      debugPrint('🗺️ MapViewScreen: Camera idle');
                      // Mark as initialized when camera becomes idle (map is fully loaded)
                      if (!_mapInitialized) {
                        setState(() {
                          _mapInitialized = true;
                          _mapLoadError = false;
                        });
                      }
                      // Camera idle usually means tiles are loaded
                      if (!_tilesLoaded) {
                        setState(() {
                          _tilesLoaded = true;
                          _mapLoadError = false;
                        });
                        debugPrint('✅ MapViewScreen: Map tiles detected');
                        unawaited(_logMapDiagnostics('camera-idle'));
                      }
                    },
                    onTap: (LatLng position) {
                      debugPrint('🗺️ MapViewScreen: Map tapped at: ${position.latitude}, ${position.longitude}');
                      _handleMapTap(position);
                    },
                  ),
                  // Loading overlay if map hasn't initialized yet
                  if (!_mapInitialized && !_mapLoadError)
                    Positioned.fill(
                      child: Container(
                        color: AppTheme.backgroundColor,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: AppTheme.spacingMD),
                              Text(
                                'Loading map...',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Error overlay if map fails to load or tiles don't appear
                  if (_mapLoadError || (!_tilesLoaded && _mapInitialized && _mapLoadStartTime != null && DateTime.now().difference(_mapLoadStartTime!).inSeconds > 5))
                    Positioned(
                      top: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                          boxShadow: AppTheme.getElevationShadow(2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: AppTheme.spacingSM),
                                Expanded(
                                  child: Text(
                                    'Google Maps API Key Issue',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _mapLoadError = false;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingXS),
                            Text(
                              'Map tiles are not loading. This usually means:\n\n'
                              '1. API key is missing or invalid\n'
                              '   → Add GOOGLE_MAPS_API_KEY to android/local.properties\n'
                              '   → Or set it as an environment variable\n\n'
                              '2. API key restrictions are too strict\n'
                              '   → Check Google Cloud Console\n'
                              '   → Ensure Maps SDK for Android is enabled\n'
                              '   → Verify package name: com.lumio.app\n\n'
                              '3. Billing not enabled\n'
                              '   → Enable billing in Google Cloud Console\n\n'
                              'After fixing, run: flutter clean && flutter run',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _mapLoadError = false;
                                        _tilesLoaded = false;
                                        _mapInitialized = false;
                                        _mapLoadStartTime = null;
                                      });
                                    unawaited(_logMapDiagnostics('retry-button'));
                                      _initializeMap();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppTheme.warningColor,
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingSM),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      // Force refresh tiles
                                      await _forceMapRefresh();
                                      unawaited(_logMapDiagnostics('manual-refresh-tiles'));
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white),
                                    ),
                                    child: const Text('Refresh Tiles'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Instruction banner when in location selection mode
                  if (isForLocationSelection && _selectedLocation == null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        color: AppTheme.primaryColor.withOpacity(0.95),
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacingSM),
                              Expanded(
                                child: Text(
                                  'Tap the map or search to select a location',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Confirm bar when selecting a location for a reminder
                  if (isForLocationSelection && _selectedLocation != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 220,
                      child: SafeArea(
                        top: false,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                          color: Theme.of(context).cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingMD),
                            child: Row(
                              children: [
                                const Icon(Icons.place_rounded, color: AppTheme.primaryColor),
                                const SizedBox(width: AppTheme.spacingSM),
                                Expanded(
                                  child: Text(
                                    'Use selected location',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    final name = await _placesService.reverseGeocode(
                                      _selectedLocation!.latitude,
                                      _selectedLocation!.longitude,
                                    );
                                    final result = await showDialog<Map<String, dynamic>>(
                                      context: context,
                                      builder: (context) => LocationReminderDialog(
                                        latitude: _selectedLocation!.latitude,
                                        longitude: _selectedLocation!.longitude,
                                        suggestedName: name,
                                        forLocationSelectionOnly: true,
                                      ),
                                    );
                                    if (result != null && mounted) {
                                      Navigator.of(context).pop(result);
                                    }
                                  },
                                  child: const Text('Use'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Floating Action Button: Use Current Location (only in selection mode)
                  if (isForLocationSelection && _currentPosition != null)
                    Positioned(
                      right: 16,
                      bottom: _selectedLocation != null ? 280 : 100,
                      child: SafeArea(
                        top: false,
                        child: FloatingActionButton.extended(
                          onPressed: () async {
                            // Use current location
                            final position = LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            );
                            
                            // Move camera to current location
                            if (_mapController != null) {
                              await _mapController!.animateCamera(
                                CameraUpdate.newLatLngZoom(position, 15.0),
                              );
                            }
                            
                            // Set as selected location
                            setState(() {
                              _selectedLocation = position;
                              _selectedLocationMarker = Marker(
                                markerId: const MarkerId('selected_location'),
                                position: position,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueRed,
                                ),
                                infoWindow: const InfoWindow(
                                  title: 'Selected Location',
                                  snippet: 'Tap "Use" to confirm',
                                ),
                              );
                              _markers = {..._markers, _selectedLocationMarker!};
                            });
                            
                            // Get location name
                            final name = await _placesService.reverseGeocode(
                              position.latitude,
                              position.longitude,
                            );
                            
                            // Show dialog to configure location details
                            if (mounted) {
                              final result = await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (context) => LocationReminderDialog(
                                  latitude: position.latitude,
                                  longitude: position.longitude,
                                  suggestedName: name ?? 'Current Location',
                                  forLocationSelectionOnly: true,
                                ),
                              );
                              
                              if (result != null && mounted) {
                                Navigator.of(context).pop({
                                  'latitude': position.latitude,
                                  'longitude': position.longitude,
                                  'radius': result['radius'] ?? 100.0,
                                  'locationName': result['locationName'],
                                });
                              } else {
                                // Remove selected marker if cancelled
                                setState(() {
                                  _markers.removeWhere((m) => m.markerId.value == 'selected_location');
                                  _selectedLocation = null;
                                  _selectedLocationMarker = null;
                                });
                              }
                            }
                          },
                          backgroundColor: AppTheme.primaryColor,
                          icon: const Icon(Icons.my_location_rounded, color: Colors.white),
                          label: Text(
                            'Use My Location',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Location reminders list overlay (respect bottom safe area)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: false,
                      child: _buildLocationRemindersList(context, provider),
                    ),
                  ),

                  // Weather badge (top-right)
                  if (_weatherIcon != null || _weatherTempC != null || _weatherConditionText != null)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: SafeArea(
                        bottom: false,
                        child: Material(
                          elevation: 4,
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMD,
                              vertical: AppTheme.spacingSM,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _weatherIcon ?? Icons.thermostat_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: AppTheme.spacingXS),
                                if (_weatherTempC != null)
                                  Text(
                                    '${_weatherTempC!.toStringAsFixed(0)}°C',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                if (_weatherTempC != null && _weatherConditionText != null)
                                  const SizedBox(width: AppTheme.spacingXS),
                                if (_weatherConditionText != null)
                                  Text(
                                    _weatherConditionText!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRemindersList(
    BuildContext context,
    ReminderProvider provider,
  ) {
    if (_locationReminders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        margin: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: AppTheme.getElevationShadow(2),
        ),
        child: Text(
          'No location-based reminders',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.getElevationShadow(2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Text(
                    'Location-Based Reminders',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              itemCount: _locationReminders.length,
              itemBuilder: (context, index) {
                final entry = _locationReminders.entries.elementAt(index);
                final locationName = entry.key;
                final reminders = entry.value;

                return FutureBuilder<List<ReminderContextStatus>>(
                  future: ReminderStatusCalculator.calculateStatuses(
                    reminders,
                    currentPosition: _currentPosition,
                  ),
                  builder: (context, snapshot) {
                    final readyCount = snapshot.hasData
                        ? snapshot.data!.where((s) => s.isReady).length
                        : 0;

                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: Center(
                            child: Text(
                              locationName == 'Home' ? '🏠' : '📍',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        title: Text(
                          locationName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${reminders.length} reminder${reminders.length != 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        trailing: readyCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingSM,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                                ),
                                child: Text(
                                  '$readyCount ready',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.successColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () async {
                        // Move camera to location
                        if (locationName == 'Home') {
                          final homeLocation = await _homeService.getHomeLocation();
                          if (homeLocation != null && _mapController != null) {
                            _mapController!.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(
                                  homeLocation.latitude,
                                  homeLocation.longitude,
                                ),
                                16.0,
                              ),
                            );
                          }
                        } else if (reminders.isNotEmpty &&
                            reminders.first.geofenceLat != null &&
                            reminders.first.geofenceLng != null &&
                            _mapController != null) {
                          _mapController!.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(
                                reminders.first.geofenceLat!,
                                reminders.first.geofenceLng!,
                              ),
                              16.0,
                            ),
                          );
                        }
                      },
                    ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

