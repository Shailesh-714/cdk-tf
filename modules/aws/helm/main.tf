# AWS Current Region
data "aws_region" "current" {}

# AWS Account ID
data "aws_caller_identity" "current" {}

# ==========================================================
#                  Helm Provider Config
# ==========================================================

data "aws_eks_cluster" "main" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = var.eks_cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
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
      clusterName = data.aws_eks_cluster.main.name

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

# Helm release for EBS CSI Driver
resource "helm_release" "ebs_csi_driver" {
  name       = "ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "1.41.0" # optional: chart version if you want to pin it
  wait       = true

  values = [
    yamlencode({
      image = {
        repository = "${var.private_ecr_repository}/ebs-csi-driver/aws-ebs-csi-driver"
        tag        = "v1.41.0"
      }
      sidecars = {
        provisioner = {
          image = {
            repository = "${var.private_ecr_repository}/eks-distro/kubernetes-csi/external-provisioner"
            tag        = "v5.2.0-eks-1-32-10"
          }
        }
        attacher = {
          image = {
            repository = "${var.private_ecr_repository}/eks-distro/kubernetes-csi/external-attacher"
            tag        = "v4.8.1-eks-1-32-10"
          }
        }
        snapshotter = {
          image = {
            repository = "${var.private_ecr_repository}/eks-distro/kubernetes-csi/external-snapshotter/csi-snapshotter"
            tag        = "v8.2.1-eks-1-32-10"
          }
        }
        livenessProbe = {
          image = {
            repository = "${var.private_ecr_repository}/eks-distro/kubernetes-csi/livenessprobe"
            tag        = "v2.15.0-eks-1-32-10"
          }
        }
        resizer = {
          image = {
            repository = "${var.private_ecr_repository}/eks-distro/kubernetes-csi/external-resizer"
            tag        = "v1.13.2-eks-1-32-10"
          }
        }
        nodeDriverRegistrar = {
          image = {
            repository = "${var.private_ecr_repository}/eks-distro/kubernetes-csi/node-driver-registrar"
            tag        = "v2.13.0-eks-1-32-10"
          }
        }
        volumemodifier = {
          image = {
            repository = "${var.private_ecr_repository}/ebs-csi-driver/volume-modifier-for-k8s"
            tag        = "v0.5.1"
          }
        }
      }
    })
  ]
}


# Helm release for Istio base components
resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  namespace        = "istio-system"
  version          = "1.25.0"
  create_namespace = true
  wait             = true

  values = [
    yamlencode({
      defaultRevision = "default"
    })
  ]
}

# Helm release for Istio control plane (istiod)
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  version    = "1.25.0"
  wait       = true

  values = [
    yamlencode({
      global = {
        hub = "${var.private_ecr_repository}/istio"
        tag = "1.25.0"
      }
      pilot = {
        nodeSelector = {
          "node-type" = "memory-optimized"
        }
      }
    })
  ]

  depends_on = [
    helm_release.istio_base
  ]
}

# Helm release for Istio ingress gateway
resource "helm_release" "istio_gateway" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"
  version    = "1.25.0"
  wait       = true

  values = [
    yamlencode({
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
    })
  ]

  depends_on = [
    helm_release.istiod
  ]
}

locals {
  sdk_version = "0.121.2"
}

resource "helm_release" "hyperswitch_services" {
  name       = "hypers-v1"
  repository = "https://juspay.github.io/hyperswitch-helm/"
  chart      = "hyperswitch-stack"
  version    = "0.2.4"
  namespace  = "hyperswitch"

  create_namespace = true

  wait = false

  values = [
    yamlencode({
      clusterName = var.eks_cluster_name

      loadBalancer = {
        targetSecurityGroup = var.internal_lb_security_group_id
      }

      prometheus = {
        enabled = false
      }

      alertmanager = {
        enabled = false
      }

      "hyperswitch-app" = {
        loadBalancer = {
          targetSecurityGroup = var.internal_lb_security_group_id
        }

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
            host       = "https://${aws_cloudfront_distribution.sdk_distribution.domain_name}"
            version    = local.sdk_version
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
            apple_pay_merchant_cert                       = var.kms_secrets["apple_pay_merchant_cert"]
            apple_pay_merchant_cert_key                   = var.kms_secrets["apple_pay_merchant_cert_key"]
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
        enabled = true

        services = {
          router = {
            host = "http://localhost:8080"
          }
          sdkDemo = {
            image                     = "juspaydotin/hyperswitch-web:v0.121.2"
            hyperswitchPublishableKey = "pub_key"
            hyperswitchSecretKey      = "secret_key"
          }
        }

        loadBalancer = {
          targetSecurityGroup = var.internal_lb_security_group_id
        }

        ingress = {
          className = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/backend-protocol"         = "HTTP"
            "alb.ingress.kubernetes.io/backend-protocol-version" = "HTTP1"
            "alb.ingress.kubernetes.io/group.name"               = "hyperswitch-web-alb-ingress-group"
            "alb.ingress.kubernetes.io/ip-address-type"          = "ipv4"
            "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTP\": 80}]"
            "alb.ingress.kubernetes.io/load-balancer-name"       = "hyperswitch-web"
            "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
            "alb.ingress.kubernetes.io/security-groups"          = var.internal_lb_security_group_id
            "alb.ingress.kubernetes.io/tags"                     = "stack=hyperswitch-lb"
            "alb.ingress.kubernetes.io/target-type"              = "ip"
          }
          hosts = [{
            host = ""
            paths = [{
              path     = "/"
              pathType = "Prefix"
            }]
          }]
        }

        autoBuild = {
          forceBuild = false
          gitCloneParam = {
            gitVersion = local.sdk_version
          }
          buildParam = {
            envSdkUrl = "https://${aws_cloudfront_distribution.sdk_distribution.domain_name}"
          }
          nginxConfig = {
            extraPath = "v1"
          }
        }
      }
    })
  ]

  depends_on = [
    helm_release.alb_controller
  ]
}

