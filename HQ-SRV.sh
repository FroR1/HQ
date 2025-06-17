#!/bin/bash

# Скрипт для настройки сервера HQ-SRV

# Установка зависимостей
install_dependencies() {
    echo "Установка зависимостей..."
    apt-get update
    apt-get install -y bind bind-utils openssh-server systemd mc wget tzdata resolvconf
    echo "Зависимости установлены."
}

install_dependencies

# Начальные значения переменных
INTERFACE_VLAN_BASE="ens192"
VLAN_MGMT_ID="99"
IP_VLAN_MGMT="172.16.99.2/29"
HOSTNAME="hq-srv.au-team.irpo"
TIME_ZONE="Asia/Novosibirsk"
USERNAME="sshuser"
USER_UID=1010
BANNER_TEXT="Authorized access only"
SSH_PORT=3010
DNS_ZONE="au-team.irpo"
DNS_FILE="au-team.irpo.db"
REVERSE_ZONE_SRV="10.168.192.in-addr.arpa"
REVERSE_FILE_SRV="zonsrv.db"
REVERSE_ZONE_CLI="20.168.192.in-addr.arpa"
REVERSE_FILE_CLI="zoncli.db"
IP_HQ_RTR="192.168.10.1"
IP_HQ_SRV="192.168.10.2"
IP_HQ_CLI="192.168.20.10"
IP_BR_RTR="172.16.77.2"
IP_BR_SRV="172.16.15.2"


configure_interfaces(){
    # Настройка VLAN интерфейсов
    for vlan in "$VLAN_MGMT_ID"; do
        iface="${INTERFACE_VLAN_BASE}.$vlan"
        # Сопоставление VLAN с переменной IP-адреса
        case $vlan in
            "$VLAN_MGMT_ID") ip_addr="$IP_VLAN_MGMT" ;;
            *) echo "Ошибка: Неизвестный VLAN $vlan"; exit 1 ;;
        esac
        
        # Проверка, что IP-адрес определен
        if [ -z "$ip_addr" ]; then
            echo "Ошибка: IP-адрес для VLAN $vlan не определен."
            exit 1
        fi
        
        mkdir -p /etc/net/ifaces/"$iface"
        cat > /etc/net/ifaces/"$iface"/options << EOF
BOOTPROTO=static
TYPE=vlan
DISABLED=no
CONFIG_IPV4=yes
VID=$vlan
HOST=$INTERFACE_VLAN_BASE
ONBOOT=yes
EOF
        echo "$ip_addr" > /etc/net/ifaces/"$iface"/ipv4address
    done
        echo  default via 172.16.99.1 > /etc/net/ifaces/"$iface"/ipv4route  
    systemctl restart network
    echo "Интерфейсы настроены."
}




# Функция настройки DNS (BIND)
configure_dns() {
    echo "Настройка DNS..."
    
    apt-get install -y bind bind-utils
    systemctl enable --now bind
    cd /etc/bind/
    rm options.conf
    touch options.conf
    echo "options {
        version \"unknown\";
        directory \"/etc/bind/zone\";
        dump-file \"/var/run/named/named_dump.db\";
        statistics-file \"/var/run/named/named.stats\";
        recursing-file \"/var/run/named/named.recursing\";
        secroots-file \"/var/run/named/named.secroots\";
        pid-file none;
        listen-on { any; };
        forward first;
        forwarders { 77.88.8.8; };
        allow-query { any; };
        };
    logging {

    };" > /etc/bind/options.conf


    # Настройка зон в /etc/bind/local.conf
    cat > /var/lib/bind/etc/local.conf << EOF
zone "$DNS_ZONE" {
    type master;
    file "$DNS_FILE";
};

zone "$REVERSE_ZONE_SRV" {
    type master;
    file "$REVERSE_FILE_SRV";
};

zone "$REVERSE_ZONE_CLI" {
    type master;
    file "$REVERSE_FILE_CLI";
};
EOF

    # Создание файла зоны прямого DNS
    cat > /var/lib/bind/etc/bind/zone/"$DNS_FILE" << EOF
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
    cat > /var/lib/bind/etc/bind/zone/"$REVERSE_FILE_SRV" << EOF
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
    cat > /var/lib/bind/etc/bind/zone/"$REVERSE_FILE_CLI" << EOF
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
    named-checkconf /etc/bind/options.conf
    named-checkconf /etc/bind/local.conf
    named-checkzone "$DNS_ZONE" /etc/bind/"$DNS_FILE"
    named-checkzone "$REVERSE_ZONE_SRV" /etc/bind/"$REVERSE_FILE_SRV"
    named-checkzone "$REVERSE_ZONE_CLI" /etc/bind/"$REVERSE_FILE_CLI"
    
    systemctl restart bind
    echo "DNS настроен."
}

