/// Profile menu button widget for AppBar
/// Shows user profile picture with dropdown menu

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:decision_agent/app/auth_provider.dart';
import 'package:decision_agent/utils/error_handling.dart';

class ProfileMenuButton extends ConsumerWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showMenu(context, ref, null),
          );
        }

        return PopupMenuButton<String>(
          offset: const Offset(0, 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildProfileAvatar(
              profile.pictureUrl,
              profile.name ?? profile.email,
            ),
          ),
          onSelected: (value) => _handleMenuSelection(context, ref, value),
          itemBuilder:
              (context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 20),
                      const SizedBox(width: 12),
                      const Text('Profile'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings, size: 20),
                      const SizedBox(width: 12),
                      const Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      const Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        );
      },
      loading:
          () => const SizedBox(
            width: 40,
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      error:
          (error, stack) => IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showMenu(context, ref, null),
          ),
    );
  }

  Widget _buildProfileAvatar(String? pictureUrl, String displayName) {
    if (pictureUrl != null && pictureUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(pictureUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback handled by child widget
        },
        child: pictureUrl.isNotEmpty ? null : _buildInitialsAvatar(displayName),
      );
    } else {
      return _buildInitialsAvatar(displayName);
    }
  }

  Widget _buildInitialsAvatar(String displayName) {
    final initials = _getInitials(displayName);
    final color = _getColorFromString(displayName);

    return CircleAvatar(
      radius: 18,
      backgroundColor: color,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.length == 1 && parts[0].contains('@')) {
      return parts[0][0].toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  Color _getColorFromString(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = hash.abs() % 360;
    return HSVColor.fromAHSV(1.0, hue.toDouble(), 0.6, 0.8).toColor();
  }

  void _handleMenuSelection(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'profile':
        context.go('/profile');
        break;
      case 'settings':
        context.go('/settings');
        break;
      case 'logout':
        _handleLogout(context, ref);
        break;
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final authService = ref.read(googleAuthServiceProvider);
      await authService.signOut();

      // Invalidate auth status to trigger redirect
      ref.invalidate(authStatusProvider);
      ref.invalidate(userProfileProvider);

      if (context.mounted) {
        context.go('/onboarding');
      }
    } catch (e) {
      if (context.mounted) {
        final errorMessage = ErrorHandler.getUserFriendlyMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMenu(BuildContext context, WidgetRef ref, UserProfile? profile) {
    // Fallback menu if profile not loaded
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        80,
        16,
        0,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person, size: 20),
              SizedBox(width: 12),
              Text('Profile'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 20),
              SizedBox(width: 12),
              Text('Settings'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Logout', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleMenuSelection(context, ref, value);
      }
    });
  }
}
