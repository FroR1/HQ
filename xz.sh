#!/bin/bash

# === ПЕРЕМЕННЫЕ ПО УМОЛЧАНИЮ (всё можно изменить через меню) ===
HOSTNAME="hq-srv.au-team.irpo"
SSHUSER="sshuser"
SSHUSER_UID="1010"
SSHUSER_PASS="P@ssw0rd"
TZ="Asia/Novosibirsk"
SSH_PORT="2024"
BANNER="Authorized access only"
DNS_DOMAIN="au-team.irpo"
ZONE_FORWARD_FILE="test.db"
ZONE_REV100_FILE="17216100.db"
ZONE_REV200_FILE="17216200.db"
ZONE_DIR="/var/lib/bind/etc/bind/zone"
LOCAL_CONF="/var/lib/bind/etc/local.conf"
NAMED_CONF="/var/lib/bind/etc/named.conf"
REV_ZONE_100="100.16.172.in-addr.arpa"
REV_ZONE_200="200.16.172.in-addr.arpa"

# PTR-записи (можно менять через меню)
PTR_100_1="hq-rtr"
PTR_100_2="hq-srv"
PTR_200_10="hq-cli"

# Остальные A-записи (можно менять через меню)
A_HQ_RTR="172.16.100.1"
A_BR_RTR="172.16.77.2"
A_HQ_SRV="172.16.100.2"
A_HQ_CLI="172.16.200.10"
A_BR_SRV="172.16.15.2"

# === ФУНКЦИИ ВВОДА ДАННЫХ ===
function input_menu() {
    while true; do
        clear
        echo "=== Подменю ввода/изменения данных ==="
        echo " 1. Имя машины ($HOSTNAME)"
        echo " 2. Имя пользователя SSH ($SSHUSER)"
        echo " 3. UID пользователя SSH ($SSHUSER_UID)"
        echo " 4. Пароль пользователя SSH"
        echo " 5. Часовой пояс ($TZ)"
        echo " 6. Порт SSH ($SSH_PORT)"
        echo " 7. Баннер SSH"
        echo " 8. Имя домена DNS ($DNS_DOMAIN)"
        echo " 9. Имя файла прямой зоны ($ZONE_FORWARD_FILE)"
        echo "10. Имя файла обратной зоны VLAN100 ($ZONE_REV100_FILE)"
        echo "11. Имя файла обратной зоны VLAN200 ($ZONE_REV200_FILE)"
        echo "12. Каталог зон ($ZONE_DIR)"
        echo "13. PTR для 1 (VLAN100) ($PTR_100_1)"
        echo "14. PTR для 2 (VLAN100) ($PTR_100_2)"
        echo "15. PTR для 10 (VLAN200) ($PTR_200_10)"
        echo "16. A-запись HQ-RTR ($A_HQ_RTR)"
        echo "17. A-запись BR-RTR ($A_BR_RTR)"
        echo "18. A-запись HQ-SRV ($A_HQ_SRV)"
        echo "19. A-запись HQ-CLI ($A_HQ_CLI)"
        echo "20. A-запись BR-SRV ($A_BR_SRV)"
        echo "21. Название обратной зоны VLAN100 ($REV_ZONE_100)"
        echo "22. Название обратной зоны VLAN200 ($REV_ZONE_200)"
        echo "23. Изменить все параметры сразу"
        echo " 0. Назад"
        read -p "Выберите пункт: " subchoice
        case "$subchoice" in
            1) read -p "Введите новое имя машины: " HOSTNAME ;;
            2) read -p "Введите новое имя пользователя SSH: " SSHUSER ;;
            3) read -p "Введите новый UID пользователя SSH: " SSHUSER_UID ;;
            4) read -s -p "Введите новый пароль пользователя SSH: " SSHUSER_PASS; echo ;;
            5) read -p "Введите новый часовой пояс: " TZ ;;
            6) read -p "Введите новый порт SSH: " SSH_PORT ;;
            7) read -p "Введите новый баннер SSH: " BANNER ;;
            8) read -p "Введите новое имя домена DNS: " DNS_DOMAIN ;;
            9) read -p "Введите имя файла прямой зоны: " ZONE_FORWARD_FILE ;;
            10) read -p "Введите имя файла обратной зоны VLAN100: " ZONE_REV100_FILE ;;
            11) read -p "Введите имя файла обратной зоны VLAN200: " ZONE_REV200_FILE ;;
            12) read -p "Введите каталог зон: " ZONE_DIR ;;
            13) read -p "Введите PTR для 1 (VLAN100): " PTR_100_1 ;;
            14) read -p "Введите PTR для 2 (VLAN100): " PTR_100_2 ;;
            15) read -p "Введите PTR для 10 (VLAN200): " PTR_200_10 ;;
            16) read -p "Введите A-запись HQ-RTR: " A_HQ_RTR ;;
            17) read -p "Введите A-запись BR-RTR: " A_BR_RTR ;;
            18) read -p "Введите A-запись HQ-SRV: " A_HQ_SRV ;;
            19) read -p "Введите A-запись HQ-CLI: " A_HQ_CLI ;;
            20) read -p "Введите A-запись BR-SRV: " A_BR_SRV ;;
            21) read -p "Введите название обратной зоны VLAN100: " REV_ZONE_100 ;;
            22) read -p "Введите название обратной зоны VLAN200: " REV_ZONE_200 ;;
            23)
                read -p "Имя машины: " HOSTNAME
                read -p "Имя пользователя SSH: " SSHUSER
                read -p "UID пользователя SSH: " SSHUSER_UID
                read -s -p "Пароль пользователя SSH: " SSHUSER_PASS; echo
                read -p "Часовой пояс: " TZ
                read -p "Порт SSH: " SSH_PORT
                read -p "Баннер SSH: " BANNER
                read -p "Имя домена DNS: " DNS_DOMAIN
                read -p "Имя файла прямой зоны: " ZONE_FORWARD_FILE
                read -p "Имя файла обратной зоны VLAN100: " ZONE_REV100_FILE
                read -p "Имя файла обратной зоны VLAN200: " ZONE_REV200_FILE
                read -p "Каталог зон: " ZONE_DIR
                read -p "PTR для 1 (VLAN100): " PTR_100_1
                read -p "PTR для 2 (VLAN100): " PTR_100_2
                read -p "PTR для 10 (VLAN200): " PTR_200_10
                read -p "A-запись HQ-RTR: " A_HQ_RTR
                read -p "A-запись BR-RTR: " A_BR_RTR
                read -p "A-запись HQ-SRV: " A_HQ_SRV
                read -p "A-запись HQ-CLI: " A_HQ_CLI
                read -p "A-запись BR-SRV: " A_BR_SRV
                read -p "Название обратной зоны VLAN100: " REV_ZONE_100
                read -p "Название обратной зоны VLAN200: " REV_ZONE_200
                ;;
            0) break ;;
            *) echo "Ошибка ввода"; sleep 1 ;;
        esac
    done
}

