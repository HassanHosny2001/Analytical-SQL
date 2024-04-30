/*Q.1 -- Each customer with his total number of invoices*/
select customer_id, count(distinct invoice) as invoice_counts
from tableretail
group by customer_id
order by invoice_counts desc;
--------------------------------------------------------------------------------
/*Q.2 -- Showing the Popular Products (Top 20)*/
-- Popular Products (Top 20)
select * 
from
(
select stockcode, sum(quantity) product_counts
from tableretail
group by stockcode
order by product_counts desc
)
where rownum <= 20;
--------------------------------------------------------------------------------
/*Q.3 -- Showing each invoice_id with its amount of money in which date and 
        the customer who made it to know who made the highest invoices*/
select customer_id, invoice, sum(quantity*price) sales, to_date(invoicedate, 'MM-DD-YYYY HH24:MI') as "Date"
from tableretail
group by customer_id, invoice,invoicedate
order by sales desc;
--------------------------------------------------------------------------------
/*Q.4 -- Showing each product and sum of quantity that have been sold and total sales for each product.*/
select stockcode, quantity, sum(sales) as product_sell_price
from
(
select stockcode, sum(quantity) quantity, sum(quantity*price) sales
from tableretail
group by stockcode
order by sales desc
)
group by stockcode, quantity
order by product_sell_price desc;
--------------------------------------------------------------------------------
/*Q.5 -- Customer Segmentation Analysis to show how much each customer pays for the invoices and
            get the rank for each customer based on total sales for each customer.
        Note: it doesn’t matter how many invoices customers make, but it matters how much they pay for each invoice.*/
-- Customer Segmentation Analysis
with cust as(
    select
        customer_id,
        count(distinct invoice) invoice_count,
        sum(quantity*price) total_spending
    from tableretail
    group by customer_id
    order by total_spending desc)

select customer_id, invoice_count, total_spending,
    rank() over(order by total_spending desc) as ranking_by_sales
from cust;
--------------------------------------------------------------------------------
/*Q.6 -- Showing each customer with corresponding sales for each invoice over its date and
            also cumulative total sales for each customer until a specific invoice.*/
select customer_id, invoicedate, cust_sales,
    sum(cust_sales) over(partition by customer_id order by invoicedate) as running_total
from
(
    select 
        customer_id,
        to_date(invoicedate, 'MM-DD-YYYY HH24:MI') as invoicedate,
        sum(quantity*price) cust_sales
    from tableretail
    group by customer_id, to_date(invoicedate, 'MM-DD-YYYY HH24:MI')
    order by customer_id, invoicedate
);
--------------------------------------------------------------------------------
/*Q.7 -- Showing each stock_code with corresponding quantity over a specific date and
            also cumulative total quantities for each stock_code until a specific invoice_date.*/
select stockcode, invoicedate, count_products_sold,
    sum(count_products_sold) over(partition by stockcode order by invoicedate) running_total
from
(
select stockcode, to_date(invoicedate, 'MM-DD-YYYY HH24:MI') as invoicedate, sum(quantity) as count_products_sold
from tableretail
group by stockcode, to_date(invoicedate, 'MM-DD-YYYY HH24:MI')
order by stockcode, invoicedate
);
--------------------------------------------------------------------------------
/*Q.8 -- Showing each day with its sales and
            ordering them from the heights, in order to know in which days we achieve a lot of sales.*/
select distinct to_date(invoicedate, 'MM-DD-YYYY HH24:MI') as invoicedate,
    sum(quantity*price) over(partition by to_date(invoicedate, 'MM-DD-YYYY HH24:MI')) sales_per_day
from tableretail
order by sales_per_day desc;
--------------------------------------------------------------------------------
/*Q.9 -- Showing each invoice with the corresponding stock_code have been bought on it and
            the deviation of the price from the average price for each stock code.*/
select invoice, stockcode, price, avg_price,
    -- calculate the deviation of the price from the average price for each stockcode.
    round(price - avg_price, 2) as price_deviation,
    dense_rank() over(order by price) as ranking
from(
select invoice, stockcode, price,
    round(avg(price) over(partition by stockcode),2) as avg_price
from tableretail);
--------------------------------------------------------------------------------
/*Q.2 -- RFM*/
WITH customer_sales as (
    select 
        customer_id,
        sum(price * quantity) as sum_of_sales 
    from tableRetail
    group by customer_id),
