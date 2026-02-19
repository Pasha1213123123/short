import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;

    final currentThemeMode = ref.watch(themeModeProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.brightness_6, color: colorScheme.primary),
            title: const Text("Theme"),
            subtitle: Text(
              _getThemeName(currentThemeMode),
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            ),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<ThemeMode>(
                value: currentThemeMode,
                dropdownColor: colorScheme.surface,
                icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text("System"),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text("Light"),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text("Dark"),
                  ),
                ],
                onChanged: (ThemeMode? newMode) {
                  if (newMode != null) {
                    ref.read(themeModeProvider.notifier).setTheme(newMode);
                  }
                },
              ),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("Autoplay"),
            subtitle: Text(
              "Start videos automatically",
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            ),
            value: true,
            activeThumbColor: colorScheme.primary,
            onChanged: (val) {},
          ),
          SwitchListTile(
            title: const Text("Haptic Feedback"),
            value: true,
            activeThumbColor: colorScheme.primary,
            onChanged: (val) {},
          ),
          const Divider(),
          ListTile(
            title: const Text("App Version"),
            trailing: Text(
              "1.0.0",
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return "Follow System";
      case ThemeMode.light:
        return "Light Theme";
      case ThemeMode.dark:
        return "Dark Theme";
    }
  }
}
