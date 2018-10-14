---
external help file: capu-help.xml
Module Name: capu
online version: https://github.com/pauby/capu/blob/master/docs/Test-Package.md
schema: 2.0.0
---

# Test-Package

## SYNOPSIS
Test Chocolatey package

## SYNTAX

```
Test-Package [[-Nu] <Object>] [-Install] [-Uninstall] [[-Parameters] <String>] [[-Vagrant] <String>]
 [-VagrantOpen] [-VagrantNoClear]
```

## DESCRIPTION
The function can test install, uninistall or both and provide package parameters during test.
It will force install and then remove the Chocolatey package if called without arguments.

It accepts either nupkg or nuspec path.
If none specified, current directory will be searched
for any of them.

## EXAMPLES

### EXAMPLE 1
```
Test-Package -Install
```

Test the install of the package from the current directory.

## PARAMETERS

### -Install
Test chocolateyInstall.ps1 only.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Nu
If file, path to the .nupkg or .nuspec file for the package.
If directory, latest .nupkg or .nuspec file wil be looked in it.
If ommited current directory will be used.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameters
Package parameters

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Uninstall
Test chocolateyUninstall.ps1 only.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Vagrant
Path to chocolatey-test-environment: https://github.com/majkinetor/chocolatey-test-environment

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: $Env:au_Vagrant
Accept pipeline input: False
Accept wildcard characters: False
```

### -VagrantNoClear
Do not remove existing packages from vagrant package directory

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -VagrantOpen
Open new shell window

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

[https://github.com/chocolatey/choco/wiki/CreatePackages#testing-your-package](https://github.com/chocolatey/choco/wiki/CreatePackages#testing-your-package)

