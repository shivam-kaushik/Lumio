import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/reminder.dart';
import '../../core/services/places_service.dart';
import '../theme/app_theme.dart';

/// Dialog for creating a location-based reminder from map selection
/// Can also be used for location selection only (when reminderText is not required)
class LocationReminderDialog extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? suggestedName; // Place name from Google Maps
  final bool forLocationSelectionOnly; // If true, allows skipping reminder text

  const LocationReminderDialog({
    super.key,
    required this.latitude,
    required this.longitude,
    this.suggestedName,
    this.forLocationSelectionOnly = false,
  });

  @override
  State<LocationReminderDialog> createState() => _LocationReminderDialogState();
}

class _LocationReminderDialogState extends State<LocationReminderDialog> {
  final TextEditingController _reminderTextController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  double _radius = 100.0; // Default radius in meters
  bool _onArrive = true;
  bool _onLeave = false;

  @override
  void initState() {
    super.initState();
    // Use suggested name or get from reverse geocoding
    if (widget.suggestedName != null) {
      _locationNameController.text = widget.suggestedName!;
    } else {
      _loadLocationName();
    }
  }

  Future<void> _loadLocationName() async {
    final placesService = PlacesService();
    final name = await placesService.reverseGeocode(
      widget.latitude,
      widget.longitude,
    );
    if (name != null && mounted) {
      setState(() {
        _locationNameController.text = name;
      });
    }
  }

  @override
  void dispose() {
    _reminderTextController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  void _save() {
    final reminderText = _reminderTextController.text.trim();
    final locationName = _locationNameController.text.trim();

    // Allow returning without reminder text (for location selection only)
    if (locationName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
      return;
    }

    // Return location data (reminder text is optional - allows location selection from reminder dialog)
    Navigator.of(context).pop({
      'reminderText': reminderText.isEmpty ? null : reminderText,
      'locationName': locationName,
      'latitude': widget.latitude,
      'longitude': widget.longitude,
      'radius': _radius,
      'onArrive': _onArrive,
      'onLeave': _onLeave,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.forLocationSelectionOnly 
                              ? 'Confirm Location' 
                              : 'Add Location Reminder',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.forLocationSelectionOnly
                              ? 'Save this spot for easier access later'
                              : 'Set reminder for this location',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Coordinates display
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Location',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // Location Type Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTypeChip('Home', '🏠'),
                    _buildTypeChip('Work', '💼'),
                    _buildTypeChip('Grocery', '🛒'),
                    _buildTypeChip('Gym', '💪'),
                    _buildTypeChip('School', '📚'),
                    _buildTypeChip('Other', '📍'),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingMD),

              // Location name input
              TextField(
                controller: _locationNameController,
                decoration: InputDecoration(
                  labelText: 'Location Name',
                  hintText: 'e.g., Coffee Shop',
                  prefixIcon: const Icon(Icons.place_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: AppTheme.spacingMD),

              if (!widget.forLocationSelectionOnly) ...[
                  const SizedBox(height: AppTheme.spacingMD),
                  // Reminder text input (optional if for location selection only)
                  TextField(
                    controller: _reminderTextController,
                    decoration: InputDecoration(
                      labelText: 'Reminder Text *',
                      hintText: 'What should I remind you?',
                      prefixIcon: const Icon(Icons.note_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                    ),
                    maxLines: 2,
                  ),
              ],

              const SizedBox(height: AppTheme.spacingLG),

              // Trigger options
              Text(
                'When to trigger:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
               Row(
                children: [
                  Expanded(
                    child: _buildTriggerChip('On Arrive', _onArrive, (v) {
                         setState(() {
                           _onArrive = v;
                           if (v && !_onLeave) {} // Logic kept
                         });
                    }),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: _buildTriggerChip('On Leave', _onLeave, (v) {
                         setState(() {
                           _onLeave = v;
                           if (v && !_onArrive) {} // Logic kept
                         });
                    }),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // Radius selector
              Text(
                'Geofence Radius: ${_radius.toInt()}m',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              
              // Radius slider
              Slider(
                value: _radius,
                min: 50.0,
                max: 500.0,
                divisions: 18, // 50m increments
                label: '${_radius.toInt()}m',
                onChanged: (value) {
                  setState(() {
                    _radius = value;
                  });
                  HapticFeedback.selectionClick();
                },
                activeColor: AppTheme.primaryColor,
              ),
              
              // Radius presets
              Wrap(
                spacing: AppTheme.spacingSM,
                children: [50.0, 100.0, 200.0, 500.0].map((radius) {
                  final isSelected = (_radius - radius).abs() < 1.0;
                  final theme = Theme.of(context);
                  final isDark = theme.brightness == Brightness.dark;
                  return ChoiceChip(
                    label: Text('${radius.toInt()}m'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _radius = radius;
                        });
                        HapticFeedback.selectionClick();
                      }
                    },
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        ),
                      ),
                      child: Text(
                        widget.forLocationSelectionOnly
                            ? 'Use This Location'
                            : 'Create Reminder',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTypeChip(String label, String emoji) {
      final isSelected = _locationNameController.text == label;
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: ChoiceChip(
            label: Text('$emoji $label'),
            selected: isSelected,
            onSelected: (selected) {
                if (selected) {
                    setState(() {
                        if (label == 'Other') {
                            _locationNameController.clear();
                        } else {
                            _locationNameController.text = label;
                        }
                    });
                    HapticFeedback.selectionClick();
                }
            },
            selectedColor: AppTheme.primaryColor,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              ),
            ),
        ),
      );
  }

  Widget _buildTriggerChip(String label, bool isSelected, Function(bool) onSelected) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (v) {
                onSelected(v);
                HapticFeedback.selectionClick();
            },
            selectedColor: AppTheme.primaryColor,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              ),
            ),
      );
  }
}

