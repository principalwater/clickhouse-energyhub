# ClickHouseInstallation Custom Resource Definition
# Deploys a sharded and replicated ClickHouse cluster.
apiVersion: "clickhouse.altinity.com/v1"
kind: "ClickHouseInstallation"
metadata:
  name: "energyhub-cluster"
  namespace: "${k8s_namespace}"
spec:
  # Defaults applied to all components unless overridden
  defaults:
    templates:
      podTemplate: default-pod-template

  configuration:
    # Zookeeper/Keeper is implicitly managed by the operator for this layout
    
    # Cluster definition
    clusters:
      - name: "dwh_prod"
        layout:
          shardsCount: 2
          replicasCount: 2
        # Keeper is also implicitly created for sharded clusters

    # User and profile definitions
    users:
      - name: "${clickhouse_user}"
        password: "${clickhouse_password}"
        networks:
          - ip: "::/0"
        profile: "default"
    
    # Cluster-wide settings
    settings:
      max_concurrent_queries: 100

    # Backup configuration pointing to our MinIO
    backups:
      - name: "s3_backups"
        type: "s3"
        s3:
          endpoint: "${s3_backup_endpoint}"
          bucket: "${s3_backup_bucket}"
          accessKeyID:
            valueFrom:
              secretKeyRef:
                name: "${s3_secret_name}"
                key: "accessKeyId"
          secretAccessKey:
            valueFrom:
              secretKeyRef:
                name: "${s3_secret_name}"
                key: "secretAccessKey"
  
  # Reusable templates
  templates:
    # Pod Template defines the pod specification for ClickHouse nodes
    podTemplates:
      - name: default-pod-template
        spec:
          # Specify the container image and mount the data volume
          containers:
            - name: clickhouse
              image: "${clickhouse_image}"
              volumeMounts:
                - name: data-storage-volume
                  mountPath: /var/lib/clickhouse
          
          # Define the hostPath volume that will be mounted
          volumes:
            - name: data-storage-volume
              hostPath:
                # This path must exist on the Kubernetes node (the Mac Studio in this case).
                # The operator will create a unique subdirectory for each pod within this path.
                path: "${local_ssd_data_path}"
                type: DirectoryOrCreate

    # --- Storage Notes ---
    # The 'hostPath' approach used here is simple and works well for single-node Kubernetes clusters
    # (like Docker Desktop or Minikube) as it directly uses a folder on the host machine.
    #
    # For a more robust, multi-node Kubernetes setup, the recommended approach is to use a
    # 'local' PersistentVolume (PV) with a dedicated StorageClass. This requires more setup,
    # including manually creating PVs for the disks on each node, but provides better
    # scheduling and management by Kubernetes.
    #
    # This implementation prioritizes ease of setup for the specified single-host environment.
