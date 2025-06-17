#!/bin/bash

# === НАСТРОЙКИ ПО УМОЛЧАНИЮ ===
HOSTNAME="hq-srv.au-team.irpo"
SSHUSER="sshuser"
SSHUSER_UID="1010"
SSHUSER_PASS="P@ssw0rd"
TZ="Asia/Novosibirsk"
SSH_PORT="2024"
BANNER="Authorized access only"
MAX_AUTH_TRIES="2"
IP_ADDR="192.168.10.2/26"
GATEWAY="192.168.10.1"
REPORT_FILE="/root/report.txt"
DNS_ZONE="au-team.irpo"
DNS_FILE="/var/lib/bind/etc/bind/zone/au-team.irpo.db"
REVERSE_ZONE_SRV="10.168.192.in-addr.arpa"
REVERSE_FILE_SRV="/var/lib/bind/etc/bind/zone/192.168.10.db"
REVERSE_ZONE_CLI="20.168.192.in-addr.arpa"
REVERSE_FILE_CLI="/var/lib/bind/etc/bind/zone/192.168.20.db"
IP_HQ_RTR="192.168.10.1"
IP_HQ_SRV="192.168.10.2"
IP_HQ_CLI="192.168.20.10"
IP_BR_RTR="172.16.77.2"
IP_BR_SRV="172.16.15.2"

# === ФУНКЦИИ ДЛЯ ВВОДА ДАННЫХ ===
function input_menu() {
    while true; do
        clear
        echo "=== Подменю ввода/изменения данных ==="
        echo "1. Изменить имя машины (текущее: $HOSTNAME)"
        echo "2. Изменить порт SSH (текущий: $SSH_PORT)"
        echo "3. Изменить имя пользователя SSH (текущее: $SSHUSER)"
        echo "4. Изменить UID пользователя SSH (текущий: $SSHUSER_UID)"
        echo "5. Изменить часовой пояс (текущий: $TZ)"
        echo "6. Изменить баннер SSH (текущий: $BANNER)"
        echo "7. Изменить максимальное количество попыток входа (текущее: $MAX_AUTH_TRIES)"
        echo "8. Изменить IP-адрес и шлюз (текущий: $IP_ADDR, шлюз: $GATEWAY)"
        echo "9. Изменить DNS-зону и IP-адреса устройств"
        echo "10. Изменить все параметры сразу"
        echo "0. Назад"
        read -p "Выберите пункт: " subchoice
        case "$subchoice" in
            1) read -p "Введите новое имя машины: " HOSTNAME ;;
            2) read -p "Введите новый порт SSH [$SSH_PORT]: " input
               SSH_PORT=${input:-$SSH_PORT} ;;
            3) read -p "Введите новое имя пользователя SSH: " SSHUSER ;;
            4) read -p "Введите новый UID пользователя SSH: " SSHUSER_UID ;;
            5) read -p "Введите новый часовой пояс: " TZ ;;
            6) read -p "Введите новый баннер SSH: " BANNER ;;
            7) read -p "Введите новое количество попыток входа [$MAX_AUTH_TRIES]: " input
               MAX_AUTH_TRIES=${input:-$MAX_AUTH_TRIES} ;;
            8) read -p "Введите новый IP-адрес [$IP_ADDR]: " input
               IP_ADDR=${input:-$IP_ADDR}
               read -p "Введите новый шлюз [$GATEWAY]: " input
               GATEWAY=${input:-$GATEWAY} ;;
            9) read -p "Новая DNS-зона [$DNS_ZONE]: " input
               DNS_ZONE=${input:-$DNS_ZONE}
               read -p "IP для hq-rtr [$IP_HQ_RTR]: " input
               IP_HQ_RTR=${input:-$IP_HQ_RTR}
               read -p "IP для hq-srv [$IP_HQ_SRV]: " input
               IP_HQ_SRV=${input:-$IP_HQ_SRV}
               read -p "IP для hq-cli [$IP_HQ_CLI]: " input
               IP_HQ_CLI=${input:-$IP_HQ_CLI}
               read -p "IP для br-rtr [$IP_BR_RTR]: " input
               IP_BR_RTR=${input:-$IP_BR_RTR}
               read -p "IP для br-srv [$IP_BR_SRV]: " input
               IP_BR_SRV=${input:-$IP_BR_SRV} ;;
            10)
                read -p "Имя машины: " HOSTNAME
                read -p "Порт SSH: " SSH_PORT
                read -p "Имя пользователя SSH: " SSHUSER
                read -p "UID пользователя SSH: " SSHUSER_UID
                read -p "Часовой пояс: " TZ
                read -p "Баннер SSH: " BANNER
                read -p "Максимальное количество попыток входа: " MAX_AUTH_TRIES
                read -p "IP-адрес: " IP_ADDR
                read -p "Шлюз: " GATEWAY
                read -p "DNS-зона: " DNS_ZONE
                read -p "IP для hq-rtr: " IP_HQ_RTR
                read -p "IP для hq-srv: " IP_HQ_SRV
                read -p "IP для hq-cli: " IP_HQ_CLI
                read -p "IP для br-rtr: " IP_BR_RTR
                read -p "IP для br-srv: " IP_BR_SRV
                ;;
            0) break ;;
            *) echo "Ошибка ввода"; sleep 1 ;;
        esac
    done
}

