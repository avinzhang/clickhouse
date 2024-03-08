SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
CREATE TABLE student (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255) NOT NULL, age INT, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP);

INSERT INTO student(name, age) VALUES 
('Alex', 16),
('John', 26),
('Alford', 18),
('Ravi', 20),
('Benjamin', 19);
