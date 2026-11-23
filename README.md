# AWS EKS GitOps Platform

An automated, event-driven GitOps platform deployed on AWS (EKS + Terraform + ArgoCD).

I built this architecture not just to host an application, but to actively stress test how cloud-native systems handle failure. This repository documents the journey of solving Day-0 pipeline race conditions, debugging cross-node VPC networking issues, and evolving traditional infrastructure into a fully automated, self-healing GitOps system.

A significant part of this project came from debugging real issues on live AWS infrastructure, iterating through hundreds of CI/CD pipeline runs. This included debugging `workflow_run` race conditions in GitHub Actions, coordinating Terraform cross-dependencies, and tracing 504 Gateway Timeouts caused by VPC CNI behavior, misconfigured security groups, and cross-node EKS networking failures.

See **Project Evolution** below for the full journey from Docker to EKS GitOps.

## Architecture Overview
<img width="3179" height="1090" alt="581249866-7d304c6a-6a37-43d7-8f14-782f600a3ab7" src="https://github.com/user-attachments/assets/b0f1795c-4603-4f16-b869-ae8289f561ff" />

## Key Highlights

- Decoupled CI/CD pipelines (GitHub Actions) with event-driven triggers
- GitOps deployment using ArgoCD (App of Apps pattern)
- Terraform based AWS infrastructure (EKS, RDS, Cognito, VPC)
- Idempotent pipelines (ECR image check + concurrency control)
- Zero Trust security using IRSA (OIDC, no static credentials)
- Observability stack PLG (Prometheus, Loki, Grafana)
- Real world issues solved: race conditions, networking, pipeline coordination

## System Demonstrations

### 1. GitOps Reconciliation

Demonstrating ArgoCD's App of Apps pattern reacting to a merged Pull Request. Infrastructure state is strictly bound to the GitHub repository. Upon a Git push, the controller automatically detects configuration drift and synchronizes the EKS cluster to the desired state with zero manual `kubectl` intervention.

<p align="center">
  <img src="https://github.com/user-attachments/assets/d156eb8c-b80b-47ac-a0b7-0f7b59d1c2f5" alt="Pipeline Idempotency Demo" width="900"/>
</p>

> [!NOTE]
> A manual UI refresh is used in this demonstration to bypass ArgoCD's default 3-minute Git polling interval for immediate verification.

### 2. Event-Driven CI/CD

To prevent immutable tag collisions and optimize compute, the CI pipeline queries AWS ECR for existing commit-SHA images before initiating Docker builds. Concurrency groups with `cancel-in-progress: false` ensure stateful pipelines queue rather than collide, protecting GitOps PR integrity and the bootstrap sequence.

<p align="center">
  <img src="https://github.com/user-attachments/assets/48c606b4-7939-48e1-97b8-f99c82f51730" alt="Pipeline Idempotency Demo" width="900"/>
</p>

### 3. Observability. PLG (Prometheus, Loki, Grafana)

Real-time cluster observability using the Prometheus stack. Metrics are continuously scraped from pods and visualized in Grafana, shown here reacting to a simulated traffic spike. You can see pod-level CPU, memory, and network usage across the webapp namespace in real time. Grafana dashboards are provisioned declaratively via ConfigMaps.

<p align="center">
  <img src="https://github.com/user-attachments/assets/fd3828e2-9785-41c2-8f44-da54412678d0" alt="Pipeline Idempotency Demo" width="900"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/0c0d45d3-55af-43e2-bb05-4bf87320d83a" alt="Pipeline Idempotency Demo" width="900"/>
</p>

-----

## Project Evolution: From Docker to GitOps

This project evolved over time rather than being built in a single pass. Each phase was a response to limitations or issues in the previous setup. It is the result of iterative learning, where each phase solved the bottlenecks of the previous one. You can trace this evolution through the repository branches and folders.
All earlier implementations are kept in the `archive/v1-development-logs` branch, including experiments, failed attempts, and intermediate setups. 

Here are all the stages:

- **Stage 1: The Baseline (Docker & Manual AWS)**
    
    Started by simply containerizing the Flask/React application and connecting it to basic managed AWS services. Everything was configured manually via the AWS Console and CLI to understand networking and IAM basics. At this stage, deployments were slow and error prone.
    
- **Stage 2: IaC & Configuration Management (`archive/ansible-non-compose-deployment`)**
    
    Transitioned from manual clicks to Infrastructure as Code (IaC). I used **Terraform** to automatically provision AWS EC2 instances, and wrote an **Ansible** playbook (`deploy-app-compose.yml`) for idempotent server configuration. I built a CI/CD pipeline that fully automated the EC2 deployment, utilizing a dynamic Docker Compose template (`docker-compose.prod.yml.j2`) and automated health checks. While this worked, maintaining long-lived EC2 instances and debugging configuration drift became painful, especially when something broke after partial updates.
    
- **Stage 3: Serverless Compute**
    
    Moved to AWS Fargate to remove host-level management and simplify scaling. This phase focused on understanding task definitions, managed scaling, and running applications without host-level maintenance.
	This reduced operational overhead, but introduced new limitations around networking visibility and debugging, which became harder compared to EC2.
	
- **Stage 4: The Kubernetes Shift (`k8s/` folder)**
    
    Started working with raw Kubernetes manifests and deployed locally using kubectl.
	This phase involved a lot of trial and error, especially around Services, networking, and understanding how pods communicate internally.
    This step was critical for deeply understanding Pods, Services, and Kubernetes networking before introducing the complexities of the cloud.
    
