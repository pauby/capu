# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 19-Dec-2016.

<#
.SYNOPSIS
    Update automatic package

.DESCRIPTION
    This function is used to perform necessary updates to the specified files in the package.
    It shouldn't be used on its own but must be part of the script which defines two functions:

    - au_SearchReplace
      The function should return HashTable where keys are file paths and value is another HashTable
      where keys and values are standard search and replace strings
    - au_GetLatest
      Returns the HashTable where the script specifies information about new Version, new URLs and
      any other data. You can refer to this variable as the $Latest in the script.
      While Version is used to determine if updates to the package are needed, other arguments can
      be used in search and replace patterns or for whatever purpose.

    With those 2 functions defined, calling Update-Package will:

    - Call your au_GetLatest function to get the remote version and other information.
    - If remote version is higher then the nuspec version, function will:
        - Check the returned URLs, Versions and Checksums (if defined) for validity (unless NoCheckXXX variables are specified)
        - Download files and calculate checksum(s), (unless already defined or ChecksumFor is set to 'none')
        - Update the nuspec with the latest version
        - Do the necessary file replacements
        - Pack the files into the nuget package

    You can also define au_BeforeUpdate and au_AfterUpdate functions to integrate your code into the update pipeline.
.EXAMPLE
    PS> notepad update.ps1
    import-module au

    function global:au_SearchReplace {
        ".\tools\chocolateyInstall.ps1" = @{
            "(^[$]url32\s*=\s*)('.*')"          = "`$1'$($Latest.URL32)'"
            "(^[$]checksum32\s*=\s*)('.*')"     = "`$1'$($Latest.Checksum32)'"
            "(^[$]checksumType32\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType32)'"
        }
    }

    function global:au_GetLatest {
        $download_page = Invoke-WebRequest -Uri https://github.com/hluk/CopyQ/releases

        $re  = "copyq-.*-setup.exe"
        $url = $download_page.links | ? href -match $re | select -First 1 -expand href
        $version = $url -split '-|.exe' | select -Last 1 -Skip 2

        return @{ URL32 = $url; Version = $version }
    }

    Update-Package -ChecksumFor 32

.NOTES
    All function parameters accept defaults via global variables with prefix `au_` (example: $global:au_Force = $true).

.OUTPUTS
    PSCustomObject with type AUPackage.

.LINK
    Update-AUPackages
