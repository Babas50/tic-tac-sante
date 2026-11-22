import 'package:material_ui/material_ui.dart';

import '../core/store.dart';
import 'history_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  final AppStore store;
  const HomeShell({super.key, required this.store});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int index = 0;

  void goToday() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(store: widget.store),
      LibraryScreen(store: widget.store),
      HistoryScreen(store: widget.store),
      SettingsScreen(store: widget.store),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: _BottomNav(
        index: index,
        onTap: (i) => setState(() => index = i),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

/// Barre de navigation maison : les libellés réduisent au lieu d'être coupés.
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  static const items = [
    _NavItem(Icons.today_rounded, 'Aujourd\'hui'),
    _NavItem(Icons.medication_rounded, 'Médicaments'),
    _NavItem(Icons.history_rounded, 'Historique'),
    _NavItem(Icons.settings_rounded, 'Réglages'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: items[i].label,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 72),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: i == index ? brand : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(items[i].icon,
                                size: 30, color: i == index ? Colors.white : ink),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              items[i].label,
                              style: TextStyle(
                                fontSize: 16,
                                color: ink,
                                fontWeight: i == index ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
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
