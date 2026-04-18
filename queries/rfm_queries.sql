--==========================================
-- 1. Drop existing table
DROP TABLE if exists customer_data_raw;
DROP TABLE if exists customer_data_clean;
DROP TABLE if exists rfm_customer_segments;
--=======================================
-- 2. Create raw table (staging layer)

CREATE TABLE customer_data_raw (
    row_num        INTEGER,  --  FIX
    invoice_no     TEXT,
    stock_code     TEXT,
    description    TEXT,
    quantity       INTEGER,
    invoice_date   DATE,
    unit_price     NUMERIC(12,2),
    customer_id    BIGINT,
    country        TEXT
);
--=======================================
-- 3. Load csv data
COPY public.customer_data_raw
FROM 'F:\PROJECT-WORKFLOW\RFM analysis customer segmentation\dataset\customer_data_raw.csv'
DELIMITER ','
CSV HEADER;

select * from customer_data_raw;
--====================================
--4. Data cleaning and Creating new table with clean csv
CREATE TABLE customer_data_clean AS
SELECT *
FROM customer_data_raw
WHERE customer_id IS NOT NULL
  AND quantity > 0
  AND unit_price >0;

select * from customer_data_clean;
--==================================
-- 5. RFM CALCULATION

CREATE TABLE rfm_customer_segments AS

WITH rfm_base AS(
	SELECT 
		customer_id,
		MAX(invoice_date) AS last_purchase_date,
		COUNT(Distinct invoice_no) AS frequency,
		SUM(quantity * unit_price) AS monetary
		FROM customer_data_clean
		group by customer_id
),
-- recency calculation 
-- Difference between latest date and last purchase
recency_calculation AS (
    SELECT *,
            (SELECT MAX(invoice_date) FROM customer_data_clean) 
            - last_purchase_date
         AS recency
    FROM rfm_base
),
-- RFM scoring (7 bucket segment)
rfm_scores AS (
    SELECT *,
        NTILE(7) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(7) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(7) OVER (ORDER BY monetary ASC) AS m_score
    FROM recency_calculation
)

-- Final segment creation
SELECT *,
    CONCAT(r_score, f_score, m_score) AS rfm_score,
    
    CASE 
        WHEN r_score = 7 AND f_score >= 6 AND m_score >= 6 THEN 'Champions'       
        WHEN r_score >= 6 AND f_score >= 5 THEN 'Loyal Customers'        
        WHEN r_score = 7 AND f_score <= 3 THEN 'New Customers'        
        WHEN r_score BETWEEN 4 AND 5 AND f_score >= 4 THEN 'Potential Loyalists'        
        WHEN r_score <= 3 AND f_score >= 5 THEN 'At Risk'       
        WHEN r_score <= 2 AND f_score <= 3 THEN 'Lost Customers'        
        ELSE 'Low Engagement'
        
    END AS customer_segment

FROM rfm_scores;

-- ================================================================
-- 6. Validating queries

--view data
select * from rfm_customer_segments;

 -- segment distribution
select distinct customer_segment, count(customer_segment) as total_cusotmers
from rfm_customer_segments
group by customer_segment;

--Total numbers of customers in rfm customer segment table
select count(customer_segment) as total_customers
from rfm_customer_segments;




