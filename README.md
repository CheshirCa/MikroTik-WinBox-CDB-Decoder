# CDB Reader 2.1

A console utility written in PureBasic for reading MikroTik WinBox address-book CDB files (WinBox 3.x and 4.x) and converting legacy Cyrillic text for use with WinBox 4.

The utility detects the CDB record format, decodes Windows-1251 and UTF-8 text, and prints the address book as a table, CSV, JSON, or a group-based tree. By default, it prints the original seven-column table.

## Features

- Reads address-book CDB files created by WinBox 3.x and WinBox 4.x.
- Detects and displays the file format (`WinBox 3.x CDB` or `WinBox 4.x CDB`) and the record count in the human-readable output.
- Reads legacy CP1251 Cyrillic and UTF-8 text, including UTF-8 text stored in a WinBox 3-style CDB.
- Preserves the original output columns: `Name`, `Address`, `User`, `Group`, `Owner`, `Key`, `Note`.
- Supports `TABLE` (default), `CSV`, `JSON`, and `TREE` output modes.
- Supports `/convert <src.cdb> <dst.cdb>` to convert legacy WinBox 3 text to UTF-8 **without changing the WinBox 3 record wrapper**.
- Conversion writes a separate destination file and refuses to overwrite an existing file.
- Source Windows code page can be selected with `/CPxxxx` (default: `/CP1251`).
- `/translit` transliterates non-ASCII text to ASCII instead of storing UTF-8; unknown characters become `?`.

## Supported fields

The following mappings are used by the reader. The console column names are retained from version 1.x for compatibility.

| CDB field ID | Parsed value | Existing output column |
| --- | --- | --- |
| `$01` | Address | `Address` |
| `$02` | Login | `User` |
| `$03` | Password / saved key | `Key` |
| `$04` | Comment / connection label | `Name` |
| `$06` | Session/owner data (WinBox 3); keep-password data (WinBox 4) | `Owner` for WinBox 3 |
| `$08` | Group | `Group` |
| `$0B` | RoMON-related value | `Note` |
| `$0C` | Workspace (WinBox 4) | Not in legacy output |
| Special `09 00 FE 21` | Display name (WinBox 4) | Not in legacy output |

Additional fields may be parsed internally but are not added to the existing seven-column output. Unknown fields are not shown. The complete CDB specification is not publicly documented; some field interpretations remain provisional.

## Usage

Print the address book as a table (default):

```powershell
cdb.exe file.cdb
cdb.exe file.cdb TABLE
```

Other output formats:

```powershell
cdb.exe file.cdb CSV
cdb.exe file.cdb JSON
cdb.exe file.cdb TREE
```

The previously supported option variants are retained:

```powershell
cdb.exe file.cdb /CSV
cdb.exe file.cdb /JSON
cdb.exe file.cdb /TREE
cdb.exe file.cdb /OUTPUT CSV
cdb.exe file.cdb --format JSON
```

Convert an old WinBox 3 address book for import into WinBox 4:

```powershell
cdb.exe /convert old.cdb converted.cdb
cdb.exe /convert old.cdb converted.cdb /CP1250
cdb.exe /convert old.cdb converted.cdb /CP1252 /translit
cdb.exe /translit old.cdb ascii.cdb /CP1251
```

The input must be a WinBox 3-style CDB. The `/CPxxxx` value is a Windows code page number, for example 1251 (Cyrillic), 1250 (Central European) or 1252 (Western European). Without the option, CP1251 is used. On Windows the conversion uses `MultiByteToWideChar`. An already valid UTF-8 field remains unchanged in normal conversion mode.

`/translit` is a separate ASCII-output option. It transliterates Cyrillic and several common Latin accented characters, strips a few signs, and replaces other non-ASCII characters with `?`. It is **lossy**, unlike UTF-8 conversion. ASCII fields and binary fields are preserved. The transliteration is intended for labels and groups, not for passwords. Do not use it if preserving the exact original spelling is important.

The original code page is not stored in a typical WinBox 3 CDB. Automatic detection is unreliable; specify it explicitly for non-CP1251 books. Also, an occasional legacy byte sequence can coincidentally pass UTF-8 validation, so back up and inspect the result.

The input must be a WinBox 3-style CDB. The program converts selected text fields (`$04`, `$06`, `$08`, `$0B`) from Windows-1251 to UTF-8 as necessary, updates the affected field and record lengths, and leaves other data, including the password field `$03`, unchanged. Strings that already pass UTF-8 validation are not converted again. The output **still has the WinBox 3 record structure**; this is intentional, because WinBox 4.4 can import such files with UTF-8 text.

