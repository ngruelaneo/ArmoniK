# Global variables
variable "namespace" {
  description = "Namespace of ArmoniK resources"
  type        = string
}

# Logging level
variable "logging_level" {
  description = "Logging level in ArmoniK"
  type        = string
}

# Working dir
variable "working_dir" {
  description = "Working directory"
  type        = string
  default     = ".."
}

# List of needed storage
variable "storage_endpoint_url" {
  description = "List of storage needed by ArmoniK"
  type        = any
  default     = {}
}

# Monitoring
variable "monitoring" {
  description = "Monitoring info"
  type        = any
  default     = {}
}

# Parameters of ingress
variable "ingress" {
  description = "Parameters of the ingress controller"
  type = object({
    name              = string
    service_type      = string
    replicas          = number
    image             = string
    tag               = string
    image_pull_policy = string
    http_port         = number
    grpc_port         = number
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
    image_pull_secrets    = string
    node_selector         = any
    annotations           = any
    tls                   = bool
    mtls                  = bool
    generate_client_cert  = bool
    custom_client_ca_file = string
  })
  validation {
    error_message = "Ingress mTLS requires TLS to be enabled."
    condition     = var.ingress != null ? !var.ingress.mtls || var.ingress.tls : true
  }
  validation {
    error_message = "Without TLS, http_port and grpc_port must be different."
    condition     = var.ingress != null ? var.ingress.http_port != var.ingress.grpc_port || var.ingress.tls : true
  }
  validation {
    error_message = "Client certificate generation requires mTLS to be enabled."
    condition     = var.ingress != null ? !var.ingress.generate_client_cert || var.ingress.mtls : true
  }
  validation {
    error_message = "Cannot generate client certificates if the client CA is custom."
    condition     = var.ingress != null ? !var.ingress.mtls || var.ingress.custom_client_ca_file == "" || !var.ingress.generate_client_cert : true
  }
}

# Extra configuration
variable "extra_conf" {
  description = "Add extra configuration in the configmaps"
  type = object({
    compute = map(string)
    control = map(string)
    core    = map(string)
    log     = map(string)
    polling = map(string)
    worker  = map(string)
  })
  default = {
    compute = {}
    control = {}
    core    = {}
    log     = {}
    polling = {}
    worker  = {}
  }
}

# Job to insert partitions in the database
variable "job_partitions_in_database" {
  description = "Job to insert partitions IDs in the database"
  type = object({
    name               = string
    image              = string
    tag                = string
    image_pull_policy  = string
    image_pull_secrets = string
    node_selector      = any
    annotations        = any
  })
}

# Parameters of control plane
variable "control_plane" {
  description = "Parameters of the control plane"
  type = object({
    name              = string
    service_type      = string
    replicas          = number
    image             = string
    tag               = string
    image_pull_policy = string
    port              = number
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
    image_pull_secrets = string
    node_selector      = any
    annotations        = any
    hpa                = any
    default_partition  = string
  })
}

# Parameters of admin gui
variable "admin_gui" {
  description = "Parameters of the admin GUI"
  type = object({
    name  = string
    image = string
    tag   = string
    port  = number
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
    service_type       = string
    replicas           = number
    image_pull_policy  = string
    image_pull_secrets = string
    node_selector      = any
  })
  default = null
}

# Parameters of old admin gui
variable "admin_old_gui" {
  description = "Parameters of the old admin GUI"
  type = object({
    api = object({
      name  = string
      image = string
      tag   = string
      port  = number
      limits = object({
        cpu    = string
        memory = string
      })
      requests = object({
        cpu    = string
        memory = string
      })
    })
    old = object({
      name  = string
      image = string
      tag   = string
      port  = number
      limits = object({
        cpu    = string
        memory = string
      })
      requests = object({
        cpu    = string
        memory = string
      })
    })
    service_type       = string
    replicas           = number
    image_pull_policy  = string
    image_pull_secrets = string
    node_selector      = any
  })
  default = null
}

# Parameters of the compute plane
variable "compute_plane" {
  description = "Parameters of the compute plane"
  type = map(object({
    partition_data = object({
      priority              = number
      reserved_pods         = number
      max_pods              = number
      preemption_percentage = number
      parent_partition_ids  = list(string)
      pod_configuration     = any
    })
    replicas                         = number
    termination_grace_period_seconds = number
    image_pull_secrets               = string
    node_selector                    = any
    annotations                      = any
    polling_agent = object({
      image             = string
      tag               = string
      image_pull_policy = string
      limits = object({
        cpu    = string
        memory = string
      })
      requests = object({
        cpu    = string
        memory = string
      })
    })
    worker = list(object({
      name              = string
      image             = string
      tag               = string
      image_pull_policy = string
      limits = object({
        cpu    = string
        memory = string
      })
      requests = object({
        cpu    = string
        memory = string
      })
    }))
    hpa = any
  }))
}

# Authentication behavior
variable "authentication" {
  description = "Authentication behavior"
  type = object({
    name                    = string
    image                   = string
    tag                     = string
    image_pull_policy       = string
    image_pull_secrets      = string
    node_selector           = any
    authentication_datafile = string
    require_authentication  = bool
    require_authorization   = bool
  })
  validation {
    error_message = "Authorization requires authentication to be activated."
    condition     = var.authentication == null || var.authentication.require_authentication || !var.authentication.require_authorization
  }
  validation {
    error_message = "File specified in authentication.authentication_datafile must be a valid json file if the field is not empty."
    condition     = var.authentication == null || !var.authentication.require_authentication || var.authentication.authentication_datafile == "" || try(fileexists(var.authentication.authentication_datafile), false) && can(jsondecode(file(var.authentication.authentication_datafile)))
  }
}

# The name of the secrets.
variable "fluent_bit_secret_name" {
  description = "the name of the fluent-bit secret"
  type        = string
  default     = "fluent-bit"
}

variable "grafana_secret_name" {
  description = "the name of the grafana secret"
  type        = string
  default     = "grafana"
}

variable "prometheus_secret_name" {
  description = "the name of the prometheus secret"
  type        = string
  default     = "prometheus"
}

variable "metrics_exporter_secret_name" {
  description = "the name of the metrics exporter secret"
  type        = string
  default     = "metrics-exporter"
}

variable "partition_metrics_exporter_secret_name" {
  description = "the name of the partition metrics exporter secret"
  type        = string
  default     = "partition-metrics-exporter"
}

variable "seq_secret_name" {
  description = "the name of the seq secret"
  type        = string
  default     = "seq"
}

variable "shared_storage_secret_name" {
  description = "the name of the shared-storage secret"
  type        = string
  default     = "shared-storage"
}

variable "deployed_object_storage_secret_name" {
  description = "the name of the deployed-object-storage secret"
  type        = string
  default     = "deployed-object-storage"
}

variable "deployed_table_storage_secret_name" {
  description = "the name of the deployed-table-storage secret"
  type        = string
  default     = "deployed-table-storage"
}

variable "deployed_queue_storage_secret_name" {
  description = "the name of the deployed-queue-storage secret"
  type        = string
  default     = "deployed-queue-storage"
}

variable "s3_secret_name" {
  description = "the name of the S3 secret"
  type        = string
  default     = "s3"
}

variable "keda_chart_name" {
  description = "Name of the Keda Helm chart"
  type        = string
  default     = "keda"
}

variable "metrics_server_chart_name" {
  description = "Name of the metrics-server Helm chart"
  type        = string
  default     = "metrics-server"
}
