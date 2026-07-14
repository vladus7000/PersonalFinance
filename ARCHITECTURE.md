# Архитектура

Короткая карта «куда класть код и как его тестировать» — для человека или ИИ-агента, который
впервые открывает репозиторий. За решениями и обоснованиями — в [BUILD_PLAN.md](BUILD_PLAN.md)
§0 (полные конвенции) и [doc.md](doc.md) (продуктовый смысл).

## Слои и правило зависимостей

```
features/<name>/presentation   →  features/<name>/application  →  domain
        ↑ (виджеты)                  (Riverpod-контроллеры)         ↑
        │                                                            │
      app/  (composition root: router, theme, DI)          data/  ──┘ (реализует интерфейсы domain/)
                                                             platform/ (notifications, files, security)

core/  — используется любым слоем (framework-agnostic: money, result, time, l10n)
```

**Главное правило:** `domain/` не импортирует Flutter, Drift или Riverpod — это чистый Dart.
`data/` и `platform/` зависят от `domain/` (реализуют его интерфейсы), а не наоборот. `features/`
связывает всё через DI (Riverpod-провайдеры в `app/di.dart` и `features/*/application/`).

Если тянет импортировать `package:drift/drift.dart` или `package:flutter/material.dart` внутри
`lib/domain/` — это сигнал, что код не в том слое.

## Куда класть новый код

| Папка | Что там живёт | Пример |
|---|---|---|
| `app/` | Composition root: роутер, тема, DI-регистрация | `app_router.dart`, `di.dart` |
| `core/` | Framework-agnostic переиспользуемое: деньги, Result/Failure, время, l10n, общие виджеты-заглушки | `core/money/money.dart` |
| `domain/entities/` | Неизменяемые доменные модели (freezed) | `exchange_rate.dart` |
| `domain/value_objects/` | Доменные value objects, специфичные для конкретной бизнес-концепции (не общего назначения — те в `core/`) | пока пусто |
| `domain/engines/` | Чистая бизнес-логика/расчёты, без I/O | `currency_converter.dart` |
| `domain/repositories/` | Абстрактные интерфейсы, которые реализует `data/` | `exchange_rate_source.dart` |
| `data/db/` | Drift: `app_database.dart`, `tables/`, `daos/`, `backup/` | — |
| `data/repositories/` | Drift-реализации интерфейсов из `domain/repositories/` | — |
| `data/sources/` | Реализации внешних источников (`ExchangeRateSource` и т.п.) | `manual_exchange_rate_source.dart` |
| `data/mappers/` | DTO (Drift row) ↔ domain entity, если маппинг нетривиален | — |
| `platform/` | Тонкие обёртки над возможностями устройства | `notifications/`, `files/`, `security/` |
| `features/<name>/application/` | Riverpod-контроллеры конкретного экрана/фичи | — |
| `features/<name>/presentation/` | Виджеты конкретного экрана/фичи | `dashboard_screen.dart` |

## Тестовая архитектура

Полная таблица и правила — [BUILD_PLAN.md](BUILD_PLAN.md) §0.6. Коротко: бизнес-логику проверяем
один раз на самом низком возможном слое (доменные тесты на фейках → data-тесты на in-memory
Drift → Riverpod-контроллеры через `ProviderContainer` → виджет-тесты только на рендер состояний
→ `integration_test/` только для того, что нельзя замокать). `test/` зеркалит `lib/` 1:1. Общие
тестовые обёртки — в `test/support/` (`pump_app.dart`).

## Рецепт: добавить новый экран с нуля

Типичный порядок работы над задачей вроде «Экран целей» (E7.T2), от данных к UI:

1. **Domain** — сущность в `domain/entities/` (если её ещё нет) + движок в `domain/engines/`,
   если есть расчёт (прогресс, дата достижения). Тест на фейках, без БД.
2. **Data** — таблица в `data/db/tables/`, регистрация в `AppDatabase(tables: [...])`, реализация
   репозитория в `data/repositories/` или `data/sources/`. Тест на `NativeDatabase.memory()`.
3. **Application** — Riverpod-контроллер в `features/<name>/application/`, зависящий от
   доменного интерфейса (не от Drift напрямую). Тест через `ProviderContainer` с override на фейк.
4. **Presentation** — экран в `features/<name>/presentation/`, читает состояние через провайдер.
   Widget-тест через `pumpApp()` — только на то, что рендерится в разных состояниях.
5. **Роутинг** — маршрут в `app/router/app_router.dart`, если экран должен открываться напрямую
   (не все экраны такие — многие открываются только как часть другого потока).

Каждый шаг — самостоятельно тестируемый и коммитуемый; необязательно делать все 5 за один присест.
