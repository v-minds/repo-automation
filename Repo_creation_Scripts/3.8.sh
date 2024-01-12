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

# Check if the package type is terraform, helm, or other
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
      "defaultDeploymentRepo": "'"$DEFAULT_LOCAL_REPO"'"
    }'
elif [ "$PACKAGE_TYPE" = "helm" ]; then
    # Create local repository for helm
    LOCAL_REPO_NAME="${REPO_NAME}-local"
    LOCAL_REPO_JSON='{
      "key": "'"$LOCAL_REPO_NAME"'",
      "rclass": "local",
      "url": "'"$URL"'",
      "packageType": "'"$PACKAGE_TYPE"'",
      "description": "'"$repository_poc"'",
      "includesPattern": "'"$INCLUSION_RULES"'",
      "excludesPattern": "'"$EXCLUSION_RULES"'",
      "repositories": '"$(printf '%s\n' "${REPO_ARRAY[@]}" | jq -R -s -c 'split("\n")[:-1]')"',
      "defaultDeploymentRepo": "'"$DEFAULT_LOCAL_REPO"'"
    }'

    # Create virtual repository for helm
    VIRTUAL_REPO_NAME="${REPO_NAME}-virtual"
    VIRTUAL_REPO_JSON='{
      "key": "'"$VIRTUAL_REPO_NAME"'",
      "rclass": "virtual",
      "packageType": "'"$PACKAGE_TYPE"'",
      "description": "'"$repository_poc"'",
      "includesPattern": "'"$INCLUSION_RULES"'",
      "excludesPattern": "'"$EXCLUSION_RULES"'",
      "repositories": ["'"$LOCAL_REPO_NAME"'"],  # Reference the local repository
      "defaultDeploymentRepo": "'"$DEFAULT_LOCAL_REPO"'"
    }'

# Function to create helm repositories
    create_helm_repos() {
      create_repo "$LOCAL_REPO_NAME" "$LOCAL_REPO_JSON"
      create_repo "$VIRTUAL_REPO_NAME" "$VIRTUAL_REPO_JSON"
    }

    create_helm_repos  # Attempt to create the repositories
else
    # JSON payload for repository creation without terraformType or helm logic
    REPO_JSON='{
      "key": "'"$REPO_NAME"'",
      "rclass": "'"$RCLASS"'",
      "url": "'"$URL"'",
      "packageType": "'"$PACKAGE_TYPE"'",
      "description": "'"$repository_poc"'",
      "includesPattern": "'"$INCLUSION_RULES"'",
      "excludesPattern": "'"$EXCLUSION_RULES"'",
      "repositories": '"$(printf '%s\n' "${REPO_ARRAY[@]}" | jq -R -s -c 'split("\n")[:-1]')"',
      "defaultDeploymentRepo": "'"$DEFAULT_LOCAL_REPO"'"
    }'
fi

echo "JSON Payload: $REPO_JSON"


# Function to create a repository using the Artifactory REST API
create_repo() {
  local repo_name="$1"
  local repo_json="$2"
  local response
  response=$(curl -u "$USERNAME:$API_KEY" -X PUT -H "Content-Type: application/json" \
    "$ARTIFACTORY_URL/api/repositories/$repo_name" -d "$repo_json"
  )
  if [[ $response == *"error"* ]]; then
    echo "Error creating repository $repo_name: $response"
    exit 1  # Exit the script if repository creation fails
  else
    echo "Repository '$repo_name' created successfully."
    # Check if the repository class is "local" and set the storage quota
    if [ "$RCLASS" == "local" ]; then
      quota_response=$(curl -u "$USERNAME:$API_KEY" -X PUT "$ARTIFACTORY_URL/api/storage/$repo_name?properties=repository.path.quota=107374182400")
      if [[ $quota_response == *"error"* ]]; then
        echo "Error setting storage quota for the local repository $repo_name: $quota_response"
      else
        echo "Storage quota set for the local repository '$repo_name'."
      fi
    fi
  fi
}

# Function to create helm repositories
create_helm_repos() {
  create_repo "$LOCAL_REPO_NAME" "$LOCAL_REPO_JSON"
  create_repo "$VIRTUAL_REPO_NAME" "$VIRTUAL_REPO_JSON"
}

# Main script execution
if [ "$PACKAGE_TYPE" = "helm" ]; then
  create_helm_repos  # Attempt to create the repositories
else
  create_repo "$REPO_NAME" "$REPO_JSON"  # Attempt to create the repository
fi

# Check if the file exists and Anonymous Read-Only Access is Yes
if [ -f "$input_file" ] && grep -q "Anonymous Read-Only Access: Yes" "$input_file" && ! grep -q "Type of Repository: virtual" "$input_file" && grep -q "Anonymous Read-Only Access: Yes" "$input_file"; then
    # Retrieve permission target
    PERMISSION_TARGET=$(curl -u "$USERNAME:$API_KEY" -X GET "$ARTIFACTORY_URL/api/v2/security/permissions/anonymous-read-only-prod")
    echo "$PERMISSION_TARGET"
    
    # Extract existing repositories from the permission target
    EXISTING_REPOS=$(echo "$PERMISSION_TARGET" | jq -r '.repo.repositories | map("\"" + . + "\"") | join(", ")')
    echo "$EXISTING_REPOS"

    # Extract REPO_NAME from the latest txt file
    REPO_NAME=$(grep -m 1 "New Repository Name:" "$input_file" | cut -d ':' -f 2 | tr -d ' ' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
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

