;--------------------------------
;Include Modern UI and nsDialogs
; Include necessary NSIS plugins and libraries
    !addplugindir "$NSISDIR\Plugins"
    !include "MUI2.nsh"
    !include "nsDialogs.nsh"
    !include "WordFunc.nsh"
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

    Var Input_APIKey
    Var DropDown_WhisperModel

    Var APIKey
    Var WhisperModel

    Var Checkbox_BasicInstall
    Var Checkbox_AdvancedInstall

    Var Is_Basic_Install
    Var Is_Adv_Install

    Var ShowComponents
    Var ShowDirectory

    Var PrimaryIP

    Var /GLOBAL CPU_RADIO
    Var /GLOBAL NVIDIA_RADIO
    Var /GLOBAL SELECTED_ARCH_FREESCRIBE

;---------------------------------
; constants
    !define MIN_CUDA_DRIVER_VERSION 527.41 ; The nvidia graphic driver that is compatiable with Cuda 12.1

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
    ; Custom function to check if at least one component is selected
    !define MUI_PAGE_CUSTOMFUNCTION_LEAVE ComponentsPageLeave
    !insertmacro MUI_PAGE_COMPONENTS

    Page custom ConditionalFreeScribeArchPageCreate

    ; Directory page with condition
    !define MUI_PAGE_CUSTOMFUNCTION_PRE ShouldShowDirectory
    !insertmacro MUI_PAGE_DIRECTORY

    ; Custom pages
    Page custom ConditionalModelPageCreate ModelPageLeave
    Page custom ConditionalWhisperPageCreate WhisperSettingsPageLeave

    ; Custom function called when leaving the InstallFiles page
    !define MUI_PAGE_CUSTOMFUNCTION_LEAVE InsfilesPageLeave
    !insertmacro MUI_PAGE_INSTFILES

    Page custom ConditionalAPIInfoPageCreate
    Page custom FinishPageCreate FinishPageLeave

; define uninstaller pages
    !insertmacro MUI_UNPAGE_CONFIRM
    !insertmacro MUI_UNPAGE_INSTFILES
    !insertmacro MUI_UNPAGE_FINISH

; define language
    !insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Macro to add firewall inbound rules
!macro AddFirewallRule RuleName Port
    ; Create a temporary PowerShell script to add inbound rule
    FileOpen $0 "$TEMP\${RuleName}_rule.ps1" w
    FileWrite $0 "$$RuleName = '${RuleName}'$\r$\n"
    FileWrite $0 "$$Port = ${Port}$\r$\n"
    FileWrite $0 "$$Protocol = 'TCP'$\r$\n"
    FileWrite $0 "$$Action = 'Allow'$\r$\n"
    FileWrite $0 "$$ruleExists = Get-NetFirewallRule -DisplayName $$RuleName -ErrorAction SilentlyContinue$\r$\n"
    FileWrite $0 "if (-not $$ruleExists) {$\r$\n"
    FileWrite $0 "    New-NetFirewallRule -DisplayName $$RuleName -Direction Inbound -Protocol $$Protocol -LocalPort $$Port -Action $$Action -Enabled True -Profile Domain,Private$\r$\n"
    FileWrite $0 "    Write-Host 'Inbound rule $$RuleName added successfully.'$\r$\n"
    FileWrite $0 "} else {$\r$\n"
    FileWrite $0 "    Write-Host 'Inbound rule $$RuleName already exists.'$\r$\n"
    FileWrite $0 "}$\r$\n"
    FileClose $0
    
    DetailPrint "Adding inbound firewall rule: ${RuleName} (Port: ${Port})"
    ; Run the PowerShell script to add rule
    nsExec::ExecToStack 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$TEMP\${RuleName}_rule.ps1"'
    Pop $R0
    Pop $R1

    ; Check the return code
    ${If} $R0 != 0
        MessageBox MB_ICONEXCLAMATION "Failed to add firewall rule: ${RuleName}. Error code: $R0"
    ${EndIf}

    ; Clean up the PowerShell script
    Delete "$TEMP\${RuleName}_rule.ps1"
