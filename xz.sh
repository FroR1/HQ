#!/bin/bash

# === НАСТРОЙКИ ПО УМОЛЧАНИЮ ===
HOSTNAME="hq-srv.au-team.irpo"
IP_ADDR="192.168.10.20"
NETMASK="255.255.255.240"
GATEWAY="192.168.10.1"
SSHUSER="sshuser"
SSHUSER_UID="1010"
SSHUSER_PASS="P@ssw0rd"
TZ="Asia/Yekaterinburg"
SSH_PORT="2024"
BANNER="Authorized access only"
DNS_DOMAIN="au-team.irpo"
DNS_PTR="10.168.192.in-addr.arpa"

# === ФУНКЦИИ ДЛЯ ВВОДА ДАННЫХ ===
function input_menu() {
    while true; do
        clear
        echo "=== Подменю ввода/изменения данных ==="
        echo "1. Изменить имя машины (текущее: $HOSTNAME)"
        echo "2. Изменить IP-адрес (текущий: $IP_ADDR)"
        echo "3. Изменить маску сети (текущая: $NETMASK)"
        echo "4. Изменить шлюз (текущий: $GATEWAY)"
        echo "5. Изменить имя пользователя SSH (текущее: $SSHUSER)"
        echo "6. Изменить UID пользователя SSH (текущий: $SSHUSER_UID)"
        echo "7. Изменить пароль пользователя SSH"
        echo "8. Изменить часовой пояс (текущий: $TZ)"
        echo "9. Изменить порт SSH (текущий: $SSH_PORT)"
        echo "10. Изменить баннер SSH"
        echo "11. Изменить домен DNS (текущий: $DNS_DOMAIN)"
        echo "12. Изменить PTR-зону DNS (текущий: $DNS_PTR)"
        echo "13. Изменить все параметры сразу"
        echo "0. Назад"
        read -p "Выберите пункт: " subchoice
        case "$subchoice" in
            1) read -p "Введите новое имя машины: " HOSTNAME ;;
            2) read -p "Введите новый IP-адрес: " IP_ADDR ;;
            3) read -p "Введите новую маску сети: " NETMASK ;;
            4) read -p "Введите новый шлюз: " GATEWAY ;;
            5) read -p "Введите новое имя пользователя SSH: " SSHUSER ;;
            6) read -p "Введите новый UID пользователя SSH: " SSHUSER_UID ;;
            7) read -s -p "Введите новый пароль пользователя SSH: " SSHUSER_PASS; echo ;;
            8) read -p "Введите новый часовой пояс: " TZ ;;
            9) read -p "Введите новый порт SSH: " SSH_PORT ;;
            10) read -p "Введите новый баннер SSH: " BANNER ;;
            11) read -p "Введите новый домен DNS: " DNS_DOMAIN ;;
            12) read -p "Введите новую PTR-зону DNS: " DNS_PTR ;;
            13)
                read -p "Имя машины: " HOSTNAME
                read -p "IP-адрес: " IP_ADDR
                read -p "Маска сети: " NETMASK
                read -p "Шлюз: " GATEWAY
                read -p "Имя пользователя SSH: " SSHUSER
                read -p "UID пользователя SSH: " SSHUSER_UID
                read -s -p "Пароль пользователя SSH: " SSHUSER_PASS; echo
                read -p "Часовой пояс: " TZ
                read -p "Порт SSH: " SSH_PORT
                read -p "Баннер SSH: " BANNER
                read -p "Домен DNS: " DNS_DOMAIN
                read -p "PTR-зона DNS: " DNS_PTR
                ;;
            0) break ;;
            *) echo "Ошибка ввода"; sleep 1 ;;
        esac
    done
}

# === УСТАНОВКА ЗАВИСИМОСТЕЙ ===
function install_deps() {
    apt-get update
    apt-get install -y mc sudo openssh-server bind9
}

# === 1. Смена имени хоста ===
function set_hostname() {
    echo "$HOSTNAME" > /etc/hostname
    hostnamectl set-hostname "$HOSTNAME"
    echo "127.0.0.1   $HOSTNAME" >> /etc/hosts
    echo "Имя хоста установлено: $HOSTNAME"
    sleep 2
}

