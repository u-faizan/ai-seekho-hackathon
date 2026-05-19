# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set environment variables to prevent Python from writing pyc files and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file first to leverage Docker caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Expose the port FastAPI will run on
EXPOSE 8080

# Command to run the application using uvicorn
# Note: we use main:app because main.py contains the FastAPI 'app' instance
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
