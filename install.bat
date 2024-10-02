@echo off

REM Check if Docker is installed
docker --version
IF ERRORLEVEL 1 (
    echo Please install Docker and restart installation (https://docs.docker.com/install/)
)

REM Install docker-compose if needed
docker-compose --version
IF ERRORLEVEL 1 (
    echo Please install docker-compose and restart installation (https://docs.docker.com/compose/install/)
)

echo Do you wish to install the backend docker containers? (y/n)
set /p choice=
if %choice% == n goto skip_docker

:try_again
echo Please select the model you wish to use:
echo 1. Model stored on local machine
echo 2. Model on Hugging Face

set /p model_choice=
if NOT %model_choice% == 1 if NOT %model_choice% == 2 (
    echo Invalid choice. Please try again.
    goto try_again
)
if %model_choice% == 1 goto local_model
if %model_choice% == 2 goto hugging_face

:hugging_face
echo Installing backend server...
echo Please enter your Hugging Face token:
set /p hf_token=

echo Please enter the model you wish to use off hugging face (Recommended: google/gemma-2-2b-it)
set /p model=

goto start_docker

:local_model
echo Please enter the path to your model folder:
set /p model_path=
if not exist %model_path% (
    echo The path %model_path% does not exist. Please try again.
    goto local_model
)

echo Please enter the models folder name:
set /p model=
set model=/%model%

:start_docker

REM Run the Docker containers
docker-compose up -d

:skip_docker

REM Install the freescribe cleint

@echo off
echo Installing AI-Scribe client...
@REM for /f "tokens=1,* delims=:" %%a in ('curl -s https://api.github.com/repos/itssimko/ai-scribe/releases/latest ^| findstr "browser_download_url" ^| findstr "_windows.exe"') do (
@REM     curl -kOL %%b
@REM )

@REM Check if FreeScribe alrdy exists in appdata
if exist "%APPDATA%\FreeScribe" (
    echo FreeScribe already exists in %APPDATA%\FreeScribe
    echo Do you wish to overwrite the existing installation? (y/n)
    set /p choice=
    if %choice% == y goto run
    if %choice% == n goto open
)


echo Do you wish to run the freescribe installer now? (y/n)
set /p choice=
if %choice% == y goto run
if %choice% == n goto open

:run
REM Run the AI-Scribe client
start freescribeinstaller_windows.exe

:open
@REM Open freescribe
echo Do you wish to open freescribe now? (y/n)
set /p choice=
if %choice% == y goto open
if %choice% == n goto end

:open
start %APPDATA%\FreeScribe\client.exe

@REM End of installation
:end

echo Installation complete!
pause
