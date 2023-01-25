locals {
  # list of partitions
  partition_names   = keys(try(var.compute_plane, {}))
  default_partition = try(var.control_plane.default_partition, "")

  # Node selector for control plane
  control_plane_node_selector        = try(var.control_plane.node_selector, {})
  control_plane_node_selector_keys   = keys(local.control_plane_node_selector)
  control_plane_node_selector_values = values(local.control_plane_node_selector)

  # Node selector for admin GUI
  admin_gui_node_selector        = try(var.admin_gui.node_selector, {})
  admin_gui_node_selector_keys   = keys(local.admin_gui_node_selector)
  admin_gui_node_selector_values = values(local.admin_gui_node_selector)

  # Node selector for compute plane
  compute_plane_node_selector        = { for partition, compute_plane in var.compute_plane : partition => try(compute_plane.node_selector, {}) }
  compute_plane_node_selector_keys   = { for partition in local.partition_names : partition => keys(local.compute_plane_node_selector[partition]) }
  compute_plane_node_selector_values = { for partition in local.partition_names : partition => values(local.compute_plane_node_selector[partition]) }

  # Node selector for pod to insert partitions IDs in database
  job_partitions_in_database_node_selector        = try(var.job_partitions_in_database.node_selector, {})
  job_partitions_in_database_node_selector_keys   = keys(local.job_partitions_in_database_node_selector)
  job_partitions_in_database_node_selector_values = values(local.job_partitions_in_database_node_selector)

  # Node selector for pod to insert authentication data in database
  job_authentication_in_database_node_selector        = try(var.authentication.node_selector, {})
  job_authentication_in_database_node_selector_keys   = keys(local.job_authentication_in_database_node_selector)
  job_authentication_in_database_node_selector_values = values(local.job_authentication_in_database_node_selector)

  # Authentication
  authentication_require_authentication = try(var.authentication.require_authentication, false)
  authentication_require_authorization  = try(var.authentication.require_authorization, false)
  authentication_datafile               = try(var.authentication.authentication_datafile, "")

  # Annotations
  control_plane_annotations              = try(var.control_plane.annotations, {})
  compute_plane_annotations              = { for partition in local.partition_names : partition => try(var.compute_plane[partition].annotations, {}) }
  ingress_annotations                    = try(var.ingress.annotations, {})
  job_partitions_in_database_annotations = try(var.job_partitions_in_database.annotations, {})

  # Fluent-bit
  fluent_bit_is_daemonset      = try(var.monitoring.fluent_bit.is_daemonset, false)
  fluent_bit_container_name    = try(var.monitoring.fluent_bit.container_name.fluent-bit, "fluent-bit")
  fluent_bit_image             = try(var.monitoring.fluent_bit.image, "fluent/fluent-bit")
  fluent_bit_tag               = try(var.monitoring.fluent_bit.tag, "1.7.2")
  fluent_bit_envvars_configmap = try(var.monitoring.fluent_bit.configmaps.envvars, "")
  fluent_bit_configmap         = try(var.monitoring.fluent_bit.configmaps.config, "")

  # Seq
  seq_host    = try(var.monitoring.seq.host, "")
  seq_port    = try(var.monitoring.seq.port, "")
  seq_url     = try(var.monitoring.seq.url, "")
  seq_web_url = try(var.monitoring.seq.web_url, "")

  # Grafana
  grafana_host = try(var.monitoring.grafana.host, "")
  grafana_port = try(var.monitoring.grafana.port, "")
  grafana_url  = try(var.monitoring.grafana.url, "")

  # Metrics exporter
  metrics_exporter_name      = try(var.monitoring.metrics_exporter.name, "")
  metrics_exporter_namespace = try(var.monitoring.metrics_exporter.namespace, "")

  # Partition metrics exporter
  partition_metrics_exporter_name      = try(var.monitoring.partition_metrics_exporter.name, "")
  partition_metrics_exporter_namespace = try(var.monitoring.partition_metrics_exporter.namespace, "")

  # ingress ports
  ingress_ports = var.ingress != null ? distinct(compact([var.ingress.http_port, var.ingress.grpc_port])) : []

  # Storage secrets
  secrets = {
    activemq = {
      certificates_secret = "activemq-user-certificates"
      credentials_secret  = "activemq-user"
      endpoints_secret    = "activemq-endpoints"
      ca_filename         = "/amqp/chain.pem"
    }
    mongodb = {
      certificates_secret = "mongodb-user-certificates"
      credentials_secret  = "mongodb-user"
      endpoints_secret    = "mongodb-endpoints"
      ca_filename         = "/mongodb/chain.pem"
    }
    redis = {
      certificates_secret = "redis-user-certificates"
      credentials_secret  = "redis-user"
      endpoints_secret    = "redis-endpoints"
      ca_filename         = "/redis/chain.pem"
    }
    shared_storage_secret = "shared-storage-endpoints"
  }

  # Shared storage
  file_storage_type       = lower(data.kubernetes_secret.shared_storage.data.file_storage_type)
  check_file_storage_type = local.file_storage_type == "s3" ? "S3" : "FS"
  file_storage_endpoints = local.check_file_storage_type == "S3" ? {
    S3Storage__ServiceURL      = data.kubernetes_secret.shared_storage.data.service_url
    S3Storage__AccessKeyId     = data.kubernetes_secret.shared_storage.data.access_key_id
    S3Storage__SecretAccessKey = data.kubernetes_secret.shared_storage.data.secret_access_key
    S3Storage__BucketName      = data.kubernetes_secret.shared_storage.data.name
  } : {}

  # Credentials
  credentials = {
    Amqp__User = {
      key  = "username"
      name = local.secrets.activemq.credentials_secret
    }
    Amqp__Password = {
      key  = "password"
      name = local.secrets.activemq.credentials_secret
    }
    Amqp__Host = {
      key  = "host"
      name = local.secrets.activemq.endpoints_secret
    }
    Amqp__Port = {
      key  = "port"
      name = local.secrets.activemq.endpoints_secret
    }
    Redis__User = {
      key  = "username"
      name = local.secrets.redis.credentials_secret
    }
    Redis__Password = {
      key  = "password"
      name = local.secrets.redis.credentials_secret
    }
    Redis__EndpointUrl = {
      key  = "url"
      name = local.secrets.redis.endpoints_secret
    }
    MongoDB__User = {
      key  = "username"
      name = local.secrets.mongodb.credentials_secret
    }
    MongoDB__Password = {
      key  = "password"
      name = local.secrets.mongodb.credentials_secret
    }
    MongoDB__Host = {
      key  = "host"
      name = local.secrets.mongodb.endpoints_secret
    }
    MongoDB__Port = {
      key  = "port"
      name = local.secrets.mongodb.endpoints_secret
    }
  }

  # Credentials
  database_credentials = {
    MongoDB_User = {
      key  = "username"
      name = local.secrets.mongodb.credentials_secret
    }
    MongoDB_Password = {
      key  = "password"
      name = local.secrets.mongodb.credentials_secret
    }
    MongoDB_Host = {
      key  = "host"
      name = local.secrets.mongodb.endpoints_secret
    }
    MongoDB_Port = {
      key  = "port"
      name = local.secrets.mongodb.endpoints_secret
    }
  }

  # Certificates
  certificates = {
    activemq = {
      name        = "activemq-secret-volume"
      mount_path  = "/amqp"
      secret_name = local.secrets.activemq.certificates_secret
    }
    redis = {
      name        = "redis-secret-volume"
      mount_path  = "/redis"
      secret_name = local.secrets.redis.certificates_secret
    }
    mongodb = {
      name        = "mongodb-secret-volume"
      mount_path  = "/mongodb"
      secret_name = local.secrets.mongodb.certificates_secret
    }
  }

  # Fluent-bit volumes
  # Please don't change below read-only permissions
  fluent_bit_volumes = {
    fluentbitstate = {
      mount_path = "/var/fluent-bit/state"
      read_only  = false
      type       = "host_path"
    }
    varlog = {
      mount_path = "/var/log"
      read_only  = true
      type       = "host_path"
    }
    varlibdockercontainers = {
      mount_path = "/var/lib/docker/containers"
      read_only  = true
      type       = "host_path"
    }
    runlogjournal = {
      mount_path = "/run/log/journal"
      read_only  = true
      type       = "host_path"
    }
    dmesg = {
      mount_path = "/var/log/dmesg"
      read_only  = true
      type       = "host_path"
    }
    fluentbitconfig = {
      mount_path = "/fluent-bit/etc/"
      read_only  = false
      type       = "config_map"
    }
  }

  # Configmaps for polling agent
  polling_agent_configmaps = {
    log           = kubernetes_config_map.log_config.metadata.0.name
    polling_agent = kubernetes_config_map.polling_agent_config.metadata.0.name
    core          = kubernetes_config_map.core_config.metadata.0.name
    compute_plane = kubernetes_config_map.compute_plane_config.metadata.0.name
  }

  # Configmaps for worker
  worker_configmaps = {
    worker        = kubernetes_config_map.worker_config.metadata.0.name
    compute_plane = kubernetes_config_map.compute_plane_config.metadata.0.name
    log           = kubernetes_config_map.log_config.metadata.0.name
  }

  # Configmaps for control plane
  control_plane_configmaps = {
    core          = kubernetes_config_map.core_config.metadata.0.name
    log           = kubernetes_config_map.log_config.metadata.0.name
    control_plane = kubernetes_config_map.control_plane_config.metadata.0.name
  }

  # Partitions data
  partitions_data = [
    for key, value in var.compute_plane : {
      _id                  = key
      ParentPartitionIds   = value.partition_data.parent_partition_ids
      PodReserved          = value.partition_data.reserved_pods
      PodMax               = value.partition_data.max_pods
      PreemptionPercentage = value.partition_data.preemption_percentage
      Priority             = value.partition_data.priority
      PodConfiguration     = value.partition_data.pod_configuration
    }
  ]

  # HPA scalers
  # Compute plane
  hpa_compute_plane_triggers = {
    for partition, value in var.compute_plane : partition => {
      triggers = [
        for trigger in try(value.hpa.triggers, []) :
        (lower(try(trigger.type, "")) == "prometheus" ? {
          type = "prometheus"
          metadata = {
            serverAddress = try(var.monitoring.prometheus.url, "")
            metricName    = "armonik_${partition}_tasks_queued"
            threshold     = tostring(try(trigger.threshold, "2"))
            namespace     = local.metrics_exporter_namespace
            query         = "armonik_${partition}_tasks_queued{job=\"${local.metrics_exporter_name}\"}"
          }
          } :
          (lower(try(trigger.type, "")) == "cpu" || lower(try(trigger.type, "")) == "memory" ? {
            type       = lower(trigger.type)
            metricType = try(trigger.metric_type, "Utilization")
            metadata = {
              value = try(trigger.value, "80")
            }
        } : object({})))
      ]
    }
  }

  compute_plane_triggers = {
    for partition in local.partition_names : partition => {
      triggers = [for trigger in local.hpa_compute_plane_triggers[partition].triggers : trigger if trigger != {}]
    }
  }

  # Control plane
  hpa_control_plane_triggers = {
    triggers = [
      for trigger in try(var.control_plane.hpa.triggers, []) :
      (lower(try(trigger.type, "")) == "cpu" || lower(try(trigger.type, "")) == "memory" ? {
        type       = lower(trigger.type)
        metricType = try(trigger.metric_type, "Utilization")
        metadata = {
          value = try(trigger.value, "80")
        }
      } : object({}))
    ]
  }

  control_plane_triggers = {
    triggers = [for trigger in local.hpa_control_plane_triggers.triggers : trigger if trigger != {}]
  }
}
