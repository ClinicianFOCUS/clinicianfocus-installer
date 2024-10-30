;--------------------------------
;Include Modern UI and nsDialogs
; Include necessary NSIS plugins and libraries
    !addplugindir "$NSISDIR\Plugins"
    !include "MUI2.nsh"
    !include "nsDialogs.nsh"
    !include WinVer.nsh
    !include LogicLib.nsh
    !include Sections.nsh
    !define MARKER_REG_KEY "Software\ClinicianFOCUS-installer\InstallState"
    

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

    Var Docker_Installed_NotificationDone
    Var WSL_Installed_NotificationDone

    Var Input_WhisperAPIKey
    Var DropDown_WhisperModel

    Var WhisperAPIKey
    Var WhisperModel

    Var Checkbox_BasicInstall
    Var Checkbox_AdvancedInstall

    Var Is_Basic_Install
    Var Is_Adv_Install

    Var ShowComponents
    Var ShowDirectory

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
; define installer pages
    !insertmacro MUI_PAGE_LICENSE ".\assets\License.txt"
    Page custom InstallModePageCreate InstallModePageLeave

    ; Components page with condition
    !define MUI_PAGE_CUSTOMFUNCTION_PRE ShouldShowComponents
    !insertmacro MUI_PAGE_COMPONENTS 

    ; Directory page with condition
    !define MUI_PAGE_CUSTOMFUNCTION_PRE ShouldShowDirectory
    !insertmacro MUI_PAGE_DIRECTORY

    ; Custom pages
    Page custom ConditionalModelPageCreate ModelPageLeave
    Page custom ConditionalWhisperPageCreate WhisperSettingsPageLeave
    !insertmacro MUI_PAGE_INSTFILES
    Page custom FinishPageCreate FinishPageLeave

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

        Section "WSL2 for LLM" SEC_WSL_LLM
            ${If} $WSL_Installed == 0
                Call InstallWSL2
            ${Else}
                ${If} $WSL_Installed_NotificationDone == 0
                    DetailPrint "WSL2 is already installed on your system."
                    StrCpy $WSL_Installed_NotificationDone 1
                ${EndIf}
            ${EndIf}
        SectionEnd

        Section "Docker for LLM" SEC_DOCKER_LLM
            ${If} $Docker_Installed == 0
                Call InstallDocker
            ${Else}
                ${If} $Docker_Installed_NotificationDone == 0
                    DetailPrint "Docker is already installed on your system."
                    StrCpy $Docker_Installed_NotificationDone 1
                ${EndIf}
            ${EndIf}
        SectionEnd

    SectionGroupEnd

    SectionGroup "Speech to Text Container" SEC_GROUP_S2T
        Section "Speech2Text-Container Module" SEC_S2T
            CreateDirectory "$INSTDIR\speech2text-container"
            
            ${If} $Is_Adv_Install == ${BST_CHECKED}
                ; Save new env stuff to memory
                FileOpen $4 "$INSTDIR\speech2text-container\.env" r
                FileSeek $4 0 ; we want to start reading at the 1000th byte
                FileRead $4 $1 ; we read until the end of line (including carriage return and new line) and save it to $1
                FileRead $4 $2 ; read 10 characters from the next line
                FileClose $4 ; and close the file
            ${EndIf}
            
            ;; Copy in new files
            SetOutPath "$INSTDIR\speech2text-container"
            File ".\speech2text-container\*.*"

            ${If} $Is_Adv_Install == ${BST_CHECKED}
                ; Set the new env stuff into env file since it just got replaced
                FileOpen $4 "$INSTDIR\speech2text-container\.env" w
                FileWrite $4 $1
                FileWrite $4 $2
                FileClose $4
            ${EndIf}

            StrCpy $Speech2Text_Installed 1
        SectionEnd

        Section "WSL2 for Speech2Text" SEC_WSL_S2T
            ${If} $WSL_Installed == 0
                Call InstallWSL2
            ${Else}
                ${If} $WSL_Installed_NotificationDone == 0
                    DetailPrint "WSL2 is already installed on your system."
                ${EndIf}
            ${EndIf}
        SectionEnd

        Section "Docker for Speech2Text" SEC_DOCKER_S2T
            ${If} $Docker_Installed == 0
                Call InstallDocker
            ${Else}
                ${If} $Docker_Installed_NotificationDone == 0
                    DetailPrint "Docker is already installed on your system."
                ${EndIf}
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
            ExecWait '"$TEMP\DockerInstaller.exe" install --quiet'
            Delete "$TEMP\DockerInstaller.exe"
            StrCpy $Docker_Installed 1
            StrCpy $Docker_Installed_NotificationDone 1
            Exec "$PROGRAMFILES64/Docker/Docker/Docker Desktop.exe"

            ; Add message box with instructions and restart option
            MessageBox MB_YESNO "Docker Desktop has been installed. Please restart your computer then restart the clincian focus toolbox installer." IDYES RestartNow IDNO ContinueInstall

            RestartNow:
                ; Save any necessary installation state here if needed
                WriteRegStr HKCU "${MARKER_REG_KEY}" "Step" "AfterRestart"
                Reboot
                
            ContinueInstall:
                MessageBox MB_OK "Please restart the installer once you have restarted your computer."
                WriteRegStr HKCU "${MARKER_REG_KEY}" "Step" "AfterRestart"
                Quit
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
            
            StrCpy $WSL_Installed 1
            StrCpy $WSL_Installed_NotificationDone 1
        ${Else}
            MessageBox MB_OK "WSL2 download failed (Error: $R0). Please install WSL2 manually after the installation."
        ${EndIf}
    FunctionEnd

