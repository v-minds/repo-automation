#!/bin/bash

# Artifactory server URL
ARTIFACTORY_URL="https://nnv.jfrog.io/artifactory"

# Artifactory username and password (replace with your credentials)
USERNAME="avardhineni2@gmail.com"
API_KEY="AKCpBrw54cFb31CoBkJRBYVET7ewRsPiskAbF4NdhmGGSzdUJaKGPP7p9MFe9BrK3H1d7cs14"

# Set the path to the new input file
yaml_file="inputs.yml"

# Read the repository inputs from the YAML input file

# Read the value of "New Repository Name" from the YAML file, excluding comments and convert to lowercase
repo_name=$(awk '!/^#/ && /New Repository Name:/ {sub(/Name:/, "", $NF); print $NF}' "$yaml_file" | tr '[:upper:]' '[:lower:]')

# Read the value of "Anonymous Read-Only Access" from the YAML file, excluding comments
anonymous_readonly_access=$(awk '!/^#/ && /Anonymous Read-Only Access:/ {sub(/Anonymous Read-Only Access:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "Repository POC" from the YAML file, excluding comments
repository_poc=$(awk '!/^#/ && /Repository POC:/ {sub(/Repository POC:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "Type of Repository" from the YAML file, excluding comments
repository_type=$(awk '!/^#/ && /Type of Repository:/ {sub(/Type of Repository:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "URL" from the YAML file, excluding comments
repository_url=$(awk '!/^#/ && /URL:/ {sub(/URL:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "Inclusion Rules" from the YAML file, excluding comments
inclusion_rules=$(awk '!/^#/ && /Inclusion Rules:/ {sub(/Inclusion Rules:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "Exclusion Rules" from the YAML file, excluding comments
exclusion_rules=$(awk '!/^#/ && /Exclusion Rules:/ {sub(/Exclusion Rules:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "Repositories" from the YAML file, excluding comments
repositories=$(awk '!/^#/ && /Repositories:/ {sub(/Repositories:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "Default Local Repo" from the YAML file, excluding comments
default_local_repo=$(awk '!/^#/ && /Default Local Repo:/ {sub(/Default Local Repo:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "Package Type" from the YAML file, excluding comments
package_type=$(awk '!/^#/ && /Package Type:/ {sub(/Package Type:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "terraformType" from the YAML file, excluding comments
terraform_type=$(awk '!/^#/ && /terraformType:/ {sub(/terraformType:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Read the value of "Repository Location" from the YAML file, excluding comments
repository_location=$(awk '!/^#/ && /Repository Location:/ {sub(/Repository Location:/, "", $0); print $0}' "$yaml_file" | tr -d '[:space:]')

# Convert the comma-separated list to an array
IFS=',' read -ra REPO_ARRAY <<< "$repositories"

# Check if the package type is helm
if [ "$package_type" = "helm" ]; then
    # Check if the repository class is local or virtual
    if [[ "$repository_type" == "local" || "$repository_type" == "virtual" ]]; then
        # Append -local to local repo type
        local_repo_name="${repo_name}-local"
        # JSON payload for local repository creation
        local_repo_json='{
            "key": "'"$local_repo_name"'",
            "rclass": "local",
            "url": "'"$repository_url"'",
            "packageType": "'"$package_type"'",
            "description": "'"$repository_poc"'",
            "includesPattern": "'"$inclusion_rules"'",
            "excludesPattern": "'"$exclusion_rules"'",
            "repositories": '"$(printf '%s\n' "${REPO_ARRAY[@]}" | jq -R -s -c 'split("\n")[:-1]')"',
            "defaultDeploymentRepo": "'"$default_local_repo"'",
            "repoLayoutRef": "'"simple-default"'"
        }'
        echo "JSON Payload for Local Repository: $local_repo_name"
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
                # Check if the repository class is "local" and set the storage quota
                if [ "$repository_type" == "local" ]; then
                    quota_response=$(curl -u "$USERNAME:$API_KEY" -X PUT "$ARTIFACTORY_URL/api/storage/$local_repo_name?properties=repository.path.quota=107374182400")
                    if [[ $quota_response == *"error"* ]]; then
                        echo "Error setting storage quota for the local repository: $quota_response"
                    else
                        echo "Storage quota set for the local repository '$local_repo_name'."
                    fi
                fi
            fi
        }

        # Create Artifactory URLs based on the repository location
        case $repository_location in
          "US")
            ARTIFACTORY_URL="https://nnv.jfrog.io/artifactory"
            ;;
          "EMEA")
            ARTIFACTORY_URL="https://nnv.jfrog.io/artifactory"
            ;;
          "AU")
            ARTIFACTORY_URL="https://nnv.jfrog.io/artifactory"
            ;;
          *)
            echo "Unknown repository location: $repository_location"
            exit 1
            ;;
        esac

        # Main script execution
        create_local_repo  # Attempt to create the local repository
    fi
    # Append -virtual to virtual repo type
    virtual_repo_name="${repo_name}-virtual"
    # JSON payload for virtual repository creation
    virtual_repo_json='{
        "key": "'"$virtual_repo_name"'",
        "rclass": "virtual",
        "url": "'"$repository_url"'",
        "packageType": "'"$package_type"'",
        "description": "'"$repository_poc"'",
        "includesPattern": "'"$inclusion_rules"'",
        "excludesPattern": "'"$exclusion_rules"'",
        "repositories": ["'"$local_repo_name"'"],
        "defaultDeploymentRepo": "'"$local_repo_name"'",
        "repoLayoutRef": "'"simple-default"'"

    }'
    echo "JSON Payload for Virtual Repository: $virtual_repo_name"
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

    # Create Artifactory URLs based on the repository location
    case $repository_location in
      "US")
        ARTIFACTORY_URL="https://nnv.jfrog.io/artifactory"
        ;;
      "EMEA")
        ARTIFACTORY_URL="https://nnv.jfrog.io/artifactory"
        ;;
      "AU")
        ARTIFACTORY_URL="https://nnv.jfrog.io/artifactory"
        ;;
      *)
        echo "Unknown repository location: $repository_location"
        exit 1
        ;;
    esac

    # Main script execution
    create_virtual_repo  # Attempt to create the virtual repository
