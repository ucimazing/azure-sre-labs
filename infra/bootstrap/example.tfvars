# Copy to terraform.tfvars (gitignored, because it holds your email) and fill in.
# Get the IDs after logging in to the NEW account:  az account show --query '{sub:id,tenant:tenantId,user:user.name}'
subscription_id = "00000000-0000-0000-0000-000000000000"
tenant_id       = "00000000-0000-0000-0000-000000000000"
expected_user   = "you@example.com" # the new account's login
alert_email     = "you@example.com"
budget_amount   = 50 # per month, billing currency (USD on a $200 trial). 0 = no budget
