#!/bin/bash

# Скрипт для настройки маршрутизатора HQ-RTR

# Установка зависимостей
install_dependencies() {
    echo "Установка зависимостей..."
    apt-get update
    apt-get install -y iproute2 nftables systemd frr dhcp-server mc wget openssh-server sudo
    echo "Зависимости установлены."
}

install_dependencies

# Начальные значения переменных
INTERFACE_ISP="ens192"
INTERFACE_VLAN_BASE="ens224"  # Физический интерфейс для VLAN (в сторону HQ-SRV, HQ-CLI, MGMT)
VLAN_SRV_ID="15"
VLAN_CLI_ID="25"
VLAN_MGMT_ID="99"
IP_VLAN_SRV="192.168.15.1/27"
IP_VLAN_CLI="192.168.25.1/28"
IP_VLAN_MGMT="192.168.99.1/29"
HOSTNAME="hq-rtr.au-team.irpo"
TIME_ZONE="Asia/Novosibirsk"
USERNAME="net_admin"
USER_UID=1010
BANNER_TEXT="Authorized access only"
TUNNEL_LOCAL_IP="172.16.4.2"
TUNNEL_REMOTE_IP="172.16.5.2"
TUNNEL_IP="172.16.100.1/28"
TUNNEL_NAME="gre1"
DHCP_VLAN_CLI="${INTERFACE_VLAN_BASE}.${VLAN_CLI_ID}"
DHCP_SUBNET="192.168.20.0"
DHCP_NETMASK="255.255.255.240"
DHCP_RANGE_START="192.168.20.10"
DHCP_RANGE_END="192.168.20.11"
DHCP_DNS="192.168.10.2"

# Функция проверки существования интерфейса
check_interface() {
    if ! ip link show "$1" &> /dev/null; then
        echo "Ошибка: Интерфейс $1 не существует."
        exit 1
    fi
}

# Функция вычисления сети из IP и маски
get_network() {
    local ip_mask=$1
    local ip=$(echo "$ip_mask" | cut -d'/' -f1)
    local mask=$(echo "$ip_mask" | cut -d'/' -f2)
    local IFS='.'
    read -r i1 i2 i3 i4 <<< "$ip"
    local bits=$((32 - mask))
    local net=$(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 ))
    local net=$(( net >> bits << bits ))
    echo "$(( (net >> 24) & 255 )).$(( (net >> 16) & 255 )).$(( (net >> 8) & 255 )).$(( net & 255 ))/$mask"
}

# Функция настройки сетевых интерфейсов через /etc/net/ifaces/
configure_interfaces() {
    echo "Настройка интерфейсов через /etc/net/ifaces/..."
    
    check_interface "$INTERFACE_ISP"
    check_interface "$INTERFACE_VLAN_BASE"  # Проверка базового интерфейса для VLAN
    
    # Настройка интерфейса ISP
    mkdir -p /etc/net/ifaces/"$INTERFACE_ISP"
    cat > /etc/net/ifaces/"$INTERFACE_ISP"/options << EOF
BOOTPROTO=static
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
EOF
    
    # Настройка базового интерфейса для VLAN
    mkdir -p /etc/net/ifaces/"$INTERFACE_VLAN_BASE"
    cat > /etc/net/ifaces/"$INTERFACE_VLAN_BASE"/options << EOF
BOOTPROTO=static
TYPE=eth
DISABLED=no
CONFIG_IPV4=yes
EOF
    
    # Настройка VLAN интерфейсов
    for vlan in "$VLAN_SRV_ID" "$VLAN_CLI_ID" "$VLAN_MGMT_ID"; do
        iface="${INTERFACE_VLAN_BASE}.$vlan"
        # Сопоставление VLAN с переменной IP-адреса
        case $vlan in
            "$VLAN_SRV_ID") ip_addr="$IP_VLAN_SRV" ;;
            "$VLAN_CLI_ID") ip_addr="$IP_VLAN_CLI" ;;
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
    
    systemctl restart network
    echo "Интерфейсы настроены."
}

