----- 
-- create inventory table
-----
create table if not exists inventory (
  id bigserial primary key,
  make text,
  model text,
  trim text,
  year int,
  powertrain text,
  body_style text,
  color text,
  msrp_usd int,
  stock_qty int,
  vin text unique,
  location text,
  status text,
  lead_time_weeks int,
  test_drive_available boolean,
  demo_unit boolean,
  source_url text,
  created_at timestamptz default now()
);

create or replace function public.search_inventory(
  p_color       text default null,
  p_make        text default null,
  p_model       text default null,
  p_powertrain  text default null,
  p_body_style  text default null,
  p_location    text default null,
  p_status      text default null,
  p_in_stock    boolean default null,
  p_price_min   int default null,
  p_price_max   int default null,
  p_limit       int default 25
)
returns table (
  make text,
  model text,
  car_trim text,
  year int,
  powertrain text,
  body_style text,
  color text,
  msrp_usd int,
  stock_qty int,
  vin text,
  location text,
  status text,
  lead_time_weeks int,
  test_drive_available boolean,
  demo_unit boolean,
  source_url text
)
language sql stable as $$
  select
    i.make, i.model, i.trim as car_trim, i.year, i.powertrain, i.body_style,
    i.color, i.msrp_usd, i.stock_qty, i.vin, i.location, i.status,
    i.lead_time_weeks, i.test_drive_available, i.demo_unit, i.source_url
  from public.inventory i
  where (p_color       is null or lower(i.color) = lower(trim(p_color)))
    and (p_make        is null or lower(i.make) = lower(trim(p_make)))
    and (p_model       is null or lower(i.model) = lower(trim(p_model)))
    and (p_powertrain  is null or lower(i.powertrain) = lower(trim(p_powertrain)))
    and (p_body_style  is null or lower(i.body_style) = lower(trim(p_body_style)))
    and (p_location    is null or lower(i.location) = lower(trim(p_location)))
    and (p_status      is null or lower(i.status) = lower(trim(p_status)))
    and (p_in_stock    is null or (case when p_in_stock then i.stock_qty > 0 else i.stock_qty = 0 end))
    and (p_price_min   is null or i.msrp_usd >= p_price_min)
    and (p_price_max   is null or i.msrp_usd <= p_price_max)
  order by i.msrp_usd asc, i.stock_qty desc
  limit p_limit;
$$;

select pg_notify('pgrst','reload schema');
