# Use a base image that includes bash and allows us to install expect
FROM ubuntu:latest

# Install expect
RUN apt-get update && apt-get install -y expect && apt-get install openssh-client -y && rm -rf /var/lib/apt/lists/*

# Copy the script into the container
COPY firsttimessh.sh /firsttimessh.sh

# Make the script executable
RUN chmod +x /firsttimessh.sh

# Environment variables (these will be overwritten by Kubernetes environment variables at runtime)
ENV SSH_HOST=20.239.245.125
ENV SSH_PORT=2222
ENV SSH_USERNAME=admin
ENV SSH_NEW_PASSWORD=Welcome.123

# Command to execute the script with environment variables
CMD  /firsttimessh.sh $SSH_HOST $SSH_PORT $SSH_USERNAME $SSH_NEW_PASSWORD

