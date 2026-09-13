# Контракты API

## Общие правила

Внешний префикс продукта — `/api/core/v1`. Защищённые запросы используют `Authorization: Bearer <access_token>`. Вход, обновление, выход и health доступны без пользовательского токена. Внутренний API `/internal/v1` требует сертификат разрешённого сервиса; кроме health и операций входа — также JWT пользователя.

Ошибка: `{"message":"Описание ошибки"}`. Поддерживаются 400 для некорректного запроса, 401/403 для проверки доступа, 404 для отсутствующего ресурса, 413 для размера тела, 422 для предела выборки, 502/503/504 для ошибок интеграции. Gateway не превращает ошибку платформы в успешный пустой ответ.

## Внешний API продукта

| Метод | Путь | Назначение |
| --- | --- | --- |
| GET | `/health` | Состояние приложения |
| POST | `/auth/login` | `{ "username": "...", "password": "..." }` |
| POST | `/auth/refresh` | `{ "refreshToken": "..." }` |
| POST | `/auth/logout` | `{ "refreshToken": "..." }`, ответ 204 |
| GET | `/auth/me` | Профиль пользователя |
| GET | `/document-types` | Метаданные настроенных типов |
| POST | `/documents/{type}/search` | Поиск карточек |
| POST | `/documents/{type}` | Создание через процесс, ответ 201 |
| GET | `/documents/{type}/{id}` | Карточка с вложениями, если тип их поддерживает |
| PATCH | `/documents/{type}/{id}` | Изменение переданных атрибутов через DataSpace |
| GET / POST | `/documents/{type}/{id}/attachments` | Список / загрузка файлов |
| GET / PUT / DELETE | `/attachments/{id}` | Скачивание / новая версия / удаление метаданных всех версий |
| GET | `/attachments/{id}/versions` | Предыдущие версии |
| POST | `/tasks/search` | `{ "queue": "MY", "query": "...", "status": "STARTED" }` |
| GET | `/tasks/{id}/actions` | Варианты завершения, предоставленные платформой |
| POST | `/tasks/{id}/start` | Взять задачу в исполнение |
| POST | `/tasks/{id}/action` | Выполнить `actionCode` либо точные `parameters` доступного варианта |
| GET | `/documents/{type}/{id}/workflow` | Активная задача, действия и исполнитель карточки |

Карточка:

```json
{
  "id": "публичный UUID",
  "typeCode": "PDS_CONTRACT",
  "typeName": "Договор ПДС",
  "attributes": {
    "contractDate": "2026-09-08",
    "contractNumber": "ПДС-001",
    "snils": "123-456-789 00"
  },
  "status": "CREATED",
  "statusLabel": "Создан"
}
```

GET карточки дополнительно возвращает `attachments`, `workflow`, а также `availableActions` и `executor` на верхнем уровне для стабильного React. История карточки не поддерживается.

Создание и изменение принимают объект `attributes`. Поиск: `query`, `status`, `dateFrom`, `dateTo`, `offset`, `limit`; результат `items`, `total`. Конкретный тип задаётся сегментом пути. Даты диапазона поддерживают `YYYY-MM-DD` и совместимый `DD.MM.YYYY`. Сейчас поддерживается `PDS_CONTRACT`: поиск по полям договора, сортировка по дате и номеру. Коды и подписи статусов описаны в контракте адаптера; доступность действий и полномочия определяет платформа.

Файлы загружаются в JSON-формате:

```json
{
  "attachments": [
    {"fileName":"example.txt","contentType":"text/plain","contentBase64":"dGVzdA=="}
  ]
}
```

PUT создаёт одну новую версию из первого элемента `attachments`. Содержимое остаётся в DAM; удаление вложения удаляет его метаданные в DataSpace, а не физические объекты DAM. Прежние версии доступны по их идентификаторам с повторной проверкой доступа к документу.

## Внутренние вызовы

- Документы: `/document-types`, `/document-types/available`, `/documents/{type}/search`, `/documents/{type}`, `/documents/{type}/{id}`.
- Процессы: `/processes/start`, `/processes/{instanceId}`. Запуск принимает `typeCode`, `documentId`, `attributes`; processId выбирает workflow-service в платформе.
- Задачи: `/tasks/search`, `/tasks/{id}`, `/tasks/{id}/details`, `/tasks/{id}/actions`, `/tasks/{id}/start`, `/tasks/{id}/complete`; названия ролей — `/roles/{role}`.
- Вложения: `/documents/{type}/{id}/attachments`, `/attachments/{id}`, `/attachments/{id}/metadata`, `/attachments/{id}/versions`.
- Авторизация: `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/me`.

Ко всем этим путям добавляется `/internal/v1`. На внешнем gateway этот префикс закрыт. Прямые маршруты к произвольным GraphQL-запросам и URL платформы отсутствуют.
