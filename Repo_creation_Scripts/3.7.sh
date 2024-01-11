#!/bin/bash

# Artifactory server URL
ARTIFACTORY_URL="https://vminds.jfrog.io/artifactory"

# Artifactory username and password (replace with your credentials)
USERNAME="avardhineni4@gmail.com"
API_KEY="AKCpBrvkRp4gkkQ3BtVzZPNh8pGnZfGEhn411GUeatAKHPRExdgPZVxgU2YRTsUsCLNzRBRso"

# Read the latest txt file from /opt/parsejsontxt
latest_txt_file=$(ls -t /opt/parsejsontxt/*.txt 2>/dev/null | head -1)
echo "$latest_txt_file"

# Prompt the user for the repository name
# read -p "Enter the repository name: " userInput

# Convert the input to lowercase and replace underscores with hyphens
REPO_NAME=$(cat "$latest_txt_file" | grep  -m 1 "New Repository Name:" | cut -d ':' -f 2 | tr -d ' ' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
echo "Repository name in lowercase: $REPO_NAME"

# Prompt the user for the package type
# read -p "Enter the package type (e.g., maven, npm, docker): " PACKAGE_TYPE
PACKAGE_TYPE=$(cat "$latest_txt_file" | grep -o "Package Type: [[:alnum:]]*" | cut -d ' ' -f 3)
echo "The Package type is: $PACKAGE_TYPE"

# Prompt the user for the repository class
# read -p "Enter the repository class (e.g., local, remote, virtual): " RCLASS
RCLASS=$(cat "$latest_txt_file" | grep -m 1 "Type of Repository:" | cut -d ':' -f 2 | tr '[:upper:]' '[:lower:]' | tr -d ' ')
echo "The Repository Class is: $RCLASS"

# Initialize URL to an empty string
URL=$(cat "$latest_txt_file" | grep "URL:" | cut -d ' ' -f 2)
echo "The URL value is: $URL"

# Conditionally prompt for URL if the repository class is "remote"
#if [ "$RCLASS" == "remote" ]; then
#  read -p "Enter the remote repository URL: " URL
#fi

if [ -z "$latest_txt_file" ]; then
  echo "No text files found in /opt/parsejsontxt."
  exit 1
fi

# Apply the 'sed' command to extract lines 4 to 6 from the latest text file
#description=$(sed -n '4,6p' "$latest_txt_file")

repository_poc=$(cat "$latest_txt_file" | grep "Repository POC:" | cut -d ':' -f 2 | sed 's/,$//' | sed 's/^ *//')
echo "Repository POC: $repository_poc"

# Extract inclusion and exclusion rules
INCLUSION_RULES=$(cat "$latest_txt_file" | grep "Inclusion Rules:" | cut -d ':' -f 2 | tr -d ' ')
EXCLUSION_RULES=$(cat "$latest_txt_file" | grep "Exclusion Rules:" | cut -d ':' -f 2 | tr -d ' ')

# Extract repository and default local repo values
REPOSITORIES=$(cat "$latest_txt_file" | grep "Repositories:" | cut -d ':' -f 2 | tr -d ' ')
DEFAULT_LOCAL_REPO=$(cat "$latest_txt_file" | grep "Default Local Repo:" | cut -d ':' -f 2 | tr -d ' ')

# Convert the comma-separated list to an array
IFS=',' read -ra REPO_ARRAY <<< "$REPOSITORIES"

# Join the array elements with a comma to create a JSON-friendly string
# REPO_LIST=$(IFS=, ; echo "${REPO_ARRAY[*]}")

# JSON payload for repository creation with the extracted information
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
if [ -f "$latest_txt_file" ] && grep -q "Anonymous Read-Only Access: Yes" "$latest_txt_file"; then
    # Retrieve permission target
    PERMISSION_TARGET=$(curl -u "$USERNAME:$API_KEY" -X GET "$ARTIFACTORY_URL/api/v2/security/permissions/anonymous-read-only-prod")
    echo "$PERMISSION_TARGET"
    # Extract existing repositories from the permission target
    EXISTING_REPOS=$(echo "$PERMISSION_TARGET" | jq -r '.repo.repositories | map(select(. != null) | tostring) | join(", ")')
    echo "$EXISTING_REPOS"
    # Extract REPO_NAME from the latest txt file
    REPO_NAME=$(cat "$latest_txt_file" | grep -m 1 "New Repository Name:" | cut -d ':' -f 2 | tr -d ' ' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    echo "$REPO_NAME"
    # Append the new repository name to the existing repositories
    NEW_REPOS=($EXISTING_REPOS "$REPO_NAME")
    NEW_REPOS_STRING=$(printf "\"%s\"," "${NEW_REPOS[@]}")
    NEW_REPOS_STRING="[${NEW_REPOS_STRING%,}]"
    echo "$NEW_REPOS_STRING"
    # Store the updated repositories list in a file
    echo "$NEW_REPOS_STRING" > /opt/ara/repositories_list.txt
    # Print the updated repositories list
    echo "Updated Repositories List: $NEW_REPOS_STRING"
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
            "repositories": '"$NEW_REPOS_STRING"',
            "include-patterns": [
                "**"
            ],
            "exclude-patterns": [
            ]
        }
    }'
fi