#!/bin/bash

# Скрипт для настройки маршрутизатора HQ-RTR

# Установка зависимостей
install_dependencies() {
    echo "Установка зависимостей..."
    apt-get update
    apt-get install -y iproute2 nftables systemd frr isc-dhcp-server
    echo "Зависимости установлены."
}

install_dependencies

# Начальные значения переменных
INTERFACE_ISP="ens192"
INTERFACE_VLAN_SRV="ens224.100"
INTERFACE_VLAN_CLI="ens224.200"
INTERFACE_VLAN_MGMT="ens224.999"
IP_ISP="172.16.4.2/28"
IP_VLAN_SRV="192.168.10.1/26"
IP_VLAN_CLI="192.168.20.1/28"
IP_VLAN_MGMT="192.168.99.1/29"
DEFAULT_GW="172.16.4.1"
HOSTNAME="hq-rtr.au-team.irpo"
TIME_ZONE="Asia/Novosibirsk"
USERNAME="net_admin"
UID=1010
PASSWORD="P@$$word"
BANNER_TEXT="Authorized access only"
TUNNEL_LOCAL_IP="172.16.4.2"
TUNNEL_REMOTE_IP="172.16.5.2"
TUNNEL_IP="172.16.100.1/28"
TUNNEL_NAME="gre1"
DHCP_INTERFACE="ens224.200"
DHCP_SUBNET="192.168.20.0"
DHCP_NETMASK="255.255.255.240"
DHCP_RANGE_START="192.168.20.10"
DHCP_RANGE_END="192.168.20.11"
DHCP_DNS="192.168.10.2"

# Функция настройки сетевых интерфейсов
configure_interfaces() {
    echo "Настройка интерфейсов..."
    ip addr add "$IP_ISP" dev "$INTERFACE_ISP"
    ip link set "$INTERFACE_ISP" up
    ip route add default via "$DEFAULT_GW"
    ip addr add "$IP_VLAN_SRV" dev "$INTERFACE_VLAN_SRV"
    ip link set "$INTERFACE_VLAN_SRV" up
    ip addr add "$IP_VLAN_CLI" dev "$INTERFACE_VLAN_CLI"
    ip link set "$INTERFACE_VLAN_CLI" up
    ip addr add "$IP_VLAN_MGMT" dev "$INTERFACE_VLAN_MGMT"
    ip link set "$INTERFACE_VLAN_MGMT" up
    echo "Интерфейсы настроены."
}

# Функция настройки NAT
configure_nftables() {
    echo "Настройка NAT..."
    sysctl -w net.ipv4.ip_forward=1
    nft add table inet nat
    nft add chain inet nat postrouting '{ type nat hook postrouting priority 100 ; policy accept ; }'
    nft add rule inet nat postrouting ip saddr 192.168.20.0/28 oifname "$INTERFACE_ISP" masquerade
    nft add rule inet nat postrouting ip saddr 192.168.10.0/26 oifname "$INTERFACE_ISP" masquerade
    nft add rule inet nat postrouting ip saddr 192.168.99.0/29 oifname "$INTERFACE_ISP" masquerade
    systemctl enable nftables
    systemctl restart nftables
    echo "NAT настроен."
}

# Функция настройки GRE-туннеля
configure_tunnel() {
    echo "Настройка GRE-туннеля..."
    ip tunnel add "$TUNNEL_NAME" mode gre local "$TUNNEL_LOCAL_IP" remote "$TUNNEL_REMOTE_IP" ttl 64
    ip addr add "$TUNNEL_IP" dev "$TUNNEL_NAME"
    ip link set "$TUNNEL_NAME" up
    echo "GRE-туннель настроен."
}

# Функция настройки OSPF
configure_ospf() {
    echo "Настройка OSPF..."
    sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
    systemctl enable --now frr
    vtysh << EOF
configure terminal
router ospf
network 172.16.100.0/28 area 0
network 192.168.10.0/26 area 0
network 192.168.20.0/28 area 0
network 192.168.99.0/29 area 0
exit
do wr mem
exit
EOF
    echo "OSPF настроен."
}