# Функция настройки GRE-туннеля через /etc/net/ifaces/
configure_tunnel() {
    echo "Настройка GRE-туннеля через /etc/net/ifaces/..."
    
    modprobe gre
    
    mkdir -p /etc/net/ifaces/"$TUNNEL_NAME"
    cat > /etc/net/ifaces/"$TUNNEL_NAME"/options << EOF
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=$TUNNEL_LOCAL_IP
TUNREMOTE=$TUNNEL_REMOTE_IP
TUNOPTIONS='ttl 64'
HOST=$INTERFACE_ISP
BOOTPROTO=static
DISABLED=no
CONFIG_IPV4=yes
EOF
    echo "$TUNNEL_IP" > /etc/net/ifaces/"$TUNNEL_NAME"/ipv4address
    
    ip link set "$TUNNEL_NAME" down 2>/dev/null || true
    ip tunnel del "$TUNNEL_NAME" 2>/dev/null || true
    ip tunnel add "$TUNNEL_NAME" mode gre local "$TUNNEL_LOCAL_IP" remote "$TUNNEL_REMOTE_IP" ttl 64
    ip addr add "$TUNNEL_IP" dev "$TUNNEL_NAME"
    ip link set "$TUNNEL_NAME" up
    
    systemctl restart network
    echo "GRE-туннель настроен."
}

# Функция настройки nftables и пересылки IP
configure_nftables() {
    echo "Настройка nftables и пересылки IP..."
    
    apt-get install -y nftables
    
    # Вычисление сетей для NAT
    VLAN_SRV_NETWORK=$(get_network "$IP_VLAN_SRV")
    VLAN_CLI_NETWORK=$(get_network "$IP_VLAN_CLI")
    VLAN_MGMT_NETWORK=$(get_network "$IP_VLAN_MGMT")
    
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
        ip saddr $VLAN_SRV_NETWORK oifname "$INTERFACE_ISP" counter masquerade
        ip saddr $VLAN_CLI_NETWORK oifname "$INTERFACE_ISP" counter masquerade
        ip saddr $VLAN_MGMT_NETWORK oifname "$INTERFACE_ISP" counter masquerade
    }
}
EOF
    
    nft -f /etc/nftables/nftables.nft
    systemctl enable --now nftables
    echo "nftables и пересылка IP настроены."
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

# Функция настройки OSPF
configure_ospf() {
    echo "Настройка OSPF..."
    
    TUNNEL_NETWORK=$(get_network "$TUNNEL_IP")
    VLAN_SRV_NETWORK=$(get_network "$IP_VLAN_SRV")
    VLAN_CLI_NETWORK=$(get_network "$IP_VLAN_CLI")
    VLAN_MGMT_NETWORK=$(get_network "$IP_VLAN_MGMT")
    
    if grep -q "ospfd=no" /etc/frr/daemons; then
        sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
    elif ! grep -q "ospfd=yes" /etc/frr/daemons; then
        echo "ospfd=yes" >> /etc/frr/daemons
    fi
    systemctl enable --now frr
    
    vtysh << EOF
configure terminal
router ospf
passive-interface default
network $TUNNEL_NETWORK area 0
network $VLAN_SRV_NETWORK area 0
network $VLAN_CLI_NETWORK area 0
network $VLAN_MGMT_NETWORK area 0
exit
interface $TUNNEL_NAME
no ip ospf passive
ip ospf authentication-key PLAINPAS
ip ospf authentication
exit
do wr mem
exit
EOF
    
    echo "OSPF настроен."
}

