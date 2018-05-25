<#
    Intall AU from git repository using given version. Can also be used to install development branches.
    Git tags are treated as autoritative AU release source.

    This script is used for build server.
#>

[CmdletBinding()]
param(
    # If parsable to [version], exact AU version will be installed. Example:  '2016.10.30'
    # If not parsable to [version] it is assumed to be name of the AU git branch. Example: 'master'
    # If empty string or $null, latest release (git tag) will be installed.
    [string] $Version
)

$ErrorActionPreference = 'STOP'
$git_url = 'https://github.com/pauby/capu.git'

if (!(gcm git -ea 0)) { throw 'Git must be installed' }
[version]$git_version = (git --version) -replace 'git|version|\.windows'
if ($git_version -lt [version]2.5) { throw 'Git version must be higher then 2.5' }

$is_latest = [string]::IsNullOrWhiteSpace($Version)
$is_branch = !($is_latest -or [version]::TryParse($Version, [ref]($_)))

pushd $PSScriptRoot\..

if ($is_latest) { $Version = (git tag | % { [version]$_ } | sort -desc | select -first 1).ToString() }
if ($is_branch) {
    $branches = git branch -r -q | % { $_.Replace('origin/','').Trim() }
    if ($branches -notcontains $Version) { throw "AU branch '$Version' doesn't exist" }
    if ($Version -ne 'master') { git fetch -q origin "${Version}:${Version}" }
} else {
    $tags = git tag
    if ($tags -notcontains $Version ) { throw "AU version '$Version' doesn't exist"}
}

git checkout -q $Version

$params = @{ Install = $true; NoChocoPackage = $true}
if (!$is_branch) { $params.Version = $Version }

"Build parameters:"
$params.GetEnumerator() | % { "  {0,-20} {1}" -f $_.Key, $_.Value }
./build.ps1 @params

popd
