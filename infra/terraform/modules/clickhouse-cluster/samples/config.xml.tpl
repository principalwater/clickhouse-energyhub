<clickhouse replace="true">
    <logger>
        <level>debug</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>3</count>
    </logger>
    <display_name>${cluster_name} node ${node.shard} replica ${node.replica}</display_name>
    <listen_host>0.0.0.0</listen_host>
    <http_port>${node.http_port}</http_port>
    <tcp_port>${node.tcp_port}</tcp_port>

    <!-- optimization part start -->
    <merge_tree>
        <parts_to_throw_insert>300</parts_to_throw_insert>
        <min_rows_for_wide_part>0</min_rows_for_wide_part>
        <min_bytes_for_wide_part>0</min_bytes_for_wide_part>
        <write_ahead_log_max_bytes>1073741824</write_ahead_log_max_bytes> <!-- 1 GB -->
        <enable_mixed_granularity_parts>1</enable_mixed_granularity_parts>
    </merge_tree>
    <compression>
        <case>
            <min_part_size>1000000000</min_part_size>
            <method>zstd</method>
        </case>
        <case>
            <min_part_size>0</min_part_size>
            <method>lz4</method>
        </case>
    </compression>
    <query_log>
        <database>system</database>
        <table>query_log</table>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </query_log>
    <!-- optimization part end -->

    <user_directories>
        <users_xml>
            <path>users.xml</path>
        </users_xml>
        <local_directory>
            <path>/var/lib/clickhouse/access/</path>
        </local_directory>
    </user_directories>
    <distributed_ddl>
        <path>/clickhouse/task_queue/ddl</path>
    </distributed_ddl>
    <zookeeper>
%{~ for keeper in keepers ~}
        <node>
            <host>${keeper.host}</host>
            <port>${keeper.tcp_port}</port>
        </node>
%{~ endfor ~}
    </zookeeper>
    <macros>
        <shard>0${node.shard}</shard>
        <replica>0${node.replica}</replica>
    </macros>

</clickhouse>
