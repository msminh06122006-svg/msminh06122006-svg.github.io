-- Dunnhumby exploration queries
USE dunnhumby;
GO

-- Q1.1 Size, IDs and date range
SELECT COUNT(*)                      AS n_rows,
       COUNT(DISTINCT household_key) AS n_households,
       COUNT(DISTINCT BASKET_ID)     AS n_baskets,
       COUNT(DISTINCT PRODUCT_ID)    AS n_products,
       COUNT(DISTINCT STORE_ID)      AS n_stores,
       MIN(WEEK_NO) AS min_week, MAX(WEEK_NO) AS max_week,
       MIN(Trans_Datetime) AS first_trans, MAX(Trans_Datetime) AS last_trans
FROM transaction_data;

-- Q1.2 Min / max / average of numeric variables
SELECT 'QUANTITY' AS variable, MIN(QUANTITY*1.0) AS min_val, MAX(QUANTITY*1.0) AS max_val, AVG(QUANTITY*1.0) AS avg_val FROM transaction_data
UNION ALL SELECT 'SALES_VALUE', MIN(SALES_VALUE), MAX(SALES_VALUE), AVG(SALES_VALUE) FROM transaction_data
UNION ALL SELECT 'RETAIL_DISC', MIN(RETAIL_DISC), MAX(RETAIL_DISC), AVG(RETAIL_DISC) FROM transaction_data
UNION ALL SELECT 'COUPON_DISC', MIN(COUPON_DISC), MAX(COUPON_DISC), AVG(COUPON_DISC) FROM transaction_data
UNION ALL SELECT 'COUPON_MATCH_DISC', MIN(COUPON_MATCH_DISC), MAX(COUPON_MATCH_DISC), AVG(COUPON_MATCH_DISC) FROM transaction_data;

-- Q1.3 Medians
SELECT DISTINCT
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY QUANTITY)    OVER () AS median_quantity,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY SALES_VALUE) OVER () AS median_sales_value,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY RETAIL_DISC) OVER () AS median_retail_disc,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY COUPON_DISC) OVER () AS median_coupon_disc
FROM transaction_data;

-- Q1.4 Where do the huge quantities come from? (preview join to product)
SELECT p.DEPARTMENT, p.COMMODITY_DESC, p.SUB_COMMODITY_DESC,
       COUNT(*) AS n_rows, MAX(t.QUANTITY) AS max_qty, AVG(t.QUANTITY*1.0) AS avg_qty
FROM transaction_data t
JOIN product p ON t.PRODUCT_ID = p.PRODUCT_ID
WHERE t.QUANTITY > 1000
GROUP BY p.DEPARTMENT, p.COMMODITY_DESC, p.SUB_COMMODITY_DESC
ORDER BY n_rows DESC;

-- Q1.5 Zero, negative and discount counts
SELECT SUM(CASE WHEN QUANTITY = 0 THEN 1 ELSE 0 END)          AS qty_zero,
       SUM(CASE WHEN SALES_VALUE = 0 THEN 1 ELSE 0 END)       AS sales_zero,
       SUM(CASE WHEN RETAIL_DISC < 0 THEN 1 ELSE 0 END)       AS lines_loyalty_disc,
       SUM(CASE WHEN RETAIL_DISC > 0 THEN 1 ELSE 0 END)       AS retail_disc_positive,
       SUM(CASE WHEN COUPON_DISC < 0 THEN 1 ELSE 0 END)       AS lines_coupon_disc,
       SUM(CASE WHEN COUPON_MATCH_DISC < 0 THEN 1 ELSE 0 END) AS lines_coupon_match,
       SUM(SALES_VALUE) AS total_sales, SUM(RETAIL_DISC) AS total_retail_disc, SUM(COUPON_DISC) AS total_coupon_disc
FROM transaction_data;

