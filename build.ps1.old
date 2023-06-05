[CmdletBinding()]
param(
)

Set-StrictMode -Version Latest

task Clean CleanRelease, CleanOutput, CleanDocs

# Default configuration
# Override this using $BuildOptions hashtable in your .<modulename>.build.ps1
$BuildDefault = @{
    ModuleName             = '' # You NEED to override this!
    RequiredModules        = "Pester", "PSScriptAnalyzer", "PSCodeHealth", "Configuration", "platyPS" # If you override this, make sure to include these!
    SourcePath             = Join-Path -Path $BuildRoot -ChildPath 'source'
    ReleasePath            = Join-Path -Path $BuildRoot -ChildPath 'release'
    BuildPath              = Join-Path -Path $BuildRoot -ChildPath 'build'
    TestPath               = Join-Path -Path $BuildRoot -ChildPath 'tests'
    DocDir                 = 'docs'
    DocPath                = Join-Path -Path $BuildRoot -ChildPath 'docs'
    OutputPath             = Join-Path -Path $BuildRoot -ChildPath 'output'
    ModuleFiles            = '' # other files and folders to copy the build folder
    MDConvert              = '' # markdown files to convert to HTML

    PSSAOutputPath         = Join-Path -Path $BuildRoot -ChildPath 'output\psscriptanalyzer.csv'
    PSSASeverity           = 'Error', 'Warning' # Can be 'Error', 'Warning' and / or 'Information'
    PesterOutputPath       = Join-Path -Path $BuildRoot -ChildPath 'output\pester-output.xml'
    CodeCoverageOutputPath = Join-Path -Path $BuildRoot -ChildPath 'output\codecoverage.csv'
    CodeCoverageThreshold  = 0.8   # 80% - 0 to disable

    ModuleHeader           = ''
    ModuleHFooter          = ''
    FunctionHeader         = ''
    FunctionFooter         = "`n"
}


Enter-Build {
    # build the config
    $BuildConfig = $BuildDefault.Clone()
    $BuildOptions.Keys | ForEach-Object {
        $BuildConfig.$_ = $BuildOptions.$_
    }

    # check we have some paths we need
    if (! (Test-Path -Path $BuildConfig.SourcePath)) {
        throw "Cannot find source path '$($BuildConfig.SourcePath)'."
    }

    # create paths needed
    $BuildConfig.ReleasePath, $BuildConfig.TestPath, $BuildConfig.DocPath, $BuildConfig.OutputPath | ForEach-Object {
        if (! (Test-Path -Path $_)) {
            $null = New-Item -Path $_ -ItemType Directory
        }
    }
}

task InstallDependencies {
    $BuildConfig.RequiredModules | ForEach-Object {
        if (!(Get-Module -Name $_ -ListAvailable)) {
            Install-Module $_ -Force -Scope CurrentUser
        }

        Import-Module -Name $_ -Force
    }

    # Check if Chocolatey is installed
    if (! [bool](Get-Command -Name 'choco' -ErrorAction SilentlyContinue)) {
        try {
            Write-Verbose 'Chocolatey not installed. Installing.'
            # taken from https://chocolatey.org/install
            Set-ExecutionPolicy Bypass -Scope Process -Force
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        }
        catch {
            throw 'Could not install Chocolatey.'
        }
    }
    else {
        Write-Verbose "Chocolatey already installed."
    }

    # Chocolatey is installed
    $packageInstalled = $false
    @(
        @{
            package = 'pandoc'
            assert  = [scriptblock] { [bool](Get-Command -Name 'pandoc') }
        },
        @{
            package = '7Zip'
            assert  = [scriptblock] { [bool](Get-Command -Name '7zfm') }
        }
    ) | ForEach-Object {
        # check the package is NOT installed already
        if (!$_.assert) {
            Write-Verbose "Installing '$($_.package)' package."
            choco install $_.package -y
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install Chocolatey package '$_'."
            }
            $packageInstalled = $true
        }
        else {
            Write-Verbose "Chocolatey package '$($_.package)' already installed. Skipping."
        }
    }

    if ($packageInstalled) {
        Write-Verbose 'Refreshing the PATH'
        refreshenv
    }
}

# Synopsis: Remove contents of the release folder
task CleanRelease {
    $null = Remove-Item -Path $BuildConfig.ReleasePath -Force -Recurse -ErrorAction SilentlyContinue
    $null = New-Item -Path $BuildCOnfig.ReleasePath -ItemType Directory
}

