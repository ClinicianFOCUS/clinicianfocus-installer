.. Toolbox Installer documentation master file, created by
   sphinx-quickstart on Thu Dec 19 12:20:56 2024.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Installation Guide
=========================================

This guide explains how to install the **ClinicianFOCUS Toolbox Installer** step by step.

Prerequisites
-------------
Before proceeding, ensure you meet the following prerequisites:

- The installer defaults to a NVIDIA GPU Installation for the containers. Ensure you have an NVIDIA GPU installed on your system.

Installation Steps
------------------

1. **Download the Installer**
        - The latest version of the **ClinicianFOCUS Toolbox Installer** from the official source. Found `here <https://github.com/ClinicianFOCUS/clinicianfocus-installer/releases>`_
      
2. **Launch the Installer**
        - Double-click the downloaded executable file to begin the installation.

3. **Accept the License Agreement**
        - Review the license terms provided in the installer.
        - Click on :guilabel:`I Agree` to proceed.

4. **Select Installation Mode**
    Choose your preferred installation mode:
        - :guilabel:`Basic Install (Recommended)` — Installs the default configuration.
        - :guilabel:`Advanced Install` — Allows customization of components.
        - Click :guilabel:`Next`.

5. **Choose Components**
    Select the components you want to install:
        - **Local LLM Container**
        - **Speech to Text Container**
        - **FreeScribe Client**
        - **Uninstaller**
        - Click :guilabel:`Next` to continue.

6. **Choose Architecture for FreeScribe**
    Choose the installation architecture based on your hardware:
      - :guilabel:`CPU` (Recommended) — For general use.
      - :guilabel:`NVIDIA` — For accelerated performance (requires an NVIDIA GPU).
      - Click :guilabel:`Next`.

7. **Select Install Location**
        - Choose the destination folder where the toolbox will be installed. The default path is: `C:\Program Files (x86)\ClinicianFOCUS Toolbox`
        - Click :guilabel:`Next`.

8. **Install the Toolbox**
        - The installation process will begin.
        - Monitor the progress bar as components are installed.

9. **Docker Installation**
        - During installation, Docker Desktop may be installed.
        - If prompted, restart your computer and relaunch the **ClinicianFOCUS Toolbox Installer**.

        .. note::
            Docker Desktop is required for running components such as the Local LLM and Speech-to-Text Container.

10. **Complete Installation**
        - Follow any remaining on-screen prompts to complete the installation.
        - Click :guilabel:`Finish` when done.

Post-Restart Instructions
--------------------------
After restarting your computer, follow these steps to complete the setup:

1. **Launch Docker Desktop**

      Docker Desktop will be automatically launched. Perform the following actions:

      - Accept the Docker license agreement.
      - Log in to your Docker account (or create one if needed).
      - Wait for Docker to fully start.

      Click :guilabel:`OK` in the installer once Docker is running.

2. **Inbound Firewall Rules**

      The installer will configure inbound firewall rules for the Speech-to-Text (STT) container (Port: 2224).

3. **Completion of Installation**

    The setup will display the following endpoints for the installed services:
        - **API Key (LLM and STT)**    
        - **Local LLM API Endpoint**
        - **Speech-to-Text API Endpoint**

    Save these endpoints for future use.

4. **Launch Installed Components**

      At the end of the installation, you will have the option to launch the following components:
         - **Local LLM**
         - **Speech2Text**
         - **FreeScribe**

      Recommended Actions:
         - Start Docker Desktop before launching Local LLM and Speech2Text.
         - Launch Local LLM and Speech2Text to build the container images.
         - Wait for the build process to complete.

5. **Verify Installation**

      Verify that all installed components are running correctly. Ensure Docker Desktop is running and the necessary containers are active. If error occurs you will encounter installation errors.

Advanced Settings
-----------------

This guide provides detailed explanations for the advanced settings available during the installation of the ClinicianFOCUS Toolbox.

Password (API Key)
^^^^^^^^^^^^^^^^^^

**Description:**
    This field allows you to set a password that will act as your API key for accessing the Whisper and LLM (Large Language Model) services.

**Options:**

    - **Password (API Key):** Enter a custom API key that will be securely stored for future use.
    - **Generate API Key:** Click this button to auto-generate a strong API key.

**Note:**
    Keep this key secure, as it is required for authentication when using the Whisper and LLM services.


Model Selection
^^^^^^^^^^^^^^^

**Description:**
    Select the Large Language Model (LLM) to be used with the ClinicianFOCUS Toolbox. This model determines the quality and functionality of the AI features.

**Options:**

- **Pre-configured Models:**
  - ``gemma2: b-instruct-q8_0``: A recommended pre-configured model optimized for general use cases.
- **Custom:** Select this option if you have a specific model to configure.

**Huggingface Token:**
    If using a gated model from `Hugging Face <https://huggingface.co/>`_, you must enter your Hugging Face API token to access it.

**Note:**
    Ensure that the model selected aligns with your use case and computational resources.

Whisper Model Selection
^^^^^^^^^^^^^^^^^^^^^^^

**Description:**
    Choose the Whisper model size to configure the speech-to-text functionality. Larger models are more accurate but require more resources.

**Options:**

- **tiny (1GB):** Fastest, but least accurate.
- **base (1GB):** Fast with basic accuracy.
- **small (2GB):** Balanced speed and accuracy.
- **medium (5GB):** Recommended for good accuracy.
- **large (10GB):** Best accuracy but slowest.

**Recommendation:**
    The **medium** model is recommended for most users as it provides a good balance between accuracy and performance.

Installation Workflow
^^^^^^^^^^^^^^^^^^^^^

1. **API Key Setup:** Enter or generate a secure API key for service access.
2. **Model Selection:** Choose a pre-configured or custom model, and provide your Hugging Face API token if required.
3. **Whisper Model Selection:** Select a model size based on your resource availability and accuracy requirements.
4. **Finalize Installation:** Click **Install** to complete the setup.

Additional Notes
^^^^^^^^^^^^^^^^

- The installation requires sufficient disk space for the selected models.
- Ensure internet connectivity for downloading model.
