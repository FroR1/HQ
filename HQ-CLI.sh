#!/bin/bash

# === НАСТРОЙКИ ПО УМОЛЧАНИЮ ===
HOSTNAME="hq-cli.au-team.irpo"
TZ="Asia/Novosibirsk"
REPORT_FILE="/root/report.txt"

# === ФУНКЦИИ ДЛЯ ВВОДА ДАННЫХ ===
function input_menu() {
    while true; do
        clear
        echo "=== Подменю ввода/изменения данных ==="
        echo "1. Изменить имя машины (текущее: $HOSTNAME)"
        echo "2. Изменить часовой пояс (текущий: $TZ)"
        echo "3. Изменить все параметры сразу"
        echo "0. Назад"
        read -p "Выберите пункт: " subchoice
        case "$subchoice" in
            1) read -p "Введите новое имя машины: " HOSTNAME ;;
            2) read -p "Введите новый часовой пояс: " TZ ;;
            3)
                read -p "Имя машины: " HOSTNAME
                read -p "Часовой пояс: " TZ
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
    apt-get install -y mc sudo tzdata
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

# === 2. Настройка часового пояса ===
function set_timezone() {
    echo "Настройка часового пояса..." | tee -a "$REPORT_FILE"
    timedatectl set-timezone "$TZ"
    echo "Часовой пояс установлен: $TZ" | tee -a "$REPORT_FILE"
    sleep 2
}

# === 3. Настроить всё сразу ===
function do_all() {
    set_hostname
    set_timezone
    echo "Все задания выполнены!" | tee -a "$REPORT_FILE"
    sleep 2
}



# === МЕНЮ ===
function main_menu() {
    while true; do
        clear
        echo "=== МЕНЮ НАСТРОЙКИ HQ-CLI ==="
        echo "1. Ввод/изменение данных"
        echo "2. Сменить имя хоста"
        echo "3. Настроить часовой пояс"
        echo "4. Настроить всё сразу"
        echo "0. Выйти"
        read -p "Выберите пункт: " choice
        case "$choice" in
            1) input_menu ;;
            2) set_hostname ;;
            3) set_timezone ;;
            4) do_all ;;
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
