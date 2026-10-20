IMAGE_URL := https://cloud-images.ubuntu.com/releases/resolute/release-20260927
IMAGE := ubuntu-26.04-server-cloudimg-amd64.img
FILES := terraform/platform/files
PLATFORM := terraform -chdir=terraform/platform
GITLAB := terraform -chdir=terraform/gitlab

.DEFAULT_GOAL := help
.PHONY: help init format apply plan output destroy deploy rollout check forget clean purge

help:
	@echo "🔧 Окружение:"
	@echo "   make init       Установка зависимостей"
	@echo "   make format     Форматирование и проверка синтаксиса"
	@echo ""
	@echo "🏗️ Инфраструктура:"
	@echo "   make apply      Создание инфраструктуры"
	@echo "   make plan       Состояние инфраструктуры"
	@echo "   make output     Выходные значения Terraform"
	@echo "   make destroy    Удаление всей инфраструктуры"
	@echo ""
	@echo "📋 Конфигурация:"
	@echo "   make deploy     Настройка машин"
	@echo "   make rollout    Деплой приложения"
	@echo "   make check      Проверка состояния"
	@echo ""
	@echo "🧹 Очистка:"
	@echo "   make forget     Удаление отпечатков машин из known_hosts"
	@echo "   make clean      Очистка зависимостей"
	@echo "   make purge      Полная очистка проекта"
	@echo ""

init:
	@echo "🔧 Установка зависимостей..."
	@command -v terraform >/dev/null || { echo "❌ Нет terraform"; exit 1; }
	@command -v ansible-playbook >/dev/null || { echo "❌ Нет ansible"; exit 1; }
	@command -v gpgv >/dev/null || { echo "❌ Нет gpgv"; exit 1; }
	@cd ansible && ansible-galaxy collection install -r requirements.yml
	@$(PLATFORM) init
	@$(GITLAB) init
	@cd $(FILES) && curl -fsSLO $(IMAGE_URL)/SHA256SUMS && curl -fsSLO $(IMAGE_URL)/SHA256SUMS.gpg
	@cd $(FILES) && gpgv --keyring ./ubuntu-cloud.gpg SHA256SUMS.gpg SHA256SUMS
	@cd $(FILES) && test -f $(IMAGE) || curl -fL -o $(IMAGE) $(IMAGE_URL)/$(IMAGE)
	@cd $(FILES) && sha256sum -c --ignore-missing SHA256SUMS
	@cd $(FILES) && test -f metadata.tar.xz || tar -cJf metadata.tar.xz metadata.yaml

format:
	@echo "🎨 Форматирование и проверка синтаксиса..."
	@terraform fmt -recursive terraform
	@$(PLATFORM) validate
	@$(GITLAB) validate
	@cd ansible && ansible-playbook site.yml --syntax-check

apply:
	@echo "🏗️ Создание инфраструктуры..."
	@test -f $(FILES)/$(IMAGE) || { echo "❌ Нет образа, выполни make init"; exit 1; }
	@$(PLATFORM) apply

plan:
	@echo "📊 Состояние инфраструктуры..."
	@$(PLATFORM) plan
	@$(GITLAB) plan

output:
	@echo "📤 Выходные значения Terraform..."
	@$(PLATFORM) output
	@$(GITLAB) output

destroy:
	@echo "💥 Удаление всей инфраструктуры..."
	@$(PLATFORM) destroy
	@rm -f terraform/gitlab/terraform.tfstate terraform/gitlab/terraform.tfstate.backup

deploy:
	@echo "📋 Настройка машин..."
	@test -f .env || { echo "❌ Нет .env, скопируй .env.example"; exit 1; }
	@cd ansible && ansible-playbook site.yml

rollout:
	@echo "🚀 Деплой приложения..."
	@test -f terraform/gitlab/terraform.tfstate || { echo "❌ Нет настроек GitLab, выполни make deploy"; exit 1; }
	@cd ansible && ansible-playbook playbooks/app.yml

check:
	@echo "🔍 Проверка состояния..."
	@cd ansible && ansible all -m ping
	@cd ansible && ansible-playbook site.yml --check --diff

forget:
	@echo "🧽 Удаление отпечатков машин из known_hosts..."
	@cd ansible && ansible all -c local -f 1 -m ansible.builtin.known_hosts -a 'name={{ ansible_host }} state=absent'
	@ssh-keygen -R '[gitlab.incus]:2222'

clean:
	@echo "🧹 Очистка зависимостей..."
	@rm -rf ansible/collections terraform/platform/.terraform terraform/gitlab/.terraform

purge:
	@read -p "⚠️ Удалить зависимости и скачанный образ? [y/N] " answer && [ "$$answer" = "y" ]
	@$(MAKE) clean
	@echo "🗑️ Удаление скачанного образа..."
	@rm -f $(FILES)/$(IMAGE) $(FILES)/SHA256SUMS $(FILES)/SHA256SUMS.gpg $(FILES)/metadata.tar.xz
