#!/usr/bin/env python3
import os
import re
import json
import requests

my_secret = os.environ.get("MY_VARIABLE")

# Use the secret in your script
print(f"Your secret is: {my_secret}")

# Artifactory server URL
ARTIFACTORY_URL = "https://vnn.jfrog.io/artifactory"
# Artifactory username and password (replace with your credentials)
USERNAME = "avardhineni1@gmail.com"
my_secret = os.environ.get("MY_VARIABLE")
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


# Check if the package type is terraform
if package_type == "terraform":
    terraform_type = terraform_type
    repo_json = {
        "key": repo_name,
        "rclass": repository_type,
        "url": repository_url,
        "packageType": package_type,
        "terraformType": terraform_type,
        "description": repository_poc,
        "includesPattern": inclusion_rules,
        "excludesPattern": exclusion_rules,
        "repositories": repo_array,
        "defaultDeploymentRepo": default_local_repo,
        "repoLayoutRef": "simple-default"
    }
else:
    # JSON payload for repository creation without terraformType
    repo_json = {
        "key": repo_name,
        "rclass": repository_type,
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
repo_json_str = json.dumps(repo_json, indent=2)
print(f"JSON Payload: {repo_json_str}")

# Function to create a local repository using the Artifactory REST API
def create_repo():
    url = f"{ARTIFACTORY_URL}/api/repositories/{repo_name}"
    headers = {
        "Content-Type": "application/json",
    }
    auth = (USERNAME, my_secret)
    
    response = requests.put(url, headers=headers, auth=auth, json=repo_json)
    
    if "error" in response.text:
        print(f"Error creating repository: {response.text}")
        exit(1)  # Exit the script if repository creation fails
    else:
        print(f"Repository '{repo_name}' created successfully.")
        
        # Check if the repository class is "local" and set the storage quota
        if repository_type == "local":
            quota_url = f"{ARTIFACTORY_URL}/api/storage/{repo_name}?properties=repository.path.quota=107374182400"
            quota_response = requests.put(quota_url, auth=auth)
            
            if "error" in quota_response.text:
                print(f"Error setting storage quota for the local repository: {quota_response.text}")
            else:
                print(f"Storage quota set for the local repository '{repo_name}'.")

# Create Artifactory URLs based on the repository location
if repository_location == "US":
    ARTIFACTORY_URL = "https://nv.jfrog.io/artifactory"
elif repository_location == "EMEA":
    ARTIFACTORY_URL = "https://nn.jfrog.io/artifactory"
elif repository_location == "AU":
    ARTIFACTORY_URL = "https://vnn.jfrog.io/artifactory"
else:
    print(f"Unknown repository location: {repository_location}")
    exit(1)

# Main script execution
create_repo()  # Attempt to create the repository

# Create a JSON-friendly string for permission target
permission_json = json.dumps({
    "name": repo_name,
    "repo": {
        "actions": {
            "users": {user.strip(): ["read", "manage"] for user in repository_poc.split(",")},
        },
        "repositories": [repo_name],
        "include-patterns": ["**"],
        "exclude-patterns": [],
    }
}, indent=2)

# Print the generated permission target JSON
print(f"Permission Target JSON:\n{permission_json}")

# Function to create a permission target using the Artifactory REST API
def create_permission_target():
    url = f"{ARTIFACTORY_URL}/api/v2/security/permissions/{repo_name}"
    headers = {
        "Content-Type": "application/json",
    }
    auth = (USERNAME, my_secret)

    response = requests.put(url, headers=headers, auth=auth, data=permission_json)

    if "error" in response.text:
        print(f"Error creating permission target: {response.text}")
        exit(1)  # Exit the script if permission target creation fails
    else:
        print(f"Permission target '{repo_name}' created successfully.")

# Main script execution
create_permission_target()  # Attempt to create the permission target


# Check if the file exists and Anonymous Read-Only Access is Yes
if os.path.exists(yaml_file) and anonymous_readonly_access.lower() == "yes" and repository_type != "virtual":
    # Retrieve permission target
    permission_target_url = f"{ARTIFACTORY_URL}/api/v2/security/permissions/anonymous-read-only-prod"
    permission_target = requests.get(permission_target_url, auth=(USERNAME, my_secret)).json()

    print(json.dumps(permission_target, indent=2))  # Display permission target

    # Extract existing repositories from the permission target
    existing_repos = permission_target["repo"]["repositories"]
    existing_repos_str = ', '.join(f'"{repo}"' for repo in existing_repos)
    print(existing_repos_str)

    # Append the new repository name to the existing repositories
    new_repos = existing_repos + [repo_name]
    new_repos_str = ', '.join(f'"{repo}"' for repo in new_repos)
    print(new_repos_str)

    # Store the updated repositories list in the same directory as the script
    repositories_list_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "repositories_list.txt")
    with open(repositories_list_path, 'w') as file:
        file.write(new_repos_str)

    # Print the updated repositories list
    print(f"Updated Repositories List: {new_repos_str}")

    # Update the permission target with the new repositories list
    update_permission_target_url = f"{ARTIFACTORY_URL}/api/v2/security/permissions/anonymous-read-only-prod"
    update_permission_target_payload = {
        "name": "anonymous-read-only-prod",
        "repo": {
            "actions": {
                "users": {
                    "anonymous": ["read"]
                }
            },
            "repositories": new_repos,
            "include-patterns": ["**"],
            "exclude-patterns": []
        }
    }

    update_permission_target_headers = {
        "Content-Type": "application/json",
    }

    update_permission_target_response = requests.put(update_permission_target_url,
                                                     headers=update_permission_target_headers,
                                                     auth=(USERNAME, my_secret),
                                                     json=update_permission_target_payload)

    if "error" in update_permission_target_response.text:
        print(f"Error updating permission target: {update_permission_target_response.text}")
        exit(1)  # Exit the script if permission target update fails
    else:
        print(f"Permission target 'anonymous-read-only-prod' updated successfully.")

# Check if the package type is docker
if package_type == "docker":
    # Display the registry URL based on the repository name
    registry_url = f"{repo_name}.docker.artifactory.viasat.com"
    print(f"Registry URL: {registry_url}")