Back up the original CDB and test the converted address book before replacing any working data. Compatibility has been checked with test records, including a multi-record book, but not every possible combination of saved passwords, sessions, and RoMON settings.

## Output formats

### TABLE

An ASCII table with the original seven columns. The format/version and record count are shown above the table.

### CSV

A header row followed by quoted fields. Double quotes inside values are escaped in accordance with RFC 4180. The existing CSV column names and order have not changed.

```powershell
cdb.exe file.cdb CSV > address-book.csv
```

### JSON

An array of JSON objects with the original property names; no version metadata is added to the JSON output.

```powershell
cdb.exe file.cdb JSON > address-book.json
```

### TREE

Records grouped by `Group`. An empty group is shown as `(no group)`.

```powershell
cdb.exe file.cdb TREE
```

**Security:** `Key` may contain saved credentials. Treat console output and exported CSV/JSON files as sensitive data; do not publish real address books or diagnostic files containing passwords.

## Build

Source: `cdb.pb`. PureBasic 6.40 or a compatible 6.x version; console application, no external dependencies.

```powershell
& 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe' 'cdb.pb' /OUTPUT 'cdb.exe' /CONSOLE
```

Syntax check:

```powershell
& 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe' 'cdb.pb' /CHECK
```

## File handling and limitations

- Both formats use the CDB signature `0D F0 1D C0` and length-prefixed `M2` records. WinBox 3 and 4 are distinguished by their record structure, **not by the exact application version**.
- The reader uses record lengths to find record boundaries. Recognized string fields use a one-byte length; the special display-name field has a different marker.
- Encoding is selected at the string level. A byte sequence that is valid UTF-8 is treated as UTF-8, including in a WinBox 3-style file. Ambiguous byte sequences may therefore be interpreted differently from the original text.
- Conversion is supported **from WinBox 3-style files only**. It is not a WinBox 4-to-3 converter and does not rebuild the native WinBox 4 record structure.
- The converter preserves fields it does not intentionally change, but CDB parsing still depends on observed, not fully documented structures. Use a copy and verify the result in WinBox before production use.
- Some WinBox 4 fields are recognized internally but deliberately omitted from the legacy table/CSV/JSON schema.

---

# CDB Reader 2.1

Консольная утилита на PureBasic для чтения адресных книг MikroTik WinBox 3.x и 4.x в формате CDB и преобразования старой кириллицы для импорта в WinBox 4.

Программа определяет формат записей CDB, читает текст в Windows-1251 и UTF-8 и выводит адресную книгу в виде таблицы, CSV, JSON или дерева по группам. По умолчанию, как и в версии 1.x, используется таблица с семью столбцами.

## Возможности

- Чтение файлов адресной книги WinBox 3.x и WinBox 4.x.
- Определение формата (`WinBox 3.x CDB` или `WinBox 4.x CDB`) и вывод количества записей в обычном консольном режиме.
- Корректное чтение кириллицы CP1251 и UTF-8, в том числе UTF-8 внутри старой структуры CDB.
- Сохранение прежних полей вывода: `Name`, `Address`, `User`, `Group`, `Owner`, `Key`, `Note`.
- Режимы `TABLE` (по умолчанию), `CSV`, `JSON`, `TREE`.
- Ключ `/convert <src.cdb> <dst.cdb>` для преобразования текстовых полей из CP1251 в UTF-8 **без изменения структуры записей WinBox 3**.
- Создание отдельного выходного файла без перезаписи существующего.

## Поддерживаемые поля

Ниже показано, как парсер трактует поля. Названия столбцов консольного вывода оставлены от версии 1.x для совместимости.

| ID поля CDB | Назначение | Прежний столбец вывода |
| --- | --- | --- |
| `$01` | Адрес | `Address` |
| `$02` | Логин | `User` |
| `$03` | Сохранённый пароль / ключ | `Key` |
| `$04` | Комментарий / название подключения | `Name` |
| `$06` | Session/Owner (WinBox 3), признак сохранения пароля (WinBox 4) | `Owner` для WinBox 3 |
| `$08` | Группа | `Group` |
| `$0B` | Значение, связанное с RoMON | `Note` |
| `$0C` | Workspace (WinBox 4) | Не выводится в прежних форматах |
| Особый маркер `09 00 FE 21` | Display name (WinBox 4) | Не выводится в прежних форматах |

