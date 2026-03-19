# Ingress and Load Balancing Configuration
# Task 3.11.1: Create ingress.tf file
# Task 3.11.2: Deploy AWS Load Balancer Controller using aws_eks/microservice internal module
# Deploys AWS Load Balancer Controller and Ingress resources for EverShop services

# =============================================================================
# AWS Load Balancer Controller
# Uses internal module: aws_eks/microservice-v3.0.0
# Deploys the controller via Helm into kube-system with IRSA for ALB management
# =============================================================================

module "aws_load_balancer_controller" {
  source = "git@bitbucket.org:Coopeuch/terraform.git//modules/aws_eks/microservice?ref=modules/aws_eks/microservice-v3.0.0"

  # EKS cluster identity
  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_ca_data  = module.eks.cluster_certificate_authority_data

  # Helm release configuration
  release_name     = "aws-load-balancer-controller"
  chart_name       = "aws-load-balancer-controller"
  chart_repository = "https://aws.github.io/eks-charts"
  chart_version    = "1.6.2"
  namespace        = "kube-system"
  create_namespace = false

  # Service account with IRSA annotation
  service_account_name = "aws-load-balancer-controller"
  irsa_role_arn        = aws_iam_role.aws_load_balancer_controller.arn

  # Helm values — configure controller for this cluster/VPC
  set_values = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = module.vpc.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.aws_load_balancer_controller.arn
    },
    {
      name  = "replicaCount"
      value = "2"
    },
    {
      name  = "resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "resources.requests.memory"
      value = "128Mi"
    },
    {
      name  = "resources.limits.cpu"
      value = "200m"
    },
    {
      name  = "resources.limits.memory"
      value = "256Mi"
    },
  ]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "ingress"
    Name        = "${var.project_name}-aws-lbc-${var.environment}"
  })

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.aws_load_balancer_controller_policy,
  ]
}

# =============================================================================
# Ingress Resource: GraphQL API
# Routes traffic to graphql-api service on port 4000
#
# Environment-Specific Configuration:
#   - Dev: HTTP only, no custom domain, no ACM certificate, access via ALB DNS
#   - QA/Prod: HTTPS with redirect, custom domain, ACM certificate
#
# HTTP → HTTPS Redirect Configuration (QA/Prod only - FR7.2):
#   - alb.ingress.kubernetes.io/listen-ports: enables both HTTP:80 and HTTPS:443 listeners
#   - alb.ingress.kubernetes.io/ssl-redirect: instructs ALB to redirect HTTP to HTTPS:443
#   - alb.ingress.kubernetes.io/actions.ssl-redirect: explicit 301 redirect action config,
#     making the redirect permanent and the behaviour fully declarative
# =============================================================================

resource "kubernetes_ingress_v1" "graphql_api" {
  metadata {
    name      = "${var.project_name}-graphql-api-ingress"
    namespace = "evershop"

    annotations = merge(
      {
        "kubernetes.io/ingress.class"                = "alb"
        "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"      = "ip"
        "alb.ingress.kubernetes.io/security-groups"  = aws_security_group.alb.id
        "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
        "alb.ingress.kubernetes.io/healthcheck-port" = "4000"
        "alb.ingress.kubernetes.io/tags"             = "Environment=${var.environment},Project=${var.project_name}"
      },
      var.environment != "dev" && var.domain_name != "" && var.acm_certificate_arn != "" ? {
        "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
        "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
        "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({
          Type = "redirect"
          RedirectConfig = {
            Protocol   = "HTTPS"
            Port       = "443"
            StatusCode = "HTTP_301"
          }
        })
        } : {
        "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
      }
    )

    labels = {
      app         = "graphql-api"
      environment = var.environment
    }
  }

  spec {
    # Rule with custom domain (QA/Prod only)
    dynamic "rule" {
      for_each = var.environment != "dev" && var.domain_name != "" ? [1] : []
      content {
        host = "api.${var.domain_name}"
        http {
          path {
            path      = "/"
            path_type = "Prefix"
            backend {
              service {
                name = "graphql-api"
                port {
                  number = 4000
                }
              }
            }
          }
        }
      }
    }

    # Rule without custom domain (Dev only - uses ALB DNS)
    dynamic "rule" {
      for_each = var.environment == "dev" || var.domain_name == "" ? [1] : []
      content {
        http {
          path {
            path      = "/api"
            path_type = "Prefix"
            backend {
              service {
                name = "graphql-api"
                port {
                  number = 4000
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [module.aws_load_balancer_controller]
}

# =============================================================================
# Ingress Resource: React Frontend
# Routes traffic to react-frontend service on port 3000
#
# Environment-Specific Configuration:
#   - Dev: HTTP only, no custom domain, no ACM certificate, access via ALB DNS
#   - QA/Prod: HTTPS with redirect, custom domain, ACM certificate
#
# HTTP → HTTPS Redirect Configuration (QA/Prod only - FR7.2):
#   - alb.ingress.kubernetes.io/listen-ports: enables both HTTP:80 and HTTPS:443 listeners
#   - alb.ingress.kubernetes.io/ssl-redirect: instructs ALB to redirect HTTP to HTTPS:443
#   - alb.ingress.kubernetes.io/actions.ssl-redirect: explicit 301 redirect action config,
#     making the redirect permanent and the behaviour fully declarative
# =============================================================================

resource "kubernetes_ingress_v1" "react_frontend" {
  metadata {
    name      = "${var.project_name}-frontend-ingress"
    namespace = "evershop"

    annotations = merge(
      {
        "kubernetes.io/ingress.class"                = "alb"
        "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"      = "ip"
        "alb.ingress.kubernetes.io/security-groups"  = aws_security_group.alb.id
        "alb.ingress.kubernetes.io/healthcheck-path" = "/"
        "alb.ingress.kubernetes.io/healthcheck-port" = "3000"
        "alb.ingress.kubernetes.io/tags"             = "Environment=${var.environment},Project=${var.project_name}"
      },
      var.environment != "dev" && var.domain_name != "" && var.acm_certificate_arn != "" ? {
        "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
        "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
        "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({
          Type = "redirect"
          RedirectConfig = {
            Protocol   = "HTTPS"
            Port       = "443"
            StatusCode = "HTTP_301"
          }
        })
        } : {
        "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
      }
    )

    labels = {
      app         = "react-frontend"
      environment = var.environment
    }
  }

  spec {
    # Rule with custom domain (QA/Prod only)
    dynamic "rule" {
      for_each = var.environment != "dev" && var.domain_name != "" ? [1] : []
      content {
        host = "shop.${var.domain_name}"
        http {
          path {
            path      = "/"
            path_type = "Prefix"
            backend {
              service {
                name = "react-frontend"
                port {
                  number = 3000
                }
              }
            }
          }
        }
      }
    }

    # Rule without custom domain (Dev only - uses ALB DNS)
    dynamic "rule" {
      for_each = var.environment == "dev" || var.domain_name == "" ? [1] : []
      content {
        http {
          path {
            path      = "/"
            path_type = "Prefix"
            backend {
              service {
                name = "react-frontend"
                port {
                  number = 3000
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [module.aws_load_balancer_controller]
}
