# API Corelia

Публичный префикс — `/api/core/v1`. Защищённые маршруты требуют `Authorization: Bearer <access_token>`. POST login/refresh/logout и GET health не требуют JWT. Внутренний `/internal/v1` дополнительно требует разрешённый mTLS-сертификат, включая health.

Ошибка имеет вид `{"message":"Описание ошибки"}`. Основные коды: 400 — неверный запрос, 401/403 — доступ, 404 — отсутствие ресурса, 409 — конфликт состояния или повторного ключа, 413 — размер тела, 422 — предел выборки, 502/503/504 — интеграция. Ошибка платформы не преобразуется в успешный пустой ответ.

## Маршруты

| Метод | Путь после префикса | Назначение |
| --- | --- | --- |
| GET | `/health` | Приложение запущено; внешние системы не проверяются |
| POST | `/auth/login` | username, password |
| POST | `/auth/refresh` | refreshToken |
| POST | `/auth/logout` | refreshToken; ответ 204 |
| GET | `/auth/me` | Профиль пользователя |
| GET | `/document-types` | Каталог PDS_CONTRACT и KID_OPS |
| POST | `/documents/search` | Общий поиск по обоим видам |
| POST | `/documents/{type}/search` | Поиск выбранного вида |
| POST | `/documents/{type}` | Создание через процесс; ответ 201 |
| GET | `/documents/by-id/{id}` | Карточка без заранее известного вида |
| GET | `/documents/{type}/{id}` | Текущая карточка |
| PATCH | `/documents/{type}/{id}` | Изменение реквизитов с контролем версии |
| GET | `/documents/{type}/{id}/versions` | История версий, объект items |
| GET | `/documents/{type}/{id}/versions/{version}` | Карточка выбранной версии |
| GET / POST | `/documents/{type}/{id}/attachments` | Список / загрузка; ответ — массив |
| GET / PUT / DELETE | `/attachments/{id}` | Скачать / заменить / исключить из текущего состава |
| GET | `/attachments/{id}/versions` | Массив версий файла младше выбранной |
| POST | `/tasks/search` | Поиск в очереди MY или AVAILABLE |
| GET | `/tasks/summary` | Сводка задач |
| GET | `/tasks/{id}/actions` | Доступные варианты завершения |
| POST | `/tasks/{id}/start` | Взять задачу в исполнение |
| POST | `/tasks/{id}/action` | Выполнить actionCode или parameters варианта |
| GET | `/documents/{type}/{id}/workflow` | Активная задача, действия и исполнитель |

## Документы

Карточка содержит id, typeCode, typeName, attributes, status, statusLabel, сведения о создании, version, currentVersion, changeToken, versionCreatedBy, versionCreatedAt и attachments из выбранного снимка. GET текущей карточки через gateway добавляет workflow, availableActions и executor. GET исторической карточки добавляет workflow текущего процесса; это не снимок исторического процесса.

Поиск принимает query, status, dateFrom, dateTo, offset и limit; возвращает items и total. Общий маршрут обходит оба вида; для ограничения одним видом используйте типизированный маршрут. Типизированный поиск сортирует по дате и номеру договора по убыванию. Диапазон дат принимает YYYY-MM-DD и совместимый DD.MM.YYYY. Поисковая проекция не равнозначна полной карточке с версией и workflow.

Создание ПДС принимает attributes с contractDate, contractNumber и snils. Создание КИД ОПС дополнительно требует UUID requestId и initialAttachment с fileName, contentType, contentBase64. Полный контракт реквизитов — [kid-ops.md](kid-ops.md). initialAttachment — один файл; последующие добавляются через маршрут вложений.

PATCH передаёт только изменяемые реквизиты внутри attributes, а также ожидаемое состояние и ключ повтора:

```json
{
  "attributes": {"contractNumber": "ПДС-002"},
  "expectedVersion": 1,
  "changeToken": "токен из актуальной карточки",
  "requestId": "f67d971f-03c7-4f85-9f0e-77bb1d0a20e4"
}
```

