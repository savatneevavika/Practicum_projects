/* Проект «Секреты Тёмнолесья»
 * Автор: Виктория Саватнеева
 * Дата: 19.06.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
SELECT COUNT(id) AS total_id, --общее количество игроков
SUM(payer) AS id_event, --кол-во платящих игроков, т.к. 1 - платит, 0 - не платит, сумма указывает на общее количество платящих
SUM(payer)::float/COUNT(id) AS dolya -- доля платящих от общего количества
FROM fantasy.users 
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race,
SUM(u.payer) AS id_event, -- кол-во платящих пользователей
COUNT(u.id) AS total_id, -- общее количество игроков
SUM(u.payer)::float/COUNT(u.id) AS perc -- доля платящих от общего количества
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r USING (race_id)
GROUP BY r.race -- смотрим долю платящих от общего количества по каждой расе персонажа
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(transaction_id) AS total_event, -- общее количество покупок в игре
SUM(amount) AS total_amount, --суммарная стоимость покупок в игре
MIN(amount) AS min_amount, --минимальная сумма покупки
MAX(amount) AS max_amount, -- максимальная сумма покупки
AVG(amount) AS avg_amount, -- среднее значение суммы покупки
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana_amount, --вычисляем медиану как 2-ой квартиль, так как он соответсвует 50му процентилю, ведь медиана делит объем данных на 2 равные части
STDDEV(amount) AS stddev_amount --среднее отклонение суммы покупки
FROM fantasy.events
WHERE amount>0 -- исключаем аномальные нулевые покупки при рассчетах, чтобы не искажать значения
-- 2.2: Аномальные нулевые покупки:
WITH anomaly AS (
SELECT COUNT(amount) AS amount_count
FROM fantasy.events
WHERE amount=0
),
am_count AS (
SELECT COUNT(amount) AS am_co
FROM fantasy.events
)
SELECT amount_count,
amount_count::float/am_co
FROM anomalii, am_count
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
--Анализируем неплатящих и платящих игроков
SELECT payer,
COUNT(DISTINCT id) AS total_id, -- уникальное количество игроков
AVG(sum_amount)::numeric AS avg_sum_per_player, -- средняя суммарная стоимость покупок на 1 игрока
AVG(total_transaction)::numeric AS avg_ev -- среднее количество покупок игроков
FROM (
SELECT e.id, u.payer,
COUNT(e.transaction_id) AS total_transaction, -- количество покупок игроков
SUM(e.amount) AS sum_amount -- суммарная стоимость покупок
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e USING(id)
WHERE e.amount>0
GROUP BY e.id, u.payer
) AS podz
GROUP BY payer

-- 2.4: Популярные эпические предметы:
WITH item_total_abs AS (
SELECT i.game_items, 
COUNT(DISTINCT id) AS id_abs, -- считаем уникальное количество игроков, совершивших покупку
SUM(amount) AS total_sum_abs, --считаем сумму покупок каждого предмета
COUNT(e.item_code) AS total_count_item -- считаем общее кол-во покупок каждого эпич предмета
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i USING(item_code)
WHERE amount>0 -- исключаем аномальные покупки
GROUP BY i.game_items -- условие для расчета суммы покупки каждого предмета
),
item_total_otnosit AS (
SELECT COUNT(DISTINCT e.id) AS total_id, --считаем общее количество игроков
COUNT(e.transaction_id) AS total_orders --общее кол-во покупок
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i USING(item_code)
WHERE amount>0 -- исключаем аномальные покупки
)
SELECT game_items, 
total_sum_abs, 
total_count_item,
total_count_item::float/total_orders AS dolya_item, -- считаем долю покупок каждого предмета относительно всех покупок
id_abs::float/total_id AS dolya_id -- считаем долю пользователей купивших предмет от общего количества игроков
FROM  item_total_abs, item_total_otnosit
ORDER BY dolya_item DESC
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH gamers_stat AS (
-- Считаем статистику по покупателям
SELECT race_id,
COUNT(u.id) AS total_gamers -- считаем общее количество игроков
FROM fantasy.users AS u
GROUP BY race_id
),
buyers_stat AS (
-- Считаем статистику по покупкам с фильтрацией нулевых покупок
SELECT u.race_id,
COUNT(DISTINCT e.id) AS total_buyers, -- считаем количество игроков, совершивших покупку
SUM(e.amount) AS total_amount, --сумма всех покупок
COUNT(e.transaction_id) AS total_orders --количество покупок
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e USING(id)
WHERE e.amount > 0
GROUP BY u.race_id
),
orders_stat AS (
-- Считаем статистику по транзакциям с фильтрацией нулевых покупок
SELECT u.race_id,
COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END)::float / COUNT(DISTINCT e.id) AS payer_buyers_share -- считаем долю платящих игроков от игроков, совершивших покупку 
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e USING(id)
WHERE e.amount > 0
GROUP BY race_id
)
SELECT
    race,
    -- выводим статистику по игрокам
    total_gamers,
    total_buyers,
    total_buyers::real/total_gamers AS buyers_share,  -- считаем долю игроков, которые совершают внутриигровые покупки от общего количества игроков
    payer_buyers_share,
    -- выводим статистику по покупкам
    total_orders::real/total_buyers AS orders_per_buyer,  --среднее количество покупок на 1 игрока
    total_amount::real/total_buyers AS total_amount_per_buyer, -- средняя стоимость одной покупки на 1 покупателя
    total_amount::real/total_orders AS avg_amount_per_buyer -- средняя стоимость одной покупки на 1 игрока
FROM gamers_stat JOIN buyers_stat USING(race_id) JOIN orders_stat USING(race_id)
JOIN fantasy.race USING(race_id)

-- Задача 2: Частота покупок
--Считаем количество дней с предыдущей покупки (подзапрос) и считаем общее количество покупок на 1 игрока со средним количеством дней между покупками
WITH date_tr AS (
SELECT id, payer,
AVG(lag_date) AS avg_lag_date, --считаем среднее количество дней, прошедших с предыдущей покупки
COUNT(transaction_id) AS transaction_user -- общее количество покупок на одного игрока
FROM (
SELECT e.id, 
e.transaction_id,
u.payer,
e.date::date - LAG(e.date::date) OVER (PARTITION BY e.id ORDER BY e.date) AS lag_date --вычислим сколько дней прошло с предыдущей покупки
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e USING (id)
WHERE amount > 0
GROUP BY id, transaction_id
) AS podz
GROUP BY id, payer
),
--делим игроков на 3 категории с учетом условия в совершении 25 или более покупок
category_id AS (
SELECT 
payer,
avg_lag_date,
transaction_user,
NTILE (3) OVER (ORDER BY avg_lag_date) AS category
FROM date_tr
WHERE transaction_user >=25
),
category_name AS (
SELECT
payer,
avg_lag_date,
transaction_user,
CASE
	WHEN category=1 THEN 'высокая частота'
	WHEN category=2 THEN 'умеренная частота'
	ELSE 'низкая частота'
END AS category_rank
FROM category_id
)
SELECT
category_rank, --ранжирование
AVG(avg_lag_date) AS avg_date, --среднее значение средних интервалов по всем записям в выборке
COUNT(payer) AS total_payer, --количество игроков, которые совершили покупки
SUM(payer) AS paying_buyers_count, -- количество платящих игроков, совершивших покупки
AVG(payer) AS dolya_pl_id, --доля платящих игроков, совершивших покупки, от общего количества игроков, совершивших покупки
AVG(transaction_user) AS avg_transaction_user --среднее количество покупок на 1 игрока
FROM category_name
GROUP BY category_rank
