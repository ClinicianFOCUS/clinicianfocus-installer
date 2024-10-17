;--------------------------------
;Include Modern UI and nsDialogs
; Include necessary NSIS plugins and libraries
    !include "MUI2.nsh"
    !include "nsDialogs.nsh"
    !include WinVer.nsh
    !include LogicLib.nsh
    !include Sections.nsh

    ; Declare variables for checkboxes and installation status
    Var Checkbox_LLM
    Var Checkbox_Speech2Text
    Var Checkbox_FreeScribe

    Var LLM_Installed
    Var Speech2Text_Installed
    Var FreeScribe_Installed

    Var DropDown_Model
    Var Input_HFToken

    Var Docker_Installed
    Var WSL_Installed

;--------------------------------
;General
; Set general installer properties
    Name "ClinicianFOCUS Toolbox Installer"
    OutFile "clinicianfocus_toolbox-installer.exe"

    InstallDir "$PROGRAMFILES\ClincianFOCUS Toolbox"

    ; Define the logo image
    !define MUI_ICON "./assets/logo.ico"

    !define MUI_ABORTWARNING

;--------------------------------
;Pages
; Define the installer pages
    !insertmacro MUI_PAGE_LICENSE ".\assets\License.txt"
    ; Page custom DependenciesPageCreate DependenciesPageLeave
    !insertmacro MUI_PAGE_COMPONENTS
    !insertmacro MUI_PAGE_DIRECTORY
    Page custom ConditionalModelPageCreate ModelPageLeave
    !insertmacro MUI_PAGE_INSTFILES
    Page custom FinishPageCreate FinishPageLeave

    !insertmacro MUI_UNPAGE_CONFIRM
    !insertmacro MUI_UNPAGE_INSTFILES

    !insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections
; Define the installer sections
    SectionGroup "Local LLM Container" SEC_GROUP_LLM
        Section "Local-LLM-Container Module" SEC_LLM
            
            CreateDirectory "$INSTDIR\local-llm-container"
            CreateDirectory "$INSTDIR\local-llm-container\models"
            SetOutPath "$INSTDIR\local-llm-container"
            File ".\local-llm-container\*.*"
            StrCpy $LLM_Installed 1
        SectionEnd

        Section "Docker for LLM" SEC_DOCKER_LLM
            ${If} $Docker_Installed == 0
                Call InstallDocker
            ${Else}
                    MessageBox MB_OK "Docker is already installed on your system."
            ${EndIf}
        SectionEnd

        Section "WSL2 for LLM" SEC_WSL_LLM
            ${If} $WSL_Installed == 0
                Call InstallWSL2
            ${Else}
                MessageBox MB_OK "WSL2 is already installed on your system."
            ${EndIf}
        SectionEnd
    SectionGroupEnd

    SectionGroup "Speech to Text Container" SEC_GROUP_S2T
        Section "Speech2Text-Container Module" SEC_S2T
            CreateDirectory "$INSTDIR\speech2text-container"
            SetOutPath "$INSTDIR\speech2text-container"
            File ".\speech2text-container\*.*"
            StrCpy $Speech2Text_Installed 1
        SectionEnd

        Section "Docker for Speech2Text" SEC_DOCKER_S2T
            ${If} $Docker_Installed == 0
                Call InstallDocker
            ${Else}
                    MessageBox MB_OK "Docker is already installed on your system."
            ${EndIf}
        SectionEnd

        Section "WSL2 for Speech2Text" SEC_WSL_S2T
            ${If} $WSL_Installed == 0
                Call InstallWSL2
            ${Else}
                MessageBox MB_OK "WSL2 is already installed on your system."
            ${EndIf}
        SectionEnd
    SectionGroupEnd

    Section "Freescribe Client" SEC_FREESCRIBE
        ; Create directories for Freescribe Client
        CreateDirectory "$INSTDIR\freescribe"
        SetOutPath "$INSTDIR\freescribe"
        File ".\freescribe\FreeScribeInstaller_windows.exe"

        ; Execute Freescribe installer silently
        ExecWait '"$INSTDIR\freescribe\FreeScribeInstaller_windows.exe" /S /D=$APPDATA\FreeScribe'

        StrCpy $FreeScribe_Installed 1
    SectionEnd

    Section "Uninstaller" SEC_UNINSTALLER
        ; Write uninstaller executable
        WriteUninstaller "$INSTDIR\uninstall.exe"
    SectionEnd

    Function InstallDocker
        ; Attempt to download Docker installer using inetc::get
        inetc::get /TIMEOUT=30000 "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe" "$TEMP\DockerInstaller.exe" /END
        Pop $R0 ;Get the return value
        ${If} $R0 == "OK"
            ; ExecWait '"$TEMP\DockerInstaller.exe" install --quiet'
            Delete "$TEMP\DockerInstaller.exe"
            Exec "$PROGRAMFILES64/Docker/Docker/Docker Desktop.exe"
        ${Else}
            MessageBox MB_YESNO "Docker download failed (Error: $R0). Would you like to download it manually?$\n$\nClick Yes to open the Docker download page in your browser.$\nClick No to skip Docker installation." IDYES OpenDockerPage IDNO SkipDockerInstall
            OpenDockerPage:
                ExecShell "open" "https://www.docker.com/products/docker-desktop"
                MessageBox MB_OK "Please download and install Docker manually, then click OK to continue with the installation."
        ${EndIf}
        SkipDockerInstall:
    FunctionEnd

    Function InstallWSL2
        ; Download the WSL2 update package
        inetc::get /TIMEOUT=30000 "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" "$TEMP\wsl_update_x64.msi" /END
        Pop $R0 ;Get the return value
        ${If} $R0 == "OK"
            ; Install WSL2 update package silently
            ExecWait 'msiexec /i "$TEMP\wsl_update_x64.msi" /qn'
            Delete "$TEMP\wsl_update_x64.msi"
            
            ; Enable WSL feature
            ExecWait 'dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart'
            
            ; Enable Virtual Machine feature
            ExecWait 'dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart'
            
            ; Set WSL 2 as the default version
            ExecWait 'wsl --set-default-version 2'
        ${Else}
            MessageBox MB_OK "WSL2 download failed (Error: $R0). Please install WSL2 manually after the installation."
        ${EndIf}
    FunctionEnd

