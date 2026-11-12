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

Medallion architecture might look like a nice way of organizing folders, but it's more than that.

You create logical flows of data transformations that makes sense to your team and scales with your business.

The further you go up, the cleaner and complexity-free the project should be.

You can break down business logic into useful transformed assets from source to final analytics ready assets.

### Bronze Layer: The Foundation

Your `sources.yml` file defines the contract between dbt and raw data:

```yaml
sources:
  - name: synthetic_data
    description: "Synthetic marketing and analytics data"
    schema: main
    tables:
      - name: campaigns
      - name: ads
      - name: sessions
      - name: conversions
      - name: journey_events
```

This is your Bronze layer raw data with minimal transformation.

The `source()` function creates dependency management that everything else builds upon. No business logic here, just clean access to your raw tables.

You can go fancy here and test things you want to validate from the backend tables even before transforming anything.

### Silver Layer: Business Logic

From a dbt perspective, what comes after this Bronze layer are known as staging models.

Clean raw data without adding business logic. Look at `stg_campaigns.sql`:

```sql
select
    campaign_id,
    name as campaign_name,  -- Simple renaming
    channel,
    ...
from {{ source('synthetic_data', 'campaigns') }}
```

What’s NOT here: no aggregations, no complex `CASE` statements, no joins. Staging models standardize column names, handle data types, and ensure consistency.

Each staging model represents should represent one source table for consistency, cleaned and ready for business logic.

This separation makes debugging infinitely easier when things break.

Then we start going fancy and apply some logic into models with dbt intermediate layer.

Intermediate models solve specific business problems.Each model has a clear purpose and can be tested independently.

You can see that joins are more common on this stage and logics are introduced such as `ctr_performance` example.

Intermediate models combine staging models with business rules. Look at `int_campaign_ads.sql`:

```sql
select
    -- columns here...
    case
        when ads.ctr > 0.02 then 'high'
        when ads.ctr > 0.01 then 'medium'
        else 'low'
    end as ctr_performance,
    current_timestamp as date_transformed
from {{ ref('stg_campaigns') }} as campaigns
left join {{ ref('stg_ads') }} as ads 
    on campaigns.campaign_id = ads.campaign_id
```

### Gold Layer: Analytics Ready Assets

Marts are your final product—tables that business users actually query. Look at `campaign_performance.sql`:

```sql
select
    -- columns here...

    -- Aggregated metrics
    count(distinct campaign_ads.ad_id) as total_ads,
    sum(campaign_ads.impressions) as total_impressions,
    sum(campaign_ads.clicks) as total_clicks,
    avg(campaign_ads.ctr) as avg_ctr,
    sum(campaign_ads.ad_spend) as total_ad_spend,
    avg(campaign_ads.avg_cpc) as avg_cpc,

    case
        when sum(campaign_ads.ad_spend) > 0 then sum(conversions.revenue) / sum(campaign_ads.ad_spend)
        else null
    end as roas,

    current_timestamp as date_transformed
from {{ ref('int_campaign_ads') }} as campaign_ads
left join {{ ref('int_visitor_sessions') }} as visitor_sessions 
    on campaign_ads.campaign_id = visitor_sessions.campaign_id
left join {{ ref('int_conversions') }} as conversions 
    on campaign_ads.campaign_id = conversions.campaign_id
group by 
    campaign_ads.campaign_id,
    campaign_ads.campaign_name,
    ...
```

Campaign managers care about ROAS, conversion rates, and spend efficiency, this is where you get those decision drivers exposed to be used for BI workflows.

### Why This Structure Actually Works

- **Separation of Concerns**: Each layer has a clear purpose. Staging cleans, intermediate adds logic, marts serve business needs.
- **Testability**: You can test data quality at each layer. Also you can decide if you enforced the tests as preventive contracts or as informative results.
- **Maintainability**: it's easier to trace where to add or edit models if you have a well structured project.
- **Performance**: Configure materialization by purpose. Decide if you need TABLE, VIEW or incremental approaches depending on the query use cases.

### Common Medallion Mistakes

- Not every transformation needs an intermediate model. Sometimes staging -> marts is perfectly fine. - Keep it flexible and don't overely if your gut and context asks for something else!
- Keep staging layer simple. Complex `CASE` statements belong in intermediate models.
- Regarding marts, if business users don't query it directly, it probably belongs in intermediate.
- Poor naming conventions like `tmp_stuff_v2` don't help anyone.

## SQL to dbt: Testing & Quality

### Data Integrity vs Data Quality

Data integrity ensures that data is accurate, complete, consistent, and secure throughout its lifecycle. Data quality measures how well data meets the criteria for its intended purpose.

You need both, but they solve different problems.

Nice questions to ask yourself:
- Can you run your analysis without this data? If no, **integrity**
- Does wrong data lead to bad decisions? If yes, **quality**

The best approach:
1. Start with integrity using constraints to prevent system failures.
2. Add quality tests for business-critical calculations and relationships.

