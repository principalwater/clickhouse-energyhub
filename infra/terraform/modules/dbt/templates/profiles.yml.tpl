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
      schema: ${clickhouse_database}
      threads: 4
      keepalives_idle: 0
      connect_timeout: 10
      send_receive_timeout: 300
      sync_request_timeout: 5
      secure: false
      verify: false
      compression: false
      settings:
        use_numpy: true
        use_pandas_numpy: true
        
    prod:
      type: clickhouse
      host: ${clickhouse_host}
      port: ${clickhouse_port}
      database: ${clickhouse_database}
      user: ${clickhouse_user}
      password: ${clickhouse_password}
      schema: ${clickhouse_database}
      threads: 8
      keepalives_idle: 0
      connect_timeout: 10
      send_receive_timeout: 300
      sync_request_timeout: 5
      secure: false
      verify: false
      compression: false
      settings:
        use_numpy: true
        use_pandas_numpy: true
        
    test:
      type: clickhouse
      host: ${clickhouse_host}
      port: ${clickhouse_port}
      database: ${clickhouse_database}
      user: ${clickhouse_user}
      password: ${clickhouse_password}
      schema: ${clickhouse_database}
      threads: 2
      keepalives_idle: 0
      connect_timeout: 10
      send_receive_timeout: 300
      sync_request_timeout: 5
      secure: false
      verify: false
      compression: false
      settings:
        use_numpy: true
        use_pandas_numpy: true
