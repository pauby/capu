# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 22-Oct-2016.

<#
.SYNOPSIS
    Push latest created package to the Chocolatey community repository.

.DESCRIPTION
    The function uses they API key from the file api_key in current or parent directory, environment variable
    or cached nuget API key.
#>
function Push-Package() {
    $api_key =  if (Test-Path api_key) { Get-Content api_key }
                elseif (Test-Path ..\api_key) { Get-Content ..\api_key }
                elseif ($Env:api_key) { $Env:api_key }

    $package = Get-ChildItem *.nupkg | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    if (!$package) { throw 'There is no nupkg file in the directory'}
    if ($api_key) {
        choco push $package.Name --api-key $api_key --source https://push.chocolatey.org
    } else {
        choco push $package.Name --source https://push.chocolatey.org
    }
}

