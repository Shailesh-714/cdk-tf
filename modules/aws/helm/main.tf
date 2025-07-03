# AWS Current Region
data "aws_region" "current" {}

# AWS Account ID
data "aws_caller_identity" "current" {}

# ==========================================================
#                  Helm Provider Config
# ==========================================================

data "aws_eks_cluster_auth" "main" {
  name = var.eks_cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = var.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(var.eks_cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

# ==========================================================
#                       Helm Releases
# ==========================================================

# Helm release for AWS Load Balancer Controller
resource "helm_release" "alb_controller" {
  name       = "hs-lb-v1"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1" # Optional: pin chart version if you want
  wait       = true

  values = [
    yamlencode({
      clusterName = var.eks_cluster_name

      image = {
        repository = "${var.private_ecr_repository}/eks/aws-load-balancer-controller"
        tag        = "v2.12.0"
      }

      enableServiceMutatorWebhook = false
      region                      = data.aws_region.current.name
      vpcId                       = var.vpc_id

      serviceAccount = {
        create = false
        name   = var.alb_controller_service_account_name
      }
    })
  ]

}

# Helm release for Hyperswitch services
resource "helm_release" "hyperswitch_services" {
  name       = var.stack_name
  repository = "https://juspay.github.io/hyperswitch-helm/"
  chart      = "hyperswitch-stack"
  version    = "0.2.4"
  namespace  = "hyperswitch"

  create_namespace = true

  wait = false

  values = [
    yamlencode({
      clusterName = var.eks_cluster_name

      prometheus = {
        enabled = false
      }

      alertmanager = {
        enabled = false
      }

      "hyperswitch-app" = {

        redis = {
          enabled = false
        }

        services = {
          router = {
            image = "${var.private_ecr_repository}/juspaydotin/hyperswitch-router:v1.114.0-standalone"
          }
          producer = {
            image = "${var.private_ecr_repository}/juspaydotin/hyperswitch-producer:v1.114.0-standalone"
          }
          consumer = {
            image = "${var.private_ecr_repository}/juspaydotin/hyperswitch-consumer:v1.114.0-standalone"
          }
          controlCenter = {
            image = "${var.private_ecr_repository}/juspaydotin/hyperswitch-control-center:v1.37.1"
          }
          sdk = {
            host       = "https://${var.sdk_distribution_domain_name}"
            version    = var.sdk_version
            subversion = "v1"
          }
        }

        server = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [{
                matchExpressions = [{
                  key      = "node-type"
                  operator = "In"
                  values   = ["generic-compute"]
                }]
              }]
            }
          }

          secrets_management = {
            secrets_manager = "aws_kms"
            aws_kms = {
              key_id = var.hyperswitch_kms_key_id
              region = data.aws_region.current.name
            }
          }

          region      = data.aws_region.current.name
          bucket_name = "logs-bucket-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

          serviceAccountAnnotations = {
            "eks.amazonaws.com/role-arn" = var.hyperswitch_service_account_role_arn
          }

          server_base_url = "https://sandbox.hyperswitch.io"

          secrets = {
            podAnnotations = {
              "traffic.sidecar.istio.io/excludeOutboundIPRanges" = "10.23.6.12/32"
            }
            kms_admin_api_key                             = var.kms_secrets["kms_admin_api_key"]
            kms_jwt_secret                                = var.kms_secrets["kms_jwt_secret"]
            kms_jwekey_locker_identifier1                 = var.kms_secrets["kms_jwekey_locker_identifier1"]
            kms_jwekey_locker_identifier2                 = var.kms_secrets["kms_jwekey_locker_identifier2"]
            kms_jwekey_locker_encryption_key1             = var.kms_secrets["kms_jwekey_locker_encryption_key1"]
            kms_jwekey_locker_encryption_key2             = var.kms_secrets["kms_jwekey_locker_encryption_key2"]
            kms_jwekey_locker_decryption_key1             = var.kms_secrets["kms_jwekey_locker_decryption_key1"]
            kms_jwekey_locker_decryption_key2             = var.kms_secrets["kms_jwekey_locker_decryption_key2"]
            kms_jwekey_vault_encryption_key               = var.kms_secrets["kms_jwekey_vault_encryption_key"]
            kms_jwekey_vault_private_key                  = var.kms_secrets["kms_jwekey_vault_private_key"]
            kms_jwekey_tunnel_private_key                 = var.kms_secrets["kms_jwekey_tunnel_private_key"]
            kms_jwekey_rust_locker_encryption_key         = var.kms_secrets["kms_jwekey_rust_locker_encryption_key"]
            kms_connector_onboarding_paypal_client_id     = var.kms_secrets["kms_connector_onboarding_paypal_client_id"]
            kms_connector_onboarding_paypal_client_secret = var.kms_secrets["kms_connector_onboarding_paypal_client_secret"]
            kms_connector_onboarding_paypal_partner_id    = var.kms_secrets["kms_connector_onboarding_paypal_partner_id"]
            kms_key_id                                    = var.hyperswitch_kms_key_id
            kms_key_region                                = data.aws_region.current.name
            kms_encrypted_api_hash_key                    = var.kms_secrets["kms_encrypted_api_hash_key"]
            admin_api_key                                 = var.kms_secrets["kms_admin_api_key"]
            jwt_secret                                    = var.kms_secrets["kms_jwt_secret"]
            recon_admin_api_key                           = var.kms_secrets["kms_recon_admin_api_key"]
            forex_api_key                                 = var.kms_secrets["kms_forex_api_key"]
            forex_fallback_api_key                        = var.kms_secrets["kms_forex_fallback_api_key"]
            apple_pay_ppc                                 = var.kms_secrets["apple_pay_ppc"]
            apple_pay_ppc_key                             = var.kms_secrets["apple_pay_ppc_key"]
            apple_pay_merchant_cert                       = var.kms_secrets["apple_pay_merchant_conf_merchant_cert"]
            apple_pay_merchant_cert_key                   = var.kms_secrets["apple_pay_merchant_conf_merchant_cert_key"]
            apple_pay_merchant_conf_merchant_cert         = var.kms_secrets["apple_pay_merchant_conf_merchant_cert"]
            apple_pay_merchant_conf_merchant_cert_key     = var.kms_secrets["apple_pay_merchant_conf_merchant_cert_key"]
            apple_pay_merchant_conf_merchant_id           = var.kms_secrets["apple_pay_merchant_conf_merchant_id"]
            pm_auth_key                                   = var.kms_secrets["pm_auth_key"]
            api_hash_key                                  = var.kms_secrets["api_hash_key"]
            master_enc_key                                = var.kms_secrets["kms_encrypted_master_key"]
          }

          google_pay_decrypt_keys = {
            google_pay_root_signing_keys = var.kms_secrets["google_pay_root_signing_keys"]
          }

          paze_decrypt_keys = {
            paze_private_key            = var.kms_secrets["paze_private_key"]
            paze_private_key_passphrase = var.kms_secrets["paze_private_key_passphrase"]
          }

          user_auth_methods = {
            encryption_key = var.kms_secrets["encryption_key"]
          }

          locker = {
            locker_enabled          = var.locker_enabled
            locker_public_key       = var.locker_enabled ? var.locker_public_key : "locker-key"
            hyperswitch_private_key = var.locker_enabled ? var.tenant_private_key : "locker-key"
          }

          basilisk = {
            host = "basilisk-host"
          }

          run_env = "sandbox"
        }

        consumer = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [{
                matchExpressions = [{
                  key      = "node-type"
                  operator = "In"
                  values   = ["generic-compute"]
                }]
              }]
            }
          }
        }

        producer = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [{
                matchExpressions = [{
                  key      = "node-type"
                  operator = "In"
                  values   = ["generic-compute"]
                }]
              }]
            }
          }
        }

        controlCenter = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [{
                matchExpressions = [{
                  key      = "node-type"
                  operator = "In"
                  values   = ["control-center"]
                }]
              }]
            }
          }
          env = {
            default__features__email = false
          }
        }

        postgresql = {
          enabled = false
        }

        externalPostgresql = {
          enabled = true
          primary = {
            host = var.rds_cluster_endpoint
            auth = {
              username      = "db_user"
              database      = "hyperswitch"
              password      = var.kms_secrets["kms_encrypted_db_pass"]
              plainpassword = var.db_password
            }
          }
          readOnly = {
            host = var.rds_cluster_reader_endpoint
            auth = {
              username      = "db_user"
              database      = "hyperswitch"
              password      = var.kms_secrets["kms_encrypted_db_pass"]
              plainpassword = var.db_password
            }
          }
        }

        externalRedis = {
          enabled = true
          host    = var.elasticache_cluster_endpoint_address
          port    = 6379
        }

        autoscaling = {
          enabled                        = true
          minReplicas                    = 3
          maxReplicas                    = 5
          targetCPUUtilizationPercentage = 80
        }

        analytics = {
          clickhouse = {
            enabled  = false
            password = "dummypassword"
          }
        }

        kafka = {
          enabled = false
        }

        clickhouse = {
          enabled = false
        }

        "hyperswitch-card-vault" = {
          enabled = false
          postgresql = {
            enabled = false
          }
        }
      }

      "hyperswitch-web" = {
        enabled = false
      }
    })
  ]

  depends_on = [
    helm_release.alb_controller
  ]
}

