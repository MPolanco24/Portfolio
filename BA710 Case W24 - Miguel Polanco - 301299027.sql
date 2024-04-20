
/***BE SURE TO DROP ALL TABLES IN WORK THAT BEGIN WITH "CASE_"***/
use ba710case;
/*Set Time Zone*/
set time_zone='-4:00';
select now();

/***PRELIMINARY ANALYSIS***/

/*Create a VIEW in WORK called CASE_SCOOT_NAMES that is a subset of the prod table
which only contains scooters.
Result should have 7 records.*/

create or replace view work.case_scoot_names AS
select * from ba710case.ba710_prod
where product_type = 'scooter';

select * from work.case_scoot_names;

/*The following code uses a join to combine the view above with the sales information.
  Can the expected performance be improved using an index?
  A) Calculate the EXPLAIN COST.
  B) Create the appropriate indexes.
  C) Calculate the new EXPLAIN COST.
  D) What is your conclusion?:
*/

select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
    
/*A) Calculate the EXPLAIN COST.*/

/*Cost is 4,472.85*/

explain format = json 
select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
/*'{
  "query_block": {
    "select_id": 1,
    "cost_info": {
      "query_cost": "4472.85"
    },
    "nested_loop": [
      {
        "table": {
          "table_name": "ba710_prod",
          "access_type": "ALL",
          "rows_examined_per_scan": 12,
          "rows_produced_per_join": 1,
          "filtered": "10.00",
          "cost_info": {
            "read_cost": "1.33",
            "eval_cost": "0.12",
            "prefix_cost": "1.45",
            "data_read_per_join": "67"
          },
          "used_columns": [
            "product_id",
            "model",
            "product_type"
          ],
          "attached_condition": "(`ba710case`.`ba710_prod`.`product_type` = ''scooter'')"
        }
      },
      {
        "table": {
          "table_name": "b",
          "access_type": "ALL",
          "rows_examined_per_scan": 36790,
          "rows_produced_per_join": 4414,
          "filtered": "10.00",
          "using_join_buffer": "hash join",
          "cost_info": {
            "read_cost": "56.60",
            "eval_cost": "441.48",
            "prefix_cost": "4472.85",
            "data_read_per_join": "206K"
          },
          "used_columns": [
            "customer_id",
            "product_id",
            "sales_transaction_date",
            "sales_amount",
            "channel",
            "dealership_id"
          ],
          "attached_condition": "(`ba710case`.`b`.`product_id` = `ba710case`.`ba710_prod`.`product_id`)"
        }
      }
    ]
  }
}'*/

/*B) Create the appropriate indexes.*/

alter table ba710case.ba710_sales
add index index_product_id(product_id);

/*C) Calculate the new EXPLAIN COST.*/

/*Cost is 605.29*/

explain format = json
select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;

/*'{
  "query_block": {
    "select_id": 1,
    "cost_info": {
      "query_cost": "605.29"
    },
    "nested_loop": [
      {
        "table": {
          "table_name": "ba710_prod",
          "access_type": "ALL",
          "rows_examined_per_scan": 12,
          "rows_produced_per_join": 1,
          "filtered": "10.00",
          "cost_info": {
            "read_cost": "1.33",
            "eval_cost": "0.12",
            "prefix_cost": "1.45",
            "data_read_per_join": "67"
          },
          "used_columns": [
            "product_id",
            "model",
            "product_type"
          ],
          "attached_condition": "((`ba710case`.`ba710_prod`.`product_type` = ''scooter'') and (`ba710case`.`ba710_prod`.`product_id` is not null))"
        }
      },
      {
        "table": {
          "table_name": "b",
          "access_type": "ref",
          "possible_keys": [
            "index_product_id"
          ],
          "key": "index_product_id",
          "used_key_parts": [
            "product_id"
          ],
          "key_length": "9",
          "ref": [
            "ba710case.ba710_prod.product_id"
          ],
          "rows_examined_per_scan": 3344,
          "rows_produced_per_join": 4013,
          "filtered": "100.00",
          "cost_info": {
            "read_cost": "202.50",
            "eval_cost": "401.35",
            "prefix_cost": "605.30",
            "data_read_per_join": "188K"
          },
          "used_columns": [
            "customer_id",
            "product_id",
            "sales_transaction_date",
            "sales_amount",
            "channel",
            "dealership_id"
          ]
        }
      }
    ]
  }
}'*/

/*D) What is your conclusion?:*/

/*It is clear that the Index helped to reduce significatly the cost of query which means that this change optimize the return of query*/

/***PART 1: INVESTIGATE BAT SALES TRENDS***/  
    
/*The following creates a table of daily sales with four columns and will be used in the following step.*/

CREATE TABLE work.case_daily_sales AS
	select p.model, p.product_id, date(s.sales_transaction_date) as sale_date, 
		   round(sum(s.sales_amount),2) as daily_sales
	from ba710case.ba710_sales as s 
    inner join ba710case.ba710_prod as p
		on s.product_id=p.product_id
    group by date(s.sales_transaction_date),p.product_id,p.model;

