SELECT billing_account_id, project.id, project.name, service.description, currency,
       currency_conversion_rate, cost, usage.amount, usage.pricing_unit
FROM `__TABLE__`
