clickhouse_energyhub:
  target: dev
  outputs:
    dev:
      type: clickhouse
      host: ${clickhouse_host}
      port: ${clickhouse_port}
      database: ${clickhouse_database}
      user: ${clickhouse_user}
      password: ${clickhouse_password}
      schema: default
      threads: 4
      keepalives_idle: 0
      connect_timeout: 10
      send_receive_timeout: 300
      sync_request_timeout: 5
      
      # Настройки для ClickHouse
      clickhouse_settings:
        use_default_database: 1
        allow_experimental_object_type: 1
        allow_experimental_map_type: 1
        allow_experimental_low_cardinality_type: 1
        
      # Настройки для DQ проверок
      dq_settings:
        enable_dq_checks: true
        dq_schema: dq_checks
        dq_failure_threshold: 0.1
        
    prod:
      type: clickhouse
      host: ${clickhouse_host}
      port: ${clickhouse_port}
      database: ${clickhouse_database}
      user: ${clickhouse_user}
      password: ${clickhouse_password}
      schema: default
      threads: 8
      keepalives_idle: 0
      connect_timeout: 10
      send_receive_timeout: 300
      sync_request_timeout: 5
      
      # Настройки для ClickHouse
      clickhouse_settings:
        use_default_database: 1
        allow_experimental_object_type: 1
        allow_experimental_map_type: 1
        allow_experimental_low_cardinality_type: 1
        
      # Настройки для DQ проверок
      dq_settings:
        enable_dq_checks: true
        dq_schema: dq_checks
        dq_failure_threshold: 0.05  # Более строгие проверки для прода
        
    test:
      type: clickhouse
      host: ${clickhouse_host}
      port: ${clickhouse_port}
      database: ${clickhouse_database}
      user: ${clickhouse_user}
      password: ${clickhouse_password}
      schema: default
      threads: 2
      keepalives_idle: 0
      connect_timeout: 10
      send_receive_timeout: 300
      sync_request_timeout: 5
      
      # Настройки для ClickHouse
      clickhouse_settings:
        use_default_database: 1
        allow_experimental_object_type: 1
        allow_experimental_map_type: 1
        allow_experimental_low_cardinality_type: 1
        
      # Настройки для DQ проверок
      dq_settings:
        enable_dq_checks: true
        dq_schema: dq_checks
        dq_failure_threshold: 0.2  # Более мягкие проверки для тестов
