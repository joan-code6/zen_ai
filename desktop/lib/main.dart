import 'package:flutter/material.dart';

void main() {
  runApp(const ZenDesktopApp());
}

class ZenDesktopApp extends StatelessWidget {
  const ZenDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zen AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const ZenHomePage(),
    );
  }
}

class ZenHomePage extends StatefulWidget {
  const ZenHomePage({super.key});

  @override
  State<ZenHomePage> createState() => _ZenHomePageState();
}

class _ZenHomePageState extends State<ZenHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: const [
          // Workspace fills the available area and will not be reflowed
          // when the sidebar animates because the sidebar overlays it.
          Positioned.fill(child: ZenWorkspace()),
          Align(alignment: Alignment.centerLeft, child: ZenSidebar()),
        ],
      ),
    );
  }
}

class ZenSidebar extends StatefulWidget {
  const ZenSidebar({super.key});

  @override
  State<ZenSidebar> createState() => _ZenSidebarState();
}

class _ZenSidebarState extends State<ZenSidebar> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final items = <_SidebarItemData>[
      const _SidebarItemData(
        icon: Icons.chat_bubble_outline,
        label: 'New Chat',
      ),
      const _SidebarItemData(
        icon: Icons.search,
        label: 'Search',
      ),
      const _SidebarItemData(
        icon: Icons.note_outlined,
        label: 'Notes',
      ),
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: _hovering ? 200 : 80,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    Flexible(
                      fit: FlexFit.loose,
                      child: _SidebarRevealText(
                        expanded: _hovering,
                        maxWidth: 120,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Text(
                            'Zen',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            for (final item in items) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: _SidebarButton(
                  data: item,
                  expanded: _hovering,
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha((0.1 * 255).round()),
                    ),
                    child: Icon(
                      Icons.account_circle_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: _SidebarRevealText(
                      expanded: _hovering,
                      maxWidth: 180,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Text(
                          'Bennet{name}',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                        ),
                      ),
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

class _SidebarItemData {
  final IconData icon;
  final String label;

  const _SidebarItemData({required this.icon, required this.label});
}

class _SidebarButton extends StatelessWidget {
  final _SidebarItemData data;
  final bool expanded;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.data,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: colorScheme.primary.withAlpha((0.08 * 255).round()),
                ),
                child: Icon(
                  data.icon,
                  color: colorScheme.primary,
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: _SidebarRevealText(
                  expanded: expanded,
                  maxWidth: 160,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Text(
                      data.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarRevealText extends StatelessWidget {
  final bool expanded;
  final Widget child;
  final double maxWidth;

  const _SidebarRevealText({
    required this.expanded,
    required this.child,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: expanded ? 1 : 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, child) {
        final clamped = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: SizedBox(
            width: maxWidth * clamped,
            child: child,
          ),
        );
      },
    );
  }
}

class ZenWorkspace extends StatelessWidget {
  const ZenWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            'Hallo Bennet{name}, wie geht es dir?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
          const SizedBox(height: 40),
          const ZenChatComposer(),
          const SizedBox(height: 48),
          // Wrap(
          //   spacing: 18,
          //   runSpacing: 18,
          //   alignment: WrapAlignment.center,
          //   children: const [
          //     _IdeaTile(
          //       title: 'Memory & Notes',
          //       description:
          //           'Capture preferences, events, and reminders that Zen can recall instantly.',
          //     ),
          //     _IdeaTile(
          //       title: 'Context-aware replies',
          //       description:
          //           'Zen blends your history with Gemini intelligence for personal responses.',
          //     ),
          //     _IdeaTile(
          //       title: 'Modules & Integrations',
          //       description:
          //           'Plug in calendar, email, messaging, and more—everything stays in sync.',
          //     ),
          //   ],
          // ),
          const Spacer(),
        ],
      ),
    );
  }
}

class ZenChatComposer extends StatelessWidget {
  const ZenChatComposer({super.key});

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey.shade300;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white,
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _RoundActionButton(
                    icon: Icons.add,
                    tooltip: 'Upload a file',
                    onPressed: () {},
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Hallo, das ist ein Test …',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RoundActionButton(
                    icon: Icons.mic_none,
                    tooltip: 'Voice to text',
                    onPressed: () {},
                  ),
                  const SizedBox(width: 12),
                  _RoundActionButton(
                    icon: Icons.send_rounded,
                    tooltip: 'Send message',
                    onPressed: () {},
                    backgroundColor: colorScheme.primary,
                    borderColor: Colors.transparent,
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  const _RoundActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBackground = Colors.grey.shade100;
    final defaultBorder = Colors.grey.shade300;
    final defaultIcon = Colors.grey.shade700;
    const size = 44.0;
    const iconSize = 24.0;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: size / 2 + 6,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? defaultBackground,
            border: Border.all(
              color: borderColor ?? defaultBorder,
            ),
          ),
          child: Icon(
            icon,
            color: iconColor ?? defaultIcon,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

