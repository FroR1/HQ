#!/bin/bash

# Скрипт для настройки сервера HQ-SRV

# Установка зависимостей
install_dependencies() {
    echo "Установка зависимостей..."
    apt-get update
    apt-get install -y bind9 bind9-utils openssh-server systemd mc wget tzdata resolvconf
    echo "Зависимости установлены."
}

# Начальные значения переменных (замените на ваши реальные значения)
HOSTNAME="hq-srv.au-team.irpo"
TIME_ZONE="Asia/Novosibirsk"
USERNAME="net_admin"
USER_UID=1010
BANNER_TEXT="Authorized access only"
SSH_PORT=22
DNS_ZONE="au-team.irpo"
DNS_FILE="au-team.irpo.db"
REVERSE_ZONE_SRV="10.168.192.in-addr.arpa"
REVERSE_FILE_SRV="192.168.10.db"
REVERSE_ZONE_CLI="20.168.192.in-addr.arpa"
REVERSE_FILE_CLI="192.168.20.db"
IP_HQ_RTR="192.168.10.1"
IP_HQ_SRV="192.168.10.2"
IP_HQ_CLI="192.168.20.10"
IP_BR_RTR="172.16.77.2"
IP_BR_SRV="172.16.15.2"

# Функция настройки DNS (BIND)
configure_dns() {
    echo "Настройка DNS..."
    
    # Установка BIND и утилит
    apt-get install -y bind9 bind9-utils
    systemctl enable --now bind9
    
    # Создание или перезапись /etc/bind/options.conf с правильными настройками
    cat > /etc/bind/options.conf << EOF
options {
    listen-on { any; };
    // listen-on-v6 { any; };
    forward first;
    forwarders { 77.88.8.8; };
    allow-query { any; };
};
EOF

    # Настройка зон в /etc/bind/named.conf.local
    cat > /etc/bind/named.conf.local << EOF
zone "$DNS_ZONE" {
    type master;
    file "/etc/bind/$DNS_FILE";
};

zone "$REVERSE_ZONE_SRV" {
    type master;
    file "/etc/bind/$REVERSE_FILE_SRV";
};

zone "$REVERSE_ZONE_CLI" {
    type master;
    file "/etc/bind/$REVERSE_FILE_CLI";
};
EOF

    # Создание файла зоны прямого DNS
    cat > /etc/bind/"$DNS_FILE" << EOF
\$TTL  1D
@    IN    SOA  $DNS_ZONE. root.$DNS_ZONE. (
                2025020600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; ncache
            )
        IN    NS       $DNS_ZONE.
        IN    A        127.0.0.1
hq-rtr  IN    A        $IP_HQ_RTR
br-rtr  IN    A        $IP_BR_RTR
hq-srv  IN    A        $IP_HQ_SRV
hq-cli  IN    A        $IP_HQ_CLI
br-srv  IN    A        $IP_BR_SRV
moodle  IN    CNAME    hq-rtr
wiki    IN    CNAME    hq-rtr
EOF

    # Создание файла зоны обратного DNS для 192.168.10.0/26
    cat > /etc/bind/"$REVERSE_FILE_SRV" << EOF
\$TTL  1D
@    IN    SOA  $DNS_ZONE. root.$DNS_ZONE. (
                2025020600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; ncache
            )
     IN    NS     $DNS_ZONE.
1    IN    PTR    hq-rtr.$DNS_ZONE.
2    IN    PTR    hq-srv.$DNS_ZONE.
EOF

    # Создание файла зоны обратного DNS для 192.168.20.0/28
    cat > /etc/bind/"$REVERSE_FILE_CLI" << EOF
\$TTL  1D
@    IN    SOA  $DNS_ZONE. root.$DNS_ZONE. (
                2025020600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; ncache
            )
     IN    NS     $DNS_ZONE.
10   IN    PTR    hq-cli.$DNS_ZONE.
EOF

    # Проверка синтаксиса конфигурации и зон
    named-checkconf
    named-checkzone "$DNS_ZONE" /etc/bind/"$DNS_FILE"
    named-checkzone "$REVERSE_ZONE_SRV" /etc/bind/"$REVERSE_FILE_SRV"
    named-checkzone "$REVERSE_ZONE_CLI" /etc/bind/"$REVERSE_FILE_CLI"
    
    # Перезапуск службы BIND
    systemctl restart bind9
    echo "DNS настроен."
}

# Функция настройки /etc/resolvconf.conf
configure_resolv() {
    echo "Настройка /etc/resolvconf.conf..."
    echo "name_servers=127.0.0.1" >> /etc/resolv.conf
    resolvconf -u
    echo "Проверка интернета..."
    cat /etc/resolv.conf
    ping -c 4 77.88.8.8
    echo "/etc/resolvconf.conf настроен и проверка интернета выполнена."
}

# Функция установки имени хоста
set_hostname() {
    echo "Установка имени хоста..."
    hostnamectl set-hostname "$HOSTNAME"
    echo "$HOSTNAME" > /etc/hostname
    echo "Имя хоста установлено: $HOSTNAME"
}

# Функция установки часового пояса
set_timezone() {
    echo "Установка часового пояса..."
    apt-get install -y tzdata
    timedatectl set-timezone "$TIME_ZONE"
    echo "Часовой пояс установлен: $TIME_ZONE"
}

# Функция настройки пользователя
configure_user() {
    echo "Настройка пользователя..."
    if adduser --uid "$USER_UID" "$USERNAME"; then
        read -s -p "Введите пароль для пользователя $USERNAME: " PASSWORD
        echo
        echo "$USERNAME:$PASSWORD" | chpasswd
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
        usermod -aG wheel "$USERNAME"
        echo "Пользователь $USERNAME создан с UID $USER_UID и правами sudo."
    else
        echo "Ошибка: Не удалось создать пользователя $USERNAME."
        exit 1
    fi
}

# Функция настройки SSH (порт и баннер)
configure_ssh() {
    echo "Настройка SSH..."
    
    # Настройка порта SSH
    if grep -q "^Port" /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    else
        echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
    fi
    
    # Настройка баннера SSH
    echo "$BANNER_TEXT" > /etc/banner
    if grep -q "^Banner" /etc/ssh/sshd_config; then
        sed -i 's|^Banner.*|Banner /etc/banner|' /etc/ssh/sshd_config
    else
        echo "Banner /etc/banner" >> /etc/ssh/sshd_config
    fi
    
    systemctl restart sshd
    echo "SSH настроен (порт: $SSH_PORT, баннер установлен)."
}

# Основное меню
while true; do
    clear
    echo -e "\nМеню настройки HQ-SRV:"
    echo "1. Редактировать данные"
    echo "2. Настроить DNS (BIND)"
    echo "3. Настроить /etc/resolvconf.conf"
    echo "4. Установить имя хоста"
    echo "5. Установить часовой пояс"
    echo "6. Настроить пользователя"
    echo "7. Настроить SSH (порт и баннер)"
    echo "8. Выполнить все настройки"
    echo "0. Выход"
    read -p "Выберите опцию: " option
    case $option in
        1) edit_data ;;
        2) configure_dns ;;
        3) configure_resolv ;;
        4) set_hostname ;;
        5) set_timezone ;;
        6) configure_user ;;
        7) configure_ssh ;;
        8) 
            install_dependencies
            configure_dns
            configure_resolv
            set_hostname
            set_timezone
            configure_user
            configure_ssh
            echo "Все настройки выполнены."
            ;;
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор." ;;
    esac
done
