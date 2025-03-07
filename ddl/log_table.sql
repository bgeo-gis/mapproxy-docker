
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
