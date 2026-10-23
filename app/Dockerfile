FROM python:3.12-slim
LABEL authors="umeshdas"
WORKDIR /app
RUN useradd --create-home appuser
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY main.py .
# The release (git commit) this image was built from; /healthz reports it. Set late so it doesn't bust the pip cache.
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
USER appuser
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]