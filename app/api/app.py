import logging
import os

import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("api")


def client_ip():
    return request.headers.get("X-Forwarded-For", request.remote_addr)


def db():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],  # injected from Secrets Manager on AWS
        sslmode=os.environ.get("DB_SSLMODE", "prefer"),
        connect_timeout=5,
    )


def ensure_schema():
    """Create tables and seed demo data if the DB is empty (needed on fresh RDS)."""
    conn = db()
    cur = conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, username TEXT UNIQUE, password TEXT)")
    cur.execute("CREATE TABLE IF NOT EXISTS products (id SERIAL PRIMARY KEY, name TEXT, price NUMERIC)")
    cur.execute("SELECT count(*) FROM users")
    if cur.fetchone()[0] == 0:
        # VULNERABLE BY DESIGN - TESTING ONLY: plaintext demo passwords
        cur.execute("INSERT INTO users (username, password) VALUES ('admin','admin123'),('guest','guest')")
        cur.execute("INSERT INTO products (name, price) VALUES ('Laptop',900),('Phone',500),('Headphones',80)")
    conn.commit()
    conn.close()


@app.get("/api/health")
def health():
    return {"status": "ok"}


# VULNERABLE BY DESIGN - TESTING ONLY
# Weak login: plaintext password comparison, no lockout, no rate limiting,
# and different error messages reveal which usernames exist.
@app.post("/api/login")
def login():
    data = request.get_json(force=True)
    conn = db()
    cur = conn.cursor()
    cur.execute("SELECT password FROM users WHERE username=%s", (data.get("username"),))
    row = cur.fetchone()
    conn.close()
    if row is None:
        log.warning("LOGIN_FAIL unknown_user user=%s ip=%s", data.get("username"), client_ip())
        return jsonify(error="unknown user"), 401
    if row[0] != data.get("password"):
        log.warning("LOGIN_FAIL bad_password user=%s ip=%s", data.get("username"), client_ip())
        return jsonify(error="wrong password"), 401
    log.info("LOGIN_OK user=%s ip=%s", data.get("username"), client_ip())
    return jsonify(message="welcome")


# VULNERABLE BY DESIGN - TESTING ONLY
# SQL injection: user input is concatenated directly into the query string.
@app.get("/api/search")
def search():
    q = request.args.get("q", "")
    log.info("SEARCH q=%s ip=%s", q, client_ip())
    try:
        conn = db()
        cur = conn.cursor()
        cur.execute("SELECT id, name, price FROM products WHERE name ILIKE '%" + q + "%'")
        rows = cur.fetchall()
        conn.close()
        return jsonify(results=[{"id": r[0], "name": r[1], "price": float(r[2])} for r in rows])
    except Exception as e:  # verbose error is also weak on purpose
        return jsonify(error=str(e)), 500


try:
    ensure_schema()
except Exception as e:  # DB may not be up yet; gunicorn keeps running
    log.error("schema init failed: %s", e)