;--------------------------------
; On installer start
; Define actions to take when the installer starts
    Function .onInit
        ${IfNot} ${AtLeastWin10}
            MessageBox MB_OK|MB_ICONSTOP "This installer requires Windows 10 or later.$\nPlease upgrade your operating system and try again."
            Quit
        ${EndIf}

        !insertmacro SetSectionFlag ${SEC_UNINSTALLER} ${SF_RO} 

        ; Check if Docker is installed and running
        nsExec::ExecToStack 'docker --version'
        Pop $0  ; Return value
        Pop $1  ; Output
        ${If} $0 == 0
            StrCpy $Docker_Installed 1
            !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DOCKER_LLM} "Docker is already installed"
            !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DOCKER_S2T} "Docker is already installed"
        ${Else}
            StrCpy $Docker_Installed 0
        ${EndIf}

        ; Check if WSL is installed
        ReadRegDWORD $R0 HKLM "SYSTEM\CurrentControlSet\Services\WslService" "Start"
        ${If} $R0 != ""
            StrCpy $WSL_Installed 1
            !insertmacro MUI_DESCRIPTION_TEXT ${SEC_WSL_LLM} "WSL2 is already installed"
            !insertmacro MUI_DESCRIPTION_TEXT ${SEC_WSL_S2T} "WSL2 is already installed"
        ${Else}
            StrCpy $WSL_Installed 0
        ${EndIf}

        ; Set up section dependencies
        SectionGetFlags ${SEC_LLM} $0
        IntOp $0 $0 | ${SF_EXPAND}
        SectionSetFlags ${SEC_LLM} $0

        SectionGetFlags ${SEC_S2T} $0
        IntOp $0 $0 | ${SF_EXPAND}
        SectionSetFlags ${SEC_S2T} $0
    FunctionEnd

;--------------------------------
;Descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_LLM} "Install Local LLM Container"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DOCKER_LLM} "Install Docker for Local LLM (required if not already installed)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_WSL_LLM} "Install WSL2 for Local LLM (required for Docker)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_S2T} "Install Speech2Text Container"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DOCKER_S2T} "Install Docker for Speech2Text (required if not already installed)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_WSL_S2T} "Install WSL2 for Speech2Text (required for Docker)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_FREESCRIBE} "Install Freescribe Client"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------
;Uninstaller Section
; Define the uninstaller section
    Section "Uninstall"
        ; Close all docker containers
        ExecWait 'docker-compose -f "$INSTDIR\local-llm-container\docker-compose.yml" down'
        ExecWait 'docker-compose -f "$INSTDIR\speech2text-container\docker-compose.yml" down'

        ; Delete files installed for Local LLM Container
        Delete "$INSTDIR\local-llm-container\*.*"
        RmDir "$INSTDIR\local-llm-container\models"
        RmDir "$INSTDIR\local-llm-container"

        ; Delete files installed for Speech2Text Container
        Delete "$INSTDIR\speech2text-container\*.*"
        RmDir "$INSTDIR\speech2text-container"

        ; Delete Freescribe installed files
        Delete "$INSTDIR\freescribe\FreeScribeInstaller_windows.exe"
        RmDir "$INSTDIR\freescribe"

        ; Remove uninstaller
        Delete "$INSTDIR\uninstall.exe"

        ; Finally, remove the installation directory if empty
        RmDir "$INSTDIR"

        ; Optionally delete the registry entry (if created)
        ;!include "WinMessages.nsh"
        ;RMDir /r "$APPDATA\FreeScribe"
        ;RegDelete "HKCU\Software\ClinicianFOCUS\Toolbox"
    SectionEnd

