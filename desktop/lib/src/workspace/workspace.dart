import 'package:flutter/material.dart';

class ZenWorkspace extends StatelessWidget {
  final int selectedIndex;

  const ZenWorkspace({super.key, this.selectedIndex = 0});

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
