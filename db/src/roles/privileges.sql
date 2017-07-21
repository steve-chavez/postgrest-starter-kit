\echo # Loading roles privilege
-------------------------------------------------------------------------------
-- api
grant usage on schema api to anonymous;
grant usage on schema api to webuser;
grant usage on schema request to public;
-------------------------------------------------------------------------------
-- me
grant execute on function api.me() to webuser;
-------------------------------------------------------------------------------
-- signup
grant execute on function api.signup(text, text, text) to anonymous;
-------------------------------------------------------------------------------
-- login
grant execute on function api.login(text,text) to anonymous;
grant execute on function api.login(text,text) to webuser;
-------------------------------------------------------------------------------
-- refresh_token
grant execute on function api.refresh_token() to webuser;
-- rabbitmq
grant usage on schema rabbitmq to webuser;
grant usage on schema rabbitmq to anonymous;
-------------------------------------------------------------------------------
-- items
-- give access to the view owner to this table
grant select, insert, update, delete on data.items to api;
grant usage on data.items_id_seq to webuser;
-- define the RLS policy

-- While grants to the view owner and the RLS policy on the underlying table 
-- takes care of what rows the view can see, we still need to define what 
-- are the rights of our application user in regard to this api view.
grant select, insert, update, delete on api.items to webuser;
grant select on api.items to anonymous;
-------------------------------------------------------------------------------
-- subitems
-- give access to the view owner to this table
grant select, insert, update, delete on data.subitems to api;
grant usage on data.subitems_id_seq to webuser;

-- define the RLS policy
-- this helper function was used because if we tried to inline the select statement
-- inside the policy, the RLS for the items table whould have kicked in
-- which would have resulted in no rows returned which in turn means
-- no subitems would be visible
create or replace function public_items() returns setof int as $$
    select id from data.items where private = false
$$ stable security definer language sql;

grant select, insert, update, delete on api.subitems to webuser;
grant select on api.subitems to anonymous;
-------------------------------------------------------------------------------