-- Q1.6 Basket-level averages
SELECT AVG(n_lines*1.0) AS avg_lines_per_basket,
       AVG(basket_sales)  AS avg_sales_per_basket,
       MAX(n_lines)       AS max_lines, MAX(basket_sales) AS max_basket_sales
FROM (SELECT BASKET_ID, COUNT(*) AS n_lines, SUM(SALES_VALUE) AS basket_sales
      FROM transaction_data GROUP BY BASKET_ID) b;

-- Q1.7 Distinct counts in product
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT PRODUCT_ID) AS n_products,
       COUNT(DISTINCT MANUFACTURER) AS n_manufacturers, COUNT(DISTINCT DEPARTMENT) AS n_departments,
       COUNT(DISTINCT BRAND) AS n_brands, COUNT(DISTINCT COMMODITY_DESC) AS n_commodities,
       COUNT(DISTINCT SUB_COMMODITY_DESC) AS n_sub_commodities, COUNT(DISTINCT CURR_SIZE_OF_PRODUCT) AS n_sizes
FROM product;

-- Q1.8 Distinct counts in hh_demographic
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT household_key) AS n_households,
       COUNT(DISTINCT AGE_DESC) AS n_age, COUNT(DISTINCT MARITAL_STATUS_CODE) AS n_marital,
       COUNT(DISTINCT INCOME_DESC) AS n_income, COUNT(DISTINCT HOMEOWNER_DESC) AS n_homeowner,
       COUNT(DISTINCT HH_COMP_DESC) AS n_hh_comp, COUNT(DISTINCT HOUSEHOLD_SIZE_DESC) AS n_size,
       COUNT(DISTINCT KID_CATEGORY_DESC) AS n_kids
FROM hh_demographic;

-- Q1.9 campaign_desc: dates and lengths
SELECT COUNT(*) AS n_campaigns, COUNT(DISTINCT DESCRIPTION) AS n_types,
       MIN(Start_Date) AS first_start, MAX(Start_Date) AS last_start,
       MIN(End_Date) AS first_end, MAX(End_Date) AS last_end,
       MIN(DATEDIFF(day, Start_Date, End_Date)) AS min_days,
       MAX(DATEDIFF(day, Start_Date, End_Date)) AS max_days,
       AVG(DATEDIFF(day, Start_Date, End_Date)*1.0) AS avg_days
FROM campaign_desc;

-- Q1.10 campaign_table: who received campaigns
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT household_key) AS n_households,
       COUNT(DISTINCT CAMPAIGN) AS n_campaigns, COUNT(DISTINCT DESCRIPTION) AS n_types,
       COUNT(*)*1.0 / COUNT(DISTINCT household_key) AS avg_campaigns_per_household
FROM campaign_table;

-- Q1.11 coupon: coupons and products
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT COUPON_UPC) AS n_coupons,
       COUNT(DISTINCT PRODUCT_ID) AS n_products, COUNT(DISTINCT CAMPAIGN) AS n_campaigns
FROM coupon;

-- Q1.12 coupon_redempt: redemptions
SELECT COUNT(*) AS n_redemptions, COUNT(DISTINCT household_key) AS n_households,
       COUNT(DISTINCT COUPON_UPC) AS n_coupons, COUNT(DISTINCT CAMPAIGN) AS n_campaigns,
       MIN(Day_Redeemed) AS first_redeem, MAX(Day_Redeemed) AS last_redeem
FROM coupon_redempt;

-- Q1.13 week_start_end
SELECT COUNT(*) AS n_weeks, MIN(WEEK_NO) AS first_week, MAX(WEEK_NO) AS last_week,
       MIN(Week_Start) AS first_day, MAX(Week_End) AS last_day,
       MIN(DATEDIFF(day, Week_Start, Week_End)) AS min_len, MAX(DATEDIFF(day, Week_Start, Week_End)) AS max_len
FROM week_start_end;

