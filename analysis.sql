-- PostgreSQL. 12 бизнес-задач по marketplace-данным.

-- 1. GMV, orders, buyers, AOV по месяцам
WITH completed AS (
  SELECT o.order_id, o.user_id, o.order_date, p.amount
  FROM orders o
  JOIN payments p USING (order_id)
  WHERE o.status='completed' AND p.payment_status='paid'
)
SELECT DATE_TRUNC('month',order_date)::date AS month,
       COUNT(*) AS orders,
       COUNT(DISTINCT user_id) AS buyers,
       ROUND(SUM(amount),2) AS gmv,
       ROUND(AVG(amount),2) AS aov
FROM completed GROUP BY 1 ORDER BY 1;

-- 2. Top-5 городов по GMV
SELECT u.city,
       COUNT(DISTINCT o.order_id) AS orders,
       COUNT(DISTINCT o.user_id) AS buyers,
       ROUND(SUM(p.amount),2) AS gmv
FROM orders o
JOIN users u USING(user_id)
JOIN payments p USING(order_id)
WHERE o.status='completed' AND p.payment_status='paid'
GROUP BY u.city
ORDER BY gmv DESC
LIMIT 5;

-- 3. Top-3 товара по GMV внутри категории
WITH product_gmv AS (
  SELECT pr.category, pr.product_id, pr.product_name,
         SUM(oi.quantity*oi.unit_price) AS gmv
  FROM order_items oi
  JOIN orders o USING(order_id)
  JOIN products pr USING(product_id)
  WHERE o.status='completed'
  GROUP BY 1,2,3
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER(PARTITION BY category ORDER BY gmv DESC) rn
  FROM product_gmv
)
SELECT category, product_id, product_name, ROUND(gmv,2) AS gmv
FROM ranked WHERE rn<=3 ORDER BY category,rn;

-- 4. Доля повторных покупателей
WITH numbered AS (
  SELECT user_id, order_id, order_date,
         ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY order_date,order_id) AS rn
  FROM orders
  WHERE status='completed'
)
SELECT DATE_TRUNC('month',order_date)::date AS month,
       COUNT(DISTINCT user_id) AS buyers,
       COUNT(DISTINCT user_id) FILTER(WHERE rn>1) AS repeat_buyers,
       ROUND(100.0*COUNT(DISTINCT user_id) FILTER(WHERE rn>1)
             / NULLIF(COUNT(DISTINCT user_id),0),2) AS repeat_share_pct
FROM numbered GROUP BY 1 ORDER BY 1;

-- 5. ARPU / ARPPU по каналу
WITH user_revenue AS (
  SELECT u.user_id,u.acquisition_channel,
         COALESCE(SUM(p.amount) FILTER(
           WHERE o.status='completed' AND p.payment_status='paid'
         ),0) AS revenue
  FROM users u
  LEFT JOIN orders o USING(user_id)
  LEFT JOIN payments p USING(order_id)
  GROUP BY 1,2
)
SELECT acquisition_channel,
       COUNT(*) AS users,
       COUNT(*) FILTER(WHERE revenue>0) AS paying_users,
       ROUND(AVG(revenue),2) AS arpu,
       ROUND(AVG(revenue) FILTER(WHERE revenue>0),2) AS arppu
FROM user_revenue GROUP BY 1 ORDER BY arpu DESC;

-- 6. 7-day moving average GMV
WITH daily AS (
  SELECT o.order_date, SUM(p.amount) AS gmv
  FROM orders o JOIN payments p USING(order_id)
  WHERE o.status='completed' AND p.payment_status='paid'
  GROUP BY 1
)
SELECT order_date, ROUND(gmv,2) AS gmv,
       ROUND(AVG(gmv) OVER(
         ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ),2) AS gmv_7d_ma
FROM daily ORDER BY order_date;

-- 7. Cancellation rate по acquisition channel
SELECT u.acquisition_channel,
       COUNT(*) AS orders,
       COUNT(*) FILTER(WHERE o.status='cancelled') AS cancelled_orders,
       ROUND(100.0*COUNT(*) FILTER(WHERE o.status='cancelled')/COUNT(*),2)
         AS cancellation_rate_pct
