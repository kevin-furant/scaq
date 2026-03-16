CREATE DATABASE IF NOT EXISTS taskdb;

USE taskdb;

CREATE TABLE task_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    year INT,
    time DATETIME,
    batch_name VARCHAR(100),
    sample_name VARCHAR(100),
    data_path VARCHAR(255)
);

CREATE INDEX idx_time ON task_records(time);
CREATE INDEX idx_year ON task_records(year);
CREATE INDEX idx_batch ON task_records(batch_name);