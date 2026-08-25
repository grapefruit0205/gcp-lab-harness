SELECT usage.unit, COUNT(*) AS billing_records
FROM `__TABLE__` WHERE cost > 0 GROUP BY usage.unit ORDER BY billing_records DESC