task CleanOutput {
    $null = Remove-Item -Path $BuildConfig.OutputPath -Force -Recurse -ErrorAction SilentlyContinue
    $null = New-Item -Path $BuildConfig.OutputPath -ItemType Directory
}

task CleanDocs {
    $null = Remove-Item -Path $BuildConfig.DocPath -Force -Recurse -ErrorAction SilentlyContinue
    $null = New-Item -Path $BuildConfig.DocPath -ItemType Directory
}

# Synopsis: Cleans the module from all PowerShell module paths
task CleanModule {
    Get-Module $BuildConfig.ModuleName -ListAvailable | ForEach-Object {
        Remove-Module $_.Path -ErrorAction SilentlyContinue
        Remove-Item -Path (Split-Path -Path $_.Path -Parent) -Force -Recurse
    }
}

# Synopsis: Warn about not empty git status if .git exists.
task GitStatus -If (Test-Path .git) {
    $status = exec { git status -s }
    if ($status) {
        Write-Warning "Git status: $($status -join ', ')"
    }
}

# Synopsis: Build the PowerShell help file.
# <https://github.com/nightroman/Helps>
task Help {
    . Helps.ps1
    Convert-Helps Invoke-Build-Help.ps1 Invoke-Build-Help.xml
}

# Synopsis: Set $script:Version.
task Version {
    # get the version from Release-Notes
    $script:Version = . { switch -Regex -File Changelog.md {'##\s+v(\d+\.\d+\.\d+)' {return $Matches[1]}} }
    assert ($Version)
}

# Synopsis: Convert markdown files to HTML.
# <http://johnmacfarlane.net/pandoc/>
task MakeHTMLDocs -If { [bool](Get-Command -Name 'pandoc') } {
    ForEach ($name in $BuildConfig.MDConvert) {
        $sourcePath = Join-Path -Path $BuildRoot -ChildPath $name
        if (Test-Path $sourcePath) {
            $baseName = (Get-Item -Path $sourcePath).BaseName
            $destPath = Join-Path -Path $BuildConfig.ReleasePath -ChildPath "$baseName.html"
            exec { pandoc.exe --standalone --from=markdown_strict --metadata=title:$name --output=$destPath $sourcePath }
            Write-Verbose "Converted markdown file '$name' to '$destPath'"
        } # end if
    } # end foreach
}