;--------------------------------
;Conditional Model Selection Page Display
; Define the conditional model selection page
    Function ConditionalModelPageCreate
        SectionGetFlags ${SEC_LLM} $0
        IntOp $0 $0 & ${SF_SELECTED}
        ${If} $0 == ${SF_SELECTED}
            Call ModelPageCreate
        ${EndIf}
    FunctionEnd
;--------------------------------
;Model Selection Page Customization using nsDialogs
; Define the model selection page
    Function ModelPageCreate
        nsDialogs::Create 1018
        Pop $0
        ${If} $0 == error
            Abort
        ${EndIf}

        ; Create dropdown for Model selection
        ${NSD_CreateLabel} 0u 0u 100% 12u "Model:"
        ${NSD_CreateComboBox} 0u 14u 100% 12u ""
        Pop $DropDown_Model

        ${NSD_CB_AddString} $DropDown_Model "google/gemma-2-2b-it"
        ${NSD_CB_AddString} $DropDown_Model "Custom"
        ${NSD_CB_SelectString} $DropDown_Model "google/gemma-2-2b-it" ; Default selection

        ; Create input for Huggingface Token
        ${NSD_CreateLabel} 0u 30u 100% 12u "Huggingface Token:"
        ${NSD_CreateText} 0u 44u 100% 12u ""
        Pop $Input_HFToken

        nsDialogs::Show
    FunctionEnd

    Function ModelPageLeave
        ${NSD_GetText} $DropDown_Model $1  # $0 will hold the user input
        StrCmp $1 "Custom" 0 +2
        MessageBox MB_OK "Please read the documentation for custom model use. This is for advanced users only."
        
        ; Get the Huggingface token
        ${NSD_GetText} $Input_HFToken $2

        ; Create the .env directories for the Local LLM container
        CreateDirectory "$INSTDIR"
        CreateDirectory "$INSTDIR\local-llm-container\"

        ; Define the file path for the .env file
        StrCpy $0 "$INSTDIR\local-llm-container\.env"

        ; Open the .env file for writing (will create the file if it doesn't exist)
        FileOpen $3 $0 w
        ${If} $3 == ""
            ; Get the last error code
            StrCpy $0 $0 $3
            ${If} $0 == "0"
                MessageBox MB_OK "Error: The .env file could not be created. Reason: Access denied or no write permissions."
            ${Else}
                MessageBox MB_OK "Error: Could not create .env file! Error code: $0"
            ${EndIf}
            Abort
        ${EndIf}
        
        ; Write the MODEL_NAME environment variable to the .env file
        FileWrite $3 "MODEL_NAME=$1$\r$\n"  ; Write the selected model directly from $1

        ; Write the HUGGINGFACE_TOKEN environment variable to the .env file
        FileWrite $3 "HF_TOKEN=$2$\r$\n" ; Write the Huggingface token from $2

        ; Close the file
        FileClose $3 
    FunctionEnd

;--------------------------------
;Finish Page Customization using nsDialogs
; Define the finish page
Function FinishPageCreate
    nsDialogs::Create 1018
    Pop $0
    ${If} $0 == error
        Abort
    ${EndIf}

    ; Conditionally create the checkboxes only if the respective sections were installed

    ${If} $LLM_Installed == 1
        ${NSD_CreateCheckbox} 0u 0u 100% 12u "Launch Local LLM"
        Pop $Checkbox_LLM
        ${NSD_SetState} $Checkbox_LLM ${BST_UNCHECKED}
    ${EndIf}

    ${If} $Speech2Text_Installed == 1
        ${NSD_CreateCheckbox} 0u 14u 100% 12u "Launch Speech2Text"
        Pop $Checkbox_Speech2Text
        ${NSD_SetState} $Checkbox_Speech2Text ${BST_UNCHECKED}
    ${EndIf}

    ${If} $FreeScribe_Installed == 1
        ${NSD_CreateCheckbox} 0u 28u 100% 12u "Launch FreeScribe"
        Pop $Checkbox_FreeScribe
        ${NSD_SetState} $Checkbox_FreeScribe ${BST_UNCHECKED}
    ${EndIf}

    nsDialogs::Show
FunctionEnd

Function FinishPageLeave
    ; Check if Local LLM was selected
    ${NSD_GetState} $Checkbox_LLM $0
    StrCmp $0 ${BST_CHECKED} 0 +2
        ExecWait 'docker-compose -f "$INSTDIR\local-llm-container\docker-compose.yml" up -d --build'

    ; Check if Speech2Text was selected
    ${NSD_GetState} $Checkbox_Speech2Text $0
    StrCmp $0 ${BST_CHECKED} 0 +2
        ExecWait 'docker-compose -f "$INSTDIR\speech2text-container\docker-compose.yml" up -d --build'

    ; Check if FreeScribe was selected
    ${NSD_GetState} $Checkbox_FreeScribe $0
    StrCmp $0 ${BST_CHECKED} 0 +2
        Exec '"$APPDATA\freescribe\freescribe-client.exe"'
FunctionEnd
