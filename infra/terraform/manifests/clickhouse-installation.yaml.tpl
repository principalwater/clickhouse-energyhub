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
    # Cluster definition
    clusters:
      - name: "dwh-prod"
        layout:
          shardsCount: 2
          replicasCount: 2

    # User and profile definitions
    users:
      "${clickhouse_user}": # User name is the key
        password: "${clickhouse_password}"
        networks:
          - ip: "::/0"
        profile: "default"

    # Definition of storage disks for ClickHouse data
    disks:
      - name: "data-storage-volume"
        type: "hostPath"
        hostPath:
          path: "${local_ssd_data_path}"
          type: "DirectoryOrCreate"
    
    # Cluster-wide settings
    settings:
      max_concurrent_queries: 100

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
          
          # The volume definition is still required here.
          # The operator will populate the hostPath from the `spec.configuration.disks` section.
          volumes:
            - name: data-storage-volume
              hostPath:
                path: "" # This will be populated by the operator

    # --- Storage Notes ---
    # The 'hostPath' approach used here is simple and works well for single-node Kubernetes clusters
    # (like Docker Desktop or Minikube) as it directly uses a folder on the host machine.
