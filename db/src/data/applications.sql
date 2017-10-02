create type db_location as enum ('container', 'external');

create table data.application (
    id uuid primary key default gen_random_uuid(),
    name  text not null,
    listener_host_name_pattern text unique,
    db_location db_location not null,
    db_admin text,
    db_admin_pass text,
    db_host text not null,
    db_port int not null,
    db_name text not null,
    db_schema text not null,
    db_authenticator text not null,
    db_authenticator_pass text not null,
    db_anon_role text not null,
    db_pool int not null default 10,
    max_rows int,
    pre_request text,
    jwt_secret text not null,
    version text not null,
    user_id int references data.user(id) default request.user_id()
);
