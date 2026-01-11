import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class DateFormatter {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (!_isInitialized) {
      await initializeDateFormatting('fr_FR', null);
      _isInitialized = true;
    }
  }

  static String formatDate(DateTime date, {String format = 'dd/MM/yyyy'}) {
    if (!_isInitialized) {
      initialize();
    }
    return DateFormat(format, 'fr_FR').format(date);
  }

  static String formatDateString(String dateString, {String format = 'dd/MM/yyyy'}) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return formatDate(date, format: format);
    } catch (e) {
      return dateString; // Return original string if parsing fails
    }
  }

  static String formatMonthYear(DateTime date) {
    if (!_isInitialized) {
      initialize();
    }
    return DateFormat('MMMM yyyy', 'fr_FR').format(date);
  }

  static String formatShortDate(DateTime date) {
    return formatDate(date, format: 'dd/MM');
  }

  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'Il y a $years an${years > 1 ? 's' : ''}';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a $months mois';
    } else if (difference.inDays >= 1) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours >= 1) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes >= 1) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}