Некоторые дополнительные поля распознаются внутри парсера, но не добавлены в привычные семь столбцов. Неизвестные поля не выводятся. Полного официального описания CDB нет, поэтому трактовка части служебных полей пока предварительная.

## Использование

Обычный запуск, таблица по умолчанию:

```powershell
cdb.exe file.cdb
cdb.exe file.cdb TABLE
```

Остальные форматы:

```powershell
cdb.exe file.cdb CSV
cdb.exe file.cdb JSON
cdb.exe file.cdb TREE
```

Старые варианты вызова сохранены:

```powershell
cdb.exe file.cdb /CSV
cdb.exe file.cdb /JSON
cdb.exe file.cdb /TREE
cdb.exe file.cdb /OUTPUT CSV
cdb.exe file.cdb --format JSON
```

Перекодирование адресной книги WinBox 3 для импорта в WinBox 4:

```powershell
cdb.exe /convert old.cdb converted.cdb
cdb.exe /convert old.cdb converted.cdb /CP1250
cdb.exe /convert old.cdb converted.cdb /CP1252 /translit
cdb.exe /translit old.cdb ascii.cdb /CP1251
```

Исходный файл должен иметь структуру записей WinBox 3. Программа при необходимости перекодирует поля `$04`, `$06`, `$08`, `$0B` из CP1251 в UTF-8, пересчитывает длины строк и записей, но не меняет остальные данные, включая поле пароля `$03`. Если строка уже распознаётся как корректный UTF-8, повторная перекодировка не выполняется.

**Выходной файл остаётся в формате записей WinBox 3.** Это сделано специально: мы проверили, что WinBox 4.4 импортирует такие CDB при правильной кодировке строк. В тестах успешно открывались как одиночная запись, так и адресная книга с несколькими записями.

Перед конвертацией сохрани копию оригинального CDB. На реальных книгах с паролями, RoMON и разными вариантами сессий перенос всех комбинаций пока не проверен. Результат лучше сначала импортировать в тестовый экземпляр WinBox и сравнить записи.

## Форматы вывода

### TABLE

ASCII-таблица с прежними семью столбцами. Над таблицей выводятся формат CDB и количество записей.

### CSV

CSV с заголовком. Значения заключаются в двойные кавычки; кавычки внутри полей экранируются по RFC 4180. Названия и порядок столбцов сохранены.

```powershell
cdb.exe file.cdb CSV > address-book.csv
```

### JSON

Массив JSON-объектов с прежними именами полей. Служебная информация о версии не добавляется внутрь JSON.

```powershell
cdb.exe file.cdb JSON > address-book.json
```

### TREE

Дерево записей по полю `Group`. Пустая группа выводится как `(no group)`.

```powershell
cdb.exe file.cdb TREE
```

**Безопасность:** в поле `Key` могут быть сохранённые учётные данные. Консольный вывод и файлы CSV/JSON с реальными адресными книгами нельзя без проверки выкладывать в открытый доступ.

## Сборка

Исходник: `cdb.pb`. Нужен PureBasic 6.40 или совместимая версия 6.x. Внешних зависимостей нет.

```powershell
& 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe' 'cdb.pb' /OUTPUT 'cdb.exe' /CONSOLE
```

Проверка синтаксиса:

```powershell
& 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe' 'cdb.pb' /CHECK
```

## Формат CDB и ограничения

- Оба варианта файла используют сигнатуру `0D F0 1D C0` и записи `M2` с длинами. WinBox 3 и 4 определяются по структуре записей, **не по точному номеру версии WinBox**.
- Границы записей находятся по длинам. У распознаваемых строковых полей длина задаётся одним байтом; для дополнительного имени есть особый маркер.
- Кодировка определяется отдельно для каждой строки. Если байты допустимы как UTF-8, они читаются как UTF-8 даже в структуре WinBox 3. Для неоднозначных последовательностей это может дать неверное прочтение старого текста.
- `/convert` принимает **только CDB со структурой WinBox 3**. Обратной конвертации 4 → 3 нет; нативная структура WinBox 4 не генерируется.
- Неизвестные данные при конвертации предполагается сохранять без изменений, но разбор CDB основан на исследованных образцах, а не на полной спецификации. Используй резервную копию и проверяй импорт до замены рабочей книги.
- Дополнительные поля WinBox 4 могут распознаваться, но не включаются в прежние форматы TABLE/CSV/JSON, чтобы не ломать совместимость.
