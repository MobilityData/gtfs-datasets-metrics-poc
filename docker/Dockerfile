FROM openjdk:11
# FROM ghcr.io/mobilitydata/gtfs-validator:4.1.0

# Install dependencies for gsutil
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install gsutil
RUN curl https://sdk.cloud.google.com | bash
ENV PATH $PATH:/root/google-cloud-sdk/bin

# Copy the shell script, Java jar file, and any other necessary files
COPY gtfs-validator-reporter.sh /
COPY gtfs-validator-reporter-entry.sh /
# The intended use of gtfs-validator-cli-help.jar is to render the latest command arguments descriptios.
COPY gtfs-validator-cli-help.jar /

# Set the working directory
WORKDIR /

# Make the shell script executable
RUN chmod +x gtfs-validator-reporter.sh
RUN chmod +x gtfs-validator-reporter-entry.sh

# Define the entry point
ENTRYPOINT ["./gtfs-validator-reporter-entry.sh"]
