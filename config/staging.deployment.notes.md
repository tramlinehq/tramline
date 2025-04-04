# Tramline Site - Staging Deployment

Quick reference for deploying to staging on GCP using [Kamal](https://kamal-deploy.org/).

- **NEVER** commit `.kamal/secrets.staging` to git

## Prerequisites

1. **GCP Setup**
   - Project with Compute Engine, Cloud DNS, Container Registry, Logging, and Monitoring APIs enabled
   - Service account with necessary roles (Compute Engine Admin, Cloud DNS Admin, Storage Admin)
   - Domain registered and DNS zone created in Cloud DNS

2. **Local Tools**
   - `gcloud` CLI
   - `kamal` CLI
   - Docker
   - Ruby 3.3.6

## Quick Start

1. **Configure Secrets**
   ```bash
   mkdir -p .kamal
   touch .kamal/secrets.staging
   chmod 600 .kamal/secrets.staging
   ```
   Update `.kamal/secrets.staging` with:
   - GCP service account JSON
   - Rails master key
   - Database and Redis credentials
   - GCP project details

2. **Deploy**
   ```bash
   kamal build staging
   kamal push staging
   kamal deploy staging
   ```

3. **Verify**
   ```bash
   kamal healthcheck staging
   kamal logs staging
   ```

## Key Commands

```bash
# Check status
kamal status staging

# SSH into instance
kamal app staging

# View environment
kamal env staging

# Restart services
kamal restart staging

# View logs
kamal logs staging
```
