/*
This file is part of Giswater 3
The program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This version of Giswater is provided by Giswater Association
*/


SET search_path = "SCHEMA_NAME", public, pg_catalog;

--2021/07/19
CREATE TABLE IF NOT EXISTS  temp_v_edit_gully AS SELECT null:integer as fid, null::text as cur_user, * FROM v_edit_gully WHERE state > 4;
ALTER TABLE temp_v_edit_gully ADD CONSTRAINT temp_v_edit_gully_pkey PRIMARY KEY(gully_id);

