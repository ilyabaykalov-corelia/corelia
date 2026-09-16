# Проверка миграции внешней конфигурации

2026-09-16. Локальная реализация, без установки на Platform V и без push.

## Изменение

Внешний registry/schema/UI/storage/workflow package; отдельный compiler; generic документная политика и mapping; статические операции вынесены из JAR в customer repo. Добавлены catalog definition, capabilities и actions API; React получает доступность редактирования из ядра. Старые процессы без documentType в задаче определяют вид по связанному документу.

## Проверки

- `mvn -B -ntp clean verify` — успешная чистая сборка после удаления старых ресурсов.
- Последний `bash scripts/test.sh`, 16:22 МСК — BUILD SUCCESS: 7 configuration tests, 1 compiler test, 55 system-module tests (1 Docker smoke skipped). Всего 62 выполнено, failures/errors 0, skipped 1.
- `npm --prefix ../sber-npf-react run build` и `run lint` — успешно. Vite сообщает о крупных chunks; новых зависимостей клиента не добавлялось.
- CLI compiler успешно выдаёт runtime package, точный permissions fragment, fixtures и воспроизводимый manifest. Тест сравнивает тела и права с существующей моделью СберНПФ.
- Проверены семь продуктовых JAR: в class-файлах нет PDS_CONTRACT/KID_OPS/PdsContract/KidOps, в адаптере нет .graphql. Конфигурация монтируется read-only, не включается в образ.

Локальные системные тесты запускались с localhost-портами и Mockito agent после разрешения среды; используется PlatformStub, не рабочий стенд.

## Границы

Capabilities пока опираются на существующую политику ядра. Единый источник customer authorization ещё не реализован; удалять текущие проверки нельзя. React ещё содержит специализированные формы и процессные представления. Fixture tests двух заказчиков проверяют классы/адаптеры/протокол, но не являются полноценным proof of configurability на двух Platform V-развёртываниях. Docker smoke, реальный SDK/permissions/BPM и визуальная проверка клиента не выполнялись.

## Локальные коммиты компонентов

| Репозиторий | Коммит |
|---|---|
| sber-npf-corelia-config | `0db0ee7` |
| corelia/corelia-common | `6058f4e` |
| corelia/corelia-platform-v | `c27576f` |
| corelia/corelia-document-service | `b30461a` |
| corelia/corelia-workflow-service | `55d6db0` |
| corelia/corelia-attachment-service | `0a31824` |
| corelia/corelia-gateway | `3863892` |
| corelia/corelia-system-tests | `dd38535` |
| sber-npf-react | `8439379` |

Полный актуальный журнал и оставшиеся этапы: `task completion progress.md` в общей рабочей папке.

## Продолжение: авторизация, интерфейс, контейнеры

Единый ac.json поставляется адаптеру и Platform V; document-service использует generic permission checker и metadata статуса/исполнителя. Клиент corelia-web строит формы и реестр из схем; рабочий каталог sber-npf-react сохранён.

Обычный backend-прогон: 65 успешных тестов, один Docker smoke пропущен. Отдельный контейнерный прогон 23:10 МСК: два DockerSmokeTest успешны. Первый проверяет сценарий СберНПФ; второй запускает 2 и 5 видов с одинаковыми image IDs, читает каталог и проверяет запрет создания для чужой роли. Смена каталога не пересобирает образы. Тестовый Compose удалён.

Клиент: lint/build успешны, 3 контрактных теста успешны; браузерные проверки обоих UI-каталогов и создания/редактирования boolean-карточки. Новый CLI-выпуск sber-4 проверен; регрессия подтверждает корректность исходных patterns ПДС.

Ограничение: Docker catalog test не исполняет полноценные операции customer-a/b; необходимые для startup общие операции взяты из миграционного пакета. Самостоятельные платформенные модели, BPMN, файлы и CAS для двух заказчиков требуют дальнейшей работы. Это не полный proof of configurability и не тест реального Platform V.
