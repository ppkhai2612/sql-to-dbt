## SQL to dbt: Get Started

dbt = SQL + "superpowers." (Jinja templating, dbt commands, and data modeling techniques)

dbt handles the T in ETL (Extract, Transform, Load). Many papers credit dbt as a key reason for the shift from ETL to ELT, where transformations happen after loading.

### SQL Vs. dbt

Your SQL might look like this:

```sql
SELECT customer_id, 
       SUM(order_amount) as total_spent 
FROM (
        SELECT table_1.column1, 
                table_b.column2, 
                table_a.column3,... 
        FROM table_a 
        JOIN table_b 
        ON table_a.id = table_b.id
    ) as raw_orders 
WHERE order_date >= '2024-01-01' 
GROUP BY customer_id; 
```

In dbt, the same logic becomes:

```sql
SELECT customer_id, 
       SUM(order_amount) as total_spent 
FROM {{ ref('staging_orders') }} 
WHERE order_date >= '2024-01-01' 
GROUP BY customer_id 
```

In the first example, `raw_orders` is a `VIEW` in your database with some logic, probably created by other analyses or backend processes.

In the second example, the `{{ ref('staging_orders') }}` handles dependency management for you.

### What Concepts Does dbt Bring To The Table?

- **Modularity: Break The Problem Into Pieces**

    - Old way: SQL files scattered across your database. You open a schema and see a list of TABLEs and VIEWs with no context or order.
    - dbt way: Everything lives in a structured project with organized folders.

- **No More "Table Not Found" Panic Attacks**

    - dbt adds the `ref()` macro, which builds a dependency graph. dbt runs everything in the right order, every time.

- **Fast Testing And Deployment**

    - dbt has built-in tests to catch nulls, duplicates, and broken relationships before production.
    - You can even come up with your own custom checks to test edge cases for your particular business needs.
    - You can run these tests during development and deployment to keep everything on track.

- **Version Control With Git**

    - One big problem in database development is tracking changes over time. Without version control, tracing issues is hard.
    - dbt solves this by being repository-driven, so you know exactly when changes happened and rollback without all the struggle of figuring out what happened when.

- **Macros With Jinja Templating**

    - Jinja lets you write dynamic SQL that adapts based on conditions, variables, and logic.
    - These are dbt macros ways to reuse code without rewriting it.
    - If you need variables or dynamic logic, you set them inside a macro. The code then behaves as you want without complex edge-case handling. For example:

        ```sql
        {% set important_date = '2024-01-01' %} 

        SELECT * 
        FROM {{ ref('orders') }} 
        WHERE order_date >= '{{ important_date }}' 
        {% if var('include_refunds', false) %} 
            AND status != 'refunded' 
        {% endif %}
        ```
    
    - At runtime, this compiles to:

        ```sql
        SELECT * 
        FROM (
            SELECT columns 
            FROM orders
            ) 
        WHERE order_date >= '2024-01-01' 
        ```

    - `important_date` is a static value. `include_refunds` defaults to `false`, so the extra status is not considered during compilation.


## SQL to dbt: dbt Starter Project

### Setup dbt project

1. Run `dbt init` to create the project structure.
2. Install your dbt adapter (PostgreSQL, BigQuery, Databricks, Snowflake, etc) using `pip install dbt-duckdb`
3. Configure your `profiles.yml` with your data warehouse details.
4. Set up `dbt_project.yml` with your project structure and materialization types.
5. Add packages to `packages.yml` if needed.

### dbt Concepts (Sources, Models, Seeds, Snapshots)

- **Sources** define external data tables in your warehouse that dbt will reference but not manage directly. They act as the entry point for raw data coming from your ETL pipelines or external systems.
- **Models** are SQL files that transform your data using SELECT statements, creating new tables or views in your warehouse. They're the core building blocks where your business logic lives.
- **Seeds** are CSV files stored in your dbt project that get loaded into your warehouse as tables. They're perfect for small reference datasets like lookup tables or configuration data.
- **Snapshots** capture point-in-time versions of your data to track how records change over time. They're essential for slowly changing dimensions and historical analysis.

### YAML Files

dbt uses YAML as the backbone for configuration, and it's everywhere in your project. You can configure your project, sources, schemas, tests, and even docs. For example:
- **Project config** (`dbt_project.yml`): Controls how everything builds

    ```yaml
    models: 
        my_project: 
            staging: +materialized: view 
    ```

- **Schema & Test definitions**:

    ```yaml
    models:
        - name: stg_customers 
          description: "Cleaned customer data" 
          columns: 
            - name: customer_id 
              description: "Unique identifier" 
              tests: - unique - not_null 
    ```

### Materializations

They define how dbt builds your models in the database. Think of them as different ways to store your SQL results:
- **View**: The classic SQL VIEW. Fast to build but slower to query. Perfect for staging models where you're just cleaning data.
- **Table**: The classic SQL TABLE. Slower to build but faster to query. Great for marts that get queried frequently.
- **Incremental**: Processes only new or changed records since the last run to avoid full reloads.
- **Ephemeral**: Instead of writing CTEs to make code modular, use this as a helper; it won't be stored in the database.

You can set them at the top of your model file using `{{ config(materialized='table') }}` or in `dbt_project.yml `

There's no right or wrong approach here; it depends on your database's capacity and your use cases.

By default, everything will be a `VIEW` unless you configure another materialization type.

### Jinja Syntax (dbt Macros)

Macros lets you reuse code whenever you don't want to repeat yourself or want to keep your code clean.

The most common one is `ref()`, which references sources or other models instead of copying SQL snippets:

```sql
FROM {{ ref('stg_customers') }} LEFT JOIN {{ ref('stg_orders') }} 
```

The `{{ ref('stg_customers') }}` syntax creates dependencies. This way, dbt knows which models to run first.

But it gets better if you want to avoid repeating code multiple times. Here's a common use case:

```sql
{% set payment_methods = ["bank_transfer", "credit_card", "gift_card"] %}

select
    order_id,
    {% for payment_method in payment_methods %}
    sum(case when payment_method = '{{payment_method}}' then amount end) as {{payment_method}}_amount,
    {% endfor %}
    sum(amount) as total_amount
from app_data.payments
group by 1
```

### dbt commands

dbt command list for the most important tasks:

```bash
# Run all models
dbt run

# Run specific model
dbt run --select stg_campaigns

# Run models and upstream (+model) or downstream (model+) dependencies
dbt run --select stg_customers+

# Test data quality
dbt test

# Run all models and tests
dbt build
```

## SQL to dbt: Medallion Architecture

## SQL to dbt: Testing & Quality

## SQL to dbt: Macros & Code Reusability

## SQL to dbt: Slowly Changing Dimensions