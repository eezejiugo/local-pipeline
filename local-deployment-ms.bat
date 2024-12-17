@echo off
setlocal EnableDelayedExpansion

:: ANSI Color codes for Windows
set "BOLD=[1m"
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "CYAN=[96m"
set "NC=[0m"

:: Functions (using labels)
:print_separator
echo.
echo %BLUE%%BOLD%-----------------------------------------------------------------------------------%NC%
echo.
goto :eof

:print_step
echo %YELLOW%%BOLD%Step %~1: %~2%NC%
goto :eof

:print_error
echo %RED%%BOLD%%~1%NC%
goto :eof

:print_success
echo %GREEN%%BOLD%%~1%NC%
goto :eof

:print_title
echo %CYAN%%BOLD%%~1%NC%
goto :eof

:: Main Script
call :print_step "1" "Service Type Selection"
call :print_title "Select service type:"
echo %GREEN%- [1] Library%NC%
echo %YELLOW%- [2] Egress%NC%
echo %RED%- [3] Other Services%NC%

:service_type_selection
set /p choice="Enter option [1-3]: "
if "%choice%"=="1" (
    set "SERVICE_TYPE=maven-repository"
    set "IS_LIBRARY=true"
    call :print_success "Library service selected"
    goto service_type_done
) else if "%choice%"=="2" (
    set "SERVICE_TYPE=egress-vertx"
    set "IS_LIBRARY=false"
    call :print_success "Egress service selected"
    goto service_type_done
) else if "%choice%"=="3" (
    set "SERVICE_TYPE=neonomics-application"
    set "IS_LIBRARY=false"
    call :print_success "Other services selected"
    goto service_type_done
) else (
    call :print_error "Invalid input. Please enter a number between 1 and 3"
    goto service_type_selection
)

:service_type_done
set "PATH_TO_HELM_PROJECT=\Path\to\helm-repository\stable\%SERVICE_TYPE%"
call :print_separator

