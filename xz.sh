#!/bin/bash

# Переменные
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

# Установка зависимостей
function install_deps() {
    apt-get update
    apt-get install -y mc sudo openssh-server bind
}

# Смена имени хоста
function set_hostname() {
    echo "$HOSTNAME" > /etc/hostname
    hostnamectl set-hostname "$HOSTNAME"
    grep -q "$HOSTNAME" /etc/hosts || echo "127.0.0.1   $HOSTNAME" >> /etc/hosts
    echo "Имя хоста установлено: $HOSTNAME"
    sleep 2
}

# Настройка IP
function set_ip() {
    IFACE=$(ip -o -4 route show to default | awk '{print $5}')
    mkdir -p /etc/net/ifaces/$IFACE
    echo "BOOTPROTO=static" > /etc/net/ifaces/$IFACE/options
    echo "ADDRESS=$IP_ADDR" >> /etc/net/ifaces/$IFACE/options
    echo "NETMASK=$NETMASK" >> /etc/net/ifaces/$IFACE/options
    echo "GATEWAY=$GATEWAY" >> /etc/net/ifaces/$IFACE/options
    echo "TYPE=eth" >> /etc/net/ifaces/$IFACE/options
    echo "DISABLED=no" >> /etc/net/ifaces/$IFACE/options
    echo "CONFIG_IPV4=yes" >> /etc/net/ifaces/$IFACE/options
    systemctl restart network
    echo "IP-адрес $IP_ADDR/$NETMASK установлен на $IFACE"
    sleep 2
}

# Создание пользователя sshuser
function create_sshuser() {
    id "$SSHUSER" &>/dev/null || useradd -u "$SSHUSER_UID" -m "$SSHUSER"
    echo "$SSHUSER:$SSHUSER_PASS" | chpasswd
    usermod -aG sudo "$SSHUSER"
    grep -q "$SSHUSER" /etc/sudoers || echo "$SSHUSER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    echo "Пользователь $SSHUSER создан и добавлен в sudoers"
    sleep 2
}

# Настройка SSH
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

# Настройка DNS (bind)
function config_dns() {
    systemctl enable named
    systemctl start named
    # Только создаём пустые шаблоны, как в методичке, без лишних записей
    touch /etc/namedb/named.conf.local
    touch /etc/namedb/db.au-team.irpo
    touch /etc/namedb/db.10.168.192.in-addr.arpa
    echo "DNS-сервер настроен (bind), шаблоны файлов созданы."
    sleep 2
}

# Настройка часового пояса
function set_timezone() {
    timedatectl set-timezone "$TZ"
    echo "Часовой пояс установлен: $TZ"
    sleep 2
}

# Меню
function main_menu() {
    while true; do
        clear
        echo "=== МЕНЮ НАСТРОЙКИ HQ-SRV ==="
        echo "1. Установить зависимости"
        echo "2. Сменить имя хоста"
        echo "3. Настроить IP-адрес"
        echo "4. Создать пользователя SSH ($SSHUSER)"
        echo "5. Настроить SSH"
        echo "6. Настроить DNS (bind, шаблоны)"
        echo "7. Настроить часовой пояс"
        echo "8. Настроить всё сразу"
        echo "0. Выйти"
        read -p "Выберите пункт: " choice
        case "$choice" in
            1) install_deps ;;
            2) set_hostname ;;
            3) set_ip ;;
            4) create_sshuser ;;
            5) config_ssh ;;
            6) config_dns ;;
            7) set_timezone ;;
            8) install_deps; set_hostname; set_ip; create_sshuser; config_ssh; config_dns; set_timezone ;;
            0) clear; exit 0 ;;
            *) echo "Ошибка ввода"; sleep 1 ;;
        esac
    done
}

if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт от root"
    exit 1
fi

main_menu
