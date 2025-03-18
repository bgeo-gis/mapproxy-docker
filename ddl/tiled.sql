-- Create schema 'tiled' to store the materialized views and logs table
CREATE SCHEMA tiled;

-- NOTE: Create DB user 'tileuser' in the DB

-- Too tile all the network, set the selectors for 'tileuser'
INSERT INTO selector_state SELECT id ,'tileuser' FROM value_state ON CONFLICT (state_id, cur_user) DO NOTHING;
INSERT INTO selector_expl SELECT expl_id ,'tileuser' FROM exploitation WHERE active is true ON CONFLICT (expl_id, cur_user) DO NOTHING;
INSERT INTO selector_sector SELECT sector_id ,'tileuser' FROM sector WHERE active is true ON CONFLICT (sector_id, cur_user) DO NOTHING;
INSERT INTO selector_municipality SELECT muni_id ,'tileuser' FROM ext_municipality WHERE active is true ON CONFLICT (muni_id, cur_user) DO NOTHING;

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
AS SELECT concat('E', expl_id, '-S', sector_id, '-T', state) AS tilecluster_id,
    expl_id,
    sector_id,
    state,
    st_multi(st_buffer(st_collect(geom), 0.01::double precision)) AS geom
   FROM ( SELECT ws_t_node.expl_id,
            ws_t_node.sector_id,
            ws_t_node.state,
            st_buffer(st_collect(ws_t_node.the_geom), 30::double precision) AS geom
           FROM tiled.ws_t_node
          GROUP BY ws_t_node.expl_id, ws_t_node.sector_id, ws_t_node.state
        UNION
         SELECT ws_t_arc.expl_id,
            ws_t_arc.sector_id,
            ws_t_arc.state,
            st_buffer(st_collect(ws_t_arc.the_geom), 30::double precision) AS geom
           FROM tiled.ws_t_arc
          GROUP BY ws_t_arc.expl_id, ws_t_arc.sector_id, ws_t_arc.state
        UNION
         SELECT ws_t_connec.expl_id,
            ws_t_connec.sector_id,
            ws_t_connec.state,
            st_buffer(st_collect(ws_t_connec.the_geom), 30::double precision) AS geom
           FROM tiled.ws_t_connec
          GROUP BY ws_t_connec.expl_id, ws_t_connec.sector_id, ws_t_connec.state
        UNION
         SELECT ws_t_link.expl_id,
            ws_t_link.sector_id,
            ws_t_link.state,
            st_buffer(st_collect(ws_t_link.the_geom), 30::double precision, 'endcap=flat join=round'::text) AS geom
           FROM tiled.ws_t_link
          GROUP BY ws_t_link.expl_id, ws_t_link.sector_id, ws_t_link.state) a
  GROUP BY expl_id, sector_id, state
WITH DATA;

-- FOR UD
CREATE MATERIALIZED VIEW tiled.ud_t_tileclusters
TABLESPACE pg_default
AS
SELECT concat('E', expl_id, '-S', sector_id, '-T', state) AS tilecluster_id,
       expl_id,
       sector_id,
       state,
       st_multi(st_buffer(st_collect(geom), 0.01::double precision)) AS geom
FROM (
    SELECT ud_t_node.expl_id,
           ud_t_node.sector_id,
           ud_t_node.state,
           st_buffer(st_collect(ud_t_node.the_geom), 30::double precision) AS geom
    FROM tiled.ud_t_node
    GROUP BY ud_t_node.expl_id, ud_t_node.sector_id, ud_t_node.state
    UNION
    SELECT ud_t_arc.expl_id,
           ud_t_arc.sector_id,
           ud_t_arc.state,
           st_buffer(st_collect(ud_t_arc.the_geom), 30::double precision) AS geom
    FROM tiled.ud_t_arc
    GROUP BY ud_t_arc.expl_id, ud_t_arc.sector_id, ud_t_arc.state
    UNION
    SELECT ud_t_connec.expl_id,
           ud_t_connec.sector_id,
           ud_t_connec.state,
           st_buffer(st_collect(ud_t_connec.the_geom), 30::double precision) AS geom
    FROM tiled.ud_t_connec
    GROUP BY ud_t_connec.expl_id, ud_t_connec.sector_id, ud_t_connec.state
    UNION
    SELECT ud_t_link.expl_id,
           ud_t_link.sector_id,
           ud_t_link.state,
           st_buffer(st_collect(ud_t_link.the_geom), 30::double precision, 'endcap=flat join=round'::text) AS geom
    FROM tiled.ud_t_link
    GROUP BY ud_t_link.expl_id, ud_t_link.sector_id, ud_t_link.state
    UNION
    SELECT ud_t_gully.expl_id,
           ud_t_gully.sector_id,
           ud_t_gully.state,
           st_buffer(st_collect(ud_t_gully.the_geom), 30::double precision) AS geom
    FROM tiled.ud_t_gully
    GROUP BY ud_t_gully.expl_id, ud_t_gully.sector_id, ud_t_gully.state
) a
GROUP BY expl_id, sector_id, state
WITH DATA;
