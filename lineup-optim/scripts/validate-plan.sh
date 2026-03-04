#!/bin/bash
# validate-plan.sh
# Validates that a Terraform plan only creates new resources and does not
# modify or destroy any existing infrastructure.
#
# Called by the CI/CD pipeline before `terraform apply` to enforce the
# zero-modification guarantee (Requirements 17.1, 17.8, 18.3, 18.7).
#
# Prerequisites: terraform, jq
# Usage: ./scripts/validate-plan.sh [terraform_dir]
#   terraform_dir: optional path to the Terraform directory (defaults to cwd)

set -euo pipefail

TERRAFORM_DIR="${1:-.}"
PLAN_FILE="plan.tfplan"
PLAN_JSON="plan.json"

echo "=== Terraform Plan Zero-Modification Validator ==="
echo "Working directory: ${TERRAFORM_DIR}"

# Change to the Terraform directory
if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "ERROR: Directory '${TERRAFORM_DIR}' does not exist."
  exit 1
fi

# Verify required tools are available
for cmd in terraform jq; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: '${cmd}' is required but not installed."
    exit 1
  fi
done

# Step 1: Run terraform plan and save the binary plan file
echo ""
echo "--- Running terraform plan ---"
terraform -chdir="$TERRAFORM_DIR" plan -out="$PLAN_FILE" -input=false
echo "Plan saved to ${PLAN_FILE}"

# Step 2: Convert the plan to JSON
echo ""
echo "--- Converting plan to JSON ---"
terraform -chdir="$TERRAFORM_DIR" show -json "$PLAN_FILE" > "${TERRAFORM_DIR}/${PLAN_JSON}"
echo "JSON plan saved to ${PLAN_JSON}"

# Step 3: Parse resource_changes and check for disallowed actions
echo ""
echo "--- Validating resource changes ---"

# Allowed actions: "create" and "no-op" only
# Disallowed: "update", "delete", "replace", "read" on managed resources that change
VIOLATIONS=$(jq -r '
  .resource_changes[]?
  | select(.mode == "managed")
  | select(.change.actions | map(select(. != "create" and . != "no-op")) | length > 0)
  | "\(.address) -> actions: \(.change.actions | join(", "))"
' "${TERRAFORM_DIR}/${PLAN_JSON}")

# Step 4: Report results
if [ -n "$VIOLATIONS" ]; then
  echo ""
  echo "ERROR: Terraform plan contains modifications to existing resources!"
  echo "The following resources have non-create/no-op actions:"
  echo ""
  echo "$VIOLATIONS"
  echo ""
  echo "Only 'create' and 'no-op' actions are allowed to protect existing infrastructure."
  echo "Review the plan and ensure no existing resources are being modified or destroyed."

  # Cleanup plan files
  rm -f "${TERRAFORM_DIR}/${PLAN_FILE}" "${TERRAFORM_DIR}/${PLAN_JSON}"
  exit 1
fi

# Count new resources being created
CREATE_COUNT=$(jq '[.resource_changes[]? | select(.mode == "managed") | select(.change.actions == ["create"])] | length' "${TERRAFORM_DIR}/${PLAN_JSON}")
NOOP_COUNT=$(jq '[.resource_changes[]? | select(.mode == "managed") | select(.change.actions == ["no-op"])] | length' "${TERRAFORM_DIR}/${PLAN_JSON}")
TOTAL_CHANGES=$(jq '[.resource_changes[]? | select(.mode == "managed")] | length' "${TERRAFORM_DIR}/${PLAN_JSON}")

echo ""
echo "Validation PASSED"
echo "  Total managed resource changes: ${TOTAL_CHANGES}"
echo "  Resources to create: ${CREATE_COUNT}"
echo "  Resources unchanged (no-op): ${NOOP_COUNT}"
echo "  Modifications to existing resources: 0"
echo ""
echo "All resource changes are safe — only new resources will be created."

# Cleanup plan files
rm -f "${TERRAFORM_DIR}/${PLAN_FILE}" "${TERRAFORM_DIR}/${PLAN_JSON}"
exit 0
