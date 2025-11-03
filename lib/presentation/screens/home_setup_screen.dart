import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/home_detection_service.dart';
import '../../data/models/saved_location.dart';
import 'package:uuid/uuid.dart';

/// Screen for setting up home location for context-aware reminders
class HomeSetupScreen extends StatefulWidget {
  const HomeSetupScreen({super.key});

  @override
  State<HomeSetupScreen> createState() => _HomeSetupScreenState();
}

class _HomeSetupScreenState extends State<HomeSetupScreen> {
  final _homeService = HomeDetectionService();
  bool _isLoading = true;
  bool _hasHomeLocation = false;
  SavedLocation? _homeLocation;
  String _detectionMode = 'none';

  @override
  void initState() {
    super.initState();
    _loadSetupStatus();
  }

  Future<void> _loadSetupStatus() async {
    setState(() => _isLoading = true);

    try {
      final status = await _homeService.getSetupStatus();

      setState(() {
        _hasHomeLocation = status['hasHomeLocation'] as bool;
        _homeLocation = status['homeLocation'] != null
            ? SavedLocation.fromMap(
                status['homeLocation'] as Map<String, dynamic>,)
            : null;
        _detectionMode = status['detectionMode'] as String;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading setup: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setHomeLocationManually() async {
    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final location = SavedLocation(
        id: const Uuid().v4(),
        name: 'Home',
        latitude: position.latitude,
        longitude: position.longitude,
        radius: 150.0,
      );

      await _homeService.setHomeLocation(location);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Home location set!')),
        );
      }

      await _loadSetupStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Future<void> _resetHomeData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Home Data?'),
        content: const Text(
          'This will remove your home location. You can set it up again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _homeService.resetHomeData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Home data reset')),
        );
      }
      await _loadSetupStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Setup'),
        actions: [
          if (_hasHomeLocation)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSetupStatus,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildLocationSection(),
                  const SizedBox(height: 24),
                  _buildDetectionModeInfo(),
                  const SizedBox(height: 32),
                  if (_hasHomeLocation)
                    Center(
                      child: TextButton.icon(
                        onPressed: _resetHomeData,
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text(
                          'Reset Home Data',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final isComplete = _hasHomeLocation;

    return Card(
      color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.info_outline,
                  color: isComplete ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isComplete ? 'Home Setup Complete' : 'Setup Required',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isComplete
                  ? 'Your home is configured. You can now use home-based reminders like "Remind me to take keys when leaving home".'
                  : 'Set up your home location to enable smart reminders that trigger when you leave or arrive home.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.home,
                  color: _hasHomeLocation ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Home Location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_homeLocation != null) ...[
              _buildInfoRow('Name', _homeLocation!.name),
              _buildInfoRow(
                'Coordinates',
                '${_homeLocation!.latitude.toStringAsFixed(4)}, ${_homeLocation!.longitude.toStringAsFixed(4)}',
              ),
              _buildInfoRow(
                'Radius',
                '${_homeLocation!.radius.toStringAsFixed(0)}m',
              ),
              const SizedBox(height: 8),
              Text(
                _detectionMode == 'automatic'
                    ? '🤖 Auto-detected based on your patterns'
                    : '📍 Manually set',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ] else ...[
              Text(
                'No home location set',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _setHomeLocationManually,
              icon: Icon(_hasHomeLocation ? Icons.edit : Icons.add_location),
              label: Text(_hasHomeLocation
                  ? 'Update Location'
                  : 'Set Current Location as Home',),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDetectionModeInfo() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'How It Works',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBulletPoint('🏠 Set your home location once'),
            _buildBulletPoint('🎯 App detects when you leave/arrive'),
            _buildBulletPoint('🔔 Triggers location-based reminders'),
            const SizedBox(height: 8),
            Text(
              'Example: "Remind me to take my keys when leaving home"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.blue.shade700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
