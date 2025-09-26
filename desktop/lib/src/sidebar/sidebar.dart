import 'package:flutter/material.dart';

class ZenSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int>? onItemSelected;

  const ZenSidebar({super.key, this.selectedIndex = 0, this.onItemSelected});

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
            for (var i = 0; i < items.length; i++)
              ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: _SidebarButton(
                    key: ValueKey('sidebar_item_$i'),
                    data: items[i],
                    expanded: _hovering,
                    selected: widget.selectedIndex == i,
                    onTap: () {
                      widget.onItemSelected?.call(i);
                    },
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
  final bool selected;
  final VoidCallback onTap;

  const _SidebarButton({
    super.key,
    required this.data,
    required this.expanded,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = selected
        ? colorScheme.primary.withAlpha((0.12 * 255).round())
        : colorScheme.primary.withAlpha((0.08 * 255).round());

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
                  color: bg,
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
