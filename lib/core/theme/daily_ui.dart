import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum DailyWindowClass { compact, medium, expanded }

DailyWindowClass dailyWindowClassFor(Size size) {
  return switch (size.shortestSide) {
    < 600 => DailyWindowClass.compact,
    < 840 => DailyWindowClass.medium,
    _ => DailyWindowClass.expanded,
  };
}

abstract final class DailyUi {
  static const primary = Color(0xff0a63d8);
  static const success = Color(0xff2aa65a);
  static const warning = Color(0xffe88b00);
  static const purple = Color(0xff6558d9);
  static const destructive = Color(0xffd93f3f);

  static bool get isDesktop {
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  static Color pageBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : const Color(0xfff5f5fa);
  }

  static Color groupedSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff1c1c1e)
        : Colors.white;
  }

  static Color elevatedSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff252528)
        : const Color(0xfff0f0f5);
  }

  static Color separator(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff343438)
        : const Color(0xffdfdfe5);
  }

  static Color secondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xffaaaab4)
        : const Color(0xff686873);
  }

  static Color tertiaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff808089)
        : const Color(0xff8a8a94);
  }
}

class DailyAdaptiveBody extends StatelessWidget {
  const DailyAdaptiveBody({
    required this.child,
    super.key,
    this.maxWidth = 720,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: DailyUi.isDesktop ? 28 : 18,
                vertical: DailyUi.isDesktop ? 24 : 14,
              ),
          child: child,
        ),
      ),
    );
  }
}

class DailyNavigationBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DailyNavigationBar({
    required this.title,
    super.key,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.backgroundColor,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: backgroundColor ?? DailyUi.pageBackground(context),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class DailyPageTitle extends StatelessWidget {
  const DailyPageTitle({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: DailyUi.secondaryText(context),
                    fontSize: 14,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 14), trailing!],
      ],
    );
  }
}

class DailySectionLabel extends StatelessWidget {
  const DailySectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 7),
      child: Text(
        label,
        style: TextStyle(
          color: DailyUi.secondaryText(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class DailyGroupedSection extends StatelessWidget {
  const DailyGroupedSection({
    required this.children,
    super.key,
    this.label,
    this.footer,
    this.margin,
  });

  final String? label;
  final List<Widget> children;
  final String? footer;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) DailySectionLabel(label!),
          Material(
            color: DailyUi.groupedSurface(context),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: DailyUi.separator(context).withValues(alpha: 0.72),
              ),
            ),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 54,
                      color: DailyUi.separator(context),
                    ),
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 8, 5, 0),
              child: Text(
                footer!,
                style: TextStyle(
                  color: DailyUi.secondaryText(context),
                  fontSize: 12,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DailySettingsIcon extends StatelessWidget {
  const DailySettingsIcon({
    required this.icon,
    super.key,
    this.color = DailyUi.primary,
    this.foregroundColor = Colors.white,
  });

  final IconData icon;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: foregroundColor, size: 18),
    );
  }
}

class DailySettingsRow extends StatelessWidget {
  const DailySettingsRow({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? DailyUi.destructive
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: onTap != null,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 57),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: enabled
                                ? foreground
                                : foreground.withValues(alpha: 0.42),
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: DailyUi.secondaryText(
                                context,
                              ).withValues(alpha: enabled ? 1 : 0.45),
                              fontSize: 12,
                              height: 1.3,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ] else if (onTap != null) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: DailyUi.tertiaryText(context),
                      size: 24,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DailyPrimaryButton extends StatelessWidget {
  const DailyPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.busy = false,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final content = busy
        ? const SizedBox.square(
            dimension: 21,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          );
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? DailyUi.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: (backgroundColor ?? DailyUi.primary)
              .withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: content,
      ),
    );
  }
}

class DailySecondaryButton extends StatelessWidget {
  const DailySecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        style: TextButton.styleFrom(foregroundColor: DailyUi.primary),
      ),
    );
  }
}

