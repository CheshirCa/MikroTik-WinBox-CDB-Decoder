# CDB Reader

A console utility for reading address-book records from MikroTik WinBox 3.* CDB files.

The program loads a `.cdb` file, finds address-book records, decodes string fields from Windows-1251, and prints the result in one of several formats: table, CSV, JSON, or a group-based tree.

## Features

- reads MikroTik address-book CDB files;
- correctly displays Cyrillic text stored as CP1251;
- outputs the `Name`, `Address`, `User`, `Group`, `Owner`, `Key`, and `Note` fields;
- supports several output formats;
- opens the file in shared-read mode, so it can still be inspected by other tools while the program is reading it.

## Supported Fields

| CDB field id | Output field |
| --- | --- |
| `$01` | `Address` |
| `$02` | `User` |
| `$03` | `Key` |
| `$04` | `Name` |
| `$06` | `Owner` |
| `$08` | `Group` |
| `$0B` | `Note` |

Unknown fields are skipped.

## Usage

The basic command prints a human-readable table:

```powershell
cdb.exe file.cdb
```

You can select the output format with the second argument:

```powershell
cdb.exe file.cdb CSV
cdb.exe file.cdb JSON
cdb.exe file.cdb TREE
```

Prefixed options and explicit output keys are also supported:

```powershell
cdb.exe file.cdb /CSV
cdb.exe file.cdb /JSON
cdb.exe file.cdb /TREE
cdb.exe file.cdb /OUTPUT CSV
cdb.exe file.cdb --format JSON
```

`TABLE` is the default format, but it can also be passed explicitly:

```powershell
cdb.exe file.cdb TABLE
```

## Output Formats

### TABLE

Prints records as an ASCII table. This is useful for quick inspection in the console.

### CSV

Prints CSV with a header row. Every cell is wrapped in double quotes, and quotes inside values are escaped according to RFC 4180.

Example:

```powershell
cdb.exe file.cdb CSV > address-book.csv
```

### JSON

Prints an array of JSON objects. This format is suitable for further processing by scripts.

Example:

```powershell
cdb.exe file.cdb JSON > address-book.json
```

### TREE

Groups records by the `Group` field and prints them as a tree. Empty groups are displayed as `(no group)`.

```powershell
cdb.exe file.cdb TREE
```

## Build

Source file: `cdb.pb`.

PureBasic 6.40 or a compatible version is required. Example command for Windows:

```powershell
& 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe' 'cdb.pb' /OUTPUT 'cdb.exe' /CONSOLE
```

Syntax check without creating an executable:

```powershell
& 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe' 'cdb.pb' /CHECK
```

## How the Parser Works

The parser reads the whole file into memory because it needs random byte access and frequent lookahead checks.

A record boundary is detected by a stable marker inside the record header:

```text
00 00 00 4D 32
```

String fields are detected by this pattern:

```text
<field-id> 00 00 21 <length> <cp1251 bytes>
```

`length` defines the exact number of bytes in the string. After decoding the string, the parser skips over the full encoded payload so service bytes after the string are not printed as data.

## Limitations

- Only the known address-book string fields listed above are supported.
- String length is read from a single `length` byte.
- The CDB format is not fully documented here; the parser is based on observed MikroTik WinBox address-book file structures.

---

# CDB Reader

Консольная утилита для чтения address-book записей из MikroTik WinBox 3.* CDB-файлов.

Программа загружает `.cdb` файл, находит записи адресной книги, декодирует строковые поля из Windows-1251 и выводит результат в одном из нескольких форматов: таблица, CSV, JSON или дерево по группам.

## Возможности

- чтение MikroTik CDB-файлов адресной книги;
- корректное отображение кириллицы из CP1251;
- вывод полей `Name`, `Address`, `User`, `Group`, `Owner`, `Key`, `Note`;
- несколько форматов вывода;
- shared-read открытие файла, чтобы его можно было параллельно смотреть другими инструментами.

## Поддерживаемые поля

| CDB field id | Поле вывода |
| --- | --- |
| `$01` | `Address` |
| `$02` | `User` |
| `$03` | `Key` |
| `$04` | `Name` |
| `$06` | `Owner` |
| `$08` | `Group` |
| `$0B` | `Note` |

Неизвестные поля пропускаются.

## Использование

Базовый запуск выводит человекочитаемую таблицу:

```powershell
cdb.exe file.cdb
```

Можно выбрать формат вторым аргументом:

```powershell
cdb.exe file.cdb CSV
cdb.exe file.cdb JSON
cdb.exe file.cdb TREE
```

Также поддерживаются варианты с префиксами и явным ключом:

```powershell
cdb.exe file.cdb /CSV
cdb.exe file.cdb /JSON
cdb.exe file.cdb /TREE
cdb.exe file.cdb /OUTPUT CSV
cdb.exe file.cdb --format JSON
```

Формат `TABLE` используется по умолчанию, но его тоже можно указать явно:

```powershell
cdb.exe file.cdb TABLE
```

## Форматы вывода

### TABLE

Выводит записи в виде ASCII-таблицы. Удобно для быстрого просмотра в консоли.

### CSV

Выводит CSV с заголовком. Каждая ячейка заключается в двойные кавычки, кавычки внутри значений экранируются по правилам RFC 4180.

Пример сохранения:

```powershell
cdb.exe file.cdb CSV > address-book.csv
```

### JSON

Выводит массив JSON-объектов. Подходит для дальнейшей обработки скриптами.

Пример сохранения:

```powershell
cdb.exe file.cdb JSON > address-book.json
```

### TREE

Группирует записи по полю `Group` и выводит их деревом. Если группа пустая, она отображается как `(no group)`.

```powershell
cdb.exe file.cdb TREE
```

## Сборка

Исходный файл: `cdb.pb`.

Требуется PureBasic 6.40 или совместимая версия. Пример команды для Windows:

```powershell
& 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe' 'cdb.pb' /OUTPUT 'cdb.exe' /CONSOLE
```

Проверка синтаксиса без создания исполняемого файла:

```powershell
& 'C:\Program Files (x86)\PureBasic\Compilers\pbcompiler.exe' 'cdb.pb' /CHECK
```

## Как работает парсер

Парсер читает файл целиком в память, потому что ему нужен произвольный доступ к байтам и проверка нескольких байтов вперед.

Граница записи определяется по стабильному маркеру внутри заголовка:

```text
00 00 00 4D 32
```

Строковые поля ищутся по шаблону:

```text
<field-id> 00 00 21 <length> <cp1251 bytes>
```

`length` задает точное количество байтов строки. После декодирования парсер перескакивает через всю строку, чтобы служебные байты после нее не попадали в вывод.

## Ограничения

- Поддерживаются только известные строковые поля адресной книги, перечисленные выше.
- Длина строки берется из одного байта поля `length`.
- Формат CDB не документирован здесь полностью; парсер ориентирован на наблюдаемые структуры MikroTik WinBox address-book файлов.

