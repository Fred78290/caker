//
//  WindowsInstallResources.swift
//  Caker
//
//  The scripts the Windows installation media carries. They run inside WinPE, where `cmd.exe` batch files,
//  `diskpart` and `dism` are all there is: no PowerShell, no curl, and no way to show anything on screen
//  (nothing refreshes the virtual display once the firmware hands over to Windows), so every step logs to
//  the media and the host reads the outcome back from `caker\result` once the VM has powered off.
//

import Foundation

enum WindowsInstallResources {
	/// Files on the media are read by Windows tools, which want CRLF line endings.
	static func crlf(_ text: String) -> String {
		text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "\r\n")
	}

	/// Replaces WinPE's default shell (which would start Windows Setup) so the install script runs instead.
	/// Windows Setup would only look for an answer file on removable media, which Virtualization.framework's
	/// USB mass storage doesn't report itself as.
	static let winpeshl = crlf(
		#"""
		[LaunchApps]
		%SYSTEMDRIVE%\Windows\System32\wpeinit.exe
		%SYSTEMDRIVE%\Windows\System32\cmd.exe, /c %SYSTEMDRIVE%\Windows\System32\pe.cmd
		"""#)

	/// Finds the installation media (the volume holding `caker\media.id`, which gets a drive letter some
	/// seconds after WinPE starts), runs its install script, then powers the VM off either way.
	static let peScript = crlf(
		#"""
		@echo off
		set M=
		set /a N=0
		:media
		for %%d in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do if exist %%d:\caker\media.id set M=%%d:
		if defined M goto found
		set /a N+=1
		if %N% geq 150 goto done
		ping -n 3 127.0.0.1 >nul
		goto media
		:found
		call %M%\caker\install.cmd %M%
		:done
		wpeutil shutdown
		"""#)

	/// Partitions the empty system disk, applies the Windows image, adds the virtio drivers and the boot files.
	static let installScript = crlf(
		#"""
		@echo off
		rem Installs Windows from WinPE: install.cmd <installation media drive>, e.g. install.cmd C:
		setlocal EnableExtensions
		set M=%1
		set T=%M%\caker
		set LOG=%T%\install.log
		echo [%time%] start > %LOG%
		call %T%\config.cmd
		call :say Installing Windows

		rem The target is the only disk without partitions (the installation media always has some).
		rem diskpart's output is localized, so rely on exit codes: selecting a partition fails on an empty disk.
		set N=0
		for /l %%d in (0,1,7) do (
		  > X:\probe.txt echo select disk %%d
		  diskpart /s X:\probe.txt >nul 2>&1 && (
		    >> X:\probe.txt echo select partition 1
		    diskpart /s X:\probe.txt >nul 2>&1 || (set DISK=%%d& set /a N+=1)
		  )
		)
		if not "%N%"=="1" (call :say expected exactly one empty disk, found %N% & goto fail)
		call :say Target disk %DISK%

		(
		echo select disk %DISK%
		echo clean
		echo convert gpt
		echo create partition efi size=260
		echo format quick fs=fat32 label=System
		echo assign letter=S
		echo create partition msr size=16
		echo create partition primary
		echo format quick fs=ntfs label=Windows
		echo assign letter=W
		) > X:\partition.txt
		call :say Partitioning the disk
		diskpart /s X:\partition.txt >> %LOG% 2>&1 || goto fail

		set WIM=%M%\sources\install.wim
		if not exist %WIM% set WIM=%M%\sources\install.esd
		call :say Applying the Windows image (%IMAGE%), this takes a few minutes
		dism /Apply-Image /ImageFile:%WIM% %IMAGE% /ApplyDir:W:\
		set RESULT=%errorlevel%
		copy /y X:\Windows\Logs\DISM\dism.log %T%\dism.log >nul 2>&1
		if not "%RESULT%"=="0" goto fail

		call :say Adding the virtio drivers
		dism /Image:W:\ /Add-Driver /Driver:%T%\drivers /Recurse
		set RESULT=%errorlevel%
		copy /y X:\Windows\Logs\DISM\dism.log %T%\dism.log >nul 2>&1
		if not "%RESULT%"=="0" goto fail

		mkdir W:\Windows\Panther W:\Windows\Setup\Scripts 2>nul
		copy /y %T%\unattend.xml W:\Windows\Panther\unattend.xml >> %LOG% || goto fail
		copy /y %T%\SetupComplete.cmd W:\Windows\Setup\Scripts\SetupComplete.cmd >> %LOG% || goto fail

		call :say Writing the boot files
		bcdboot W:\Windows /s S: /f UEFI >> %LOG% 2>&1 || goto fail
		mkdir S:\EFI\caker 2>nul
		copy /y %T%\framebuffer.efi S:\EFI\caker\framebuffer.efi >> %LOG% || goto fail
		rem Windows Boot Manager moves to windows.efi and the loader takes its place at the removable media path,
		rem so the framebuffer driver is up before Windows starts (see EFI\loader.c).
		mkdir S:\EFI\BOOT 2>nul
		copy /y S:\EFI\Microsoft\Boot\bootmgfw.efi S:\EFI\BOOT\windows.efi >> %LOG% || goto fail
		copy /y %T%\loader.efi S:\EFI\BOOT\BOOTAA64.EFI >> %LOG% || goto fail

		call :say Done, powering off
		echo OK> %T%\result
		goto end

		:fail
		call :say Installation failed
		echo FAILED> %T%\result

		:end
		exit /b 0

		rem Shows a progress line and keeps it in the log
		:say
		echo %*
		echo [%time%] %* >> %LOG%
		exit /b 0
		"""#)

	/// Runs once as SYSTEM when the installed Windows finishes setting itself up. It leaves a marker on the
	/// EFI system partition (a FAT32 volume the host can read) and powers the VM off, which is how the host
	/// knows first boot is over: Virtualization.framework stops a VM whose guest reboots, so a stop alone says
	/// nothing about whether setup is complete.
	static let setupComplete = crlf(
		#"""
		@echo off
		powercfg /hibernate off
		mountvol S: /S
		mkdir S:\EFI\caker 2>nul
		echo done> S:\EFI\caker\installed
		mountvol S: /D
		shutdown /s /t 5 /c "caker: Windows installation complete"
		"""#)

	/// The answer file for the installed system: a local administrator account that logs on automatically,
	/// and no out-of-box experience. `language` is the image's default (e.g. `en-US`).
	static func unattend(username: String, password: String, computerName: String, language: String) -> String {
		func escaped(_ value: String) -> String {
			value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
		}

		return crlf(
			"""
			<?xml version="1.0" encoding="utf-8"?>
			<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
			  <settings pass="specialize">
			    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			      <ComputerName>\(escaped(computerName))</ComputerName>
			      <TimeZone>UTC</TimeZone>
			    </component>
			  </settings>
			  <settings pass="oobeSystem">
			    <component name="Microsoft-Windows-International-Core" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			      <InputLocale>\(escaped(language))</InputLocale>
			      <SystemLocale>\(escaped(language))</SystemLocale>
			      <UILanguage>\(escaped(language))</UILanguage>
			      <UserLocale>\(escaped(language))</UserLocale>
			    </component>
			    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
			      <OOBE>
			        <HideEULAPage>true</HideEULAPage>
			        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
			        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
			        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
			        <HideLocalAccountScreen>true</HideLocalAccountScreen>
			        <ProtectYourPC>3</ProtectYourPC>
			        <SkipMachineOOBE>true</SkipMachineOOBE>
			        <SkipUserOOBE>true</SkipUserOOBE>
			      </OOBE>
			      <UserAccounts>
			        <LocalAccounts>
			          <LocalAccount wcm:action="add">
			            <Name>\(escaped(username))</Name>
			            <Group>Administrators</Group>
			            <Password>
			              <Value>\(escaped(password))</Value>
			              <PlainText>true</PlainText>
			            </Password>
			          </LocalAccount>
			        </LocalAccounts>
			      </UserAccounts>
			      <AutoLogon>
			        <Enabled>true</Enabled>
			        <LogonCount>1</LogonCount>
			        <Username>\(escaped(username))</Username>
			        <Password>
			          <Value>\(escaped(password))</Value>
			          <PlainText>true</PlainText>
			        </Password>
			      </AutoLogon>
			    </component>
			  </settings>
			</unattend>
			""")
	}

	/// `set IMAGE=...` for install.cmd: which edition of install.wim to apply.
	static func config(imageIndex: Int) -> String {
		crlf("@echo off\nset IMAGE=/Index:\(imageIndex)\n")
	}
}
