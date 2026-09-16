# Конфигурация продукта

Внедряется ADR [0001](adr/0001-configurable-product.md). Реестр видов, валидация реквизитов, проекция хранилища и выбор транзакционной операции теперь загружаются извне. Переход всего продукта ещё не завершён: React пока содержит логику прежнего заказчика. Это не заявление о выполнении полного proof of configurability.

## Загрузка и поставка

Каждому приложению задаётся `CORELIA_CONFIG_PATH` — каталог с `configuration.json` и статическими `.graphql`. Отсутствие пути, несовместимая версия, неизвестные поля конфигурации, сломанные ссылки или неполный mapping прерывают запуск. Каждый Spring context владеет отдельным неизменяемым registry; горячей перезагрузки нет. Значения окружения и секреты не входят в пакет.

Для Compose задайте `CORELIA_CUSTOMER_CONFIG` абсолютным путём на хосте. Все приложения монтируют каталог read-only в `/etc/corelia/config`. Образы не включают пакет заказчика. Для запуска непосредственно из IDE задайте `CORELIA_CONFIG_PATH` в окружении приложения.

При запуске из исходного каталога без собранного пакета задайте `CORELIA_PLATFORM_V_AC_PATH` — абсолютный путь к исходному ac.json платформы. По умолчанию адаптер читает `platform-v-ac.json` внутри runtime package. Изменения ac.json требуют пересборки пакета и согласованной поставки платформы и Corelia.

Пакет СберНПФ расположен в соседнем репозитории `sber-npf-corelia-config`. Его нельзя заменять содержимым образа или встроенной конфигурацией по умолчанию.

## Контракт версии 1

Формат — JSON. `schemaVersion: 1`; `compatibility.corelia` имеет явный формат `>=0.1.0 <1.0.0` (полные версии из трёх чисел). Это версия продукта; `documentTypes[].schemaVersion` отдельно версионирует снимок реквизитов.

Каждый вид содержит `id`, `title`, `schemaVersion`, `schema`, `ui`, `storage`, `workflow`, `attachments`; `authorization` (обязателен для Platform V); необязательные `presentation` и `normalization`. Примеры — пакет заказчика и `corelia-system-tests/src/test/resources/customers`.

- JSON Schema: объект с именованными скалярными полями string/integer/number/boolean, required, additionalProperties=false; minLength/maxLength (Unicode code points), pattern, format=date, minimum/maximum, enum. Целое число определяется математически, поэтому 2024.0 допустимо как integer. Неподдерживаемые ключи (включая $ref, oneOf, вложенные объекты/массивы) отклоняются; это ограниченный профиль, а не полная реализация JSON Schema. Регулярные выражения исполняются Java Pattern; переносимость выражений между Java и браузером требует ограничения синтаксиса при подготовке пакета.
- `normalization`: флаги trim/nullAsEmpty/defaultEmpty по строковым полям. Они выполняются до валидации, не меняя исходный JSON. Для PATCH defaultEmpty не заполняет пропущенное поле. Перед записью проверяется также полный объединённый снимок.
- `ui`: массивы columns/fields/searchFields/sortFields, необязательный dateField. Все ссылки проверяются.
- `storage`: provider/entity/details, полное взаимно однозначное fields-отображение, operations. Адаптер Platform V использует search/update; search возвращает стандартный корень `searchDocument`, update принимает стандартные переменные атомарного commit. Имена физических полей могут отличаться от публичных. Общие операции Document/Version/Command/Attachment сохраняют транспортный контракт; адаптер проверяет обязательные операции при старте.
- `workflow`: processes и actions с проверяемыми ссылками на process aliases. `creationSource=platform-settings` сохраняет выбор через `DocumentProcessSettings`; `creationSource=configuration` выбирает process alias по creationAction. externalFields задаёт реквизиты поиска задач; completion задаёт statusField/assigneeField, признаки назначения и autoStart. Произвольный запуск остальных logical actions пока не опубликован в API.
- `attachments`: enabled/initialRequired/maxCount. Обязательное начальное вложение использует существующий staging → BPM → v1 протокол; ограничение количества проверяется владельцем документа перед транзакцией.
- `presentation`: statuses/aliases/tones/initialStatus. Это представление состояний, не разрешение менять статус произвольно.

