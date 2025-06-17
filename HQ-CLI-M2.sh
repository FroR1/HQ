#!/bin/bash


function yand() {
    systemctl disable NetworkManager
    mkdir /root/yandex-browser/
    cd /root/yandex-browser/
    wget https://download.yandex.ru/browser/alt-os/yandex-browser.rpm
    rpm -i yandex-browser.rpm
    clear
    echo "Яндекс браузер установлен"
    
}

function main_menu() {
    while true; do
        clear
        echo "=== МЕНЮ НАСТРОЙКИ HQ-CLI ==="
        echo "1. Ввод/изменение данных"
        echo "0. Выйти"
        read -p "Выберите пункт: " choice
        case "$choice" in
            1) yand ;;
            0) clear; exit 0 ;;
            *) echo "Ошибка ввода"; sleep 1 ;;
        esac
    done
}

if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт от root"
    exit 1
fi

install_deps
main_menu
