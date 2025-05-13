#!/bin/bash

# Скрипт для настройки сервера HQ-SRV

# Установка зависимостей
install_dependencies() {
    echo "Установка зависимостей..."
    apt-get update
    apt-get install -y iproute2 bind9 bind9-utils openssh-server systemd mc wget tzdata
    echo "Зависимости установлены."
}

install_dependencies

# Начальные значения переменных
INTERFACE_LAN="ens192"
IP_LAN="192.168.10.2/26"
DEFAULT_GW="192.168.10.1"
HOSTNAME="hq-srv.au-team.irpo"
TIME_ZONE="Asia/Novosibirsk"
USERNAME="net_admin"
USER_UID=1010
BANNER_TEXT="Authorized access only"
DNS_ZONE="au-team.irpo"
DNS_FILE="au-team.irpo.db"
REVERSE_ZONE_SRV="10.168.192.in-addr.arpa"
REVERSE_FILE_SRV="192.168.10.db"
REVERSE_ZONE_CLI="20.168.192.in-addr.arpa"
REVERSE_FILE_CLI="192.168.20.db"
IP_HQ_RTR="192.168.10.1"
IP_HQ_SRV="192.168.10.2"
IP_HQ_CLI="192.168.20.10"

# Функция проверки существования интерфейса
check_interface() {
    if ! ip link show "$1" &> /dev/null; then
        echo "Ошибка: Интерфейс $1 не существует."
        exit 1
    fi
}

# Функция настройки сетевых интерфейсов через /etc/net/ifaces/
configure_interfaces() {
    echo "Настройка интерфейсов через /etc/net/ifaces/..."
    
    check_interface "$INTERFACE_LAN"
    
    mkdir -p /etc/net/ifaces/"$INTERFACE_LAN"
    cat > /etc/net/ifaces/"$INTERFACE_LAN"/options << EOF
BOOTPROTO=static
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
EOF
    echo "$IP_LAN" > /etc/net/ifaces/"$INTERFACE_LAN"/ipv4address
    echo "default via $DEFAULT_GW" > /etc/net/ifaces/"$INTERFACE_LAN"/ipv4route
    
    systemctl restart network
    echo "Интерфейсы настроены."
}

# Функция настройки DNS (BIND)
configure_dns() {
    echo "Настройка DNS..."
    
    apt-get install -y bind9 bind9-utils
    systemctl enable --now bind9
    
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
        IN    A        $IP_HQ_SRV
hq-rtr  IN    A        $IP_HQ_RTR
hq-srv  IN    A        $IP_HQ_SRV
hq-cli  IN    A        $IP_HQ_CLI
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

    # Проверка синтаксиса зон
    named-checkconf /etc/bind/named.conf.local
    named-checkzone "$DNS_ZONE" /etc/bind/"$DNS_FILE"
    named-checkzone "$REVERSE_ZONE_SRV" /etc/bind/"$REVERSE_FILE_SRV"
    named-checkzone "$REVERSE_ZONE_CLI" /etc/bind/"$REVERSE_FILE_CLI"
    
    systemctl restart bind9
    echo "DNS настроен."
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
    if [ -z "$USER_UID" ]; then
        read -p "Введите UID для пользователя $USERNAME: " USER_UID
    fi
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

# Функция настройки баннера SSH
configure_ssh_banner() {
    echo "Настройка баннера SSH..."
    echo "$BANNER_TEXT" > /etc/banner
    if grep -q "^Banner" /etc/openssh/sshd_config; then
        sed -i 's|^Banner.*|Banner /etc/banner|' /etc/openssh/sshd_config
    else
        echo "Banner /etc/banner" >> /etc/openssh/sshd_config
    fi
    systemctl restart sshd
    echo "Баннер SSH настроен."
}

# Функция редактирования данных
edit_data() {
    while true; do
        clear
        echo "Текущие значения:"
        echo "1. Интерфейс LAN: $INTERFACE_LAN"
        echo "2. IP для LAN: $IP_LAN"
        echo "3. Шлюз по умолчанию: $DEFAULT_GW"
        echo "4. Hostname: $HOSTNAME"
        echo "5. Часовой пояс: $TIME_ZONE"
        echo "6. Имя пользователя: $USERNAME"
        echo "7. UID пользователя: $USER_UID"
        echo "8. Текст баннера: $BANNER_TEXT"
        echo "9. DNS зона: $DNS_ZONE"
        echo "10. IP для hq-rtr: $IP_HQ_RTR"
        echo "11. IP для hq-srv: $IP_HQ_SRV"
        echo "12. IP для hq-cli: $IP_HQ_CLI"
        echo "0. Назад"
        read -p "Введите номер параметра для изменения: " choice
        case $choice in
            1) read -p "Новый интерфейс LAN [$INTERFACE_LAN]: " input
               INTERFACE_LAN=${input:-$INTERFACE_LAN} ;;
            2) read -p "Новый IP для LAN [$IP_LAN]: " input
               IP_LAN=${input:-$IP_LAN} ;;
            3) read -p "Новый шлюз по умолчанию [$DEFAULT_GW]: " input
               DEFAULT_GW=${input:-$DEFAULT_GW} ;;
            4) read -p "Новый hostname [$HOSTNAME]: " input
               HOSTNAME=${input:-$HOSTNAME} ;;
            5) read -p "Новый часовой пояс [$TIME_ZONE]: " input
               TIME_ZONE=${input:-$TIME_ZONE} ;;
            6) read -p "Новое имя пользователя [$USERNAME]: " input
               USERNAME=${input:-$USERNAME} ;;
            7) read -p "Новый UID пользователя [$USER_UID]: " input
               USER_UID=${input:-$USER_UID} ;;
            8) read -p "Новый текст баннера [$BANNER_TEXT]: " input
               BANNER_TEXT=${input:-$BANNER_TEXT} ;;
            9) read -p "Новая DNS зона [$DNS_ZONE]: " input
               DNS_ZONE=${input:-$DNS_ZONE} ;;
            10) read -p "Новый IP для hq-rtr [$IP_HQ_RTR]: " input
                IP_HQ_RTR=${input:-$IP_HQ_RTR} ;;
            11) read -p "Новый IP для hq-srv [$IP_HQ_SRV]: " input
                IP_HQ_SRV=${input:-$IP_HQ_SRV} ;;
            12) read -p "Новый IP для hq-cli [$IP_HQ_CLI]: " input
                IP_HQ_CLI=${input:-$IP_HQ_CLI} ;;
            0) return ;;
            *) echo "Неверный выбор." ;;
        esac
    done
}

# Основное меню
while true; do
    clear
    echo -e "\nМеню настройки HQ-SRV:"
    echo "1. Редактировать данные"
    echo "2. Настроить сетевые интерфейсы"
    echo "3. Настроить DNS (BIND)"
    echo "4. Установить имя хоста"
    echo "5. Установить часовой пояс"
    echo "6. Настроить пользователя"
    echo "7. Настроить баннер SSH"
    echo "8. Выполнить все настройки"
    echo "0. Выход"
    read -p "Выберите опцию: " option
    case $option in
        1) edit_data ;;
        2) configure_interfaces ;;
        3) configure_dns ;;
        4) set_hostname ;;
        5) set_timezone ;;
        6) configure_user ;;
        7) configure_ssh_banner ;;
        8) 
            configure_interfaces
            configure_dns
            set_hostname
            set_timezone
            configure_user
            configure_ssh_banner
            echo "Все настройки выполнены."
            ;;
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор." ;;
    esac
done
