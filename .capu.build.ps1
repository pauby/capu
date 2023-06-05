Import-Module PowerShellBuild -force
. PowerShellBuild.IB.Tasks

$PSBPreference.Build.OutDir =
    Join-Path -Path $PSBPreference.General.ProjectRoot -ChildPath "output"
$PSBPreference.Build.ModuleOutDir =
    Join-Path `
        -Path $PSBPreference.Build.OutDir `
        -ChildPath ("{0}{1}{2}" -f
            $PSBPreference.General.ModuleName,
            [IO.Path]::DirectorySeparatorChar,
            $PSBPreference.General.ModuleVersion)
$PSBPreference.Build.CompileModule = $true
#$PSBPreference.Build.Exclude = @( '[\\|/]source[\\|/]plugins[\\|/]' )
$PSBPreference.Build.CompileHeader = "Set-StrictMode -Version Latest`n"
$PSBPreference.Build.CompileScriptFooter = "`n"
# $PSBPreference.Build.Dependencies                           = 'StageFiles', 'BuildHelp'
$PSBPreference.Build.Exclude = @('/source/Plugins/*.ps1')
$PSBPreference.Test.Enabled                                 = $true
$PSBPreference.Test.CodeCoverage.Enabled                    = $false
$PSBPreference.Test.CodeCoverage.Threshold                  = 0.75
$PSBPreference.Test.CodeCoverage.Files                      =
    (Join-Path -Path $PSBPreference.Build.ModuleOutDir -ChildPath "*.psm1")
$PSBPreference.Test.ScriptAnalysis.Enabled                  = $true
$PSBPreference.Test.ScriptAnalysis.FailBuildOnSeverityLevel = 'Error'
$PSBPreference.Publish.PSRepository = 'PSGallery'
$PSBPreference.Publish.ApiKey = $env:PSGALLERY_API_KEY

task LocalDeploy {
    $sourcePath = $PSBPreference.Build.ModuleOutDir
    $destPath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) `
        -ChildPath "WindowsPowerShell\Modules\$($PSBPreference.General.ModuleName)\$($PSBPreference.General.ModuleVersion)\"

    if (Test-Path -Path $destPath) {
        Remove-Item -Path $destPath -Recurse -Force
    }
    Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
}

# this is broken for PowerShellBuild 0.4.0 - redefine it here
task Publish Test, {
    assert ($PSBPreference.Publish.PSRepositoryApiKey -or $PSBPreference.Publish.PSRepositoryCredential) "API key or credential not defined to authenticate with [$($PSBPreference.Publish.PSRepository)] with."

    $publishParams = @{
        Path       = $PSBPreference.Build.ModuleOutDir
        Version    = $PSBPreference.General.ModuleVersion
        Repository = $PSBPreference.Publish.PSRepository
        Verbose    = $VerbosePreference
    }
    if ($PSBPreference.Publish.PSRepositoryApiKey) {
        $publishParams.ApiKey = $PSBPreference.Publish.PSRepositoryApiKey
    }

    if ($PSBPreference.Publish.PSRepositoryCredential) {
        $publishParams.Credential = $PSBPreference.Publish.PSRepositoryCredential
    }

    Publish-PSBuildModule @publishParams
}

task Announce {
    Import-Module PSTwitterApi
    $OAuthSettings = @{
        ApiKey = $env:TWITTER_API_KEY
        ApiSecret = $env:TWITTER_API_KEY_SECRET
        AccessToken = $env:TWITTER_ACCESS_TOKEN
        AccessTokenSecret = $ENV:TWITTER_ACCESS_TOKEN_SECRET
    }
    Set-TwitterOAuthSettings @OAuthSettings

    $twitterUser = Get-TwitterUsers_Lookup -screen_name 'pauby'

    $status = "Version {0} of {1} has just been pushed to PowerShell Gallery! https://www.powershellgallery.com/packages/{1}/{0} Find it on GitHub at https://github.com/pauby/{1}" `
        -f $PSBPreference.General.ModuleVersion, $PSBPreference.General.ModuleName
    Send-TwitterStatuses_Update -status $status
}

$moduleVersion = (Get-Module -Name PowerShellBuild -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
if ($moduleVersion -le [version]"0.3.0") {
    task Build {
        #Write-Host "Setting env"
        #[Environment]::SetEnvironmentVariable("BHBuildOutput", $PSBPreference.Build.ModuleOutDir, "machine")
    }, StageFiles, BuildHelp

    task Init {
        Initialize-PSBuild
        Set-BuildEnvironment -BuildOutput $PSBPreference.Build.ModuleOutDir -Force
        $nl = [System.Environment]::NewLine
        "$nl`Environment variables:"
        (Get-Item ENV:BH*).Foreach({
            '{0,-20}{1}' -f $_.name, $_.value
        })
    }
}


# task compilemodule {
#     ipmo modulebuilder
#     $params = @{
#         SourcePath               = $PSBPreference.General.SrcRootDir
#         OutputDirectory          = $PSBPreference.Build.OutDir
#         VersionedOutputDirectory = $true
#         Version                  = $PSBPreference.General.ModuleVersion
#         Prefix                   = if ($PSBPreference.Build.Contains('Prefix')) { $PSBPreference.Build.PrefixFile } else { '' }
#         Suffix                   = if ($PSBPreference.Build.Contains('Suffix')) { $PSBPreference.Build.SuffixFile } else { '' }
#     }

#     build-module @params
# }

Task Clean Init, {
    Clear-PSBuildOutputFolder -Path $PSBPreference.Build.ModuleOutDir

    # Remove docs folder
    Remove-Item -Path $PSBPreference.Docs.RootDir -Recurse -Force -ErrorAction SilentlyContinue
}

Task Build StageFiles, BuildHelp
Task Test Pester