# Helm release for Hyperswitch Istio chart
resource "helm_release" "traffic_control" {
  name             = "hs-istio"
  chart            = "hyperswitch-istio"
  repository       = "https://shailesh-714.github.io/istio-test/"
  namespace        = "istio-system"
  create_namespace = true

  values = [
    yamlencode({
      # Service-specific versions
      hyperswitchServer = {
        version = "v1o114o0" # hyperswitch-router version
      }
      hyperswitchControlCenter = {
        version = "v1o37o1" # hyperswitch-control-center version
      }
      image = {
        version = "v1o107o0"
      }
      service = {
        type = "ClusterIP"
        port = 80
      }
      ingress = {
        enabled   = true
        className = "alb"
        annotations = {
          "alb.ingress.kubernetes.io/backend-protocol"             = "HTTP"
          "alb.ingress.kubernetes.io/backend-protocol-version"     = "HTTP1"
          "alb.ingress.kubernetes.io/group.name"                   = "hyperswitch-istio-app-alb-ingress-group"
          "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "5"
          "alb.ingress.kubernetes.io/healthcheck-path"             = "/healthz/ready"
          "alb.ingress.kubernetes.io/healthcheck-port"             = "15021"
          "alb.ingress.kubernetes.io/healthcheck-protocol"         = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "2"
          "alb.ingress.kubernetes.io/healthy-threshold-count"      = "5"
          "alb.ingress.kubernetes.io/ip-address-type"              = "ipv4"
          "alb.ingress.kubernetes.io/listen-ports"                 = "[{\"HTTP\": 80}]"
          "alb.ingress.kubernetes.io/load-balancer-attributes"     = "routing.http.drop_invalid_header_fields.enabled=true,routing.http.xff_client_port.enabled=true,routing.http.preserve_host_header.enabled=true"
          "alb.ingress.kubernetes.io/scheme"                       = "internal"
          "alb.ingress.kubernetes.io/security-groups"              = aws_security_group.internal_alb_sg.id
          "alb.ingress.kubernetes.io/subnets"                      = join(",", var.subnet_ids["istio_lb_transit_zone"])
          "alb.ingress.kubernetes.io/target-type"                  = "ip"
          "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "3"
        }
        hosts = {
          paths = [
            {
              path     = "/"
              pathType = "Prefix"
              port     = 80
              name     = "istio-ingressgateway"
            },
            {
              path     = "/healthz/ready"
              pathType = "Prefix"
              port     = 15021
              name     = "istio-ingressgateway"
            }
          ]
        }
        tls = []
      }
      livenessProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
      }
      readinessProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
      }
      # Istio Base Configuration
      istio-base = {
        enabled         = true
        defaultRevision = "default"
      }
      # Istiod Configuration
      istiod = {
        enabled = true
        global = {
          hub = "${var.private_ecr_repository}/istio"
          tag = "1.25.0"
        }
        pilot = {
          nodeSelector = {
            "node-type" = "memory-optimized"
          }
          serviceAccountAnnotations = {
            "eks.amazonaws.com/role-arn" = var.istio_service_account_role_arn
          }
        }
      }
      # Istio Gateway Configuration
      istio-gateway = {
        enabled = true
        name    = "istio-ingressgateway"
        global = {
          hub = "${var.private_ecr_repository}/istio"
          tag = "1.25.0"
        }
        service = {
          type = "ClusterIP"
        }
        nodeSelector = {
          "node-type" = "memory-optimized"
        }
        serviceAccountAnnotations = {
          "eks.amazonaws.com/role-arn" = var.istio_service_account_role_arn
        }
      }
      # Create istio-system namespace
      createNamespace = false
      # Service account configuration
      serviceAccount = {
        # Specifies whether a service account should be created
        create = false
        # The name of the service account to use.
        # If not set and create is true, a name is generated using the fullname template
        name = "istio-service-account"
      }
    })
  ]

  depends_on = [
    helm_release.hyperswitch_services,
    aws_security_group.internal_alb_sg
  ]
}

