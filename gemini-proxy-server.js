const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3080;

// Middleware
app.use(cors({
    origin: '*', // Разрешаем все источники (можете ограничить только вашим российским сервером)
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-goog-api-key']
}));

app.use(express.json({ limit: '50mb' }));

// Healthcheck endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        message: 'Gemini API Proxy Server is running',
        timestamp: new Date().toISOString()
    });
});

// Основной прокси-эндпоинт для Gemini API
app.post('/proxy/gemini/:modelName', async (req, res) => {
    try {
        const { modelName } = req.params;
        const apiKey = req.headers['x-goog-api-key'];
        
        if (!apiKey) {
            return res.status(400).json({ 
                error: 'API ключ не предоставлен в заголовке X-goog-api-key' 
            });
        }

        console.log(`[${new Date().toISOString()}] Проксируем запрос к модели: ${modelName}`);
        console.log('Размер тела запроса:', JSON.stringify(req.body).length, 'символов');

        // Формируем URL для Google Gemini API
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent`;

        // Проксируем запрос к Gemini API
        const response = await axios.post(geminiUrl, req.body, {
            headers: {
                'Content-Type': 'application/json',
                'X-goog-api-key': apiKey
            },
            timeout: 60000 // 60 секунд таймаут
        });

        console.log(`[${new Date().toISOString()}] Успешный ответ от Gemini API`);
        
        // Возвращаем ответ от Gemini API без изменений
        res.json(response.data);

    } catch (error) {
        console.error(`[${new Date().toISOString()}] Ошибка при проксировании запроса:`, error.message);
        
        if (error.response) {
            // Ошибка от Gemini API
            console.error('Статус ошибки:', error.response.status);
            console.error('Данные ошибки:', error.response.data);
            
            res.status(error.response.status).json({
                error: 'Ошибка от Gemini API',
                details: error.response.data,
                status: error.response.status
            });
        } else if (error.request) {
            // Нет ответа от Gemini API
            console.error('Нет ответа от Gemini API');
            res.status(503).json({
                error: 'Не удалось связаться с Gemini API',
                message: 'Сервис временно недоступен'
            });
        } else if (error.code === 'ECONNABORTED') {
            // Таймаут
            console.error('Превышено время ожидания ответа от Gemini API');
            res.status(504).json({
                error: 'Превышено время ожидания',
                message: 'Gemini API не ответил в течение установленного времени'
            });
        } else {
            // Другие ошибки
            console.error('Общая ошибка:', error.message);
            res.status(500).json({
                error: 'Внутренняя ошибка прокси-сервера',
                message: error.message
            });
        }
    }
});

// Обработка всех остальных запросов
app.use('*', (req, res) => {
    res.status(404).json({
        error: 'Эндпоинт не найден',
        message: 'Используйте POST /proxy/gemini/{modelName} для проксирования запросов к Gemini API',
        availableEndpoints: [
            'GET /health - проверка состояния сервера',
            'POST /proxy/gemini/{modelName} - проксирование запросов к Gemini API'
        ]
    });
});

// Обработка ошибок
app.use((err, req, res, next) => {
    console.error('Необработанная ошибка:', err);
    res.status(500).json({ 
        error: 'Внутренняя ошибка сервера',
        message: err.message 
    });
});

// Запуск сервера
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🔄 Gemini API Proxy Server запущен на порту ${PORT}`);
    console.log(`🌍 Доступен по адресу: http://0.0.0.0:${PORT}`);
    console.log(`🏥 Healthcheck: http://0.0.0.0:${PORT}/health`);
    console.log(`🔗 Прокси эндпоинт: http://0.0.0.0:${PORT}/proxy/gemini/{modelName}`);
    console.log(`📝 Пример использования: POST /proxy/gemini/gemini-2.0-flash`);
});

module.exports = app;
