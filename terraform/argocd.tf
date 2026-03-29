provider "helm" {
    kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
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

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"
  version    = "2.0.0"

  depends_on = [helm_release.argocd]

  values = [
    <<-EOT
    applications:
      webapp:
        namespace: argocd
        project: default
        source:
          repoURL: "https://github.com/Alexander-Grg/aws-cloud-native-webapp.git"
          targetRevision: HEAD
          path: charts/webapp
        destination:
          server: "https://kubernetes.default.svc"
          namespace: webapp
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
          syncOptions:
            - CreateNamespace=true
    EOT
  ]
}