# Istio Internal ALB Data Source
data "aws_lb" "internal_alb" {
  tags = {
    "ingress.k8s.aws/stack" = "hyperswitch-istio-app-alb-ingress-group" # Your group name
  }

  depends_on = [helm_release.traffic_control]
}

resource "aws_s3_bucket" "loki_logs" {
  bucket = "${var.stack_name}-loki-logs-storage-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = true

  tags = {
    Name = "${var.stack_name}-loki-logs-storage-bucket"
  }
}

resource "aws_s3_bucket_policy" "loki_logs_rw" {
  bucket = aws_s3_bucket.loki_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowGrafanaServiceAccountRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.grafana_service_account_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.loki_logs.arn,
          "${aws_s3_bucket.loki_logs.arn}/*"
        ]
      }
    ]
  })
}

# # Loki Helm release
# resource "helm_release" "loki_stack" {
#   name             = "loki"
#   chart            = "loki-stack"
#   repository       = "https://grafana.github.io/helm-charts/"
#   namespace        = "loki"
#   create_namespace = true
#   wait             = true
#   timeout          = 900
#   values = [
#     yamlencode({
#       grafana = {
#         global = {
#           imageRegistry = var.private_ecr_repository
#         }
#         image = {
#           repository = "${var.private_ecr_repository}/grafana/grafana"
#           tag        = "latest"
#         }
#         sidecar = {
#           image = {
#             repository = "${var.private_ecr_repository}/kiwigrid/k8s-sidecar"
#             tag        = "1.30.3"
#             sha        = ""
#           }
#           imagePullPolicy = "IfNotPresent"
#           resources       = {}
#         }
#         enabled       = true
#         adminPassword = "admin"
#         serviceAccount = {
#           annotations = {
#             "eks.amazonaws.com/role-arn" = var.grafana_service_account_role_arn
#           }
#         }
#         nodeSelector = {
#           "node-type" = "monitoring"
#         }
#         ingress = {
#           enabled          = true
#           ingressClassName = "alb"
#           annotations = {
#             "alb.ingress.kubernetes.io/backend-protocol"         = "HTTP"
#             "alb.ingress.kubernetes.io/group.name"               = "hs-logs-alb-ingress-group"
#             "alb.ingress.kubernetes.io/ip-address-type"          = "ipv4"
#             "alb.ingress.kubernetes.io/healthcheck-path"         = "/api/health"
#             "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTP\": 80}]"
#             "alb.ingress.kubernetes.io/load-balancer-attributes" = "routing.http.drop_invalid_header_fields.enabled=true"
#             "alb.ingress.kubernetes.io/load-balancer-name"       = "hyperswitch-grafana-logs"
#             "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
#             "alb.ingress.kubernetes.io/tags"                     = "stack=hyperswitch-lb"
#             "alb.ingress.kubernetes.io/security-groups"          = aws_security_group.grafana_ingress_lb_sg.id
#             "alb.ingress.kubernetes.io/subnets"                  = join(",", var.subnet_ids["external_incoming_zone"])
#             "alb.ingress.kubernetes.io/target-type"              = "ip"
#           }
#           extraPaths = [
#             {
#               path     = "/"
#               pathType = "Prefix"
#               backend = {
#                 service = {
#                   name = "loki-grafana"
#                   port = {
#                     number = 80
#                   }
#                 }
#               }
#             }
#           ]
#           hosts = []
#         }
#       }

