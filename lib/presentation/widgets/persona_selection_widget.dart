import 'package:flutter/material.dart';
import '../../core/services/persona_service.dart';

class PersonaSelectionWidget extends StatefulWidget {
  const PersonaSelectionWidget({super.key});

  @override
  State<PersonaSelectionWidget> createState() => _PersonaSelectionWidgetState();
}

class _PersonaSelectionWidgetState extends State<PersonaSelectionWidget> {
  final PersonaService _service = PersonaService();
  PersonaType _active = PersonaType.standard;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final active = await _service.getActivePersona();
    setState(() {
      _active = active;
      _isLoading = false;
    });
  }

  Future<void> _select(PersonaType type) async {
    setState(() => _active = type);
    await _service.setPersona(type);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "AI Coach Persona",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120, // Height for cards
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PersonaType.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final type = PersonaType.values[index];
              final isActive = type == _active;
              final name = _service.getDisplayName(type);
              
              // Simple descriptions
              String desc = "Standard";
              if (type == PersonaType.drillSergeant) desc = "Strict & Loud";
              if (type == PersonaType.sassyFriend) desc = "Fun & Sassy";
              if (type == PersonaType.wisePhilosopher) desc = "Deep & Stoic";
              if (type == PersonaType.hypeMan) desc = "High Energy";

              return GestureDetector(
                onTap: () => _select(type),
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? Colors.transparent : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name.split(' ').last, // Emoji
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name.replaceAll(RegExp(r'[^\w\s]'), '').trim(), // Text only
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive ? Colors.white70 : Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
