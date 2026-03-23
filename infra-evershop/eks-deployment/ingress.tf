# Ingress and Load Balancing Configuration
# Task 3.11.1: Create ingress.tf file
# Task 3.11.2: Deploy AWS Load Balancer Controller using aws_eks/microservice internal module
# Deploys AWS Load Balancer Controller and Ingress resources for EverShop services

# =============================================================================
# AWS Load Balancer Controller
# Uses public Terraform Registry module: DNXLabs/eks-lb-controller/aws
# Deploys the controller via Helm into kube-system with IRSA for ALB management
# =============================================================================

module "aws_load_balancer_controller" {
  source  = "DNXLabs/eks-lb-controller/aws"
  version = "0.8.1"

  # EKS cluster identity
  cluster_name                     = module.eks.cluster_name
  cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn

  # Helm configuration
  helm_chart_version = "1.6.2"
  namespace          = "kube-system"
  create_namespace   = false

  # Service account configuration
  service_account_name = "aws-load-balancer-controller"

  # Additional Helm values for controller configuration
  settings = {
    clusterName = module.eks.cluster_name
    region      = var.aws_region
    vpcId       = module.vpc.vpc_id
    replicaCount = 2
    resources = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "256Mi"
      }
    }
  }

  # IAM role tags
  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "ingress"
    Name        = "${var.project_name}-aws-lbc-${var.environment}"
  })

  depends_on = [module.eks]
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
