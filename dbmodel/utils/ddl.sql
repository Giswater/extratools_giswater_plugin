/*
This file is part of Giswater 3
The program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This version of Giswater is provided by Giswater Association
*/


SET search_path = "SCHEMA_NAME", public, pg_catalog;


DROP TABLE IF EXISTS temp_import_arc;
create table temp_import_arc (

fid integer,
cur_user text NOT NULL DEFAULT "current_user"(),
log_message text,
log_level integer,

--level 3
id text,
code text,
arccat_id text,
the_geom geometry('LINESTRING', SRID_VALUE),

-- level 2
epa_type text, 
expl_id int4, 
state int2, 
state_type int2,
function_type text, 
category_type text,
workcat_id text, 
sector_id int4, 
dma_id int4, 
presszone_id text, 
builtdate timestamp, 

-- level 1
dqa_id int4, 
minsector_id int4,
workcat_id_end text, 
workcat_id_plan text, 
buildercat_id text, 
enddate timestamp, 
ownercat_id text,
fluid_type text, 
location_type text, 
annotation text, 
observ text, 
comment text, 
descript text, 
link text,
muni_id integer,
district_id integer, 
postcode text, 
streetname text, 
postnumber integer, 
postcomplement text, 
streetname2 text, 
postnumber2 integer, 
postcomplement2 text, 
custom_length float, 
soilcat_id text, 
verified text, 
undelete boolean, 
label text, 
label_x text, 
label_y text, 
label_rotation float, 
publish boolean, 
inventory boolean, 
num_value integer, 
tstamp timestamp, 
insert_user  text, 
lastupdate timestamp, 
lastupdate_user text, 
adate text, 
adescript text, 
asset_id text
);


DROP TABLE IF EXISTS temp_import_node;
create table temp_import_node (

fid integer,
cur_user text NOT NULL DEFAULT "current_user"(),
log_message text,
log_level integer,

--level 3
id text,
code text,
nodecat_id text,
the_geom geometry('POINT', SRID_VALUE),

-- level 2
elevation float,
epa_type text, 
expl_id int4, 
state int2, 
state_type int2,
function_type text, 
category_type text,
workcat_id text, 
sector_id int4, 
dma_id int4, 
presszone_id text, 
builtdate timestamp, 

-- level 1
arc_id text,
parent_id text,
dqa_id int4, 
minsector_id int4,
workcat_id_end text, 
workcat_id_plan text, 
buildercat_id text, 
enddate timestamp, 
ownercat_id text,
fluid_type text, 
location_type text, 
annotation text, 
observ text, 
comment text, 
descript text, 
link text,
muni_id integer,
district_id integer, 
postcode text, 
streetname text, 
postnumber integer, 
postcomplement text, 
streetname2 text, 
postnumber2 integer, 
postcomplement2 text, 
soilcat_id text, 
verified text, 
undelete boolean, 
label text, 
label_x text, 
label_y text, 
label_rotation float, 
publish boolean, 
inventory boolean, 
num_value integer, 
tstamp timestamp, 
insert_user  text, 
lastupdate timestamp, 
lastupdate_user text, 
staticpressure float,
adate text, 
adescript text, 
asset_id text
);


DROP TABLE IF EXISTS temp_import_connec;
create table temp_import_connec (

fid integer,
cur_user text NOT NULL DEFAULT "current_user"(),
log_message text,
log_level integer,

--level 3
id text,
code text,
connecat_id text,
the_geom geometry('POINT', SRID_VALUE),

-- level 2
elevation float,
customer_code text,
expl_id int4, 
state int2, 
state_type int2,
function_type text, 
category_type text,
workcat_id text, 
sector_id int4, 
dma_id int4, 
presszone_id text, 
builtdate timestamp, 

-- level 1
connec_length float,
arc_id text,
dqa_id int4, 
minsector_id int4,
workcat_id_end text, 
workcat_id_plan text, 
buildercat_id text, 
enddate timestamp, 
ownercat_id text,
fluid_type text, 
location_type text, 
annotation text, 
observ text, 
comment text, 
descript text, 
link text,
muni_id integer,
district_id integer, 
postcode text, 
streetname text, 
postnumber integer, 
postcomplement text, 
streetname2 text, 
postnumber2 integer, 
postcomplement2 text, 
soilcat_id text, 
verified text, 
undelete boolean, 
label text, 
label_x text, 
label_y text, 
label_rotation float, 
publish boolean, 
inventory boolean, 
num_value integer, 
tstamp timestamp, 
insert_user  text, 
lastupdate timestamp, 
lastupdate_user text, 
staticpressure float,
adate text, 
adescript text, 
asset_id text
);

ALTER TABLE temp_import_arc ADD CONSTRAINT temp_import_node_pkey PRIMARY KEY (fid,cur_user,id);
ALTER TABLE temp_import_node ADD CONSTRAINT temp_import_arc_pkey PRIMARY KEY (fid,cur_user,id);
ALTER TABLE temp_import_connec ADD CONSTRAINT temp_import_connec_pkey PRIMARY KEY (fid,cur_user,id);