-- Q1.14 Do the keys match across tables?
SELECT
 (SELECT COUNT(DISTINCT household_key) FROM transaction_data
   WHERE household_key IN (SELECT household_key FROM hh_demographic)) AS demo_households_that_shop,
 (SELECT COUNT(DISTINCT PRODUCT_ID) FROM transaction_data
   WHERE PRODUCT_ID NOT IN (SELECT PRODUCT_ID FROM product)) AS trans_products_missing_in_product,
 (SELECT COUNT(DISTINCT household_key) FROM campaign_table
   WHERE household_key IN (SELECT household_key FROM hh_demographic)) AS campaign_households_with_demo,
 (SELECT COUNT(*) FROM coupon_redempt r WHERE NOT EXISTS
   (SELECT 1 FROM campaign_table c WHERE c.household_key = r.household_key AND c.CAMPAIGN = r.CAMPAIGN)) AS redeemed_without_receiving,
 (SELECT COUNT(*) FROM coupon_redempt r JOIN campaign_desc d ON r.CAMPAIGN = d.CAMPAIGN
   WHERE r.Day_Redeemed NOT BETWEEN d.Start_Date AND d.End_Date) AS redeemed_outside_campaign_dates;

-- Q2 – hh_demographic by AGE_DESC
SELECT AGE_DESC, COUNT(*) AS n_households,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM hh_demographic
GROUP BY AGE_DESC
ORDER BY n_households DESC;

-- Q2 – hh_demographic by MARITAL_STATUS_CODE
SELECT MARITAL_STATUS_CODE, COUNT(*) AS n_households,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM hh_demographic
GROUP BY MARITAL_STATUS_CODE
ORDER BY n_households DESC;

-- Q2 – hh_demographic by INCOME_DESC
SELECT INCOME_DESC, COUNT(*) AS n_households,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM hh_demographic
GROUP BY INCOME_DESC
ORDER BY n_households DESC;

-- Q2 – hh_demographic by HOMEOWNER_DESC
SELECT HOMEOWNER_DESC, COUNT(*) AS n_households,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM hh_demographic
GROUP BY HOMEOWNER_DESC
ORDER BY n_households DESC;

-- Q2 – hh_demographic by HH_COMP_DESC
SELECT HH_COMP_DESC, COUNT(*) AS n_households,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM hh_demographic
GROUP BY HH_COMP_DESC
ORDER BY n_households DESC;

-- Q2 – hh_demographic by HOUSEHOLD_SIZE_DESC
SELECT HOUSEHOLD_SIZE_DESC, COUNT(*) AS n_households,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM hh_demographic
GROUP BY HOUSEHOLD_SIZE_DESC
ORDER BY n_households DESC;

-- Q2 – hh_demographic by KID_CATEGORY_DESC
SELECT KID_CATEGORY_DESC, COUNT(*) AS n_households,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM hh_demographic
GROUP BY KID_CATEGORY_DESC
ORDER BY n_households DESC;

-- Q2 – product by DEPARTMENT (top 15)
SELECT TOP 15 DEPARTMENT, COUNT(*) AS n_products,
       COUNT(DISTINCT MANUFACTURER) AS n_manufacturers,
       ROUND(SUM(CASE WHEN BRAND = 'Private' THEN 1 ELSE 0 END)*100.0 / COUNT(*), 1) AS pct_private
FROM product
GROUP BY DEPARTMENT
ORDER BY n_products DESC;

-- Q2 – product by BRAND
SELECT BRAND, COUNT(*) AS n_products, COUNT(DISTINCT MANUFACTURER) AS n_manufacturers,
       COUNT(DISTINCT DEPARTMENT) AS n_departments
FROM product
GROUP BY BRAND
ORDER BY n_products DESC;

-- Q2 – product by COMMODITY_DESC (top 10)
SELECT TOP 10 COMMODITY_DESC, COUNT(*) AS n_products,
       COUNT(DISTINCT SUB_COMMODITY_DESC) AS n_sub_commodities
