def model(dbt, session):
    dbt.config(materialized="table")

    orders_df = dbt.ref("fct_orders")
    customers_df = dbt.ref("dim_customers")

    merged = orders_df.join(customers_df, on="customer_id", how="left")

    merged = merged.withColumn(
        "revenue_with_tax",
        merged["total_amount"] * (1 + merged["tax_rate"])
    ).withColumn(
        "is_high_value",
        merged["total_amount"] > 200
    ).withColumn(
        "margin",
        merged["total_amount"] - merged["acquisition_cost"]
    )

    result = merged.select(
        "customer_id", "campaign_id", "product_id", "email",
        "ordered_at", "total_amount", "tax_rate", "revenue_with_tax",
        "is_high_value", "margin", "lifetime_revenue", "valid_from", "valid_to"
    )

    return result