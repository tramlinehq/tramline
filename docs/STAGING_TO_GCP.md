# Moving to Kamal via GCP

In this document I am laying out in detail how we should go about setting up stuff (infra and kamal-specific) to ensure successful deployment on GCP via kamal (v2).

## Google Cloud Platform (GCP) Compute Engine VM Setup Guide

This documentation provides step-by-step instructions for:

1. Creating a Compute Engine VM instance.
2. Reserving and assigning a static (permanent) external IP address.
3. Configuring firewall rules to allow HTTP, HTTPS, and load balancer health check traffic.
4. Adding an SSH public key for secure VM access.

---

### 1. Create a VM Instance

**Via GCP Console UI:**

- Go to the [Compute Engine VM instances page](https://console.cloud.google.com/compute/instances).
- Click **Create Instance**.
- Configure the instance (name, region, machine type, boot disk, etc.).
- Under "Firewall", check **Allow HTTP traffic** and **Allow HTTPS traffic**.
- Click **Create**.

**Via gcloud CLI:**

```sh
gcloud compute instances create INSTANCE_NAME \
    --zone=ZONE \
    --machine-type=MACHINE_TYPE \
    --image-family=IMAGE_FAMILY \
    --image-project=IMAGE_PROJECT \
    --tags=http-server,https-server
```

---

### 2. Reserve and Assign a Static External IP

This is important because GCP by default gives us a dynamic IP for the VM instance and so our kamal scripts will go haywire. So it's paramount that we ensure that the IP doesn't change and it can correctly referenced in the kamal script(s).

**Via GCP Console UI:**

- Go to the [VPC network > External IP addresses](https://console.cloud.google.com/networking/addresses/list).
- Click **Reserve static address**.
- Enter a name, select the region, and click **Reserve**.
- After creation, associate the IP with your VM instance.

**Via gcloud CLI:**

```sh
gcloud compute addresses create ADDRESS_NAME --region=REGION
gcloud compute instances add-access-config INSTANCE_NAME \
    --zone=ZONE \
    --address=STATIC_IP_ADDRESS
```

---

### 3. Allow HTTP, HTTPS, and Health Check Traffic

**Via GCP Console UI:**

- Go to [VPC network > Firewall rules](https://console.cloud.google.com/networking/firewalls/list).
- Click **Create Firewall Rule**.
- Set the following:
    - **Targets:** All instances in the network or specify by tag.
    - **Source IP ranges:** `0.0.0.0/0` for HTTP/HTTPS, or restrict as needed.
    - **Protocols and ports:** `tcp:80,443` for HTTP/HTTPS.
- For health checks, add a rule allowing traffic from `130.211.0.0/22` and `35.191.0.0/16` (Google health check IPs) to the required ports.

**Via gcloud CLI:**

```sh
gcloud compute firewall-rules create allow-http \
    --allow tcp:80 --target-tags=http-server
gcloud compute firewall-rules create allow-https \
    --allow tcp:443 --target-tags=https-server
gcloud compute firewall-rules create allow-health-check \
    --allow tcp:80,tcp:443 \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=INSTANCE_TAG
```

---

### 4. Add an SSH Public Key for VM Access

**Via GCP Console UI:**

- Go to the [Compute Engine VM instances page](https://console.cloud.google.com/compute/instances).
- Click the instance name.
- Click **Edit**.
- Scroll to **SSH Keys** and add your **public** SSH key.
- Save.

**Via gcloud CLI:**

- Add your public key to the project or instance metadata:

```sh
gcloud compute instances add-metadata INSTANCE_NAME \
    --metadata ssh-keys="USERNAME:PUBLIC_KEY_CONTENT"
```

- Use your private key locally to connect:

```sh
ssh -i /path/to/private_key USERNAME@EXTERNAL_IP
```

---

**References:**

- [GCP Compute Engine Documentation](https://cloud.google.com/compute/docs)
- [gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference/compute/)

# Kamal (v2) Deployment Documentation

This project uses **Kamal v2** for deployment orchestration. Most of the Kamal-specific configuration is located in the `.kamal` directory. The primary configuration file is `config/deploy.yml`, which defines deployment targets, roles, and environment-specific settings. For detailed configuration options, refer to the [Kamal v2 documentation](https://kamal-deploy.org/docs/installation/). Just keep in mind that accessories need to be started on the VM manually but the github workflow we have now does it automatically.

## Secrets Management

Sensitive values and secrets are managed using **Google Secret Manager**. Many required secrets are already stored there and referenced in the Kamal configuration.

### Storing Secrets with Google Cloud CLI

To add a new secret to Google Secret Manager, use the following command:

```sh
gcloud secrets create SECRET_NAME --replication-policy="automatic"
```

To add a secret version (the actual secret value):

```sh
echo -n "YOUR_SECRET_VALUE" | gcloud secrets versions add SECRET_NAME --data-file=-
```

To grant your VM or service account access to the secret:

```sh
gcloud secrets add-iam-policy-binding SECRET_NAME \
    --member="serviceAccount:SERVICE_ACCOUNT_EMAIL" \
    --role="roles/secretmanager.secretAccessor"
```

To retrieve a secret value:

```sh
gcloud secrets versions access latest --secret=SECRET_NAME
```

For more details, see the [Secret Manager documentation](https://cloud.google.com/secret-manager/docs).

## Debugging Tips and commands

- To properly view logs of the prod instance running on the VM

```sh

docker exec <-container_id-> tail -f log/production.log

```

- Where is the location of the `kamal` deploy lockfile which sometimes gets affected if deployments fail and there's no graceful shutdown

```sh

home/<--SSH key name-->/.kamal

# e.g right now for key named 
# sam-staging-key it is
# home/sam-staging-local/.kamal

```

## TODO list to take things to Prod

- [ ] change to a tramline SSH key - not sam staging
- [ ] write our own version db prepare => extend the rake task
- [ ] move current staging data on to VM
- [ ] Support SSL for Proxy and accessories
