# Personal Finance Assistant (PFA)

Мобильное приложение (Flutter, сначала iOS) для управления личным капиталом и
финансовым циклом — прогноз дохода, план распределения, счета, инвестиции,
финансовые решения и подтверждающие документы. Это осознанно **не** трекер
расходов: философия продукта — в [doc.md](doc.md) §1.

## С чего начать

| Файл | Что это |
|---|---|
| [doc.md](doc.md) | Полное ТЗ и дизайн-документ (функции, экраны, модель данных, технические решения) |
| [MVP_PLAN.md](MVP_PLAN.md) | Фазовый план MVP (Phase 0–10) |
| [BUILD_PLAN.md](BUILD_PLAN.md) | **Источник истины для реализации.** Гранулированные эпики/задачи (E0–E13), у каждой — контекст, конкретные действия и Definition of Done. Раздел §0 (конвенции) — прочитать до начала работы с кодом: там зафиксированы решения (деньги как `Decimal`, слоистая архитектура, границы агрегатов), нарушение которых дорого исправлять. |
| [CLAUDE.md](CLAUDE.md) | Правила работы для ИИ-агента, продолжающего проект |
| [design/](design/) | Референсные макеты (`dashboard-detail.png` — основной референс для Dashboard; что куда мапится — doc.md §6.7) |

**Чтобы продолжить работу:** откройте `BUILD_PLAN.md`, найдите первую задачу без
отметки ✅ в разделе «Прогресс» ниже и следуйте её Definition of Done. Эпик
E0 (каркас проекта) завершён — начинать с **E1**.

## Прогресс

- [x] **E0** — Каркас проекта: навигация (5 вкладок), тема, l10n (en/ru), DI-корень на Riverpod, CI
- [ ] **E1** — Money/Decimal, Drift-БД, курсы валют, снапшоты капитала, Clock
- [ ] E2–E13 — см. [BUILD_PLAN.md](BUILD_PLAN.md)

## Требования

- macOS с Xcode (сборка только под iOS — Android/web/macOS сознательно не настроены)
- Flutter 3.44.x, канал stable
- CocoaPods (для сборки iOS-плагинов)

## Установка

```bash
# 1. Flutter SDK (если ещё не установлен)
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zprofile

# 2. CocoaPods
brew install cocoapods   # обычный путь, если Homebrew уже настроен
# Если Homebrew нет и вы застряли на старом системном Ruby, а `pod` падает с
# "uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger" —
# это баг порядка require в activesupport/logger, обходится так:
#   gem install cocoapods --user-install
#   echo 'export PATH="$PATH:$HOME/.gem/ruby/2.6.0/bin"' >> ~/.zprofile   # чтобы `pod` находился
#   echo 'export RUBYOPT="-rlogger"' >> ~/.zprofile                      # чинит баг с Logger
```

Далее, из корня репозитория:

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

## Основные команды

```bash
flutter analyze                                        # статический анализ — должен быть чист
flutter test                                            # unit- и widget-тесты
flutter build ios --debug --simulator --no-codesign     # проверочная сборка под iOS
flutter run -d <device-id>                               # запуск на симуляторе (flutter devices — список)
```

Перегонять `dart run build_runner build --delete-conflicting-outputs` (или
держать `dart run build_runner watch -d` во время разработки) нужно при любом
изменении `@freezed`, `@riverpod`, `@JsonSerializable` или Drift-таблицы.

## Идентификация приложения

- Имя Dart-пакета: `personal_finance_assistant`
- iOS bundle id: `com.vladus7000.pfa`
- Apple Developer Team ID сознательно не зашит в `ios/Runner.xcodeproj/project.pbxproj` — для
  запуска на симуляторе он не нужен, для сборки на реальное устройство каждый разработчик
  выбирает свою команду локально: Xcode → `ios/Runner.xcworkspace` → Runner → Signing & Capabilities → Team.

## Известные отклонения от плановых документов

Подробности — в [BUILD_PLAN.md](BUILD_PLAN.md) §0.2:

- `sqlite3_flutter_libs` не используется (пакет официально EOL) — вместо него напрямую `sqlite3` 3.x.
- `riverpod_lint` / `custom_lint` пока не установлены — жёсткий конфликт версий между `custom_lint` (нужен `analyzer ^7`/`^8`) и `drift_dev` (нужен `analyzer ^13`). Это только dev-линтер, на работу приложения не влияет.

## Лицензия

Проприетарный код, все права защищены — см. [LICENSE](LICENSE). Использование, копирование
и распространение без письменного разрешения правообладателя запрещены.
