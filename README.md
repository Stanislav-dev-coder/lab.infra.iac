# lab.infra.iac

Учебный стенд на виртуальных машинах Incus с GitLab, CI, мониторингом и HTTPS, который поднимается кодом Terraform и Ansible. В стенд входят роутер с Traefik и NAT, GitLab с Registry и runner, Prometheus с Grafana и приложение, а все значения хранятся в инвентаре Ansible. Стенд пересоздаваемый, при `make destroy` данные GitLab, Grafana и Prometheus уничтожаются полностью.

## Цель и задачи

Цель: описать базовую инфраструктуру с помощью кода.

Задачи

- Cloud-образ Ubuntu 26.04 с проверкой GPG-подписи и SHA256, первичная настройка через cloud-init
- Сети `lab_10` с NAT и приватная `lab_20`, DHCP и DNS-зона стенда в dnsmasq Incus
- Роутер как NAT-инстанс и бастион
- ACL Incus на картах
- Инвентарь Ansible как единственный источник истины
- Traefik с wildcard-сертификатом по DNS-01, бэкап `acme.json`
- Модули Ansible и сервисы в Docker Compose из шаблонов
- Дашборд, источник данных и алерты Grafana файлами provisioning
- Первичная настройка GitLab и runner в стиле IaC
- Деплой приложения с помощью Ansible

## Стек

| Технология     | Версия | Назначение                             |
| -------------- | ------ | -------------------------------------- |
| Incus          | 7.5.1  | ВМ, сети, ACL, DHCP и DNS              |
| Ubuntu         | 26.04  | ОС машин, cloud-init                   |
| Terraform      | 1.15   | Платформа и настройки GitLab           |
| Ansible core   | 2.21   | Конфигурация машин и деплой приложения |
| nftables       | 1.1.6  | NAT и входящие правила роутера         |
| Traefik        | 3.7.15 | Reverse proxy, ACME по DNS-01          |
| Docker         | 29.9   | Сервисы на машинах за роутером         |
| Docker Compose | 5.6    | Описание сервисов в шаблонах           |
| Grafana        | 13.2.4 | Дашборды и алерты                      |
| Prometheus     | 3.15.0 | Сбор метрик                            |
| node_exporter  | 1.12.1 | Метрики машин                          |
| GitLab CE      | 19.5.0 | Git, CI, Container Registry            |

## Архитектура

```
                     Хост
                      │  https://*.lab.<домен>, SSH
                      ▼
 lab_10 10.10.0.0/24  ─┬──────────────────────────────────────────
                       │ 10.10.0.2
                ┌──────┴───────────────────────────┐
                │ router                           │
                │ Traefik :80 :443  ─► бэкенды     │
                │ nftables NAT lab_20 → lab_10     │
                │ бастион SSH                      │
                └──────┬───────────────────────────┘
                       │ 10.20.0.2
 lab_20 10.20.0.0/24  ─┴──────┬──────────┬──────────┬──────────
                              │          │          │          │
                            app       gitlab   monitoring   runner
                         10.20.0.10 10.20.0.11 10.20.0.12 10.20.0.13
                           :8080   :80 :5050    :3000
                                   :2222
```

| Машина     | vCPU | RAM  | Диск  |
| ---------- | ---- | ---- | ----- |
| router     | 1    | 1 ГБ | 5 ГБ  |
| app        | 1    | 1 ГБ | 5 ГБ  |
| gitlab     | 6    | 8 ГБ | 20 ГБ |
| monitoring | 2    | 4 ГБ | 15 ГБ |
| runner     | 2    | 2 ГБ | 15 ГБ |

## Требования

- Linux с Incus 7.5.1, `incus admin init`, пользователь в `incus-admin`
- Terraform 1.15, Ansible core 2.21, Python 3, `gpgv`, `openssl`, `btrfs-progs`
- 16 ГБ RAM и 60 ГиБ диска
- Зона в Timeweb Cloud с записью `A *.lab` → `10.10.0.2` и токен API
- Репозиторий [lab.infra.app](https://github.com/Stanislav-dev-coder/lab.infra.app) для пайплайна

## Развёртывание

1. Клонирование

```bash
git clone https://github.com/Stanislav-dev-coder/lab.infra.iac.git
cd lab.infra.iac
```

2. SSH-ключи

`ubuntu-cloud` для Ansible, попадает в cloud-init. `lab-gitlab` для git, Terraform добавляет его root в GitLab.

```bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/ubuntu-cloud
ssh-keygen -t ed25519 -N '' -f ~/.ssh/lab-gitlab
```

3. Секреты

```bash
cp .env.example .env
sed -i "s/^GITLAB_ADMIN_TOKEN=.*/GITLAB_ADMIN_TOKEN=glpat-$(openssl rand -hex 20)/" .env
vi .env
```

В `.env` вписываются токен Timeweb Cloud, почта ACME и пароли Grafana и root GitLab. Слабый пароль GitLab не примет.

4. Инвентарь

Другой домен или ключ меняются в `domain` и `ssh_key` в `inventory.yml`.

5. Зависимости

```bash
make init
```

Коллекции Ansible, провайдеры Terraform, образ Ubuntu 26.04 с проверкой GPG-подписи и SHA256.

6. Платформа

```bash
make apply
```

Образ, пул, сети, ACL и пять ВМ.

7. Конфигурация

```bash
make deploy
```

Роутер, Docker, мониторинг, GitLab, его настройки и runner. Сертификат выпускается около 10 минут, бэкап `acme.json` с ним появится при следующем `make deploy`.

8. Приложение

В `~/.ssh/config` добавляется доступ к GitLab через бастион.

```text
Host router
    HostName 10.10.0.2
    User ubuntu
    IdentityFile ~/.ssh/ubuntu-cloud

Host gitlab.lab.<домен>
    HostName gitlab.incus
    Port 2222
    User git
    IdentityFile ~/.ssh/lab-gitlab
    ProxyJump router
```

Код пушится в `root/app` с тегом из `app_version`.

```bash
git clone https://github.com/Stanislav-dev-coder/lab.infra.app.git
cd lab.infra.app
git remote add gitlab ssh://git@gitlab.lab.<домен>:2222/root/app.git
git push gitlab main
git tag v1.0.0
git push gitlab v1.0.0
```

9. Деплой приложения

```bash
make rollout
```

Плейбук ждёт образ в Registry и запускает приложение.

10. Проверка

```bash
make plan
make check
curl https://app.lab.<домен>
```

Новая версия приложения деплоится тегом, сменой `app_version` в инвентаре и `make rollout`.

Пересборка с нуля выполняется через `make destroy`, `make forget` и шаги 6–9.

## Команды

```bash
# Окружение
make init       Установка зависимостей
make format     Форматирование и проверка синтаксиса

# Инфраструктура
make apply      Создание инфраструктуры
make plan       Состояние инфраструктуры
make output     Выходные значения Terraform
make destroy    Удаление всей инфраструктуры

# Конфигурация
make deploy     Настройка машин
make rollout    Деплой приложения
make check      Проверка состояния

# Очистка
make forget     Удаление отпечатков машин из known_hosts
make clean      Очистка зависимостей
make purge      Полная очистка проекта
```

Точечные запуски делаются из каталогов, например:

```bash
terraform -chdir=terraform/platform plan
```

```bash
cd ansible/
ansible-playbook playbooks/router.yml
```