task UpdateModuleHelp -If (Get-Module platyPS -ListAvailable) CleanDocs, {
    try {
        $modulePath = Join-Path -Path $BuildConfig.ReleasePath -ChildPath "$($BuildConfig.ModuleName).psm1"
        $moduleInfo = Import-Module -FullyQualifiedName $modulePath -ErrorAction Stop -PassThru -Force
        if ($moduleInfo.ExportedFunctions.Count -gt 0) {
            $moduleInfo.ExportedFunctions.Keys | ForEach-Object {

                if ($ManifestOptions.ContainsKey('ProjectUri')) {
                    $onlineUrl = $ManifestOptions.ProjectUri
                    if (-not $onlineUrl.EndsWith('/')) {
                        $onlineUrl += '/'
                    }

                    $onlineUrl += "blob/master/$($BuildConfig.DocDir)/$_.md"
                }
                else {
                    $onlineUrl = ''
                }

                $params = @{
                    Command               = $_
                    OutputFolder          = $BuildConfig.DocPath
                    OnlineVersionUrl      = $onlineUrl
                    AlphabeticParamsOrder = $true
                    Force                 = $true
                }

                New-MarkdownHelp @params | Out-Null
            }

            New-ExternalHelp -Path $BuildConfig.DocPath `
                -OutputPath (Join-Path -Path $BuildConfig.ReleasePath -ChildPath 'en-US') -Force | Out-Null
        }

        Remove-Module -Name $BuildConfig.ModuleName -Force
    }
    catch {
        throw
    }
}

# Synopsis: Make the build folder.
task Build InstallDependencies, CleanRelease, TestFunctionSyntax, TestFunctionAttributeSyntax, BuildManifest, BuildScriptModule, {
    # copy files
    $BuildConfig.ModuleFiles | ForEach-Object {
        Copy-Item -Path (Join-Path -Path $BuildRoot -ChildPath $_) `
            -Destination $BuildConfig.ReleasePath -Recurse
        Write-Verbose "Copied $_ to build directory '$($BuildConfig.ReleasePath)'"
    }
}, MakeHTMLDocs

# Synopsis: Builds the module manifest
task BuildManifest Version, BuildScriptModule, {
    $releaseManifestPath = Join-Path -Path $BuildConfig.ReleasePath -ChildPath "$($BuildConfig.ModuleName).psd1"
    $sourceManifestPath = Join-Path -Path $BuildConfig.SourcePath -ChildPath "$($BuildConfig.ModuleName).psd1"

    # copy existing manifest
    Copy-Item -Path $sourceManifestPath -Destination $releaseManifestPath -ErrorAction Stop

    # Update the copied manifest
    if (Test-Path -Path variable:ManifestOptions) {
        ForEach ($key in $ManifestOptions.Keys) {
            Update-Metadata -Path $releaseManifestPath -PropertyName $key -Value $ManifestOptions.$key -ErrorAction Stop
        }
    }
}, TestModule

task BuildScriptModule {
    # build the psm1 module file with all of the scripts
    $modulePath = Join-Path -Path $BuildConfig.ReleasePath -ChildPath "$($BuildConfig.ModuleName).psm1"
    Remove-Item $modulePath -Force -ErrorAction SilentlyContinue

    if ($BuildConfig.ContainsKey('ModuleHeader') -and !([string]::IsNullOrEmpty($BuildConfig.ModuleHeader))) {
        Add-Content -Path $modulePath -Value $BuildConfig.ModuleHeader
        Write-Verbose "Added ModuleHeader contents to script module '$modulePath'."
    }

    # get a list of all scipts in the public and private directories and subdirectories
    $functions = Get-ChildItem (Join-Path -Path $BuildConfig.SourcePath -ChildPath "public\*.ps1") -Recurse #).FullName)  #| ForEach-Object { "public\$_" }
    $functions += Get-ChildItem (Join-Path -Path $BuildConfig.SourcePath -ChildPath "private\*.ps1") -Recurse -ErrorAction SilentlyContinue #.FullName) #| ForEach-Object { "private\$_" }

    Foreach ($function in $functions) {
        if ($BuildConfig.ContainsKey('FunctionHeader') -and !([string]::IsNullOrEmpty($BuildConfig.FunctionHeader))) {
            Add-Content -Path $modulePath -Value $BuildConfig.FunctionHeader
        }

        Get-Content -Path $function | Add-Content -Path $modulePath

        if ($BuildConfig.ContainsKey('FunctionFooter') -and !([string]::IsNullOrEmpty($BuildConfig.FunctionFooter))) {
            Add-Content -Path $modulePath -Value $BuildConfig.FunctionFooter
        }

        Write-Verbose "Added $($function.name) to script module."
    }

    if ($BuildConfig.ContainsKey('ModuleFooter') -and !([string]::IsNullOrEmpty($BuildConfig.ModuleFooter))) {
        Add-Content -Path $modulePath -Value $BuildConfig.ModuleFooter
        Write-Verbose "Added ModuleFooter contents to script module '$modulePath'."
    }
}, TestScriptModule, UpdateModuleHelp

# Synopsis: Push with a version tag.
task PushRelease Version, {
    $changes = exec { git status --short }
    assert (!$changes) "Please, commit changes."

    exec { git push }
    exec { git tag -a "v$Version" -m "v$Version" }
    exec { git push origin "v$Version" }
}

task PushPSGallery Test, CodeAnalysis, CleanModule, Build, {
    if (-not $BuildConfig.PSGalleryApiKey) {
        Write-Error "You need to set the environment variable PSGALLERY_API_KEY to the PowerShell Gallery API Key"
    }

    #    exec {$null = robocopy.exe $($BuildConfig.ReleasePath) "$($BuildConfig.ModuleLoadPath)\$($BuildConfig.ModuleName)" /mir} (0..2)
    #   Write-Verbose "Copied $($BuildConfig.ReleasePath) to $($BuildConfig.ModuleLoadPath)\$($BuildConfig.ModuleName)"

    #Import-Module "$($BuildConfig.ReleasePath)\$($BuildConfig.ModuleName).psd1"
    Publish-Module -Name $BuildConfig.ModuleName -NuGetApiKey $BuildConfig.PSGalleryApiKey
}, CleanModule, CleanRelease

# Synopsis: Test and check expected output.
# Requires PowerShelf/Assert-SameFile.ps1
task Test3 {
    # invoke tests, get output and result
    $output = Invoke-Build . Tests\.build.ps1 -Result result -Summary | Out-String -Width:200
    if ($NoTestDiff) {return}

    # process and save the output
    $resultPath = "$BuildRoot\Invoke-Build-Test.log"
    $samplePath = "$HOME\data\Invoke-Build-Test.$($PSVersionTable.PSVersion.Major).log"
    $output = $output -replace '\d\d:\d\d:\d\d(?:\.\d+)?( )? *', '00:00:00.0000000$1'
    [System.IO.File]::WriteAllText($resultPath, $output, [System.Text.Encoding]::UTF8)

    # compare outputs
    Assert-SameFile $samplePath $resultPath $env:MERGE
    Remove-Item $resultPath
}

# Synopsis: Test with PowerShell v2.
task Test2 {
    $diff = if ($NoTestDiff) {'-NoTestDiff'}
    exec {powershell.exe -Version 2 -NoProfile -Command Invoke-Build Test3 $diff}
}

# Synopsis: Test with PowerShell v6.
task Test6 -If $env:powershell6 {
    $diff = if ($NoTestDiff) {'-NoTestDiff'}
    exec {& $env:powershell6 -NoProfile -Command Invoke-Build Test3 $diff}
}

task TestModule {
    $pesterParams = @{
        EnableExit = $false;
        PassThru   = $true;
        Strict     = $true;
        Show       = "Failed"
    }

    # will throw an error and stop the build if errors
    Test-ModuleManifest -Path (Join-Path -Path $BuildConfig.ReleasePath -ChildPath "$($BuildConfig.ModuleName).psd1") -ErrorAction Stop | Out-Null

    # remove the module before we test it
    #Remove-Module $BuildConfig.ModuleName -Force -ErrorAction SilentlyContinue
    #$results = Invoke-Pester @pesterParams
    #$fails = @($results).FailedCount
    #assert($fails -eq 0) ('Failed "{0}" unit tests.' -f $fails)
}

task TestScriptModule {
    $path = Join-Path $BuildConfig.ReleasePath -ChildPath "$($BuildConfig.ModuleName).psm1"
    Import-Module -Name $path -ErrorAction Stop -PassThru | Remove-Module
}

# https://github.com/indented-automation/Indented.Build
task TestFunctionSyntax {
    $hasSyntaxErrors = $false

    Get-ChildItem -Path $BuildConfig.SourcePath -Include '*.ps1' -Recurse | ForEach-Object {
        Write-Verbose "Checking source code syntax on '$($_.name)'"
        $tokens = $null
        [System.Management.Automation.Language.ParseError[]]$parseErrors = @()
        $null = [System.Management.Automation.Language.Parser]::ParseInput(
            (Get-Content $_.FullName -Raw),
            $_.FullName,
            [Ref]$tokens,
            [Ref]$parseErrors
        )

        if ($parseErrors.Count -gt 0) {
            $parseErrors | Write-Error

            $hasSyntaxErrors = $true
        }
    }

    if ($hasSyntaxErrors) {
        throw 'TestFunctionSyntax failed'
    }
    else {
        Write-Verbose "No syntax errors"
    }
}

# https://github.com/indented-automation/Indented.Build
task TestFunctionAttributeSyntax {
    $hasSyntaxErrors = $false
    Get-ChildItem -Path $BuildConfig.SourcePath -Include '*.ps1' -Recurse | ForEach-Object {
        Write-Verbose "Checking source code attribute syntax on '$($_.name)'"
        $tokens = $null
        [System.Management.Automation.Language.ParseError[]]$parseErrors = @()
        $ast = [System.Management.Automation.Language.Parser]::ParseInput(
            (Get-Content $_.FullName -Raw),
            $_.FullName,
            [Ref]$tokens,
            [Ref]$parseErrors
        )

        # Test attribute syntax
        $attributes = $ast.FindAll( {
                param( $ast )
                $ast -is [System.Management.Automation.Language.AttributeAst]
            },
            $true
        )
        foreach ($attribute in $attributes) {
            if (($type = $attribute.TypeName.FullName -as [Type]) -or ($type = ('{0}Attribute' -f $attribute.TypeName.FullName) -as [Type])) {
                $propertyNames = $type.GetProperties().Name

                if ($attribute.NamedArguments.Count -gt 0) {
                    foreach ($argument in $attribute.NamedArguments) {
                        if ($argument.ArgumentName -notin $propertyNames) {
                            'Invalid property name in attribute declaration: {0}: {1} at line {2}, character {3}' -f
                            $_.Name,
                            $argument.ArgumentName,
                            $argument.Extent.StartLineNumber,
                            $argument.Extent.StartColumnNumber

                            $hasSyntaxErrors = $true
                        }
                    }
                }
            }
            else {
                'Invalid attribute declaration: {0}: {1} at line {2}, character {3}' -f
                $_.Name,
                $attribute.TypeName.FullName,
                $attribute.Extent.StartLineNumber,
                $attribute.Extent.StartColumnNumber

                $hasSyntaxErrors = $true
            }
        }
    }

    if ($hasSyntaxErrors) {
        throw 'TestFunctionAttributeSyntax failed'
    }
    else {
        Write-Verbose "No attribute syntax errors"
    }
}

task PSScriptAnalyzer -If (Get-Module PSScriptAnalyzer -ListAvailable) {
    $splat = @{
        Path     = $BuildConfig.ReleasePath
        Severity = $BuildConfig.PSSASeverity
        Recurse  = $true
        Verbose  = $VerbosePreference
    }

    Write-Verbose "Running PSScriptAnalyzer default rules on '$($splat.Path)'."
    Invoke-ScriptAnalyzer @splat | ForEach-Object {
        $_
        $_ | Export-Csv $BuildConfig.PSSAOutputPath -NoTypeInformation -Append
    }
}

task Pester -If { (Get-Module PSScriptAnalyzer -ListAvailable) -and (Get-ChildItem -Path $BuildConfig.TestPath -Filter '*.tests.ps1' -Recurse -File) } {

    Import-Module -Name (Join-Path -Path $BuildConfig.ReleasePath -ChildPath "$($BuildConfig.ModuleName).psd1")`
        -Global -ErrorAction Stop -Force
    $params = @{
        Script       = $BuildConfig.TestPath
        CodeCoverage = Join-Path -Path $BuildConfig.ReleasePath -ChildPath "$($BuildConfig.ModuleName).psm1"
        OutputFile   = Join-Path -Path $BuildConfig.OutputPath -ChildPath "$($BuildConfig.ModuleName)-nunit.xml"
        PassThru     = $true
        Show         = if ($VerbosePreference -eq 'SilentlyContinue') { 'None' } else { 'all' }
        Strict       = $true
    }

    $pester = Invoke-Pester @params -Verbose

    $pester | Export-CliXml $BuildConfig.PesterOutputPath
}

task ValidateTestResults PSScriptAnalyzer, Pester, {
    $testsFailed = $false

    # PSScriptAnalyzer
    if ((Test-Path -Path $BuildConfig.PSSAOutputPath) -and ($testResults = Import-Csv -Path $BuildConfig.PSSAOutputPath)) {
        '{0} warnings were raised by PSScriptAnalyzer' -f @($testResults).Count
        $testsFailed = $true
    }
    else {
        Write-Verbose '0 warnings were raised by PSScriptAnalyzer'
    }

    # Pester tests
    if (Test-Path -Path $BuildConfig.PesterOutputPath) {
        $pester = Import-CliXml -Path $BuildConfig.PesterOutputPath
        if ($pester.FailedCount -gt 0) {
            '{0} of {1} Pester tests are failing' -f $pester.FailedCount, $pester.TotalCount
            $testsFailed = $true
        }
        else {
            Write-Verbose 'All Pester tests passed.'
        }

        # Pester code coverage
        [Double]$codeCoverage = $pester.CodeCoverage.NumberOfCommandsExecuted / $pester.CodeCoverage.NumberOfCommandsAnalyzed
        $pester.CodeCoverage.MissedCommands | `
            Export-Csv -Path $BuildConfig.CodeCoverageOutputPath -NoTypeInformation

        if ($codecoverage -lt $BuildConfig.CodeCoverageThreshold) {
            'Pester code coverage ({0:P}) is below threshold {1:P}.' -f $codeCoverage, $BuildConfig.CodeCoverageThreshold
            $testsFailed = $true
        }
    }
    else {
        Write-Warning 'Pester tests not run.'
    }

    if ($testsFailed) {
        throw 'Test result validation failed'
    }
}

task CreateCodeHealthReport -If (Get-Module PSCodeHealth -ListAvailable) {
    Import-Module -FullyQualifiedName $BuildInfo.BuildManifestPath -Global -ErrorAction Stop
    $params = @{
        Path           = $BuildInfo.BuildModulePath
        Recurse        = $true
        TestsPath      = $BuildInfo.TestPath
        HtmlReportPath = Join-Path -Path $BuildInfo.OutputPath -ChildPath "$($Buildinfo.ModuleName)-code-health.html"
    }
    Invoke-PSCodeHealth @params
}