# AWS Current Region
data "aws_region" "current" {}

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
      clusterName = aws_eks_cluster.main.name

      image = {
        repository = "${var.private_ecr_repository}/eks/aws-load-balancer-controller"
        tag        = "v2.12.0"
      }

      enableServiceMutatorWebhook = false
      region                      = data.aws_region.current.name
      vpcId                       = var.vpc_id

      serviceAccount = {
        create = false
        name   = kubernetes_service_account.alb_controller.metadata[0].name
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.alb_controller
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
  depends_on = [
    kubernetes_service_account.ebs_csi_controller_sa
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