#       loki = {
#         enabled = true
#         serviceAccount = {
#           annotations = {
#             "eks.amazonaws.com/role-arn" = var.grafana_service_account_role_arn
#           }
#         }
#         config = {
#           limits_config = {
#             max_entries_limit_per_query = 5000
#             max_query_length            = "90d" # Renamed from max_query_lookback
#             reject_old_samples          = true
#             reject_old_samples_max_age  = "168h"
#             retention_period            = "100d"
#             retention_stream = [
#               {
#                 period   = "7d"
#                 priority = 1
#                 selector = "{level=\"debug\"}"
#               }
#             ]
#           }
#           schema_config = {
#             configs = [
#               {
#                 chunks = {
#                   period = "24h"
#                   prefix = "loki_chunk_"
#                 }
#                 from = "2024-05-01"
#                 index = {
#                   prefix = "loki_index_"
#                   period = "24h"
#                 }
#                 object_store = "s3"
#                 schema       = "v12"
#                 store        = "tsdb"
#               }
#             ]
#           }
#           storage_config = {
#             tsdb_shipper = {
#               active_index_directory = "/data/tsdb-index"
#               cache_location         = "/data/tsdb-cache"
#             }
#             aws = {
#               bucketnames = aws_s3_bucket.loki_logs.bucket
#               region      = data.aws_region.current.name
#             }
#           }
#         }
#       }


#       promtail = {
#         enabled = true
#         global = {
#           imageRegistry = var.private_ecr_repository
#         }
#         image = {
#           registry   = var.private_ecr_repository
#           repository = "grafana/promtail"
#           tag        = "latest"
#         }
#         config = {
#           snippets = {
#             extraRelabelConfigs = [
#               {
#                 action        = "keep"
#                 regex         = "hyperswitch-.*"
#                 source_labels = ["__meta_kubernetes_pod_label_app"]
#               }
#             ]
#           }
#         }
#       }
#     })
#   ]

#   depends_on = [helm_release.hyperswitch_services]
# }

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  chart      = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  namespace  = "kube-system"

  values = [
    yamlencode({
      image = {
        repository = "${var.private_ecr_repository}/bitnami/metrics-server"
        tag        = "0.7.2"
      }
    })
  ]
}
