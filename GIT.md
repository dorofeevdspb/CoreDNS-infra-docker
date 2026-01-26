
`    ./GIT.md    `

```sh

 git config --local push.followTags true
 git config --local commit.gpgsign true


```

# Git Flow: быстрая шпаргалка

## Базовая инициализация
- Настроить Git Flow (ответы по умолчанию: `master`, `develop`, `feature-`, `release-/`, `hotfix-`, `support-`, `versiontag-`):

```bash
git flow init
```

## Жизненный цикл веток

### Фичи
- Начать фичу от `develop`:

```bash
git flow feature start -{taskname}
```

- Пушим фичу для совместной работы:

```bash
git push -u origin feature/-{taskname}
```

- Завершить фичу (merge в `develop`, удаление ветки локально):

```bash
git flow feature finish -{taskname}
```

- Опционально после финиша удалить ветку на origin (если finish не сделал этого автоматически):

```bash
git push origin --delete feature/-{taskname}
```

### Релизы
- Начать релиз от `develop`:

```bash
git flow release start 0.0.0
```

- Правим, тестируем, фиксируем. Публикация черновика релиза на origin:

```bash
git flow release publish 0.0.0
```

- Завершить релиз (merge в `master` и `develop`, тегирование):

```bash
git flow release finish 0.0.0
git push origin master develop --tags
```

### Хотфиксы
- Начать хотфикс от `master`:

```bash
git flow hotfix start 0.0.0
```

- После фиксов завершить (merge в `master` и `develop`, тегирование):

```bash
git flow hotfix finish 0.0.0
git push origin master develop --tags
```

## Практические советы
- Всегда создавайте issue-ключ в имени ветки: `feature/{taskname}-short-title`.
- Перед `finish` убедитесь, что ветка актуальна: `git fetch --all` и `git rebase origin/develop` (или `origin/master` для hotfix).
- При конфликте во время `finish` остановите процесс, решите конфликты, завершите merge вручную и продолжите: `git flow feature finish {taskname}` повторно или обычный `git merge` + `git branch -d`.
- Для повторяемых шагов используйте хуки: `hooks/post-flow-finish` и др., чтобы автоматически пушить или запускать проверки.
- Проверяйте теги: после `finish` убедитесь, что нужные теги отправлены (`git push --tags`).

## Быстрые команды (подсмотрщик)
- Список активных фич: `git flow feature list`
- Список релизов: `git flow release list`
- Список хотфиксов: `git flow hotfix list`
- Отмена незавершённого `finish`: используйте обычные команды Git (`git merge --abort` или `git reset --merge`) в зависимости от стадии.
