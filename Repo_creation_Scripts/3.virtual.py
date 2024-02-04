#!/usr/bin/env python3.11
import os
import re
import json
import requests

# Artifactory server URL
ARTIFACTORY_URL = "https://nnv.jfrog.io/artifactory"
# Artifactory username and password (replace with your credentials)
USERNAME = "avardhineni2@gmail.com"
API_KEY = "AKCpBrw54cFb31CoBkJRBYVET7ewRsPiskAbF4NdhmGGSzdUJaKGPP7p9MFe9BrK3H1d7cs14"
# Set the path to the new input file
yaml_file = "inputs.yml"

# Read the repository inputs from the YAML input file
with open(yaml_file, 'r') as file:
    yaml_content = file.read()

# Read the value of "New Repository Name" from the YAML file, excluding comments and convert to lowercase
repo_name = next(line.split(':')[-1].strip().lower() for line in yaml_content.split('\n') if not line.startswith('#') and 'New Repository Name:' in line)

# Read the value of "Anonymous Read-Only Access" from the YAML file, excluding comments
anonymous_readonly_access = next(re.search(r'Anonymous Read-Only Access:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Anonymous Read-Only Access:' in line)

# Read the value of "Repository POC" from the YAML file, excluding comments
repository_poc = next(re.search(r'Repository POC:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Repository POC:' in line)

# Read the value of "Type of Repository" from the YAML file, excluding comments
repository_type = next(re.search(r'Type of Repository:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Type of Repository:' in line)

# Read the value of "URL" from the YAML file, excluding comments
repository_url = next(re.search(r'URL:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'URL:' in line)

# Read the value of "Inclusion Rules" from the YAML file, excluding comments
inclusion_rules = next(re.search(r'Inclusion Rules:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Inclusion Rules:' in line)

# Read the value of "Exclusion Rules" from the YAML file, excluding comments
exclusion_rules = next(re.search(r'Exclusion Rules:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Exclusion Rules:' in line)

# Read the value of "Repositories" from the YAML file, excluding comments
repositories = next(re.search(r'Repositories:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Repositories:' in line)

# Read the value of "Default Local Repo" from the YAML file, excluding comments
default_local_repo = next(re.search(r'Default Local Repo:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Default Local Repo:' in line)

# Read the value of "Package Type" from the YAML file, excluding comments
package_type = next(re.search(r'Package Type:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Package Type:' in line)

# Read the value of "terraformType" from the YAML file, excluding comments
terraform_type = next(re.search(r'terraformType:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'terraformType:' in line)

# Read the value of "Repository Location" from the YAML file, excluding comments
repository_location = next(re.search(r'Repository Location:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Repository Location:' in line)

# Convert the comma-separated list to an array
repo_array = [repo.strip() for repo in repositories.split(',')]

print(f"Repository Name: {repo_name}")
print(f"Anonymous Read-Only Access: {anonymous_readonly_access}")
print(f"Repository POC: {repository_poc}")
print(f"Type of Repository: {repository_type}")
print(f"URL: {repository_url}")
print(f"Inclusion Rules: {inclusion_rules}")
print(f"Exclusion Rules: {exclusion_rules}")
print(f"Repositories: {repo_array}")
print(f"Default Local Repo: {default_local_repo}")
print(f"Package Type: {package_type}")
print(f"terraformType: {terraform_type}")
print(f"Repository Location: {repository_location}")

# Construct repository names
local_repo_name = f"{repo_name}-local"
virtual_repo_name = f"{repo_name}-virtual"

# JSON payload for local repository creation
local_repo_json = {
            "key": local_repo_name,
            "rclass": "local",
            "url": repository_url,
            "packageType": package_type,
            "description": repository_poc,
            "includesPattern": inclusion_rules,
            "excludesPattern": exclusion_rules,
            "repositories": repo_array,
            "defaultDeploymentRepo": default_local_repo,
            "repoLayoutRef": "simple-default"
        }

# Convert dictionary to JSON string
repo_json_str = json.dumps(local_repo_json, indent=2)
print(f"JSON Payload: {repo_json_str}")

# JSON payload for virtual repository creation
virtual_repo_json = {
            "key": virtual_repo_name,
            "rclass": "virtual",
            "url": repository_url,
            "packageType": package_type,
            "description": repository_poc,
            "includesPattern": inclusion_rules,
            "excludesPattern": exclusion_rules,
            "repositories": [local_repo_name],
            "defaultDeploymentRepo": local_repo_name,
            "repoLayoutRef": "simple-default"
        }

# Convert dictionary to JSON string
repo_json_str1 = json.dumps(virtual_repo_json, indent=2)
print(f"JSON Payload: {repo_json_str1}")

# Function to create a repository using the Artifactory REST API
def create_repo(repo_name, repo_json):
    url = f"{ARTIFACTORY_URL}/api/repositories/{repo_name}"
    headers = {"Content-Type": "application/json"}
    auth = (USERNAME, API_KEY)

    response = requests.put(url, headers=headers, auth=auth, json=json.loads(repo_json))

    if "error" in response.text:
        print(f"Error creating repository '{repo_name}': {response.text}")
        exit(1)
    else:
        print(f"Repository '{repo_name}' created successfully.")

# Create Artifactory URLs based on the repository location
repository_location = "AU"  # replace with your actual repository location
if repository_location == "US":
    ARTIFACTORY_URL = "https://nnv.jfrog.io/artifactory"
elif repository_location == "EMEA":
    ARTIFACTORY_URL = "https://nnv.jfrog.io/artifactory"
elif repository_location == "AU":
    ARTIFACTORY_URL = "https://nnv.jfrog.io/artifactory"
else:
    print(f"Unknown repository location: {repository_location}")
    exit(1)

# Main script execution
create_repo(local_repo_name, json.dumps(local_repo_json, indent=2))
create_repo(virtual_repo_name, json.dumps(virtual_repo_json, indent=2))

# Create a JSON-friendly string for permission target
permission_json = json.dumps({
    "name": local_repo_name,
    "repo": {
        "actions": {
            "users": {user.strip(): ["read", "manage"] for user in repository_poc.split(",")},
        },
        "repositories": [local_repo_name],
        "include-patterns": ["**"],
        "exclude-patterns": [],
    }
}, indent=2)

# Print the generated permission target JSON
print(f"Permission Target JSON:\n{permission_json}")

# Function to create a permission target using the Artifactory REST API
def create_permission_target():
    url = f"{ARTIFACTORY_URL}/api/v2/security/permissions/{local_repo_name}"
    headers = {
        "Content-Type": "application/json",
    }
    auth = (USERNAME, API_KEY)

    response = requests.put(url, headers=headers, auth=auth, data=permission_json)

    if "error" in response.text:
        print(f"Error creating permission target: {response.text}")
        exit(1)  # Exit the script if permission target creation fails
    else:
        print(f"Permission target '{local_repo_name}' created successfully.")

# Main script execution
create_permission_target()  # Attempt to create the permission target