# Функция настройки DHCP
configure_dhcp() {
    echo "Настройка DHCP..."
    apt-get install -y dhcp-server
    sed -i "s/DHCPDARGS=.*/DHCPDARGS=$DHCP_VLAN_CLI/" /etc/sysconfig/dhcpd
    systemctl enable --now dhcpd.service
    cat > /etc/dhcp/dhcpd.conf << EOF
default-lease-time 6000;
max-lease-time 72000;
authoritative;

# subnet for VLAN $VLAN_CLI_ID (HQ-CLI)
subnet $DHCP_SUBNET netmask $DHCP_NETMASK {
    range $DHCP_RANGE_START $DHCP_RANGE_END;
    option domain-name-servers $DHCP_DNS;
    option domain-name "au-team.irpo";
    option routers $(echo $IP_VLAN_CLI | cut -d'/' -f1);
}
EOF
    systemctl restart dhcpd.service
    echo "DHCP настроен."
}

# Функция редактирования данных
edit_data() {
    while true; do
        clear
        echo "Текущие значения:"
        echo "1. Интерфейс к ISP: $INTERFACE_ISP"
        echo "2. Базовый интерфейс для VLAN (в сторону HQ-SRV, HQ-CLI, MGMT): $INTERFACE_VLAN_BASE"
        echo "3. ID VLAN SRV: $VLAN_SRV_ID"
        echo "4. ID VLAN CLI (используется для DHCP): $VLAN_CLI_ID"
        echo "5. ID VLAN MGMT: $VLAN_MGMT_ID"
        echo "6. IP для VLAN SRV: $IP_VLAN_SRV"
        echo "7. IP для VLAN CLI: $IP_VLAN_CLI"
        echo "8. IP для VLAN MGMT: $IP_VLAN_MGMT"
        echo "9. Hostname: $HOSTNAME"
        echo "10. Часовой пояс: $TIME_ZONE"
        echo "11. Имя пользователя: $USERNAME"
        echo "12. UID пользователя: $USER_UID"
        echo "13. Текст баннера: $BANNER_TEXT"
        echo "14. Локальный IP для туннеля: $TUNNEL_LOCAL_IP"
        echo "15. Удаленный IP для туннеля: $TUNNEL_REMOTE_IP"
        echo "16. IP для туннеля: $TUNNEL_IP"
        echo "17. Подсеть для DHCP: $DHCP_SUBNET"
        echo "18. Маска для DHCP: $DHCP_NETMASK"
        echo "19. Начало диапазона DHCP: $DHCP_RANGE_START"
        echo "20. Конец диапазона DHCP: $DHCP_RANGE_END"
        echo "21. DNS для DHCP: $DHCP_DNS"
        echo "0. Назад"
        read -p "Введите номер параметра для изменения: " choice
        case $choice in
            1) read -p "Новый интерфейс к ISP [$INTERFACE_ISP]: " input
               INTERFACE_ISP=${input:-$INTERFACE_ISP} ;;
            2) read -p "Новый базовый интерфейс для VLAN [$INTERFACE_VLAN_BASE]: " input
               new_base=${input:-$INTERFACE_VLAN_BASE}
               if [ "$new_base" != "$INTERFACE_VLAN_BASE" ]; then
                   INTERFACE_VLAN_BASE=$new_base
                   DHCP_VLAN_CLI="$INTERFACE_VLAN_BASE.$VLAN_CLI_ID"
               fi ;;
            3) read -p "Новый ID VLAN SRV [$VLAN_SRV_ID]: " input
               VLAN_SRV_ID=${input:-$VLAN_SRV_ID} ;;
            4) read -p "Новый ID VLAN CLI [$VLAN_CLI_ID]: " input
               VLAN_CLI_ID=${input:-$VLAN_CLI_ID}
               DHCP_VLAN_CLI="$INTERFACE_VLAN_BASE.$VLAN_CLI_ID" ;;
            5) read -p "Новый ID VLAN MGMT [$VLAN_MGMT_ID]: " input
               VLAN_MGMT_ID=${input:-$VLAN_MGMT_ID} ;;
            6) read -p "Новый IP для VLAN SRV [$IP_VLAN_SRV]: " input
               IP_VLAN_SRV=${input:-$IP_VLAN_SRV} ;;
            7) read -p "Новый IP для VLAN CLI [$IP_VLAN_CLI]: " input
               IP_VLAN_CLI=${input:-$IP_VLAN_CLI} ;;
            8) read -p "Новый IP для VLAN MGMT [$IP_VLAN_MGMT]: " input
               IP_VLAN_MGMT=${input:-$IP_VLAN_MGMT} ;;
            9) read -p "Новый hostname [$HOSTNAME]: " input
               HOSTNAME=${input:-$HOSTNAME} ;;
            10) read -p "Новый часовой пояс [$TIME_ZONE]: " input
                TIME_ZONE=${input:-$TIME_ZONE} ;;
            11) read -p "Новое имя пользователя [$USERNAME]: " input
                USERNAME=${input:-$USERNAME} ;;
            12) read -p "Новый UID пользователя [$USER_UID]: " input
                USER_UID=${input:-$USER_UID} ;;
            13) read -p "Новый текст баннера [$BANNER_TEXT]: " input
                BANNER_TEXT=${input:-$BANNER_TEXT} ;;
            14) read -p "Новый локальный IP для туннеля [$TUNNEL_LOCAL_IP]: " input
                TUNNEL_LOCAL_IP=${input:-$TUNNEL_LOCAL_IP} ;;
            15) read -p "Новый удаленный IP для туннеля [$TUNNEL_REMOTE_IP]: " input
                TUNNEL_REMOTE_IP=${input:-$TUNNEL_REMOTE_IP} ;;
            16) read -p "Новый IP для туннеля [$TUNNEL_IP]: " input
                TUNNEL_IP=${input:-$TUNNEL_IP} ;;
            17) read -p "Новая подсеть для DHCP [$DHCP_SUBNET]: " input
                DHCP_SUBNET=${input:-$DHCP_SUBNET} ;;
            18) read -p "Новая маска для DHCP [$DHCP_NETMASK]: " input
                DHCP_NETMASK=${input:-$DHCP_NETMASK} ;;
            19) read -p "Новое начало диапазона DHCP [$DHCP_RANGE_START]: " input
                DHCP_RANGE_START=${input:-$DHCP_RANGE_START} ;;
            20) read -p "Новый конец диапазона DHCP [$DHCP_RANGE_END]: " input
                DHCP_RANGE_END=${input:-$DHCP_RANGE_END} ;;
            21) read -p "Новый DNS для DHCP [$DHCP_DNS]: " input
                DHCP_DNS=${input:-$DHCP_DNS} ;;
            0) return ;;
            *) echo "Неверный выбор." ;;
        esac
    done
}

# Основное меню
while true; do
    clear
    echo -e "\nМеню настройки HQ-RTR:"
    echo "1. Редактировать данные"
    echo "2. Настроить сетевые интерфейсы"
    echo "3. Настроить NAT и пересылку IP"
    echo "4. Настроить GRE-туннель"
    echo "5. Настроить OSPF"
    echo "6. Настроить DHCP"
    echo "7. Установить имя хоста"
    echo "8. Установить часовой пояс"
    echo "9. Настроить пользователя"
    echo "10. Настроить баннер SSH"
    echo "11. Выполнить все настройки"
    echo "0. Выход"
    read -p "Выберите опцию: " option
    case $option in
        1) edit_data ;;
        2) configure_interfaces ;;
        3) configure_nftables ;;
        4) configure_tunnel ;;
        5) configure_ospf ;;
        6) configure_dhcp ;;
        7) set_hostname ;;
        8) set_timezone ;;
        9) configure_user ;;
        10) configure_ssh_banner ;;
        11) 
            configure_interfaces
            configure_nftables
            configure_tunnel
            configure_ospf
            configure_dhcp
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
