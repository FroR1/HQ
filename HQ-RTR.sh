#!/bin/bash

# Скрипт настройки ISP

# Проверка запуска от имени root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: Этот скрипт должен быть запущен от имени root." >&2
    exit 1
fi

# Файл логов
LOG_FILE="/var/log/isp_config.log"

# Установка зависимостей
install_dependencies() {
    echo "Установка зависимостей..."
    apt-get update
    apt-get install -y iproute2 nftables systemd locales
    chmod 644 "$LOG_FILE" 2>/dev/null || { echo "Ошибка: Не удалось установить права на файл логов." >&2; exit 1; }
    echo "Зависимости установлены."
}

# Функция логирования
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
    echo "$1"
}

# Инициализация файла логов
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE" 2>/dev/null || { echo "Ошибка: Не удалось создать файл логов в $LOG_FILE." >&2; exit 1; }
fi

install_dependencies

# Начальные значения переменных
INTERFACE_HQ="ens256"
INTERFACE_BR="ens224"
INTERFACE_OUT="ens192"
IP_HQ="172.16.40.1/28"
IP_BR="172.16.50.1/28"
HOSTNAME="isp"
TIME_ZONE="Asia/Novosibirsk"

# Функция проверки существования интерфейса
check_interface() {
    if ! ip link show "$1" &>/dev/null; then
        log_message "Ошибка: Интерфейс $1 не существует."
        exit 1
    fi
}

# Функция валидации IP-адреса
validate_ip() {
    local ip_with_mask=$1
    if [[ $ip_with_mask =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        local ip=$(echo "$ip_with_mask" | cut -d'/' -f1)
        local prefix=$(echo "$ip_with_mask" | cut -d'/' -f2)
        if [[ $ip =~ ^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$ ]] && [ "$prefix" -ge 0 ] && [ "$prefix" -le 32 ]; then
            return 0
        fi
    fi
    return 1
}

# Функция вычисления сети из IP и маски
get_network() {
    local ip_with_mask=$1
    if ! [[ $ip_with_mask =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]{1,2})$ ]]; then
        log_message "Ошибка: Неверный формат IP: $ip_with_mask"
        return 1
    fi
    local ip=$(echo "$ip_with_mask" | cut -d'/' -f1)
    local prefix=$(echo "$ip_with_mask" | cut -d'/' -f2)
    if [ "$prefix" -lt 0 ] || [ "$prefix" -gt 32 ]; then
        log_message "Ошибка: Неверный префикс: $prefix (должен быть 0-32)"
        return 1
    fi
    IFS='.' read -r oct1 oct2 oct3 oct4 <<< "$ip"
    for oct in $oct1 $oct2 $oct3 $oct4; do
        if [ "$oct" -lt 0 ] || [ "$oct" -gt 255 ]; then
            log_message "Ошибка: Неверный октет: $oct (должен быть 0-255)"
            return 1
        fi
    done
    local ip_num=$(( (oct1 << 24) + (oct2 << 16) + (oct3 << 8) + oct4 ))
    local bits=$((32 - prefix))
    local mask=$(( (0xffffffff << bits) & 0xffffffff ))
    local net_num=$((ip_num & mask))
    local net_oct1=$(( (net_num >> 24) & 0xff ))
    local net_oct2=$(( (net_num >> 16) & 0xff ))
    local net_oct3=$(( (net_num >> 8) & 0xff ))
    local net_oct4=$(( net_num & 0xff ))
    echo "${net_oct1}.${net_oct2}.${net_oct3}.${net_oct4}/${prefix}"
}

# Функция настройки сетевых интерфейсов через /etc/net/ifaces/
configure_interfaces() {
    log_message "Настройка интерфейсов через /etc/net/ifaces/..."
    
    check_interface "$INTERFACE_HQ"
    check_interface "$INTERFACE_BR"
    check_interface "$INTERFACE_OUT"

    for iface in "$INTERFACE_HQ" "$INTERFACE_BR"; do
        mkdir -p "/etc/net/ifaces/$iface"
        cat > "/etc/net/ifaces/$iface/options" << EOF
BOOTPROTO=static
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
EOF
        if [ "$iface" = "$INTERFACE_HQ" ]; then
            echo "$IP_HQ" > "/etc/net/ifaces/$iface/ipv4address"
        elif [ "$iface" = "$INTERFACE_BR" ]; then
            echo "$IP_BR" > "/etc/net/ifaces/$iface/ipv4address"
        fi
    done

    systemctl restart network
    log_message "Интерфейсы $INTERFACE_HQ и $INTERFACE_BR настроены."
}

