resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "example" {
  private_key_pem = tls_private_key.example.private_key_pem

  subject {
    common_name  = "api.my-webapp.internal"
    organization = "My DevOps project"
  }

  validity_period_hours = 720 # Valid for 30 days

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

output "ssl_cert_pem" {
  description = "The public SSL certificate content"
  value       = tls_self_signed_cert.example.cert_pem
  sensitive   = true
}

output "ssl_key_pem" {
  description = "The private SSL key content"
  value       = tls_private_key.example.private_key_pem
  sensitive   = true
}