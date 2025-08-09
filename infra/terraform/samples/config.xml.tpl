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
<remote_servers>
  <${cluster_name}>
%{ for shard in remote_servers ~}
    <shard>
    %{ for replica in shard.replicas ~}
      <replica>
        <host>${replica.host}</host>
        <port>${replica.port}</port>
        <user>${super_user_name}</user>
        <password>${super_user_password}</password>
      </replica>
    %{ endfor ~}
    </shard>
%{ endfor ~}
  </${cluster_name}>
</remote_servers>
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

    <storage_configuration>
        <disks>
            %{ if storage_type == "s3_ssd" ~}
            <s3_storage_disk>
                <type>s3</type>
                <endpoint>http://minio-local-storage:${local_minio_port}/clickhouse-storage-bucket/</endpoint>
                <access_key_id>${minio_root_user}</access_key_id>
                <secret_access_key>${minio_root_password}</secret_access_key>
                <metadata_path>/var/lib/clickhouse/disks/s3_storage_disk/</metadata_path>
            </s3_storage_disk>
            <s3_cache>
                <type>cache</type>
                <disk>s3_storage_disk</disk>
                <path>/var/lib/clickhouse/disks/s3_cache/</path>
                <max_size>10Gi</max_size>
            </s3_cache>
            %{ endif ~}
            <backups>
                <type>local</type>
                <path>/tmp/backups/</path>
            </backups>
        </disks>
        <policies>
            %{ if storage_type == "s3_ssd" ~}
            <s3_main>
                <volumes>
                    <main>
                        <disk>s3_cache</disk>
                    </main>
                </volumes>
            </s3_main>
            %{ endif ~}
            <default>
                 <volumes>
                    <main>
                        <disk>default</disk>
                    </main>
                </volumes>
            </default>
        </policies>
    </storage_configuration>
    <backups>
        <allowed_disk>backups</allowed_disk>
        <allowed_path>/tmp/backups/</allowed_path>
    </backups>
</clickhouse>
