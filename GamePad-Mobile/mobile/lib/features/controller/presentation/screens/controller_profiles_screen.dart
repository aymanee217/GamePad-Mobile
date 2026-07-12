import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/service/layout_manager.dart';
import '../../../../core/model/button_layout_item.dart';
import '../../providers/connection_provider.dart';
import '../../providers/layout_provider.dart';
import 'controller_screen.dart';

class ControllerProfilesScreen extends ConsumerStatefulWidget {
  const ControllerProfilesScreen({super.key});

  @override
  ConsumerState<ControllerProfilesScreen> createState() => _ControllerProfilesScreenState();
}

class _ControllerProfilesScreenState extends ConsumerState<ControllerProfilesScreen> {
  List<LayoutProfile> _profiles = [];
  bool _loading = true;
  String _savedHost = AppConfig.defaultHost;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(AppConfig.prefDiscoveredHost) ?? AppConfig.defaultHost;
    setState(() => _savedHost = host);
  }

  Future<void> _loadProfiles() async {
    final profiles = await LayoutManager.loadAll();
    if (profiles.isEmpty) {
      final def = LayoutManager.defaultLayout();
      await LayoutManager.saveAll([def]);
      setState(() {
        _profiles = [def];
        _loading = false;
      });
    } else {
      setState(() {
        _profiles = profiles;
        _loading = false;
      });
    }
  }

  Future<void> _createProfile() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Controller'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'e.g. Racing, FPS, Fighting...',
            labelText: 'Controller name',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await LayoutManager.createProfile(result);
      await _loadProfiles();
    }
  }

  Future<void> _renameProfile(int index) async {
    final nameController = TextEditingController(text: _profiles[index].name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Controller'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) Navigator.of(ctx).pop(name);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await LayoutManager.renameProfile(index, result);
      await _loadProfiles();
    }
  }

  Future<void> _deleteProfile(int index) async {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the only controller')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Controller?'),
        content: Text('Delete "${_profiles[index].name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await LayoutManager.deleteProfile(index);
      await _loadProfiles();
    }
  }

  void _showConnectionSettings() {
    showDialog(
      context: context,
      builder: (ctx) => _ConnectionSettingsDialog(
        initialHost: _savedHost,
        onSaved: (host) => setState(() => _savedHost = host),
      ),
    );
  }

  void _selectProfile(int index) async {
    await LayoutManager.setActiveIndex(index);
    final profile = _profiles[index];

    if (!mounted) return;

    ref.read(layoutProvider.notifier).setProfile(profile);
    ref.read(connectionProvider.notifier).tryAutoReconnect();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ControllerScreen(
          profile: profile,
          profileIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Controllers'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Connection Settings',
            onPressed: _showConnectionSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gamepad, size: 80, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No controllers yet', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(height: 8),
                      Text('Create your first controller', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Connection status bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _savedHost,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _showConnectionSettings,
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Settings', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    // Profile list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        itemCount: _profiles.length,
                        itemBuilder: (context, index) {
                          final profile = _profiles[index];
                          return _ProfileCard(
                            profile: profile,
                            onTap: () => _selectProfile(index),
                            onRename: () => _renameProfile(index),
                            onDelete: () => _deleteProfile(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProfile,
        icon: const Icon(Icons.add),
        label: const Text('New Controller'),
      ),
    );
  }
}

class _ConnectionSettingsDialog extends ConsumerStatefulWidget {
  final String initialHost;
  final ValueChanged<String> onSaved;

  const _ConnectionSettingsDialog({required this.initialHost, required this.onSaved});

  @override
  ConsumerState<_ConnectionSettingsDialog> createState() => _ConnectionSettingsDialogState();
}

class _ConnectionSettingsDialogState extends ConsumerState<_ConnectionSettingsDialog> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  bool _saving = false;
  bool _saved = false;
  ConnectionPhase? _resultPhase;
  late int _playerId;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.initialHost);
    _portController = TextEditingController(text: AppConfig.defaultPort.toString());
    _loadPlayerId();
  }

  Future<void> _loadPlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _playerId = prefs.getInt(AppConfig.prefPlayerId) ?? 1);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _saveAndConnect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? AppConfig.defaultPort;
    if (ip.isEmpty) return;

    setState(() {
      _saving = true;
      _resultPhase = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefDiscoveredHost, ip);
    await prefs.setInt(AppConfig.prefDiscoveredPort, port);
    await prefs.setInt(AppConfig.prefPlayerId, _playerId);
    ref.read(connectionProvider.notifier).setHost(ip);
    ref.read(connectionProvider.notifier).clearUserDisconnected();
    ref.read(connectionProvider.notifier).setPlayerId(_playerId);
    widget.onSaved(ip);

    await ref.read(connectionProvider.notifier).connectToHost(ip, port: port);

    if (!mounted) return;
    final phase = ref.read(connectionProvider).phase;
    setState(() {
      _saving = false;
      _saved = true;
      _resultPhase = phase;
    });

    if (phase == ConnectionPhase.connected) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Connection Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'Server IP',
              hintText: 'e.g. 192.168.1.100',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Port',
              hintText: '42420',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Text('Player Number', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [1, 2, 3, 4].map((id) {
              final selected = _playerId == id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _playerId = id),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'P$id',
                      style: TextStyle(
                        color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PC server must be running for connection to work.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (_saved) ...[
            const SizedBox(height: 16),
            _buildStatusIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        if (_resultPhase == ConnectionPhase.failed)
          FilledButton(
            onPressed: _saveAndConnect,
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Retry'),
          )
        else
          FilledButton(
            onPressed: _saving ? null : _saveAndConnect,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save & Connect'),
          ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    final phase = _resultPhase;
    if (phase == null) return const SizedBox.shrink();

    Color color;
    IconData icon;
    String text;

    switch (phase) {
      case ConnectionPhase.connected:
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Connecté!';
        break;
      case ConnectionPhase.connecting:
        color = Colors.orange;
        icon = Icons.sync;
        text = 'Connexion en cours...';
        break;
      default:
        color = Colors.red;
        icon = Icons.error;
        text = 'Échoué - le serveur est-il en marche?';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final LayoutProfile profile;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonCount = profile.items.where((i) => i.controlId.type == ControlType.button).length;
    final joystickCount = profile.items.where((i) => i.controlId.type == ControlType.joystick).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.gamepad,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$buttonCount buttons, $joystickCount joysticks',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
