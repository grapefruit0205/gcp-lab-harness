SELECT service.description, COUNT(*) AS billing_records
FROM `__TABLE__` GROUP BY service.description ORDER BY billing_records DESC
