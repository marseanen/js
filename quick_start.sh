#!/usr/bin/env bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# Версия JumpServer
VERSION="v4.10.1"
DOWNLOAD_URL="https://github.com/jumpserver/jumpserver/releases/download/${VERSION}"

# Настройки x-pack (по умолчанию включен)
XPACK_ENABLED=${XPACK_ENABLED:-"true"}
XPACK_LICENSE_EDITION=${XPACK_LICENSE_EDITION:-"ultimate"}
XPACK_LICENSE_IS_VALID=${XPACK_LICENSE_IS_VALID:-"true"}

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
        apt-get install -y curl wget tar iptables
    elif [ "$OS" = "CentOS Linux" ]; then
        yum install -y epel-release
        yum install -y curl wget tar iptables
    fi
}

# Получение установщика
get_installer() {
    info "Загрузка установщика JumpServer ${VERSION}..."
    
    # Создаем директорию для установки
    mkdir -p /opt/jumpserver-installer-${VERSION}
    cd /opt || exit 1
    
    # Скачиваем установщик
    if [ ! -d "/opt/jumpserver-installer-${VERSION}" ]; then
        timeout 60 wget -qO jumpserver-installer-${VERSION}.tar.gz ${DOWNLOAD_URL}/quick_start.sh || {
            rm -f /opt/jumpserver-installer-${VERSION}.tar.gz
            error "Не удалось загрузить установщик JumpServer"
        }
        
        # Делаем скрипт исполняемым
        chmod +x /opt/jumpserver-installer-${VERSION}.tar.gz
    fi
}

# Настройка и запуск установщика
config_installer() {
    info "Настройка и запуск установщика..."
    cd /opt || exit 1
    
    # Настройка x-pack
    info "Настройка x-pack..."
    cat > /opt/jumpserver-installer-${VERSION}/.env << EOF
XPACK_ENABLED=${XPACK_ENABLED}
XPACK_LICENSE_EDITION=${XPACK_LICENSE_EDITION}
XPACK_LICENSE_IS_VALID=${XPACK_LICENSE_IS_VALID}
EOF
    
    # Запускаем установку
    if [ -f "/opt/jumpserver-installer-${VERSION}.tar.gz" ]; then
        bash /opt/jumpserver-installer-${VERSION}.tar.gz
    else
        error "Установщик не найден"
    fi
}

# Основная функция
main() {
    info "Начало установки JumpServer ${VERSION}..."
    info "Настройки x-pack:"
    info "- Включен: ${XPACK_ENABLED}"
    info "- Издание: ${XPACK_LICENSE_EDITION}"
    info "- Лицензия действительна: ${XPACK_LICENSE_IS_VALID}"
    
    detect_os
    install_dependencies
    get_installer
    config_installer
    
    info "Установка JumpServer завершена!"
    info "Доступ к веб-интерфейсу: http://your-server-ip"
    info "Логин администратора по умолчанию: admin"
    info "Пароль администратора по умолчанию: admin"
    warn "Рекомендуется немедленно изменить пароль по умолчанию!"
}

# Запуск основной функции
main 