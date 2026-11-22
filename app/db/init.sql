-- Used by docker-compose only. The API also creates these tables on startup (for RDS).
CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, username TEXT UNIQUE, password TEXT);
CREATE TABLE IF NOT EXISTS products (id SERIAL PRIMARY KEY, name TEXT, price NUMERIC);
-- VULNERABLE BY DESIGN - TESTING ONLY: plaintext passwords
INSERT INTO users (username, password) VALUES ('admin','admin123'),('guest','guest') ON CONFLICT DO NOTHING;
INSERT INTO products (name, price) VALUES ('Laptop',900),('Phone',500),('Headphones',80);
