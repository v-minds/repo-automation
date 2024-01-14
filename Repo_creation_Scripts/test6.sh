#!/bin/bash

# Artifactory server URL
ARTIFACTORY_URL="https://vminds.jfrog.io/artifactory"

# Artifactory username and password (replace with your credentials)
USERNAME="avardhineni4@gmail.com"
API_KEY="AKCpBrvkRp4gkkQ3BtVzZPNh8pGnZfGEhn411GUeatAKHPRExdgPZVxgU2YRTsUsCLNzRBRso"

# Set the path to the new input file
input_file="inputs.txt"

# Check if the file exists and Anonymous Read-Only Access is Yes
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
