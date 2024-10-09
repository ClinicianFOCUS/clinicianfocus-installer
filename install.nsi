!include "MUI2.nsh"

; Define constants
!define MUI_PRODUCT "MyGitHubRepoInstaller"
!define MUI_VERSION "1.0"
!define MUI_BRANDINGTEXT "My GitHub Repo Installer"
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Launch Docker Compose"
!define MUI_FINISHPAGE_RUN_FUNCTION "LaunchDockerCompose"

; Define the GitHub repository URL
!define GITHUB_REPO_URL "https://github.com/username/repo/archive/main.zip"

; Define the installation directory
!define INSTALL_DIR "$PROGRAMFILES\MyGitHubRepo"

; Define the temporary directory for downloading and unzipping
!define TEMP_DIR "$TEMP\MyGitHubRepo"

; Define the Docker Compose file path
!define DOCKER_COMPOSE_FILE "${INSTALL_DIR}\docker-compose.yml"

; Modern UI settings
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${NSISDIR}\Docs\Modern UI\License.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; Language settings
!insertmacro MUI_LANGUAGE "English"

; Installer sections
Section "Install"
    ; Create the installation directory
    CreateDirectory "${INSTALL_DIR}"

    ; Download the GitHub repo zip file
    inetc::get /NOCANCEL /SILENT "${GITHUB_REPO_URL}" "${TEMP_DIR}\repo.zip"

    ; Unzip the downloaded file
    nsisunz::UnzipToLog "${TEMP_DIR}\repo.zip" "${TEMP_DIR}"

    ; Move the contents to the installation directory
    CopyFiles /SILENT "${TEMP_DIR}\repo-main\*" "${INSTALL_DIR}"

    ; Clean up temporary files
    Delete "${TEMP_DIR}\repo.zip"
    RMDir /r "${TEMP_DIR}\repo-main"
    RMDir "${TEMP_DIR}"
SectionEnd

; Function to launch Docker Compose
Function LaunchDockerCompose
    Exec '"cmd" /c "cd ${INSTALL_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} up -d"'
FunctionEnd

; Installer functions
Function .onInit
    ; Check if Docker is installed
    IfFileExists "$PROGRAMFILES\Docker\Docker\Docker Desktop.exe" DockerInstalled
    MessageBox MB_OK|MB_ICONSTOP "Docker Desktop is not installed. Please install Docker Desktop to use this installer."
    Abort
    DockerInstalled:
FunctionEnd

; Uninstaller sections
Section "Uninstall"
    ; Remove the installation directory
    RMDir /r "${INSTALL_DIR}"
SectionEnd
