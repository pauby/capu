$BuildOptions = @{
    ModuleName      = 'capu'
    PSGalleryApiKey = $env:PSGALLERY_API_KEY
    ModuleFiles     = @(
        # Plugins folder
        "source\Plugins"
    )
    # Markdown files to convert to HTML
    MDConvert       = @(
        'README.md',
        'CHANGELOG.md'
    )
    PSSASeverity           = 'Error'
    CodeCoverageThreshold  = 0.8

    ModuleHeader    = "Set-StrictMode -Version Latest`n"
}

$ManifestOptions = @{
    Copyright         = if ((Get-Date).Year -eq 2018) { "(c) 2018 Paul Broadwith, 2016 Miodrag Milić" } else { "(c) 2018-$((Get-Date).Year) Paul Broadwith, 2016 Miodrag Milić" }
    FunctionsToExport = (Get-ChildItem (Join-Path -Path (Join-Path -Path $BuildRoot -ChildPath 'source') `
                            -ChildPath "public\*.ps1") -Recurse).BaseName
}

Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/pauby/ps-build-script/master/build.ps1' -OutFile 'build.ps1'

. .\build.ps1

task . InstallDependencies, Clean, Build, ValidateTestResults