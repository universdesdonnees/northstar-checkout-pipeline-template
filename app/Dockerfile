FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN groupadd --system northstar \
    && useradd --system --gid northstar --no-create-home northstar

COPY requirements.txt .
RUN pip install --no-cache-dir --disable-pip-version-check --root-user-action=ignore -r requirements.txt

COPY --chown=northstar:northstar app.py .
COPY --chown=northstar:northstar templates ./templates
COPY --chown=northstar:northstar static ./static

ARG APP_VERSION=1.0.0
LABEL org.opencontainers.image.title="Northstar Checkout" \
      org.opencontainers.image.version="$APP_VERSION"
ENV APP_VERSION="$APP_VERSION"

USER northstar
EXPOSE 8080

HEALTHCHECK --interval=5s --timeout=3s --start-period=3s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')"]

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", "app:app"]
