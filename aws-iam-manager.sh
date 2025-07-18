#!/bin/bash
#
# Script Name: aws-iam-manager.sh
# Purpose: Automates the creation of AWS IAM users and an 'admin' group,
#          assigns AdministratorAccess to the group, and adds users to it.

# Pre-requisites:
#   - AWS CLI installed and configured with appropriate IAM permissions.
#   - Basic Linux shell scripting knowledge.

# --- Global Configuration ---
# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The exit status of a pipeline is the exit status of the last command to exit with a non-zero status.
set -euo pipefail

# Define the names of the IAM users to be created in an array.
iam_users=("adedeji" "michael" "lateef" "mercy" "hammed")

# Define the name of the IAM group for administrators.
admin_group_name="admin"

# Define the ARN (Amazon Resource Name) for the AWS-managed AdministratorAccess policy.
# This policy grants full access to AWS services and resources.
admin_policy_arn="arn:aws:iam::aws:policy/AdministratorAccess"

# --- Functions ---

# Function to create an IAM group if it does not already exist.
# Arguments: $1 = group_name
create_iam_group() {
    local group_name="$1"
    echo "Checking if IAM group '$group_name' exists..."

    # Use 'aws iam get-group' to check for group existence.
    # Redirect stdout and stderr to /dev/null to suppress output for the check.
    if aws iam get-group --group-name "$group_name" &>/dev/null; then
        echo "IAM group '$group_name' already exists. Skipping creation."
    else
        echo "IAM group '$group_name' does not exist. Creating..."
        # Use 'aws iam create-group' to create the group.
        if aws iam create-group --group-name "$group_name"; then
            echo "Successfully created IAM group '$group_name'."
        else
            echo "ERROR: Failed to create IAM group '$group_name'." >&2
            return 1 # Indicate failure
        fi
    fi
    return 0 # Indicate success
}

# Function to attach an AWS-managed policy to an IAM group.
# Arguments: $1 = group_name, $2 = policy_arn
attach_policy_to_group() {
    local group_name="$1"
    local policy_arn="$2"
    echo "Checking if policy '$policy_arn' is attached to group '$group_name'..."

    # Use 'aws iam list-attached-group-policies' to check for policy attachment.
    # Filter by policy ARN and check if any output is returned.
    if aws iam list-attached-group-policies --group-name "$group_name" --query "AttachedPolicies[?PolicyArn=='$policy_arn']" --output text | grep -q "$policy_arn"; then
        echo "Policy '$policy_arn' is already attached to group '$group_name'. Skipping attachment."
    else
        echo "Policy '$policy_arn' is not attached to group '$group_name'. Attaching..."
        # Use 'aws iam attach-group-policy' to attach the policy.
        if aws iam attach-group-policy --group-name "$group_name" --policy-arn "$policy_arn"; then
            echo "Successfully attached policy '$policy_arn' to group '$group_name'."
        else
            echo "ERROR: Failed to attach policy '$policy_arn' to group '$group_name'." >&2
            return 1 # Indicate failure
        fi
    fi
    return 0 # Indicate success
}

# Function to create an IAM user if they do not already exist.
# Arguments: $1 = user_name
create_iam_user() {
    local user_name="$1"
    echo "Checking if IAM user '$user_name' exists..."

    # Use 'aws iam get-user' to check for user existence.
    # Redirect stdout and stderr to /dev/null to suppress output for the check.
    if aws iam get-user --user-name "$user_name" &>/dev/null; then
        echo "IAM user '$user_name' already exists. Skipping creation."
    else
        echo "IAM user '$user_name' does not exist. Creating..."
        # Use 'aws iam create-user' to create the user.
        if aws iam create-user --user-name "$user_name"; then
            echo "Successfully created IAM user '$user_name'."
        else
            echo "ERROR: Failed to create IAM user '$user_name'." >&2
            return 1 # Indicate failure
        fi
    fi
    return 0 # Indicate success
}

# Function to add an IAM user to an IAM group.
# Arguments: $1 = user_name, $2 = group_name
add_user_to_group() {
    local user_name="$1"
    local group_name="$2"
    echo "Checking if IAM user '$user_name' is already in group '$group_name'..."

    # Use 'aws iam get-group' and 'jq' to check if the user is already a member.
    # 'jq' is a powerful JSON processor, often used with AWS CLI output.
    # If jq is not installed, this check will fail. A simpler check could be done
    # by parsing text output, but jq is more robust for JSON.
    if aws iam get-group --group-name "$group_name" --query "Users[?UserName=='$user_name']" --output text | grep -q "$user_name"; then
        echo "IAM user '$user_name' is already a member of group '$group_name'. Skipping addition."
    else
        echo "IAM user '$user_name' is not in group '$group_name'. Adding..."
        # Use 'aws iam add-user-to-group' to add the user.
        if aws iam add-user-to-group --user-name "$user_name" --group-name "$group_name"; then
            echo "Successfully added IAM user '$user_name' to group '$group_name'."
        else
            echo "ERROR: Failed to add IAM user '$user_name' to group '$group_name'." >&2
            return 1 # Indicate failure
        fi
    fi
    return 0 # Indicate success
}

# --- Main Script Execution ---

echo "--- Starting AWS IAM Management Script ---"

# Objective 3: Define and call a function to create an IAM group named "admin"
echo -e "\nStep 1: Creating IAM Group '$admin_group_name'..."
if ! create_iam_group "$admin_group_name"; then
    echo "FATAL: Group creation failed. Exiting." >&2
    exit 1
fi

# Objective 4: Attach an AWS-managed administrative policy to the "admin" group
echo -e "\nStep 2: Attaching policy '$admin_policy_arn' to group '$admin_group_name'..."
if ! attach_policy_to_group "$admin_group_name" "$admin_policy_arn"; then
    echo "FATAL: Policy attachment failed. Exiting." >&2
    exit 1
fi

# Objective 2 & 5: Create IAM Users and assign each user to the "admin" group
echo -e "\nStep 3: Creating IAM Users and adding them to group '$admin_group_name'..."
for user in "${iam_users[@]}"; do
    echo -e "\nProcessing user: $user"
    if ! create_iam_user "$user"; then
        echo "WARNING: Failed to create user '$user'. Skipping adding to group." >&2
        continue # Continue to next user even if one fails
    fi
    if ! add_user_to_group "$user" "$admin_group_name"; then
        echo "WARNING: Failed to add user '$user' to group '$admin_group_name'." >&2
        # Continue even if adding to group fails for one user
    fi
done

echo -e "\n--- AWS IAM Management Script Finished ---"
echo "Please verify the IAM users and group in the AWS Management Console."
echo "Remember to set initial passwords and/or generate access keys for new users as needed."

