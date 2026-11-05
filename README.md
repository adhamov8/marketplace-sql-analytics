# Marketplace SQL Analytics

Учебный SQL-проект на синтетических данных маркетплейса.

## Цель

Показать работу с реляционной моделью и бизнес-запросами, близкими к e-commerce / marketplace аналитике.

## Данные

- 5 000 пользователей
- 16 000 заказов
- 120 товаров
- отдельные таблицы `orders`, `order_items`, `payments`

Схема: `users → orders → order_items → products`, отдельно `payments`.

## Что есть в analysis.sql

12 задач: GMV/AOV, города, Top-N внутри категории, repeat buyers, ARPU/ARPPU,
rolling GMV, cancellation rate, category share, cohort retention,
RFM-like segmentation, new vs existing buyers, payment metrics.

Используются `JOIN`, `GROUP BY`, `HAVING`, CTE, `FILTER`, `DATE_TRUNC`,
`ROW_NUMBER`, `NTILE` и оконные функции.

## Быстрые цифры

- уникальных покупателей: **3,840**
- GMV завершённых заказов: **731,724,747**
- cancellation rate: **9.0%**

Данные синтетические

## Структура

```text
marketplace-sql-analytics/
├── data/
├── schema.sql
├── analysis.sql
└── README.md
```

## Стек

PostgreSQL, SQL
