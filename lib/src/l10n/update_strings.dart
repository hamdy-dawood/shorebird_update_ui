import 'dart:ui';

/// All user-visible texts. Use [UpdateStrings.en], [UpdateStrings.ar] or
/// build your own.
class UpdateStrings {
  const UpdateStrings({
    required this.updatingTitle,
    required this.updatingSubtitle,
    required this.readyTitle,
    required this.restartMessage,
    required this.reopenMessage,
    required this.step1,
    required this.step2,
    required this.restartNow,
    required this.restartingIn,
    required this.later,
    required this.errorTitle,
    required this.errorMessage,
    required this.close,
  });

  final String updatingTitle;
  final String updatingSubtitle;
  final String readyTitle;

  /// Android message.
  final String restartMessage;

  /// iOS message (also Android fallback if the restart fails).
  final String reopenMessage;
  final String step1;
  final String step2;
  final String restartNow;

  /// Template containing `{seconds}`, e.g. "Restarting in {seconds}...".
  final String restartingIn;
  final String later;
  final String errorTitle;
  final String errorMessage;
  final String close;

  static const UpdateStrings en = UpdateStrings(
    updatingTitle: 'Updating the app...',
    updatingSubtitle: 'Please keep the app open',
    readyTitle: 'Update ready!',
    restartMessage: 'The app needs to restart to apply the update',
    reopenMessage:
        'Please close the app completely and reopen it to use the latest version',
    step1: 'Close the app completely from the app switcher',
    step2: 'Open it again',
    restartNow: 'Restart now',
    restartingIn: 'Restarting in {seconds}...',
    later: 'Later',
    errorTitle: 'Update failed',
    errorMessage: 'We could not download the update. Please try again later.',
    close: 'Close',
  );

  static const UpdateStrings ar = UpdateStrings(
    updatingTitle: 'جاريٍ تحديث التطبيق...',
    updatingSubtitle: 'من فضلك أبقِ التطبيق مفتوحًا',
    readyTitle: 'التحديث جاهز!',
    restartMessage: 'يحتاج التطبيق إلى إعادة التشغيل لتطبيق التحديث',
    reopenMessage:
        'من فضلك أغلق التطبيق بالكامل ثم افتحه مرة أخرى لاستخدام أحدث نسخة',
    step1: 'أغلق التطبيق بالكامل من قائمة التطبيقات الأخيرة',
    step2: 'افتحه مرة أخرى',
    restartNow: 'إعادة التشغيل الآن',
    restartingIn: 'إعادة التشغيل خلال {seconds}...',
    later: 'لاحقًا',
    errorTitle: 'فشل التحديث',
    errorMessage: 'تعذر تنزيل التحديث. حاول مرة أخرى لاحقًا.',
    close: 'إغلاق',
  );

  /// Picks Arabic for `ar`, English otherwise.
  static UpdateStrings forLocale(Locale? locale) =>
      locale?.languageCode == 'ar' ? ar : en;
}
