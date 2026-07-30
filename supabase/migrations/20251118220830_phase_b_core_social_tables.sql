begin;

create extension if not exists "pgcrypto";

create table public.cafes (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    address text,
    city text,
    country text,
    latitude double precision,
    longitude double precision,
    apple_place_id text,
    website_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.follows (
    follower_id uuid not null references public.users(id) on delete cascade,
    followee_id uuid not null references public.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (follower_id, followee_id)
);

create table public.visits (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    cafe_id uuid not null references public.cafes(id) on delete cascade,
    drink_type text,
    drink_type_custom text,
    caption text not null,
    notes text,
    visibility text not null check (visibility in ('private','friends','everyone')),
    ratings jsonb not null default '{}'::jsonb,
    overall_score double precision not null,
    poster_photo_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.visit_photos (
    id uuid primary key default gen_random_uuid(),
    visit_id uuid not null references public.visits(id) on delete cascade,
    photo_url text not null,
    sort_order int not null default 0,
    created_at timestamptz not null default now()
);

create table public.likes (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    visit_id uuid not null references public.visits(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique (user_id, visit_id)
);

create table public.comments (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    visit_id uuid not null references public.visits(id) on delete cascade,
    text text not null,
    created_at timestamptz not null default now()
);

create table public.notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    actor_user_id uuid not null references public.users(id) on delete cascade,
    type text not null check (type in ('like','comment','mention','follow')),
    visit_id uuid references public.visits(id) on delete cascade,
    comment_id uuid references public.comments(id) on delete cascade,
    created_at timestamptz not null default now(),
    read_at timestamptz
);

create index on public.visits (user_id, created_at desc);
create index on public.visits (visibility, created_at desc);
create index on public.visit_photos (visit_id, sort_order);
create index on public.likes (visit_id);
create index on public.comments (visit_id, created_at);
create index on public.notifications (user_id, created_at desc);
create index on public.follows (follower_id);
create index on public.follows (followee_id);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$ language plpgsql;

create trigger cafes_set_updated_at
before update on public.cafes
for each row execute function public.set_updated_at();

create trigger visits_set_updated_at
before update on public.visits
for each row execute function public.set_updated_at();

alter table public.cafes enable row level security;
alter table public.follows enable row level security;
alter table public.visits enable row level security;
alter table public.visit_photos enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.notifications enable row level security;

create policy "Cafes are readable by everyone" on public.cafes
    for select using (true);

create policy "Authenticated users can write cafes" on public.cafes
    for insert with check (auth.role() = 'authenticated');

create policy "Authenticated users can update cafes" on public.cafes
    for update using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Users follow others they choose" on public.follows
    for select using (auth.uid() = follower_id or auth.uid() = followee_id);

create policy "Users create follow relationships" on public.follows
    for insert with check (auth.uid() = follower_id);

create policy "Users delete follow relationships" on public.follows
    for delete using (auth.uid() = follower_id);

create policy "Owners read their visits" on public.visits
    for select using (auth.uid() = user_id);

create policy "Public visits are world-readable" on public.visits
    for select using (visibility = 'everyone');

create policy "Friends can read friends visits" on public.visits
    for select using (
        visibility = 'friends'
        and auth.uid() is not null
        and (
            user_id = auth.uid()
            or exists (
                select 1 from public.follows f
                where f.follower_id = auth.uid()
                  and f.followee_id = public.visits.user_id
            )
        )
    );

create policy "Users insert their own visits" on public.visits
    for insert with check (auth.uid() = user_id);

create policy "Users update their own visits" on public.visits
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users delete their own visits" on public.visits
    for delete using (auth.uid() = user_id);

create policy "Visit photos follow visit visibility" on public.visit_photos
    for select using (
        exists (
            select 1
            from public.visits v
            where v.id = public.visit_photos.visit_id
              and (
                v.visibility = 'everyone'
                or v.user_id = auth.uid()
                or (
                    v.visibility = 'friends'
                    and auth.uid() is not null
                    and (
                        v.user_id = auth.uid()
                        or exists (
                            select 1 from public.follows f
                            where f.follower_id = auth.uid()
                              and f.followee_id = v.user_id
                        )
                    )
                )
            )
        )
    );

create policy "Visit owners manage their photos" on public.visit_photos
    for all using (
        exists (
            select 1 from public.visits v
            where v.id = public.visit_photos.visit_id
              and v.user_id = auth.uid()
        )
    ) with check (
        exists (
            select 1 from public.visits v
            where v.id = public.visit_photos.visit_id
              and v.user_id = auth.uid()
        )
    );

create policy "Likes visible when visit is visible" on public.likes
    for select using (
        auth.uid() = user_id
        or exists (
            select 1
            from public.visits v
            where v.id = public.likes.visit_id
              and (
                v.visibility = 'everyone'
                or v.user_id = auth.uid()
                or (
                    v.visibility = 'friends'
                    and auth.uid() is not null
                    and (
                        v.user_id = auth.uid()
                        or exists (
                            select 1 from public.follows f
                            where f.follower_id = auth.uid()
                              and f.followee_id = v.user_id
                        )
                    )
                )
              )
        )
    );

create policy "Users insert their own likes" on public.likes
    for insert with check (auth.uid() = user_id);

create policy "Users delete their own likes" on public.likes
    for delete using (auth.uid() = user_id);

create policy "Comments visible when visit is visible" on public.comments
    for select using (
        auth.uid() = user_id
        or exists (
            select 1
            from public.visits v
            where v.id = public.comments.visit_id
              and (
                v.visibility = 'everyone'
                or v.user_id = auth.uid()
                or (
                    v.visibility = 'friends'
                    and auth.uid() is not null
                    and (
                        v.user_id = auth.uid()
                        or exists (
                            select 1 from public.follows f
                            where f.follower_id = auth.uid()
                              and f.followee_id = v.user_id
                        )
                    )
                )
              )
        )
    );

create policy "Users insert their own comments" on public.comments
    for insert with check (auth.uid() = user_id);

create policy "Users delete their own comments" on public.comments
    for delete using (auth.uid() = user_id);

create policy "Users read their notifications" on public.notifications
    for select using (auth.uid() = user_id);

create policy "Users insert notifications for their actions" on public.notifications
    for insert with check (auth.uid() = actor_user_id);

create policy "Users mark notifications as read" on public.notifications
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

commit;;
