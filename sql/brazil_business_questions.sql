-- ================================================
-- BRAZILIAN E-COMMERCE — BUSINESS ANALYSIS
-- Author: Vidhya Rasu
-- Date: February 2026
-- ================================================

-- ------------------------------------------------
-- Q1: OVERALL BUSINESS OVERVIEW
-- ------------------------------------------------      
WITH order_summary AS(
	SELECT
		o.order_id,
        o.customer_id,
        SUM(oi.price + oi.freight_value) AS spend
	FROM orders o
    JOIN order_items oi
		ON o.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.customer_id
)
SELECT
	COUNT(order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(SUM(spend),2) AS revenue,
    ROUND(AVG(spend),2) AS avg_order_value
FROM order_summary;

-- ------------------------------------------------
-- Q2: REVENUE BY STATE
-- ------------------------------------------------
-- Step 1: Aggregate item-level data to order-level
WITH order_summary AS(
	SELECT
		o.order_id,
        o.customer_id,
        SUM(oi.price + oi.freight_value) AS spend
	FROM orders o
    JOIN order_items oi
		ON o.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.customer_id
)
-- Step 2: Aggregate order-level data by state
SELECT
	c.customer_state AS state,
    COUNT(os.order_id) AS total_orders,
    COUNT(DISTINCT os.customer_id) AS total_customers,
    ROUND(SUM(os.spend),2) AS revenue,
    ROUND(AVG(os.spend),2) AS avg_order_value
FROM customers c
JOIN order_summary os
	ON c.customer_id = os.customer_id
GROUP BY state
ORDER BY revenue DESC
LIMIT 10;
    
-- ------------------------------------------------
-- Q3: TOP CATEGORIES BY REVENUE
-- ------------------------------------------------
-- Step 1: Aggregate item-level data (order-product)
WITH order_product_summary AS(
	SELECT
		o.order_id,
        o.customer_id,
        oi.product_id,
        SUM(oi.price + oi.freight_value) AS spend
	FROM orders o
    JOIN order_items oi
		ON o.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.customer_id, oi.product_id
)
-- Step 2: Aggregate by product category
SELECT
	p.product_category_name AS category,
    COUNT(ops.order_id) AS total_orders,
    COUNT(ops.product_id) AS total_products,
    COUNT(DISTINCT ops.customer_id) AS total_customers,
    ROUND(SUM(ops.spend),2) AS revenue,
    ROUND(AVG(ops.spend),2) AS avg_product_order_value
FROM products p
JOIN order_product_summary ops
	ON p.product_id = ops.product_id
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;
-- ------------------------------------------------
-- Q4: MONTHLY REVENUE TREND
-- ------------------------------------------------
-- Step 1: Aggregate item-level data to order-level
WITH order_summary AS(
	SELECT
		o.order_id,
        SUM(oi.price + oi.freight_value) AS spend,
        o.order_purchase_timestamp
	FROM orders o
    JOIN order_items oi
		ON o.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.order_purchase_timestamp
),

-- Step 2: Aggregate order-level data by month
monthly_summary AS(
	SELECT
		DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS yearmonth,
        COUNT(order_id) AS total_orders,
        ROUND(SUM(spend),2) AS revenue,
        ROUND(AVG(spend),2) AS avg_order_value
	FROM order_summary
    GROUP BY yearmonth
)
-- Step 3: Add month-over-month change using LAG()
SELECT
	yearmonth,
    total_orders,
    revenue,
    avg_order_value,
    ROUND(revenue-LAG(revenue) OVER (ORDER BY yearmonth),2) AS revenue_change,
    ROUND(((revenue - LAG(revenue) OVER (ORDER BY yearmonth)) / LAG(revenue) OVER (ORDER BY yearmonth)) * 100, 2) AS revenue_pct_change
FROM monthly_summary
ORDER BY yearmonth ASC;

-- ------------------------------------------------
-- Q5: AVERAGE DELIVERY TIME BY STATE
-- ------------------------------------------------
-- Step 1: Aggregate order-level delivery times
WITH order_delivery AS (
    SELECT
        o.order_id,
        o.customer_id,
        DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_days
    FROM orders o
    WHERE o.order_status = 'delivered'
)

-- Step 2: Aggregate by state
SELECT
    c.customer_state AS state,
    ROUND(AVG(od.delivery_days), 2) AS avg_delivery_time
FROM order_delivery od
JOIN customers c
    ON od.customer_id = c.customer_id
GROUP BY state
ORDER BY avg_delivery_time DESC;

-- ------------------------------------------------
-- Q6: PAYMENT TYPE ANALYSIS
-- ------------------------------------------------
WITH delivered_summary AS(
	SELECT
		order_id,
        customer_id
	FROM orders 
    WHERE order_status = 'delivered'
)
SELECT
	COUNT(ds.order_id) AS total_orders,
    COUNT(DISTINCT ds.customer_id) AS total_customers,
    p.payment_type AS type_of_payment,
    ROUND(SUM(p.payment_value),2) AS revenue,
    ROUND(AVG(p.payment_value),2) AS avg_payment_value,
    ROUND(SUM(p.payment_value) / SUM(SUM(p.payment_value)) OVER() *100,2) AS payment_percentage
FROM delivered_summary ds
JOIN payments p
	ON ds.order_id = p.order_id
GROUP BY type_of_payment
ORDER BY revenue DESC;

-- ------------------------------------------------
-- Q7 — REVIEW SCORE BY CATEGORY
-- -----------------------------------------------
WITH delivered_review_summary AS(
	SELECT
		o.order_id,
        o.customer_id,
        r.review_score
	FROM orders o
    JOIN reviews r
		ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
),
product_category AS(
	SELECT DISTINCT
		oi.order_id,
        p.product_category_name AS category
	FROM products p
    JOIN order_items oi
		ON p.product_id = oi.product_id
)
SELECT
	pc.category AS category,
	drs.review_score AS review_score,
	COUNT(DISTINCT drs.order_id) AS total_orders,
    COUNT(DISTINCT drs.customer_id) AS total_customers
FROM delivered_review_summary drs
JOIN product_category pc
	ON drs.order_id = pc.order_id
GROUP BY review_score, category
ORDER BY review_score DESC;

-- ------------------------------------------------
-- Q8 — TOP SELLERS BY REVENUE
-- -----------------------------------------------
WITH seller_revenue AS(
	SELECT
		oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        ROUND(SUM(oi.price + oi.freight_value),2) AS revenue
	FROM orders o
    JOIN order_items oi
		ON o.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)
SELECT
	DENSE_RANK() OVER(ORDER BY sr.revenue DESC) AS seller_rank,
	s.seller_id AS sellerID,
	s.seller_state AS state,
    sr.total_orders AS total_orders,
    sr.revenue AS revenue,
    ROUND(sr.revenue / SUM(sr.revenue) OVER() *100,2) AS revenue_pct
FROM seller_revenue sr
JOIN sellers s
	ON sr.seller_id = s.seller_id
ORDER BY sr.revenue DESC
LIMIT 10;

-- ------------------------------------------------
-- Q9 — LATE DELIVERIES!
-- -----------------------------------------------
WITH delivered_late_summary AS(
SELECT
	order_id,
    customer_id,
    DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS days_late
FROM orders 
WHERE order_status = 'delivered' AND 
	DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) > 0
)
SELECT
	c.customer_state AS state,
    COUNT(DISTINCT dls.order_id) AS total_orders,
    COUNT(dls.days_late) AS late_orders,
    ROUND(COUNT(DISTINCT dls.order_id) / SUM(COUNT(dls.order_id)) OVER() * 100, 2) AS late_pct,
    ROUND(AVG(dls.days_late),2) AS avg_days_late
FROM delivered_late_summary dls
JOIN customers c
	ON dls.customer_id = c.customer_id
GROUP BY state;

-- ------------------------------------------------
-- Q10 — FIND CUSTOMERS WHO PLACED MORE THAN 1 ORDER
-- -----------------------------------------------
WITH customer_orders AS(
SELECT
	customer_id,
	COUNT(order_id) AS total_order
FROM orders 
WHERE order_status = 'delivered'
GROUP BY customer_id
)
SELECT
	COUNT(customer_id) AS total_customers,
    COUNT(CASE WHEN total_order = 1 THEN 1 END) AS one_time_customer,
    COUNT(CASE WHEN total_order > 1 THEN 1 END) AS repeated_customers,
    ROUND(COUNT(CASE WHEN total_order > 1 THEN 1 END) / COUNT(customer_id) * 100 ,2) AS customer_returned_pct
FROM customer_orders; 

    
    
        