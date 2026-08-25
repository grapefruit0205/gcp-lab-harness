SELECT service.description, sku.description, location.country, cost, project.id,
       project.name, currency, currency_conversion_rate, usage.amount, usage.unit
FROM `__TABLE__` WHERE cost > 10