;--------------------------------
; On installer start
    Function .onInit
        ; Read the state from the registry
        ReadRegStr $0 HKCU "${MARKER_REG_KEY}" "Step"
        ReadRegStr $1 HKCU "${MARKER_REG_KEY}" "InstallPath"

        StrCpy $ShowComponents 1 ; 1 = show, 0 = hide
        StrCpy $ShowDirectory 1  ; 1 = show, 0 = hide

        ${If} $0 == "AfterRestart"
            ; Set the installation directory from registry
            ${If} $1 != ""
                StrCpy $INSTDIR $1
            ${EndIf}
            
            
            ; Start Docker Desktop
            Exec "$PROGRAMFILES64/Docker/Docker/Docker Desktop.exe"
            
            ; Show Docker startup message
            MessageBox MB_OK "Docker Desktop has been launched. Please follow these steps:$\n$\n1. Accept the Docker license agreement$\n2. Log in to your Docker account (or create one if needed)$\n3. Wait for Docker to fully start before continuing$\n$\nClick OK when Docker is running."
            
            ; Set Docker as installed
            StrCpy $Docker_Installed 1
            StrCpy $Docker_Installed_NotificationDone 1

            StrCpy $ShowComponents 0
            StrCpy $ShowDirectory 0
            
            Goto skipChecks
        ${EndIf}

        ${IfNot} ${AtLeastWin10}
            MessageBox MB_OK|MB_ICONSTOP "This installer requires Windows 10 or later.$\nPlease upgrade your operating system and try again."
            Quit
        ${EndIf}

        StrCpy $WSL_Installed_NotificationDone 0
        StrCpy $Docker_Installed_NotificationDone 0

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

        skipChecks:
        ; Set up section dependencies
        SectionGetFlags ${SEC_LLM} $0
        IntOp $0 $0 | ${SF_EXPAND}
        SectionSetFlags ${SEC_LLM} $0

        SectionGetFlags ${SEC_S2T} $0
        IntOp $0 $0 | ${SF_EXPAND}
        SectionSetFlags ${SEC_S2T} $0
    FunctionEnd

