# Card-Issuer Dispute & Chargeback Ops Analytics (SQLite)

**Topic of the project:** Disputes/chargebacks analytics for a *card-issuing fintech* with multi-country customers and merchants.  
**Goal:**  Analyze disputes and chargebacks to:

  -Identify which merchants or categories cause the most disputes //
  -Monitor win/loss rates 
  -Track SLA performance
  -Spot high-risk patterns (repeat offenders, high refund rates, cross-border disputes)
  -Give management data to improve policies (like blocking risky merchants or adding extra checks)



## How to run (100% in browser)
1. Open https://sqliteonline.com/
2. **File → Open DB** → upload `fintech_analytics.db` (from the parent project)
3. Switch to the **SQL** tab
4. Open `queries_disputes.sql` (this folder), copy a query, paste, and **Run**

**Tables:**  
- `transactions` — includes purchases and their amounts/MCC/merchant/country  
- `chargebacks` — disputes with `created_at` and `outcome` (won/lost/open)  
- `merchants`, `mcc_categories`, `cards` → `accounts` → `customers` for joins and geography

**Time range:** 2024-01-01 → 2025-07-31 (synthetic data)

## KPIs you’ll build
- Monthly **dispute volume**, **win/loss rates**, and **exposure** (amount under dispute)
- **Top disputed merchants** and **repeat dispute rate**
- **Cross-border dispute rate** (customer ≠ merchant country)
- **High-risk MCC** disputes (e.g., 7995 Gambling, 5732 Electronics)
- **SLA buckets** (time from transaction to dispute) and **time-to-outcome** proxies
- **Refund ratio** for disputed merchants
- **Customer dispute rate** and concentration (top 1% disputers)

## What to present on GitHub
- `README.md` (this file): business framing, KPIs, and how to run
- `queries_disputes.sql`: 10–12 focused SQL questions/answers
- `results.md` (template provided): paste outputs/plots and add insights
- *(Optional)* `automation_daily_summary.gs`: Google Apps Script to email a daily dispute KPI summary from Sheets

## Extensions (optional)
- Dashboard in **Tableau/Qlik/Sheets**: dispute volume trend, win/loss, top merchants, cross‑border rate
- **Automation**: Apps Script to refresh a Google Sheet from CSV exports and email stakeholders
- **Policy ideas**: velocity soft limits, step‑up auth after top-ups, targeted declines for repeat-disputed merchants
