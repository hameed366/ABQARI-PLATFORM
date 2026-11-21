import 'package:material_ui/material_ui.dart';

/// Describes a capability.
///
/// Without [onTap] it is deliberately not tappable and shows no arrow: it must
/// not look like a control until the feature behind it exists. With [onTap]
/// it opens that feature and shows an arrow that follows the reading direction.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// A short label shown at the end of a card that cannot be opened yet
  /// (e.g. "coming soon"), so it is not mistaken for a broken button.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: onTap != null
            ? Icon(Icons.arrow_forward, color: scheme.primary)
            : badge == null
                ? null
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                    ),
                  ),
      ),
    );
  }
}
