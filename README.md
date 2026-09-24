# KAPL — Keep-Alive Privacy Lock

Приложение для macOS: блокирует управление Mac и размывает экран, **не переводя Mac в сон**. Claude Code, сборки, загрузки и другие фоновые задачи продолжают работать. Разблокировка через Touch ID или системный запрос пароля.

> Статус: ранний прототип (v0.1). Работают Privacy Lock, Touch ID и запрет сна; при любом сбое приложение переключается на системную блокировку macOS.

## Требования

- macOS 14+
- Xcode 16+ (разработка ведётся в Xcode 27)

## Сборка и запуск

```bash
open KAPL.xcodeproj          # затем ⌘R
```

или из терминала:

```bash
xcodebuild -project KAPL.xcodeproj -scheme KAPL -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/KAPL.app
```

Приложение живёт в строке меню (иконка щита) → **Lock Now**, или горячая клавиша **⌘Esc** из любого приложения.

## DMG для установки

```bash
scripts/make-dmg.sh
```

Собирает Release (универсальный: Apple silicon и Intel) и кладёт `build/KAPL-<версия>.dmg`: приложение, ссылка на «Программы», иконка на диске и файле. Версия берётся из `MARKETING_VERSION` в настройках таргета.

По умолчанию подпись ad-hoc: на этом Mac всё работает, а на других macOS заблокирует запуск (Системные настройки → Конфиденциальность и безопасность → «Всё равно открыть»). Для раздачи нужен сертификат Developer ID (Apple Developer Program):

```bash
xcrun notarytool store-credentials KAPL --apple-id you@example.com --team-id TEAMID   # один раз
scripts/make-dmg.sh --team TEAMID --notary-profile KAPL
```

Первый запуск со стандартной раскладкой окна может спросить разрешение управлять Finder; без него DMG всё равно соберётся (`--no-layout` пропускает этот шаг).

## Иконка

Исходник — `Design/AppIcon.png` (1024×1024, сейчас временная). После замены:

```bash
scripts/set-app-icon.sh
```

Скрипт заполняет `KAPL/Assets.xcassets/AppIcon.appiconset`; DMG берёт иконку из собранного приложения.

## Тесты

```bash
cd Packages/KAPLKit && swift test
# или: xcodebuild -project KAPL.xcodeproj -scheme KAPL test
```

Ручная проверка на реальном Mac — [docs/TESTING.md](docs/TESTING.md).

## Документация

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): устройство проекта и принятые решения
- [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md): продуктовые требования
- [docs/TESTING.md](docs/TESTING.md): чек-лист ручной проверки