select * from work.case_daily_sales;

/*Create a view (5 columns)of cumulative sales figures for just the Bat scooter from
the daily sales table you created.
Using the table created above, add a column that contains the cumulative
sales amount (one row per date).
Hint: Window Functions, Over*/

create or replace view work.cumulative_sales_bat as
select case_daily_sales. * , sum(daily_sales) over(partition by model order by sale_date) as cumulative_sales
from work.case_daily_sales
where product_id='7';
    
select * from work.cumulative_sales_bat;

/*Using the view above, create a VIEW (6 columns) that computes the cumulative sales 
for the previous 7 days for just the Bat scooter. 
(i.e., running total of sales for 7 rows inclusive of the current row.)
This is calculated as the 7 day lag of cumulative sum of sales
(i.e., each record should contain the sum of sales for the current date plus
the sales for the preceeding 6 records).
*/

create or replace view work.cumulative_sales_bat_2 as
select cumulative_sales_bat. * , sum(daily_sales) over(partition by model order by sale_date rows between 6 preceding and current row) as cumulative_sales_7_days
from work.cumulative_sales_bat
where product_id='7';

select * from work.cumulative_sales_bat_2;

/*Using the view you just created, create a new view (7 columns) that calculates
the weekly sales growth as a percentage change of cumulative sales
compared to the cumulative sales from the previous week (seven days ago).

See the Word document for an example of the expected output for the Blade scooter.*/

/*Paste a screenshot of at least the first 10 records of the table
  and answer the questions in the Word document*/
  
create or replace view work.cumulative_sales_bat_3 as
select cumulative_sales_bat_2. * , (cumulative_sales-lag(cumulative_sales,7) over(order by sale_date))/lag(cumulative_sales,7) over(order by sale_date)*100 as percentage_weekly_cumulative_sales_growth
from work.cumulative_sales_bat_2
where product_id='7';

select * from work.cumulative_sales_bat_3;  
  
/*********************************************************************************************
Is the launch timing (October) a potential cause for the drop?
Answer: It does not seem to be the case as if it is compared with the other editions of the product that were launched in a different season.

Replicate the Bat sales cumulative analysis for the Bat Limited Edition.
*/

/*First Part*/
create or replace view work.cumulative_sales_bat_limited_edition as
select case_daily_sales. * , sum(daily_sales) over(partition by model order by sale_date) as cumulative_sales
from work.case_daily_sales
where product_id='8';
    
select * from work.cumulative_sales_bat_limited_edition;

/*Second Part*/
create or replace view work.cumulative_sales_bat_limited_edition_2 as
select cumulative_sales_bat_limited_edition. * , sum(daily_sales) over(partition by model order by sale_date rows between 6 preceding and current row) as cumulative_sales_7_days
from work.cumulative_sales_bat_limited_edition
where product_id='8';

select * from work.cumulative_sales_bat_limited_edition_2;

/*Third Part*/
create or replace view work.cumulative_sales_bat_limited_edition_3 as
select cumulative_sales_bat_limited_edition_2. * , (cumulative_sales-lag(cumulative_sales,7) over(order by sale_date))/lag(cumulative_sales,7) over(order by sale_date)*100 as percentage_weekly_cumulative_sales_growth
from work.cumulative_sales_bat_limited_edition_2
where product_id='8';

select * from work.cumulative_sales_bat_limited_edition_3;

/*Paste a screenshot of at least the first 10 records of the table
  and answer the questions in the Word document*/

/*********************************************************************************************
However, the Bat Limited was at a higher price point.
Let's take a look at the 2013 Lemon model, since it's a similar price point.  
Is the launch timing (October) a potential cause for the drop?
Answer: It does not seem to be the case as if it is compared with the other editions of the product that were launched in a different season.

Replicate the Bat sales cumulative analysis for the 2013 Lemon model.*/

/*First Part*/
create or replace view work.cumulative_sales_2013_lemon_model as
select case_daily_sales. * , sum(daily_sales) over(partition by model order by sale_date) as cumulative_sales
from work.case_daily_sales
where product_id='3';
    
select * from work.cumulative_sales_2013_lemon_model;

/*Second Part*/
create or replace view work.cumulative_sales_2013_lemon_model_2 as
select cumulative_sales_2013_lemon_model. * , sum(daily_sales) over(partition by model order by sale_date rows between 6 preceding and current row) as cumulative_sales_7_days
from work.cumulative_sales_2013_lemon_model
where product_id='3';

select * from work.cumulative_sales_2013_lemon_model_2;

/*Third Part*/
create or replace view work.cumulative_sales_2013_lemon_model_3 as
select cumulative_sales_2013_lemon_model_2. * , (cumulative_sales-lag(cumulative_sales,7) over(order by sale_date))/lag(cumulative_sales,7) over(order by sale_date)*100 as percentage_weekly_cumulative_sales_growth
from work.cumulative_sales_2013_lemon_model_2
where product_id='3';

select * from work.cumulative_sales_2013_lemon_model_3;  

/*Paste a screenshot of at least the first 10 records of the table
  and answer the questions in the Word document*/