Work closely with whoever produces the raw data: backend teams, backoffice users, and others. They’ll help you understand what must never fail and what needs testing to avoid erratic decisions.

---

> The Multi-Layer Defense Strategy

---

### Data Contracts

Data contracts validate during model compilation, failing fast if schema violations occur. Here's your staging model definition:

```yaml
models:
  - name: stg_campaigns
    columns:
      - name: campaign_id
        data_type: string
        constraints:
          - type: not_null
          - type: primary_key
          - type: unique
      - name: budget
        data_type: double
        constraints:
          - type: check
            expression: "budget > 0"
      ...
```

Contracts stop bad data from entering your transformation pipeline. If `campaign_id` isn't unique, a column's data type doesn't match, or budget is negative, the model won't compile. This catches schema problems before they propagate downstream.

More info on [dbt docs](https://docs.getdbt.com/reference/resource-configs/contract?version=2)

### Generic Tests

dbt ships with four generic data tests already defined: `unique`, `not_null`, `accepted_values` and `relationships`.

But you can customise something for your use case. In this case, we have multiple columns that can't be negative, here's a budget numeric validation test:

```sql
{% test positive_numeric(model, column_name) %}

select *
from {{ model }}
where {{ column_name }} is not null
    and {{ column_name }} <= 0

{% endtest %}
```

Apply these tests via YAML configuration on the column level:

```yaml
columns:
  - name: conversion_type
    data_tests:
      - accpepted_values:
          arguments:
            values: ["purchase", "lead", "signup", "appointment", "download"]
  - name: conversion_value
    data_tests:
      - positive_numeric
```

Generic tests are reusable across models and catch universal data quality issues.

More info on [dbt docs](https://docs.getdbt.com/docs/build/data-tests?version=2#generic-data-tests)

### Singular Tests

Singular tests validate specific business rules that generic tests can't handle. Here's a campaign date logic test:

```sql
-- Test that campaign start_date is always <= end_date
select
    campaign_id,
    capaign_name,
    start_date,
    end_date
from {{ ref('stg_campaigns') }}
where start_date > end_date
```

These tests catch logical inconsistencies specific to marketing analytics that only domain experts would know to check.

More info on [dbt docs](https://docs.getdbt.com/docs/build/data-tests?version=2#singular-data-tests).

### dbt-expectations

You can use it for similar use cases as mentioned before, but its really good at statistical validation or anomaly detection:

```yaml
columns:
  - name: budget
    data_tests:
      - dbt_expectations.expect_column_values_to_be_between:
          arguments:
            min_value: 1000
            max_value: 10000000
```

This provides the statistical rigor of Great Expectations within your dbt workflow, catching anomalies that simple range checks might miss.

More info on [dbt_expectations](https://hub.getdbt.com/metaplane/dbt_expectations/latest/)

### Execution Flow

Run `dbt build` or `dbt run` (with contracts enforced) to make all the tests happen:
1. **Contract Validation**: Ensures schema compliance during model compilation
2. **Model Creation**: Builds staging views with enforced contracts
3. **Test Execution**: Runs all configured tests (generic, singular, and expectations)
4. **Failure Handling**: Stops the pipeline or warns on critical test failures

More info on [dbt test docs](../dbt/tests/README.md#test-execution-flow)

### What Does A Test Failure Means

Test failures warn you when something's wrong, and how serious they are depends on the test type. Depending on the context, tests require different responses and involve different stakeholders.

Here's how to handle them:
- **Contract**: Fix schema issues at the source or adjust model expectations
- **Generic**: Investigate data quality issues in upstream systems
- **Singular**: Business logic violations require domain expert review
- **Expectations**: Statistical anomalies may indicate data pipeline issues

## SQL to dbt: Macros & Code Reusability

The repo keeps `int_first_touchpoints.sql` as a raw SQL view alongside `eph_first_touchpoints.sql`, which does the same thing with a macro. Side by side:

Raw SQL - `int_first_touchpoints.sql`:

```sql
select
    visitor_id,
    first_value(campaign_id) over (partition by visitor_id order by event_timestamp) as first_campaign_id,
    first_value(event_channel) over (partition by visitor_id order by event_timestamp) as first_event_channel,
    first_value(campaign_name) over (partition by visitor_id order by event_timestamp) as first_campaign_name,
    first_value(ad_name) over (partition by visitor_id order by event_timestamp) as first_ad_name,
    first_value(ad_id) over (partition by visitor_id order by event_timestamp) as first_ad_id,
    first_value(event_timestamp) over (partition by visitor_id order by event_timestamp) as first_event_timestamp
from {{ ref('int_journey_events') }}
qualify row_number() over (partition by visitor_id order by event_timestamp) = 1
```

Macro version (`eph_first_touchpoints.sql`):

```sql
{{ get_touchpoint_attribution(
    source_table=ref('int_journey_events'),
    attribution_type='first'
) }}
```

Same output. Six repeated `first_value(...)` calls reduced to a single macro invocation. And when you need last-touch attribution, you change `attribution_type='last'`.

The project has five macros across two files. Four utility macros live in `classify_performance_tier.sql`, and the attribution macro stands alone.

## SQL to dbt: Slowly Changing Dimensions

In the project, there are two clear use cases that actually need historical tracking.
- **Campaign performance evolution**: ROAS, conversion rates, and budget utilization change daily. Marketing managers need performance trends over time, not just today’s snapshot.
- **Visitor segment transitions**: Customers evolve from prospects to VIP buyers. Understanding these lifecycle transitions helps predict behavior and optimize targeting.

dbt snapshots detect changes in two ways. Your choice depends on what triggers historical tracking.

### Timestamp: When Records Change

`snap_campaign_performance.sql` uses the timestamp strategy. Every time the source data updates, dbt captures a new historical record:

```sql
{% snapshot snap_campaign_performance %}
{{
    config(
        target_schema='snapshots',
        strategy='timestamp',
        unique_key='campaign_id',
        updated_at='date_transformed',
        invalidate_hard_deletes=true
    )
}}

select
    campaign_id,
    campaign_name,
    ...
    case 
        when roas >= 4.0 then 'excellent'
        when roas >= 2.0 then 'good'
        when roas >= 1.0 then 'break_even'
        else 'poor'
    end as roas_tier,
    date_transformed,
from {{ ref('campaign_performance') }}

{% endsnapshot %}
```

Timestamp strategy works when you have a reliable `updated_at` column and want to capture every change. Campaign metrics move daily. This is the right fit.

### Check: When Specific Columns Change

`snap_visitor_segments.sql` uses the check strategy. dbt only creates a new record when specific columns actually change:

```sql
{% snapshot snap_visitor_segments %}
{{
  config(
    target_schema='snapshots',
    strategy='check',
    unique_key='visitor_id',
    check_cols=[
        'visitor_frequency_segment',
        'visitor_value_segment', 
        'visitor_engagement_segment',
        'total_sessions',
        'total_conversions',
        'total_revenue'
    ],
    invalidate_hard_deletes=true
  )
}}

select
    visitor_id,
    ...
    case 
        when total_conversions = 0 then 'prospect'
        when total_conversions = 1 and total_revenue < 100 then 'new_customer'
        when total_conversions > 1 and total_revenue < 500 then 'repeat_customer'
        when total_conversions > 1 and total_revenue >= 500 then 'vip_customer'
        else 'unknown'
    end as lifecycle_stage,
    date_transformed,
from  {{ ref('visitor_journey') }}

{% endsnapshot %}
```

Check strategy is the right call when you care about specific attribute transitions, not every data update.

If a visitor’s page view count increases but their segment stays the same, no new snapshot record.

The strategy-to-use-case mapping is the core lesson: **timestamp** for metrics that change frequently and where every change matters, **check** for categorical shifts where you’re tracking transitions.

### Querying Historical Data

Snapshots create three special columns: `dbt_valid_from` (when this version became active), `dbt_valid_to` (when it was superseded, NULL for current), and `dbt_updated_at` (when dbt processed it).
- **Current state** - get the latest version of each record:

    ```sql
    select *
    from snapshots.snap_campaign_performance
    where dbt_valid_to is null
    ```

- **Point-in-time** - what did the data look like on a specific date:

    ```sql
    select *
    from snapshots.snap_campaign_performance
    where ‘2024-01-15’ >= dbt_valid_from
    and (’2024-01-15’ < dbt_valid_to or dbt_valid_to is null)
    ```

- **Trend analysis** - track changes over time with window functions:

    ```sql
    select
        campaign_id,
        campaign_name,
        dbt_valid_from,
        roas,
        roas_tier,
        lag(roas) over (partition by campaign_id order by dbt_valid_from) as previous_roas
    from snapshots.snap_campaign_performance
    order by campaign_id, dbt_valid_from
    ```

These three patterns cover most analytical needs. Current state for dashboards, point-in-time for compliance, trend analysis for optimization decisions.

### The Costs and When to Skip It

SCD2 is not free. Before snapshotting everything, understand the trade-offs:
- **Storage**: A campaign that changes daily creates 365 records per year. Multiply by thousands of campaigns.
- **Query complexity**: Historical queries require date filters and window functions. Not every analyst is comfortable with these.
- **Processing time**: Every `dbt snapshot` run compares current data against all historical records.
- **Maintenance**: Snapshot schemas need monitoring. The repo includes a `snapshots/schema.yml` with column descriptions and `not_null` tests on key identifiers. Treat snapshot documentation the same as any other model.

**You probably don’t need SCD2 if** your analysis only looks at current state, historical changes happen infrequently, or storage costs outweigh analytical value.

**You definitely need SCD2** if compliance requires audit trails, business decisions depend on trend analysis, or customer lifecycle analysis drives strategy.

Mitigation helps: use `invalidate_hard_deletes=true` to handle deleted source records, consider archiving old snapshots after defined retention periods, and create mart models that pre-calculate common historical analyses.