!macroend
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

        Section "Inbound Firewall Rule" SEC_LLM_INBOUND_RULE
            !insertmacro AddFirewallRule "LLM Container" 3334
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

        Section "Inbound Firewall Rule" SEC_S2T_INBOUND_RULE
            !insertmacro AddFirewallRule "STT Container" 2224
        SectionEnd

    SectionGroupEnd

    Section "Freescribe Client" SEC_FREESCRIBE
        ; Create directories for Freescribe Client
        CreateDirectory "$INSTDIR\freescribe"
        SetOutPath "$INSTDIR\freescribe"
        File ".\freescribe\FreeScribeInstaller_windows.exe"

        ; Execute Freescribe installer silently
        ExecWait '"$INSTDIR\freescribe\FreeScribeInstaller_windows.exe" /S /ARCH=$SELECTED_ARCH_FREESCRIBE'

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


    Function CheckNvidiaDrivers
        Var /GLOBAL DriverVersion

        ; Try to read from the registry
        SetRegView 64
        ReadRegStr $DriverVersion HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}_Display.Driver" "DisplayVersion"

        ${If} $DriverVersion == ""
            ; Fallback to 32-bit registry view
            SetRegView 32
            ReadRegStr $DriverVersion HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}_Display.Driver" "DisplayVersion"
        ${EndIf}

        ; No nvidia drivers detected - show error message
        ${If} $DriverVersion == ""
            MessageBox MB_OK "No valid Nvidia device deteced (Drivers Missing). This program relys on a Nvidia GPU to run. Functionality is not guaranteed without a Nvidia GPU."
            Goto driver_check_end
        ${EndIf}
        ; Push the version number to the stack
        Push $DriverVersion
        ; Push min driver version
        Push ${MIN_CUDA_DRIVER_VERSION}
        
        Call CompareVersions

        Pop $0 ; Get the return value

        ${If} $0 == 1
            MessageBox MB_OK "Your NVIDIA driver version ($DriverVersion) is older than the minimum required version (${MIN_CUDA_DRIVER_VERSION}). Please update at https://www.nvidia.com/en-us/drivers/. Then contiune with the installation."
            Quit
        ${EndIf}
        driver_check_end:
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

    ; Function to execute when leaving the Component page
    Function ComponentsPageLeave
        ; Initialize the count of selected components
        StrCpy $0 0

        ; Check if Local LLM is selected
        SectionGetFlags ${SEC_LLM} $1
        IntOp $1 $1 & ${SF_SELECTED}
        StrCmp $1 ${SF_SELECTED} 0 +2
            IntOp $0 $0 + 1

        ; Check if Speech2Text is selected
        SectionGetFlags ${SEC_S2T} $1
        IntOp $1 $1 & ${SF_SELECTED}
        StrCmp $1 ${SF_SELECTED} 0 +2
            IntOp $0 $0 + 1

        ; Check if FreeScribe is selected
        SectionGetFlags ${SEC_FREESCRIBE} $1
        IntOp $1 $1 & ${SF_SELECTED}
        StrCmp $1 ${SF_SELECTED} 0 +2
            IntOp $0 $0 + 1

        ; If user has selected 0 components, show a message and abort
        IntCmp $0 1 +3 0 +3
        MessageBox MB_OK "You must select at least one components to proceed."
        Abort

    FunctionEnd

    ; Function to execute when leaving the InstallFiles page
    ; Goes to the next page after the installation is complete
    Function InsfilesPageLeave
        SetAutoClose true
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
        ${NSD_CreateLabel} 0u 0u 100% 12u "Password (API Key):"
        ${NSD_CreateText} 0u 14u 100% 12u ""
        Pop $Input_APIKey
        
        ; Create description label for API key
        ${NSD_CreateLabel} 0u 28u 100% 12u "This will be your password (API key) used to access the Whisper and LLM services"
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

    !macro WriteEnvFiles APIKey WhisperModel
        ; Create the .env directories for the Whisper settings
        CreateDirectory "$INSTDIR\speech2text-container"
        CreateDirectory "$INSTDIR\local-llm-container"

        ; Define the file path for the Whisper .env settings
        StrCpy $0 "$INSTDIR\speech2text-container\.env"
        StrCpy $1 "$INSTDIR\local-llm-container\.env"

        ; Open the .env file for writing
        FileOpen $3 $0 w
        FileOpen $4 $1 w

        ${If} $3 == ""
            MessageBox MB_OK "Error: Could not create .env file for Whisper settings."
            Abort
        ${EndIf}

        ${If} $4 == ""
            MessageBox MB_OK "Error: Could not create .env file for LLM settings."
            Abort
        ${EndIf}

        ; Write the API key and model selection to the whisper/.env file
        FileWrite $3 "SESSION_API_KEY=$APIKey$\r$\n"
        FileWrite $3 "WHISPER_MODEL=$WhisperModel$\r$\n"

        ; Write the API key to the LLM/.env file
        FileWrite $4 "SESSION_API_KEY=$APIKey$\r$\n"

        ; Close the whisper/.env file
        FileClose $3

        ; Close the LLM/.env file
        FileClose $4
    !macroend

    Function WhisperSettingsPageLeave
        ; Get the API key entered by the user
        ${NSD_GetText} $Input_APIKey $APIKey

        ; Get the selected Whisper model
        ${NSD_GetText} $DropDown_WhisperModel $WhisperModel  ; $1 will hold the user input

        ; Call the macro to write the .env files
        !insertmacro WriteEnvFiles $APIKey $WhisperModel
    FunctionEnd

    

