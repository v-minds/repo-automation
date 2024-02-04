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

# Check if the package type is helm
if package_type == "helm":
    # Check if the repository class is local or virtual
    if repository_type == "local" or repository_type == "virtual":
        # Append -local to local repo type
        local_repo_name = f"{repo_name}-local"

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

        # Function to create a local repository using the Artifactory REST API
        def create_local_repo():
            url = f"{ARTIFACTORY_URL}/api/repositories/{local_repo_name}"
            headers = {
                "Content-Type": "application/json",
            }
            auth = (USERNAME, API_KEY)

            response_local = requests.put(url, headers=headers, auth=auth, json=local_repo_json)

            if "error" in response_local.text:
                print(f"Error creating local repository: {response_local.text}")
                exit(1)
            else:
                print(f"Local Repository '{local_repo_name}' created successfully.")

                # Check if the repository class is "local" and set the storage quota
                if repository_type == "local":
                    quota_url = f"{ARTIFACTORY_URL}/api/storage/{local_repo_name}?properties=repository.path.quota=107374182400"
                    quota_response = requests.put(quota_url, auth=auth)

                    if "error" in quota_response.text:
                        print(f"Error setting storage quota for the local repository: {quota_response.text}")
                    else:
                        print(f"Storage quota set for the local repository '{local_repo_name}'.")

        # Determine Artifactory URLs based on the repository location
        if repository_location == "US":
            ARTIFACTORY_URL = "https://nv.jfrog.io/artifactory"
        elif repository_location == "EMEA":
            ARTIFACTORY_URL = "https://nn.jfrog.io/artifactory"
        elif repository_location == "AU":
            ARTIFACTORY_URL = "https://nnv.jfrog.io/artifactory"
        else:
            print(f"Unknown repository location: {repository_location}")
            exit(1)

        # Call the function to create a local repository
        create_local_repo()

        # Append -virtual to virtual repo type
        virtual_repo_name = f"{repo_name}-virtual"

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

        print(f"JSON Payload for Virtual Repository: {virtual_repo_name}")

        # Function to create a virtual repository using the Artifactory REST API
        def create_virtual_repo():
            url = f"{ARTIFACTORY_URL}/api/repositories/{virtual_repo_name}"
            headers = {
                "Content-Type": "application/json",
            }
            auth = (USERNAME, API_KEY)
            response_virtual = requests.put(url, headers=headers, auth=auth, json=virtual_repo_json)
            if response_virtual.status_code != 200:
                print(f"Error creating virtual repository: {response_virtual.text}")
                exit(1)
            else:
                print(f"Virtual Repository '{virtual_repo_name}' created successfully.")

        # Determine Artifactory URLs based on the repository location
        if repository_location == "US":
            ARTIFACTORY_URL = "https://nv.jfrog.io/artifactory"
        elif repository_location == "EMEA":
            ARTIFACTORY_URL = "https://nn.jfrog.io/artifactory"
        elif repository_location == "AU":
            ARTIFACTORY_URL = "https://nnv.jfrog.io/artifactory"
        else:
            print(f"Unknown repository location: {repository_location}")
            exit(1)

        # Main script execution
        create_virtual_repo()

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

# Add the condition to check if the package type is helm
if package_type == "helm":
    # Check if the repository class is local
    if repository_type == "local":
    # Check if the file exists and Anonymous Read-Only Access is Yes
        if os.path.exists(yaml_file) and anonymous_readonly_access.lower() == "yes" and repository_type != "virtual":
            # Retrieve permission target
            permission_target_url = f"{ARTIFACTORY_URL}/api/v2/security/permissions/anonymous-read-only-prod"
            permission_target = requests.get(permission_target_url, auth=(USERNAME, API_KEY)).json()

            print(json.dumps(permission_target, indent=2))  # Display permission target

            # Extract existing repositories from the permission target
            existing_repos = permission_target["repo"]["repositories"]
            existing_repos_str = ', '.join(f'"{repo}"' for repo in existing_repos)
            print(existing_repos_str)

            # Append the new repository name to the existing repositories
            new_repos = existing_repos + [local_repo_name]
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
                                                            auth=(USERNAME, API_KEY),
                                                            json=update_permission_target_payload)

            if "error" in update_permission_target_response.text:
                print(f"Error updating permission target: {update_permission_target_response.text}")
                exit(1)  # Exit the script if permission target update fails
            else:
                print(f"Permission target 'anonymous-read-only-prod' updated successfully.")
