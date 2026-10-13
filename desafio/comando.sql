CREATE MATERIALIZED VIEW mv_driver_season_summary AS
SELECT 
    r.year AS season_year,
    d.id AS driver_id,
    d.name,
    COUNT(*) AS total_races,
    COUNT(CASE WHEN rd.position_number = 1 THEN 1 END) AS total_wins,
    COUNT(CASE WHEN rd.position_number <= 3 THEN 1 END) AS total_podiums,
    COUNT(CASE WHEN rd.race_reason_retired IS NOT NULL THEN 1 END) AS total_dnfs,
    SUM(COALESCE(rd.points, 0)) AS total_points
FROM race_data rd
JOIN race r ON rd.race_id = r.id
JOIN driver d ON rd.driver_id = d.id
WHERE rd.type = 'RACE_RESULT'
GROUP BY
    r.year, 
    d.id,
    d.name,

CREATE UNIQUE INDEX idx_mv_driver_season_summary_unique 
ON mv_driver_season_summary (season_year, driver_id);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_driver_season_summary;

SELECT 
    season_year,
    name AS driver_name,
    total_races,
    total_wins,
    total_podiums,
    total_dnfs,
    total_points
FROM mv_driver_season_summary
WHERE (LOWER(forename) = 'ayrton' AND LOWER(surname) = 'senna')
   OR (driver_id = 'senna')
ORDER BY season_year DESC
LIMIT 10;


-- Auditoria

DROP TABLE IF EXISTS points_adjustment_audit CASCADE;

CREATE TABLE points_adjustment_audit (
    id         SERIAL PRIMARY KEY,
    year       INT NOT NULL,
    driver_id  VARCHAR(100) NOT NULL,
    old_points DECIMAL(8,2),
    new_points DECIMAL(8,2),
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION trg_audit_points_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.points IS DISTINCT FROM NEW.points) THEN
        INSERT INTO points_adjustment_audit (
            year,
            driver_id,
            old_points,
            new_points,
            changed_at
        ) VALUES (
            OLD.year,
            OLD.driver_id,
            OLD.points,
            NEW.points,
            NOW()
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_season_driver_standing_points_audit ON season_driver_standing;

CREATE TRIGGER trg_season_driver_standing_points_audit
AFTER UPDATE ON season_driver_standing
FOR EACH ROW
EXECUTE FUNCTION trg_audit_points_change();

UPDATE season_driver_standing
SET points = points + 100
WHERE year = 1993 
  AND driver_id = 'senna';

SELECT * FROM points_adjustment_audit;