FROM product
GROUP BY COMMODITY_DESC
ORDER BY n_products DESC;

-- Q2 – product by MANUFACTURER (top 10)
SELECT TOP 10 MANUFACTURER, COUNT(*) AS n_products,
       COUNT(DISTINCT DEPARTMENT) AS n_departments,
       SUM(CASE WHEN BRAND = 'Private' THEN 1 ELSE 0 END) AS n_private
FROM product
GROUP BY MANUFACTURER
ORDER BY n_products DESC;

-- Q2 – product by CURR_SIZE_OF_PRODUCT (top 10)
SELECT TOP 10 CURR_SIZE_OF_PRODUCT, COUNT(*) AS n_products
FROM product
GROUP BY CURR_SIZE_OF_PRODUCT
ORDER BY n_products DESC;

-- Q2 – campaign_desc by DESCRIPTION
SELECT DESCRIPTION, COUNT(*) AS n_campaigns,
       AVG(DATEDIFF(day, Start_Date, End_Date)*1.0) AS avg_length_days,
       MIN(Start_Date) AS first_start, MAX(End_Date) AS last_end
FROM campaign_desc
GROUP BY DESCRIPTION
ORDER BY n_campaigns DESC;

-- Q2 – campaign_table by DESCRIPTION
SELECT DESCRIPTION, COUNT(*) AS n_rows, COUNT(DISTINCT household_key) AS n_households,
       COUNT(DISTINCT CAMPAIGN) AS n_campaigns,
       COUNT(*)*1.0 / COUNT(DISTINCT CAMPAIGN) AS households_per_campaign
FROM campaign_table
GROUP BY DESCRIPTION
ORDER BY n_rows DESC;

-- Q2 – campaign_table by CAMPAIGN (top 10)
SELECT TOP 10 CAMPAIGN, DESCRIPTION, COUNT(*) AS n_households
FROM campaign_table
GROUP BY CAMPAIGN, DESCRIPTION
ORDER BY n_households DESC;

-- Q2 – coupon by CAMPAIGN (top 10)
SELECT TOP 10 CAMPAIGN, COUNT(*) AS n_rows, COUNT(DISTINCT COUPON_UPC) AS n_coupons,
       COUNT(DISTINCT PRODUCT_ID) AS n_products
FROM coupon
GROUP BY CAMPAIGN
ORDER BY n_rows DESC;

-- Q2 – coupon_redempt by CAMPAIGN (top 10)
SELECT TOP 10 CAMPAIGN, COUNT(*) AS n_redemptions,
       COUNT(DISTINCT household_key) AS n_households, COUNT(DISTINCT COUPON_UPC) AS n_coupons
FROM coupon_redempt
GROUP BY CAMPAIGN
ORDER BY n_redemptions DESC;

-- Q2 – transaction_data by STORE_ID (top 10)
SELECT TOP 10 STORE_ID, COUNT(*) AS n_rows, SUM(SALES_VALUE) AS total_sales,
       COUNT(DISTINCT household_key) AS n_households, COUNT(DISTINCT BASKET_ID) AS n_baskets
FROM transaction_data
GROUP BY STORE_ID
ORDER BY n_rows DESC;

-- Q2 – transaction_data by year/month
SELECT YEAR(Trans_Datetime) AS yr, MONTH(Trans_Datetime) AS mth,
       COUNT(*) AS n_rows, SUM(SALES_VALUE) AS total_sales,
       COUNT(DISTINCT BASKET_ID) AS n_baskets, COUNT(DISTINCT household_key) AS n_households
FROM transaction_data
GROUP BY YEAR(Trans_Datetime), MONTH(Trans_Datetime)
ORDER BY n_rows DESC;

-- Q2 – transaction_data by day of week
SELECT DATENAME(weekday, Trans_Datetime) AS day_of_week,
       COUNT(*) AS n_rows, COUNT(DISTINCT BASKET_ID) AS n_baskets, SUM(SALES_VALUE) AS total_sales