# Функция настройки nftables и пересылки IP
configure_nftables() {
    log_message "Настройка nftables и пересылки IP..."
    
    if [ -z "$IP_HQ" ] || [ -z "$IP_BR" ] || [ -z "$INTERFACE_OUT" ]; then
        log_message "Ошибка: IP-адреса или исходящий интерфейс не заданы."
        exit 1
    fi

    HQ_NETWORK=$(get_network "$IP_HQ") || { log_message "Ошибка: Не удалось вычислить сеть HQ."; exit 1; }
    BR_NETWORK=$(get_network "$IP_BR") || { log_message "Ошибка: Не удалось вычислить сеть BR."; exit 1; }
    log_message "Сеть HQ: $HQ_NETWORK"
    log_message "Сеть BR: $BR_NETWORK"

    sysctl -w net.ipv4.ip_forward=1
    if grep -q "net.ipv4.ip_forward" /etc/net/sysctl.conf; then
        sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/net/sysctl.conf
    else
        echo "net.ipv4.ip_forward=1" >> /etc/net/sysctl.conf
    fi

    cat > /etc/nftables/nftables.nft << EOF
#!/usr/sbin/nft -f
flush ruleset

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 0; policy accept;
        ip saddr $HQ_NETWORK oifname "$INTERFACE_OUT" counter masquerade
        ip saddr $BR_NETWORK oifname "$INTERFACE_OUT" counter masquerade
    }
}
EOF

    nft -f /etc/nftables/nftables.nft
    systemctl enable --now nftables
    log_message "nftables и пересылка IP настроены."
}

# Функция установки имени хоста
set_hostname() {
    log_message "Установка имени хоста..."
    hostnamectl set-hostname "$HOSTNAME"
    echo "$HOSTNAME" > /etc/hostname
    log_message "Имя хоста установлено: $HOSTNAME"
}

# Функция установки часового пояса
set_timezone() {
    log_message "Установка часового пояса..."
 timedatectl set-timezone "$TIME_ZONE"
    log_message "Часовой пояс установлен: $TIME_ZONE"
}

# Функция настройки русского языка
configure_russian_locale() {
    log_message "Настройка русского языка (ru_RU.UTF-8)..."
    if ! locale -a | grep -q "ru_RU.utf8"; then
        log_message "Русский язык не найден. Установка и генерация..."
        apt-get install -y locales
        echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
        locale-gen ru_RU.UTF-8
        update-locale LANG=ru_RU.UTF-8
        log_message "Русский язык (ru_RU.UTF-8) настроен."
    else
        log_message "Русский язык (ru_RU.UTF-8) уже настроен."
    fi
}

# Функция редактирования данных
edit_data() {
    while true; do
        clear
        echo "Текущие значения:"
        echo "1. Интерфейс HQ: $INTERFACE_HQ"
        echo "2. Интерфейс BR: $INTERFACE_BR"
        echo "3. Интерфейс для выхода в интернет: $INTERFACE_OUT"
        echo "4. IP для HQ: $IP_HQ"
        echo "5. IP для BR: $IP_BR"
        echo "6. Имя хоста: $HOSTNAME"
        echo "7. Часовой пояс: $TIME_ZONE"
        echo "0. Назад"
        read -p "Введите номер параметра для изменения: " choice
        case $choice in
            1) read -p "Новый интерфейс HQ [$INTERFACE_HQ]: " input
               INTERFACE_HQ=${input:-$INTERFACE_HQ} ;;
            2) read -p "Новый интерфейс BR [$INTERFACE_BR]: " input
               INTERFACE_BR=${input:-$INTERFACE_BR} ;;
            3) read -p "Новый интерфейс для выхода в интернет [$INTERFACE_OUT]: " input
               INTERFACE_OUT=${input:-$INTERFACE_OUT} ;;
            4) while true; do
                   read -p "Новый IP для HQ [$IP_HQ]: " input
                   input=${input:-$IP_HQ}
                   if validate_ip "$input"; then
                       IP_HQ=$input
                       break
                   else
                       echo "Неверный формат IP. Используйте формат, например, 172.16.4.1/28."
                   fi
               done ;;
            5) while true; do
                   read -p "Новый IP для BR [$IP_BR]: " input
                   input=${input:-$IP_BR}
                   if validate_ip "$input"; then
                       IP_BR=$input
                       break
                   else
                       echo "Неверный формат IP. Используйте формат, например, 172.16.5.1/28."
                   fi
               done ;;
            6) read -p "Новый hostname [$HOSTNAME]: " input
               HOSTNAME=${input:-$HOSTNAME} ;;
            7) read -p "Новый часовой пояс [$TIME_ZONE]: " input
               TIME_ZONE=${input:-$TIME_ZONE} ;;
            0) return ;;
            *) echo "Неверный выбор." ;;
        esac
    done
}

# Основное меню
while true; do
    clear
    echo -e "\nМеню настройки ISP:"
    echo "1. Редактировать данные"
    echo "2. Настроить сетевые интерфейсы"
    echo "3. Настроить NAT и пересылку IP"
    echo "4. Установить имя хоста"
    echo "5. Установить часовой пояс"
    echo "6. Настроить русский язык"
    echo "7. Выполнить все настройки"
    echo "0. Выход"
    read -p "Выберите опцию: " option
    case $option in
        1) edit_data ;;
        2) configure_interfaces ;;
        3) configure_nftables ;;
        4) set_hostname ;;
        5) set_timezone ;;
        6) configure_russian_locale ;;
        7) 
            configure_russian_locale
            configure_interfaces
            configure_nftables
            set_hostname
            set_timezone
            log_message "Все настройки выполнены."
            ;;
        0) log_message "Выход."; exit 0 ;;
        *) echo "Неверный выбор." ;;
    esac
done
