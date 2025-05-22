#!/usr/bin/env bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# Функции для вывода информации с цветом
info() {
    echo -e "${GREEN}[INFO] $1${PLAIN}"
}

warn() {
    echo -e "${YELLOW}[WARN] $1${PLAIN}"
}

error() {
    echo -e "${RED}[ERROR] $1${PLAIN}"
    exit 1
}

# Проверка на root пользователя
if [ "$EUID" -ne 0 ]; then
    error "Пожалуйста, запустите скрипт с правами root"
fi

# Проверка требований системы
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        error "Не удалось определить операционную систему"
    fi

    case $OS in
        "Ubuntu")
            if [ "$VERSION" != "20.04" ] && [ "$VERSION" != "22.04" ]; then
                error "Неподдерживаемая версия Ubuntu: $OS $VERSION"
            fi
            ;;
        "CentOS Linux")
            if [ "$VERSION" != "7" ] && [ "$VERSION" != "8" ]; then
                error "Неподдерживаемая версия CentOS: $OS $VERSION"
            fi
            ;;
        *)
            error "Неподдерживаемая операционная система: $OS"
            ;;
    esac
}

# Установка зависимостей
install_dependencies() {
    info "Установка необходимых пакетов..."
    if [ "$OS" = "Ubuntu" ]; then
        apt-get update
        apt-get install -y python3-pip python3-venv git nginx supervisor curl
    elif [ "$OS" = "CentOS Linux" ]; then
        yum install -y epel-release
        yum install -y python3-pip python3-venv git nginx supervisor curl
    fi
}

# Создание виртуального окружения Python
create_venv() {
    info "Создание виртуального окружения Python..."
    python3 -m venv /opt/jumpserver/venv
    source /opt/jumpserver/venv/bin/activate
    pip install --upgrade pip
}

# Установка JumpServer
install_jumpserver() {
    info "Установка JumpServer..."
    
    # Создаем директорию для установки
    mkdir -p /opt/jumpserver
    cd /opt/jumpserver
    
    # Скачиваем скрипт установки
    curl -sSL https://github.com/jumpserver/jumpserver/releases/download/v2.28.5/quick_start.sh > quick_start.sh
    chmod +x quick_start.sh
    
    # Запускаем установку
    ./quick_start.sh
    
    # Создаем x-pack директорию и конфигурацию
    mkdir -p /opt/jumpserver/jumpserver/apps/jumpserver/conf/xpack
    cat > /opt/jumpserver/jumpserver/apps/jumpserver/conf/xpack/_xpack.py << EOF
XPACK_ENABLED = True
XPACK_LICENSE_EDITION_ULTIMATE = True
XPACK_LICENSE_IS_VALID = True
EOF
}

# Настройка сервисов
setup_services() {
    info "Настройка системных сервисов..."
    
    # Перезапуск сервисов
    systemctl restart nginx
    systemctl restart supervisor
}

# Основная функция
main() {
    info "Начало установки JumpServer..."
    
    detect_os
    install_dependencies
    create_venv
    install_jumpserver
    setup_services
    
    info "Установка JumpServer завершена!"
    info "Доступ к веб-интерфейсу: http://your-server-ip"
    info "Логин администратора по умолчанию: admin"
    info "Пароль администратора по умолчанию: admin"
    warn "Рекомендуется немедленно изменить пароль по умолчанию!"
}

# Запуск основной функции
main 