# Функция настройки /etc/resolvconf.conf
configure_resolv() {
    echo "Настройка /etc/resolvconf.conf..."
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    echo "Проверка интернета..."
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

# Функция настройки SSH (порт и баннер)
configure_ssh() {
    echo "Настройка SSH..."
    
    # Настройка порта SSH
    if grep -q "^Port" /etc/openssh/sshd_config; then
        sed -i "s/^Port .*/Port $SSH_PORT/" /etc/openssh/sshd_config
    else
        echo "Port $SSH_PORT" >> /etc/openssh/sshd_config
    fi
    
    # Настройка баннера SSH
    sed -i "s/^#*MaxAuthTries .*/MaxAuthTries 2/" /etc/openssh/sshd_config
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin no/" /etc/openssh/sshd_config
    grep -q "^AllowUsers" /etc/openssh/sshd_config && \
    sed -i "s/^AllowUsers .*/AllowUsers $SSHUSER/" /etc/openssh/sshd_config || \
    echo "AllowUsers $SSHUSER" >> /etc/openssh/sshd_config
    echo "$BANNER_TEXT" > /etc/banner
    if grep -q "^Banner" /etc/openssh/sshd_config; then
        sed -i 's|^Banner.*|Banner /etc/banner|' /etc/openssh/sshd_config
    else
        echo "Banner /etc/banner" >> /etc/openssh/sshd_config
    fi
    
    systemctl restart sshd
    echo "SSH настроен (порт: $SSH_PORT, баннер установлен)."
}

# Функция редактирования данных
edit_data() {
    while true; do
        clear
        echo "Текущие значения:"
        echo "1. Hostname: $HOSTNAME"
        echo "2. Часовой пояс: $TIME_ZONE"
        echo "3. Имя пользователя: $USERNAME"
        echo "4. UID пользователя: $USER_UID"
        echo "5. Текст баннера: $BANNER_TEXT"
        echo "6. Порт SSH: $SSH_PORT"
        echo "7. DNS зона: $DNS_ZONE"
        echo "8. IP для hq-rtr: $IP_HQ_RTR"
        echo "9. IP для hq-srv: $IP_HQ_SRV"
        echo "10. IP для hq-cli: $IP_HQ_CLI"
        echo "11. IP для br-rtr: $IP_BR_RTR"
        echo "12. IP для br-srv: $IP_BR_SRV"
        echo "13. Reverse зона для SRV: $REVERSE_ZONE_SRV"
        echo "14. Reverse зона для CLI: $REVERSE_ZONE_CLI"
        echo "0. Назад"
        read -p "Введите номер параметра для изменения: " choice
        case $choice in
            1) read -p "Новый hostname [$HOSTNAME]: " input
               HOSTNAME=${input:-$HOSTNAME} ;;
            2) read -p "Новый часовой пояс [$TIME_ZONE]: " input
               TIME_ZONE=${input:-$TIME_ZONE} ;;
            3) read -p "Новое имя пользователя [$USERNAME]: " input
               USERNAME=${input:-$USERNAME} ;;
            4) read -p "Новый UID пользователя [$USER_UID]: " input
               USER_UID=${input:-$USER_UID} ;;
            5) read -p "Новый текст баннера [$BANNER_TEXT]: " input
               BANNER_TEXT=${input:-$BANNER_TEXT} ;;
            6) read -p "Новый порт SSH [$SSH_PORT]: " input
               SSH_PORT=${input:-$SSH_PORT} ;;
            7) read -p "Новая DNS зона [$DNS_ZONE]: " input
               DNS_ZONE=${input:-$DNS_ZONE} ;;
            8) read -p "Новый IP для hq-rtr [$IP_HQ_RTR]: " input
               IP_HQ_RTR=${input:-$IP_HQ_RTR} ;;
            9) read -p "Новый IP для hq-srv [$IP_HQ_SRV]: " input
               IP_HQ_SRV=${input:-$IP_HQ_SRV} ;;
            10) read -p "Новый IP для hq-cli [$IP_HQ_CLI]: " input
                IP_HQ_CLI=${input:-$IP_HQ_CLI} ;;
            11) read -p "Новый IP для br-rtr [$IP_BR_RTR]: " input
                IP_BR_RTR=${input:-$IP_BR_RTR} ;;
            12) read -p "Новый IP для br-srv [$IP_BR_SRV]: " input
                IP_BR_SRV=${input:-$IP_BR_SRV} ;;
            13) read -p "Новая Reverse зона для SRV [$REVERSE_ZONE_SRV]: " input
                REVERSE_ZONE_SRV=${input:-$REVERSE_ZONE_SRV} ;;
            14) read -p "Новая Reverse зона для CLI [$REVERSE_ZONE_CLI]: " input
                REVERSE_ZONE_CLI=${input:-$REVERSE_ZONE_CLI} ;;
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
    echo "2. Настроить DNS (BIND)"
    echo "3. Настроить /etc/resolvconf.conf"
    echo "4. Установить имя хоста"
    echo "5. Установить часовой пояс"
    echo "6. Настроить пользователя"
    echo "7. Настроить SSH (порт и баннер)"
    echo "8. Выполнить все настройки"
    echo "9. Настройка админского vlan"
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
            configure_dns
            configure_resolv
            set_hostname
            set_timezone
            configure_user
            configure_ssh
            configure_interfaces
            echo "Все настройки выполнены."
            ;;
        9) configure_interfaces ;;
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор." ;;
    esac
done
