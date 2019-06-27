Param(
    [Parameter(Mandatory = $True)]
    [String]$TenantId,
    [Parameter(Mandatory = $True)]
    [String[]]$SubscriptionIds
)

Write-Host "Creating Lock Manager custom role for tenant '$TenantId'..."
Set-AzureRmContext -TenantId $TenantId
$perms = 'Microsoft.Authorization/locks/*'

$roleName = "Lock Manager"
$role = (Get-AzureRmRoleDefinition -Scope "/" -Custom | Where-Object Name -eq "Lock Manager")
if ($role -eq $null) {
    $role = [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition]::new()
    $role.Name = $roleName
    $role.Description = 'Can manage resource locks.'
    $role.IsCustom = $true
}
$role.Actions = $perms
$role.AssignableScopes = $SubscriptionIds | % {"/subscriptions/$_"}

if ($role.Id -eq $null) {
    New-AzureRmRoleDefinition -Role $role
}
else {
    Set-AzureRmRoleDefinition -Role $role
}
Write-Host "Lock Manager custom role created"
