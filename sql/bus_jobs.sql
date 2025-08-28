-- Bus Jobs Database Structure
-- This file contains all the SQL needed to set up the bus jobs system
-- Note: The stored procedures at the bottom are not used by the Lua code
-- All database operations are handled directly in the Lua code for simplicity

-- Create the bus_jobs table to store player statistics
CREATE TABLE IF NOT EXISTS `bus_jobs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `player_name` varchar(100) NOT NULL,
    `total_xp` int(11) DEFAULT 0,
    `current_level` int(11) DEFAULT 1,
    `total_distance` decimal(10,2) DEFAULT 0.00,
    `jobs_completed` int(11) DEFAULT 0,
    `total_earnings` decimal(10,2) DEFAULT 0.00,
    `last_job_date` timestamp NULL DEFAULT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create the bus_job_history table to track individual job completions
CREATE TABLE IF NOT EXISTS `bus_job_history` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `route_name` varchar(100) NOT NULL,
    `route_payment` decimal(10,2) NOT NULL,
    `passenger_bonus` decimal(10,2) DEFAULT 0.00,
    `total_payment` decimal(10,2) NOT NULL,
    `passengers_loaded` int(11) DEFAULT 0,
    `distance_traveled` decimal(10,2) DEFAULT 0.00,
    `xp_earned` int(11) DEFAULT 0,
    `completion_time` int(11) DEFAULT 0, -- in seconds
    `completed_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`),
    KEY `completed_at` (`completed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create the bus_leaderboard table for weekly/monthly rankings
CREATE TABLE IF NOT EXISTS `bus_leaderboard` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `player_name` varchar(100) NOT NULL,
    `period` enum('weekly','monthly') NOT NULL,
    `period_start` date NOT NULL,
    `total_xp` int(11) DEFAULT 0,
    `jobs_completed` int(11) DEFAULT 0,
    `total_earnings` decimal(10,2) DEFAULT 0.00,
    `total_distance` decimal(10,2) DEFAULT 0.00,
    `rank` int(11) DEFAULT 0,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_ranking` (`citizenid`, `period`, `period_start`),
    KEY `period_rank` (`period`, `period_start`, `rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Note: Level configuration is handled in config.lua
-- The Config.Leveling.levels table contains all level information

-- Create indexes for better performance
CREATE INDEX idx_bus_jobs_citizenid ON bus_jobs(citizenid);
CREATE INDEX idx_bus_job_history_citizenid ON bus_job_history(citizenid);
CREATE INDEX idx_bus_job_history_completed_at ON bus_job_history(completed_at);
CREATE INDEX idx_bus_leaderboard_period_rank ON bus_leaderboard(period, period_start, rank);

-- Create a view for easy leaderboard queries
CREATE OR REPLACE VIEW `bus_leaderboard_current` AS
SELECT 
    bj.citizenid,
    bj.player_name,
    bj.total_xp,
    bj.current_level,
    bj.total_distance,
    bj.jobs_completed,
    bj.total_earnings,
    ROW_NUMBER() OVER (ORDER BY bj.total_xp DESC) as global_rank
FROM bus_jobs bj
ORDER BY bj.total_xp DESC;

