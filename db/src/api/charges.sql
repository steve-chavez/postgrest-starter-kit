create or replace view charges as
select id, cus_id from data.charge;

alter view charges owner to api;
