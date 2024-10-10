;--------------------------------
;Include Modern UI

  !include "MUI2.nsh"

Var SectionIndex

;--------------------------------
;General

  ;Name and file
  Name "Docker Compose Installer"
  OutFile "DockerComposeInstaller.exe"

  ;Default installation folder
  InstallDir "$PROGRAMFILES\TOOLKITFORFOCUS"



; Define the logo image
!define MUI_ICON ./assets/logo.ico

;--------------------------------
;Interface Settings

  !define MUI_ABORTWARNING

;--------------------------------
;Pages

  !insertmacro MUI_PAGE_LICENSE ".\assets\License.txt"
  !insertmacro MUI_PAGE_COMPONENTS
  !insertmacro MUI_PAGE_DIRECTORY
  !insertmacro MUI_PAGE_INSTFILES

  !insertmacro MUI_UNPAGE_CONFIRM
  !insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
;Languages

  !insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections

; ----------- LLM SECTION-----------------
    Section "Install Local-LLM-Container" Section1
        ; Check for docker and docker compose
        Call CheckForDocker

        ; Create the installation directory
        CreateDirectory "$INSTDIR"
        CreateDirectory "$INSTDIR\local-llm-container"

        SetOutPath "$INSTDIR\local-llm-container"    ; Set the output directory to the installation folder

        File '.\assets\License.txt'

        File '.\local-llm-container\'

        Goto done
        done:
        
        ; MOVE TO END OF INSTALL
        ;nsExec::ExecToLog 'docker-compose -f "$INSTDIR\local-llm-container\docker-compose.yml" up -d --build'


    SectionEnd
    LangString DESC_Section1 ${LANG_ENGLISH} "Turnkey local llm container to support other activities and tools we are developing. This will host your own LLM with accesible API."

;------------ LLM SECTION END -------------


;---------------- Speech2Text Section--------------------

    Section "Install Speech2Text-Container" Section2

    SectionEnd
    LangString DESC_Section2 ${LANG_ENGLISH} "Containerized solution for AI speech-to-text that can run locally. This runs a whisper server with accessible API."
;---------------- Speech2Text Section End ----------------


;---------- FreeScribe Section ----------------------
    Section "Install Freescribe Client" Section3

    SectionEnd
    LangString DESC_Section3 ${LANG_ENGLISH} "A medical scribe capable of creating SOAP notes running Whisper and Kobold based on conversation with a patient"
;---------- FreeScribe Section End ------------------


;--------------------------------
;Descriptions

  ;Language strings
  LangString DESC_SecDockerCompose ${LANG_ENGLISH} "Install Docker Compose and run the Docker Compose file."

  ;Assign language strings to sections
  !insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
      !insertmacro MUI_DESCRIPTION_TEXT ${Section1} $(DESC_Section1)
      !insertmacro MUI_DESCRIPTION_TEXT ${Section2} $(DESC_Section2)
      !insertmacro MUI_DESCRIPTION_TEXT ${Section3} $(DESC_Section3)
  !insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------
;Uninstaller Section

Section "Uninstall"

  ; Remove installation directory
  RMDir "$INSTDIR"

  ; Remove registry key
  DeleteRegKey /ifempty HKCU "Software\DockerCompose"

SectionEnd


; --------- UTIL FUNCTIONS -----------
    Function CheckForDocker

        ; Run the Docker Compose version command
        nsExec::ExecToStack 'docker-compose --version'
        Pop $0  ; exit code of command
        Pop $1  ; command output

        ; Check if Docker Compose is installed
        StrCmp $0 "0" +3 0
            ; If not installed, display an error and abort
            MessageBox MB_OK "Docker Compose is not installed. Please install it before continuing. Canceling Install..."
            Abort

        ; If installed, continue
        Goto CheckDocker

    CheckDocker:
        ; Check if Docker is installed
        nsExec::ExecToStack 'docker --version'
        Pop $0  ; exit code of command
        Pop $1  ; command output
        
        StrCmp $0 "0" +3 0
            ; If Docker is not installed, display an error and abort
            MessageBox MB_OK "Docker is not installed. Please install it before continuing. Canceling Install..."
            Abort

        ; If both Docker and Docker Compose are installed, continue with the installation
        Goto Done

    Done:
    FunctionEnd

