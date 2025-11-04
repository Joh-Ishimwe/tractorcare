// lib/widgets/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  bool _isOnline = true; // This would be managed by a connection provider in real app

  void _showMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Menu items
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: Color(0xFF4CAF50)),
                    title: const Text('My Account'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  
                  ListTile(
                    leading: Icon(
                      _isOnline ? Icons.wifi : Icons.wifi_off,
                      color: _isOnline ? Color(0xFF4CAF50) : Colors.grey,
                    ),
                    title: Text(_isOnline ? 'Online' : 'Offline'),
                    trailing: Switch(
                      value: _isOnline,
                      activeColor: const Color(0xFF4CAF50),
                      onChanged: (bool value) {
                        setModalState(() {
                          _isOnline = value;
                        });
                        setState(() {
                          _isOnline = value;
                        });
                        // Here you would implement actual online/offline logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isOnline ? 'Switched to Online mode' : 'Switched to Offline mode'),
                            backgroundColor: _isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const Divider(),
                  
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _showLogoutDialog();
                    },
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: widget.showBackButton 
        ? IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
            onPressed: () => Navigator.pop(context),
          )
        : null,
      title: Row(
        children: [
          // TractorCare Logo
          Image.asset(
            'assets/images/logo.png',
            width: 42,
            height: 42,
            fit: BoxFit.contain,
          ),
          // const SizedBox(width: 8),
          // const Text(
          //   'Care',
          //   style: TextStyle(
          //     fontSize: 20,
          //     fontWeight: FontWeight.bold,
          //     color: Color(0xFF333333),
          //   ),
          // ),
        ],
      ),
      centerTitle: false,
      actions: [
        // Menu Button
        IconButton(
          onPressed: _showMenuBottomSheet,
          icon: const Icon(
            Icons.menu,
            color: Color(0xFF333333),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: const Color(0xFFE0E0E0),
          height: 1,
        ),
      ),
    );
  }
}