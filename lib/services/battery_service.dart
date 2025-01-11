// battery_service.dart

import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  final Battery _battery = Battery();

  /// قراءة نسبة البطارية وتحويلها للغة العربية
  Future<String> getBatteryPercentageInArabic() async {
    try {
      final batteryLevel = await _battery.batteryLevel;

      // تحويل الرقم إلى النص العربي
      String arabicNumber = batteryLevel.toString().replaceAllMapped(
          RegExp(r'[0-9]'),
          (match) => {
                '0': '٠',
                '1': '١',
                '2': '٢',
                '3': '٣',
                '4': '٤',
                '5': '٥',
                '6': '٦',
                '7': '٧',
                '8': '٨',
                '9': '٩',
              }[match.group(0)]!);

      return 'نسبة شحن البطارية: $arabicNumber٪';
    } catch (e) {
      return 'حدث خطأ في قراءة البطارية';
    }
  }

  /// قراءة نسبة البطارية كرقم
  Future<int> getBatteryPercentage() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      return -1; // رمز للخطأ
    }
  }
}
