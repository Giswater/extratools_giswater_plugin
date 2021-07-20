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
"form":{},"feature":{"tableName":"temp_ve_node"}}$$)::JSON

-- fid: 392

*/

v_incorrect_arc text[];
v_count integer;
v_errortext text;
v_start_point public.geometry(Point,SRID_VALUE);
v_end_point public.geometry(Point,SRID_VALUE);
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
v_fid = 392;
 
BEGIN 

	-- search path
	SET search_path = "ws_sample", public;

	-- select config values
	SELECT project_type, giswater INTO v_project_type, v_version FROM sys_version order by id desc limit 1;

	-- delete old values on result table
	DELETE FROM audit_check_data WHERE fid = v_fid AND cur_user=current_user;
	DELETE FROM temp_ve_node WHERE fid = v_fid AND cur_user=current_user;
	DELETE FROM temp_ve_arc WHERE fid = v_fid AND cur_user=current_user;
	
	-- Starting process
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 4, concat('CHECK IMPORT GEOPACKAGE'));
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 4, '-------------------------------------------------------------');

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, 'CRITICAL ERRORS');
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 3, '----------------------');

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 2, 'WARNINGS');
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 2, '--------------');

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, 'INFO');
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, '-------');

	

	-- mandatory
	------------
	
	-- catalog
		
	-- state
		
	-- state_type
		
	-- exploitation
	
	
	
	-- higly recommendend
	---------------------
	
	-- dma_id
	
	-- presszone_id
	
	-- category_type
	
	-- function_type
	
	
	
	-- recomended
	-------------
	
	-- workcat_id
	
	-- builtdate
	
	
	
	-- topology nodes
	-----------------
	-- duplicated nodes
	
		
	
	-- topology arcs
	----------------
	
	-- extermals nodes
	
	-- duplicated arcs
	
		
	
	

	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, null);
	INSERT INTO audit_check_data (fid, result_id, criticity, error_message) VALUES (v_fid, null, 1, 'PRESS RUN TO EXECUTE INSERT');

	-- get results
	-- info
	SELECT array_to_json(array_agg(row_to_json(row))) INTO v_result
	FROM (SELECT id, error_message as message FROM audit_check_data 
	WHERE cur_user="current_user"() AND fid = v_fid ORDER BY criticity desc, id asc) row;
	
	v_result_info := COALESCE(v_result, '{}'); 
	v_result_info = concat ('{"geometryType":"", "values":',v_result_info, '}');

	--points
	v_result = null;

	SELECT array_to_json(array_agg(row_to_json(row))) INTO v_result 
	FROM (SELECT id, node_id as feature_id, nodecat_id as feature_catalog, state, expl_id, descript,fid, the_geom
	FROM anl_node WHERE cur_user="current_user"() AND fid = v_fid) row;

	v_result := COALESCE(v_result, '{}'); 
	
	v_result = null;
	
	SELECT jsonb_agg(features.feature) INTO v_result
	FROM (
  	SELECT jsonb_build_object(
     'type',       'Feature',
    'geometry',   ST_AsGeoJSON(the_geom)::jsonb,
    'properties', to_jsonb(row) - 'the_geom'
  	) AS feature
  	FROM (SELECT id, node_id, nodecat_id, state, expl_id, descript,fid, the_geom
  	FROM  anl_node WHERE cur_user="current_user"() AND fid = v_fid) row) features;

	v_result := COALESCE(v_result, '{}'); 
	
	IF v_result::text = '{}' THEN 
		v_result_point = '{"geometryType":"", "values":[]}';
	ELSE 
		v_result_point = concat ('{"geometryType":"Point", "features":',v_result,',"category_field":"descript","size":4}'); 
	END IF;

	v_result_line = '{"geometryType":"", "features":[],"category_field":""}';
	v_result_polygon = '{"geometryType":"", "features":[],"category_field":""}';

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