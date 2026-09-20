# 🏎️ Serverless Formula 1 Tracker Dashboard

A highly available, real-time serverless dashboard that tracks Formula 1 driver standings, constructor standings, race schedules, and historical race results.

This project was intentionally engineered to maintain a **strictly zero-cost footprint** on Microsoft Azure by leveraging a stateless API proxy pattern, edge caching, and serverless consumption tiers, eliminating all recurring database and compute costs.

---

## 🚀 Architecture

This application is decoupled into three primary automated layers:

1. **Presentation Layer (Frontend):**
* Built with pure HTML/CSS/JavaScript.
* Hosted globally on **Azure Static Web Apps (Free Tier)**.


2. **Proxy API Layer (Backend):**
* Serverless APIs built using **Azure Functions (PowerShell Core 7.4)** on the Y1 Consumption plan.
* Acts as a stateless proxy fetching live F1 telemetry on demand from the community-driven **[Jolpica F1 API](https://www.google.com/search?q=https://api.jolpi.ca/&utm_source=gemini)**.


3. **Infrastructure & CI/CD Layer:**
* Infrastructure as Code (IaC) is entirely managed by **Terraform**.
* Continuous Integration and Continuous Deployment (CI/CD) pipelines run on **GitHub Actions**, authenticated securely to Azure via **OIDC (OpenID Connect)**.



---

## 💡 Key Engineering Optimizations

### 1. Stateless "Zero-Cost" Backend

The initial architecture utilized an Azure SQL Database with automated data ingestion scripts. To optimize for cost and maintenance, the database was completely decommissioned. The backend was refactored into a **stateless proxy**, dropping the cloud bill to $0.00 while drastically reducing architectural complexity.

### 2. Browser-Side Edge Caching

Because F1 standings only update once a week, querying the Jolpica API on every page load wastes network bandwidth. The Azure Functions are configured to inject strict `Cache-Control: public, max-age=14400` headers, caching the F1 data locally in the user's browser for 4 hours. This ensures instant page loads on subsequent visits and minimizes outbound function executions.

### 3. Zero-Trust CI/CD Security

Deployment pipelines are fully passwordless. GitHub Actions interacts with Azure via Federated Credentials (OIDC), meaning no long-lived secrets or connection strings are stored in GitHub repository secrets.

### 4. AI-Driven Development

This project was developed in tandem with Large Language Models (LLMs) acting as an active pair-programming collaborator. AI was leveraged to rapidly iterate on PowerShell proxy scripts, diagnose CORS security blocks, optimize Terraform resource deployments, and accelerate the overall software development lifecycle.

---

## 🛠️ Tech Stack

* **Cloud Provider:** Microsoft Azure
* **Frontend:** HTML, CSS, JavaScript (Vanilla)
* **Backend:** PowerShell Core 7.4
* **Compute:** Azure Functions (Serverless Consumption)
* **Hosting:** Azure Static Web Apps
* **Infrastructure as Code (IaC):** Terraform
* **CI/CD:** GitHub Actions
* **External API:** Jolpica F1 (Ergast compatible)

---

## 📂 Repository Structure

```text
├── .github/
│   └── workflows/          # GitHub Actions deployment pipelines (TF, Frontend, Backend)
├── functions/
│   ├── GetConstructorStandings/ # Proxy API for Constructor points
│   ├── GetRaceResults/          # Proxy API for historical race data
│   ├── GetSchedule/             # Proxy API for the F1 calendar
│   └── GetStandings/            # Proxy API for Driver points
├── src/                    # Frontend HTML/CSS/JS source code
└── terraform/              # Terraform state and main.tf configurations

```

---

## 🚀 Getting Started

If you want to deploy a clone of this architecture to your own Azure tenant:

**1. Clone the repository:**

```bash
git clone https://github.com/Vatsal2307/f1-tracker-dashboard.git
cd f1-tracker-dashboard

```

**2. Provision the Infrastructure:**

```bash
cd terraform
terraform init
terraform apply -auto-approve

```

**3. Configure GitHub Actions (OIDC):**

* Set up a Federated Credential in Microsoft Entra ID pointing to your GitHub repository.
* Add your `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` to your GitHub Repository variables.
* The GitHub Actions pipelines will automatically detect pushes to `main` and deploy the frontend and backend layers into the newly provisioned Terraform resources.