;--------------------------------
;Descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_LLM} "Install Local LLM Container"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DOCKER_LLM} "Install Docker for Local LLM (required if not already installed)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_WSL_LLM} "Install WSL2 for Local LLM (required for Docker)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_LLM_INBOUND_RULE} "Add Inbound Rule to allow external connections"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_S2T} "Install Speech2Text Container"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DOCKER_S2T} "Install Docker for Speech2Text (required if not already installed)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_WSL_S2T} "Install WSL2 for Speech2Text (required for Docker)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_S2T_INBOUND_RULE} "Add Inbound Rule to allow external connections"
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

    Function ConditionalFreeScribeArchPageCreate
        ; Check if FreeScribe is selected
        SectionGetFlags ${SEC_FREESCRIBE} $0
        IntOp $0 $0 & ${SF_SELECTED}
        StrCmp $0 ${SF_SELECTED} 0 +2
            Call FreeScribeArchPageCreate
    FunctionEnd

    Function FreeScribeArchPageCreate
        !insertmacro MUI_HEADER_TEXT "Architecture Selection For FreeScribe" "Choose your preferred installation architecture for FreeScribe based on your hardware"

        nsDialogs::Create 1018
        Pop $0

        ${If} $0 == error
            Abort
        ${EndIf}

        ; Main instruction text for architecture selection
        ${NSD_CreateLabel} 0 0 100% 12u "Choose your preferred installation architecture for FreeScribe based on your hardware:"
        Pop $0

        ; Radio button for CPU
        ${NSD_CreateRadioButton} 10 15u 100% 10u "CPU"
        Pop $CPU_RADIO
        ${NSD_Check} $CPU_RADIO
        StrCpy $SELECTED_ARCH_FREESCRIBE "CPU"

        ; CPU explanation text (grey with padding)
        ${NSD_CreateLabel} 20 25u 100% 20u "Recommended for most users. Runs on any modern processor and provides good performance for general use."
        Pop $0
        SetCtlColors $0 808080 transparent

        ; Radio button for NVIDIA
        ${NSD_CreateRadioButton} 10 55u 100% 10u "NVIDIA"
        Pop $NVIDIA_RADIO

        ; NVIDIA explanation text (grey with padding)
        ${NSD_CreateLabel} 20 65u 100% 30u "Choose this option if you have an NVIDIA GPU. Provides accelerated performance. Only select if you have a Nvidia GPU installed."
        Pop $0
        SetCtlColors $0 808080 transparent

        ; Bottom padding (10u of space)
        ${NSD_CreateLabel} 0 95u 100% 10u ""
        Pop $0

        ${NSD_OnClick} $CPU_RADIO OnRadioClick
        ${NSD_OnClick} $NVIDIA_RADIO OnRadioClick

        nsDialogs::Show
    FunctionEnd

    ; Callback function for radio button clicks
    Function OnRadioClick
        Pop $0 ; Get the handle of the clicked control

        ${If} $0 == $CPU_RADIO
            StrCpy $SELECTED_ARCH_FREESCRIBE "CPU"
        ${ElseIf} $0 == $NVIDIA_RADIO
            StrCpy $SELECTED_ARCH_FREESCRIBE "NVIDIA"
        ${EndIf}
    FunctionEnd

    ; Conditional function to show the API Info page if the user has installed llm or s2t container
    Function ConditionalAPIInfoPageCreate
        ; Call CreateAPIInfoPage if either $LLM_Installed or $Speech2Text_Installed is true
        ${If} $LLM_Installed == 1
            Call CreateAPIInfoPage
        ${ElseIf} $Speech2Text_Installed == 1
            Call CreateAPIInfoPage
        ${EndIf}
    FunctionEnd

    ; Function to get the primary IP address of the network adapter
    Function GetPrimaryIPAddress
        ; Get the IP address of the network adapter associated with the default gateway
        nsExec::ExecToStack 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $$_.InterfaceIndex -eq (Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Select-Object -First 1).InterfaceIndex }).IPAddress"'
        Pop $0
        Pop $PrimaryIP

        ${If} $0 != 0
            MessageBox MB_OK "Error: Could not retrieve IP address of the primary network adapter."
            Abort
        ${EndIf}
        MessageBox MB_OK "Primary IP Address: $PrimaryIP"
    FunctionEnd

    ; Function to create the API Info page
    Function CreateAPIInfoPage
        call GetPrimaryIPAddress
        nsDialogs::Create 1018
        Pop $0

        ${If} $0 == error
            Abort
        ${EndIf}


        ; Create an Edit control to display the API key
        ${NSD_CreateText} 0u 0u 100% 12u "$APIKey"
        Pop $0
        SendMessage $0 ${EM_SETREADONLY} 1 0

        ; Create an Edit control to display the IP address
        ${NSD_CreateText} 0u 14u 100% 12u "$PrimaryIP"
        Pop $0
        SendMessage $0 ${EM_SETREADONLY} 1 0

        nsDialogs::Show

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
        ${NSD_GetText} $DropDown_Model $1  ; $0 will hold the user input
        StrCmp $1 "Custom" 0 +2
        ${NSD_GetText} $Input_CustomModel $1
        
        ; Get the Huggingface token
        ${NSD_GetText} $Input_HFToken $2

        ; Create the .env directories for the Local LLM container
        CreateDirectory "$INSTDIR"
        CreateDirectory "$INSTDIR\local-llm-container\"
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

        ; Initialize the vertical position for the first checkbox
        StrCpy $1 0

        ; Create checkboxes for each installed component
        ; Only show checkboxes for components that were actually installed
        
        ; Check if LLM was installed and create its checkbox if true
        ${If} $LLM_Installed == 1
            ${NSD_CreateCheckbox} 0u $1 100% 12u "Launch Local LLM"
            Pop $Checkbox_LLM
            ${NSD_SetState} $Checkbox_LLM ${BST_UNCHECKED}
            IntOp $1 $1 + 20u ; Increment the vertical position for the next checkbox
        ${EndIf}

        ; Check if Speech2Text was installed and create its checkbox if true
        ${If} $Speech2Text_Installed == 1
            ${NSD_CreateCheckbox} 0u $1 100% 12u "Launch Speech2Text"
            Pop $Checkbox_Speech2Text
            ${NSD_SetState} $Checkbox_Speech2Text ${BST_UNCHECKED}
            IntOp $1 $1 + 20u ; Increment the vertical position for the next checkbox
        ${EndIf}

        ; Check if FreeScribe was installed and create its checkbox if true
        ${If} $FreeScribe_Installed == 1
            ${NSD_CreateCheckbox} 0u $1 100% 12u "Launch FreeScribe"
            Pop $Checkbox_FreeScribe
            ${NSD_SetState} $Checkbox_FreeScribe ${BST_UNCHECKED}
            IntOp $1 $1 + 20u ; Increment the vertical position for the next checkbox
        ${EndIf}

        
        ; Display a recommendation message if LLM or Speech2Text is installed
        ${If} $LLM_Installed == 1
        ${OrIf} $Speech2Text_Installed == 1
            ; Create a bold label for the recommendation title
            IntOp $1 $1 + 5u ; Increment the vertical position for the next checkbox
            ${NSD_CreateLabel} 0u $1 100% 12u "Recommended Actions:"
            Pop $0
            IntOp $1 $1 + 20u ; Increment the vertical position for the next checkbox

            ; Create a label for the first recommendation
            ${NSD_CreateLabel} 0u $1 100% 12u "1. Start Docker Desktop before launching Local LLM and Speech2Text."
            Pop $0
            IntOp $1 $1 + 20u ; Increment the vertical position for the next checkbox

            ; Create a label for the second recommendation
            ${NSD_CreateLabel} 0u $1 100% 12u "2. Launch Local LLM and Speech2Text to build the container image."
            Pop $0
        ${EndIf}

        ; Get the handle of the "Close" button and change its text to "Finish"
        GetDlgItem $0 $HWNDPARENT 1
        SendMessage $0 ${WM_SETTEXT} 0 "STR:Finish"

        ; Display the dialog
        nsDialogs::Show
    FunctionEnd

    
    ; Function to check if Docker is running and start it if not
    Function CheckAndStartDocker
        ; Check if Docker is running
        ExecWait 'docker info' $0
        StrCmp $0 0 done

        ; If Docker is not running, start Docker Desktop
        MessageBox MB_OK "Docker is not running. Starting Docker Desktop..."
        ExecWait '"$PROGRAMFILES64\Docker\Docker\Docker Desktop.exe"'
        Sleep 5000 ; Wait for Docker to start

        ; Check again if Docker is running
        ExecWait 'docker info' $0
        StrCmp $0 0 done

        ; If Docker still isn't running, show an error message
        MessageBox MB_OK "Docker could not be started or took too long. Please start Docker manually and try again."
        Abort

        done:
    FunctionEnd

    ; Function that executes when leaving the finish page
    Function FinishPageLeave
        ; Check if either LLM or Speech2Text checkbox is checked and call CheckAndStartDocker if true
        ${NSD_GetState} $Checkbox_LLM $0
        StrCmp $0 ${BST_CHECKED} +2
        ${NSD_GetState} $Checkbox_Speech2Text $0
        StrCmp $0 ${BST_CHECKED} 0 +3
        Call CheckAndStartDocker

        ; Check Speech2Text checkbox state and launch if checked
        ${NSD_GetState} $Checkbox_Speech2Text $0
        StrCmp $0 ${BST_CHECKED} 0 +2
            Exec 'docker-compose -f "$INSTDIR\speech2text-container\docker-compose.yml" up -d --build'

        ; Check LLM checkbox state and launch if checked
        ${NSD_GetState} $Checkbox_LLM $0
        StrCmp $0 ${BST_CHECKED} 0 +2

        ${If} $0 == ${BST_CHECKED}
            ; wait fir the container to be up before running the model
            ExecWait 'docker-compose -f "$INSTDIR\local-llm-container\docker-compose.yml" up -d --build'
            ${For} $R1 0 30
                ExecWait 'docker container inspect -f "{{.State.Running}}" ollama' $0
                ${If} $0 == 0
                    ${Break}
                ${EndIf}
                Sleep 1000
            ${Next}
            
            ; Create a temporary PowerShell script to run the Gemma model on Ollama
            ; This also pulls and downloads if doesnt exist
            FileOpen $0 "$TEMP\docker_command.ps1" w
            FileWrite $0 "Write-Host $\"Please wait until this install is finished before using FreeScribe client.$\"$\r$\n"
            FileWrite $0 "Write-Host $\"Downloading the Gemma model on Ollama...$\"$\r$\n"
            FileWrite $0 "$${ErrorActionPreference} = 'Stop'$\r$\n"
            FileWrite $0 "try {$\r$\n"
            FileWrite $0 "    docker exec ollama ollama pull gemma2:2b-instruct-q8_0$\r$\n"
            FileWrite $0 "} catch {$\r$\n"
            FileWrite $0 "    Write-Host 'Error: Failed to pull Gemma model' -ForegroundColor Red$\r$\n"
            FileWrite $0 "    exit 1$\r$\n"
            FileWrite $0 "}$\r$\n"
            FileWrite $0 "Write-Host $\"Starting the Gemma model on Ollama...$\"$\r$\n"
            FileWrite $0 "docker exec ollama ollama run gemma2:2b-instruct-q8_0:$\r$\n"
            FileWrite $0 "Write-Host $\"Gemma installed and launched on Ollama. You may now use the FreeScribe Client.$\"$\r$\n"
            FileWrite $0 "Write-Host $\"Press any key to continue...$\" -NoNewLine$\r$\n"
            FileWrite $0 "$$host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') | Out-Null$\r$\n"
            FileClose $0
            
            ; Run the powershell script
            ExecWait 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$TEMP\docker_command.ps1"'
            
            ; Clean up the powershell script
            Delete "$TEMP\docker_command.ps1"
        ${EndIf}

        ; Check FreeScribe checkbox state and launch if checked
        ${NSD_GetState} $Checkbox_FreeScribe $0
        StrCmp $0 ${BST_CHECKED} 0 +3
            MessageBox MB_OK|MB_TOPMOST "Please make sure that the Local LLM and Speech2Text Docker containers are running successfully for FreeScribe to function properly."
            Exec '"$APPDATA\freescribe\freescribe-client.exe"'

        ; Cleanup: Remove registry entries used during installation
        DeleteRegValue HKCU "${MARKER_REG_KEY}" "Step"
        DeleteRegValue HKCU "${MARKER_REG_KEY}" "InstallPath"
        DeleteRegKey /ifempty HKCU "${MARKER_REG_KEY}"
    FunctionEnd

    ; Function to create the installation mode selection page
    Function InstallModePageCreate
        Call CheckNvidiaDrivers

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
            ; Add the required amount for mistral model
            SectionSetSize ${SEC_LLM} 2805000

            ; Generate a random API key
            nsExec::ExecToStack 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[guid]::NewGuid().ToString()"'
            Pop $0
            Pop $APIKey

            ${If} $0 != 0
                MessageBox MB_OK "Error: Could not generate API key."
                Abort
            ${EndIf}

            MessageBox MB_OK "Your API key is: $APIKey"
            StrCpy $WhisperModel "medium"

            ; Call the macro to write the .env files
            !insertmacro WriteEnvFiles $APIKey $WhisperModel
        ${EndIf}

        ; If not basic set install size without mistral model
        ${If} $Is_Adv_Install == ${BST_CHECKED}
            SectionSetSize ${SEC_LLM} 43.0
        ${EndIf}
    FunctionEnd

    ;------------------------------------------------------------------------------
    ; Function: CompareVersions
    ; Purpose: Compares two version numbers in format "X.Y" (e.g., "1.0", "2.3")
    ; 
    ; Parameters:
    ;   Stack 1 (bottom): First version string to compare
    ;   Stack 0 (top): Second version string to compare
    ;
    ; Returns:
    ;   0: Versions are equal
    ;   1: First version is less than second version
    ;   2: First version is greater than second version
    ;
    ; Example:
    ;   Push "1.0"    ; First version
    ;   Push "2.0"    ; Second version
    ;   Call CompareVersions
    ;   Pop $R0       ; $R0 will contain 1 (1.0 < 2.0)
    ;------------------------------------------------------------------------------
    Function CompareVersions
        Exch $R0      ; Get second version from stack into $R0
        Exch
        Exch $R1      ; Get first version from stack into $R1
        Push $R2
        Push $R3
        Push $R4
        Push $R5
        
        ; Split version strings into major and minor numbers
        ${WordFind} $R1 "." "+1" $R2    ; Extract major number from first version
        ${WordFind} $R1 "." "+2" $R3    ; Extract minor number from first version
        ${WordFind} $R0 "." "+1" $R4    ; Extract major number from second version
        ${WordFind} $R0 "." "+2" $R5    ; Extract minor number from second version
        
        ; Convert to comparable numbers:
        ; Multiply major version by 1000 to handle minor version properly
        IntOp $R2 $R2 * 1000            ; Convert first version major number
        IntOp $R4 $R4 * 1000            ; Convert second version major number
        
        ; Add minor numbers to create complete comparable values
        IntOp $R2 $R2 + $R3             ; First version complete number
        IntOp $R4 $R4 + $R5             ; Second version complete number
        
        ; Compare versions and set return value
        ${If} $R2 < $R4                 ; If first version is less than second
            StrCpy $R0 1
        ${ElseIf} $R2 > $R4             ; If first version is greater than second
            StrCpy $R0 2
        ${Else}                         ; If versions are equal
            StrCpy $R0 0
        ${EndIf}
        
        ; Restore registers from stack
        Pop $R5
        Pop $R4
        Pop $R3
        Pop $R2
        Pop $R1
        Exch $R0                        ; Put return value on stack
    FunctionEnd