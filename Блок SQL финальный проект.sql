USE customers_transactions;

#1. Средний чек за период с 01.06.2015 по 01.06.2016 с непрерывной историей за год
# +общую сумму покупок за 12 месяцев
# + количество операция за год
# + сумму покупок и количество операций за каждый месяц
SELECT * FROM transactions;

WITH checks AS(
	SELECT id_client, id_check, DATE(date_new) AS check_date, SUM(sum_payment) AS check_amount
    FROM transactions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
    GROUP BY id_client, id_check, DATE(date_new)),
    
monthly AS(
		SELECT id_client, DATE_FORMAT(check_date, '%Y-%m') AS month, SUM(check_amount) AS monthly_sum, AVG(check_amount) AS monthly_avg_check,COUNT(*) AS operations
        FROM checks
        GROUP BY id_client, DATE_FORMAT(check_date, '%Y-%m')),
        
eligible_clients AS(
		SELECT id_client
        FROM monthly
        GROUP BY id_client
        HAVING COUNT(DISTINCT month) = 12), 
        
client_summary AS(
	SELECT c.id_client, AVG(c.check_amount) AS average_check, SUM(c.check_amount) / 12 AS average_monthly_sum, COUNT(*) AS total_operations, SUM(c.check_amount) AS total_sum
    FROM checks c
    JOIN eligible_clients ec
		ON c.id_client = ec.id_client
	GROUP BY ec.id_client)
    
SELECT m.id_client, m.month, m.monthly_sum, m.monthly_avg_check, m.operations AS monthly_operations, cs.average_check, cs.average_monthly_sum, cs.total_operations, cs.total_sum
FROM monthly m
JOIN client_summary cs
	ON m.id_client = cs.id_client
ORDER BY m.id_client, m.month;

#2. Средняя сумма чека в месяц
SELECT DATE_FORMAT(date_new, '%Y-%m') AS month, AVG(check_amount) AS average_check
FROM(
	SELECT date_new, id_check, id_client, SUM(sum_payment) AS check_amount
    FROM transactions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
    GROUP BY date_new, id_check, id_client
    ) AS checks
GROUP BY DATE_FORMAT(date_new, '%Y-%m')
ORDER BY month;

#2. Среднее число операций в месяц.
SELECT COUNT(*) / 12 AS avg_operations_per_month
FROM(
	SELECT id_check, id_client, date_new
    FROM transactions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
    GROUP BY id_check, id_client, date_new
	) AS operations;
    
#2. Среднее количество клиентов, которые совершали операции;
SELECT AVG(monthly_clients) AS avg_clients_per_month
FROM(
	SELECT DATE_FORMAT(date_new, '%Y-%m') AS month, COUNT(DISTINCT id_client) AS monthly_clients
    FROM transactions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
    GROUP BY DATE_FORMAT(date_new, '%Y-%m')
	) AS monthly_stats;
    
#2. Доля от общего количества операций за год и доля в месяц от общей суммы операций;
SELECT 
	DATE_FORMAT(date_new, '%Y-%m') AS month, 
    COUNT(*) AS monthly_operations, 
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS operations_share_percent,
    SUM(sum_payment) AS monthly_amount,
    SUM(sum_payment) * 100.0 / SUM(SUM(sum_payment)) OVER () AS amount_share_percent
FROM transactions
WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
GROUP BY DATE_FORMAT(date_new, '%Y-%m')
ORDER BY month;

#2. Вывести % соотношение M/F/NA в каждом месяце с их долей затрат;
SELECT
	DATE_FORMAT(date_new, '%Y-%m') AS month,
    COUNT(DISTINCT CASE WHEN c.gender = 'M' THEN t.id_client END) * 100.0 / COUNT(DISTINCT t.id_client) AS m_clients_percent,
    SUM(CASE WHEN c.gender = 'M' THEN t.sum_payment ELSE 0 END) * 100.0 / NULLIF(SUM(t.sum_payment), 0) AS m_spending_percent,
    COUNT(DISTINCT CASE WHEN c.gender = 'F' THEN t.id_client END) * 100.0 / COUNT(DISTINCT t.id_client) AS f_clients_percent,
    SUM(CASE WHEN c.gender = 'F' THEN t.sum_payment ELSE 0 END) * 100.0 / NULLIF(SUM(t.sum_payment), 0) AS f_spending_percent,
    COUNT(DISTINCT CASE WHEN c.gender IS NULL OR TRIM(c.gender) = '' OR c.gender NOT IN ('M', 'F') THEN t.id_client END) * 100.0 / COUNT(DISTINCT t.id_client) AS na_clients_percent,
    SUM(CASE WHEN c.gender IS NULL OR TRIM(c.gender) = '' OR c.gender NOT IN ('M', 'F') THEN t.sum_payment ELSE 0 END) * 100.0 / NULLIF(SUM(t.sum_payment), 0) AS na_spending_percent