;--------------------------------
; Whisper Settings Page Customization using nsDialogs
; Define the Whisper settings page
    Function WhisperSettingsPageCreate
        nsDialogs::Create 1018

        Pop $0
        ${If} $0 == error
            Abort
        ${EndIf}

        ; Create a label for the API key input
        ${NSD_CreateLabel} 0u 0u 100% 12u "Whisper Password (API Key):"
        ${NSD_CreateText} 0u 14u 100% 12u ""
        Pop $Input_WhisperAPIKey
        
        ; Create description label for API key
        ${NSD_CreateLabel} 0u 28u 100% 12u "This will be your password (API key) used to access the Whisper service"
        Pop $0
        SetCtlColors $0 808080 transparent

        ; Create a label for the model selection
        ${NSD_CreateLabel} 0u 44u 100% 12u "Select Whisper Model:"
        ${NSD_CreateComboBox} 0u 58u 100% 12u ""
        Pop $DropDown_WhisperModel

        ; Create description label for model selection
        ${NSD_CreateLabel} 0u 72u 100% 12u "Choose model size (larger models are more accurate but slower) - 'medium' recommended"
        Pop $0
        SetCtlColors $0 808080 transparent

        ; Add more detailed model descriptions
        ${NSD_CreateLabel} 0u 86u 100% 48u "tiny: Fastest, least accurate (1GB)$\nbase: Fast, basic accuracy (1GB)$\nsmall: Balanced speed/accuracy (2GB)$\nmedium: Good accuracy (5GB)$\nlarge: Best accuracy, slowest (10GB)"
        Pop $0
        SetCtlColors $0 808080 transparent

        ; Add the model options to the drop-down
        ${NSD_CB_AddString} $DropDown_WhisperModel "tiny"
        ${NSD_CB_AddString} $DropDown_WhisperModel "base"
        ${NSD_CB_AddString} $DropDown_WhisperModel "small"
        ${NSD_CB_AddString} $DropDown_WhisperModel "medium"
        ${NSD_CB_AddString} $DropDown_WhisperModel "large"

        ; Set "medium" as the default and recommended selection
        ${NSD_CB_SelectString} $DropDown_WhisperModel "medium"

        ; Display the dialog
        nsDialogs::Show
    FunctionEnd

    Function WhisperSettingsPageLeave
        ; Get the API key entered by the user
        ${NSD_GetText} $Input_WhisperAPIKey $WhisperAPIKey

        ; Get the selected Whisper model
        ${NSD_GetText} $DropDown_WhisperModel $WhisperModel  # $1 will hold the user input

        ; Create the .env directories for the Whisper settings
        CreateDirectory "$INSTDIR\speech2text-container"

        ; Define the file path for the Whisper .env settings
        StrCpy $0 "$INSTDIR\speech2text-container\.env"

        ; Open the .env file for writing
        FileOpen $3 $0 w
        ${If} $3 == ""
            MessageBox MB_OK "Error: Could not create .env file for Whisper settings."
            Abort
        ${EndIf}

        ; Write the API key and model selection to the .env file
        FileWrite $3 "SESSION_API_KEY=$WhisperAPIKey$\r$\n"
        FileWrite $3 "WHISPER_MODEL=$WhisperModel$\r$\n"

        ; Close the file
        FileClose $3
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

    SectionEnd

