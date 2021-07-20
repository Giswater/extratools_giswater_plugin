/*
This file is part of Giswater 3
The program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This version of Giswater is provided by Giswater Association
*/

--FUNCTION CODE: 3068

CREATE OR REPLACE FUNCTION "ws_sample".gw_fct_check_importgpkg(p_data json) RETURNS json AS 
$BODY$

/*EXAMPLE
SELECT ws_sample.gw_fct_check_importgpkg($${"client":{"device":4, "infoType":1, "lang":"ES"},
"form":{},"feature":{"featureType":"CONNEC"}}$$)::JSON

-- fid: 392

*/
DECLARE

rec_table record;
rec_feature record;
rec_node record;

v_incorrect_arc text[];
v_count integer;
v_errortext text;
v_start_point public.geometry(Point,25831);
v_end_point public.geometry(Point,25831);
v_query text;
rec record;
v_result json;
v_result_info json;
v_result_point json;
v_project_type text;
v_version text;
v_result_polygon json;
v_result_line json;
v_missing_cat_node text;
v_missing_cat_arc text;
v_incorrect_start text[];
v_incorrect_end text[];
v_error_context text;
v_fid integer = 392;
v_querytext text;

v_featuretype text;
v_nodeproximity float;
v_connecproximity float;
v_arcsearchnodes float;
v_value text;
v_values record;

 
BEGIN 

	-- search path
	SET search_path = "ws_sample", public;

	-- get input values
	v_featuretype  = upper((p_data->>'feature')::json->>'featureType');

	-- get system values
	SELECT project_type, giswater INTO v_project_type, v_version FROM sys_version order by id desc limit 1;
	SELECT value::json->>'value' INTO v_nodeproximity FROM config_param_system WHERE parameter = 'edit_node_proximity';
	SELECT value::json->>'value' INTO v_connecproximity FROM config_param_system WHERE parameter = 'edit_connec_proximity';
	SELECT value::json->>'value' INTO v_arcsearchnodes FROM config_param_system WHERE parameter = 'edit_arc_searchnodes';

	-- delete old values on tables
	DELETE FROM audit_check_data WHERE fid = v_fid AND cur_user=current_user;
	
	-- Starting process
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 4, concat('CHECK IMPORT GEOPACKAGE'));
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 4, '---------------------------------------');

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, 'CRITICAL ERRORS');
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, '----------------------');

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 2, 'WARNINGS');
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 2, '--------------');

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, 'INFO');
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, '-------');


	-- mandatory columns
	IF v_featuretype = 'NODE' THEN

		-- nodecat
		FOR rec_feature IN SELECT * FROM temp_import_node WHERE fid = v_fid AND cur_user=current_user
		LOOP 
			IF (SELECT id FROM cat_node WHERE id = rec_feature.nodecat_id) IS NULL THEN
				UPDATE temp_import_node SET log_level = 3, log_message = 'Value for [nodecat_id] do not match with cat_node table ' WHERE node_id = rec_feature.id;
			END IF;
		END LOOP;

		-- get log
		SELECT count(*) INTO v_count FROM temp_import_node WHERE fid = v_fid AND cur_user=current_user AND log_message like '%cat_node%';
		IF v_count > 0 THEN
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, concat('There are ',v_count,' node(s) wich nodecat_id do not match with cat_node table)'));	
		ELSE
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, concat('All values of nodecat_id match with cat_node table'));	
		END IF;

		-- node proximity
		UPDATE temp_import_node temp SET log_level = 3, log_message = concat('Node is closer than minimun distance (',v_nodeproximity,') to other node. ') FROM (
		SELECT rid FROM (
		SELECT DISTINCT t1.id as rid, t1.nodecat_id, t1.state as state1, t2.nodecat_id, t2.state as state2, t1.expl_id, t1.the_geom
		FROM temp_import_node AS t1 JOIN temp_import_node AS t2 ON ST_Dwithin(t1.the_geom, t2.the_geom,(v_nodeproximity)) 
		WHERE t1.id != t2.id 
		AND t1.fid=v_fid and t2.fid=v_fid AND t1.cur_user=current_user AND t2.cur_user=current_user
		ORDER BY t1.id ) a ) b
		WHERE temp.id = b.rid ;

		-- get log
		GET DIAGNOSTICS v_count = row_count;
		IF v_count > 0 THEN
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, concat('There are ',v_count,' duplicated node(s)'));	
		ELSE
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, concat('There are not duplicated nodes'));	
		END IF;
	
			
	ELSIF v_featuretype = 'ARC' THEN
		FOR rec_feature IN SELECT * FROM temp_import_arc WHERE fid = v_fid AND cur_user=current_user
		LOOP 
			IF (SELECT id FROM cat_node WHERE id = rec_feature.arccat_id) IS NULL THEN
				UPDATE temp_import_arc SET log_message = 'Value for [arccat_id] do not match with cat_arc table' WHERE node_id = rec_feature.arc_id;
			END IF;

			-- searchnodes
			SELECT * INTO rec_node FROM node WHERE ST_DWithin(ST_startpoint(arc_rec.the_geom), node.the_geom, v_arcsearchnodes) AND (node.state=1 OR node.state=2)
			ORDER BY ST_Distance(node.the_geom, ST_startpoint(arc_rec.the_geom)) LIMIT 1;
			IF rec_node IS NULL THEN
				UPDATE temp_import_node SET log_level = 3, log_message = concat(log_message, 'Any node have been found using buffer ',v_arcsearchnodes' close the [startpoint]. ') WHERE arc_id = rec_feature.id;			
			END IF;
		
			SELECT * INTO rec_node FROM node WHERE ST_DWithin(ST_endpoint(arc_rec.the_geom), node.the_geom, v_arcsearchnodes) AND (node.state=1 OR node.state=2)
			ORDER BY ST_Distance(node.the_geom, ST_endpoint(arc_rec.the_geom)) LIMIT 1;
			IF rec_node IS NULL THEN
				UPDATE temp_import_node SET log_level = 3, log_message = concat(log_message, 'Any node have been found using buffer ',v_arcsearchnodes' close the [endpoint]. ') WHERE arc_id = rec_feature.id;			
			END IF;
		END LOOP;

		-- get log for catalog
		SELECT count(*) INTO v_count FROM temp_import_arc WHERE fid = v_fid AND cur_user=current_user AND log_message like '%cat_arc%';
		IF v_count > 0 THEN
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, concat('There are ',v_count,' arc(s) wich arccat_id do not match with cat_arc table)'));	
		ELSE
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, concat('All values of arccat_id match with cat_arc table'));	
		END IF;

		-- get log for topology
		SELECT count(*) INTO v_count FROM temp_import_arc WHERE fid = v_fid AND cur_user=current_user AND log_message like '%node have found%';
		IF v_count > 0 THEN
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, concat('There are ',v_count,' arcs without node_1 or node_2)'));	
		ELSE
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, concat('There are no problems withs node_1 and node_2'));	
		END IF;


	ELSIF v_featuretype = 'CONNEC' THEN
		FOR rec_feature IN SELECT * FROM temp_import_connec WHERE fid = v_fid AND cur_user=current_user
		LOOP 
			IF (SELECT id FROM cat_connec WHERE id = rec_feature.connecat_id) IS NULL THEN
				UPDATE temp_import_connec SET log_level = 3, log_message = 'Value for [connecat_id] do not match with cat_connec table' WHERE node_id = rec_feature.id;
			END IF;
		END LOOP;

		-- connec proximity
		UPDATE temp_import_connec temp SET log_level = 3, log_message = concat('Connec is closer than minimun distance (',v_connecproximity,') to other connec. ') FROM (
		SELECT rid FROM (
		SELECT DISTINCT t1.id as rid, t1.connecat_id, t1.state as state1, t2.id, t2.connecat_id, t2.state as state2, t1.expl_id, t1.the_geom
		FROM temp_import_connec AS t1 JOIN temp_import_connec AS t2 ON ST_Dwithin(t1.the_geom, t2.the_geom,(v_connecproximity)) 
		WHERE t1.id != t2.id 
		AND t1.fid=v_fid and t2.fid=v_fid AND t1.cur_user=current_user AND t2.cur_user=current_user
		ORDER BY t1.id ) a ) b
		WHERE temp.id = b.rid ;

		-- get log for topology
		GET DIAGNOSTICS v_count = row_count;
		IF v_count > 0 THEN
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, concat('There are ',v_count,' duplicated connec(s). Check temporal layer to see details.'));	
		ELSE
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, concat('There are not duplicated connecs'));	
		END IF;

		-- get log for catalog
		SELECT count(*) INTO v_count FROM temp_import_connec WHERE fid = v_fid AND cur_user=current_user AND log_message like '%cat_connec%';
		IF v_count > 0 THEN
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, concat('There are ',v_count,' connec(s) wich connecat_id do not match with cat_connec table.)'));	
		ELSE
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, concat('All values for [connecat_id] matchs with cat_connec table'));	
		END IF;
		
	END IF;
		
	-- other columns with catalog
	v_querytext = 'SELECT * FROM config_form_fields WHERE formname = ''v_edit_'||lower(v_featuretype)||
	''' AND columnname IN (''epa_type'', ''expl_id'', ''state'', ''state_type'', ''function_type'', ''category_type'',''workcat_id'',''sector_id'', ''dma_id'', ''presszone_id'',
			       ''dqa_id'', ''minsector_id'', ''workcat_id_end'', ''workcat_id_plan'', ''buildercat_id'', ''ownercat_id'', ''fluid_type'', ''location_type'', ''muni_id'',
			        ''streetaxis_id'',  ''streetaxis2_id'', ''postcode'', ''soilcat_id'')';
	FOR rec_table IN EXECUTE v_querytext
	LOOP
		v_querytext = 'SELECT * FROM temp_import_'||lower(v_featuretype)||' WHERE fid = '||v_fid||' AND cur_user=current_user';		
		FOR rec_feature IN EXECUTE v_querytext
		LOOP
			-- getting value for feature
			v_querytext ='SELECT '||quote_ident(rec_table.columnname)||' FROM temp_import_'||lower(v_featuretype)||' WHERE id = '||quote_literal(rec_feature.id);
			EXECUTE v_querytext INTO v_value;

			-- getting values on catalog table
			IF rec_table.dv_querytext is not null AND v_value IS NOT NULL then
				EXECUTE concat('SELECT count(*) FROM (',rec_table.dv_querytext,')a WHERE a.id = ',quote_literal(v_value)) INTO v_count;
				IF v_count = 0 THEN
					UPDATE temp_import_connec temp SET log_level = 3, log_message = concat(log_message, 'Value for [',rec_table.columnname,'] not match with catalog]. ') WHERE id = rec_feature.id;
				END IF;
			END IF;			
		END LOOP;

		-- building log
		EXECUTE 'SELECT count(*) FROM temp_import_'||lower(v_featuretype)||' WHERE fid = '||v_fid||' AND cur_user=current_user AND '||rec_table.columnname||' IS NOT NULL' INTO v_count;
		IF v_count > 0 THEN

			EXECUTE 'SELECT count(*) FROM temp_import_'||lower(v_featuretype)||' WHERE fid = '||v_fid||' AND cur_user=current_user AND log_message like ''$with catalog$''' INTO v_count;

			SELECT count(*) INTO v_count FROM temp_import_node WHERE fid = v_fid AND cur_user=current_user AND log_message like '%cat_node%';
			IF v_count > 0 THEN
				INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, concat('There are ',v_count,' features(s) wich [',rec_table.columnname,'] do not match with catalog table)'));	
			ELSE
				INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, concat('All values for [',rec_table.columnname,'] matchs with catalog table'));	
			END IF;
		ELSE
			INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, concat('No values found for [',rec_table.columnname,'] column'));	
		END IF;
		
	END LOOP;

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, 'NOTICE: Address columns [district_id], [streetaxis_id] and [postcode] are not checked.');


	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 4, null);
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, null);
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 2, null);	
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, null);
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, 'PRESS RUN TO EXECUTE INSERT OR CANCEL IF THERE ARE ERRORS');

	-- get results
	-- info
	SELECT array_to_json(array_agg(row_to_json(row))) INTO v_result
	FROM (SELECT id, error_message as message FROM audit_check_data 
	WHERE cur_user="current_user"() AND fid = v_fid ORDER BY criticity desc, id asc) row;
	
	v_result_info := COALESCE(v_result, '{}'); 
	v_result_info = concat ('{"geometryType":"", "values":',v_result_info, '}');

	-- points (node and connec)
	v_result = null;
	SELECT jsonb_agg(features.feature) INTO v_result
	FROM (
  	SELECT jsonb_build_object(
	'type',       'Feature',
	'geometry',   ST_AsGeoJSON(the_geom)::jsonb,
	'properties', to_jsonb(row) - 'the_geom'
  	) AS feature
  	FROM (SELECT id, nodecat_id, log_message, log_level the_geom
  	FROM  temp_import_node WHERE cur_user="current_user"() AND fid = v_fid AND log_level > 1
  	UNION
  	SELECT id, connecat_id, log_message, log_level the_geom
  	FROM  temp_import_connec WHERE cur_user="current_user"() AND fid = v_fid AND log_level > 1
  	) row) features;

	v_result := COALESCE(v_result, '{}'); 
	v_result_point = concat ('{"geometryType":"Point", "features":',v_result,'}'); 


	--lines
	v_result = null;
	SELECT jsonb_agg(features.feature) INTO v_result
	FROM (
	SELECT jsonb_build_object(
	'type',       'Feature',
	'geometry',   ST_AsGeoJSON(the_geom)::jsonb,
	'properties', to_jsonb(row) - 'the_geom'
	) AS feature
	FROM (SELECT id, arccat_id, log_message, log_level the_geom FROM  temp_import_arc 
	WHERE cur_user="current_user"() AND fid = v_fid AND log_level > 1) row) features;

	v_result := COALESCE(v_result, '{}'); 
	v_result_line = concat ('{"geometryType":"LineString", "features":',v_result, '}'); 	

	-- Control nulls
	v_result_info := COALESCE(v_result_info, '{}'); 
	v_result_point := COALESCE(v_result_point, '{}'); 
	v_result_line := COALESCE(v_result_line, '{}'); 

	--  Return
	RETURN ('{"status":"Accepted", "message":{"level":1, "text":"Check import dxf done succesfully"}, "version":"'||v_version||'"'||
             ',"body":{"form":{}'||
		     ',"data":{ "info":'||v_result_info||','||
				'"point":'||v_result_point||','||
				'"line":'||v_result_line||','||
				'"polygon":'||v_result_polygon||'}'||
		       '}'||
	    '}')::json;

	EXCEPTION WHEN OTHERS THEN
	GET STACKED DIAGNOSTICS v_error_context = PG_EXCEPTION_CONTEXT;
	RETURN ('{"status":"Failed","NOSQLERR":' || to_json(SQLERRM) || ',"SQLSTATE":' || to_json(SQLSTATE) ||',"SQLCONTEXT":' || to_json(v_error_context) || '}')::json;

END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;