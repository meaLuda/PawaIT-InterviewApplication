terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
  ])
  
  project = var.project_id
  service = each.value
  
  disable_on_destroy = false
}

# Artifact Registry repository
resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.region
  repository_id = "insight-agent-repo"
  description   = "Container images for Insight-Agent"
  format        = "DOCKER"
  
  depends_on = [google_project_service.apis]
}

# Service account for Cloud Run
resource "google_service_account" "cloud_run_sa" {
  project      = var.project_id
  account_id   = "insight-agent-sa"
  display_name = "Insight Agent Service Account"
  description  = "Service account for Insight-Agent Cloud Run service"
}

# IAM binding for service account (minimal permissions)
resource "google_project_iam_member" "cloud_run_sa_binding" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Cloud Run service
resource "google_cloud_run_v2_service" "insight_agent" {
  project  = var.project_id
  name     = var.service_name
  location = var.region
  
  deletion_protection = false
  
  template {
    service_account = google_service_account.cloud_run_sa.email
    
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}/insight-agent:${var.image_tag}"
      
      ports {
        container_port = 8080
      }
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
      
      env {
        name  = "PORT"
        value = "8080"
      }
    }
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }
  
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
  
  depends_on = [google_project_service.apis]
}

# IAM policy for private access only
resource "google_cloud_run_service_iam_binding" "noauth" {
  project  = var.project_id
  location = google_cloud_run_v2_service.insight_agent.location
  service  = google_cloud_run_v2_service.insight_agent.name
  role     = "roles/run.invoker"
  
  members = [
    "serviceAccount:${google_service_account.cloud_run_sa.email}",
  ]
}