status не является изменяемым реквизитом. Одинаковые нормализованные значения не повышают номер версии. При 409 перечитайте карточку и согласуйте правки; для новой команды используйте новый requestId. При повторе потерянного ответа сохраняйте исходное тело и requestId. Другое тело с прежним ключом отклоняется.

## Файлы

Загрузка принимает:

```json
{
  "requestId": "f67d971f-03c7-4f85-9f0e-77bb1d0a20e4",
  "attachments": [
    {"fileName":"example.txt","contentType":"text/plain","contentBase64":"dGVzdA=="}
  ]
}
```

PUT принимает такой же объект, но ровно с одним файлом. DELETE требует UUID в query-параметре requestId. Для нового независимого действия нужен новый UUID. expectedVersion и changeToken не являются параметрами публичной файловой команды: ожидаемое состояние для пакета читает document-service.

Многофайловая загрузка выполняется последовательно и не атомарна целиком. При повторе сохраняйте порядок и состав attachments вместе с requestId. Состав закрытых версий и бинарные файлы после DELETE сохраняются. DAM и DataSpace не имеют общей транзакции; подробности — [document-versioning.md](document-versioning.md).

## Процессные действия

Доступные параметры берутся из актуальных вариантов формы COMPLETIONS, а не из произвольного нового статуса клиента. Маршрут `/tasks/{id}/action` принимает ID задачи; для совместимости также обрабатывает ID документа, если поиск задачи вернул 404. В этом случае gateway находит активную задачу и возвращает обновлённую карточку в плоском формате клиента с documentTypeId, documentType, status, documentStatus и реквизитами. Другие ошибки поиска задачи не запускают этот fallback.

## Внутренний API

Контракты задают контроллеры [документов](../corelia-document-service/src/main/java/ru/corelia/documents/DocumentController.java), [вложений](../corelia-attachment-service/src/main/java/ru/corelia/attachments/AttachmentController.java), [workflow](../corelia-workflow-service/src/main/java/ru/corelia/workflow/WorkflowController.java) и [auth](../corelia-auth/src/main/java/ru/corelia/identity/IdentityController.java).

Специальные POST-маршруты: `/documents/{type}/{id}/attachment-commands` — только от attachment-service, `/initial-attachments/{id}` — только от document-service. Запуск `/processes/start` передаёт typeCode, documentId, attributes; для КИД ОПС также подготовленное вложение и реквизиты команды создания. Процесс выбирается по DocumentProcessSettings.

Gateway закрывает `/internal/`; публичного выполнения произвольного GraphQL или произвольного URL платформы нет. Источник публичных маршрутов — [CoreController.java](../corelia-gateway/src/main/java/ru/corelia/gateway/CoreController.java).

## API внешней конфигурации и capabilities

- `GET /api/core/v1/document-types` — каталог с прежними code/name/fields и дополнительными schema/ui.
- `GET /api/core/v1/document-types/{type}` — одно публичное определение без storage/workflow internals.
- `GET /api/core/v1/documents/{type}/{id}/capabilities` — `{capabilities: ["EDIT", "ADD_ATTACHMENT", "REPLACE_ATTACHMENT", "DELETE_ATTACHMENT"]}` с актуально допустимым подмножеством. В отсутствие файлов replace/delete не возвращаются. Это предварительный ответ текущей политики; команда повторно проверяет права и платформу.
- `GET /api/core/v1/documents/{type}/{id}/actions` — `{actions: [...], capabilities: [...]}`. Объекты actions получены из текущих options задачи Platform V.
- `POST /api/core/v1/documents/{type}/{id}/actions/{action}` — выполнить доступный код действия текущей задачи и вернуть карточку. Параметры берутся из платформенной option, произвольный payload не используется. Не создаёт новый процесс для новой версии.

Старые маршруты задач сохраняются для совместимости. Ошибка платформы при чтении capabilities не превращается в выданное право; отсутствие capability не заменяет серверный запрет. Полная унификация customer authorization ещё не завершена.