Каталог `/api/core/v1/document-types` сохраняет поля прежнего API и дополнен schema/ui; `/document-types/{type}` возвращает одно определение. Storage mappings и process IDs в публичный ответ не включаются.

## Компилятор

Из корня Corelia:

```bash
mkdir -p .local/config-releases
bash scripts/compile-config.sh ../sber-npf-corelia-config .local/config-releases/sber-release ../sber-npf-platform-v/ac.json
```

Выходной каталог должен отсутствовать; его родитель должен существовать и находиться вне source package. Maven собирает CLI с зависимостями. Компилятор валидирует пакет, сохраняет статические тела операций (без начальных/конечных пробелов), объединяет их с `operation-permissions.json` и выдаёт:

- `corelia/configuration.json`, `corelia/graphql/*.graphql` — runtime package;
- `corelia/platform-v-ac.json` и `platform-v/ac.json` — одинаковые копии исходного платформенного соответствия прав ролям;
- `platform-v/graphql-permissions.fragment.json` — fragment для включения в модель заказчика;
- `tests/allowed-requests.json` — fixture;
- `manifest.json` — версия продукта и SHA-256 конфигурации/операций/ac.json.

`operation-permissions.json` содержит name, checkForAnyPrivilege, при необходимости checkSelects/allowEmptyChecks/disableJwtVerification, но не дублирует body. Компилятор переносит явные условия доступа без выдумывания прав. Он не генерирует DataSpace-модель или BPMN и не публикует пакет. Фрагмент нельзя слепо подменять всем файлом permissions: в платформе есть и другие операции. Проверка компилятора сверяет полный текст и правила с существующим комплектом СберНПФ. Для нового релиза эти проверки необходимо выполнять вместе с тестами целевой модели.

## Совместимость миграции

Сохраняются ID, schemaVersion=1, токены, receipts, названия операций и BPM-параметры СберНПФ. В старой задаче без documentType вид определяется по её документу с JWT пользователя; подстановка вида по умолчанию удалена. Процессы не перезапускаются при миграции кода.

Нормализация КИД сохранена. Проверка даты ПДС теперь отвергает несуществующие календарные даты; раньше проверялся только формат. До развёртывания следует проверить такие данные: их правка может потребовать исправления даты. Автоматической миграции исторических снимков нет.

Права создания и изменения проверяются через PermissionChecker по единственному исходному ac.json платформы. `authorization` содержит ссылки createPermission/editPermission, executorRole, editableStatuses и initialUploadStatuses. Неизвестное право или роль прерывает запуск. Ограничения статуса и назначения проверяет document-service; это правила изменения документа, а не отдельный список выдачи ролям прав. Подготовка первого файла разрешена по mTLS только document-service после его проверки права создания. Общей транзакции DAM/BPM/DataSpace нет; существующие ограничения повторов запуска BPM сохраняются.

## Capabilities и действия

Добавлены read-only `/documents/{type}/{id}/capabilities` и `/actions`, а также выполнение текущего процессного действия `/actions/{action}`. Доступность операций в React-карточке приходит из capabilities. Ответ предварительный: мутации повторяют правила ядра и обращаются к платформе с JWT. Роли получают права из того же ac.json, который поставляется платформе; проверки состояния и исполнителя настраиваются для вида документа. Это предварительная проверка: окончательные permissions платформы сохраняют силу.

`workflow.terminalStatuses` задаёт состояния завершённого процесса для представления карточки; gateway получает флаг от document-service и больше не содержит констант статусов заказчика.
