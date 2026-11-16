-- ============================================================
-- D-DART CANTEEN MENU ITEMS TABLE & EXTENSIVE SEED DATA
-- Copy and run this in your Supabase Dashboard -> SQL Editor
-- ============================================================

-- 1. Create table if not exists
create table if not exists public.canteen_menu_items (
  id text primary key,
  name text not null,
  canteen text not null default 'Main Canteen',
  category text not null,
  price numeric(10,2) not null,
  unit_description text default '',
  image_url text,
  is_available boolean not null default true,
  available_canteens text[] default '{}',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Indexes
create index if not exists idx_canteen_menu_items_category on public.canteen_menu_items (category);
create index if not exists idx_canteen_menu_items_canteen on public.canteen_menu_items (canteen);

-- 3. Row Level Security
alter table public.canteen_menu_items enable row level security;

drop policy if exists "Allow read active menu items" on public.canteen_menu_items;
create policy "Allow read active menu items"
  on public.canteen_menu_items for select
  using (is_available = true);

drop policy if exists "Allow admins manage menu items" on public.canteen_menu_items;
create policy "Allow admins manage menu items"
  on public.canteen_menu_items for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and (account_type = 'admin' or role = 'admin')
    )
  );

grant select on public.canteen_menu_items to anon, authenticated;
grant all on public.canteen_menu_items to authenticated;

