# Habit Tracker Android - Supabase Kurulum

## 1. Supabase Projesi Oluştur

1. https://supabase.com/dashboard adresinden yeni proje oluştur.
2. SQL Editor'u aç ve aşağıdaki tablo/policy scriptini çalıştır:

```sql
create table if not exists public.habittracker_state (
  id text primary key default 'default',
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.habittracker_state (id, data)
values ('default', '{}'::jsonb)
on conflict (id) do nothing;

alter table public.habittracker_state enable row level security;

grant select, insert, update on public.habittracker_state to anon;

drop policy if exists "public read habit state" on public.habittracker_state;
drop policy if exists "public insert habit state" on public.habittracker_state;
drop policy if exists "public update habit state" on public.habittracker_state;

create policy "public read habit state"
on public.habittracker_state
for select
to anon
using (id = 'default');

create policy "public insert habit state"
on public.habittracker_state
for insert
to anon
with check (id = 'default');

create policy "public update habit state"
on public.habittracker_state
for update
to anon
using (id = 'default')
with check (id = 'default');

create or replace function public.habittracker_prevent_stale_update()
returns trigger
language plpgsql
as $$
declare
  old_modified timestamptz;
  new_modified timestamptz;
begin
  old_modified := nullif(old.data->>'lastModified', '')::timestamptz;
  new_modified := nullif(new.data->>'lastModified', '')::timestamptz;

  if old_modified is not null
     and new_modified is not null
     and new_modified < old_modified then
    return old;
  end if;

  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists habittracker_prevent_stale_update
on public.habittracker_state;

create trigger habittracker_prevent_stale_update
before update on public.habittracker_state
for each row
execute function public.habittracker_prevent_stale_update();
```

3. Project Settings -> API ekranından bilgileri kopyala:
   - Project URL: `https://PROJE.supabase.co`
   - anon/public key

## 2. Plasma Widget Ayarı

Widget'e sağ tıkla -> Configure veya widget içindeki ayar butonu:

- **Project URL**: `https://PROJE.supabase.co`
- **Anon/Public Key**: Supabase anon key

## 3. Flutter APK Derleme

```bash
cd /home/abis/Projeler/habittracker-android
flutter pub get
flutter build apk --release
```

APK konumu:

```text
build/app/outputs/flutter-apk/app-release.apk
```

APK'yı telefona kur. İlk açılışta ayarlardan Supabase URL ve anon key'i gir, sonra "Kaydet & Senkronize Et" butonuna bas.

## Nasıl Çalışır

- Masaüstü: Her habit toggle'ında Supabase'e yazar; widget açıldığında Supabase'den çeker.
- Telefon: Her toggle'da Supabase'e yazar; açılışta ve yenile butonuyla Supabase'den çeker.
- Çakışma: İki cihazdan da işaretlenmiş habitler union mantığıyla birleştirilir.

## Yetki Hatası

`permission denied for table habittracker_state` hatası alırsan Supabase SQL Editor'da şunu çalıştır:

```sql
grant select, insert, update on public.habittracker_state to anon;
```

İkinci tıklamada tik geri geliyorsa eski bir sync isteği yeni veriyi eziyor olabilir. Bunu engellemek için SQL Editor'da şunu da çalıştır:

```sql
create or replace function public.habittracker_prevent_stale_update()
returns trigger
language plpgsql
as $$
declare
  old_modified timestamptz;
  new_modified timestamptz;
begin
  old_modified := nullif(old.data->>'lastModified', '')::timestamptz;
  new_modified := nullif(new.data->>'lastModified', '')::timestamptz;

  if old_modified is not null
     and new_modified is not null
     and new_modified < old_modified then
    return old;
  end if;

  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists habittracker_prevent_stale_update
on public.habittracker_state;

create trigger habittracker_prevent_stale_update
before update on public.habittracker_state
for each row
execute function public.habittracker_prevent_stale_update();
```

## Güvenlik

Bu kurulum kişisel kullanım için Firebase'deki açık read/write kurallarına benzer şekilde anon erişime izin verir. URL ve anon key'i bilen biri veriyi okuyup yazabilir. Daha güvenli kullanım için Supabase Auth ekleyip tabloya `user_id` alanı ve kullanıcı bazlı RLS policy kurulmalıdır.
