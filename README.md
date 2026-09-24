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
