-- Card-Issuer Dispute & Chargeback Ops Analytics (SQLite)
-- Focus on chargebacks and dispute operations KPIs

-- Q1) Monthly dispute volume
SELECT strftime('%Y-%m', c.created_at) AS ym,
       COUNT(*) AS disputes
FROM chargebacks c
GROUP BY ym
ORDER BY ym;

-- Q2) Win/Loss/Open rates by month
SELECT strftime('%Y-%m', c.created_at) AS ym,
       SUM(CASE WHEN c.outcome='won' THEN 1 ELSE 0 END) AS won,
       SUM(CASE WHEN c.outcome='lost' THEN 1 ELSE 0 END) AS lost,
       SUM(CASE WHEN c.outcome='open' THEN 1 ELSE 0 END) AS open_cnt,
       ROUND(100.0*SUM(CASE WHEN c.outcome='won' THEN 1 ELSE 0 END)/COUNT(*),2)  AS won_pct,
       ROUND(100.0*SUM(CASE WHEN c.outcome='lost' THEN 1 ELSE 0 END)/COUNT(*),2) AS lost_pct
FROM chargebacks c
GROUP BY ym
ORDER BY ym;

-- Q3) Dispute exposure (amount under dispute) by month
SELECT strftime('%Y-%m', t.txn_datetime) AS ym,
       ROUND(SUM(t.amount),2) AS disputed_amount
FROM chargebacks c
JOIN transactions t ON t.txn_id = c.txn_id
GROUP BY ym
ORDER BY ym;

-- Q4) Top disputed merchants (by amount & frequency)
WITH base AS (
  SELECT m.merchant_id, m.merchant_name, SUM(t.amount) AS disputed_amt, COUNT(*) AS disputes
  FROM chargebacks c
  JOIN transactions t ON t.txn_id = c.txn_id
  LEFT JOIN merchants m ON m.merchant_id = t.merchant_id
  GROUP BY m.merchant_id, m.merchant_name
)
SELECT merchant_id, merchant_name, ROUND(disputed_amt,2) AS disputed_amt, disputes
FROM base
ORDER BY disputed_amt DESC
LIMIT 20;

-- Q5) Repeat-dispute merchants in last 90 days (proxy for recurrence)
WITH cb AS (
  SELECT m.merchant_id, date(c.created_at) AS d
  FROM chargebacks c
  JOIN transactions t ON t.txn_id = c.txn_id
  JOIN merchants m ON m.merchant_id = t.merchant_id
)
SELECT merchant_id,
       COUNT(*) AS disputes_90d
FROM cb
WHERE d >= date('2025-07-31','-90 day')
GROUP BY merchant_id
HAVING disputes_90d >= 3
ORDER BY disputes_90d DESC;

-- Q6) Cross-border dispute rate (customer vs merchant country)
WITH base AS (
  SELECT c.cb_id, t.txn_datetime, cu.country AS customer_country, m.country AS merchant_country
  FROM chargebacks c
  JOIN transactions t ON t.txn_id = c.txn_id
  JOIN cards ca ON ca.card_id = t.card_id
  JOIN accounts a ON a.account_id = ca.account_id
  JOIN customers cu ON cu.customer_id = a.customer_id
  LEFT JOIN merchants m ON m.merchant_id = t.merchant_id
)
SELECT strftime('%Y-%m', txn_datetime) AS ym,
       ROUND(100.0 * SUM(CASE WHEN customer_country <> merchant_country THEN 1 ELSE 0 END) / COUNT(*), 2) AS cross_border_dispute_pct
FROM base
GROUP BY ym
ORDER BY ym;

-- Q7) Disputes by MCC category (risk mix)
SELECT mc.category_name,
       COUNT(*) AS disputes,
       ROUND(SUM(t.amount),2) AS disputed_amt
FROM chargebacks c
JOIN transactions t ON t.txn_id = c.txn_id
LEFT JOIN mcc_categories mc ON mc.mcc = t.mcc
GROUP BY mc.category_name
ORDER BY disputed_amt DESC;

-- Q8) SLA buckets — time from transaction to dispute created
-- 0-7d, 8-30d, 31-60d, 61+d
WITH durs AS (
  SELECT c.cb_id,
         (julianday(c.created_at) - julianday(t.txn_datetime)) AS days_to_dispute
  FROM chargebacks c
  JOIN transactions t ON t.txn_id = c.txn_id
)
SELECT SUM(CASE WHEN days_to_dispute BETWEEN 0 AND 7 THEN 1 ELSE 0 END)  AS d_0_7,
       SUM(CASE WHEN days_to_dispute BETWEEN 8 AND 30 THEN 1 ELSE 0 END) AS d_8_30,
       SUM(CASE WHEN days_to_dispute BETWEEN 31 AND 60 THEN 1 ELSE 0 END)AS d_31_60,
       SUM(CASE WHEN days_to_dispute > 60 THEN 1 ELSE 0 END)            AS d_61_plus
