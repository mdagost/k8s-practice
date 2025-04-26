FROM python:3.10.8
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /code

COPY app.py pyproject.toml uv.lock /code/

RUN uv sync --locked

CMD ["uv", "run", "fastapi", "run", "app.py", "--port", "80"]
