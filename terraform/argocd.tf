data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "6.7.11"

  depends_on = [module.eks] 
}

resource "kubernetes_secret_v1" "github_repo_secret" {
  metadata {
    name      = "github-repo-secret"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = "https://github.com/Alexander-Grg/aws-cloud-native-webapp.git"
    username = "Alexander-Grg"
    password = var.github_token
  }

  depends_on = [helm_release.argocd]
}

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"
  version    = "2.0.0"

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.github_repo_secret,
    null_resource.gateway_api_crds,
    helm_release.external_secrets
  ]

  values = [
    <<-EOT
    projects:
      webapp-project:
        description: Custom project for webapp
        sourceRepos:
          - '*'
        destinations:
          - namespace: 'webapp'
            server: https://kubernetes.default.svc
          - namespace: 'argocd'
            server: https://kubernetes.default.svc
          - namespace: 'monitoring'
            server: https://kubernetes.default.svc
          - namespace: 'kube-system'              
            server: https://kubernetes.default.svc
        clusterResourceWhitelist:
          - group: '*'
            kind: '*'
            
    applications:
      root-app:
        namespace: argocd
        project: webapp-project
        source:
          repoURL: "https://github.com/Alexander-Grg/aws-cloud-native-webapp.git"
          targetRevision: HEAD
          path: argocd-apps
        destination:
          server: "https://kubernetes.default.svc"
          namespace: argocd
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
          syncOptions:
            - CreateNamespace=true
    EOT
  ]
}

resource "kubernetes_service_account_v1" "external_secrets_sa" {
  metadata {
    name      = "external-secrets-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets_role.arn
    }
  }

  depends_on = [module.eks]
}