FROM transactions t
LEFT JOIN customers c
	ON t.id_client = c.id_client
WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
GROUP BY DATE_FORMAT(date_new, '%Y-%m')
ORDER BY month;

#3. возрастные группы клиентов с шагом 10 лет и отдельно клиенты, у которых нет данной информации с параметрами сумма и количество операций за весь период.
WITH checks AS(
	SELECT t.id_client, t.id_check, DATE(t.date_new) AS check_date, SUM(t.sum_payment) AS check_amount
    FROM transactions t
    WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
    GROUP BY t.id_client, t.id_check, DATE(t.date_new)),
    
age_data AS(
	SELECT 
		c.id_client, 
		c.check_date, 
		c.check_amount,
        CASE 
			WHEN cu.age IS NULL THEN 'No data' 
			ELSE CONCAT(FLOOR(cu.age / 10) * 10, '-', FLOOR(cu.age / 10) * 10 + 9)
		END AS age_group,
        CASE
			WHEN cu.age IS NULL THEN 999
            ELSE FLOOR(cu.age / 10) * 10
		END AS age_sort
	FROM checks c
    LEFT JOIN customers cu ON c.id_client = cu.id_client),
    
age_stats AS(
	SELECT age_group, age_sort, SUM(check_amount) as total_amount, COUNT(*) AS total_operations, AVG(check_amount) AS average_check
    FROM age_data
    GROUP BY age_group, age_sort)
    
SELECT
	age_group, 
	total_amount, 
    total_operations, 
    average_check, 
    100.0 * total_amount / SUM(total_amount) OVER() AS amount_share_percent,
    100.0 * total_operations / SUM(total_operations) OVER() AS operations_share_percent
FROM age_stats
ORDER BY age_sort;

#3. Возрастные группы поквартально - средние показатели и %.
WITH RECURSIVE months AS(
	SELECT DATE('2015-06-01') AS month_start
    UNION ALL
    SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
    FROM months
    WHERE month_start < '2016-05-01'),
    
quarter_months AS(
	SELECT YEAR(month_start) AS report_year, QUARTER(month_start) AS report_quarter, COUNT(*) AS months_count
    FROM months
    GROUP BY YEAR(month_start), QUARTER(month_start)),
    
checks AS(
	SELECT t.id_client, t.id_check, DATE(t.date_new) AS check_date, SUM(t.sum_payment) AS check_amount
    FROM transactions t
    WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
    GROUP BY t.id_client, t.id_check, DATE(t.date_new)),
    
age_data AS(
	SELECT 
		c.id_client, 
        c.check_date, 
        c.check_amount,
        CASE
			WHEN cu.age IS NULL THEN 'No data'
            ELSE CONCAT(FLOOR(cu.age / 10) * 10, '-', FLOOR(cu.age / 10) * 10 + 9)
		END AS age_group,
        CASE 
			WHEN cu.age IS NULL THEN 999
            ELSE FLOOR(cu.age / 10) * 10
		END AS age_sort
	FROM checks c
    LEFT JOIN customers cu ON c.id_client = cu.id_client),
    
quarter_stats AS(
	SELECT 
		age_group, 
        age_sort, 
        YEAR(check_date) AS report_year, 
        QUARTER(check_date) AS report_quarter, 
        SUM(check_amount) AS quarter_amount,
        COUNT(*) AS quarter_operations,
        AVG(check_amount) AS average_check
	FROM age_data
    GROUP BY age_group, age_sort, YEAR(check_date), QUARTER(check_date)),
    
quarter_totals AS(
	SELECT report_year, report_quarter, SUM(quarter_amount) AS total_quarter_amount, SUM(quarter_operations) AS total_quarter_operations
    FROM quarter_stats
    GROUP BY report_year, report_quarter)
    
SELECT 
	qs.age_group,
	CONCAT(qs.report_year, '-Q', qs.report_quarter) AS quarter,
    qs.quarter_amount,
    qs.quarter_operations,
    qs.average_check,
    qs.quarter_amount / qm.months_count AS avg_monthly_amount,
    qs.quarter_operations / qm.months_count AS avg_monthly_operations,
    100.0 * qs.quarter_amount / NULLIF(qt.total_quarter_amount, 0) AS amount_share_percent,
    100.0 * qs.quarter_operations / NULLIF(qt.total_quarter_operations, 0) AS operations_share_percent
FROM quarter_stats qs
JOIN quarter_months qm
	ON qs.report_year = qm.report_year
    AND qs.report_quarter = qm.report_quarter
JOIN quarter_totals qt
	ON qs.report_year = qt.report_year
    AND qs.report_quarter = qt.report_quarter
ORDER BY qs.report_year, qs.report_quarter, qs.age_sort;