- **Stage 5: Cloud-Native GitOps (`main` branch)**
    
    Final stage of the project. Migrated the local k8s cluster to AWS EKS, replaced raw manifests with Helm charts, and moved to a GitOps model using ArgoCD. This improved deployment consistency, but also introduced new challenges, mainly CI/CD race conditions, Terraform dependency issues, and pipeline coordination. Most of these were solved iteratively and can be seen in the commit history and GitHub Actions runs. 

> [!NOTE]
> Development was conducted directly against live AWS infrastructure without a dedicated staging environment, which explains the iterative commit history on `main`. In a team setting, this would be replaced with branch protection rules, PR based workflows, and a separate staging environment.

 ----- 

### Engineering Decisions & Architectural Challenges

Building this platform required solving real deployment bottlenecks and race conditions encountered during development. Key implementations include:

- **Decoupled CI/CD & Bootstrapping (Day-0):**  
    To align with GitOps principles, the deployment pipeline is split into decoupled workflows (`ci-app.yml` and `cd-infra.yml`). To handle "Day-0" scenarios, the application pipeline checks an `infra_ready` state and skips Docker builds if infrastructure is still provisioning, instead of failing. Once Terraform completes, a `workflow_run` event triggers the application pipeline to fetch live configuration (e.g., Cognito IDs) and proceed with the build.
- **Cross-Node VPC Networking & Gateway API Routing:**  
    Debugged 504 errors in an EKS environment caused by restrictive Security Groups and CNI misconfigurations. Restored connectivity between node groups and configured the Gateway API (Nginx) to correctly handle NLB traffic flow to backend pods.
- **Pipeline Idempotency & Compute Optimization:**  
    To prevent AWS ECR immutable tag collisions and reduce unnecessary builds, the pipeline checks for existing Git-SHA images before building. If the image exists, the build is skipped. Stateful pipelines queue rather than cancel concurrent runs, protecting write operations and the workflow_run bootstrap sequence.
- **Continuous GitOps Manifest Validation:**  
    A dedicated validation pipeline (`gitops-validate.yml`) enforces `yamllint` and `helm lint` checks on all changes, preventing invalid configurations from reaching ArgoCD.
- **Zero-Trust Security (IRSA) & TLS Handling:**  
    The cluster operates without static AWS credentials. Pods assume IAM roles via OIDC (IRSA) to securely access secrets through the External Secrets Operator. Public traffic is routed through a Network Load Balancer (NLB) with TLS handling configured to reduce load on EKS nodes.
- **Immutable Git-SHA Tagging:**  
    Docker images are tagged using Git-SHA to ensure immutability and direct traceability between source code and deployed artifacts.
- **Stateless Compute & Spot Instances:**  
    Used EC2 Spot Instances to cut costs, moving application state to RDS and DynamoDB. This keeps the system stateless so it can handle node interruptions without losing data.
- **Observability & Dashboarding (PLG Stack):**  
    Deployed Prometheus, Loki, and Grafana via ArgoCD-managed Helm charts with auto-sync and self-healing enabled. Dashboards for pod-level CPU, memory, and network metrics are defined as Kubernetes ConfigMaps and automatically picked up by the Grafana, no manual setup in the UI.

-----  
## Deployment Flow
Operating strictly on GitOps principles, daily operations require zero manual `terraform apply` or `kubectl deploy` execution. The lifecycle flows through three dedicated, event-driven pipelines:

1. **Infrastructure Provisioning (`cd-infra.yml`):** Changes to the `terraform/` directory trigger infrastructure updates. Upon successful completion, this pipeline automatically signals the application workflow.
2. **Application CI & Build (`ci-app.yml`):** Triggered by app code pushes or infrastructure completion. It runs Python/React tests, securely extracts live AWS Cognito IDs from the HCP Terraform state, and idempotently builds/pushes Docker images to ECR.
3. **Automated Manifest PR Generation:** Upon a successful push to ECR, a GitHub Actions bot dynamically updates the Helm `values.yaml` with the newly generated Git-SHA tag and automatically opens a Pull Request.
4. **Validation & GitOps Sync (`gitops-validate.yml`):** The Pull Request is linted for Helm and YAML syntax compliance. Upon merge, ArgoCD detects repository drift and automatically synchronizes the live EKS cluster to the newly declared state.

## Core Technology Stack

| Layer | Technology |
| :--- | :--- |
| **Cloud Provider** | AWS (EKS, RDS, DynamoDB, Cognito, VPC, NLB) |
| **Infrastructure as Code** | Terraform (Modular design, HCP Remote State) |
| **CI/CD Automation** | GitHub Actions (Decoupled, Event-Driven, Concurrency Controlled) |
| **GitOps Controller** | ArgoCD (Automated sync, App-of-Apps pattern) |
| **Security & Identity** | AWS IRSA (OIDC), External Secrets Operator |
| **Application** | Python (Flask), React.js, PostgreSQL, Docker |

-----

## Architecture Implementation Patterns

This repository showcases three distinct deployment methodologies, demonstrating technical depth across the configuration management and cloud-native orchestration lifecycle.

| Architecture Pattern | Primary Focus | Branch | Key Technical Components |
| :--- | :--- | :--- | :--- |
| **Cloud-Native GitOps** | Current Standard | `main` | EKS, Helm, ArgoCD, OIDC/IRSA, External Secrets, Spot Instances. |
| **Hardened Network** | Security & Compliance | `archive/AWS-SSM-private-endpoints` | VPC Endpoints, Private Subnets, AWS SSM for secure, SSH-free access. |
| **Automated server configuration** | IaC + Config Management | `archive/ansible-deployment` | Terraform provisioning, Ansible idempotent server setup, standalone EC2. |

_____
