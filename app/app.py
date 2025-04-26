import os

from fastapi import FastAPI

app = FastAPI()


@app.get("/health")
async def hello():
    return {"OK"}


@app.get("/hello")
async def hello():
    return {"message": f"Hello to {os.environ['NAME']} from {os.environ['ENVIRONMENT']}!!"}
