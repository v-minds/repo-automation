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
REPO_NAME=$(awk '!/^#/ && /New Repository Name:/ {sub(/Name:/, "", $NF); print $NF}' "$yaml_file" | tr '[:upper:]' '[:lower:]')

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
IFS=',' read -ra REPO_ARRAY <<< "$REPOSITORIES"

# Construct repository names
local_repo_name="${REPO_NAME}-local"
virtual_repo_name="${REPO_NAME}-virtual"

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
    "defaultDeploymentRepo": "'"$default_local_repo"'"
}'

echo "JSON Payload for Local Repository: $local_repo_json"

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
    "defaultDeploymentRepo": "'"$local_repo_name"'"
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
create_repo "$local_repo_name" "$local_repo_json"  # Attempt to create the local repository

create_repo "$virtual_repo_name" "$virtual_repo_json"  # Attempt to create the virtual repository

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





