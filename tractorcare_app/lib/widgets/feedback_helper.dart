// lib/widgets/feedback_helper.dart

import 'package:flutter/material.dart';
import '../config/colors.dart';

/// Centralized feedback helper for consistent user messages
class FeedbackHelper {
  /// Show success message
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: onAction != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// Show error message
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: onAction != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// Show warning message
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.warning,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show info message
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.info,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show loading dialog
  static void showLoading(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hide loading dialog
  static void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Format error message to be user-friendly
  static String formatErrorMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';
    
    final errorStr = error.toString().toLowerCase();
    
    // Network errors
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'Request timed out. The server is taking too long to respond. Please try again.';
    }
    if (errorStr.contains('connection') || errorStr.contains('network') || errorStr.contains('failed to fetch')) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }
    if (errorStr.contains('socketexception') || errorStr.contains('connection refused')) {
      return 'Cannot connect to server. Please check your internet connection.';
    }
    
    // Authentication errors
    if (errorStr.contains('401') || errorStr.contains('unauthorized') || errorStr.contains('authentication')) {
      return 'Authentication failed. Please login again.';
    }
    if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return 'You do not have permission to perform this action.';
    }
    
    // Server errors
    if (errorStr.contains('500') || errorStr.contains('internal server error')) {
      return 'Server error occurred. Please try again later.';
    }
    if (errorStr.contains('502') || errorStr.contains('bad gateway')) {
      return 'Server is temporarily unavailable. Please try again in a moment.';
    }
    if (errorStr.contains('503') || errorStr.contains('service unavailable')) {
      return 'Service is temporarily unavailable. Please try again later.';
    }
    
    // Validation errors
    if (errorStr.contains('400') || errorStr.contains('bad request')) {
      return 'Invalid request. Please check your input and try again.';
    }
    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'Resource not found. It may have been deleted or moved.';
    }
    if (errorStr.contains('422') || errorStr.contains('unprocessable')) {
      return 'Invalid data provided. Please check your input.';
    }
    
    // Specific error messages
    if (errorStr.contains('invalid email') || errorStr.contains('email')) {
      return 'Invalid email address. Please check and try again.';
    }
    if (errorStr.contains('invalid password') || errorStr.contains('password')) {
      return 'Invalid password. Please check and try again.';
    }
    if (errorStr.contains('already exists') || errorStr.contains('duplicate')) {
      return 'This item already exists. Please use a different value.';
    }
    if (errorStr.contains('permission denied') || errorStr.contains('microphone')) {
      return 'Microphone permission denied. Please enable it in settings.';
    }
    
    // Extract meaningful message from exception
    final message = error.toString();
    if (message.contains('Exception: ')) {
      return message.split('Exception: ').last.trim();
    }
    if (message.contains('Error: ')) {
      return message.split('Error: ').last.trim();
    }
    
    // Default fallback
    return 'An error occurred: ${message.length > 100 ? message.substring(0, 100) + "..." : message}';
  }
}

