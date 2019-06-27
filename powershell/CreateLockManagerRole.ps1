Param(
    [Parameter(Mandatory = $True)]
    [String]$SubscriptionId
)

Write-Host "Creating Lock Manager custom role for subcription '$SubscriptionId'..."
Select-AzureRmSubscription -SubscriptionId $SubscriptionId
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

if ($role.AssignableScopes -eq $null) {
    $role.AssignableScopes = @("/subscriptions/$SubscriptionId")
}
else {
    if ($role.AssignableScopes.Contains("/subscriptions/$SubscriptionId") -eq $false) {
        $role.AssignableScopes.Add("/subscriptions/$SubscriptionId")
    }
}

if ($role.Id -eq $null) {
    New-AzureRmRoleDefinition -Role $role
}
else {
    Set-AzureRmRoleDefinition -Role $role
}
Write-Host "Lock Manager custom role created"