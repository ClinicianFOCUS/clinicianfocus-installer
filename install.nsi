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

;--------------------------------
;General

    Name "ClinicianFOCUS Toolbox Installer"
    OutFile "clinicianfocus_toolbox-installer.exe"

    InstallDir "$PROGRAMFILES\TOOLKITFORFOCUS"

    ; Define the logo image
    !define MUI_ICON "./assets/logo.ico"

    !define MUI_ABORTWARNING

;--------------------------------
;Pages

    !insertmacro MUI_PAGE_LICENSE ".\assets\License.txt"
    !insertmacro MUI_PAGE_COMPONENTS
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
        Exec '"$INSTDIR\freescribe\Freescribe.exe"'
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
