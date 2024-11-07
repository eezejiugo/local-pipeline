#!/bin/bash

# Colors
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
CYAN=$(tput setaf 6)
NC=$(tput sgr0)  # No Color

# Functions
print_separator() {
    printf "\n%s\n\n" "${BLUE}${BOLD}----------------------------------------------------------------------------------${NC}"
}

print_step() {
    printf "%s\n" "${YELLOW}${BOLD}Step $1: $2${NC}"
}

print_error() {
    printf "%s\n" "${RED}${BOLD}$1${NC}"
}

print_success() {
    printf "%s\n" "${GREEN}${BOLD}$1${NC}"
}

print_title() {
    printf "%s\n" "${CYAN}${BOLD}$1${NC}"
}

# Step 1: Service Type Selection
print_step "1" "Service Type Selection"
print_title "Select service type:"
printf "%s\n" "${GREEN}- [1] Library${NC}"
printf "%s\n" "${YELLOW}- [2] Egress${NC}"
printf "%s\n" "${RED}- [3] Other Services${NC}"

while true; do
    read -p "Enter option [1-3]: " choice
    case $choice in
        1 ) 
            SERVICE_TYPE="maven-repository"
            print_success "Library service selected"
            IS_LIBRARY=true
            break;;
        2 ) 
            SERVICE_TYPE="egress-vertx"
            print_success "Egress service selected"
            IS_LIBRARY=false
            break;;
        3 ) 
            SERVICE_TYPE="neonomics-application"
            print_success "Other services selected"
            IS_LIBRARY=false
            break;;
       * ) 
            print_error "Invalid input. Please enter a number between 1 and 3";;
    esac
done

PATH_TO_HELM_PROJECT="/Path/to/helm-repository/stable/$SERVICE_TYPE"
print_separator

# For Library, we need WRK_PROJECT_PATH first before other steps
if [ "$IS_LIBRARY" = true ]; then
    print_title "Enter the path to your project:"
    printf "[x] Run command 'pwd' in the project directory and paste the output here.\n"
    read WRK_PROJECT_PATH
    print_separator

    # Extra step confirm if kubectl context is development
    print_title "Confirm you have switched your kubectl context to 'development'"
    printf "[x] Run command 'kubectl config current-context' to confirm\n"
    printf "[x] Run command 'kubectl config use-context gke_development-240711_europe-west3_main-cluster' to switch\n"
    while true; do
        read -p "Confirm switch? [Y/N]: " confirm
        case $confirm in
            [Yy]* )
                print_success "kubectl context switched to 'development'"
                break;;
            [Nn]* )
                print_error "Cancel deployment. Please switch kubectl context and try again"
                exit 1;;
            * )
                print_error "Invalid input. Please enter Y or N";;
        esac
    done
    print_separator


    # Step 2: Maven Build for Library
    print_step "2" "Building Maven Package"
    printf "%s\n" "${YELLOW}CD into project directory...${NC}"

    if cd "$WRK_PROJECT_PATH"; then
        print_separator
        
        # Get current git branch
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')
        if [ $? -eq 0 ]; then
            print_success "Current git branch: $CURRENT_BRANCH"
            
            # Confirm branch
            while true; do
                read -p "Continue with branch '$CURRENT_BRANCH'? [Y/N]: " confirm
                case $confirm in
                    [Yy]* )
                        print_success "Proceeding with branch: $CURRENT_BRANCH"
                        break;;
                    [Nn]* )
                        print_error "Deployment cancelled. Please checkout the correct branch and try again"
                        exit 1;;
                    * )
                        print_error "Invalid input. Please enter Y or N";;
                esac
            done
        else
            print_error "Failed to get git branch. Is this a git repository?"
            exit 1
        fi
        print_separator

        # Using SED to set for local deployment
        printf "Using SED to set for local deployment"
        sed -i '' "s/integration-240711/development-240711/g" "pom.xml"
        print_separator

        # Setting version in POM
        printf "%s\n" "${YELLOW}Setting version in pom.xml...${NC}"
        sleep 2
        
        release_version="${CURRENT_BRANCH}-SNAPSHOT"
        if mvn versions:set -DnewVersion="$release_version" -DprocessAllModules -DgenerateBackupPoms=false -q; then
            print_separator
        else
            print_error "Setting version in POM failed"
            exit 1
        fi

        # Maven package
        printf "%s\n" "${YELLOW}Maven package...${NC}"
        sleep 2
        
        if mvn -Dmaven.test.skip=true clean package -U; then
            print_separator
        else
            print_error "Maven package failed"
            exit 1
        fi

        # Maven deploy
        printf "%s\n" "${YELLOW}Maven deploy...${NC}"
        sleep 2
        
        GAR_REPOSITORY="artifactregistry://europe-west3-maven.pkg.dev/development-240711/maven-repository"
        if mvn -DaltDeploymentRepository=artifact-registry::default::"$GAR_REPOSITORY" \
        -Dmaven.test.skip=true clean deploy; then
            print_separator
        else
            print_error "Maven deploy failed"
            exit 1
        fi

        # Using SED to revert to production deployment
        printf "Using SED to revert to production deployment"
        sed -i '' "s/development-240711/integration-240711/g" "pom.xml"
        print_separator
    else
        print_error "Failed to change directory"
        exit 1
    fi

    print_success "Library deployment completed"
    print_separator
    exit 0