:: Library specific workflow
if "%IS_LIBRARY%"=="true" (
    call :print_title "Enter the path to your project:"
    echo [x] Run command 'cd' in the project directory and paste the output here.
    set /p WRK_PROJECT_PATH=

    call :print_separator

    :: Confirm kubectl context
    call :print_title "Confirm you have switched your kubectl context to 'development'"
    echo [x] Run command 'kubectl config current-context' to confirm
    echo [x] Run command 'kubectl config use-context gke_development-240711_europe-west3_main-cluster' to switch

    :confirm_kubectl_library
    set /p confirm="Confirm switch? [Y/N]: "
    if /i "%confirm%"=="y" (
        call :print_success "kubectl context switched to 'development'"
    ) else if /i "%confirm%"=="n" (
        call :print_error "Cancel deployment. Please switch kubectl context and try again"
        exit /b 1
    ) else (
        call :print_error "Invalid input. Please enter Y or N"
        goto confirm_kubectl_library
    )

    call :print_separator

    :: Maven Build for Library
    call :print_step "2" "Building Maven Package"
    echo %YELLOW%CD into project directory...%NC%

    cd /d "%WRK_PROJECT_PATH%" || (
        call :print_error "Failed to change directory"
        exit /b 1
    )

    :: Get current git branch
    for /f "tokens=*" %%a in ('git rev-parse --abbrev-ref HEAD') do set "CURRENT_BRANCH=%%a"
    if !errorlevel! neq 0 (
        call :print_error "Failed to get git branch. Is this a git repository?"
        exit /b 1
    )
    set "CURRENT_BRANCH=!CURRENT_BRANCH:/=-!"
    call :print_success "Current git branch: !CURRENT_BRANCH!"

    :confirm_branch
    set /p confirm="Continue with branch '!CURRENT_BRANCH!'? [Y/N]: "
    if /i "!confirm!"=="y" (
        call :print_success "Proceeding with branch: !CURRENT_BRANCH!"
    ) else if /i "!confirm!"=="n" (
        call :print_error "Deployment cancelled. Please checkout the correct branch and try again"
        exit /b 1
    ) else (
        goto confirm_branch
    )

    call :print_separator

    :: Using PowerShell for SED-like functionality
    powershell -Command "(Get-Content pom.xml) -replace 'integration-240711', 'development-240711' | Set-Content pom.xml"
    call :print_separator

    :: Setting version in POM
    echo %YELLOW%Setting version in pom.xml...%NC%
    timeout /t 2 /nobreak > nul

    set "release_version=!CURRENT_BRANCH!-SNAPSHOT"
    call mvn versions:set -DnewVersion="!release_version!" -DprocessAllModules -DgenerateBackupPoms=false -q
    if !errorlevel! neq 0 (
        call :print_error "Setting version in POM failed"
        exit /b 1
    )
    call :print_separator

    :: Maven package
    echo %YELLOW%Maven package...%NC%
    timeout /t 2 /nobreak > nul

    call mvn -Dmaven.test.skip=true clean package -U
    if !errorlevel! neq 0 (
        call :print_error "Maven package failed"
        exit /b 1
    )
    call :print_separator

    :: Maven deploy
    echo %YELLOW%Maven deploy...%NC%
    timeout /t 2 /nobreak > nul

    set "GAR_REPOSITORY=artifactregistry://europe-west3-maven.pkg.dev/development-240711/maven-repository"
    call mvn -DaltDeploymentRepository=artifact-registry::default::"%GAR_REPOSITORY%" -Dmaven.test.skip=true clean deploy
    if !errorlevel! neq 0 (
        call :print_error "Maven deploy failed"
        exit /b 1
    )
    call :print_separator

    :: Revert pom.xml changes
    powershell -Command "(Get-Content pom.xml) -replace 'development-240711', 'integration-240711' | Set-Content pom.xml"
    call :print_separator

    call :print_success "Library deployment completed"
    call :print_separator
    exit /b 0

) else (
    :: Regular deployment steps
    call :print_step "2" "Project Configuration"

    call :print_title "Select deployment environment:"
    echo %GREEN%- [1] Staging%NC%
    echo %RED%- [2] Development%NC%

    :env_selection
    set /p choice="Enter option [1-2]: "
    if "%choice%"=="1" (
        set "DEPLOYMENT_ENVIRONMENT=staging"
        call :print_success "Staging environment selected"
    ) else if "%choice%"=="2" (
        set "DEPLOYMENT_ENVIRONMENT=development"
        call :print_success "Development environment selected"
    ) else (
        call :print_error "Invalid input. Please enter '1' for Staging or '2' for Development"
        goto env_selection
    )
    call :print_separator

    :: Confirm kubectl context
    call :print_title "Confirm you are authenticated & have switched your kubectl context to %DEPLOYMENT_ENVIRONMENT%"
    echo [x] Run command 'gcloud auth login' to authenticate
    echo [x] Run command 'kubectl config current-context' to confirm
    echo [x] Run command 'kubectl config use-context gke_%DEPLOYMENT_ENVIRONMENT%-240711_europe-west3_main-cluster' to switch

    :confirm_kubectl
    set /p confirm="Confirm switch? [Y/N]: "
    if /i "%confirm%"=="y" (
        call :print_success "Authenticated & kubectl context switched to '%DEPLOYMENT_ENVIRONMENT%'"
    ) else if /i "%confirm%"=="n" (
        call :print_error "Cancel deployment. Please switch kubectl context and try again"
        exit /b 1
    ) else (
        call :print_error "Invalid input. Please enter Y or N"
        goto confirm_kubectl
    )
    call :print_separator

    call :print_title "Enter the path to your project:"
    echo [x] Run command 'cd' in the project directory and paste the output here.
    set /p WRK_PROJECT_PATH=
    call :print_separator

    set "HELM_VALUES_FILE=%WRK_PROJECT_PATH%\deployment\helm-values-%DEPLOYMENT_ENVIRONMENT%.yaml"

    :: Maven Build
    call :print_step "3" "Building Maven Package"
    echo %YELLOW%CD into project directory...%NC%

    cd /d "%WRK_PROJECT_PATH%" || (
        call :print_error "Failed to change directory"
        exit /b 1
    )

    :: Get current git branch
    for /f "tokens=*" %%a in ('git rev-parse --abbrev-ref HEAD') do set "CURRENT_BRANCH=%%a"
    set "CURRENT_BRANCH=!CURRENT_BRANCH:/=-!"
    call :print_success "Current git branch: !CURRENT_BRANCH!"
    call :print_separator

    :: Extract values from yaml using PowerShell
    for /f "tokens=*" %%a in ('powershell -Command "Get-Content '%HELM_VALUES_FILE%' | Select-String 'namespace:' | ForEach-Object { $_.Line.Split(':')[1].Trim().Trim('\"') }"') do set "NAMESPACE=%%a"
    for /f "tokens=*" %%a in ('powershell -Command "Get-Content '%HELM_VALUES_FILE%' | Select-String 'release-name:' | ForEach-Object { $_.Line.Split(':')[1].Trim().Trim('\"') }"') do set "DEPLOYMENT_RELEASE_NAME=%%a"
    for /f "tokens=*" %%a in ('powershell -Command "Get-Content '%HELM_VALUES_FILE%' | Select-String 'appName:' | ForEach-Object { $_.Line.Split(':')[1].Trim().Trim('\"') }"') do set "APP_NAME=%%a"
    for /f "tokens=*" %%a in ('powershell -Command "Get-Content '%HELM_VALUES_FILE%' | Select-String 'tag:' | ForEach-Object { $_.Line.Split(':')[1].Trim() }"') do set "CURRENT_VERSION=%%a"

    :: Set new version
    for /f "tokens=*" %%a in ('powershell -Command "Get-Date -Format yyyyMMddHHmmss"') do set "BUILD_TIMESTAMP=%%a"
    set "NEW_VERSION=!CURRENT_BRANCH!-!BUILD_TIMESTAMP!-SNAPSHOT"

    :: Update yaml file using PowerShell
    powershell -Command "(Get-Content '%HELM_VALUES_FILE%') -replace 'tag: .*', 'tag: !NEW_VERSION!' | Set-Content '%HELM_VALUES_FILE%'"
    powershell -Command "(Get-Content '%HELM_VALUES_FILE%') -replace 'version: .*', 'version: \"!NEW_VERSION!\",' | Set-Content '%HELM_VALUES_FILE%'"

    :: Maven package
    call mvn -Dmaven.test.skip=true clean package -U
    if !errorlevel! neq 0 (
        call :print_error "Maven build failed"
        exit /b 1
    )

    :: Docker build
    call :print_step "4" "Building Docker Image"
    set "DOCKER_IMAGE=europe-west3-docker.pkg.dev/development-240711/docker-repository/%APP_NAME%:%NEW_VERSION%"
    docker build -t "%DOCKER_IMAGE%" .
    if !errorlevel! neq 0 (
        call :print_error "Docker build failed"
        exit /b 1
    )
    call :print_separator

    :: Docker push
    call :print_step "5" "Pushing Docker Image"
    docker push "%DOCKER_IMAGE%"
    if !errorlevel! neq 0 (
        call :print_error "Docker push failed"
        exit /b 1
    )
    call :print_success "%APP_NAME%:%NEW_VERSION% pushed to Docker registry"
    call :print_separator

    :: Helm deployment
    call :print_step "6" "Upgrading Helm Release"
    helm upgrade --install ^
        --namespace "%NAMESPACE%" ^
        -f "%WRK_PROJECT_PATH%\deployment\helm-values-%DEPLOYMENT_ENVIRONMENT%.yaml" ^
        "%DEPLOYMENT_RELEASE_NAME%" ^
        "%PATH_TO_HELM_PROJECT%" ^
        --atomic ^
        --cleanup-on-fail ^
        --timeout 300s

    if !errorlevel! neq 0 (
        call :print_error "Helm upgrade failed"
        exit /b 1
    )
    call :print_separator

    call :print_success "Process completed & deployed to env=%DEPLOYMENT_ENVIRONMENT%"
    echo %YELLOW%%BOLD%Confirm deployment using OpenLens%NC%
    call :print_separator
)

endlocal