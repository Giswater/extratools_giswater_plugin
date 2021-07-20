/*
This file is part of Giswater 3
The program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This version of Giswater is provided by Giswater Association
*/


SET search_path = "SCHEMA_NAME", public, pg_catalog;

INSERT INTO sys_function(id, function_name, project_type, function_type, input_params, return_type, descript, sys_role, sample_query, source)
VALUES (3068, 'gw_fct_check_importgpkg', 'utils', 'function', 'json', 'json','Function to check the quality of imported geopackage files',
'role_edit', null, 'giswater_tools plugin')
ON CONFLICT (id) DO NOTHING;

INSERT INTO sys_function(id, function_name, project_type, function_type, input_params, return_type, descript, sys_role, sample_query, source)
VALUES (3070, 'gw_fct_import_importgpkg', 'utils', 'function', 'json', 'json','This function to import geopackage files into a Giswater schema works using the geopackage layername(s) AS Giswater catalogs. 
If catalog does not exists, the process will propose to create a new one. It has two steps:
- STEP 1: A preview of data is showed. Topological information is provided in order to show user the topological consistency of geopackage data.
- STEP 2: User can run or cancel the importation process.',
'role_edit', null, 'giswater_tools plugin')
ON CONFLICT (id) DO NOTHING;

INSERT INTO sys_fprocess(fid, fprocess_name, project_type, source)
VALUES (392, 'Import geopackage', 'utils', 'giswater_tools plugin')ON CONFLICT (fid) DO NOTHING;