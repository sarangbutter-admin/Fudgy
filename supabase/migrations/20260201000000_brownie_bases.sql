-- Callebrownies migration 32: brownie base (step 1 in the shop, before the box).
--  * a new collection "bases" (name, description, extra price per brownie, on/off), edited in Boxes & extras
--    like box sizes; starts with Semisweet and Bittersweet
--  * while at least one base is switched on, every order must have one; it is saved on the order as
--    "batter" {id, name} and its price as "batterFee", which is part of the total
--  * same rules as box sizes: "Boxes & extras" access to change, owner password for a price, owner only to delete
-- Safe to run more than once. Run after migration 31.

-- the two starting bases (only when there are none yet)
insert into public.coll (coll, id, pos, data, updated_at)
select 'bases', b.id, b.pos, b.data, public.now_ms() from (values
  ('semisweet', 0, '{"id":"semisweet","name":"Semisweet","desc":"","price":0,"active":true}'::jsonb),
  ('bittersweet', 1, '{"id":"bittersweet","name":"Bittersweet","desc":"","price":0,"active":true}'::jsonb)) as b(id, pos, data)
where not exists (select 1 from public.coll where coll = 'bases');

do $do$
declare d text; n text;
begin
  -- the team can save the new collection
  d := pg_get_functiondef('public.admin_put_rows(text,jsonb)'::regprocedure);
  if position('''bases''' in d) = 0 then
    n := replace(d, $a$p_coll not in ('sizes',$a$, $a$p_coll not in ('bases','sizes',$a$);
    if n = d then raise exception 'admin_put_rows patch did not apply'; end if;
    execute n;
  end if;

  -- access, price and delete rules, activity log name
  d := pg_get_functiondef('public.coll_guard()'::regprocedure);
  if position('''bases''' in d) = 0 then
    n := replace(d, $a$when 'sizes' then 'boxes'$a$, $a$when 'sizes' then 'boxes' when 'bases' then 'boxes'$a$);
    n := replace(n, $a$c in ('products','categories','sizes','addons')$a$, $a$c in ('products','categories','sizes','addons','bases')$a$);
    n := replace(n, $a$c in ('sizes','addons') and$a$, $a$c in ('sizes','addons','bases') and$a$);
    n := replace(n, $a$when 'sizes' then 'box size'$a$, $a$when 'sizes' then 'box size' when 'bases' then 'brownie base'$a$);
    if (length(n) - length(replace(n, '''bases''', ''))) / length('''bases''') < 5 then raise exception 'coll_guard patch did not apply'; end if;
    execute n;
  end if;

  -- the shop gets the list
  d := pg_get_functiondef('public.shop_public()'::regprocedure);
  if position('''bases''' in d) = 0 then
    n := replace(d, $a$'sizes', public.coll_arr('sizes'),$a$, $a$'sizes', public.coll_arr('sizes'), 'bases', public.coll_arr('bases'),$a$);
    if n = d then raise exception 'shop_public patch did not apply'; end if;
    execute n;
  end if;

  -- placing or editing an order checks the base, adds its price and saves it
  d := pg_get_functiondef('public.place_order(jsonb)'::regprocedure);
  if position('batter_fee' in d) = 0 then
    n := replace(d, 'own_stock int;', 'own_stock int; v_batter jsonb; batter_fee numeric := 0; bt record;');
    n := replace(n, '  -- sale + coupon + delivery fee', $a$  -- brownie base: needed while at least one base is switched on; its price is per brownie
  if exists (select 1 from public.coll where coll = 'bases' and coalesce((data ->> 'active')::boolean, true)) then
    select * into bt from public.coll where coll = 'bases' and id = coalesce(p ->> 'batter', '') and coalesce((data ->> 'active')::boolean, true);
    if not found then perform public.bad('Please choose your brownie base.'); end if;
    batter_fee := round(greatest(0, coalesce((bt.data ->> 'price')::numeric, 0)) * v_size, 2);
    v_batter := jsonb_build_object('id', bt.id, 'name', coalesce(bt.data ->> 'name', ''));
  end if;

  -- sale + coupon + delivery fee$a$);
    n := replace(n, 'total := round(base - sd - cdisc + surcharge + addons_total + fee, 2);',
                    'total := round(base - sd - cdisc + surcharge + batter_fee + addons_total + fee, 2);');
    n := replace(n, $a$'addonsTotal', addons_total, 'fee', fee,$a$, $a$'batter', v_batter, 'batterFee', batter_fee, 'addonsTotal', addons_total, 'fee', fee,$a$);
    if position('Please choose your brownie base' in n) = 0 or position('+ batter_fee +' in n) = 0
       or (length(n) - length(replace(n, '''batterFee''', ''))) / length('''batterFee''') <> 2 then
      raise exception 'place_order patch did not apply'; end if;
    execute n;
  end if;
end $do$;
