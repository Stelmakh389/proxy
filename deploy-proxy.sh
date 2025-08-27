#!/bin/bash

# Скрипт для быстрого развертывания прокси-сервера на сервере в Амстердаме

set -e

# Конфигурация
AMSTERDAM_SERVER="185.200.178.213"
AMSTERDAM_USER="root"
PROJECT_DIR="/opt/gemini-proxy"
LOCAL_DIR="/Users/andrejstelmah/Desktop/fast_docs/proxy-files"

echo "🚀 Начало развертывания Gemini API прокси..."

# Проверка доступности сервера
echo "📡 Проверка доступности сервера..."
if ! ping -c 1 $AMSTERDAM_SERVER > /dev/null 2>&1; then
    echo "❌ Сервер $AMSTERDAM_SERVER недоступен"
    exit 1
fi

echo "✅ Сервер доступен"

# Создание директории на удаленном сервере
echo "📁 Создание директории проекта..."
ssh $AMSTERDAM_USER@$AMSTERDAM_SERVER "mkdir -p $PROJECT_DIR"

# Копирование файлов
echo "📂 Копирование файлов на сервер..."
scp "$LOCAL_DIR/gemini-proxy-server.js" "$AMSTERDAM_USER@$AMSTERDAM_SERVER:$PROJECT_DIR/"
scp "$LOCAL_DIR/package-proxy.json" "$AMSTERDAM_USER@$AMSTERDAM_SERVER:$PROJECT_DIR/package.json"

# Установка зависимостей и запуск
echo "📦 Установка зависимостей и запуск сервиса..."
ssh $AMSTERDAM_USER@$AMSTERDAM_SERVER << 'ENDSSH'
    cd /opt/gemini-proxy
    
    # Установка Node.js если еще не установлен
    if ! command -v node &> /dev/null; then
        echo "🔧 Установка Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        apt-get install -y nodejs
    fi
    
    # Установка PM2 если еще не установлен
    if ! command -v pm2 &> /dev/null; then
        echo "🔧 Установка PM2..."
        npm install -g pm2
    fi
    
    # Установка зависимостей проекта
    echo "📦 Установка зависимостей..."
    npm install
    
    # Остановка старого процесса если существует
    echo "🛑 Остановка старого процесса..."
    pm2 stop gemini-proxy 2>/dev/null || true
    pm2 delete gemini-proxy 2>/dev/null || true
    
    # Запуск нового процесса
    echo "🚀 Запуск прокси-сервера..."
    pm2 start gemini-proxy-server.js --name gemini-proxy
    
    # Сохранение конфигурации PM2
    pm2 save
    
    # Настройка автозапуска (только если еще не настроен)
    if ! systemctl is-enabled pm2-root >/dev/null 2>&1; then
        echo "⚙️ Настройка автозапуска..."
        pm2 startup systemd -u root --hp /root
        systemctl enable pm2-root
    fi
    
    # Настройка firewall
    echo "🔒 Настройка firewall..."
    if command -v ufw &> /dev/null; then
        ufw allow 8080/tcp
    fi
    
    echo "✅ Развертывание завершено!"
    
    # Показ статуса
    echo "📊 Статус сервиса:"
    pm2 status
    
    echo ""
    echo "🌐 Тестирование доступности..."
    sleep 2
    curl -s http://localhost:8080/health || echo "❌ Сервис недоступен"
ENDSSH

# Финальная проверка с внешнего адреса
echo ""
echo "🔍 Финальная проверка доступности извне..."
sleep 3
if curl -s "http://$AMSTERDAM_SERVER:8080/health" | grep -q "ok"; then
    echo "✅ Прокси-сервер успешно развернут и доступен!"
    echo "🌐 URL: http://$AMSTERDAM_SERVER:8080"
    echo "🏥 Health check: http://$AMSTERDAM_SERVER:8080/health"
    echo "🔗 Прокси endpoint: http://$AMSTERDAM_SERVER:8080/proxy/gemini/{modelName}"
else
    echo "❌ Сервис недоступен извне. Проверьте настройки firewall."
    exit 1
fi

echo ""
echo "🎉 Развертывание завершено успешно!"
echo ""
echo "Теперь обновите настройки в вашем основном приложении:"
echo "const PROXY_SERVER_URL = 'http://$AMSTERDAM_SERVER:8080';"
echo "const USE_PROXY = true;"
