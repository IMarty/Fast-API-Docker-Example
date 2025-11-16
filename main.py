from fastapi import FastAPI
import redis
import os
import logging

import redis.exceptions

# Loggin setup
logging.basicConfig(filename='/app/logs/app.log', level=logging.INFO)

#Redis - Reaching another container
r = None
try:
    r = redis.Redis(host=os.getenv("REDIS_HOST","redis-db"), port=6379, db=0, socket_connect_timeout=1, decode_responses=True)
    r.ping()
    print("Database reached")
    logging.info("Database reached")
    if not r.exists('hits'):
        r.set("hits", 0)
except redis.exceptions.ConnectionError as e:
    print("Unable to reach Database - app will continue without Redis")
    logging.error(f"Unable to reach Database: {e}")
    r = None

app = FastAPI()
@app.get('/')
def index():
    return {"message":"Hello You All DLH Students"}

@app.get('/logs')
def write_log():
    logging.info("Coucou les amis")
    return {"message":"writing to /app/logs/app.log"}

@app.get('/vulnerability/{cmd}')
def run_cmd(cmd):
    eval(cmd)
    return {"message":"writing to /app/logs/app.log"}

@app.get('/hits')
def read_hit():
    if not r:
        return {"error": "Redis connection not established."}, 500  
    try:
        hits = r.incr("hits")
        return {"message": "This page has been viewed", "hits": hits}
    except redis.exceptions.ConnectionError as e:
        return {"error": f"Redis connection failed: {e}"}, 500