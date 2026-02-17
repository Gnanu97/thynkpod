import 'package:flutter/material.dart';
import 'devices_overlay.dart';
import '../../files/files_screen.dart';
import 'menu_overlay.dart'; // ADD this line
class BottomNavigationWidget extends StatefulWidget {
  const BottomNavigationWidget({Key? key}) : super(key: key);

  @override
  State<BottomNavigationWidget> createState() => _BottomNavigationWidgetState();
}

class _BottomNavigationWidgetState extends State<BottomNavigationWidget> {
  int _selectedIndex = 0;
  int _hoveredIndex = -1;

  void _showDevicesOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return DevicesOverlay();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.8,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
    );
  }

  void _navigateToFiles() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FilesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 20, left: 20, right: 20),
      child: Container(
        width: 185,
        height: 64,
        decoration: ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavButton(Icons.menu, 0),
            _buildNavButton(Icons.bluetooth, 1),
            _buildNavButton(Icons.copy_outlined, 2),
          ],
        ),
      ),
    );
  }

  void _showMenuOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MenuOverlay();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(-1, 0), // Slide from left
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
    );
  }
  Widget _buildNavButton(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    bool isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = -1),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hoveredIndex = index),
        onTapUp: (_) => setState(() => _hoveredIndex = -1),
        onTapCancel: () => setState(() => _hoveredIndex = -1),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 0:
              print('Menu tapped - Opening menu overlay');
              _showMenuOverlay(); // ✅ Actually call the menu overlay function
              break;
            case 1:
              print('Bluetooth tapped - Opening devices overlay');
              _showDevicesOverlay();
              break;
            case 2:
              print('Files tapped - Navigating to files screen');
              _navigateToFiles(); // Navigate to full files screen
              break;
          }
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 40,
          height: 40,
          transform: Matrix4.identity()..scale(isHovered ? 1.1 : 1.0),
          decoration: ShapeDecoration(
            color: isSelected
                ? Colors.white
                : isHovered
                ? Color(0xFFE8E8E8)
                : Color(0xFFD9D9D9),
            shape: OvalBorder(),
            shadows: isHovered ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ] : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}