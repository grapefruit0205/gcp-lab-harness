SELECT service.description, ROUND(SUM(cost),2) AS total_cost
FROM `__TABLE__` GROUP BY service.description ORDER BY total_cost DESC
