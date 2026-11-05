-- 리센느 팬북 소통창 + 회원 설정
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 내용을 전부 붙여넣고 Run 을 누르세요.
-- 다른 앱과 같은 프로젝트를 쓰더라도 겹치지 않게 fanbook 스키마를 따로 씁니다.

create schema if not exists fanbook;
grant usage on schema fanbook to anon, authenticated;

create table if not exists fanbook.posts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('stock','chat')),
  item text check (char_length(item) <= 40),
  status text check (status in ('have','few','out')),
  area text check (char_length(area) <= 20),
  store text check (char_length(store) <= 30),
  body text check (char_length(body) <= 200),
  nick text not null default '리마인' check (char_length(nick) between 1 and 12),
  reports int not null default 0
);
create index if not exists posts_created_idx on fanbook.posts (created_at desc);

alter table fanbook.posts enable row level security;
grant select on fanbook.posts to anon, authenticated;
grant insert (kind,item,status,area,store,body,nick), delete on fanbook.posts to authenticated;

-- 누구나 읽기: 신고 3번 미만, 최근 7일 글
drop policy if exists "read recent posts" on fanbook.posts;
create policy "read recent posts" on fanbook.posts
  for select using (reports < 3 and created_at > now() - interval '7 days');

-- 로그인한 회원만 쓰기 (작성자는 자동으로 본인)
drop policy if exists "members can post" on fanbook.posts;
create policy "members can post" on fanbook.posts
  for insert to authenticated with check (user_id = auth.uid());

-- 본인 글만 지우기
drop policy if exists "delete own posts" on fanbook.posts;
create policy "delete own posts" on fanbook.posts
  for delete to authenticated using (user_id = auth.uid());

-- 신고: 신고 수만 1 올려요
create or replace function fanbook.report_post(pid uuid)
returns void language sql security definer set search_path = fanbook as $$
  update fanbook.posts set reports = reports + 1 where id = pid;
$$;
grant execute on function fanbook.report_post(uuid) to anon, authenticated;

-- 회원 탈퇴: 본인 계정을 지우면 글도 함께 지워져요 (posts.user_id on delete cascade)
create or replace function fanbook.delete_me()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not logged in'; end if;
  delete from fanbook.posts where user_id = auth.uid();
  delete from auth.users where id = auth.uid();
end;
$$;
revoke all on function fanbook.delete_me() from public, anon;
grant execute on function fanbook.delete_me() to authenticated;

-- 마지막으로: 대시보드 → Project Settings → Data API → Exposed schemas 에 fanbook 을 추가해 주세요.
