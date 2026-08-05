-- ============================================================
-- Migration: Tambah kolom Midtrans ke tabel orders
-- Requirements: 7.1, 7.2, 7.3, 7.4
-- ============================================================

-- Tambah kolom Midtrans ke tabel orders
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS snap_token TEXT,
  ADD COLUMN IF NOT EXISTS payment_method TEXT,
  ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'unpaid',
  ADD COLUMN IF NOT EXISTS midtrans_transaction_id TEXT;

-- Constraint nilai yang diizinkan untuk payment_status
ALTER TABLE public.orders
  ADD CONSTRAINT chk_payment_status
    CHECK (payment_status IN ('unpaid', 'paid', 'failed'));

-- Constraint nilai yang diizinkan untuk payment_method
ALTER TABLE public.orders
  ADD CONSTRAINT chk_payment_method
    CHECK (payment_method IS NULL OR payment_method IN ('midtrans', 'COD'));

-- Index untuk performa webhook lookup berdasarkan snap_token
CREATE INDEX IF NOT EXISTS idx_orders_snap_token ON public.orders(snap_token)
  WHERE snap_token IS NOT NULL;
