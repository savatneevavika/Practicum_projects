 --* Автор: Саватнеева Виктория
 --* Дата: 28.06.25
--*/
--Задача 1. Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
clean_id AS (
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id)
),
-- Категоризируем типы населенных пунктов на Санкт-Петербург и ЛенОбл
category_rank AS (
SELECT *,
CASE
	WHEN city_id = '6X8I' THEN 'Санкт-Петербург'
	ELSE 'ЛенОбл'
END AS category
FROM clean_id
),
category_active AS (
SELECT *, 
last_price::float/total_area AS toral_price_area, -- стоимость одного квадратного метра
CASE 
	WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'месяц' 
WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'квартал' 
WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'полгода' 
WHEN a.days_exposition >= 181 THEN 'от полугода'
ELSE 'другие'
END AS activity_category 
FROM category_rank AS cr
LEFT JOIN real_estate.advertisement AS a USING(id)
)
--Основной запрос с подсчетом основных метрик по регионам и активности объявлений
SELECT category, 
activity_category,
COUNT(id) AS total_id, --количество объявлений
(COUNT(id) * 100.0 / (SELECT COUNT(*) FROM category_rank)) AS percentage_of_total, -- доля объявлений в разрезе каждого региона
AVG(toral_price_area) AS avg_total_price_area, -- средняя стоимость одного квадратного метра
AVG(total_area)AS avg_total_area, --cредняя площаль недвижимости
AVG(ceiling_height) AS avg_ceiling_height, --средняя высота потолка
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS mediana_rooms, --медиана кол-ва комнат
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS mediana_balcony, -- медиана кол-ва балконов
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS mediana_floor-- медиана этажности
FROM category_active
GROUP BY category, activity_category;

--Задача 2. Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
clean_id AS (
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id)
),
-- Определим дату "продажи" недвижимости и выделим месяц из даты для дальнейших расчетов
real_estate_ads AS (
SELECT c.city,
a.first_day_exposition,
a.last_price,
ci.total_area,
EXTRACT(MONTH FROM a.first_day_exposition) AS month_published, --выделяем месяц из даты публикации объявления
a.first_day_exposition::date + a.days_exposition::integer AS last_date, --определим дату снятия объявления
EXTRACT(MONTH FROM (a.first_day_exposition::date + a.days_exposition::integer)) AS month_closed --выделим месяц из даты снятия публикации
FROM clean_id AS ci
LEFT JOIN real_estate.advertisement AS a USING(id)
LEFT JOIN real_estate.city AS c USING (city_id)
),
--Сортируем количество объявлений по дате публикации
rank_published_month AS (
SELECT month_published,
AVG(last_price::float/total_area) AS avg_total_price_area_p, -- средняя стоимость одного квадратного метра
AVG(total_area) AS avg_total_area_p, --cредняя площаль недвижимости
COUNT(*) AS total_ads_publ, 
RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_publ
FROM real_estate_ads 
GROUP BY month_published
ORDER BY total_ads_publ DESC
),
rank_closed_month AS (
SELECT month_closed,
AVG(last_price::float/total_area) AS avg_total_price_area_c, -- средняя стоимость одного квадратного метра
AVG(total_area) AS avg_total_area_c, --cредняя площаль недвижимости
COUNT(*) AS total_ads_closed, 
RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_closed
FROM real_estate_ads
WHERE last_date IS NOT NULL AND month_closed IS NOT NULL
GROUP BY month_closed
ORDER BY total_ads_closed DESC
)
SELECT *
FROM rank_published_month AS rpm
JOIN rank_closed_month AS rcm ON rpm.month_published = rcm.month_closed;

--Задача 3. Анализ рынка недвижимости Ленобласти
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
clean_id AS (
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id)
)
SELECT DISTINCT c.city,
COUNT(ci.id) AS total_id, --считаем общее кол-во объявлений
SUM(CASE WHEN a.days_exposition IS NOT NULL THEN 1 ELSE 0 END)::float/COUNT(ci.id)*100 AS removal_percentage, --считаем долю снятых с публикации объявлений
AVG(a.last_price::float/ci.total_area) AS toral_price_area, -- средняя стоимость одного квадратного метра
AVG(ci.total_area) AS avg_total_area, --считаем среднюю площадь недвижимости
AVG(a.days_exposition) AS avg_days_to_sell --считаем среднее кол-во дней публикации объявления
FROM clean_id AS ci
LEFT JOIN real_estate.advertisement AS a USING(id)
LEFT JOIN real_estate.city AS c USING(city_id)
WHERE city <> 'Санкт-Петербург' --исключаем СпБ, т.к. исследуем ЛенОбл
GROUP BY c.city
ORDER BY total_id DESC
LIMIT 15; --выводим только топ-15 для емкости выводов из полученных данных и для простоты визуализации самых востребованных рынков в разрезе по населенным пунктам
