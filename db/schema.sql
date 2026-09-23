-- Teacher grade platform: isolated "gradebook" schema (not exposed by the Supabase Data API).
-- Only the backend API (Cloudflare Worker, worker/) touches these tables, as the gradebook_api role.

create schema if not exists gradebook;
revoke all on schema gradebook from public, anon, authenticated;

create table gradebook.teachers (
  id serial primary key,
  email text not null unique,
  name text not null,
  password_hash text not null            -- bcrypt via pgcrypto
);

create table gradebook.students (
  id serial primary key,
  teacher_id int not null references gradebook.teachers(id) on delete cascade,
  name text not null,
  subject text not null,
  grade int check (grade between 0 and 100),
  updated_at timestamptz not null default now()
);
create index on gradebook.students(teacher_id);

create table gradebook.sessions (
  token uuid primary key default gen_random_uuid(),
  teacher_id int not null references gradebook.teachers(id) on delete cascade,
  expires_at timestamptz not null default now() + interval '12 hours'
);

alter table gradebook.teachers enable row level security;
alter table gradebook.students enable row level security;
alter table gradebook.sessions enable row level security;

-- Least-privilege login used by the backend API. Set the password yourself:
--   alter role gradebook_api password '<password>';
create role gradebook_api login;
grant usage on schema gradebook, extensions to gradebook_api;
grant select on gradebook.teachers to gradebook_api;
grant select, update (grade, updated_at) on gradebook.students to gradebook_api;
grant select, insert, delete on gradebook.sessions to gradebook_api;
create policy api_read on gradebook.teachers for select to gradebook_api using (true);
create policy api_rw on gradebook.students for all to gradebook_api using (true) with check (true);
create policy api_rw on gradebook.sessions for all to gradebook_api using (true) with check (true);
