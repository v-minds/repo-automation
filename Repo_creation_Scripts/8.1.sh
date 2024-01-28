#!/bin/bash

# Artifactory server URL
ARTIFACTORY_URL="https://nnv.jfrog.io/artifactory"

# Artifactory username and password (replace with your credentials)
USERNAME="avardhineni2@gmail.com"
API_KEY="AKCpBrw54cFb31CoBkJRBYVET7ewRsPiskAbF4NdhmGGSzdUJaKGPP7p9MFe9BrK3H1d7cs14"

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

# Construct repository names
local_repo_name="${REPO_NAME}-local"
virtual_repo_name="${REPO_NAME}-virtual"

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
    "defaultDeploymentRepo": "'"$DEFAULT_LOCAL_REPO"'"
}'

echo "JSON Payload for Virtual Repository: $virtual_repo_json"

# Function to create a repository using the Artifactory REST API
create_repo() {
    local repo_name="$1"
    local repo_json="$2"
    local response
    response=$(curl -u "$USERNAME:$API_KEY" -X PUT -H "Content-Type: application/json" \
        "$ARTIFACTORY_URL/api/repositories/$repo_name" -d "$repo_json"
    )
    if [[ $response == *"error"* ]]; then
        echo "Error creating repository '$repo_name': $response"
        exit 1
    else
        echo "Repository '$repo_name' created successfully."
    fi
}

# Main script execution
create_repo "$local_repo_name" "$local_repo_json"  # Attempt to create the local repository

create_repo "$virtual_repo_name" "$virtual_repo_json"  # Attempt to create the virtual repository



