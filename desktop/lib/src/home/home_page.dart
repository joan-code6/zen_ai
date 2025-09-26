import 'package:flutter/material.dart';

import '../workspace/workspace.dart';
import '../sidebar/sidebar.dart';
import '../sidebar/notes_panel.dart';

class ZenHomePage extends StatefulWidget {
  const ZenHomePage({super.key});

  @override
  State<ZenHomePage> createState() => _ZenHomePageState();
}

class _ZenHomePageState extends State<ZenHomePage> {
  // 0 = New Chat, 1 = Search, 2 = Notes
  int _selectedIndex = 0;

  void _onSidebarItemSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar on the left
          ZenSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: _onSidebarItemSelected,
          ),

          // Main content area
          Expanded(
            child: Row(
              children: [
                // Center workspace
                Expanded(
                  child: ZenWorkspace(selectedIndex: _selectedIndex),
                ),

                // Notes panel on the right when Notes is selected
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: const SizedBox(
                    width: 360,
                    child: ZenNotesPanel(),
                  ),
                  crossFadeState: _selectedIndex == 2
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 260),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
