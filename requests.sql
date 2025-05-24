-- 1.Provide the list of markets in which customer  "Atliq  Exclusive"  operates its 
-- business in the  APAC  region. 

SELECT DISTINCT market
FROM dim_customer
WHERE customer = "Atliq Exclusive" AND region = "APAC";

-- 2.What is the percentage of unique product increase in 2021 vs. 2020? The 
-- final output contains these fields, 
-- unique_products_2020 
-- unique_products_2021 
-- percentage_chg

WITH cte1 AS(
SELECT COUNT(distinct product_code) AS up_20
FROM fact_sales_monthly 
WHERE fiscal_year = 2020),

cte2 AS(
SELECT COUNT(distinct product_code) AS up_21
FROM fact_sales_monthly 
WHERE fiscal_year = 2021)

SELECT up_20 AS unique_products_2020,
	   up_21 AS unique_products_2021,
       ROUND((up_21-up_20)*100/up_20,2) AS percentage_change
FROM cte1,cte2;

-- 3.  Provide a report with all the unique product counts for each  segment  and 
-- sort them in descending order of product counts. The final output contains 
-- 2 fields, 
-- segment 
-- product_count

SELECT segment,COUNT(product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- 4.  Follow-up: Which segment had the most increase in unique products in 
-- 2021 vs 2020? The final output contains these fields, 
-- segment 
-- product_count_2020 
-- product_count_2021 
-- difference

WITH prod_20 AS(
SELECT p.segment,
	   COUNT(DISTINCT sm.product_code) AS product_count_2020
FROM dim_product p 
JOIN fact_sales_monthly sm 
ON
	p.product_code = sm.product_code
WHERE sm.fiscal_year = 2020
GROUP BY p.segment),

prod_21 AS(
SELECT p.segment,
	   COUNT(DISTINCT sm.product_code) AS product_count_2021
FROM dim_product p 
JOIN fact_sales_monthly sm 
ON
	p.product_code = sm.product_code
WHERE sm.fiscal_year = 2021
GROUP BY p.segment)

SELECT prod_21.segment,
	   product_count_2021,
       product_count_2020,
       product_count_2021-product_count_2020 AS difference
FROM prod_20
JOIN prod_21
ON
	prod_20.segment = prod_21.segment
GROUP BY prod_21.segment ;

-- 5.Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, 
-- product_code 
-- product 
-- manufacturing_cost

SELECT p.product_code,
	   p.product,
       mc.manufacturing_cost
FROM dim_product p 
JOIN fact_manufacturing_cost mc
ON
	p.product_code = mc.product_code
WHERE mc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)

UNION

SELECT p.product_code,
	   p.product,
       mc.manufacturing_cost
FROM dim_product p 
JOIN fact_manufacturing_cost mc
ON
	p.product_code = mc.product_code
WHERE mc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost);


-- 6.Generate a report which contains the top 5 customers who received an 
-- average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the 
-- Indian  market. The final output contains these fields, 
-- customer_code 
-- customer 
-- average_discount_percentage

SELECT pid.customer_code,
	   c.customer,
       pid.pre_invoice_discount_pct AS average_discount_percentage 
FROM dim_customer c
JOIN fact_pre_invoice_deductions pid
USING (customer_code)
WHERE pid.fiscal_year = 2021 AND 
	  c.market = "India" AND
	  pid.pre_invoice_discount_pct>(SELECT AVG(pre_invoice_discount_pct) FROM fact_pre_invoice_deductions)
GROUP BY c.customer
ORDER BY average_discount_percentage DESC LIMIT 5;

-- 7.Get the complete report of the Gross sales amount for the customer  “Atliq 
-- Exclusive”  for each month  .  This analysis helps to  get an idea of low and 
-- high-performing months and take strategic decisions. 
-- The final report contains these columns: 
-- Month 
-- Year 
-- Gross sales Amount 

SELECT 
	CONCAT(MONTHNAME(sm.date),'(',YEAR(sm.date),')') AS Month,
    sm.fiscal_year AS Year,
    ROUND(SUM(gp.gross_price*sm.sold_quantity),2) AS Gross_Sales_Amount
FROM dim_customer c
JOIN fact_sales_monthly sm 
ON
	c.customer_code = sm.customer_code
JOIN fact_gross_price gp
ON
	gp.product_code = sm.product_code AND
    gp.fiscal_year = sm.fiscal_year
WHERE c.customer = "Atliq Exclusive"
GROUP BY Month
ORDER BY Year;

-- 8.In which quarter of 2020, got the maximum total_sold_quantity? The final 
-- output contains these fields sorted by the total_sold_quantity, 
-- Quarter 
-- total_sold_quantity

WITH cte1 AS
(
	SELECT MONTH(DATE_ADD(date, INTERVAL 4 MONTH)) AS monthnum,
		   SUM(sold_quantity) AS total_sales
	FROM fact_sales_monthly sm
    WHERE fiscal_year = 2020
    GROUP BY monthnum
)


	SELECT
		CASE
			WHEN monthnum BETWEEN 1 AND 3 THEN 'q1'
            WHEN monthnum BETWEEN 4 AND 6 THEN 'q2'
            WHEN monthnum BETWEEN 7 AND 9 THEN 'q3'
            WHEN monthnum BETWEEN 10 AND 12 THEN 'q4'
        END AS quarters,
        ROUND(SUM(total_sales)/1000000,2) AS total_sold_quantity_mln
	FROM cte1 
    GROUP BY quarters
    ORDER BY total_sold_quantity_mln DESC;

-- 9.Which channel helped to bring more gross sales in the fiscal year 2021 
-- and the percentage of contribution?  The final output  contains these fields, 
-- channel 
-- gross_sales_mln 
-- percentage

WITH sales_21 AS(
SELECT
	c.channel,
    ROUND(SUM(gp.gross_price*sm.sold_quantity)/1000000,2) AS gross_sales_mln
FROM dim_customer c
JOIN fact_sales_monthly sm
ON
	c.customer_code = sm.customer_code
JOIN fact_gross_price gp
ON
	gp.fiscal_year = sm.fiscal_year AND
    gp.product_code = sm.product_code
WHERE sm.fiscal_year = 2021
GROUP BY c.channel),

total_sales AS
(
	SELECT SUM(gross_sales_mln) AS total_sales_value FROM sales_21 
)

SELECT 
	s.channel,
    s.gross_sales_mln,
    ROUND((s.gross_sales_mln/t.total_sales_value)*100,2) as percentage
FROM sales_21 s, total_sales t
GROUP BY s.channel
ORDER BY percentage DESC;

-- 10.Get the Top 3 products in each division that have a high 
-- total_sold_quantity in the fiscal_year 2021? The final output contains these 
-- fields, 
-- division 
-- product_code 
-- product 
-- total_sold_quantity 
-- rank_order

WITH division_sales AS(
SELECT 
	p.division,
    sm.product_code,
    p.product,
    SUM(sm.sold_quantity) AS total_sold_quantity,
    DENSE_RANK() OVER(PARTITION BY p.division ORDER BY SUM(sm.sold_quantity) DESC) AS rank_order
FROM dim_product p
JOIN fact_sales_monthly sm
ON
	p.product_code = sm.product_code
WHERE fiscal_year = 2021
GROUP BY p.division,sm.product_code,p.product)

SELECT *
FROM division_sales
WHERE rank_order<=3