FROM transaction_data
GROUP BY DATENAME(weekday, Trans_Datetime)
ORDER BY n_rows DESC;

-- Q2 – transaction_data by hour (top 5)
SELECT TOP 5 DATEPART(hour, Trans_Datetime) AS hour_of_day,
       COUNT(DISTINCT BASKET_ID) AS n_baskets
FROM transaction_data
GROUP BY DATEPART(hour, Trans_Datetime)
ORDER BY n_baskets DESC;

-- Q2 – transaction_data by DEPARTMENT (preview join, top 10)
SELECT TOP 10 p.DEPARTMENT, COUNT(*) AS n_rows, SUM(t.SALES_VALUE) AS total_sales,
       SUM(t.RETAIL_DISC) AS loyalty_disc, SUM(t.COUPON_DISC) AS coupon_disc
FROM transaction_data t
JOIN product p ON t.PRODUCT_ID = p.PRODUCT_ID
GROUP BY p.DEPARTMENT
ORDER BY n_rows DESC;

-- Step 1 – Find candidate households
SELECT TOP 10 r.household_key, COUNT(*) AS n_redemptions,
       COUNT(DISTINCT r.CAMPAIGN) AS n_campaigns_redeemed
FROM coupon_redempt r
JOIN hh_demographic h ON r.household_key = h.household_key
WHERE r.household_key <> 208
GROUP BY r.household_key
HAVING COUNT(*) BETWEEN 3 AND 8
ORDER BY n_campaigns_redeemed DESC, n_redemptions DESC;

-- Step 2 – Demographics (hh_demographic)
SELECT * FROM hh_demographic WHERE household_key = 117;

-- Step 3 – Campaigns received (campaign_table + campaign_desc)
SELECT c.household_key, c.CAMPAIGN, c.DESCRIPTION, d.Start_Date, d.End_Date
FROM campaign_table c
JOIN campaign_desc d ON c.CAMPAIGN = d.CAMPAIGN
WHERE c.household_key = 117
ORDER BY d.Start_Date;

-- Step 4 – Coupons redeemed (coupon_redempt)
SELECT r.*, d.DESCRIPTION, d.Start_Date, d.End_Date
FROM coupon_redempt r
JOIN campaign_desc d ON r.CAMPAIGN = d.CAMPAIGN
WHERE r.household_key = 117
ORDER BY r.Day_Redeemed;

-- Step 5 – What products do those coupons cover? (coupon + product)
SELECT c.COUPON_UPC, c.CAMPAIGN, COUNT(*) AS n_products,
       MIN(p.COMMODITY_DESC) AS example_commodity_1, MAX(p.COMMODITY_DESC) AS example_commodity_2
FROM coupon c
JOIN product p ON c.PRODUCT_ID = p.PRODUCT_ID
WHERE c.COUPON_UPC IN (SELECT COUPON_UPC FROM coupon_redempt WHERE household_key = 117)
GROUP BY c.COUPON_UPC, c.CAMPAIGN
ORDER BY c.COUPON_UPC, c.CAMPAIGN;

-- Step 6 – Overall shopping of household 117 (transaction_data)
SELECT COUNT(*) AS n_lines, COUNT(DISTINCT BASKET_ID) AS n_baskets,
       COUNT(DISTINCT STORE_ID) AS n_stores, SUM(SALES_VALUE) AS total_sales,
       SUM(RETAIL_DISC) AS loyalty_disc, SUM(COUPON_DISC) AS coupon_disc,
       MIN(Trans_Datetime) AS first_trip, MAX(Trans_Datetime) AS last_trip
FROM transaction_data
WHERE household_key = 117;

