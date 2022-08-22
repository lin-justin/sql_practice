# Customer Nodes

1. How many unique nodes are there?

```sql
SELECT
	COUNT(DISTINCT(node_id))
FROM
	data_bank.customer_nodes;
```

Result:

|count|
|:---:|
|5    |

2. What is the number of nodes per region?

- Inner join the customer_nodes table with the regions table
- Count node_id and group by region_name

```sql
SELECT
	r.region_name,
	COUNT(cn.node_id) AS n_nodes
FROM
	data_bank.customer_nodes cn
INNER JOIN
	data_bank.regions r 
ON
	cn.region_id = r.region_id
GROUP BY 1
ORDER BY 2 DESC;
```

Result:

|region_name|n_nodes|
|:---:      |:---:  |
|Australia  |770    |
|America    |735    |
|Africa     |714    |
|Asia       |665    |
|Europe     |616    |

3. How many customers are allocated to each region?

- Inner join the customer_nodes table with the regions table
- Count customer_id and group by region_name

```sql
SELECT
	r.region_name,
	COUNT(cn.customer_id) AS n_customers
FROM
	data_bank.customer_nodes cn
INNER JOIN
	data_bank.regions r
ON
	cn.region_id = r.region_id
GROUP BY 1
ORDER BY 2 DESC;
```

Result:

|region_name|n_customers|
|:---:      |:---:      |
|Australia  |770        |
|America    |735        |
|Africa     |714        |
|Asia       |665        |
|Europe     |616        |

4. How many days on average are customers reallocated to a different node?

- Create a CTE that calculates the date difference between the end_date and start_date (check date ranges)
- Create another CTE to sum the date difference
- Final query would be to calculate the average of the sum of the date difference

Check min and max of start_date and end_date to ensure valid dates

```sql
SELECT
	MIN(start_date) AS min_start_date,
	MAX(start_date) AS max_start_date,
	MIN(end_date) AS min_end_date,
	MAX(end_date) AS max_end_date
FROM
	data_bank.customer_nodes;
```

Result:

|min_start_date|max_start_date|min_end_date|max_end_date|
|:---:         |:---:         |:---:       |:---:       |
|2020-01-01    |2020-07-03    |2020-01-02  |9999-12-31  |

From the query above, the max_end_date is `9999-12-31`. In the CTE, filter out this date.

```sql
-- CTE for calculating date difference
WITH node_diff_cte AS 
(
	SELECT
		customer_id,
		node_id,
		start_date,
		end_date,
		end_date - start_date AS date_diff
	FROM
		data_bank.customer_nodes
	WHERE
		end_date != '9999-12-31'
	GROUP BY 1, 2, 3, 4
	ORDER BY 1, 2
),
-- CTE for calculating the sum of the day difference
sum_date_diff_cte AS
(
	SELECT
		customer_id,
		node_id,
		SUM(date_diff) AS sum_date_diff
	FROM
		node_diff_cte
	GROUP BY 1, 2
)

-- Final query to get average of the date difference
SELECT
	ROUND(AVG(sum_date_diff), 0) AS avg_reallocation_days
FROM
	sum_date_diff_cte;
```

Result:

|avg_reallocation_days|
|:---:                |
|24                   |

5. What is the median, 80th, and 95th percentile for this same allocation days metric for each region?

- Create same node_diff_cte but include region_id to get region_name from regions table when joining
- Use the `PERCENTILE_CONT()` function to get the values

```sql
WITH node_diff_cte2 AS 
(
	SELECT
		customer_id,
		region_id,
		node_id,
		start_date,
		end_date,
		end_date - start_date AS date_diff
	FROM
		data_bank.customer_nodes
	WHERE
		end_date != '9999-12-31'
	GROUP BY 1, 2, 3, 4, 5
	ORDER BY 1, 2
)

SELECT
	r.region_name,
	(PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY n.date_diff)) AS median,
	(PERCENTILE_CONT(0.85) WITHIN GROUP(ORDER BY n.date_diff)) AS percentile_85,
	(PERCENTILE_CONT(0.95) WITHIN GROUP(ORDER BY n.date_diff)) AS percentile_95
FROM
	data_bank.regions r
INNER JOIN
	node_diff_cte2 n
ON
	r.region_id = n.region_id
GROUP BY 1;
```

Result:

|region_name|median|percentile_85|percentile_95|
|:---:      |:---: |:---:        |:---:        |
|Africa     |15    |25           |28           |
|America    |15    |25           |28           |
|Asia       |15    |24           |28           |
|Australia  |15    |25           |28           |
|Europe     |15    |26           |28           |