import os
import re

my_secret = os.environ.get("MY_VARIABLE")

# Use the secret in your script
print(f"Your secret is: {my_secret}")

yaml_file = "inputs.yml"

with open(yaml_file, 'r') as file:
    yaml_content = file.read()

package_type = next(re.search(r'Package Type:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Package Type:' in line)
repository_type = next(re.search(r'Type of Repository:\s*([^#\n]*)', line).group(1).strip() for line in yaml_content.split('\n') if not line.startswith('#') and 'Type of Repository:' in line)

if package_type == "helm" and repository_type == "local":
    script_name = "2.helm-local.py"
elif repository_type == "virtual":
    script_name = "3.virtual.py"
elif repository_type == "local" or repository_type == "remote":
    script_name = "1.local-remote.py"
else:
    print("No matching condition found for execution.")
    exit(1)

script_path = os.path.join("Repo_creation_Scripts", script_name)

with open(script_path, 'r') as script_file:
    exec(script_file.read())



