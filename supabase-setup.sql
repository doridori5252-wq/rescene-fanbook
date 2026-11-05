-- 리센느 팬북 소통창 설정
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 내용을 전부 붙여넣고 Run 을 누르세요.

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  kind text not null check (kind in ('stock','chat')),
  item text check (char_length(item) <= 40),
  status text check (status in ('have','few','out')),
  area text check (char_length(area) <= 20),
  store text check (char_length(store) <= 30),
  body text check (char_length(body) <= 200),
  nick text not null default '리마인' check (char_length(nick) between 1 and 12),
  reports int not null default 0
);

alter table public.posts enable row level security;

-- 누구나 읽기: 신고 3번 미만, 최근 7일 글만 보여요
drop policy if exists "read recent posts" on public.posts;
create policy "read recent posts" on public.posts
  for select using (reports < 3 and created_at > now() - interval '7 days');

-- 누구나 쓰기: 신고 수나 작성 시각은 직접 정할 수 없어요
drop policy if exists "anyone can post" on public.posts;
create policy "anyone can post" on public.posts
  for insert with check (reports = 0 and created_at > now() - interval '1 minute');

-- 신고: 글 내용은 못 바꾸고 신고 수만 1 올려요
create or replace function public.report_post(pid uuid)
returns void language sql security definer set search_path = public as $$
  update public.posts set reports = reports + 1 where id = pid;
$$;
grant execute on function public.report_post(uuid) to anon;

create index if not exists posts_created_idx on public.posts (created_at desc);