FROM orders o JOIN users u USING(user_id)
GROUP BY 1 ORDER BY cancellation_rate_pct DESC;

-- 8. Доля категорий в GMV
WITH category_gmv AS (
  SELECT pr.category,SUM(oi.quantity*oi.unit_price) AS gmv
  FROM order_items oi
  JOIN orders o USING(order_id)
  JOIN products pr USING(product_id)
  WHERE o.status='completed'
  GROUP BY 1
)
SELECT category,ROUND(gmv,2) AS gmv,
       ROUND(100.0*gmv/SUM(gmv) OVER(),2) AS gmv_share_pct
FROM category_gmv ORDER BY gmv DESC;

-- 9. Cohort retention по месяцу первой покупки
WITH first_purchase AS (
  SELECT user_id,DATE_TRUNC('month',MIN(order_date))::date AS cohort_month
  FROM orders WHERE status='completed' GROUP BY 1
),
activity AS (
  SELECT DISTINCT o.user_id,f.cohort_month,
         DATE_TRUNC('month',o.order_date)::date AS activity_month
  FROM orders o JOIN first_purchase f USING(user_id)
  WHERE o.status='completed'
),
cohort_activity AS (
  SELECT cohort_month,
         (EXTRACT(YEAR FROM AGE(activity_month,cohort_month))*12
          +EXTRACT(MONTH FROM AGE(activity_month,cohort_month)))::int AS month_number,
         COUNT(DISTINCT user_id) AS active_users
  FROM activity GROUP BY 1,2
),
cohort_size AS (
  SELECT cohort_month,COUNT(*) AS cohort_users
  FROM first_purchase GROUP BY 1
)
SELECT ca.cohort_month,ca.month_number,cs.cohort_users,ca.active_users,
       ROUND(100.0*ca.active_users/cs.cohort_users,2) AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs USING(cohort_month)
ORDER BY 1,2;

-- 10. RFM-like segmentation
WITH user_stats AS (
  SELECT o.user_id,MAX(o.order_date) AS last_order_date,
         COUNT(*) AS frequency,SUM(p.amount) AS monetary
  FROM orders o JOIN payments p USING(order_id)
  WHERE o.status='completed' AND p.payment_status='paid'
  GROUP BY 1
),
scored AS (
  SELECT *,
         NTILE(4) OVER(ORDER BY last_order_date) AS recency_score,
         NTILE(4) OVER(ORDER BY frequency) AS frequency_score,
         NTILE(4) OVER(ORDER BY monetary) AS monetary_score
  FROM user_stats
)
SELECT * FROM scored
ORDER BY monetary_score DESC,frequency_score DESC,recency_score DESC;

-- 11. New vs existing buyers contribution to GMV
WITH first_purchase AS (
  SELECT user_id,DATE_TRUNC('month',MIN(order_date))::date AS first_month
  FROM orders WHERE status='completed' GROUP BY 1
),
monthly AS (
  SELECT o.user_id,DATE_TRUNC('month',o.order_date)::date AS month,
         SUM(p.amount) AS gmv
  FROM orders o JOIN payments p USING(order_id)
  WHERE o.status='completed' AND p.payment_status='paid'
  GROUP BY 1,2
)
SELECT m.month,
       CASE WHEN m.month=f.first_month THEN 'new' ELSE 'existing' END AS buyer_type,
       COUNT(DISTINCT m.user_id) AS buyers,
       ROUND(SUM(m.gmv),2) AS gmv
FROM monthly m JOIN first_purchase f USING(user_id)
GROUP BY 1,2 ORDER BY 1,2;

-- 12. Метрики по payment method
SELECT p.payment_method,
       COUNT(*) FILTER(WHERE p.payment_status='paid') AS paid_orders,
       ROUND(AVG(p.amount) FILTER(WHERE p.payment_status='paid'),2) AS aov,
       ROUND(SUM(p.amount) FILTER(WHERE p.payment_status='paid'),2) AS gmv
FROM payments p
JOIN orders o USING(order_id)
WHERE o.status='completed'
GROUP BY 1 ORDER BY gmv DESC;
