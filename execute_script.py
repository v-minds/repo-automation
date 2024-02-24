import os

my_secret = os.environ.get("MY_VARIABLE")

# Use the secret in your script
print(f"Your secret is: {my_secret}")
