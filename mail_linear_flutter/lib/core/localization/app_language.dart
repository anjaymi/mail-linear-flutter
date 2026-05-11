part of 'app_localizations.dart';

enum AppLanguage {
  zhHans('zh-Hans', '简体中文', Locale('zh', 'Hans')),
  zhHant('zh-Hant', '繁體中文', Locale('zh', 'Hant')),
  ja('ja', '日本語', Locale('ja')),
  en('en', 'English', Locale('en')),
  ko('ko', '한국어', Locale('ko'));

  const AppLanguage(this.code, this.nativeName, this.locale);

  final String code;
  final String nativeName;
  final Locale locale;

  static AppLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return AppLanguage.zhHans;
  }
}
