FROM python:3.11-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install network debugging tools
RUN apt-get update && apt-get install -y curl iputils-ping telnet

COPY . .

# Render sets $PORT; bind uvicorn to it
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port $PORT"]