FROM python:3.11-slim

WORKDIR /usr/src/app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy dbt project
COPY . .

# Set up profiles directory
ENV DBT_PROFILES_DIR=/usr/src/app

# Default command
CMD ["dbt", "debug"]
