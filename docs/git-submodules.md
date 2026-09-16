# Git и подмодули Corelia

Корень хранит сборку, Compose, скрипты и документацию, а также gitlinks восьми модулей: corelia-common, corelia-platform-v, corelia-auth, corelia-document-service, corelia-workflow-service, corelia-attachment-service, corelia-gateway, corelia-system-tests.

Удалённый адрес корня — `git@github.com:ilyabaykalov-corelia/corelia.git`. Адреса модулей в [.gitmodules](../.gitmodules) указывают на отдельные SSH-репозитории той же организации. Для получения кода нужен соответствующий доступ к GitHub.

```bash
git clone --recurse-submodules git@github.com:ilyabaykalov-corelia/corelia.git
cd corelia
git submodule status --recursive
```

После изменения адресов или переключения состава, предварительно сохранив локальные изменения:

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

update получает записанные родителем коммиты, не последние коммиты веток. Подмодули могут находиться в detached HEAD; перед разработкой выберите рабочую ветку. Не используйте --force для обхода локальных изменений.

## Согласованные изменения

Сначала проверить и закоммитить изменения внутри затронутых модулей, затем обновить gitlinks одним коммитом корня. Общая документация и конфигурация коммитятся в корне; README конкретного модуля — в его репозитории.

```bash
git status --short
git submodule foreach --recursive 'git status --short'
```

Публиковать сначала коммиты модулей, затем родительский состав. `git push --recurse-submodules=check` помогает обнаружить недоступные ссылки. Публикация только корня не публикует историю модулей.

Не удалять корневую .git: там находятся административные данные подмодулей. .env, .local, ключи и результаты сборки не входят в переносимый исходный состав. Сборка Maven и Docker использует пути модулей внутри корня.
