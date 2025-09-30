import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that renders markdown content for chat messages with proper styling
class MarkdownMessage extends StatelessWidget {
  final String content;
  final Color textColor;
  final bool fromUser;

  const MarkdownMessage({
    super.key,
    required this.content,
    required this.textColor,
    this.fromUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MarkdownBody(
      data: content,
      selectable: true,
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      },
      styleSheet: MarkdownStyleSheet(
        // Basic text styling
        p: TextStyle(
          color: textColor,
          fontSize: 14,
          height: 1.4,
        ),
        
        // Headers
        h1: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        h2: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        h3: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        h4: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        h5: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        h6: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        
        // Links
        a: TextStyle(
          color: fromUser 
            ? textColor.withOpacity(0.8) 
            : theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        
        // Code styling
        code: TextStyle(
          backgroundColor: fromUser 
            ? textColor.withOpacity(0.1)
            : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          color: textColor,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        
        // Code blocks
        codeblockDecoration: BoxDecoration(
          color: fromUser 
            ? textColor.withOpacity(0.1)
            : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: textColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        
        // Lists
        listBullet: TextStyle(
          color: textColor,
          fontSize: 14,
        ),
        
        // Emphasis
        em: TextStyle(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
        strong: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        
        // Blockquotes
        blockquote: TextStyle(
          color: textColor.withOpacity(0.8),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: textColor.withOpacity(0.3),
              width: 4,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        
        // Tables
        tableHead: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        tableBody: TextStyle(
          color: textColor,
        ),
        tableBorder: TableBorder.all(
          color: textColor.withOpacity(0.2),
          width: 1,
        ),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.all(8),
        
        // Horizontal rules
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: textColor.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}