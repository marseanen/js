#!/usr/bin/env bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# Версия JumpServer
VERSION="v4.10.1"
DOWNLOAD_URL="https://github.com/jumpserver/installer/releases/download/${VERSION}"

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

# Функция установки пакетов
install_soft() {
    if command -v dnf >/dev/null 2>&1; then
        dnf -q -y install "$1"
    elif command -v yum >/dev/null 2>&1; then
        yum -q -y install "$1"
    elif command -v apt >/dev/null 2>&1; then
        apt-get -qqy install "$1"
    elif command -v zypper >/dev/null 2>&1; then
        zypper -q -n install "$1"
    elif command -v apk >/dev/null 2>&1; then
        apk add -q "$1"
        if ! command -v gettext >/dev/null 2>&1; then
            apk add -q gettext-dev python3
        fi
    else
        echo -e "[\033[31m ERROR \033[0m] $1 command not found, Please install it first"
        exit 1
    fi
}

# Подготовка к установке
prepare_install() {
    for i in curl wget tar iptables; do
        command -v "$i" &>/dev/null || install_soft "$i"
    done
}

# Получение установщика
get_installer() {
    echo "Downloading JumpServer installer ${VERSION}..."
    cd /opt || exit 1
    
    if [ ! -d "/opt/jumpserver-installer-${VERSION}" ]; then
        echo "Downloading from ${DOWNLOAD_URL}/jumpserver-installer-${VERSION}.tar.gz"
        if ! timeout 60 wget -qO "/opt/jumpserver-installer-${VERSION}.tar.gz" "${DOWNLOAD_URL}/jumpserver-installer-${VERSION}.tar.gz"; then
            rm -f "/opt/jumpserver-installer-${VERSION}.tar.gz"
            error "Failed to download jumpserver-installer-${VERSION}. Please check your internet connection and try again."
        fi
        
        echo "Extracting installer..."
        if ! tar -xf "/opt/jumpserver-installer-${VERSION}.tar.gz" -C /opt; then
            rm -rf "/opt/jumpserver-installer-${VERSION}"
            error "Failed to extract jumpserver-installer-${VERSION}. The downloaded file might be corrupted."
        fi
        
        rm -f "/opt/jumpserver-installer-${VERSION}.tar.gz"
        echo "Installer downloaded and extracted successfully."
    else
        echo "Installer directory already exists at /opt/jumpserver-installer-${VERSION}"
    fi
}

# Настройка установщика
config_installer() {
    cd "/opt/jumpserver-installer-${VERSION}" || exit 1
    
    # Настройка x-pack
    echo "Configuring x-pack..."
    cat > .env << EOF
XPACK_ENABLED=${XPACK_ENABLED}
XPACK_LICENSE_EDITION=${XPACK_LICENSE_EDITION}
XPACK_LICENSE_IS_VALID=${XPACK_LICENSE_IS_VALID}
EOF
    
    # Экспортируем переменные окружения
    export XPACK_ENABLED
    export XPACK_LICENSE_EDITION
    export XPACK_LICENSE_IS_VALID
    
    # Запускаем установку
    ./jmsctl.sh install
    ./jmsctl.sh start
}

# Основная функция
main() {
    if [[ "${OS}" == 'Darwin' ]]; then
        echo
        echo "Unsupported Operating System Error"
        exit 1
    fi
    
    echo "Starting JumpServer installation with x-pack settings:"
    echo "- Enabled: ${XPACK_ENABLED}"
    echo "- Edition: ${XPACK_LICENSE_EDITION}"
    echo "- License Valid: ${XPACK_LICENSE_IS_VALID}"
    
    prepare_install
    get_installer
    config_installer
}

main 