/*
This file is part of Giswater 3
The program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This version of Giswater is provided by Giswater Association
*/


SET search_path = "ws_sample", public, pg_catalog;

--2021/07/19
CREATE TABLE IF NOT EXISTS  temp_v_edit_node AS SELECT null::integer as fid, null::text as cur_user, * FROM v_edit_node WHERE state > 4;
ALTER TABLE temp_v_edit_node ADD CONSTRAINT temp_v_edit_node_pkey PRIMARY KEY(node_id);

CREATE TABLE IF NOT EXISTS  temp_v_edit_arc AS SELECT null::integer as fid, null::text as cur_user, * FROM v_edit_arc WHERE state > 4;
ALTER TABLE temp_v_edit_arc ADD CONSTRAINT temp_v_edit_arc_pkey PRIMARY KEY(arc_id);

CREATE TABLE IF NOT EXISTS  temp_v_edit_connec AS SELECT null::integer as fid, null::text as cur_user, * FROM v_edit_connec WHERE state > 4;
ALTER TABLE temp_v_edit_connec ADD CONSTRAINT temp_v_edit_connec_pkey PRIMARY KEY(connec_id);




