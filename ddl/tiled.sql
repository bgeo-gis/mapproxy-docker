-- CREATE USER tileuser WITH PASSWORD '<secure_password>';

-- Create schema 'tiled' to store the materialized views and logs table

CREATE SCHEMA tiled;

-- Table for storing logs of updates tile generation
CREATE TABLE tiled.logs (
    id SERIAL PRIMARY KEY,
    process_id VARCHAR(255) NOT NULL,
    tilecluster_id VARCHAR(255) NOT NULL,
    project_id VARCHAR(255) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    geometry GEOMETRY NOT NULL
);


-- Table for storing the last seed time for each project
CREATE TABLE tiled.last_seed_time (
	id varchar(255) NOT NULL,
	last_seed timestamp NOT NULL,
	CONSTRAINT last_seed_time_pkey PRIMARY KEY (id)
);

-- Insert
INSERT INTO config_param_user VALUES ('inp_options_networkmode', 1,  'tileuser');

-- Create the materialized views in the schema 'tiled'
-- For WS
CREATE MATERIALIZED VIEW tiled.ws_t_node AS SELECT * FROM v_edit_node WHERE state < 2;
CREATE MATERIALIZED VIEW tiled.ws_t_arc AS SELECT * FROM v_edit_arc WHERE state < 2;
CREATE MATERIALIZED VIEW tiled.ws_t_connec AS SELECT * FROM v_edit_connec WHERE state < 2;
CREATE MATERIALIZED VIEW tiled.ws_t_link AS SELECT * FROM v_edit_link WHERE state < 2;

-- For UD
CREATE MATERIALIZED VIEW tiled.ud_t_node AS SELECT * FROM v_edit_node WHERE state < 2;
CREATE MATERIALIZED VIEW tiled.ud_t_arc AS SELECT * FROM v_edit_arc WHERE state < 2;
CREATE MATERIALIZED VIEW tiled.ud_t_connec AS SELECT * FROM v_edit_connec WHERE state < 2;
CREATE MATERIALIZED VIEW tiled.ud_t_link AS SELECT * FROM v_edit_link WHERE state < 2;
CREATE MATERIALIZED VIEW tiled.ud_t_gully AS SELECT * FROM v_edit_gully WHERE state < 2;


-- Create the tilecluster materialized view

-- FOR WS
CREATE MATERIALIZED VIEW tiled.ws_t_tileclusters
TABLESPACE pg_default
AS SELECT concat('E', expl_id, '-T', state) AS tilecluster_id,
    expl_id,
    state,
    st_union(geom) AS geom
   FROM ( SELECT ws_t_node.expl_id,
            ws_t_node.state,
            st_collect(st_buffer(ws_t_node.the_geom, 30::double precision)) AS geom
           FROM tiled.ws_t_node
          GROUP BY ws_t_node.expl_id, ws_t_node.state
        UNION
         SELECT ws_t_arc.expl_id,
            ws_t_arc.state,
            st_collect(st_buffer(ws_t_arc.the_geom, 30::double precision)) AS geom
           FROM tiled.ws_t_arc
          GROUP BY ws_t_arc.expl_id, ws_t_arc.state
        UNION
         SELECT ws_t_connec.expl_id,
            ws_t_connec.state,
            st_collect(st_buffer(ws_t_connec.the_geom, 30::double precision)) AS geom
           FROM tiled.ws_t_connec
          GROUP BY ws_t_connec.expl_id, ws_t_connec.state
        UNION
         SELECT ws_t_link.expl_id,
            ws_t_link.state,
            st_collect(st_buffer(ws_t_link.the_geom, 30::double precision)) AS geom
           FROM tiled.ws_t_link
          GROUP BY ws_t_link.expl_id, ws_t_link.state) a
  GROUP BY expl_id, state
WITH DATA;

-- FOR UD
CREATE MATERIALIZED VIEW tiled.ud_t_tileclusters
TABLESPACE pg_default
AS
SELECT concat('E', expl_id, '-T', state) AS tilecluster_id,
       expl_id,
       state,
       st_union(geom) AS geom
FROM (
    SELECT ud_t_node.expl_id,
           ud_t_node.state,
           st_collect(st_buffer(ud_t_node.the_geom, 30::double precision)) AS geom
    FROM tiled.ud_t_node
    GROUP BY ud_t_node.expl_id, ud_t_node.state
    UNION
    SELECT ud_t_arc.expl_id,
           ud_t_arc.state,
           st_collect(st_buffer(ud_t_arc.the_geom, 30::double precision)) AS geom
    FROM tiled.ud_t_arc
    GROUP BY ud_t_arc.expl_id, ud_t_arc.state
    UNION
    SELECT ud_t_connec.expl_id,
           ud_t_connec.state,
           st_collect(st_buffer(ud_t_connec.the_geom, 30::double precision)) AS geom
    FROM tiled.ud_t_connec
    GROUP BY ud_t_connec.expl_id, ud_t_connec.state
    UNION
    SELECT ud_t_link.expl_id,
           ud_t_link.state,
           st_collect(st_buffer(ud_t_link.the_geom, 30::double precision)) AS geom
    FROM tiled.ud_t_link
    GROUP BY ud_t_link.expl_id, ud_t_link.state
    UNION
    SELECT ud_t_gully.expl_id,
           ud_t_gully.sector_id,
           ud_t_gully.state,
           st_collect(st_buffer(ud_t_gully.the_geom, 30::double precision)) AS geom
    FROM tiled.ud_t_gully
    GROUP BY ud_t_gully.expl_id, ud_t_gully.sector_id, ud_t_gully.state
) a
GROUP BY expl_id, state, sector_id
WITH DATA;