-- Step 7 – Coupon lines in the household's purchases
SELECT t.BASKET_ID, t.Trans_Datetime, t.STORE_ID, t.PRODUCT_ID, p.COMMODITY_DESC,
       t.QUANTITY, t.SALES_VALUE, t.RETAIL_DISC, t.COUPON_DISC, t.COUPON_MATCH_DISC
FROM transaction_data t
JOIN product p ON t.PRODUCT_ID = p.PRODUCT_ID
WHERE t.household_key = 117 AND t.COUPON_DISC < 0
ORDER BY t.Trans_Datetime;

-- Step 1 – Product details (product)
SELECT * FROM product WHERE PRODUCT_ID = 8014645;

-- Step 2 – Which coupons and campaigns include it? (coupon + campaign_desc)
SELECT c.CAMPAIGN, c.COUPON_UPC, d.DESCRIPTION, d.Start_Date, d.End_Date,
       (SELECT COUNT(*) FROM coupon c2
         WHERE c2.COUPON_UPC = c.COUPON_UPC AND c2.CAMPAIGN = c.CAMPAIGN) AS products_on_coupon
FROM coupon c
JOIN campaign_desc d ON c.CAMPAIGN = d.CAMPAIGN
WHERE c.PRODUCT_ID = 8014645
ORDER BY d.Start_Date;

-- Step 3 – Who buys it? (transaction_data)
SELECT COUNT(*) AS n_lines, COUNT(DISTINCT household_key) AS n_households,
       SUM(QUANTITY) AS total_qty, SUM(SALES_VALUE) AS total_sales,
       SUM(CASE WHEN COUPON_DISC < 0 THEN 1 ELSE 0 END) AS lines_with_coupon,
       AVG((SALES_VALUE - RETAIL_DISC - COUPON_MATCH_DISC) / NULLIF(QUANTITY, 0)) AS avg_shelf_price
FROM transaction_data
WHERE PRODUCT_ID = 8014645;

-- Step 4 – Sales inside vs outside its campaign windows
WITH camp AS (
    SELECT DISTINCT d.Start_Date, d.End_Date
    FROM coupon c JOIN campaign_desc d ON c.CAMPAIGN = d.CAMPAIGN
    WHERE c.PRODUCT_ID = 8014645 ),
t AS (
    SELECT t.*, CASE WHEN EXISTS (SELECT 1 FROM camp
              WHERE CAST(t.Trans_Datetime AS date) BETWEEN camp.Start_Date AND camp.End_Date)
              THEN 'In campaign' ELSE 'Not in campaign' END AS period
    FROM transaction_data t WHERE t.PRODUCT_ID = 8014645 )
SELECT period, COUNT(*) AS n_lines, SUM(QUANTITY) AS total_qty,
       COUNT(DISTINCT WEEK_NO) AS n_weeks,
       SUM(QUANTITY)*1.0 / COUNT(DISTINCT WEEK_NO) AS qty_per_week,
       SUM(CASE WHEN COUPON_DISC < 0 THEN 1 ELSE 0 END) AS lines_with_coupon
FROM t
GROUP BY period
ORDER BY n_lines DESC;

-- Step 5 – Who redeemed its coupons? (coupon_redempt)
WITH r AS (
    SELECT r.*, CASE WHEN EXISTS (SELECT 1 FROM transaction_data t
                  WHERE t.household_key = r.household_key AND t.PRODUCT_ID = 8014645
                    AND CAST(t.Trans_Datetime AS date) = r.Day_Redeemed) THEN 1 ELSE 0 END AS bought_flag
    FROM coupon_redempt r
    WHERE r.COUPON_UPC IN (SELECT COUPON_UPC FROM coupon WHERE PRODUCT_ID = 8014645) )
SELECT r.COUPON_UPC, COUNT(*) AS n_redemptions, COUNT(DISTINCT r.household_key) AS n_households,
       SUM(bought_flag) AS bought_this_product_same_day
FROM r
GROUP BY r.COUPON_UPC
ORDER BY n_redemptions DESC;
