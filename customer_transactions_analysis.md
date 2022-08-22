# Customer Transactions

## 1. What is the unique count and total amount for each transaction type?

```sql
SELECT
	txn_type,
	COUNT(txn_type),
	SUM(txn_amount) AS total_amount
FROM
	data_bank.customer_transactions
GROUP BY 1
ORDER BY 1 DESC, 2 DESC;
```

Result:

|txn_type  |count|total_amount|
|:---:     |:---:|:---:       |
|withdrawal|1580 |793003      |
|purchase  |1617 |806537      |
|deposit   |2671 |1359168     |

## 2. What is the average total historical deposit counts and amounts for all customers?

-- Create a CTE to calculate the transaction count and average historical deposit amount for each customer and then filter `txn_type` to `deposit`

```sql
WITH deposit_cte AS 
(
	SELECT
		customer_id,
		txn_type,
		COUNT(txn_type) AS deposit_count,
		AVG(txn_amount) AS avg_txn_amount
	FROM
		data_bank.customer_transactions
	WHERE
		txn_type = 'deposit'
	GROUP BY 1, 2
)

SELECT
	ROUND(AVG(deposit_count), 0) AS avg_deposit,
	ROUND(AVG(avg_txn_amount), 2) AS avg_deposit_amount
FROM
	deposit_cte;
```

Result:

|avg_deposit|avg_deposit_amount|
|:---:      |:---:             |
|5          |508.61            |

## 3. For each month - how many customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

- Create CTE to calculate count for each transaction type for each customer, grouped by month
- Apply filtering logic

```sql
WITH monthly_transactions_cte AS
(
	SELECT
		customer_id,
		TO_CHAR(txn_date, 'Month') AS month,
		SUM(
			CASE
				WHEN txn_type = 'deposit' THEN 1
				ELSE 0
			END
		) AS deposit_total,
		SUM(
			CASE
				WHEN txn_type = 'purchase' THEN 1
				ELSE 0
			END
		) AS purchase_total,
		SUM(
			CASE
				WHEN txn_type = 'withdrawal' THEN 1
				ELSE 0
			END
		) AS withdrawal_total
	FROM
		data_bank.customer_transactions
	GROUP BY 1, 2
)

SELECT
	month,
	COUNT(DISTINCT customer_id)
FROM
	monthly_transactions_cte
WHERE
	deposit_total > 1 AND
	(purchase_total = 1 OR withdrawal_total = 1)
GROUP BY 1
ORDER BY 2 ASC;
```

Result:

|month   |count|
|:---:   |:---:|
|April   |50   |
|February|108  |
|March   |113  |
|January |115  |

## 4. What is the closing balance for each customer at the end of the month?

```sql
-- CTE 1: Get the transaction amount as an inflow (+) or outflow (-)
WITH monthly_balances AS (
  SELECT 
    customer_id, 
    (DATE_TRUNC('month', txn_date) + INTERVAL '1 MONTH - 1 DAY') AS closing_month, 
    txn_type, 
    txn_amount,
    SUM(CASE 
			WHEN txn_type = 'withdrawal' OR txn_type = 'purchase' THEN (-txn_amount)
      		ELSE txn_amount 
		END) AS transaction_balance
  FROM data_bank.customer_transactions
  GROUP BY customer_id, txn_date, txn_type, txn_amount
),

-- CTE 2: Transform txn_date as a series of the last day of each month for each customer
last_day AS (
  SELECT
    DISTINCT customer_id,
    ('2020-01-31'::DATE + GENERATE_SERIES(0,3) * INTERVAL '1 MONTH') AS ending_month
  FROM
	data_bank.customer_transactions
),

-- CTE 3: Calculate the closing balance for each month using a Window function 
-- and the SUM() function to capture changes during the month
closing_balance_cte AS (
  SELECT 
    ld.customer_id, 
    ld.ending_month,
    COALESCE(mb.transaction_balance, 0) AS monthly_change,
    SUM(mb.transaction_balance) OVER 
      (PARTITION BY ld.customer_id 
	   ORDER BY ld.ending_month
       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS closing_balance
  FROM last_day ld
  LEFT JOIN 
	monthly_balances mb
  ON 
	ld.ending_month = mb.closing_month AND 
	ld.customer_id = mb.customer_id
),

-- CTE 4: Use ROW_NUMBER() to rank the transactions within each month
transaction_rank_cte AS (
  SELECT 
    customer_id, 
	ending_month, 
    monthly_change, 
	closing_balance,
    ROW_NUMBER() OVER 
      (PARTITION BY customer_id, ending_month 
	   ORDER BY ending_month) AS record_no
  FROM closing_balance_cte
),

-- CTE 5: Use LEAD() to query the value in the next row and retrieve NULL for the last row
lead_cte AS (
  SELECT 
    customer_id, 
	ending_month, 
    monthly_change, 
	closing_balance, 
    record_no,
    LEAD(record_no) OVER 
      (PARTITION BY customer_id, ending_month 
	   ORDER BY ending_month) AS lead_no
  FROM transaction_rank_cte
)

SELECT 
  customer_id, 
  ending_month::DATE, 
  monthly_change, 
  closing_balance,
  CASE 
  	WHEN lead_no IS NULL THEN record_no 
  END AS criteria
FROM 
	lead_cte
WHERE 
	lead_no IS NULL;
```

|customer_id|ending_month|monthly_change|closing_balance|
|:---:      |:---:       |:---:         |:---:          |
|1          |2020-01-31  |312           |312            |
|1          |2020-02-29  |0             |312            |
|1          |2020-03-31  |324           |-640           |
|1          |2020-04-30  |0             |-640           |
|2          |2020-01-31  |549           |549            |
|2          |2020-02-29  |0             |549            |
|2          |2020-03-31  |61            |610            |
|2          |2020-04-30  |0             |610            |
|3          |2020-01-31  |144           |144            |
|3          |2020-02-29  |-965          |-821           |
|...        |...         |...           |               |