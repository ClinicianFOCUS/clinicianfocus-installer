# ClincianFOCUS Toolbox Installer

This project automates the setup of Docker containers and the installation of the FreeScribe client.

## Prerequisites

Ensure you have the following installed on your system before running the script:

- **Docker**: If Docker is not installed, the script will prompt you to install it. Follow the installation guide [here](https://docs.docker.com/install/).
- **Docker Compose**: If Docker Compose is not installed, the script will also prompt you to install it. Follow the installation guide [here](https://docs.docker.com/compose/install/).

- This script is designed to run on Windows environments only.

## Running the Script

- Download the exe from releases.
- Launch and follow the steps!

## Changing Network Profile From Public To Private

For Windows:

1. Click on the Network icon in the system tray (near the clock) and select “Open Network & Internet settings”.
2. Click on “Ethernet” or “Wi-Fi” (depending on your connection type) and select the connected network.
3. Look for the “Network profile type” or “Network location” section.
4. Change to Private Network.

## Additional Notes

- To obtain API key follow these steps:
  1. Start the Docker container.
  2. Access the Docker logs to view the API key.
  3. Use the API key on the settings page for the Speech2Text (Whisper) API Key and AI Server API Key.