;--------------------------------
;Conditional Model Selection Page Display
; Define the conditional model selection page
    Function ConditionalModelPageCreate
        ReadRegStr $0 HKCU "${MARKER_REG_KEY}" "Step"

        ${If} $0 == "AfterRestart"
            Abort ; Skip this page
        ${EndIf}

        SectionGetFlags ${SEC_LLM} $0
        IntOp $0 $0 & ${SF_SELECTED}
        ${If} $0 == ${SF_SELECTED}
            ${If} $Is_Adv_Install == ${BST_CHECKED}
                Call ModelPageCreate
            ${EndIf}
        ${EndIf}
    FunctionEnd

    Function ConditionalWhisperPageCreate
        ReadRegStr $0 HKCU "${MARKER_REG_KEY}" "Step"

        ${If} $0 == "AfterRestart"
            Abort ; Skip this page
        ${EndIf}

        SectionGetFlags ${SEC_S2T} $0
        IntOp $0 $0 & ${SF_SELECTED}
        ${If} $0 == ${SF_SELECTED}
            ${If} $Is_Adv_Install == ${BST_CHECKED}
                Call WhisperSettingsPageCreate
            ${EndIf}
        ${EndIf}
    FunctionEnd


    Function ShouldShowComponents
        ${If} $ShowComponents == 0
            ; Set default selections
            SectionGetFlags ${SEC_LLM} $0
            IntOp $0 $0 | ${SF_SELECTED}
            SectionSetFlags ${SEC_LLM} $0
            
            SectionGetFlags ${SEC_S2T} $0
            IntOp $0 $0 | ${SF_SELECTED}
            SectionSetFlags ${SEC_S2T} $0
            
            Abort ; Skip the page
        ${EndIf}
    FunctionEnd

    Function ShouldShowDirectory
        ${If} $ShowDirectory == 0
            ; Set default directory
            ${If} $1 != ""
                StrCpy $INSTDIR $1
            ${EndIf}
            Abort ; Skip the page
        ${EndIf}
    FunctionEnd

;--------------------------------
;Model Selection Page Customization using nsDialogs
; Define the model selection page

    Var Input_CustomModel
    Function ModelPageCreate        
        nsDialogs::Create 1018
        Pop $0
        ${If} $0 == error
            Abort
        ${EndIf}

        ; Create label for Model selection
        ${NSD_CreateLabel} 0u 0u 100% 12u "Model:"
        Pop $0

        ; Create dropdown for Model selection
        ${NSD_CreateComboBox} 0u 14u 100% 12u ""
        Pop $DropDown_Model
        
        ; Create description label for model selection
        ${NSD_CreateLabel} 0u 28u 100% 12u "Select a pre-configured model or choose 'Custom' for your own model"
        Pop $0
        SetCtlColors $0 808080 transparent

        ; Create text input for custom model (initially hidden)
        ${NSD_CreateText} 0u 14u 100% 12u ""
        Pop $Input_CustomModel
        ShowWindow $Input_CustomModel ${SW_HIDE}
        
        ; Create description label for custom model (initially hidden)
        ${NSD_CreateLabel} 0u 28u 100% 12u "Enter the full path or identifier of your custom model"
        Pop $0
        SetCtlColors $0 808080 transparent
        ShowWindow $0 ${SW_HIDE}

        ; Add items to dropdown
        ${NSD_CB_AddString} $DropDown_Model "google/gemma-2-2b-it"
        ${NSD_CB_AddString} $DropDown_Model "Custom"
        ${NSD_CB_SelectString} $DropDown_Model "google/gemma-2-2b-it"

        ; Create input for Huggingface Token
        ${NSD_CreateLabel} 0u 44u 100% 12u "Huggingface Token:"
        Pop $0
        ${NSD_CreateText} 0u 58u 100% 12u ""
        Pop $Input_HFToken
        
        ; Create description label for Huggingface token
        ${NSD_CreateLabel} 0u 72u 100% 12u "Enter your Huggingface API token if referencing a gated model on Huggingface"
        Pop $0
        SetCtlColors $0 808080 transparent

        ; Add event handler for dropdown changes
        ${NSD_OnChange} $DropDown_Model ModelSelectionChanged

        Call ModelSelectionChanged

        nsDialogs::Show
    FunctionEnd

    Function ModelSelectionChanged
        Pop $0 ; Remove callback handle from stack
        
        ; Get current selection after the change
        System::Call "user32::SendMessage(p $DropDown_Model, i ${CB_GETCURSEL}, i 0, i 0) i .r0"
        System::Call "user32::SendMessage(p $DropDown_Model, i ${CB_GETLBTEXT}, i r0, t .r1)"
        
        ${If} $1 == "Custom"
            ShowWindow $DropDown_Model ${SW_HIDE}
            ShowWindow $Input_CustomModel ${SW_SHOW}
        ${Else}
            ShowWindow $DropDown_Model ${SW_SHOW}
            ShowWindow $Input_CustomModel ${SW_HIDE}
        ${EndIf}
    FunctionEnd

    Function ModelPageLeave
        ${NSD_GetText} $DropDown_Model $1  # $0 will hold the user input
        StrCmp $1 "Custom" 0 +2
        ${NSD_GetText} $Input_CustomModel $1
        
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

