# Insight-Agent - Cloud Engineering Solution

## Repository Structure
```
insight-agent/
├── README.md
├── app/
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── .github/
│   └── workflows/
│       └── deploy.yml
└── scripts/
    └── setup.sh
```

---

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │   Cloud Build    │    │  Artifact Reg   │
│                 ├────┤   CI/CD Pipeline ├────┤   Container     │
│   Code Changes  │    │                  │    │   Images        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                └────────────────────────┼─────────┐
                                                         │         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────▼─────────▼┐
│   Private VPC   │    │      IAM         │    │    Cloud Run      │
│   Network       ├────┤   Service Acct   ├────┤   insight-agent   │
│                 │    │   Least Privilege│    │   (Private)       │
└─────────────────┘    └──────────────────┘    └───────────────────┘
```

**Services Used:**
- **Cloud Run**: Serverless container platform for the Python API
- **Artifact Registry**: Container image storage
- **Cloud Build**: CI/CD automation
- **IAM**: Security and access management
- **VPC**: Network isolation

---

## Design Decisions

**Why Cloud Run?**
- Serverless, fully managed platform
- Automatic scaling to zero
- Built-in security features
- Cost-effective for variable workloads

**Security Approach:**
- Private Cloud Run service (no public access)
- Dedicated service account with minimal permissions
- Container runs as non-root user
- Network isolation via VPC

**CI/CD Strategy:**
- GitHub Actions for simplicity and GitHub integration
- Automated on main branch pushes
- Multi-stage pipeline: Test → Build → Push → Deploy


## Setup and Deployment Instructions

# NOTE: since this is just an interview application here is how I would go about it.


### Prerequisites
1. **GCP Account** with billing enabled
2. **GitHub Account** 
3. **Local Environment** with:
   - `gcloud` CLI installed
   - `terraform` installed
   - `docker` installed

### Initial Setup

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd insight-agent
   ```

2. **GCP Project Setup**
   ```bash
   # Create new project (optional)
   gcloud projects create YOUR_PROJECT_ID
   
   # Set project
   gcloud config set project YOUR_PROJECT_ID
   
   # Enable billing
   # (Do this via GCP Console)
   ```

3. **Service Account for CI/CD**
   ```bash
   # Create service account
   gcloud iam service-accounts create github-actions \
     --display-name="GitHub Actions SA"
   
   # Grant necessary roles
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/run.admin"
   
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/artifactregistry.admin"
   
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/iam.serviceAccountUser"
   
   # Create and download key
   gcloud iam service-accounts keys create key.json \
     --iam-account=github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com
   ```

4. **GitHub Secrets Configuration**
   Add these secrets to your GitHub repository:
   - `GCP_PROJECT_ID`: Your GCP project ID
   - `GCP_SA_KEY`: Contents of the `key.json` file

5. **Local Development Setup**
   ```bash
   # Copy and configure terraform variables
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your project details
   
   # Initialize Terraform
   terraform init
   ```

### Deployment

1. **Initial Infrastructure Deployment**
   ```bash
   cd terraform
   terraform plan
   terraform apply
   ```

2. **Application Deployment**
   ```bash
   # Push to main branch triggers automatic deployment
   git add .
   git commit -m "Initial deployment"
   git push origin main
   ```

### Testing the Service

```bash
# Get service URL from Terraform output
SERVICE_URL=$(cd terraform && terraform output -raw service_url)

# Test the API (requires authentication)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
     -H "Content-Type: application/json" \
     -d '{"text":"I love cloud engineering!"}' \
     "$SERVICE_URL/analyze"
```

### Security Notes

- The Cloud Run service is **private** and requires authentication
- Use `gcloud auth print-identity-token` for testing
- Service account follows principle of least privilege
- Container runs as non-root user
- No secrets are committed to repository

### Monitoring and Troubleshooting

```bash
# View Cloud Run logs
gcloud run services logs read insight-agent --region=us-central1

# Check service status
gcloud run services describe insight-agent --region=us-central1
```

---

This solution provides a complete, production-ready deployment pipeline following cloud engineering best practices with security, scalability, and automation built-in.