FROM durs;

-- Q9) Refund ratio for disputed merchants (amount)
WITH p AS (
  SELECT merchant_id, SUM(amount) AS purchase_amt
  FROM transactions
  WHERE txn_type='purchase' AND status='approved'
  GROUP BY merchant_id
),
r AS (
  SELECT merchant_id, -SUM(amount) AS refund_amt
  FROM transactions
  WHERE txn_type='refund' AND status='approved'
  GROUP BY merchant_id
),
dm AS (
  SELECT DISTINCT m.merchant_id
  FROM chargebacks c
  JOIN transactions t ON t.txn_id = c.txn_id
  JOIN merchants m ON m.merchant_id = t.merchant_id
)
SELECT m.merchant_id, m.merchant_name,
       ROUND(COALESCE(r.refund_amt,0) / NULLIF(p.purchase_amt,0) * 100.0, 2) AS refund_pct
FROM dm
JOIN merchants m ON m.merchant_id = dm.merchant_id
LEFT JOIN p ON p.merchant_id = dm.merchant_id
LEFT JOIN r ON r.merchant_id = dm.merchant_id
WHERE p.purchase_amt > 0
ORDER BY refund_pct DESC
LIMIT 20;

-- Q10) Customer dispute rate (which customers dispute the most)
WITH cust_cb AS (
  SELECT a.customer_id, COUNT(*) AS disputes
  FROM chargebacks c
  JOIN transactions t ON t.txn_id = c.txn_id
  JOIN cards ca ON ca.card_id = t.card_id
  JOIN accounts a ON a.account_id = ca.account_id
  GROUP BY a.customer_id
),
cust_purch AS (
  SELECT a.customer_id, COUNT(*) AS purchases
  FROM transactions t
  JOIN cards ca ON ca.card_id = t.card_id
  JOIN accounts a ON a.account_id = ca.account_id
  WHERE t.txn_type='purchase' AND t.status='approved'
  GROUP BY a.customer_id
)
SELECT c.customer_id,
       c.disputes,
       cp.purchases,
       ROUND(100.0 * c.disputes / NULLIF(cp.purchases,0),2) AS dispute_rate_pct
FROM cust_cb c
JOIN cust_purch cp ON cp.customer_id = c.customer_id
ORDER BY dispute_rate_pct DESC
LIMIT 20;

-- Q11) Gambling (MCC 7995) dispute share by month
WITH g AS (
  SELECT strftime('%Y-%m', t.txn_datetime) AS ym, COUNT(*) AS g_disputes
  FROM chargebacks c
  JOIN transactions t ON t.txn_id = c.txn_id
  WHERE t.mcc = 7995
  GROUP BY ym
),
allm AS (
  SELECT strftime('%Y-%m', t.txn_datetime) AS ym, COUNT(*) AS all_disputes
  FROM chargebacks c
  JOIN transactions t ON t.txn_id = c.txn_id
  GROUP BY ym
)
SELECT a.ym,
       COALESCE(g.g_disputes,0) AS gambling_disputes,
       a.all_disputes,
       ROUND(100.0 * COALESCE(g.g_disputes,0) / NULLIF(a.all_disputes,0),2) AS gambling_share_pct
FROM allm a
LEFT JOIN g ON g.ym = a.ym
ORDER BY a.ym;

-- Q12) Decline rate for disputed merchants (context on auth behavior)
WITH purch AS (
  SELECT date(txn_datetime) AS d, status, merchant_id
  FROM transactions
  WHERE txn_type='purchase'
),
dm AS (
  SELECT DISTINCT m.merchant_id
  FROM chargebacks c
  JOIN transactions t ON t.txn_id = c.txn_id
  JOIN merchants m ON m.merchant_id = t.merchant_id
)
SELECT strftime('%Y-%m', p.d) AS ym,
       ROUND(100.0*SUM(CASE WHEN p.status='declined' THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN p.status IN ('approved','declined') THEN 1 ELSE 0 END),0),2) AS decline_rate_pct
FROM purch p
JOIN dm ON dm.merchant_id = p.merchant_id
GROUP BY ym
ORDER BY ym;