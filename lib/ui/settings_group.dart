import 'package:flutter/material.dart';
import '../localization.dart';
import 'glass.dart';

/// Shared spacing, text, and icon alignment for every Settings row.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.title,
    required this.icon,
    required this.children,
    super.key,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(context, title),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          margin: EdgeInsets.zero,
          child: ListTileTheme(
            data: ListTileThemeData(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              horizontalTitleGap: 12,
              minLeadingWidth: 40,
              titleTextStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              subtitleTextStyle: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 68, endIndent: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {super.key});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
  );
}

class SettingsItem extends StatelessWidget {
  const SettingsItem({
    required this.title,
    required this.icon,
    this.description,
    this.control,
    this.onTap,
    this.enabled = true,
    super.key,
  });
  final String title;
  final IconData icon;
  final String? description;
  final Widget? control;
  final VoidCallback? onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled,
    leading: SettingsIcon(icon),
    title: Text(tr(context, title)),
    subtitle:
        control ??
        (description == null ? null : Text(tr(context, description!))),
    trailing: onTap == null
        ? null
        : const Icon(Icons.chevron_right_rounded, size: 22),
    onTap: enabled ? onTap : null,
  );
}