# === УСТАНОВКА ЗАВИСИМОСТЕЙ ===
function install_deps() {
    apt-get update
    apt-get install -y mc sudo openssh-server bind bind-utils
}

# === 1. Смена имени хоста ===
function set_hostname() {
    echo "$HOSTNAME" > /etc/hostname
    hostnamectl set-hostname "$HOSTNAME"
    grep -q "$HOSTNAME" /etc/hosts || echo "127.0.0.1   $HOSTNAME" >> /etc/hosts
    echo "Имя хоста установлено: $HOSTNAME"
    sleep 2
}

# === 2. Создание пользователя sshuser ===
function create_sshuser() {
    id "$SSHUSER" &>/dev/null || useradd -u "$SSHUSER_UID" -m "$SSHUSER"
    echo "$SSHUSER:$SSHUSER_PASS" | chpasswd
    usermod -aG sudo "$SSHUSER"
    grep -q "$SSHUSER" /etc/sudoers || echo "$SSHUSER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    echo "Пользователь $SSHUSER создан и добавлен в sudoers"
    sleep 2
}

# === 3. Настройка SSH ===
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

# === 4. Настройка DNS (bind, всё из переменных) ===
function config_dns() {
    echo "Настройка DNS (bind)"
    apt-get update
    apt-get install -y bind bind-utils

    systemctl enable --now bind

    mkdir -p "$ZONE_DIR"

    # Конфиг зон
    cat > "$LOCAL_CONF" <<EOF
zone "$DNS_DOMAIN" {
    type master;
    file "$ZONE_FORWARD_FILE";
};

zone "$REV_ZONE_100" {
    type master;
    file "$ZONE_REV100_FILE";
};
zone "$REV_ZONE_200" {
    type master;
    file "$ZONE_REV200_FILE";
};
EOF

    # Обратные зоны
    cat > "$ZONE_DIR/$ZONE_REV100_FILE" <<EOF
\$TTL  1D
@    IN    SOA  $DNS_DOMAIN. root.$DNS_DOMAIN. (
                2025020600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; ncache
            )
     IN    NS     $DNS_DOMAIN.
1    IN    PTR    $PTR_100_1.$DNS_DOMAIN.
2    IN    PTR    $PTR_100_2.$DNS_DOMAIN.
EOF

    cat > "$ZONE_DIR/$ZONE_REV200_FILE" <<EOF
\$TTL  1D
@    IN    SOA  $DNS_DOMAIN. root.$DNS_DOMAIN. (
                2025020600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; ncache
            )
      IN    NS     $DNS_DOMAIN.
10    IN    PTR    $PTR_200_10.$DNS_DOMAIN.
EOF

    # Прямая зона
    cat > "$ZONE_DIR/$ZONE_FORWARD_FILE" <<EOF
\$TTL  1D
@    IN    SOA  $DNS_DOMAIN. root.$DNS_DOMAIN. (
                2025020600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; ncache
            )
        IN    NS       $DNS_DOMAIN.
        IN    A        127.0.0.1
hq-rtr  IN    A        $A_HQ_RTR
br-rtr  IN    A        $A_BR_RTR
hq-srv  IN    A        $A_HQ_SRV
hq-cli  IN    A        $A_HQ_CLI
br-srv  IN    A        $A_BR_SRV
moodle  IN    CNAME    hq-rtr
wiki    IN    CNAME    hq-rtr
EOF

    # Включаем local.conf в основной named.conf, если не включён
    grep -q 'local.conf' "$NAMED_CONF" || echo "include \"$LOCAL_CONF\";" >> "$NAMED_CONF"

    systemctl restart bind

    echo "DNS-сервер (bind) настроен!"
    sleep 2
}

# === 5. Настройка часового пояса ===
function set_timezone() {
    timedatectl set-timezone "$TZ"
    echo "Часовой пояс установлен: $TZ"
    sleep 2
}

# === 6. Настроить всё сразу ===
function do_all() {
    install_deps
    set_hostname
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
        echo "2. Установить зависимости"
        echo "3. Сменить имя хоста"
        echo "4. Создать пользователя SSH ($SSHUSER)"
        echo "5. Настроить SSH"
        echo "6. Настроить DNS (bind)"
        echo "7. Настроить часовой пояс"
        echo "8. Настроить всё сразу"
        echo "0. Выйти"
        read -p "Выберите пункт: " choice
        case "$choice" in
            1) input_menu ;;
            2) install_deps ;;
            3) set_hostname ;;
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

if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт от root"
    exit 1
fi

main_menu