# Функция настройки DHCP
configure_dhcp() {
    echo "Настройка DHCP..."
    apt-get install -y isc-dhcp-server
    sed -i "s/DHCPDARGS=.*/DHCPDARGS=$DHCP_INTERFACE/" /etc/sysconfig/dhcpd
    cat > /etc/dhcp/dhcpd.conf << EOF
default-lease-time 6000;
max-lease-time 72000;
authoritative;

# subnet for VLAN 200 (HQ-CLI)
subnet $DHCP_SUBNET netmask $DHCP_NETMASK {
    range $DHCP_RANGE_START $DHCP_RANGE_END;
    option domain-name-servers $DHCP_DNS;
    option domain-name "au-team.irpo";
    option routers $(echo $IP_VLAN_CLI | cut -d'/' -f1);
}
EOF
    systemctl restart dhcpd
    echo "DHCP настроен."
}

# Функция установки hostname
set_hostname() {
    echo "Установка hostname..."
    hostnamectl set-hostname "$HOSTNAME"
    echo "Hostname установлен."
}

# Функция установки часового пояса
set_timezone() {
    echo "Установка часового пояса..."
    timedatectl set-timezone "$TIME_ZONE"
    echo "Часовой пояс установлен."
}

# Функция создания пользователя
configure_user() {
    echo "Создание пользователя..."
    useradd -m -u "$UID" -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "Пользователь $USERNAME создан."
}

# Функция настройки баннера
configure_banner() {
    echo "Настройка баннера..."
    echo "$BANNER_TEXT" > /etc/issue
    echo "Баннер настроен."
}

