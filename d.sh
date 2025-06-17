#!/bin/bash
# Модификация /etc/bind/options.conf
echo "Модификация параметров в /etc/bind/options.conf..."
if [ -f /etc/bind/options.conf ]; then
    # Установка listen-on
    if grep -q "^[[:space:]]*listen-on[[:space:]]*{" /etc/bind/options.conf; then
        sed -i 's/^[[:space:]]*listen-on[[:space:]]*{.*};/    listen-on { any; };/' /etc/bind/options.conf
    else
        echo "    listen-on { any; };" >> /etc/bind/options.conf
    fi
    
    # Закомментирование listen-on-v6
    if grep -q "^[[:space:]]*listen-on-v6[[:space:]]*{" /etc/bind/options.conf; then
        sed -i 's/^[[:space:]]*\/\/*[[:space:]]*listen-on-v6[[:space:]]*{.*};/    \/\/ listen-on-v6 { any; };/' /etc/bind/options.conf
    else
        echo "    // listen-on-v6 { any; };" >> /etc/bind/options.conf
    fi
    
    # Изменение forward (only или first) на forward first
    if grep -q "^[[:space:]]*forward[[:space:]]*\(only\|first\);" /etc/bind/options.conf; then
        sed -i 's/^[[:space:]]*\/\/*[[:space:]]*forward[[:space:]]*\(only\|first\);/    forward first;/' /etc/bind/options.conf
    else
        echo "    forward first;" >> /etc/bind/options.conf
    fi
    
    # Установка forwarders без комментариев
    if grep -q "^[[:space:]]*forwarders[[:space:]]*{" /etc/bind/options.conf; then
        sed -i 's/^[[:space:]]*\/\/*[[:space:]]*forwarders[[:space:]]*{.*};/    forwarders { 77.88.8.8; };/' /etc/bind/options.conf
    else
        echo "    forwarders { 77.88.8.8; };" >> /etc/bind/options.conf
    fi
    
    # Установка allow-query без комментариев
    if grep -q "^[[:space:]]*allow-query[[:space:]]*{" /etc/bind/options.conf; then
        sed -i 's/^[[:space:]]*\/\/*[[:space:]]*allow-query[[:space:]]*{.*};/    allow-query { any; };/' /etc/bind/options.conf
    else
        echo "    allow-query { any; };" >> /etc/bind/options.conf
    fi
else
    echo "Файл /etc/bind/options.conf не найден, создаю новый..."
    cat > /etc/bind/options.conf << EOF
options {
    listen-on { any; };
    // listen-on-v6 { any; };
    forward first;
    forwarders { 77.88.8.8; };
    allow-query { any; };
};
EOF
fi
