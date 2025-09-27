import 'package:flutter/material.dart';

import '../models/chat.dart';

class ZenSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int>? onItemSelected;
  final List<Chat> chats;
  final ValueChanged<String>? onChatSelected;
  final VoidCallback? onNewChat;
  final VoidCallback? onUserPressed;
  final ValueChanged<String>? onChatRename;
  final ValueChanged<String>? onChatDelete;
  final Future<void> Function()? onRefreshChats;
  final bool isLoadingChats;
  final bool isAuthenticated;
  final String userDisplayName;

  const ZenSidebar({
    super.key,
    this.selectedIndex = 0,
    this.onItemSelected,
    this.chats = const [],
    this.onChatSelected,
    this.onNewChat,
    this.onUserPressed,
    this.onChatRename,
    this.onChatDelete,
    this.onRefreshChats,
    this.isLoadingChats = false,
    this.isAuthenticated = false,
    this.userDisplayName = 'Guest',
  });

  @override
  State<ZenSidebar> createState() => _ZenSidebarState();
}

class _ZenSidebarState extends State<ZenSidebar> {
  bool _hovering = false;
  bool _contextMenuOpen = false;

  Future<void> _showChatContextMenu(
    BuildContext context,
    Offset globalPosition,
    Chat chat,
  ) async {
    if (widget.onChatRename == null && widget.onChatDelete == null) {
      return;
    }

    final overlay = Overlay.of(context);
    final renderBox = overlay.context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _contextMenuOpen = true;
    try {
      final result = await showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromPoints(globalPosition, globalPosition),
          Offset.zero & renderBox.size,
        ),
        items: [
          if (widget.onChatRename != null)
            const PopupMenuItem<String>(
              value: 'rename',
              child: Text('Rename'),
            ),
          if (widget.onChatDelete != null)
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text('Delete'),
            ),
        ],
      );

      switch (result) {
        case 'rename':
          widget.onChatRename?.call(chat.id);
          break;
        case 'delete':
          widget.onChatDelete?.call(chat.id);
          break;
      }
    } finally {
      _contextMenuOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final sidebarColor = colorScheme.surface;
    final shadowColor = theme.shadowColor.withOpacity(isDark ? 0.4 : 0.12);
    final dividerColor = colorScheme.outlineVariant.withOpacity(
      isDark ? 0.25 : 0.18,
    );

    final items = <_SidebarItemData>[
      const _SidebarItemData(
        icon: Icons.chat_bubble_outline,
        label: 'New Chat',
      ),
      const _SidebarItemData(icon: Icons.search, label: 'Search'),
      const _SidebarItemData(icon: Icons.note_outlined, label: 'Notes'),
    ];
    // keep a fixed per-item height to avoid vertical shifts on hover/expand
    final double itemHeight = 56.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) {
        if (!_contextMenuOpen) {
          setState(() => _hovering = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: _hovering ? 200 : 80,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: sidebarColor,
          border: Border(right: BorderSide(color: dividerColor)),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 24,
              offset: const Offset(4, 0),
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
                        maxWidth: 100,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Text(
                            'Zen',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
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
            // keep the buttons block a fixed height so hover/width animation
            // doesn't change vertical positions of items below (e.g., chat icons)
            SizedBox(
              height: items.length * (itemHeight + 12.0),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    SizedBox(
                      height: itemHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: _SidebarButton(
                          key: ValueKey('sidebar_item_$i'),
                          data: items[i],
                          expanded: _hovering,
                          selected: widget.selectedIndex == i,
                          onTap: () {
                            if (i == 0) {
                              widget.onNewChat?.call();
                            }
                            widget.onItemSelected?.call(i);
                          },
                        ),
                      ),
                    ),
                    if (i < items.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),

            // quick list of chats
            if (widget.chats.isNotEmpty || widget.isLoadingChats) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SidebarRevealText(
                    expanded: _hovering,
                    maxWidth: 160,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              'Chats',
                              style: Theme.of(context).textTheme.titleSmall,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.isLoadingChats)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (widget.onRefreshChats != null)
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              tooltip: 'Refresh chats',
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                widget.onRefreshChats?.call();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // scrollable chat list with a bottom fade so the user/avatar area
              // remains visible and long lists gracefully fade out
              Flexible(
                child: Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88.0),
                      itemCount: widget.chats.length,
                      itemBuilder: (ctx, i) {
                        final c = widget.chats[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onSecondaryTapDown: (details) =>
                                _showChatContextMenu(
                                  context,
                                  details.globalPosition,
                                  c,
                                ),
                            onLongPress: () {
                              if (widget.onChatRename == null &&
                                  widget.onChatDelete == null) {
                                return;
                              }
                              final box = context.findRenderObject();
                              if (box is RenderBox) {
                                final position = box.localToGlobal(
                                  box.size.center(Offset.zero),
                                );
                                _showChatContextMenu(
                                  context,
                                  position,
                                  c,
                                );
                              }
                            },
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => widget.onChatSelected?.call(c.id),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 6.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary.withAlpha(20),
                                        ),
                                        child: Icon(
                                          Icons.chat_bubble,
                                          size: 18,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          c.title ?? 'Untitled chat',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // bottom fade overlay
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                sidebarColor.withOpacity(0),
                                sidebarColor,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 16.0,
              ),
              child: GestureDetector(
                onTap: widget.onUserPressed,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: widget.onUserPressed == null
                        ? Colors.transparent
                        : _hovering
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.06)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha((0.1 * 255).round()),
                        ),
                        child: Icon(
                          widget.isAuthenticated
                              ? Icons.account_circle_outlined
                              : Icons.login,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.loose,
                        child: _SidebarRevealText(
                          expanded: _hovering,
                          maxWidth: 140,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12.0),
                            child: Text(
                              widget.isAuthenticated
                                  ? widget.userDisplayName
                                  : 'Sign in',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        ),
                      ),
                      if (_hovering)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.expand_more,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: bg,
                ),
                child: Icon(data.icon, color: colorScheme.primary),
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
          child: SizedBox(width: maxWidth * clamped, child: child),
        );
      },
    );
  }
}