-- Create a stored procedure to update player statistics after job completion
DELIMITER //
CREATE PROCEDURE `UpdateBusJobStats`(
    IN p_citizenid VARCHAR(50),
    IN p_player_name VARCHAR(100),
    IN p_route_payment DECIMAL(10,2),
    IN p_passenger_bonus DECIMAL(10,2),
    IN p_total_payment DECIMAL(10,2),
    IN p_passengers_loaded INT,
    IN p_distance_traveled DECIMAL(10,2),
    IN p_xp_earned INT,
    IN p_completion_time INT,
    IN p_route_name VARCHAR(100)
)
BEGIN
    DECLARE v_current_xp INT;
    DECLARE v_new_level INT;
    DECLARE v_bonus_multiplier DECIMAL(5,2);
    
    -- Insert job history
    INSERT INTO bus_job_history (
        citizenid, route_name, route_payment, passenger_bonus, total_payment,
        passengers_loaded, distance_traveled, xp_earned, completion_time
    ) VALUES (
        p_citizenid, p_route_name, p_route_payment, p_passenger_bonus, p_total_payment,
        p_passengers_loaded, p_distance_traveled, p_xp_earned, p_completion_time
    );
    
    -- Update or insert player stats
    INSERT INTO bus_jobs (
        citizenid, player_name, total_xp, current_level, total_distance,
        jobs_completed, total_earnings, last_job_date
    ) VALUES (
        p_citizenid, p_player_name, p_xp_earned, 1, p_distance_traveled,
        1, p_total_payment, NOW()
    )
    ON DUPLICATE KEY UPDATE
        total_xp = total_xp + p_xp_earned,
        total_distance = total_distance + p_distance_traveled,
        jobs_completed = jobs_completed + 1,
        total_earnings = total_earnings + p_total_payment,
        last_job_date = NOW(),
        player_name = p_player_name;
    
    -- Get current XP and calculate new level
    SELECT total_xp, current_level INTO v_current_xp, v_new_level
    FROM bus_jobs WHERE citizenid = p_citizenid;
    
    -- Calculate new level based on XP
    SELECT MAX(level) INTO v_new_level
    FROM bus_levels 
    WHERE xp_required <= v_current_xp;
    
    -- Update level if changed
    IF v_new_level != (SELECT current_level FROM bus_jobs WHERE citizenid = p_citizenid) THEN
        UPDATE bus_jobs SET current_level = v_new_level WHERE citizenid = p_citizenid;
    END IF;
    
    -- Update leaderboard
    CALL UpdateLeaderboard(p_citizenid, p_player_name);
END //
DELIMITER ;

-- Create a stored procedure to update leaderboard
DELIMITER //
CREATE PROCEDURE `UpdateLeaderboard`(
    IN p_citizenid VARCHAR(50),
    IN p_player_name VARCHAR(100)
)
BEGIN
    DECLARE v_weekly_start DATE;
    DECLARE v_monthly_start DATE;
    
    -- Calculate period start dates
    SET v_weekly_start = DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY);
    SET v_monthly_start = DATE_FORMAT(CURDATE(), '%Y-%m-01');
    
    -- Update weekly leaderboard
    INSERT INTO bus_leaderboard (
        citizenid, player_name, period, period_start, total_xp, jobs_completed, total_earnings, total_distance
    )
    SELECT 
        citizenid, player_name, 'weekly', v_weekly_start, total_xp, jobs_completed, total_earnings, total_distance
    FROM bus_jobs 
    WHERE citizenid = p_citizenid
    ON DUPLICATE KEY UPDATE
        total_xp = VALUES(total_xp),
        jobs_completed = VALUES(jobs_completed),
        total_earnings = VALUES(total_earnings),
        total_distance = VALUES(total_distance);
    
    -- Update monthly leaderboard
    INSERT INTO bus_leaderboard (
        citizenid, player_name, period, period_start, total_xp, jobs_completed, total_earnings, total_distance
    )
    SELECT 
        citizenid, player_name, 'monthly', v_monthly_start, total_xp, jobs_completed, total_earnings, total_distance
    FROM bus_jobs 
    WHERE citizenid = p_citizenid
    ON DUPLICATE KEY UPDATE
        total_xp = VALUES(total_xp),
        jobs_completed = VALUES(jobs_completed),
        total_earnings = VALUES(total_earnings),
        total_distance = VALUES(total_distance);
    
    -- Update rankings
    UPDATE bus_leaderboard SET rank = (
        SELECT rank_num FROM (
            SELECT citizenid, ROW_NUMBER() OVER (ORDER BY total_xp DESC) as rank_num
            FROM bus_leaderboard 
            WHERE period = 'weekly' AND period_start = v_weekly_start
        ) ranked WHERE ranked.citizenid = bus_leaderboard.citizenid
    ) WHERE period = 'weekly' AND period_start = v_weekly_start;
    
    UPDATE bus_leaderboard SET rank = (
        SELECT rank_num FROM (
            SELECT citizenid, ROW_NUMBER() OVER (ORDER BY total_xp DESC) as rank_num
            FROM bus_leaderboard 
            WHERE period = 'monthly' AND period_start = v_monthly_start
        ) ranked WHERE ranked.citizenid = bus_leaderboard.citizenid
    ) WHERE period = 'monthly' AND period_start = v_monthly_start;
END //
DELIMITER ;
