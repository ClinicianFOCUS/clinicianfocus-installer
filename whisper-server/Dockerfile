# Use the official Python image
FROM python:3.10

# Set the working directory
WORKDIR /

# Copy the FastAPI application code into the container
COPY ./whisper-server/requirements.txt .
COPY ./whisper-server/server.py .

# Install the required packages
RUN pip install --no-cache-dir -r requirements.txt

# Expose the port the app runs on
EXPOSE 2224

# Command to run the FastAPI application
CMD ["python", "server.py", "--port", "2224"]