-- 4. Extensive Seed Data (Food, Snacks, Beverages, Desserts across CIT-U Canteens)
insert into public.canteen_menu_items (id, name, canteen, category, price, unit_description, image_url, available_canteens) values
  -- FOOD & SNACKS
  ('food-siomai', 'Pork Siomai with rice', 'Main Canteen', 'Food and snacks', 30.00, '3 for 30 Pesos with chili garlic & calamansi', 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('food-burger', 'Burger', 'Main Canteen', 'Food and snacks', 35.00, 'Classic burger with dressing', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('food-cheeseburger', 'Cheesy Bacon Burger', 'Main Canteen', 'Food and snacks', 45.00, 'Burger with cheddar cheese slice & crispy bacon', 'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('food-egg-rice', 'Egg w/ rice', 'Main Canteen', 'Food and snacks', 25.00, 'Sunny side up with garlic fried rice', 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'Elementary Canteen']),
  ('food-pancit', 'Pancit Canton', 'Main Canteen', 'Food and snacks', 25.00, 'With boiled egg & calamansi', 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen', 'Elementary Canteen']),
  ('food-tocilog', 'Tocilog', 'Main Canteen', 'Food and snacks', 55.00, 'Sweet pork tocino, egg & sinangag', 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('food-tapsilog', 'Tapsilog Special', 'College Canteen', 'Food and snacks', 65.00, 'Tender beef tapa with fried egg & garlic rice', 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Main Canteen']),
  ('food-bangsilog', 'Bangsilog', 'Main Canteen', 'Food and snacks', 60.00, 'Pan-fried daing na bangus with egg & rice', 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80', array['Main Canteen']),
  ('food-sisig', 'Pork Sisig w/ Rice', 'College Canteen', 'Food and snacks', 60.00, 'Sizzling savory pork sisig with egg & calamansi', 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Main Canteen']),
  ('food-hotdog', 'Hotdog', 'Main Canteen', 'Food and snacks', 20.00, 'Classic grilled red hotdog with dressing', 'https://images.unsplash.com/photo-1619740455993-9e612b1af08a?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen', 'Elementary Canteen']),
  ('food-footlong', 'Footlong', 'Main Canteen', 'Food and snacks', 40.00, 'Footlong hotdog sandwich with cheese & ketchup', 'https://images.unsplash.com/photo-1627059173079-58ec789fc57d?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('food-corndog', 'Mozzarella Corndog', 'College Canteen', 'Food and snacks', 45.00, 'Half mozzarella half sausage with honey mustard', 'https://images.unsplash.com/photo-1627059173079-58ec789fc57d?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Main Canteen']),
  ('food-nuggets', 'Chicken Nuggets w/ Rice', 'Elementary Canteen', 'Food and snacks', 45.00, '4 pcs crispy nuggets with BBQ sauce & rice', 'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=400&q=80', array['Elementary Canteen', 'Main Canteen']),
  ('food-fries', 'Cheese French Fries', 'College Canteen', 'Food and snacks', 30.00, 'Crispy crinkle-cut fries coated in cheese powder', 'https://images.unsplash.com/photo-1576107232684-1279f3908594?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Elementary Canteen']),
  ('food-lumpia', 'Shanghai Rolls w/ Rice', 'Main Canteen', 'Food and snacks', 35.00, '4 pcs crispy pork lumpia with sweet chili sauce', 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('food-shawarma', 'Beef Shawarma Rice', 'Main Canteen', 'Food and snacks', 55.00, 'Spiced beef shawarma with garlic cucumber sauce', 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('food-kwek', 'Kwek-Kwek & Fishballs', 'Campus Kiosks', 'Food and snacks', 20.00, '4 pcs quail eggs & 5 fishballs with sweet brown sauce', 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=400&q=80', array['Campus Kiosks', 'Main Canteen']),
  ('food-porkchop', 'Breaded Porkchop w/ Rice', 'College Canteen', 'Food and snacks', 60.00, 'Golden deep-fried porkchop with mushroom gravy', 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Main Canteen']),

  -- BEVERAGES / DRINKS
  ('bev-dew', 'Mountain dew (Plastic bottle)', 'Main Canteen', 'Beverages', 25.00, '25 Pesos/bottle 500ml', 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen', 'Elementary Canteen']),
  ('bev-coke', 'Coca-Cola Mismo', 'Main Canteen', 'Beverages', 20.00, '300ml chilled glass/plastic bottle', 'https://images.unsplash.com/photo-1554866585-cd94860890b7?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen', 'Elementary Canteen']),
  ('bev-sprite', 'Sprite Mismo', 'Main Canteen', 'Beverages', 20.00, '300ml crisp chilled lemon-lime soda', 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('bev-royal', 'Royal Tru-Orange Mismo', 'Elementary Canteen', 'Beverages', 20.00, '300ml chilled orange soda', 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80', array['Elementary Canteen', 'Main Canteen']),
  ('bev-c2', 'C2 Green Tea Apple', 'Main Canteen', 'Beverages', 20.00, '500ml chilled bottle', 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen', 'Elementary Canteen']),
  ('bev-c2-lemon', 'C2 Green Tea Lemon', 'Main Canteen', 'Beverages', 20.00, '500ml chilled bottle', 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('bev-water', 'Mineral Water 500ml', 'Main Canteen', 'Beverages', 15.00, '500ml purified cold bottle', 'https://images.unsplash.com/photo-1559839914-1b39868735df?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen', 'Elementary Canteen']),
  ('bev-water-1l', 'Nature Spring 1 Liter', 'Main Canteen', 'Beverages', 25.00, '1 Liter cold purified water', 'https://images.unsplash.com/photo-1559839914-1b39868735df?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('bev-calamansi', 'Fresh Calamansi Juice', 'Main Canteen', 'Beverages', 20.00, '16oz freshly squeezed cold cup with honey', 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('bev-iced-tea', 'House Iced Tea', 'Main Canteen', 'Beverages', 15.00, '16oz refreshing cold iced tea with ice', 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen', 'Elementary Canteen']),
  ('bev-coffee', 'Iced Coffee Latte', 'College Canteen', 'Beverages', 35.00, '16oz brewed coffee with fresh milk & syrup', 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Main Canteen']),
  ('bev-milo', 'Iced Milo Dinosaur', 'College Canteen', 'Beverages', 30.00, 'Cold chocolate malt drink with extra Milo powder', 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Elementary Canteen']),
  ('bev-gulaman', 'Sago''t Gulaman Cooler', 'Campus Kiosks', 'Beverages', 15.00, 'Classic caramelized brown sugar with pearls & jelly', 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=400&q=80', array['Campus Kiosks', 'Main Canteen']),
  ('bev-juice', 'Orange Juice Box', 'Elementary Canteen', 'Beverages', 18.00, '250ml tetra pack with straw', 'https://images.unsplash.com/photo-1613478223719-2ab802602423?auto=format&fit=crop&w=400&q=80', array['Elementary Canteen', 'Main Canteen']),
  ('bev-chuckie', 'Nestle Chuckie Box', 'Elementary Canteen', 'Beverages', 25.00, '250ml chilled chocolate drink', 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?auto=format&fit=crop&w=400&q=80', array['Elementary Canteen', 'College Canteen']),

  -- DESSERTS
  ('des-banana', 'Banana', 'Main Canteen', 'Desserts', 15.00, '15 pesos/fruit fresh ripe sweet banana', 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen', 'Elementary Canteen']),
  ('des-turon', 'Turon (2 pcs)', 'Main Canteen', 'Desserts', 20.00, 'Crispy caramelized banana roll with jackfruit', 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('des-halohalo', 'Special Halo-Halo', 'Main Canteen', 'Desserts', 45.00, 'Shaved ice with ube, leche flan, sago & milk', 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('des-waffle', 'Belgian Chocolate Waffle', 'College Canteen', 'Desserts', 30.00, 'Crispy toasted waffle with rich chocolate filling', 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Main Canteen']),
  ('des-waffle-cheese', 'Belgian Cheese Waffle', 'College Canteen', 'Desserts', 30.00, 'Crispy toasted waffle with savory melted cheese', 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Main Canteen']),
  ('des-cookies', 'Chocolate Chip Cookies (3 pcs)', 'Elementary Canteen', 'Desserts', 20.00, 'Freshly baked chocolate chip cookies', 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?auto=format&fit=crop&w=400&q=80', array['Elementary Canteen', 'Main Canteen']),
  ('des-mango-float', 'Mango Float Cup', 'Main Canteen', 'Desserts', 40.00, 'Layered graham crackers, sweet cream & fresh ripe mango', 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('des-lecheflan', 'Leche Flan Slice', 'Main Canteen', 'Desserts', 30.00, 'Smooth caramel custard flan slice', 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen']),
  ('des-cornetto', 'Cornetto Ice Cream Cone', 'Main Canteen', 'Desserts', 35.00, 'Chocolate / Vanilla drumstick with chocolate tip', 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80', array['Main Canteen', 'College Canteen', 'Elementary Canteen']),
  ('des-donut', 'Choco Glazed Donut', 'College Canteen', 'Desserts', 25.00, 'Soft ring donut with thick chocolate glaze & sprinkles', 'https://images.unsplash.com/photo-1527515862127-a4fc05baf7a5?auto=format&fit=crop&w=400&q=80', array['College Canteen', 'Elementary Canteen']),
  ('des-pichi', 'Pichi-Pichi with Cheese', 'Campus Kiosks', 'Desserts', 25.00, '4 pcs chewy steamed cassava cake with cheddar cheese', 'https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80', array['Campus Kiosks', 'Main Canteen'])
on conflict (id) do update set
  name = excluded.name,
  canteen = excluded.canteen,
  category = excluded.category,
  price = excluded.price,
  unit_description = excluded.unit_description,
  image_url = excluded.image_url,
  available_canteens = excluded.available_canteens,
  is_available = excluded.is_available;
