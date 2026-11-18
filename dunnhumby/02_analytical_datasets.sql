
USE dunnhumby;
GO
   --QUERY 1: Basket_overview  (one row per basket)

WITH transactions_joined AS
(
    SELECT
        t.household_key,
        t.BASKET_ID,
        t.STORE_ID,
        t.Trans_Datetime,
        t.PRODUCT_ID,
        t.QUANTITY,
        t.SALES_VALUE,
        t.RETAIL_DISC,
        t.COUPON_DISC,
        t.SALES_VALUE + t.COUPON_DISC                       AS customer_paid,  -- what the shopper actually paid
        CASE WHEN p.SUB_COMMODITY_DESC LIKE 'GASOLINE%'
             THEN 1 ELSE 0 END                              AS is_gasoline,    -- 1 = fuel line
        -- all demographic variables (NULL when the household has no demographics)
        h.AGE_DESC,
        h.MARITAL_STATUS_CODE,
        h.INCOME_DESC,
        h.HOMEOWNER_DESC,
        h.HH_COMP_DESC,
        h.HOUSEHOLD_SIZE_DESC,
        h.KID_CATEGORY_DESC
    FROM transaction_data t
    INNER JOIN product p             ON t.PRODUCT_ID    = p.PRODUCT_ID     -- every product matches 
    LEFT  JOIN hh_demographic h      ON t.household_key = h.household_key  -- keep households without demographics
)
SELECT
    -- a. demographic variables (constant within a basket, so safe in GROUP BY)
    household_key,
    AGE_DESC, MARITAL_STATUS_CODE, INCOME_DESC, HOMEOWNER_DESC,
    HH_COMP_DESC, HOUSEHOLD_SIZE_DESC, KID_CATEGORY_DESC,
    BASKET_ID,
    -- b. store and c. date/time (each basket has exactly ONE store and ONE datetime)
    STORE_ID,
    Trans_Datetime,

    -- d.i   number of distinct products in the basket
    COUNT(DISTINCT PRODUCT_ID)                                   AS n_distinct_products,
    -- d.ii  total quantity, gasoline excluded
    SUM(CASE WHEN is_gasoline = 0 THEN QUANTITY ELSE 0 END)      AS total_quantity_excl_gas,
    -- d.iii total sales = revenue the retailer receives
    SUM(SALES_VALUE)                                             AS total_revenue,
    -- d.iv  total the customer actually paid
    SUM(customer_paid)                                           AS amount_spent,
    -- d.v   discounts as positive savings: loyalty card, coupon, then both combined
    0 - SUM(RETAIL_DISC)                                         AS retail_disc_savings,   -- "0 -" instead of "-" avoids showing -0
    0 - SUM(COUPON_DISC)                                         AS coupon_disc_savings,
    0 - SUM(RETAIL_DISC + COUPON_DISC)                           AS total_disc_savings,
    -- d.vi  percent discount = savings / price before those discounts
    --       price before discounts = amount_spent + total savings
    --       NULLIF avoids divide-by-zero for baskets worth $0 (859 baskets -> NULL)
    --       A few baskets exceed 100% when a coupon is worth more than the
    --       item's price after the loyalty discount.
    ROUND( 100.0 * (0 - SUM(RETAIL_DISC + COUPON_DISC))
           / NULLIF(SUM(customer_paid) - SUM(RETAIL_DISC + COUPON_DISC), 0), 2)
                                                                 AS pct_discount
FROM transactions_joined
GROUP BY
    household_key,
    AGE_DESC, MARITAL_STATUS_CODE, INCOME_DESC, HOMEOWNER_DESC,
    HH_COMP_DESC, HOUSEHOLD_SIZE_DESC, KID_CATEGORY_DESC,
    BASKET_ID, STORE_ID, Trans_Datetime
ORDER BY household_key, Trans_Datetime;
-- Check: returns 251,118 rows = COUNT(DISTINCT BASKET_ID) in transaction_data,
-- so no basket was split or duplicated by the joins.
GO

 --  QUERY 2: Monthly_hh_overview  (one row per household per month)

