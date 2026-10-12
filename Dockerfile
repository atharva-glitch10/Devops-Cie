# Small official Python image (Debian slim variant)
FROM python:3.12-slim

# No .pyc clutter, unbuffered logs (so `docker logs` shows output immediately)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=5000 \
    DATABASE_PATH=/data/students.db

# Create an unprivileged user and a data directory it owns
RUN useradd --create-home --uid 10001 appuser \
    && mkdir /data && chown appuser:appuser /data

WORKDIR /app

# Copy requirements first so Docker can cache the dependency layer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY templates/ templates/
COPY static/ static/

USER appuser
EXPOSE 5000

# Python-based check, so we don't need curl inside the image
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=2)"

# One worker + threads: the in-process Prometheus metrics stay correct,
# and a single SQLite writer process avoids lock contention.
# 0.0.0.0 makes the server reachable from outside the container.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "4", "app:create_app()"]
