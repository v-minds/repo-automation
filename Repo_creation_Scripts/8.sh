#!/bin/bash

# Artifactory server URL
ARTIFACTORY_URL="https://vminds.jfrog.io/artifactory"

# Artifactory username and password (replace with your credentials)
USERNAME="avardhineni4@gmail.com"
API_KEY="AKCpBrvkRp4gkkQ3BtVzZPNh8pGnZfGEhn411GUeatAKHPRExdgPZVxgU2YRTsUsCLNzRBRso"

# Set the path to the new input file
input_file="inputs.txt"

# Read the repository inputs from the specified file
REPO_NAME=$(grep -m 1 "New Repository Name:" "$input_file" | cut -d ':' -f 2 | tr -d ' ' | tr '[:upper:]' '[:lower:]' | tr '_' '-')

PACKAGE_TYPE=$(grep -o "Package Type: [[:alnum:]]*" "$input_file" | cut -d ' ' -f 3)

RCLASS=$(grep -m 1 "Type of Repository:" "$input_file" | cut -d ':' -f 2 | tr '[:upper:]' '[:lower:]' | tr -d ' ')

URL=$(grep "URL:" "$input_file" | cut -d ' ' -f 2)

repository_poc=$(grep "Repository POC:" "$input_file" | cut -d ':' -f 2 | sed 's/,$//' | sed 's/^ *//')

INCLUSION_RULES=$(grep "Inclusion Rules:" "$input_file" | cut -d ':' -f 2 | tr -d ' ')

EXCLUSION_RULES=$(grep "Exclusion Rules:" "$input_file" | cut -d ':' -f 2 | tr -d ' ')

REPOSITORIES=$(grep "Repositories:" "$input_file" | cut -d ':' -f 2 | tr -d ' ')

DEFAULT_LOCAL_REPO=$(grep "Default Local Repo:" "$input_file" | cut -d ':' -f 2 | tr -d ' ')

# Convert the comma-separated list to an array
IFS=',' read -ra REPO_ARRAY <<< "$REPOSITORIES"

# Check if the package type is helm
if [ "$PACKAGE_TYPE" = "helm" ]; then
    # Check if the repository class is local or virtual
    if [[ "$RCLASS" == "local" || "$RCLASS" == "virtual" ]]; then
        # Append -local to local repo type
        local_repo_name="${REPO_NAME}-local"
        # JSON payload for local repository creation
        local_repo_json='{
            "key": "'"$local_repo_name"'",
            "rclass": "local",
            "url": "'"$URL"'",
            "packageType": "'"$PACKAGE_TYPE"'",
            "description": "'"$repository_poc"'",
            "includesPattern": "'"$INCLUSION_RULES"'",
            "excludesPattern": "'"$EXCLUSION_RULES"'",
            "repositories": '"$(printf '%s\n' "${REPO_ARRAY[@]}" | jq -R -s -c 'split("\n")[:-1]')"',
            "defaultDeploymentRepo": "'"$DEFAULT_LOCAL_REPO"'"
        }'
        echo "JSON Payload for Local Repository: $local_repo_json"
        # Function to create a local repository using the Artifactory REST API
        create_local_repo() {
            local response_local
            response_local=$(curl -u "$USERNAME:$API_KEY" -X PUT -H "Content-Type: application/json" \
            "$ARTIFACTORY_URL/api/repositories/$local_repo_name" -d "$local_repo_json"
            )
            if [[ $response_local == *"error"* ]]; then
                echo "Error creating local repository: $response_local"
                exit 1
            else
                echo "Local Repository '$local_repo_name' created successfully."
            fi
        }
        # Main script execution
        create_local_repo  # Attempt to create the local repository
    fi
    # Append -virtual to virtual repo type
    virtual_repo_name="${REPO_NAME}-virtual"
    # JSON payload for virtual repository creation
    virtual_repo_json='{
        "key": "'"$virtual_repo_name"'",
        "rclass": "virtual",
        "url": "'"$URL"'",
        "packageType": "'"$PACKAGE_TYPE"'",
        "description": "'"$repository_poc"'",
        "includesPattern": "'"$INCLUSION_RULES"'",
        "excludesPattern": "'"$EXCLUSION_RULES"'",
        "repositories": ["'"$local_repo_name"'"],
        "defaultDeploymentRepo": "'"$local_repo_name"'"
    }'
    echo "JSON Payload for Virtual Repository: $virtual_repo_json"
    # Function to create a virtual repository using the Artifactory REST API
    create_virtual_repo() {
        local response_virtual
        response_virtual=$(curl -u "$USERNAME:$API_KEY" -X PUT -H "Content-Type: application/json" \
        "$ARTIFACTORY_URL/api/repositories/$virtual_repo_name" -d "$virtual_repo_json"
        )
        if [[ $response_virtual == *"error"* ]]; then
            echo "Error creating virtual repository: $response_virtual"
            exit 1
        else
            echo "Virtual Repository '$virtual_repo_name' created successfully."
        fi
    }
    # Main script execution
    create_virtual_repo  # Attempt to create the virtual repository
fi

# Additional checks or actions can be added here

# Check if the package type is helm
if [ "$PACKAGE_TYPE" = "helm" ]; then
    # Check if the repository class is local or virtual
    if [ "$RCLASS" == "local" ]; then
        # Append -local to local repo type
        #LOCAL_REPO_NAME="${REPO_NAME}-local"
        # Check additional conditions
        if [ -f "$input_file" ] && grep -q "Anonymous Read-Only Access: Yes" "$input_file" && ! grep -q "Type of Repository: virtual" "$input_file" && grep -q "Anonymous Read-Only Access: Yes" "$input_file"; then
            # Your logic here for local repository
            # Retrieve permission target
            PERMISSION_TARGET=$(curl -u "$USERNAME:$API_KEY" -X GET "$ARTIFACTORY_URL/api/v2/security/permissions/anonymous-read-only-prod")
            echo "$PERMISSION_TARGET"
            # Extract existing repositories from the permission target
            EXISTING_REPOS=$(echo "$PERMISSION_TARGET" | jq -r '.repo.repositories | map("\"" + . + "\"") | join(", ")')
            echo "$EXISTING_REPOS"
            # Append the new repository name to the existing repositories
            NEW_REPOS1="$EXISTING_REPOS, \"$local_repo_name\""
            echo "$NEW_REPOS1"
            # Store the updated repositories list in a file
            echo "$NEW_REPOS1" > repositories_list.txt
            # Print the updated repositories list
            echo "Updated Repositories List: $NEW_REPOS1"
            # Update the permission target with the new repositories list
            curl -X PUT "$ARTIFACTORY_URL/api/v2/security/permissions/anonymous-read-only-prod" \
                -H "Content-Type: application/json" \
                -u "$USERNAME:$API_KEY" \
                -d '{
                    "name": "anonymous-read-only-prod",
                    "repo": {
                        "actions": {
                            "users": {
                                "anonymous": [
                                    "read"
                                ]
                            }
                        },
                        "repositories": ['"$NEW_REPOS1"'],
                        "include-patterns": [
                            "**"
                        ],
                        "exclude-patterns": [
                        ]
                    }
                }'
        fi
    fi
fi
