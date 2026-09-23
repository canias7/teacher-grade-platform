-- Teacher grade platform: isolated "gradebook" schema (not exposed by the Data API).
-- The browser can only call the gb_* RPC functions below; every one of them
-- checks the session token and only touches the logged-in teacher's rows.

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

-- Resolve a session token to a teacher id, or fail.
create or replace function gradebook.session_teacher(p_token uuid) returns int
language plpgsql set search_path = '' as $$
declare v_id int;
begin
  select s.teacher_id into v_id from gradebook.sessions s
   where s.token = p_token and s.expires_at > now();
  if v_id is null then raise exception 'Not logged in'; end if;
  return v_id;
end $$;

create or replace function public.gb_login(p_email text, p_password text) returns json
language plpgsql security definer set search_path = '' as $$
declare t gradebook.teachers%rowtype; v_token uuid;
begin
  select * into t from gradebook.teachers where email = lower(trim(p_email));
  if not found or t.password_hash <> extensions.crypt(p_password, t.password_hash) then
    raise exception 'Invalid email or password';
  end if;
  delete from gradebook.sessions where expires_at < now();
  insert into gradebook.sessions(teacher_id) values (t.id) returning token into v_token;
  return json_build_object('token', v_token, 'name', t.name, 'email', t.email);
end $$;

create or replace function public.gb_logout(p_token uuid) returns void
language sql security definer set search_path = '' as $$
  delete from gradebook.sessions where token = p_token;
$$;

create or replace function public.gb_my_students(p_token uuid)
returns table(id int, name text, subject text, grade int, updated_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare v_teacher int := gradebook.session_teacher(p_token);
begin
  return query
    select s.id, s.name, s.subject, s.grade, s.updated_at
      from gradebook.students s
     where s.teacher_id = v_teacher
     order by s.name;
end $$;

create or replace function public.gb_set_grade(p_token uuid, p_student_id int, p_grade int) returns json
language plpgsql security definer set search_path = '' as $$
declare v_teacher int := gradebook.session_teacher(p_token); r record;
begin
  if p_grade is null or p_grade < 0 or p_grade > 100 then
    raise exception 'Grade must be between 0 and 100';
  end if;
  update gradebook.students s set grade = p_grade, updated_at = now()
   where s.id = p_student_id and s.teacher_id = v_teacher
   returning s.id, s.grade, s.updated_at into r;
  if not found then raise exception 'Student not found'; end if;
  return row_to_json(r);
end $$;

revoke all on function gradebook.session_teacher(uuid) from public, anon, authenticated;
revoke all on function public.gb_login(text, text) from public;
revoke all on function public.gb_logout(uuid) from public;
revoke all on function public.gb_my_students(uuid) from public;
revoke all on function public.gb_set_grade(uuid, int, int) from public;
grant execute on function public.gb_login(text, text), public.gb_logout(uuid),
  public.gb_my_students(uuid), public.gb_set_grade(uuid, int, int) to anon, authenticated;

notify pgrst, 'reload schema';
