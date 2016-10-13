# Overview
PowerShell script for executing different tasks with source files (fix encoding, add/remove header and comments).


USAGE:
``` 
powershell.exe ./process.ps1 [-basePath <path>] [-include <filesmask-list>] [-convertEncoding <encoding>] [-addHeader <path>] [-removeHeader] [-removeComments] [-ignoreFiles <filemask-list>] [-ignorePaht <path-list>]
```

## Options

### basePath
Base path where to search files. 
If not specified script folder will be used.

### include 
Mask of files to process, e.g. '*.cs'.

### fixEncoding 
Switch to enable fixing encoding of all files to utf-8 (if it defers).

### addHeader 
A path to a text file (in utf-8) with a header to add to all files.

### removeHeader 
Switch to remove headers from files (comments at top).

### removeComments 
Switch to remove all comments (only line, not block) and empty lines from file.

### ignoreFiles 
Mask of files to ignore.
Example: 'Resources.cs, *.Design.cs'

### ignorePath
A list of pathes to ignore. Masks are applied to path relative to basePath.
Example: "*\bin\*, Demo\*"

## Examples
* Fix encoding in all *.cs (default) files:
```
powershell ./process.ps1 "D:\Work\R-n-D\MyProject\Sources\MyLib\Repo\Src" -fixEncoding
```

* Fix encoding in all *.java files:
```
powershell ./process.ps1 "D:\Work\R-n-D\MyProject\Sources\MyLib\Repo\Src" -fixEncoding -Include *.java
```

* Fix encoding and add header from header.txt, check out files via tf.exe (TFS), 
```
powershell ./process.ps1 "D:\Work\R-n-D\MyProject\Sources\MyLib\Repo\Src" -fixEncoding -addHeader "header.txt" \
	-ignorePath *\Backup\*,*\NotUsed\*
	-ignoreFiles AssemblyInfo.cs
	-tfs """Z:\Prog\Microsoft Visual Studio 12.0\Common7\IDE\TF.exe"""
```
