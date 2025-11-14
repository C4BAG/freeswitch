param (
    [Parameter(Mandatory = $true)]
    [string]$Branch
)

.\copybuild2server.ps1 -Configuration "Debug" -Branch $branch
