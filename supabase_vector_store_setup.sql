-- ========= 1) Prereqs =========
create extension if not exists vector;

-- ========= 2) Table =========
-- Keep in `public` for simplicity. Adjust vector dimension if your model differs.
create table if not exists public.car_sales_knowledge_base (
  id          bigserial primary key,
  content     text            not null,
  embedding   vector(1536)    not null,   -- <<< change dimension if needed
  metadata    jsonb           not null default '{}'::jsonb,
  created_at  timestamptz     not null default now()
);

-- ========= 3) REQUIRED RPC for n8n's Supabase Vector Store =========
-- Signature expected by n8n: public.match_documents(filter jsonb, match_count int, query_embedding vector)
create or replace function public.match_documents(
  filter jsonb,
  match_count int,
  query_embedding vector
)
returns table(
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language sql
stable
as $$
  select
    d.id,
    d.content,
    d.metadata,
    1 - (d.embedding <=> query_embedding) as similarity
  from public.car_sales_knowledge_base d
  -- If filter is null or {}, return all; otherwise metadata must contain the filter
  where (filter is null or filter = '{}'::jsonb or d.metadata @> filter)
  order by d.embedding <=> query_embedding
  limit match_count
$$;

-- ========= 4) OPTIONAL helper RPCs =========

-- (A) Parametrized filtering without JSON construction in the client.
-- Put required params first (Postgres rule re: defaults).
create or replace function public.match_documents_params(
  match_count int,
  query_embedding vector,
  p_color text default null,
  p_min_stock int default null,
  p_location text default null
)
returns table(
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language sql
stable
as $$
  select
    d.id,
    d.content,
    d.metadata,
    1 - (d.embedding <=> query_embedding) as similarity
  from public.car_sales_knowledge_base d
  where (p_color is null or d.metadata->>'color' = p_color)
    and (p_min_stock is null or coalesce((d.metadata->>'stock_qty')::int, 0) >= p_min_stock)
    and (p_location is null or d.metadata->>'location' = p_location)
  order by d.embedding <=> query_embedding
  limit match_count
$$;

-- (B) Simple insert helper if you want to ingest via RPC instead of REST.
create or replace function public.upsert_document(
  p_content text,
  p_embedding vector,
  p_metadata jsonb
) returns bigint
language sql
volatile
as $$
  insert into public.car_sales_knowledge_base (content, embedding, metadata)
  values (p_content, p_embedding, coalesce(p_metadata, '{}'::jsonb))
  returning id;
$$;

-- ========= 5) (Optional) RLS / permissions =========
-- If you enable RLS, add policies or use a service-role key from n8n.
-- alter table public.car_sales_knowledge_base enable row level security;
-- Example permissive policies (only if you understand the exposure):
-- create policy "allow_select" on public.car_sales_knowledge_base for select using (true);
-- create policy "allow_insert" on public.car_sales_knowledge_base for insert with check (true);

-- ========= 6) Refresh PostgREST schema cache (so RPCs are visible immediately) =========
select pg_notify('pgrst', 'reload schema');


