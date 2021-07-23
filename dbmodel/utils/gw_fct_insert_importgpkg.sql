/*
This file is part of Giswater 3
The program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This version of Giswater is provided by Giswater Association
*/

--FUNCTION CODE: 3070

CREATE OR REPLACE FUNCTION "SCHEMA_NAME".gw_fct_insert_importgpkg(p_data json) 
RETURNS json AS
$BODY$

/*
EXAMPLE
SELECT SCHEMA_NAME.gw_fct_insert_importgpkg($${"client":{"device":4, "infoType":1, "lang":"es_ES"},
"form":{},"feature":{"featureType":"NODE"}, "data":{"topocontrol":false}}$$)::JSON

SELECT SCHEMA_NAME.gw_fct_insert_importgpkg($${"client":{"device":4, "infoType":1, "lang":"es_ES"},
"form":{},"feature":{"featureType":"ARC"},"data":{"topocontrol":true}}$$)::JSON

SELECT SCHEMA_NAME.gw_fct_insert_importgpkg($${"client":{"device":4, "infoType":1, "lang":"es_ES"},
"form":{},"feature":{"featureType":"CONNEC"}, "data":{"topocontrol":false}}$$)::JSON

delete from arc where comment ='INS';
SELECT gw_fct_setfeaturedelete(concat('{"feature":{"type":"NODE"}, "data":{"feature_id":"',node_id,'"}}')::json) FROM node where comment ='INS';
delete from connec where comment ='INS';

SELECT * FROM arc where comment ='INS'

-- fid: 392
*/


DECLARE 


v_featuretype text;
v_incorrect_arc text[];
v_count integer;
v_errortext text;
v_start_point public.geometry(Point,SRID_VALUE);
v_end_point public.geometry(Point,SRID_VALUE);
v_query text;
v_result json;
v_result_info json;
v_result_point json;
v_result_polygon json;
v_result_line json;
v_missing_cat_node text;
v_missing_cat_arc text;

v_project_type text;
v_version text;
v_cat_feature text;
rec text;
v_error_context text;

v_topocontrol boolean;
v_workcat text;
v_state integer;
v_state_type integer;
v_builtdate date;
v_arc_type text;
v_node_type text;
v_current_psector text;
v_fid integer = 392;
v_querytext text;
v_message text = 'Import geopackage done succesfully';

v_status boolean;


