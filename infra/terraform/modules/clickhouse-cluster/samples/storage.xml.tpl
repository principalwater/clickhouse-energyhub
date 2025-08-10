<!-- Storage and backup settings -->
<clickhouse>
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
