# 🏎️ Formula 1 Tracker Dashboard

A real-time Formula 1 dashboard tracking driver standings, constructor standings, race schedules, and historical race results — built entirely as a **static web app with zero backend infrastructure**.

Live at: **[witty-pebble-003877210.6.azurestaticapps.net](https://witty-pebble-003877210.6.azurestaticapps.net)**

---

## 🚀 Architecture

The application is intentionally simple and **100% serverless with zero recurring compute cost**:

```
Browser → Azure Static Web App (Free Tier)
              └─ app.js calls Jolpica F1 API directly (CORS-open, public, no auth)
```

There is no backend proxy layer. The browser fetches live F1 data directly from the community-maintained **[Jolpica F1 API](https://api.jolpi.ca)** (Ergast-compatible), which sets `Access-Control-Allow-Origin: *`.

**Infrastructure & CI/CD:**
- Infrastructure as Code managed by **Terraform** (only 2 Azure resources: Resource Group + Static Web App)
- CI/CD via **GitHub Actions**, authenticated to Azure via **OIDC (no stored secrets)**

---

## 💡 Key Engineering Decisions

### 1. Eliminated the Backend Proxy Layer

The original architecture routed all API calls through **Azure Functions (PowerShell)** acting as stateless proxies to Jolpica. Since Jolpica is a free, public, CORS-open API with no authentication requirement, the proxy added cost and latency with zero benefit. The Functions were removed entirely — data normalisation (mapping Jolpica's nested JSON to UI-ready objects) moved into `app.js`.

**Azure resources removed:** `azurerm_windows_function_app`, `azurerm_service_plan`, `azurerm_storage_account`

### 2. Zero-Cost Footprint

The only Azure resource is the **Static Web App on the Free Tier** — genuinely $0.00/month. No compute, no storage, no consumption billing.

### 3. Zero-Trust CI/CD Security

GitHub Actions authenticates to Azure via Federated Credentials (OIDC). No long-lived secrets or connection strings are stored anywhere.

### 4. AI-Assisted Development

This project was developed with LLMs as active pair-programming collaborators, used for architecture decisions, refactoring, Terraform configuration, and CI/CD pipeline design.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | HTML, CSS, JavaScript (Vanilla) |
| **Data Source** | [Jolpica F1 API](https://api.jolpi.ca) (public, no auth) |
| **Hosting** | Azure Static Web Apps (Free Tier) |
| **IaC** | Terraform |
| **CI/CD** | GitHub Actions (OIDC auth) |
| **Cloud** | Microsoft Azure |

---

## 📂 Repository Structure

```text
├── .github/
│   └── workflows/
│       ├── frontend.yml     # Deploys src/ to Azure Static Web App
│       └── terraform.yml    # Provisions / destroys Azure infrastructure
├── src/
│   ├── index.html           # Dashboard UI
│   ├── app.js               # Data fetching & DOM rendering (calls Jolpica directly)
│   └── styles.css           # F1-themed dark mode styling
└── terraform/
    ├── main.tf              # Resource Group + Static Web App only
    ├── variables.tf         # Location variable
    └── providers.tf         # AzureRM provider + remote state backend
```

---

## 🚀 Deploy Your Own

**1. Clone the repository:**

```bash
git clone https://github.com/Vatsal2307/f1-tracker-dashboard.git
cd f1-tracker-dashboard
```

**2. Provision infrastructure:**

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

This creates one Resource Group and one Static Web App (Free Tier).

**3. Configure GitHub Actions (OIDC):**

- Create a Federated Credential in Microsoft Entra ID pointing to your GitHub repo.
- Add these secrets to your GitHub repository:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
- Push to `main` — the `frontend.yml` workflow will deploy `src/` automatically.

> No backend deployment needed. No Function App. No secrets beyond the OIDC identity.