# === УСТАНОВКА ЗАВИСИМОСТЕЙ ===
function install_deps() {
    echo "Установка зависимостей..." | tee -a "$REPORT_FILE"
    apt-get update
    apt-get install -y mc sudo openssh-server bind bind-utils tzdata resolvconf
    echo "Зависимости установлены." | tee -a "$REPORT_FILE"
    sleep 2
}

# === 1. Смена имени хоста ===
function set_hostname() {
    echo "Установка имени хоста..." | tee -a "$REPORT_FILE"
    echo "$HOSTNAME" > /etc/hostname
    hostnamectl set-hostname "$HOSTNAME"
    echo "127.0.0.1   $HOSTNAME" >> /etc/hosts
    echo "Имя хоста установлено: $HOSTNAME" | tee -a "$REPORT_FILE"
    sleep 2
}

# === 2. Настройка IP-адресации ===
function set_ip() {
    echo "Настройка IP-адресации..." | tee -a "$REPORT_FILE"
    IFACE=$(ip -o -4 route show to default | awk '{print $5}')
    mkdir -p /etc/net/ifaces/"$IFACE"
    cat > /etc/net/ifaces/"$IFACE"/options <<EOF
BOOTPROTO=static
ADDRESS=${IP_ADDR%/*}
NETMASK=$(ipcalc -m "$IP_ADDR" | cut -d= -f2)
GATEWAY=$GATEWAY
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
EOF
    systemctl restart network
    echo "IP-адрес $IP_ADDR, шлюз $GATEWAY установлен на $IFACE" | tee -a "$REPORT_FILE"
    sleep 2
}

# === 3. Создание пользователя sshuser ===
function create_sshuser() {
    echo "Настройка пользователя..." | tee -a "$REPORT_FILE"
    if [ -z "$SSHUSER_UID" ]; then
        read -p "Введите UID для пользователя $SSHUSER: " SSHUSER_UID
    fi
    if adduser --uid "$SSHUSER_UID" "$SSHUSER"; then
        echo "$SSHUSER:$SSHUSER_PASS" | chpasswd
        echo "$SSHUSER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
        usermod -aG wheel "$SSHUSER"
        echo "Пользователь $SSHUSER создан с UID $SSHUSER_UID и правами sudo." | tee -a "$REPORT_FILE"
    else
        echo "Ошибка: Не удалось создать пользователя $SSHUSER." | tee -a "$REPORT_FILE"
        exit 1
    fi
    sleep 2
}

# === 4. Настройка SSH ===
function config_ssh() {
    echo "Настройка SSH..." | tee -a "$REPORT_FILE"
    echo "$BANNER" > /etc/banner
    if grep -q "^Banner" /etc/ssh/sshd_config; then
        sed -i 's|^Banner.*|Banner /etc/banner|' /etc/ssh/sshd_config
    else
        echo "Banner /etc/banner" >> /etc/ssh/sshd_config
    fi
    sed -i "s/^#*Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
    grep -q "^AllowUsers" /etc/ssh/sshd_config && \
        sed -i "s/^AllowUsers .*/AllowUsers $SSHUSER/" /etc/ssh/sshd_config || \
        echo "AllowUsers $SSHUSER" >> /etc/ssh/sshd_config
    sed -i "s/^#*MaxAuthTries .*/MaxAuthTries $MAX_AUTH_TRIES/" /etc/ssh/sshd_config
    systemctl restart sshd
    echo "SSH настроен: порт $SSH_PORT, только $SSHUSER, $MAX_AUTH_TRIES попытки, баннер" | tee -a "$REPORT_FILE"
    sleep 2
}

# === 5. Настройка часового пояса ===
function set_timezone() {
    echo "Настройка часового пояса..." | tee -a "$REPORT_FILE"
    timedatectl set-timezone "$TZ"
    echo "Часовой пояс установлен: $TZ" | tee -a "$REPORT_FILE"
    sleep 2
}

# === 6. Настройка DNS ===
function configure_dns() {
    echo "Настройка DNS..." | tee -a "$REPORT_FILE"
    
    # Установка и активация сервиса bind
    apt-get install -y bind bind-utils
    systemctl enable --now bind

    # Настройка named.conf.options
    cat > /etc/bind/options.conf <<EOF
options {
    directory "/var/cache/bind";
    listen-on { any; };
    forward first;
    forwarders { 77.88.8.8; 8.8.8.8; };
    allow-query { any; };
    allow-transfer { none; };
    recursion yes;
};
EOF

    # Настройка named.conf.local
    cat > /etc/bind/named.conf.local <<EOF
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

    # Создание директории для зон
    mkdir -p /var/cache/bind/zones
    chown -R bind:bind /var/cache/bind
    chmod -R 755 /var/cache/bind

    # Создание файла прямой зоны
    cat > "$DNS_FILE" <<EOF
$TTL 1D
@    IN    SOA  hq-srv.$DNS_ZONE. root.$DNS_ZONE. (
                2025061600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; minimum
            )
        IN    NS       hq-srv.$DNS_ZONE.
        IN    A        $IP_HQ_SRV
hq-rtr  IN    A        $IP_HQ_RTR
br-rtr  IN    A        $IP_BR_RTR
hq-srv  IN    A        $IP_HQ_SRV
hq-cli  IN    A        $IP_HQ_CLI
br-srv  IN    A        $IP_BR_SRV
moodle  IN    CNAME    hq-rtr.$DNS_ZONE.
wiki    IN    CNAME    hq-rtr.$DNS_ZONE.
EOF

    # Создание файла обратной зоны для подсети 192.168.10.0/26
    cat > "$REVERSE_FILE_SRV" <<EOF
$TTL 1D
@    IN    SOA  hq-srv.$DNS_ZONE. root.$DNS_ZONE. (
                2025061600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; minimum
            )
        IN    NS       hq-srv.$DNS_ZONE.
$(echo $IP_HQ_RTR | cut -d. -f4)    IN    PTR    hq-rtr.$DNS_ZONE.
$(echo $IP_HQ_SRV | cut -d. -f4)    IN    PTR    hq-srv.$DNS_ZONE.
EOF

    # Создание файла обратной зоны для подсети 192.168.20.0/28
    cat > "$REVERSE_FILE_CLI" <<EOF
$TTL 1D
@    IN    SOA  hq-srv.$DNS_ZONE. root.$DNS_ZONE. (
                2025061600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; minimum
            )
        IN    NS       hq-srv.$DNS_ZONE.
$(echo $IP_HQ_CLI | cut -d. -f4)    IN    PTR    hq-cli.$DNS_ZONE.
EOF

    # Проверка конфигурации
    named-checkconf /etc/bind/options.conf
    named-checkconf /etc/bind/named.conf.local
    named-checkzone "$DNS_ZONE" "$DNS_FILE"
    named-checkzone "$REVERSE_ZONE_SRV" "$REVERSE_FILE_SRV"
    named-checkzone "$REVERSE_ZONE_CLI" "$REVERSE_FILE_CLI"

    # Перезапуск сервиса bind
    systemctl restart bind
    if systemctl is-active --quiet bind; then
        echo "Сервис bind успешно запущен." | tee -a "$REPORT_FILE"
    else
        echo "Ошибка: Сервис bind не запустился." | tee -a "$REPORT_FILE"
        exit 1
    fi

    # Настройка resolv.conf
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    chattr +i /etc/resolv.conf  # Защита от перезаписи
    resolvconf -u

    echo "DNS настроен." | tee -a "$REPORT_FILE"
    sleep 2
}

# === 7. Настроить всё сразу ===
function do_all() {
    set_hostname
    set_ip
    create_sshuser
    config_ssh
    set_timezone
    configure_dns
    echo "Все задания выполнены!" | tee -a "$REPORT_FILE"
    sleep 2
}

# === МЕНЮ ===
function main_menu() {
    while true; do
        clear
        echo "=== МЕНЮ НАСТРОЙКИ HQ-SRV ==="
        echo "1. Ввод/изменение данных"
        echo "2. Сменить имя хоста"
        echo "3. Настроить IP-адрес"
        echo "4. Создать пользователя SSH ($SSHUSER)"
        echo "5. Настроить SSH"
        echo "6. Настроить часовой пояс"
        echo "7. Настроить DNS"
        echo "8. Настроить всё сразу"
        echo "0. Выйти"
        read -p "Выберите пункт: " choice
        case "$choice" in
            1) input_menu ;;
            2) set_hostname ;;
            3) set_ip ;;
            4) create_sshuser ;;
            5) config_ssh ;;
            6) set_timezone ;;
            7) configure_dns ;;
            8) do_all ;;
            0) clear; exit 0 ;;
            *) echo "Ошибка ввода"; sleep 1 ;;
        esac
    done
}

# === ОСНОВНОЙ БЛОК ===
if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт от root"
    exit 1
fi

install_deps
main_menu
