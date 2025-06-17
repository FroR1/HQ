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
    echo "Настройка пользователя..."
