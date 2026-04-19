resource "null_resource" "gateway_api_crds" {
  depends_on = [module.eks]

  triggers = {
    crd_version = "v1.2.0"
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x ./kubectl
      aws eks update-kubeconfig --region ap-southeast-2 --name ${module.eks.cluster_name}
      ./kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
    EOT
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  
  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [module.eks]
}

resource "helm_release" "nginx_gateway" {
  name             = "nginx-gateway"
  repository       = "oci://ghcr.io/nginxinc/charts"
  chart            = "nginx-gateway-fabric"
  namespace        = "nginx-gateway"
  create_namespace = true

  values = [
    yamlencode({
      service = {
        type                  = "LoadBalancer"
        externalTrafficPolicy = "Cluster"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    null_resource.gateway_api_crds
  ]
}