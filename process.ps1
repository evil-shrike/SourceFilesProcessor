[CmdletBinding()]
Param(
	[Parameter(Position=1)]
	[String]$basePath,
	[String[]]$Include=@("*.cs"),
	[switch]$fixEncoding,
	[switch]$useBom,
	[String]$tfs,
	[String]$addHeader,
	[switch]$removeHeader,
	[switch]$removeComments,
	[String[]]$ignoreFiles=@(),
	[String[]]$ignorePath=@()
)
$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
if (!$basePath)  {
	$basePath = $scriptPath
}
$scriptName = Split-Path $MyInvocation.MyCommand.Definition -Leaf
if (!$fixEncoding -and !$addHeader -and !$removeHeader -and !$removeComments) {
	Write-Host "USAGE: $scriptName [-basePath <path>] [-include <filesmask-list>] [-convertEncoding <encoding>] [-addHeader <path>] [-removeHeader] [-removeComments] [-ignoreFiles <filemask-list>] [-ignorePaht <path-list>]
    where:
        basePath - base path where to search files
        include - mask of files to process, e.g. '*.cs'
        fixEncoding - fix encoding of all files to utf-8 (if it defers)
        addHeader - path to a text file (in utf-8) with a header to add to all files
        removeHeader - remove header from files
        removeComments - remove all comments (only line, not block) and empty lines from file
        ignoreFiles - mask of files to ignore, e.g. 'Resources.cs, *.Design.cs'
        ignorePath - list of pathes to ignore, e.g. '*\bin\*, Demo\*', masks are applied to path relative to basePath
	"
	exit
}

# Using C# port of Mozilla Universal Charset Detector from https://github.com/errepi/ude
Add-Type -Path $scriptPath\Ude.dll

function GetFileEncoding($filePath, $relativePath)  {
	[byte[]]$bytes = get-content -Encoding byte -Path $filePath
	$cdet = new-object -TypeName Ude.CharsetDetector
	$cdet.Feed($bytes, 0, $bytes.Length);
    $cdet.DataEnd();
	return $cdet.Charset
}

function Resolve-RelativePath($path, $fromPath) {
	$path = Resolve-Path $path
	$fromPath = Resolve-Path $fromPath
	$fromUri = new-object -TypeName System.Uri -ArgumentList "$fromPath\"
	$pathUri = new-object -TypeName System.Uri -ArgumentList $path
    return [System.Uri]::UnescapeDataString( $fromUri.MakeRelativeUri($pathUri).ToString().Replace('/', [System.IO.Path]::DirectorySeparatorChar) )
}

if ($addHeader) {
	$headerText = Get-Content $addHeader -Encoding UTF8 -Raw
}
$needProcess = $addHeader -or $removeHeader -or $removeComments

Write-Host "Converting ($Include) files in $basePath" -ForegroundColor DarkGray
Get-ChildItem -Path $basePath -r -Include $Include | ForEach-Object {
	$filePath = $_.fullname
	$relativePath = Resolve-RelativePath $filePath $basePath
	$fileName = $_.name

	# Fitler out files
	if ($ignoreFiles -contains $fileName) {
		Write-Host "Skipping file $fileName" -ForegroundColor DarkGray
		return
	}
	if (($ignorePath | where { $relativePath -like $_}).Length -gt 0) {
		Write-Host "Skipping path $filePath" -ForegroundColor DarkGray
		return
	}
	# in any way we need to read the file, so need to know its encoding

	# Detect encoding
	$enc = GetFileEncoding $filePath $relativePath	
	if ($enc -eq $null) {
		Write-Host "Could not detect encoding in $relativePath" -ForegroundColor Red
		return
	} 

	# File should be proces if: 
	# 	- we need to change file encoding and its encoding is not utf-8 (ASCII is 7bit so actualy it's the same)
	#	- we need to add or remove header
	#	- we need to remove comments
	$needProcessFile = $needProcess
	$needDecodeFile = $false
	if ($fixEncoding -and $enc -ne "UTF-8" -and $enc -ne "ASCII") {
		$needProcessFile = $true
		$needDecodeFile = $true
	}
	if (!$needProcessFile) {
		Write-Host "Skipping $relativePath (encoding: $enc)" -ForegroundColor DarkGray
		return
	}

	# Read file in detected encoding
	$text = ""
	if ($enc -eq "UTF-8") {
		$text = Get-Content $filePath -Encoding UTF8 -Raw
	} else {
		$text = Get-Content $filePath -Encoding Byte -ReadCount 0
		# ugly hack: if not utf-8 then consider ASCII
		$text = [System.Text.Encoding]::GetEncoding(1251).GetString($text)
	}

	# Update file header/comments
	$headerTextOld = ""
	if ($addHeader -or $removeHeader) {
		# Remove all comment lines from the beginning of the file
		$bHeader = $true
		$lines = $text -split "\r\n" | where { 
			if (!$bHeader) { return $true }
			if ($_ -eq "\r\n" -or $_ -eq "\n") { return $false }
			if ($_ -notmatch "^//") {
				$bHeader = $false
				return $true
			}
			$headerTextOld = $headerTextOld + "\r\n" + $_
			return $false
		}
		if ($headerText) {
			# Add new header
			if ($headerText -eq $headerTextOld) {
				# header didn't change
				if (!$removeComments -and !$needDecodeFile) {
					# If no other task with the file, skip it as the header is the same
					Write-Host "Skipping adding header (no change) $relativePath" -ForegroundColor DarkGray
					return
				}
			}
			$lines = @() + $headerText + $lines
		}
		$text = [System.String]::Join([System.Environment]::NewLine, $lines)	
	}
	if ($removeComments) {
		# Remove all comment lines and empty lines
		$lines = $text -split "\r\n" | where { $_ -notmatch "^\s*//" -and $_ -notmatch "\s*\r\n" -and $_ -notmatch "\s*\n" }
		$text = [System.String]::Join([System.Environment]::NewLine, $lines)	
	}

	if ($text) {
		# TFS: check out the file
		if ($tfs) {
			&$tfs checkout $filePath | Out-Null
		}

		# Write it down back as UTF-8
		if($useBom)
		{
			#with BOM
			Out-File -FilePath $filePath -Encoding UTF8 -InputObject $text
		}
		else
		{
			#w/o BOM
			# NOTE: both Set-Content and Out-File write out BOM for UTF8, so we're using .NET method:
			[System.IO.File]::WriteAllText($filePath, $text)
		}
		Write-Host "Updated $relativePath\$fileName"
	}
}
