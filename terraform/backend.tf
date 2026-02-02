terraform {
  cloud {
    hostname = "app.terraform.io"
    organization = "westlaw_personal"

    workspaces {
      name = "aws-cloud-native-webapp"
    }
  }
}