RFM as (
    select distinct customer_id,
        round(max(to_date(invoicedate, 'MM-DD-YYYY HH24:MI')) over() - max(to_date(invoicedate, 'MM-DD-YYYY HH24:MI')) over(partition by customer_id)) as recency,
        count(invoice) over(partition by customer_id) as frequency,
        round(sum((quantity*price)/1000) over(partition by customer_id), 2) as monetary
    from tableretail),
RFM_scores as (
    select customer_id, recency, frequency, monetary,
        ntile(5) over (order by recency) as r_score,
        ntile(5) over (order by frequency+monetary) as fm_score 
    from RFM)
select customer_id, recency, frequency, monetary, r_score, fm_score, 
CASE
          WHEN R_SCORE=5 AND FM_SCORE=5 THEN 'Champion'
          WHEN R_SCORE=5 AND FM_SCORE=4 THEN 'Champion'
          WHEN R_SCORE=4 AND FM_SCORE=5 THEN 'Champion'
          WHEN R_SCORE=5 AND FM_SCORE=2 THEN 'Potential Loyalist'
          WHEN R_SCORE=4 AND FM_SCORE=2 THEN 'Potential Loyalist'
          WHEN R_SCORE=3 AND FM_SCORE=3 THEN 'Potential Loyalist'
          WHEN R_SCORE=4 AND FM_SCORE=3 THEN 'Potential Loyalist'
          WHEN R_SCORE=5 AND FM_SCORE=3 THEN 'Loyal Customer'
          WHEN R_SCORE=4 AND FM_SCORE=4 THEN 'Loyal Customer'
          WHEN R_SCORE=3 AND FM_SCORE=5 THEN 'Loyal Customer'
          WHEN R_SCORE=3 AND FM_SCORE=4 THEN 'Loyal Customer'
          WHEN R_SCORE=5 AND FM_SCORE=1 THEN 'Recent Customer'
          WHEN R_SCORE=4 AND FM_SCORE=1 THEN 'Promising'
          WHEN R_SCORE=3 AND FM_SCORE=1 THEN 'Promising'
          WHEN R_SCORE=3 AND FM_SCORE=2 THEN 'Customers Needing Attention'
          WHEN R_SCORE=2 AND FM_SCORE=3 THEN 'Customers Needing Attention'
          WHEN R_SCORE=2 AND FM_SCORE=2 THEN 'Customers Needing Attention'
          WHEN R_SCORE=2 AND FM_SCORE=5 THEN 'At Risk'
          WHEN R_SCORE=2 AND FM_SCORE=4 THEN 'AT RISK'
          WHEN R_SCORE=1 AND FM_SCORE=3 THEN 'AT RISK'
          WHEN R_SCORE=1 AND FM_SCORE=5 THEN 'Cant Lose Them'
          WHEN R_SCORE=1 AND FM_SCORE=4 THEN 'Cant Lose Them'
          WHEN R_SCORE=1 AND FM_SCORE=2 THEN 'Hibernating'
          WHEN R_SCORE=1 AND FM_SCORE=1 THEN 'Lost'
          ELSE 'Other'
        END AS "CUSTOMER GROUP" from RFM_scores ;
--------------------------------------------------------------------------------
/*Q.3 -- a. What is the maximum number of consecutive days a customer made purchases?*/
with CTE as(
    select cust_id, calendar_dt,
        calendar_dt - row_number() over (partition by cust_id order by calendar_dt) as date_check
    from cust_transactions
    )

select cust_id, max(counts) as max_consecutive_days
from
(
    select cust_id, count(date_check) counts, min(calendar_dt) min_date, max(calendar_dt) max_date
    from cte
    group by cust_id, date_check
) 
group by cust_id;
--------------------------------------------------------------------------------
/* b. On average, How many days/transactions does it take a customer to reach a spent 
        threshold of 250 L.E?*/
with CTE as(
select cust_id, calendar_dt, amt_le,
    sum(amt_le) over(partition by cust_id order by calendar_dt) as cum_total_spend,
    row_number() over(partition by cust_id order by calendar_dt) as days_count
from cust_transactions),
CTE2 as(
select 
    cust_id,
    cum_total_spend,
    days_count
from CTE
where cum_total_spend >= 250),
average as(
select
    cust_id,
    min(days_count) as counts
from CTE2
group by cust_id
order by counts desc)

select 
    round(avg(counts)) as avg_days_reach_250LE
from average;