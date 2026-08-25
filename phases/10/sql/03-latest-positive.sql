SELECT service.description, sku.description, location.country, cost, project.id,
       project.name, currency, currency_conversion_rate, usage.amount, usage.unit
FROM `__TABLE__` WHERE Cost > 0 ORDER BY usage_end_time DESC LIMIT 100
