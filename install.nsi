;--------------------------------
;Include Modern UI and nsDialogs

    !include "MUI2.nsh"
    !include "nsDialogs.nsh"

    Var Checkbox_LLM
    Var Checkbox_Speech2Text
    Var Checkbox_FreeScribe

    Var LLM_Installed
    Var Speech2Text_Installed
    Var FreeScribe_Installed

    Var DropDown_Model
    Var Input_HFToken

;--------------------------------
;General

    Name "ClinicianFOCUS Toolbox Installer"
    OutFile "clinicianfocus_toolbox-installer.exe"

    InstallDir "$PROGRAMFILES\ClincianFOCUS Toolbox"

    ; Define the logo image
    !define MUI_ICON "./assets/logo.ico"

    !define MUI_ABORTWARNING

;--------------------------------
;Pages

    !insertmacro MUI_PAGE_LICENSE ".\assets\License.txt"
    !insertmacro MUI_PAGE_COMPONENTS
    Page custom ConditionalModelPageCreate ModelPageLeave
    !insertmacro MUI_PAGE_DIRECTORY
    !insertmacro MUI_PAGE_INSTFILES
    Page custom FinishPageCreate FinishPageLeave

    !insertmacro MUI_UNPAGE_CONFIRM
    !insertmacro MUI_UNPAGE_INSTFILES

    !insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections

    Section "Install Local-LLM-Container" Section1
        WriteUninstaller "$INSTDIR\uninstall.exe"
        Call CheckForDocker
        CreateDirectory "$INSTDIR\local-llm-container"
        CreateDirectory "$INSTDIR\local-llm-container\models"
        SetOutPath "$INSTDIR\local-llm-container"
        File ".\local-llm-container\*.*"
        StrCpy $LLM_Installed 1
    SectionEnd

    Section "Install Speech2Text-Container" Section2
        CreateDirectory "$INSTDIR\speech2text-container"
        SetOutPath "$INSTDIR\speech2text-container"
        File ".\speech2text-container\*.*"
        StrCpy $Speech2Text_Installed 1
    SectionEnd

    Section "Install Freescribe Client" Section3 

        CreateDirectory "$INSTDIR\freescribe"
        SetOutPath "$INSTDIR\freescribe"
        File ".\freescribe\FreeScribeInstaller_windows.exe"

        ExecWait '"$INSTDIR\freescribe\FreeScribeInstaller_windows.exe" /S /D=$APPDATA\FreeScribe'

        StrCpy $FreeScribe_Installed 1
    SectionEnd

;--------------------------------
;Conditional Model Selection Page Display

    Function ConditionalModelPageCreate
        SectionGetFlags ${Section1} $0
        IntOp $0 $0 & ${SF_SELECTED}
        ${If} $0 == ${SF_SELECTED}
            Call ModelPageCreate
        ${EndIf}
    FunctionEnd

;--------------------------------
;Model Selection Page Customization using nsDialogs

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

;--------------------------------
;UTIL FUNCTIONS

    Function CheckForDocker
        nsExec::ExecToStack 'docker-compose --version'
        Pop $0
        StrCmp $0 "0" +3 0
            MessageBox MB_OK "Docker Compose is not installed. Canceling install..."
            Abort
        nsExec::ExecToStack 'docker --version'
        Pop $0
        StrCmp $0 "0" +3 0
            MessageBox MB_OK "Docker is not installed. Canceling install..."
            Abort
    FunctionEnd
