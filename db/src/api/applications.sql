create or replace view applications as
select
    id,
    name,
    listener_host_name_pattern as domain,
    db_location,
    db_admin,
    db_admin_pass,
    db_host,
    db_port,
    db_name,
    db_schema,
    db_authenticator,
    db_authenticator_pass,
    db_anon_role,
    max_rows,
    pre_request,
    jwt_secret,
    version
from data.application;
alter view applications owner to api;