# === 2. Настройка IP-адресации ===
function set_ip() {
    IFACE=$(ip -o -4 route show to default | awk '{print $5}')
    cat > /etc/net/ifaces/$IFACE/options <<EOF
BOOTPROTO=static
ADDRESS=$IP_ADDR
NETMASK=$NETMASK
GATEWAY=$GATEWAY
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
EOF
    systemctl restart network
    echo "IP-адрес $IP_ADDR/$NETMASK установлен на $IFACE"
    sleep 2
}

# === 3. Создание пользователя sshuser ===
function create_sshuser() {
    id "$SSHUSER" &>/dev/null || useradd -u "$SSHUSER_UID" -m "$SSHUSER"
    echo "$SSHUSER:$SSHUSER_PASS" | chpasswd
    usermod -aG sudo "$SSHUSER"
    grep -q "$SSHUSER" /etc/sudoers || echo "$SSHUSER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    echo "Пользователь $SSHUSER создан и добавлен в sudoers"
    sleep 2
}

# === 4. Настройка SSH ===
function config_ssh() {
    sed -i "s/^#*Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
    grep -q "^AllowUsers" /etc/ssh/sshd_config && \
        sed -i "s/^AllowUsers .*/AllowUsers $SSHUSER/" /etc/ssh/sshd_config || \
        echo "AllowUsers $SSHUSER" >> /etc/ssh/sshd_config
    sed -i "s/^#*MaxAuthTries .*/MaxAuthTries 2/" /etc/ssh/sshd_config
    echo "$BANNER" > /etc/issue.net
    grep -q "^Banner" /etc/ssh/sshd_config && \
        sed -i "s|^Banner .*|Banner /etc/issue.net|" /etc/ssh/sshd_config || \
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
    systemctl restart sshd
    echo "SSH настроен: порт $SSH_PORT, только $SSHUSER, 2 попытки, баннер"
    sleep 2
}

# === 5. Настройка DNS (bind9) ===
function config_dns() {
    systemctl enable bind9
    systemctl start bind9
    # Пример настройки зоны:
    cat > /etc/bind/named.conf.local <<EOF
zone "$DNS_DOMAIN" {
    type master;
    file "/etc/bind/db.$DNS_DOMAIN";
};
zone "$DNS_PTR" {
    type master;
    file "/etc/bind/db.$DNS_PTR";
};
EOF
    # Пример файла зоны:
    cat > /etc/bind/db.$DNS_DOMAIN <<EOF
\$TTL    604800
@       IN      SOA     $HOSTNAME. root.$DNS_DOMAIN. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $HOSTNAME.
hq-srv  IN      A       $IP_ADDR
EOF
    # Пример PTR-зоны:
    PTR_ADDR=$(echo $IP_ADDR | awk -F. '{print $4"."$3"."$2"."$1}')
    cat > /etc/bind/db.$DNS_PTR <<EOF
\$TTL    604800
@       IN      SOA     $HOSTNAME. root.$DNS_PTR. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $HOSTNAME.
$(echo $IP_ADDR | awk -F. '{print $4}') IN PTR hq-srv.$DNS_DOMAIN.
EOF
    systemctl restart bind9
    echo "DNS-сервер настроен (bind9)"
    sleep 2
}

# === 6. Настройка часового пояса ===
function set_timezone() {
    timedatectl set-timezone "$TZ"
    echo "Часовой пояс установлен: $TZ"
    sleep 2
}

# === 7. Настроить всё сразу ===
function do_all() {
    set_hostname
    set_ip
    create_sshuser
    config_ssh
    config_dns
    set_timezone
    echo "Все задания выполнены!"
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
        echo "6. Настроить DNS (bind9)"
        echo "7. Настроить часовой пояс"
        echo "8. Настроить всё сразу"
        echo "0. Выйти"
        read -p "Выберите пункт: " choice
        case "$choice" in
            1) input_menu ;;
            2) set_hostname ;;
            3) set_ip ;;
            4) create_sshuser ;;
            5) config_ssh ;;
            6) config_dns ;;
            7) set_timezone ;;
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