# Функция редактирования данных
edit_data() {
    while true; do
        clear
        echo "Текущие значения:"
        echo "1. Интерфейс к ISP: $INTERFACE_ISP"
        echo "2. Интерфейс VLAN SRV: $INTERFACE_VLAN_SRV"
        echo "3. Интерфейс VLAN CLI: $INTERFACE_VLAN_CLI"
        echo "4. Интерфейс VLAN MGMT: $INTERFACE_VLAN_MGMT"
        echo "5. IP для ISP: $IP_ISP"
        echo "6. IP для VLAN SRV: $IP_VLAN_SRV"
        echo "7. IP для VLAN CLI: $IP_VLAN_CLI"
        echo "8. IP для VLAN MGMT: $IP_VLAN_MGMT"
        echo "9. Шлюз по умолчанию: $DEFAULT_GW"
        echo "10. Hostname: $HOSTNAME"
        echo "11. Часовой пояс: $TIME_ZONE"
        echo "12. Имя пользователя: $USERNAME"
        echo "13. UID пользователя: $UID"
        echo "14. Пароль пользователя: $PASSWORD"
        echo "15. Текст баннера: $BANNER_TEXT"
        echo "16. Локальный IP для туннеля: $TUNNEL_LOCAL_IP"
        echo "17. Удаленный IP для туннеля: $TUNNEL_REMOTE_IP"
        echo "18. IP для туннеля: $TUNNEL_IP"
        echo "19. Интерфейс для DHCP: $DHCP_INTERFACE"
        echo "20. Подсеть для DHCP: $DHCP_SUBNET"
        echo "21. Маска для DHCP: $DHCP_NETMASK"
        echo "22. Начало диапазона DHCP: $DHCP_RANGE_START"
        echo "23. Конец диапазона DHCP: $DHCP_RANGE_END"
        echo "24. DNS для DHCP: $DHCP_DNS"
        echo "0. Назад"
        read -p "Введите номер параметра для изменения: " choice
        case $choice in
            1) read -p "Новый интерфейс к ISP [$INTERFACE_ISP]: " input
               INTERFACE_ISP=${input:-$INTERFACE_ISP} ;;
            2) read -p "Новый интерфейс VLAN SRV [$INTERFACE_VLAN_SRV]: " input
               INTERFACE_VLAN_SRV=${input:-$INTERFACE_VLAN_SRV} ;;
            3) read -p "Новый интерфейс VLAN CLI [$INTERFACE_VLAN_CLI]: " input
               INTERFACE_VLAN_CLI=${input:-$INTERFACE_VLAN_CLI} ;;
            4) read -p "Новый интерфейс VLAN MGMT [$INTERFACE_VLAN_MGMT]: " input
               INTERFACE_VLAN_MGMT=${input:-$INTERFACE_VLAN_MGMT} ;;
            5) read -p "Новый IP для ISP [$IP_ISP]: " input
               IP_ISP=${input:-$IP_ISP} ;;
            6) read -p "Новый IP для VLAN SRV [$IP_VLAN_SRV]: " input
               IP_VLAN_SRV=${input:-$IP_VLAN_SRV} ;;
            7) read -p "Новый IP для VLAN CLI [$IP_VLAN_CLI]: " input
               IP_VLAN_CLI=${input:-$IP_VLAN_CLI} ;;
            8) read -p "Новый IP для VLAN MGMT [$IP_VLAN_MGMT]: " input
               IP_VLAN_MGMT=${input:-$IP_VLAN_MGMT} ;;
            9) read -p "Новый шлюз по умолчанию [$DEFAULT_GW]: " input
               DEFAULT_GW=${input:-$DEFAULT_GW} ;;
            10) read -p "Новый hostname [$HOSTNAME]: " input
                HOSTNAME=${input:-$HOSTNAME} ;;
            11) read -p "Новый часовой пояс [$TIME_ZONE]: " input
                TIME_ZONE=${input:-$TIME_ZONE} ;;
            12) read -p "Новое имя пользователя [$USERNAME]: " input
                USERNAME=${input:-$USERNAME} ;;
            13) read -p "Новый UID пользователя [$UID]: " input
                UID=${input:-$UID} ;;
            14) read -p "Новый пароль пользователя [$PASSWORD]: " input
                PASSWORD=${input:-$PASSWORD} ;;
            15) read -p "Новый текст баннера [$BANNER_TEXT]: " input
                BANNER_TEXT=${input:-$BANNER_TEXT} ;;
            16) read -p "Новый локальный IP для туннеля [$TUNNEL_LOCAL_IP]: " input
                TUNNEL_LOCAL_IP=${input:-$TUNNEL_LOCAL_IP} ;;
            17) read -p "Новый удаленный IP для туннеля [$TUNNEL_REMOTE_IP]: " input
                TUNNEL_REMOTE_IP=${input:-$TUNNEL_REMOTE_IP} ;;
            18) read -p "Новый IP для туннеля [$TUNNEL_IP]: " input
                TUNNEL_IP=${input:-$TUNNEL_IP} ;;
            19) read -p "Новый интерфейс для DHCP [$DHCP_INTERFACE]: " input
                DHCP_INTERFACE=${input:-$DHCP_INTERFACE} ;;
            20) read -p "Новая подсеть для DHCP [$DHCP_SUBNET]: " input
                DHCP_SUBNET=${input:-$DHCP_SUBNET} ;;
            21) read -p "Новая маска для DHCP [$DHCP_NETMASK]: " input
                DHCP_NETMASK=${input:-$DHCP_NETMASK} ;;
            22) read -p "Новое начало диапазона DHCP [$DHCP_RANGE_START]: " input
                DHCP_RANGE_START=${input:-$DHCP_RANGE_START} ;;
            23) read -p "Новый конец диапазона DHCP [$DHCP_RANGE_END]: " input
                DHCP_RANGE_END=${input:-$DHCP_RANGE_END} ;;
            24) read -p "Новый DNS для DHCP [$DHCP_DNS]: " input
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
    echo "3. Настроить NAT и IP forwarding"
    echo "4. Настроить GRE-туннель"
    echo "5. Настроить OSPF"
    echo "6. Настроить DHCP"
    echo "7. Установить hostname"
    echo "8. Установить часовой пояс"
    echo "9. Настроить пользователя"
    echo "10. Настроить баннер"
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
        10) configure_banner ;;
        11) 
            configure_interfaces
            configure_nftables
            configure_tunnel
            configure_ospf
            configure_dhcp
            set_hostname
            set_timezone
            configure_user
            configure_banner
            echo "Все настройки выполнены."
            ;;
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор." ;;
    esac
done
