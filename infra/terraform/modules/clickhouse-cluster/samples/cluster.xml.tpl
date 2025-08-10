<!-- Cluster definition (remote servers) -->
<clickhouse>
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
</clickhouse>