fi

# Create a JSON-friendly string for Local Repository permission target
PERMISSION_JSON1='{
  "name": "'"$local_repo_name"'",
  "repo": {
    "actions": {
      "users": {
        '"$(awk -v RS=, -v ORS=, '{print "\"" $1 "\": [\"read\", \"manage\"]"}' <<< "$repository_poc" | sed 's/,$//')"'
      }
    },
    "repositories": ["'"$local_repo_name"'"],
    "include-patterns": ["**"],
    "exclude-patterns": []
  }
}'
# Print the generated permission target JSON
echo "Permission Target JSON: $PERMISSION_JSON"
# Function to create a permission target using the Artifactory REST API
create_permission_target_local() {
  local response
  response=$(curl -u "$USERNAME:$API_KEY" -X PUT -H "Content-Type: application/json" \
    "$ARTIFACTORY_URL/api/v2/security/permissions/$local_repo_name" -d "$PERMISSION_JSON1"
  )
  if [[ $response == *"error"* ]]; then
    echo "Error creating permission target: $response"
    exit 1  # Exit the script if permission target creation fails
  else
    echo "Permission target '$local_repo_name' created successfully."
  fi
}
# Main script execution
create_permission_target_local  # Attempt to create the permission target

# Additional checks or actions can be added here

# Check if the package type is helm
if [ "$package_type" = "helm" ]; then
    # Check if the repository class is local or virtual
    if [ "$repository_type" == "local" ]; then
        # Append -local to local repo type
        #LOCAL_REPO_NAME="${REPO_NAME}-local"
        # Check additional conditions
        # if [ -f "$input_file" ] && grep -q "Anonymous Read-Only Access: Yes" "$input_file" && ! grep -q "Type of Repository: virtual" "$input_file" && grep -q "Anonymous Read-Only Access: Yes" "$input_file"; then
        if [ -f "$yaml_file" ] && [ "$anonymous_readonly_access" = "yes" ] && [ "$repository_type" != "virtual" ]; then
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

