-- Purpose: inspect order and invoice exception plans.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_sme_procure.purchase_orders;
ANALYZE ug_sme_procure.purchase_order_lines;
ANALYZE ug_sme_procure.supplier_invoices;
EXPLAIN (COSTS, VERBOSE)
SELECT purchase_order_id,SUM(ordered_quantity*unit_price+tax_amount)
FROM ug_sme_procure.purchase_order_lines GROUP BY purchase_order_id;
EXPLAIN (COSTS, VERBOSE)
SELECT invoice_ref,invoice_amount FROM ug_sme_procure.supplier_invoices WHERE status IN ('received','exception');