BEGIN 

	-- search path
	SET search_path = "SCHEMA_NAME", public;

	-- get input values
	v_featuretype  = upper((p_data->>'feature')::json->>'featureType');
	v_topocontrol := ((p_data ->>'data')::json->>'parameters')::json->>'topocontrol'::text;
	
	-- select config values
	SELECT project_type, giswater INTO v_project_type, v_version FROM sys_version order by id desc limit 1;

	-- delete old values on result table
	DELETE FROM audit_check_data WHERE fid=v_fid AND cur_user=current_user;

	-- Starting process
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 4, concat('IMPORT GEOPACKAGE'));
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 4, '-------------------------------------------------------------');

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, 'CRITICAL ERRORS');
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, '----------------------');

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 2, 'WARNINGS');
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 2, '--------------');

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, 'INFO');
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, '-------');


	-- check quality data from temp_table
	v_querytext ='SELECT count(*) FROM temp_import_'||lower(v_featuretype)||' WHERE log_level > 2';
	EXECUTE v_querytext INTO v_count;

	IF v_count > 0 THEN

		INSERT INTO audit_check_data (fid, result_id, criticity, error_message) 
		VALUES (v_fid, null, 3, concat ('There is/are ', v_count,' features with errors on columns related to catalog. Please fix it before continue.'));
		v_message = 'Import geopackage canceled. Please check your data....';
		
	IF v_featuretype = 'LINK' THEN

		-- check quality data from temp_table
		v_querytext ='SELECT count(*) FROM temp_import_'||lower(v_featuretype)||' WHERE log_level = 2';
		EXECUTE v_querytext INTO v_count;
	
		INSERT INTO audit_check_data (fid, result_id, criticity, error_message) 
		VALUES (v_fid, null, 2, concat ('There is/are ', v_count,' topology errors. Please fix it before continue. Disable topocontrol is not allowed for links.'));
		v_message = 'Import geopackage canceled. Please check your data....';
	
	ELSE 
		--disable topocontrol
		IF v_topocontrol is FALSE THEN
			UPDATE config_param_system SET value = gw_fct_json_object_set_key(value::json, 'activated', FALSE) WHERE parameter = 'edit_node_proximity';
			UPDATE config_param_system SET value = gw_fct_json_object_set_key(value::json, 'activated', FALSE) WHERE parameter = 'edit_connec_proximity';
			UPDATE config_param_system SET value = TRUE WHERE parameter = 'edit_topocontrol_disable_error';
		END IF;
		
		--insert nodes from gpkg
		IF v_project_type = 'WS' THEN

			IF v_featuretype = 'NODE' THEN
			-- nodes
				INSERT INTO v_edit_node (	
					-- error
					code, nodecat_id, the_geom,
					-- warning
					elevation,
					epa_type, expl_id, state, state_type,
					function_type, category_type,workcat_id,
					sector_id, dma_id, presszone_id,
					builtdate,
					-- info
					arc_id, parent_id, 
					dqa_id, minsector_id,
					workcat_id_end, workcat_id_plan, buildercat_id, enddate, ownercat_id,
					fluid_type, location_type, 
					annotation, observ, comment, descript, link,
					muni_id, postcode, district_id, streetname, postnumber, postcomplement, streetname2, postnumber2, postcomplement2,
					soilcat_id, verified, undelete, label, label_x, label_y, label_rotation, publish, inventory, num_value, tstamp, insert_user, lastupdate, lastupdate_user, staticpressure, adate, adescript, asset_id)

				SELECT 
					-- error
					code, nodecat_id, the_geom,
					-- warning
					elevation,
					epa_type, expl_id, state, state_type,
					function_type, category_type,workcat_id,
					sector_id, dma_id, presszone_id,
					builtdate,
					-- info
					arc_id, parent_id, 
					dqa_id, minsector_id,
					workcat_id_end, workcat_id_plan, buildercat_id, enddate, ownercat_id,
					fluid_type, location_type, 
					annotation, observ, comment, descript, link,
					muni_id, postcode, district_id, streetname, postnumber, postcomplement, streetname2, postnumber2, postcomplement2,
					soilcat_id, verified, undelete, label, label_x, label_y, label_rotation, publish, inventory, num_value, tstamp, insert_user, lastupdate, lastupdate_user, staticpressure, adate, adescript, asset_id
				FROM temp_import_node;

				GET DIAGNOSTICS v_count = row_count;
				INSERT INTO audit_check_data (fid,  criticity, error_message) VALUES (v_fid, 1, concat ('INFO: There is/are ',v_count,' inserted node(s) from geopackage file.'));

				-- enable topology proximity control
				UPDATE config_param_system SET value = gw_fct_json_object_set_key(value::json, 'activated', TRUE) WHERE parameter = 'edit_node_proximity';


			ELSIF v_featuretype ='ARC' THEN
			
				-- arcs
				INSERT INTO v_edit_arc (	
					-- error
					code, arccat_id, the_geom,

					-- warning
					epa_type, expl_id, state, state_type,
					function_type, category_type,workcat_id,
					sector_id, dma_id, presszone_id,
					builtdate,

					-- info
					dqa_id, minsector_id,
					workcat_id_end, workcat_id_plan, buildercat_id, enddate, ownercat_id,
					fluid_type, location_type, 
					annotation, observ, comment, descript, link,
					muni_id, postcode, district_id, streetname, postnumber, postcomplement, streetname2, postnumber2, postcomplement2,
					custom_length, soilcat_id, verified, undelete, label, label_x, label_y, label_rotation, publish, inventory, num_value, tstamp, insert_user, lastupdate, lastupdate_user, adate, asset_id)

				SELECT 
					-- error
					code, arccat_id, the_geom,

					-- warning
					epa_type, expl_id, state, state_type,
					function_type, category_type,workcat_id,
					sector_id, dma_id, presszone_id,
					builtdate,

					-- info
					dqa_id, minsector_id,
					workcat_id_end, workcat_id_plan, buildercat_id, enddate, ownercat_id,
					fluid_type, location_type, 
					annotation, observ, comment, descript, link,
					muni_id, postcode, district_id, streetname, postnumber, postcomplement, streetname2, postnumber2, postcomplement2,
					custom_length, soilcat_id, verified, undelete, label, label_x, label_y, label_rotation, publish, inventory, num_value, tstamp, insert_user, lastupdate, lastupdate_user, adate, asset_id
				FROM temp_import_arc;

				GET DIAGNOSTICS v_count = row_count;
				INSERT INTO audit_check_data (fid,  criticity, error_message) VALUES (v_fid, 1, concat ('INFO: There is/are ',v_count,' inserted arc(s) from geopackage file.'));
				
			ELSIF  v_featuretype ='CONNEC' THEN

				-- disable autofill customer code
				v_status = (SELECT (value::json)->>'status' FROM config_param_system WHERE parameter = 'edit_connec_autofill_ccode');
				UPDATE config_param_system SET value = gw_fct_json_object_set_key(value::json, 'status', FALSE) WHERE parameter = 'edit_connec_autofill_ccode';

				-- remove arc_id
				UPDATE temp_import_connec SET arc_id = null;
				
				-- connecs
				INSERT INTO v_edit_connec (	
					-- error
					code, connecat_id, the_geom,
					-- warning
					elevation, customer_code,
					expl_id, state, state_type,
					function_type, category_type,workcat_id,
					sector_id, dma_id, presszone_id,
					builtdate,
					-- info
					connec_length, arc_id, 
					dqa_id, minsector_id,
					workcat_id_end, workcat_id_plan, buildercat_id, enddate, ownercat_id,
					fluid_type, location_type, 
					annotation, observ, comment, descript, link,
					muni_id, postcode, district_id, streetname, postnumber, postcomplement, streetname2, postnumber2, postcomplement2,
					soilcat_id, verified, undelete, label, label_x, label_y, label_rotation, publish, inventory, num_value, tstamp, insert_user, lastupdate, lastupdate_user, staticpressure, adate, adescript, asset_id)

				SELECT 
					-- error
					code, connecat_id, the_geom,
					-- warning
					elevation, customer_code,
					expl_id, state, state_type,
					function_type, category_type,workcat_id,
					sector_id, dma_id, presszone_id,
					builtdate,
					-- info
					connec_length, arc_id, 
					dqa_id, minsector_id,
					workcat_id_end, workcat_id_plan, buildercat_id, enddate, ownercat_id,
					fluid_type, location_type, 
					annotation, observ, comment, descript, link,
					muni_id, postcode, district_id, streetname, postnumber, postcomplement, streetname2, postnumber2, postcomplement2,
					soilcat_id, verified, undelete, label, label_x, label_y, label_rotation, publish, inventory, num_value, tstamp, insert_user, lastupdate, lastupdate_user, staticpressure, adate, adescript, asset_id
				FROM temp_import_connec;

				GET DIAGNOSTICS v_count = row_count;
				INSERT INTO audit_check_data (fid,  criticity, error_message) VALUES (v_fid, 1, concat ('INFO: There is/are ',v_count,' inserted connec(s) from geopackage file.'));
				INSERT INTO audit_check_data (fid,  criticity, error_message) VALUES (v_fid, 1, concat ('INFO: arc_id have been removed, as result connecs are disconnected from any arc.'));

				-- restore values
				UPDATE config_param_system SET value = gw_fct_json_object_set_key(value::json, 'status', v_status) WHERE parameter = 'edit_connec_autofill_ccode';			

			ELSIF  v_featuretype ='LINK' THEN

				-- disable autofill customer code
				v_status = (SELECT (value::json)->>'status' FROM config_param_system WHERE parameter = 'edit_connec_autofill_ccode');
				UPDATE config_param_system SET value = gw_fct_json_object_set_key(value::json, 'status', FALSE) WHERE parameter = 'edit_connec_autofill_ccode';
				
				-- links
				INSERT INTO v_edit_link (state, expl_id, the_geom)
				SELECT state, expl_id, the_geom					
				FROM temp_import_link;

				GET DIAGNOSTICS v_count = row_count;
				INSERT INTO audit_check_data (fid,  criticity, error_message) VALUES (v_fid, 1, concat ('INFO: There is/are ',v_count,' inserted link(s) from geopackage file.'));	
				
				-- update those links related to other links insertet after that thoses predecesors
				UPDATE v_edit_link SET the_geom=the_geom FROM v_edit_connec WHERE arc_id IS NULL AND connec_id = feature_id;
				
				-- update those links related to other links insertet after that thoses predecesors (again)
				UPDATE v_edit_link SET the_geom=the_geom FROM v_edit_connec WHERE arc_id IS NULL AND connec_id = feature_id;
				
				-- update those links related to other links insertet after that thoses predecesors (again again)
				UPDATE v_edit_link SET the_geom=the_geom FROM v_edit_connec WHERE arc_id IS NULL AND connec_id = feature_id;
				
				
			END IF;
		ELSIF v_project_type = 'UD' THEN
			-- todo;
			
		END IF;

		IF v_topocontrol is FALSE THEN
			-- disable topology proximity control
			UPDATE config_param_system SET value = gw_fct_json_object_set_key(value::json, 'activated', TRUE) WHERE parameter = 'edit_node_proximity';
			UPDATE config_param_system SET value = gw_fct_json_object_set_key(value::json, 'activated', TRUE) WHERE parameter = 'edit_connec_proximity';
			UPDATE config_param_system SET value = FALSE WHERE parameter = 'edit_topocontrol_disable_error';
			
			-- log 
			INSERT INTO audit_check_data (fid,  criticity, error_message) VALUES (v_fid, 4, 
			concat ('INFO: Geopackage have been inserted without topocontrol rules. Maybe there are some incosistencies in your network.'));

			-- log for arcs
			SELECT count (*) INTO v_count FROM audit_log_data WHERE fid=4 and cur_user = current_user;
			IF v_count >0 THEN
				INSERT INTO audit_check_data (fid,  criticity, error_message) VALUES (v_fid, 3, concat ('ERROR-004: There is/are ',v_count,' inserted aec(s) without node_1 or node_2. Check it before continue.'));
			ELSE
				INSERT INTO audit_check_data (fid,  criticity, error_message) VALUES (v_fid, 1, concat ('INFO: All arcs have been inserted with correct topology.'));
			END IF;

			-- log for connecs (duplicated)

			-- log for nodes (duplicated)			
		END IF;
	END IF;

	-- get results
	-- info
	SELECT array_to_json(array_agg(row_to_json(row))) INTO v_result
	FROM (SELECT id, error_message as message FROM audit_check_data 
	WHERE cur_user="current_user"() AND fid=v_fid ORDER BY criticity desc, id asc) row;
	
	v_result_info := COALESCE(v_result, '{}'); 
	v_result_info = concat ('{"geometryType":"", "values":',v_result_info, '}');

	--geometry
	v_result_line = '{"geometryType":"", "features":[]}';
	v_result_polygon = '{"geometryType":"", "features":[]}';
	v_result_point = '{"geometryType":"", "features":[]}';

	-- Return
	RETURN gw_fct_json_create_return(('{"status":"Accepted", "message":{"level":1, "text":"'||v_message||'"}, "version":"'||v_version||'"'||
             ',"body":{"form":{}'||
		     ',"data":{ "info":'||v_result_info||','||
				'"point":'||v_result_point||','||
				'"line":'||v_result_line||','||
				'"polygon":'||v_result_polygon||'}'||
		       '}'||
	    '}')::json, 3070, null, null, null);

	EXCEPTION WHEN OTHERS THEN
	GET STACKED DIAGNOSTICS v_error_context = PG_EXCEPTION_CONTEXT;
	RETURN ('{"status":"Failed","NOSQLERR":' || to_json(SQLERRM) || ',"SQLSTATE":' || to_json(SQLSTATE) ||',"SQLCONTEXT":' || to_json(v_error_context) || '}')::json;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