; Function to create the finish page with launch options
    Function FinishPageCreate
        ; Create a new dialog
        nsDialogs::Create 1018
        Pop $0
        ${If} $0 == error
            Abort
        ${EndIf}

        ; Create checkboxes for each installed component
        ; Only show checkboxes for components that were actually installed
        
        ; Check if LLM was installed and create its checkbox if true
        ${If} $LLM_Installed == 1
            ${NSD_CreateCheckbox} 0u 0u 100% 12u "Launch Local LLM"
            Pop $Checkbox_LLM
            ${NSD_SetState} $Checkbox_LLM ${BST_UNCHECKED}
        ${EndIf}

        ; Check if Speech2Text was installed and create its checkbox if true
        ${If} $Speech2Text_Installed == 1
            ${NSD_CreateCheckbox} 0u 14u 100% 12u "Launch Speech2Text"
            Pop $Checkbox_Speech2Text
            ${NSD_SetState} $Checkbox_Speech2Text ${BST_UNCHECKED}
        ${EndIf}

        ; Check if FreeScribe was installed and create its checkbox if true
        ${If} $FreeScribe_Installed == 1
            ${NSD_CreateCheckbox} 0u 28u 100% 12u "Launch FreeScribe"
            Pop $Checkbox_FreeScribe
            ${NSD_SetState} $Checkbox_FreeScribe ${BST_UNCHECKED}
        ${EndIf}

        ; Display the dialog
        nsDialogs::Show
    FunctionEnd

    ; Function that executes when leaving the finish page
    Function FinishPageLeave
        ; Check LLM checkbox state and launch if checked
        ${NSD_GetState} $Checkbox_LLM $0
        StrCmp $0 ${BST_CHECKED} 0 +2
            ExecWait 'docker-compose -f "$INSTDIR\local-llm-container\docker-compose.yml" up -d --build'

        ; Check Speech2Text checkbox state and launch if checked
        ${NSD_GetState} $Checkbox_Speech2Text $0
        StrCmp $0 ${BST_CHECKED} 0 +2
            ExecWait 'docker-compose -f "$INSTDIR\speech2text-container\docker-compose.yml" up -d --build'

        ; Check FreeScribe checkbox state and launch if checked
        ${NSD_GetState} $Checkbox_FreeScribe $0
        StrCmp $0 ${BST_CHECKED} 0 +2
            Exec '"$APPDATA\freescribe\freescribe-client.exe"'

        ; Cleanup: Remove registry entries used during installation
        DeleteRegValue HKCU "${MARKER_REG_KEY}" "Step"
        DeleteRegValue HKCU "${MARKER_REG_KEY}" "InstallPath"
        DeleteRegKey /ifempty HKCU "${MARKER_REG_KEY}"
    FunctionEnd

    ; Function to create the installation mode selection page
    Function InstallModePageCreate
        ; Set page title and description
        !insertmacro MUI_HEADER_TEXT "Installation Mode" "Select the installation mode: Basic or Advanced."

        ; Check if we're returning after a restart
        ReadRegStr $0 HKCU "${MARKER_REG_KEY}" "Step"
        ${If} $0 == "AfterRestart"
            ; Skip this page if we're returning from a restart
            StrCpy $Is_Basic_Install ${BST_UNCHECKED}
            StrCpy $Is_Adv_Install ${BST_CHECKED}
            Abort ; Skip this page
        ${EndIf}

        ; Create the dialog
        nsDialogs::Create 1018
        Pop $0
        ${If} $0 == error
            Abort
        ${EndIf}

        ; Create radio-like checkboxes for installation mode selection
        ${NSD_CreateCheckbox} 0u 0u 100% 12u "Basic Install (Recommended)"
        Pop $Checkbox_BasicInstall
        ${NSD_SetState} $Checkbox_BasicInstall ${BST_CHECKED}

        ${NSD_CreateCheckbox} 0u 14u 100% 12u "Advanced Install"
        Pop $Checkbox_AdvancedInstall
        ${NSD_SetState} $Checkbox_AdvancedInstall ${BST_UNCHECKED}

        ; Add click handlers to implement radio-button behavior
        ${NSD_OnClick} $Checkbox_BasicInstall EnableBasicInstall
        ${NSD_OnClick} $Checkbox_AdvancedInstall EnableAdvancedInstall

        ; Display the dialog
        nsDialogs::Show
    FunctionEnd

    ; Function to handle Basic Install checkbox click
    Function EnableBasicInstall
        ; Implement radio-button behavior: check Basic, uncheck Advanced
        ${NSD_SetState} $Checkbox_BasicInstall ${BST_CHECKED}
        ${NSD_SetState} $Checkbox_AdvancedInstall ${BST_UNCHECKED}
    FunctionEnd

    ; Function to handle Advanced Install checkbox click
    Function EnableAdvancedInstall
        ; Implement radio-button behavior: check Advanced, uncheck Basic
        ${NSD_SetState} $Checkbox_BasicInstall ${BST_UNCHECKED}
        ${NSD_SetState} $Checkbox_AdvancedInstall ${BST_CHECKED}
    FunctionEnd

    ; Function that executes when leaving the installation mode page
    Function InstallModePageLeave
        ; Store the selected installation mode for later use
        ${NSD_GetState} $Checkbox_BasicInstall $Is_Basic_Install
        ${NSD_GetState} $Checkbox_AdvancedInstall $Is_Adv_Install

        ; Setuo the defaults for s2t container
        ${If} $Is_Basic_Install == ${BST_CHECKED}
            ; Create the .env directories for the Speech2Text container
            CreateDirectory "$INSTDIR\speech2text-container"

            ; Define the file path for the .env settings
            StrCpy $0 "$INSTDIR\speech2text-container\.env"

            ; Open the .env file for writing
            FileOpen $3 $0 w
            ${If} $3 == ""
                MessageBox MB_OK "Error: Could not create .env file for Speech2Text settings."
                Abort
            ${EndIf}

            ; Write the API key and model selection to the .env file
            FileWrite $3 "SESSION_API_KEY=GENERATE$\r$\n"
            FileWrite $3 "WHISPER_MODEL=medium$\r$\n"

            ; Close the file
            FileClose $3

            ; Create the .env directories for the Local LLM container
            CreateDirectory "$INSTDIR\local-llm-container"

            ; Define the file path for the .env settings
            StrCpy $0 "$INSTDIR\local-llm-container\.env"

            ; Open the .env file for writing
            FileOpen $3 $0 w
            ${If} $3 == ""
                MessageBox MB_OK "Error: Could not create .env file for Local LLM settings."
                Abort
            ${EndIf}

            ; Write the MODEL_NAME environment variable to the .env file
            FileWrite $3 "MODEL_NAME=google/gemma-2-2b-it$\r$\n"

            ; Close the file
            FileClose $3
        ${EndIf}
    FunctionEnd