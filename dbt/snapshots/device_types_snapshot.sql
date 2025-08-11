{% snapshot device_types_snapshot %}

{{
    config(
      target_schema='snapshots',
      strategy='check',
      check_cols=['device_type_name', 'description', 'power_rating_min', 'power_rating_max', 'voltage_standard', 'is_active'],
      unique_key='device_type_id',
    )
}}

select * from {{ source('raw', 'device_types') }}

{% endsnapshot %}
