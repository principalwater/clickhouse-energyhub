<?xml version="1.0"?>
<clickhouse replace="true">
    <profiles>
        <${super_user_name}>
            <!-- optimization part start -->
            <max_memory_usage>10000000000</max_memory_usage> <!-- 10 GB -->
            <max_threads>8</max_threads> <!-- не стоит завышать, как правило = числу vCPU или performance cores в Apple M-chips -->
            <max_block_size>65536</max_block_size> <!-- разумный дефолт -->
            <max_read_buffer_size>16777216</max_read_buffer_size> <!-- 16MB -->
            <max_bytes_before_external_group_by>2G</max_bytes_before_external_group_by>
            <max_bytes_before_external_sort>2G</max_bytes_before_external_sort>
            <load_balancing>random</load_balancing>
            <log_queries>1</log_queries>
            <!-- НЕ используем background_pool_size, он obsolete! -->
            <!-- Можно добавить prefer_localhost_replica=true для чтения с локальной ноды -->
            <prefer_localhost_replica>1</prefer_localhost_replica>
            <!-- optimization part end -->
        </${super_user_name}>
        <${bi_user_name}>
            <max_memory_usage>500000000</max_memory_usage>
            <readonly>2</readonly>
            <allow_ddl>0</allow_ddl>
            <load_balancing>random</load_balancing>
        </${bi_user_name}>
    </profiles>
    <users>
        <${super_user_name}>
            <password_sha256_hex>${super_user_password_sha256}</password_sha256_hex>
            <profile>${super_user_name}</profile>
            <networks>
                <ip>::1</ip> <!-- IPv6 localhost -->
                <ip>127.0.0.1</ip> <!-- IPv4 localhost -->
                <ip>::/0</ip>
            </networks>
            <quota>${super_user_name}</quota>
            <access_management>1</access_management>
            <named_collection_control>1</named_collection_control>
            <show_named_collections>1</show_named_collections>
            <show_named_collections_secrets>1</show_named_collections_secrets>
        </${super_user_name}>
        <${bi_user_name}>
            <password_sha256_hex>${bi_user_password_sha256}</password_sha256_hex>
            <profile>${bi_user_name}</profile>
            <networks>
                <ip>::/0</ip>
            </networks>
            <quota>${bi_user_name}</quota>
        </${bi_user_name}>
        <!-- Полностью удаляем стандартного пользователя default (без этого cluster-auth по TCP может ругаться на несуществующего default) -->
        <default remove="true"/>
    </users>
    <quotas>
        <${super_user_name}>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </${super_user_name}>
        <${bi_user_name}>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </${bi_user_name}>
    </quotas>
</clickhouse>