WITH transactions_joined AS
(
    -- same joined table as Query 1, plus a month key
    SELECT
        t.household_key,
        t.BASKET_ID,
        t.STORE_ID,
        t.PRODUCT_ID,
        t.RETAIL_DISC,
        t.COUPON_DISC,
        t.SALES_VALUE + t.COUPON_DISC                       AS customer_paid,
        CAST(t.Trans_Datetime AS date)                      AS visit_date,
        YEAR(t.Trans_Datetime)                              AS trans_year,
        MONTH(t.Trans_Datetime)                             AS trans_month,
        h.AGE_DESC,
        h.MARITAL_STATUS_CODE,
        h.INCOME_DESC,
        h.HOMEOWNER_DESC,
        h.HH_COMP_DESC,
        h.HOUSEHOLD_SIZE_DESC,
        h.KID_CATEGORY_DESC
    FROM transaction_data t
    INNER JOIN product p             ON t.PRODUCT_ID    = p.PRODUCT_ID
    LEFT  JOIN hh_demographic h      ON t.household_key = h.household_key
),

/* ---- BONUS (i): average number of days between visits ----------------------
   Step 1: one row per household per visit DAY (several baskets on the same
           day count as one visit).
   Step 2: LAG() gets the household's previous visit date; DATEDIFF = gap.
           The first visit of each household has no previous visit -> NULL,
           and AVG() ignores NULLs.
   Step 3: the gap is assigned to the month of the LATER visit, then averaged
           per household-month.                                              */
visits AS
(
    SELECT DISTINCT household_key, visit_date
    FROM transactions_joined
),
visit_gaps AS
(
    SELECT
        household_key,
        visit_date,
        DATEDIFF(day,
                 LAG(visit_date) OVER (PARTITION BY household_key ORDER BY visit_date),
                 visit_date)                                AS days_since_last_visit
    FROM visits
),
monthly_gaps AS
(
    SELECT
        household_key,
        YEAR(visit_date)                                    AS trans_year,
        MONTH(visit_date)                                   AS trans_month,
        AVG(days_since_last_visit * 1.0)                    AS avg_days_between_visits
    FROM visit_gaps
    GROUP BY household_key, YEAR(visit_date), MONTH(visit_date)
),

--main monthly aggregation
monthly AS
(
    SELECT
        household_key,
        trans_year,
        trans_month,
        -- a. demographic variables
        AGE_DESC, MARITAL_STATUS_CODE, INCOME_DESC, HOMEOWNER_DESC,
        HH_COMP_DESC, HOUSEHOLD_SIZE_DESC, KID_CATEGORY_DESC,
        -- b. number of baskets (shopping trips) in the month
        COUNT(DISTINCT BASKET_ID)                           AS n_baskets,
        -- c. total amount the household paid
        SUM(customer_paid)                                  AS total_amount_paid,
        -- d. average amount paid PER BASKET (not per line)
        SUM(customer_paid) / COUNT(DISTINCT BASKET_ID)      AS avg_amount_paid_per_basket,
        -- e. number of different stores visited
        COUNT(DISTINCT STORE_ID)                            AS n_distinct_stores,
        -- f. saved with the loyalty card (positive number)
        0 - SUM(RETAIL_DISC)                                AS saved_loyalty_card,
        -- g. saved with coupons (positive number)
        0 - SUM(COUPON_DISC)                                AS saved_coupons,
        -- h. average number of products per basket
        --    (1 line = 1 distinct product in a basket, so lines / baskets)
        COUNT(*) * 1.0 / COUNT(DISTINCT BASKET_ID)          AS avg_products_per_basket
    FROM transactions_joined
    GROUP BY
        household_key, trans_year, trans_month,
        AGE_DESC, MARITAL_STATUS_CODE, INCOME_DESC, HOMEOWNER_DESC,
        HH_COMP_DESC, HOUSEHOLD_SIZE_DESC, KID_CATEGORY_DESC
)
SELECT
    m.*,
    -- i. (bonus) average days between visits; NULL only in a household's first month
    --    if it had a single visit that month
    g.avg_days_between_visits
FROM monthly m
LEFT JOIN monthly_gaps g
       ON  m.household_key = g.household_key
       AND m.trans_year    = g.trans_year
       AND m.trans_month   = g.trans_month
ORDER BY m.household_key, m.trans_year, m.trans_month;
-- Check: one row per household-month (40,266 rows, 2,499 households); SUM(total_amount_paid)
-- equals SUM(SALES_VALUE + COUPON_DISC) over the whole transaction_data table.
GO