else
    # Continue with regular deployment steps
    # Step 2: Project Configuration
    print_step "2" "Project Configuration"

    print_title "Select deployment environment:"
    printf "%s\n" "${GREEN}- [1] Staging${NC}"
    printf "%s\n" "${RED}- [2] Development${NC}"

    while true; do
        read -p "Enter option [1-2]: " choice
        case $choice in
            1 ) 
                DEPLOYMENT_ENVIRONMENT="staging"
                print_success "Staging environment selected"
                break;;
            2 ) 
                DEPLOYMENT_ENVIRONMENT="development"
                print_success "Development environment selected"
                break;;
            * ) 
                print_error "Invalid input. Please enter '1' for Staging or '2' for Development";;
        esac
    done
    print_separator

    # Extra step confirm if kubectl context is development
    print_title "Confirm you are authenticated & have switched your kubectl context to $DEPLOYMENT_ENVIRONMENT"
    printf "[x] Run command 'gcloud auth login' to authenticate\n"
    printf "[x] Run command 'kubectl config current-context' to confirm\n"
    printf "[x] Run command 'kubectl config use-context gke_${DEPLOYMENT_ENVIRONMENT}-240711_europe-west3_main-cluster' to switch\n"
    while true; do
        read -p "Confirm switch? [Y/N]: " confirm
        case $confirm in
            [Yy]* )
                print_success "Authenticated & kubectl context switched to '$DEPLOYMENT_ENVIRONMENT'"
                break;;
            [Nn]* )
                print_error "Cancel deployment. Please switch kubectl context and try again"
                exit 1;;
            * )
                print_error "Invalid input. Please enter Y or N";;
        esac
    done
    print_separator

    print_title "Enter the path to your project:"
    printf "[x] Run command 'pwd' in the project directory and paste the output here.\n"
    read WRK_PROJECT_PATH
    print_separator

    HELM_VALUES_FILE="$WRK_PROJECT_PATH/deployment/helm-values-$DEPLOYMENT_ENVIRONMENT.yaml"
    print_separator

    # Step 3: Maven Build
    print_step "3" "Building Maven Package"
    printf "%s\n" "${YELLOW}CD into project directory...${NC}"

    if cd "$WRK_PROJECT_PATH"; then
        print_separator

        # Get current git branch
        printf "%s\n" "${YELLOW}Get project Git branch...${NC}"
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')
        sleep 2
        print_success "Current git branch: $CURRENT_BRANCH"
        print_separator

        # Using SED to update helm-values-$DEPLOYMENT_ENVIRONMENT.yaml
        printf "%s\n" "${YELLOW}Using SED to update helm-values-$DEPLOYMENT_ENVIRONMENT.yaml...${NC}"

        # Read pod namespace
        NAMESPACE=$(grep 'namespace:' "$HELM_VALUES_FILE" | head -n 1 | awk -F'"' '{print $2}')
        if [[ -z "$NAMESPACE" ]]; then
            print_error "Could not find the pod namespace in $HELM_VALUES_FILE"
            exit 1
        fi

        # Read pod release name
        # This info is found in the Pod > Deployment release name from OpenLens
        DEPLOYMENT_RELEASE_NAME=$(grep 'release-name:' "$HELM_VALUES_FILE" | head -n 1 | awk -F'"' '{print $2}')
        if [[ -z "$DEPLOYMENT_RELEASE_NAME" ]]; then
            print_error "Could not find the pod release-name in $HELM_VALUES_FILE"
            exit 1
        fi

        # Read app name
        APP_NAME=$(grep 'appName:' "$HELM_VALUES_FILE" | head -n 1 | awk -F'"' '{print $2}')
        if [[ -z "$APP_NAME" ]]; then
            print_error "Could not find the appName in $HELM_VALUES_FILE"
            exit 1
        fi

        # Extract the current version from the Helm values file
        CURRENT_VERSION=$(awk -F'[:, ]+' '/tag:/ {print $3}' "$HELM_VALUES_FILE")
        if [[ -z "$CURRENT_VERSION" ]]; then
            echo "Error: Could not find the image.tag in $HELM_VALUES_FILE."
            exit 1
        fi

        # Set new version from branch
        BUILD_TIMESTAMP=$(date +%Y%m%d%H%M%S)
        NEW_VERSION="${CURRENT_BRANCH}-${BUILD_TIMESTAMP}-SNAPSHOT"

        printf "%s\n" "${YELLOW}Updating version from $CURRENT_VERSION to $NEW_VERSION${NC}"

        # Update both tag and version in the file
        sed -i '' "s|tag: .*|tag: ${NEW_VERSION}|g" "$HELM_VALUES_FILE"
        sed -i '' "s|version: .*|version: \"${NEW_VERSION}\",|g" "$HELM_VALUES_FILE"

        print_success "Updated versions in $HELM_VALUES_FILE"
        print_separator

        # Running Maven package
        printf "%s\n" "${YELLOW}Building Maven package...${NC}"
        sleep 1
        if mvn -Dmaven.test.skip=true clean package -U; then
            print_separator
        else
            print_error "Maven build failed"
            exit 1
        fi

        # Step 4: Docker Build
        print_step "4" "Building Docker Image"
        sleep 1
        DOCKER_IMAGE="europe-west3-docker.pkg.dev/development-240711/docker-repository/$APP_NAME:${NEW_VERSION}"
        if ! docker build -t "$DOCKER_IMAGE" .; then
            print_error "Docker build failed"
            exit 1
        fi
        print_separator

        # Step 5: Docker Push
        print_step "5" "Pushing Docker Image"
        sleep 1
        if ! docker push "$DOCKER_IMAGE"; then
            print_error "Docker push failed"
            exit 1
        fi
        print_success "$APP_NAME:${NEW_VERSION} pushed to Docker registry"
        print_separator

        # Step 6: Helm Deployment
        print_step "6" "Upgrading Helm Release"
        sleep 2
        if ! helm upgrade --install \
            --namespace "$NAMESPACE" \
            -f "$WRK_PROJECT_PATH/deployment/helm-values-$DEPLOYMENT_ENVIRONMENT.yaml" \
            "$DEPLOYMENT_RELEASE_NAME" \
            "$PATH_TO_HELM_PROJECT" \
            --atomic \
            --cleanup-on-fail \
            --timeout 300s; then
            print_error "Helm upgrade failed"
            exit 1
        fi
        print_separator

    else
        print_error "Failed to change directory"
        exit 1
    fi

    print_success "Process completed & deployed to env=$DEPLOYMENT_ENVIRONMENT"
    printf "%s\n" "${YELLOW}${BOLD}Confirm deployment using OpenLens${NC}"
    print_separator
fi