#>
function Update-Package {
    [CmdletBinding()]
    param(
        #Do not check URL and version for validity.
        [switch] $NoCheckUrl,

        #Do not check if latest returned version already exists in the Chocolatey community feed.
        #Ignored when Force is specified.
        [switch] $NoCheckChocoVersion,

        #Specify for which architectures to calculate checksum - all, 32 bit, 64 bit or none.
        [ValidateSet('all', '32', '64', 'none')]
        [string] $ChecksumFor='all',

        #Timeout for all web operations, by default 100 seconds.
        [int]    $Timeout,

        #Force package update even if no new version is found.
        [switch] $Force,

        #Do not show any Write-Host output.
        [switch] $NoHostOutput,

        #Output variable.
        [string] $Result
    )

    function check_urls() {
        "URL check" | result
        $Latest.Keys | Where-Object {$_ -like 'url*' } | ForEach-Object {
            $url = $Latest[ $_ ]
            if ($res = check_url $url) { throw "${res}:$url" } else { "  $url" | result }
        }
    }

    function get_checksum()
    {
        function invoke_installer() {
            if (!(Test-Path tools\chocolateyInstall.ps1)) { "  aborted, chocolateyInstall not found for this package" | result; return }

            Import-Module "$choco_tmp_path\helpers\chocolateyInstaller.psm1" -Force -Scope Global

            if ($ChecksumFor -eq 'none') { "Automatic checksum calculation is disabled"; return }
            if ($ChecksumFor -eq 'all')  { $arch = '32','64' } else { $arch = $ChecksumFor }

            $pkg_path = [System.IO.Path]::GetFullPath("$Env:TEMP\chocolatey\$($package.Name)\" + $global:Latest.Version) #https://github.com/majkinetor/au/issues/32
            mkdir -Force $pkg_path | Out-Null

            $Env:ChocolateyPackageName         = "chocolatey\$($package.Name)"
            $Env:ChocolateyPackageVersion      = $global:Latest.Version
            $Env:ChocolateyAllowEmptyChecksums = 'true'
            foreach ($a in $arch) {
                $Env:chocolateyForceX86 = if ($a -eq '32') { 'true' } else { '' }
                try {
                    #rm -force -recurse -ea ignore $pkg_path
                    .\tools\chocolateyInstall.ps1 | result
                } catch {
                    if ( "$_" -notlike 'au_break: *') { throw $_ } else {
                        $filePath = "$_" -replace 'au_break: '
                        if (!(Test-Path $filePath)) { throw "Can't find file path to checksum" }

                        $item = Get-Item $filePath
                        $type = if ($global:Latest.ContainsKey('ChecksumType' + $a)) { $global:Latest.Item('ChecksumType' + $a) } else { 'sha256' }
                        $hash = (Get-FileHash $item -Algorithm $type | ForEach-Object Hash).ToLowerInvariant()

                        if (!$global:Latest.ContainsKey('ChecksumType' + $a)) { $global:Latest.Add('ChecksumType' + $a, $type) }
                        if (!$global:Latest.ContainsKey('Checksum' + $a)) {
                            $global:Latest.Add('Checksum' + $a, $hash)
                            "Package downloaded and hash calculated for $a bit version" | result
                        } else {
                            $expected = $global:Latest.Item('Checksum' + $a)
                            if ($hash -ne $expected) { throw "Hash for $a bit version mismatch: actual = '$hash', expected = '$expected'" }
                            "Package downloaded and hash checked for $a bit version" | result
                        }
                    }
                }
            }
        }

        function fix_choco {
            Start-Sleep -Milliseconds (Get-Random 500) #reduce probability multiple updateall threads entering here at the same time (#29)

            # Copy choco modules once a day
            if (Test-Path $choco_tmp_path) {
                $ct = Get-Item $choco_tmp_path | ForEach-Object creationtime
                if (((get-date) - $ct).Days -gt 1) { Remove-Item -recurse -force $choco_tmp_path } else { Write-Verbose 'Chocolatey copy is recent, aborting monkey patching'; return }
            }

            Write-Verbose "Monkey patching chocolatey in: '$choco_tmp_path'"
            Copy-Item -recurse -force $Env:ChocolateyInstall\helpers $choco_tmp_path\helpers
            if (Test-Path $Env:ChocolateyInstall\extensions) { Copy-Item -recurse -force $Env:ChocolateyInstall\extensions $choco_tmp_path\extensions }

            $fun_path = "$choco_tmp_path\helpers\functions\Get-ChocolateyWebFile.ps1"
            (Get-Content $fun_path) -replace '^\s+return \$fileFullPath\s*$', '  throw "au_break: $fileFullPath"' | Set-Content $fun_path -ea ignore
        }

        "Automatic checksum started" | result

        # Copy choco powershell functions to TEMP dir and monkey patch the Get-ChocolateyWebFile function
        $choco_tmp_path = "$Env:TEMP\chocolatey\au\chocolatey"
        fix_choco

        # This will set the new URLs before the files are downloaded but will replace checksums to empty ones so download will not fail
        #  because checksums are at that moment set for the previous version.
        # SkipNuspecFile is passed so that if things fail here, nuspec file isn't updated; otherwise, on next run
        #  AU will think that package is the most recent. 
        #
        # TODO: This will also leaves other then nuspec files updated which is undesired side effect (should be very rare)
        #
        $global:Silent = $true

        $c32 = $global:Latest.Checksum32; $c64 = $global:Latest.Checksum64          #https://github.com/majkinetor/au/issues/36
        $global:Latest.Remove('Checksum32'); $global:Latest.Remove('Checksum64')    #  -||-
        update_files -SkipNuspecFile | out-null
        if ($c32) {$global:Latest.Checksum32 = $c32}
        if ($c64) {$global:Latest.Checksum64 = $c64}                                #https://github.com/majkinetor/au/issues/36

        $global:Silent = $false

        # Invoke installer for each architecture to download files
        invoke_installer
    }

    function set_fix_version() {
        $script:is_forced = $true

        if ($global:au_Version) {
            "Overriding version to: $global:au_Version" | result
            $global:Latest.Version = $package.RemoteVersion = $global:au_Version
            if (!(is_version $Latest.Version)) { throw "Invalid version: $($Latest.Version)" }
            $global:au_Version = $null
            return
        }

        $date_format = 'yyyyMMdd'
        $d = (get-date).ToString($date_format)
        $v = [version]($package.NuspecVersion -replace '-.+')
        $rev = $v.Revision.ToString()
        try { $revdate = [DateTime]::ParseExact($rev, $date_format,[System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None) } catch {}
        if (($rev -ne -1) -and !$revdate) { return }

        $build = if ($v.Build -eq -1) {0} else {$v.Build}
        $Latest.Version = $package.RemoteVersion = '{0}.{1}.{2}.{3}' -f $v.Major, $v.Minor, $build, $d
    }

    function update_files( [switch]$SkipNuspecFile )
    {
        'Updating files' | result
        '  $Latest data:' | result;  ($global:Latest.keys | Sort-Object | ForEach-Object { "    {0,-15} ({1})    {2}" -f $_, $global:Latest[$_].GetType().Name, $global:Latest[$_] }) | result; '' | result

        if (!$SkipNuspecFile) {
            "  $(Split-Path $package.NuspecPath -Leaf)" | result

            "    setting id:  $($global:Latest.PackageName)" | result
            $package.NuspecXml.package.metadata.id = $package.Name = $global:Latest.PackageName.ToString()

            $msg ="updating version: {0} -> {1}" -f $package.NuspecVersion, $package.RemoteVersion
            if ($script:is_forced) {
                if ($package.RemoteVersion -eq $package.NuspecVersion) {
                    $msg = "    version not changed as it already uses 'revision': {0}" -f $package.NuspecVersion
                } else {
                    $msg = "    using Chocolatey fix notation: {0} -> {1}" -f $package.NuspecVersion, $package.RemoteVersion
                }
            }
            $msg | result

            $package.NuspecXml.package.metadata.version = $package.RemoteVersion.ToString()
            $package.SaveNuspec()
        }

        $sr = au_SearchReplace
        if ($sr.Keys.Count -gt 0) {
            $sr.Keys | ForEach-Object {
                $fileName = $_
                "  $fileName" | result

                $fileContent = Get-Content $fileName
                $sr[ $fileName ].GetEnumerator() | ForEach-Object {
                    ('    {0} = {1} ' -f $_.name, $_.value) | result
                    if (!($fileContent -match $_.name)) { throw "Search pattern not found: '$($_.name)'" }
                    $fileContent = $fileContent -replace $_.name, $_.value
                }

                $fileContent | Out-File -Encoding UTF8 $fileName
            }
        }
    }

    function is_updated() {
        $remote_l = $package.RemoteVersion -replace '-.+'
        $nuspec_l = $package.NuspecVersion -replace '-.+'
        $remote_r = $package.RemoteVersion.Replace($remote_l,'')
        $nuspec_r = $package.NuspecVersion.Replace($nuspec_l,'')

        if ([version]$remote_l -eq [version] $nuspec_l) {
            if (!$remote_r -and $nuspec_r) { return $true }
            if ($remote_r -and !$nuspec_r) { return $false }
            return ($remote_r -gt $nuspec_r)
        }
        [version]$remote_l -gt [version] $nuspec_l
    }

    function result() {
        if ($global:Silent) { return }

        $input | ForEach-Object {
            $package.Result += $_
            if (!$NoHostOutput) { Write-Host $_ }
        }
    }

    if ($PSCmdlet.MyInvocation.ScriptName -eq '') {
        Write-Verbose 'Running outside of the script'
        if (!(Test-Path update.ps1)) { return "Current directory doesn't contain ./update.ps1 script" } else { return ./update.ps1 }
    } else { Write-Verbose 'Running inside the script' }

    # Assign parameters from global variables with the prefix `au_` if they are bound
    (Get-Command $PSCmdlet.MyInvocation.InvocationName).Parameters.Keys | ForEach-Object {
        if ($PSBoundParameters.Keys -contains $_) { return }
        $value = Get-Variable "au_$_" -Scope Global -ea Ignore | ForEach-Object Value
        if ($value -ne $null) {
            Set-Variable $_ $value
            Write-Verbose "Parameter $_ set from global variable au_${_}: $value"
        }
    }

    $package = [AUPackage]::new( $pwd )
    if ($Result) { Set-Variable -Scope Global -Name $Result -Value $package }

    $global:Latest = @{PackageName = $package.Name}
    $global:Latest.NuspecVersion = $package.NuspecVersion
    if (!(is_version $package.NuspecVersion)) {
        Write-Warning "Invalid nuspec file Version '$($package.NuspecVersion)' - using 0.0"
        $global:Latest.NuspecVersion = $package.NuspecVersion = '0.0'
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $module = $MyInvocation.MyCommand.ScriptBlock.Module
    "{0} - checking updates using {1} version {2}" -f $package.Name, $module.Name, $module.Version | result
    try {
        $res = au_GetLatest | Select-Object -Last 1
        if ($res -eq $null) { throw 'au_GetLatest returned nothing' }

        $res_type = $res.GetType()
        if ($res_type -ne [HashTable]) { throw "au_GetLatest doesn't return a HashTable result but $res_type" }

        $res.Keys | ForEach-Object { $global:Latest.Remove($_) }
        $global:Latest += $res
        if ($global:au_Force) { $Force = $true }
    } catch {
        throw "au_GetLatest failed`n$_"
    }

    if (!(is_version $Latest.Version)) { throw "Invalid version: $($Latest.Version)" }
    $package.RemoteVersion = $Latest.Version

    if (!$NoCheckUrl) { check_urls }

    "nuspec version: " + $package.NuspecVersion | result
    "remote version: " + $package.RemoteVersion | result

    if (is_updated) {
        if (!($NoCheckChocoVersion -or $Force)) {
            $choco_url = "https://chocolatey.org/packages/{0}/{1}" -f $package.Name, $package.RemoteVersion
            try {
                request $choco_url $Timeout | out-null
                "New version is available but it already exists in the Chocolatey community feed (disable using `$NoCheckChocoVersion`):`n  $choco_url" | result
                return $package
            } catch { }
        }
    } else {
        if (!$Force) {
            'No new version found' | result
            return $package
        }
        else { 'No new version found, but update is forced' | result; set_fix_version }
    }

    'New version is available' | result

    $match_url = ($Latest.Keys | Where-Object { $_ -match '^URL*' } | Select-Object -First 1 | ForEach-Object { $Latest[$_] } | split-Path -Leaf) -match '(?<=\.)[^.]+$'
    if ($match_url -and !$Latest.FileType) { $Latest.FileType = $Matches[0] }

    if ($ChecksumFor -ne 'none') { get_checksum } else { 'Automatic checksum skipped' | result }

    if (Test-Path Function:\au_BeforeUpdate) { 'Running au_BeforeUpdate' | result; au_BeforeUpdate | result }
    update_files
    if (Test-Path Function:\au_AfterUpdate) { 'Running au_AfterUpdate' | result; au_AfterUpdate | result }

    choco pack --limit-output | result
    if ($LastExitCode -ne 0) { throw "Choco pack failed with exit code $LastExitCode" }

    'Package updated' | result
    $package.Updated = $true

    return $package
}

Set-Alias update Update-Package


