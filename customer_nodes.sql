-- A. Customer Nodes
-- 1. How many unique nodes are there on the Data Bank System?
SELECT
	COUNT(DISTINCT(node_id))
FROM
	data_bank.customer_nodes;
	
-- 2. What is the number of nodes per region?
-- Inner join the customer_nodes table with the regions table
-- Count node_id and group by region_name
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

-- 3. How many customers are allocated to each region?
-- Inner join the customer_nodes table with the regions_table
-- Count customer_id and group by region_name
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

-- 4. How many days on average are customers reallocated to a different node?
-- customer_nodes table is main table of interest
-- Create a CTE that calculates the date difference between end_date and start_date (would need to check the dates)
-- Then create another CTE that sums the date difference
-- Final query would be the average of the sum of the date difference

-- First check min and max of start_date and end_date to ensure valid dates
SELECT
	MIN(start_date) AS min_start_date,
	MAX(start_date) AS max_start_date,
	MIN(end_date) AS min_start_date,
	MAX(end_date) AS max_end_date
FROM
	data_bank.customer_nodes;
	
-- From the query above, max_end_date is 9999-12-31
-- Therefore, in the CTE for calculating the date difference,
-- filter out 9999-12-31 from end_date

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
-- Result = 24
	
-- 5. What is the median, 80th, and 95th percentile for this same allocation days metric for each region?
-- Create same node_diff_cte but include region_id since we need region_name from the regions table
-- Use the PERCENTILE_CONT() function to get the percentile values
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