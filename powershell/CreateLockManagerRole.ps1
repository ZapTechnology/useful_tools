Param(
    [Parameter(Mandatory = $True)]
    [String]$SubscriptionId
)

Write-Host "Creating Lock Manager custom role for subcription '$SubscriptionId'..."
Select-AzureRmSubscription -SubscriptionId $SubscriptionId
$perms = 'Microsoft.Authorization/locks/*'

$roleName = "Lock Manager"
$role = Get-AzureRmRoleDefinition -Name $roleName
if ($role -eq $null) {
    $role = [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition]::new()
    $role.Name = $roleName
    $role.Description = 'Can manage resource locks.'
    $role.IsCustom = $true
}
$role.Actions = $perms
$role.AssignableScopes = @("/subscriptions/$SubscriptionId")
if ($role.Id -eq $null) 
{
    New-AzureRmRoleDefinition -Role $role
}
else 
{
    Set-AzureRmRoleDefinition -Role $role
}
Write-Host "Lock Manager custom role created"