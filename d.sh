#!/bin/bash
# Модификация /etc/bind/named.conf.options
echo "Модификация параметров в /etc/bind/named.conf.options..."
if [ -f /etc/bind/named.conf.options ]; then
    # Установка listen-on
    if grep -q "^[[:space:]]*listen-on[[:space:]]*{" /etc/bind/named.conf.options; then
        sed -i 's/^[[:space:]]*listen-on[[:space:]]*{.*};/    listen-on { any; };/' /etc/bind/named.conf.options
    else
        echo "    listen-on { any; };" >> /etc/bind/named.conf.options
    fi
    
    # Закомментирование listen-on-v6
    if grep -q "^[[:space:]]*listen-on-v6[[:space:]]*{" /etc/bind/named.conf.options; then
        sed -i 's/^[[:space:]]*\/\/*[[:space:]]*listen-on-v6[[:space:]]*{.*};/    \/\/ listen-on-v6 { any; };/' /etc/bind/named.conf.options
    else
        echo "    // listen-on-v6 { any; };" >> /etc/bind/named.conf.options
    fi
    
    # Изменение forward (only или first) на forward first
    if grep -q "^[[:space:]]*forward[[:space:]]*\(only\|first\);" /etc/bind/named.conf.options; then
        sed -i 's/^[[:space:]]*\/\/*[[:space:]]*forward[[:space:]]*\(only\|first\);/    forward first;/' /etc/bind/named.conf.options
    else
        echo "    forward first;" >> /etc/bind/named.conf.options
    fi
    
    # Установка forwarders без комментариев
    if grep -q "^[[:space:]]*forwarders[[:space:]]*{" /etc/bind/named.conf.options; then
        sed -i 's/^[[:space:]]*\/\/*[[:space:]]*forwarders[[:space:]]*{.*};/    forwarders { 77.88.8.8; };/' /etc/bind/named.conf.options
    else
        echo "    forwarders { 77.88.8.8; };" >> /etc/bind/named.conf.options
    fi
    
    # Установка allow-query без комментариев
    if grep -q "^[[:space:]]*allow-query[[:space:]]*{" /etc/bind/named.conf.options; then
        sed -i 's/^[[:space:]]*\/\/*[[:space:]]*allow-query[[:space:]]*{.*};/    allow-query { any; };/' /etc/bind/named.conf.options
    else
        echo "    allow-query { any; };" >> /etc/bind/named.conf.options
    fi
else
    echo "Файл /etc/bind/named.conf.options не найден, создаю новый..."
    cat > /etc/bind/named.conf.options << EOF
options {
    listen-on { any; };
    // listen-on-v6 { any; };
    forward first;
    forwarders { 77.88.8.8; };
    allow-query { any; };
};
EOF
fi
