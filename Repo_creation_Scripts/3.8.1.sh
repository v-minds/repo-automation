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

# Create a JSON-friendly string for repositories
# REPO_LIST=$(IFS=, ; echo "${REPO_ARRAY[*]}")

# Check if the package type is terraform
if [ "$PACKAGE_TYPE" = "terraform" ]; then
    terraformType=$(grep "terraformType:" "$input_file" | cut -d ':' -f 2 | tr -d ' ')
    REPO_JSON='{
      "key": "'"$REPO_NAME"'",
      "rclass": "'"$RCLASS"'",
      "url": "'"$URL"'",
      "packageType": "'"$PACKAGE_TYPE"'",
      "terraformType": "'"$terraformType"'",
      "description": "'"$repository_poc"'",
      "includesPattern": "'"$INCLUSION_RULES"'",
      "excludesPattern": "'"$EXCLUSION_RULES"'",
      "repositories": '"$(printf '%s\n' "${REPO_ARRAY[@]}" | jq -R -s -c 'split("\n")[:-1]')"',
      "defaultDeploymentRepo": "'"$DEFAULT_LOCAL_REPO"'",
      "repoLayoutRef": "'"simple-default"'"
    }'
else
    # JSON payload for repository creation without terraformType
    REPO_JSON='{
      "key": "'"$REPO_NAME"'",
      "rclass": "'"$RCLASS"'",
      "url": "'"$URL"'",
      "packageType": "'"$PACKAGE_TYPE"'",
      "description": "'"$repository_poc"'",
      "includesPattern": "'"$INCLUSION_RULES"'",
      "excludesPattern": "'"$EXCLUSION_RULES"'",
      "repositories": '"$(printf '%s\n' "${REPO_ARRAY[@]}" | jq -R -s -c 'split("\n")[:-1]')"',
      "defaultDeploymentRepo": "'"$DEFAULT_LOCAL_REPO"'",
      "repoLayoutRef": "'"simple-default"'"
    }'
fi

echo "JSON Payload: $REPO_JSON"
# Function to create a local repository using the Artifactory REST API
create_repo() {
  local response
  response=$(curl -u "$USERNAME:$API_KEY" -X PUT -H "Content-Type: application/json" \
    "$ARTIFACTORY_URL/api/repositories/$REPO_NAME" -d "$REPO_JSON"
  )
  if [[ $response == *"error"* ]]; then
    echo "Error creating repository: $response"
    exit 1  # Exit the script if repository creation fails
  else
    echo "Repository '$REPO_NAME' created successfully."
    # Check if the repository class is "local" and set the storage quota
    if [ "$RCLASS" == "local" ]; then
      quota_response=$(curl -u "$USERNAME:$API_KEY" -X PUT "$ARTIFACTORY_URL/api/storage/$REPO_NAME?properties=repository.path.quota=107374182400")
      if [[ $quota_response == *"error"* ]]; then
        echo "Error setting storage quota for the local repository: $quota_response"
      else
        echo "Storage quota set for the local repository '$REPO_NAME'."
      fi
    fi
  fi
}

# Main script execution
create_repo  # Attempt to create the repository

# Check if the file exists and Anonymous Read-Only Access is Yes
# if [ -f "$input_file" ] && grep -q "Anonymous Read-Only Access: Yes" "$input_file"; then
# if [ -f "$input_file" ] && grep -q "Anonymous Read-Only Access: Yes" "$input_file" && ! grep -q "Type of Repository: virtual" "$input_file"; then

if [ -f "$input_file" ] && grep -q "Anonymous Read-Only Access: Yes" "$input_file" && ! grep -q "Type of Repository: virtual" "$input_file" && grep -q "Anonymous Read-Only Access: Yes" "$input_file"; then

    # Retrieve permission target
    PERMISSION_TARGET=$(curl -u "$USERNAME:$API_KEY" -X GET "$ARTIFACTORY_URL/api/v2/security/permissions/anonymous-read-only-prod")
    echo "$PERMISSION_TARGET"

    # Extract existing repositories from the permission target
    EXISTING_REPOS=$(echo "$PERMISSION_TARGET" | jq -r '.repo.repositories | map("\"" + . + "\"") | join(", ")')
    echo "$EXISTING_REPOS"

    # Extract REPO_NAME from the latest txt file
    REPO_NAME=$(cat "$input_file" | grep -m 1 "New Repository Name:" | cut -d ':' -f 2 | tr -d ' ' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    echo "$REPO_NAME"

    # Append the new repository name to the existing repositories
    NEW_REPOS="$EXISTING_REPOS, \"$REPO_NAME\""
    echo "$NEW_REPOS"

    # Store the updated repositories list in a file
    echo "$NEW_REPOS" > repositories_list.txt

    # Print the updated repositories list
    echo "Updated Repositories List: $NEW_REPOS"

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
            "repositories": ['"$NEW_REPOS"'],
            "include-patterns": [
                "**"
            ],
            "exclude-patterns": [
            ]
        }
    }'
fi

# Check if the package type is docker
if [ "$PACKAGE_TYPE" = "docker" ]; then
    # Display the registry URL based on the repository name
    REGISTRY_URL="$REPO_NAME.docker.artifactory.viasat.com"
    echo "Registry URL: $REGISTRY_URL"
fi
