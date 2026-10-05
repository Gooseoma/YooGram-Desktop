# Сборка YooGram для Windows и установщик

## Способ 1. На GitHub Actions (проще всего)

Нужен публичный репозиторий (там Actions бесплатны) и **публичный `Gooseoma/lib_ui`** — на него ссылается подмодуль `Telegram/lib_ui`, иначе checkout не сможет его скачать.

1. В репозитории: **Settings → Secrets and variables → Actions → New repository secret**, добавьте
   `API_ID` и `API_HASH` — ваши данные с https://my.telegram.org (раздел API development tools).
   Без них соберётся с ограниченными тестовыми данными: войти можно, но потом начнутся ошибки.
2. **Actions → «YooGram Windows installer.» → Run workflow** (ветка `main`).
3. Первая сборка идёт 1,5–3 часа (собирает Qt и библиотеки), следующие быстрее благодаря кэшу.
4. По завершении откройте запуск → **Artifacts → YooGram-windows-x64**:
   - `YooGram-setup-x64-<версия>.exe` — установщик (Inno Setup);
   - `YooGram-portable-x64-<версия>.zip` — переносная версия (данные лежат рядом с программой).

Автообновление отключено (`DESKTOP_APP_DISABLE_AUTOUPDATE=ON`), чтобы мод не заменился официальным клиентом. Установщик и exe не подписаны — Windows SmartScreen покажет предупреждение, это нормально для неподписанных сборок.

## Способ 2. Локально на своём ПК

**Что нужно**
- Windows 10/11 x64, 16 ГБ ОЗУ и больше, **100+ ГБ свободного места** на SSD.
- **Visual Studio 2022 версии 17.14** (Community подойдёт): рабочая нагрузка «Разработка классических приложений на C++». Она включает `MSVC v143 14.44` и `MSBuild` с набором `v143`, а также Windows SDK. Visual Studio 2026 не подходит одна: в её MSBuild нет набора `v143`, который нужен для `lzma`, `breakpad` и `libvpx` (можно держать обе версии рядом, скрипт `tools\yoogram-build.bat` выберет 2022).
- Компонент **«C++ ATL для новейших средств сборки v143 (x86 и x64)»** (Visual Studio Installer → «Отдельные компоненты» → поиск `ATL`). Без него этап `breakpad` падает с `error C1083: ... atlbase.h`.
- Python 3.10 (при установке отметьте «Add to PATH») и Git.
- Короткий путь без пробелов и кириллицы, например `D:\TBuild`.

**Быстрый вариант:** клонируйте репозиторий в `D:\TBuild` (шаг 2) и запустите двойным щелчком `tools\yoogram-build.bat`. Он сам найдёт Visual Studio, настроит окружение, спросит `api_id`/`api_hash` и выполнит шаги 3–4. Если что-то не запускается, он напишет, чего не хватает. Ниже то же самое вручную.

**Шаги**

1. Создайте папку `D:\TBuild` и откройте консоль с окружением Visual Studio для x64:

       %comspec% /k "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" -vcvars_ver=14.44

   (путь зависит от издания VS; можно открыть «x64 Native Tools Command Prompt for VS» и выполнить `vcvars64.bat -vcvars_ver=14.44` из неё). Все команды ниже — в этой консоли.

2. Клонируйте репозиторий **в `D:\TBuild`** (рядом появятся `Libraries` и `ThirdParty`):

       cd /d D:\TBuild
       git clone --recursive https://github.com/Gooseoma/YooGram-Desktop.git

   Если `Gooseoma/lib_ui` приватный, Git попросит войти в GitHub.

3. Соберите библиотеки (**1–3 часа**, Debug и Release; без аргумента `skip-release` — он нужен только для Debug-сборки):

       YooGram-Desktop\Telegram\build\prepare\win.bat qt6

   Скрипт можно запускать повторно — готовые библиотеки он пропускает. Если на каком-то этапе ошибка, пришлите последние 30–40 строк перед `FAILED`.

4. Соберите приложение (подставьте свои `api_id`/`api_hash` с my.telegram.org; для беглой проверки можно `-D TDESKTOP_API_TEST=ON` вместо них):

       cd YooGram-Desktop\Telegram
       configure.bat x64 qt6 -D TDESKTOP_API_ID=ВАШ_ID -D TDESKTOP_API_HASH=ВАШ_HASH -D DESKTOP_APP_DISABLE_AUTOUPDATE=ON -D CMAKE_CONFIGURATION_TYPES=Release
       cmake --build ..\out --config Release --parallel

   Готовый `Telegram.exe` — в `D:\TBuild\YooGram-Desktop\out\Release`. Если компиляция остановилась на ошибке, пришлите **первые** строки с `error C...` / `error:` (самое первое сообщение, остальные обычно следствие).

   Отладка: открыть `out\Telegram.slnx` в Visual Studio (для Debug-конфигурации нужны Debug-библиотеки).

### Установщик локально

1. Установите [Inno Setup 6](https://jrsoftware.org/isdl.php).
2. Скопируйте `d3dcompiler_47.dll` из `C:\Windows\System32` в `out\Release\modules\x64\d3d\`.
3. В копии `Telegram\build\setup.iss` удалите строки `SignTool=sha256` и `Source: ...Updater.exe...` (подписи и Updater у мода нет).
4. Выполните (подставьте версию из `Telegram\build\version`, например `7.2.10`):

       "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /dMyAppVersion=7.2.10 /dMyAppVersionFull=7.2.10 "/dReleasePath=C:\путь\YooGram-Desktop\out\Release" /dMyBuildTarget=win64 /dMyOutputBaseFilename=YooGram-setup-x64-7.2.10 setup.iss

   Установщик появится в `out\Release`.

## Про старые workflow

Файлы `win.yml`, `mac.yml`, `linux.yml` и др. достались от оригинального репозитория и на каждый push/PR запускают огромные матрицы сборок (часть — на платных runner'ах `depot-*`, которых у форка нет). Для мода они не нужны: можно отключить их в **Actions → (workflow) → ⋯ → Disable workflow** или удалить файлы.
