START TRANSACTION;

SET search_path = api, pg_catalog;

DROP VIEW todos;

CREATE VIEW todos AS
	SELECT todo.id,
    todo.todo,
    todo.private,
    (todo.owner_id = request.user_id()) AS mine
   FROM data.todo;
REVOKE ALL ON TABLE todos FROM webuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE todos TO webuser;

COMMIT TRANSACTION;