class DailyIconAction extends StatelessWidget {
  const DailyIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
    this.selected = false,
    this.selectedIcon,
    this.accentColor = DailyUi.primary,
    this.size = 40,
    this.borderless = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final IconData? selectedIcon;
  final Color accentColor;
  final double size;
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final actionSize = size - 4;
    final foreground = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: SizedBox.square(
          dimension: actionSize,
          child: IconButton(
            tooltip: tooltip,
            isSelected: selected,
            onPressed: onPressed,
            icon: Icon(icon, size: size <= 36 ? 18 : 20),
            selectedIcon: Icon(
              selectedIcon ?? icon,
              size: size <= 36 ? 18 : 20,
            ),
            style: IconButton.styleFrom(
              foregroundColor: enabled
                  ? foreground
                  : foreground.withValues(alpha: 0.36),
              backgroundColor: selected
                  ? accentColor
                  : borderless
                  ? Colors.transparent
                  : DailyUi.groupedSurface(context),
              disabledBackgroundColor: borderless
                  ? Colors.transparent
                  : DailyUi.groupedSurface(context).withValues(alpha: 0.58),
              minimumSize: Size.square(actionSize),
              maximumSize: Size.square(actionSize),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: borderless
                  ? const CircleBorder()
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(size <= 36 ? 8 : 9),
                      side: BorderSide(
                        color: selected
                            ? accentColor
                            : DailyUi.separator(
                                context,
                              ).withValues(alpha: 0.82),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class DailyInfoCallout extends StatelessWidget {
  const DailyInfoCallout({
    required this.text,
    super.key,
    this.title,
    this.icon = Icons.shield_outlined,
    this.color = DailyUi.primary,
  });

  final String text;
  final String? title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: dark ? 0.3 : 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: TextStyle(
                        color: dark
                            ? Color.lerp(Colors.white, color, 0.12)
                            : Color.lerp(Colors.black, color, 0.42),
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: dark
                          ? Color.lerp(Colors.white, color, 0.18)
                          : Color.lerp(Colors.black, color, 0.48),
                      fontSize: 13,
                      height: 1.4,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyOnboardingFrame extends StatelessWidget {
  const DailyOnboardingFrame({
    required this.step,
    required this.stepCount,
    required this.kicker,
    required this.title,
    required this.description,
    required this.content,
    required this.primaryLabel,
    required this.onPrimary,
    super.key,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryIcon,
    this.busy = false,
  });

  final int step;
  final int stepCount;
  final String kicker;
  final String title;
  final String description;
  final Widget content;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData? primaryIcon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DailyUi.pageBackground(context),
      child: SafeArea(
        child: DailyAdaptiveBody(
          maxWidth: 560,
          padding: EdgeInsets.fromLTRB(
            DailyUi.isDesktop ? 30 : 22,
            DailyUi.isDesktop ? 34 : 22,
            DailyUi.isDesktop ? 30 : 22,
            DailyUi.isDesktop ? 30 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DailyOnboardingProgress(current: step, total: stepCount),
              const SizedBox(height: 30),
              Text(
                kicker,
                style: const TextStyle(
                  color: DailyUi.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: DailyUi.isDesktop ? 36 : 32,
                  height: 1.14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                description,
                style: TextStyle(
                  color: DailyUi.secondaryText(context),
                  fontSize: 16,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: content),
              const SizedBox(height: 18),
              DailyPrimaryButton(
                label: primaryLabel,
                onPressed: onPrimary,
                icon: primaryIcon,
                busy: busy,
              ),
              if (secondaryLabel != null)
                DailySecondaryButton(
                  label: secondaryLabel!,
                  onPressed: onSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyOnboardingProgress extends StatelessWidget {
  const DailyOnboardingProgress({
    required this.current,
    required this.total,
    super.key,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final active = index <= current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 5,
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 7),
            decoration: BoxDecoration(
              color: active ? DailyUi.primary : DailyUi.separator(context),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }
}

class DailyFeatureCard extends StatelessWidget {
  const DailyFeatureCard({
    required this.icon,
    required this.title,
    super.key,
    this.description,
    this.color = DailyUi.primary,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DailyUi.groupedSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: DailyUi.separator(context).withValues(alpha: 0.75),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 3),
              Text(
                description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: DailyUi.secondaryText(context),
                  fontSize: 11,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DailySheetHandle extends StatelessWidget {
  const DailySheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 5,
        decoration: BoxDecoration(
          color: DailyUi.tertiaryText(context).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}
