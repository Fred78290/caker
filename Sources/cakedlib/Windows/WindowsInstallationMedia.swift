//
//  WindowsInstallationMedia.swift
//  Caker
//
//  Turns a Windows installation ISO into a disk image a Virtualization.framework VM can boot and install from.
//
//  Why the ISO can't be attached as is: it carries no partition table, only an El Torito boot record, which
//  firmware reads on optical media but not on the 512-byte-sector USB disk a VM gets. So the image is a GPT
//  disk with:
//   - a FAT32 partition typed as EFI system partition, holding the ISO's files except install.wim (which is
//     over 4 GB, FAT32's file size limit). `EFI\BOOT\BOOT<arch>.EFI` is replaced by our loader (see
//     EFI/loader.c) and Windows Boot Manager moved next to it as `windows.efi`, unless the guest does without the
//     framebuffer helpers (see WindowsArchitecture.usesFramebufferShim); and
//   - an exFAT partition holding install.wim, the virtio drivers and the `caker` folder with the install
//     scripts. WinPE gives that volume a drive letter, which it doesn't for the (hidden) system partition.
//
//  WinPE's own boot.wim is edited (see WIMArchive) so its shell runs our script instead of Windows Setup.
//

import Foundation

public struct WindowsInstallationMedia {
	/// What the cakeagent service needs: the Windows build of the agent and the certificates it authenticates clients with.
	struct CakeAgent {
		var executable: URL
		var caCert: URL
		var serverCert: URL
		var serverKey: URL
	}

	/// The OpenSSH server (Win32-OpenSSH): Windows 11 ships the client only, and the server is a Feature on Demand that
	/// needs Windows Update, so it goes on the media and `SetupComplete.cmd` installs it from there.
	struct OpenSSH {
		/// Win32-OpenSSH's release archive for the guest's architecture.
		var archive: URL
		/// Public keys allowed to log in as an administrator (`administrators_authorized_keys`).
		var authorizedKeys: [String]
	}

	struct Options {
		var username: String
		var password: String
		var computerName: String
		/// Applied by the answer file (the `WINDOWS_KEY` provisioning variable), validated by `validatedProductKey(_:)`.
		var productKey: String?
		/// The display driver's frame segment (MiB) asked for, validated by `validatedFrameSegmentMiB(_:)`; nil keeps the INF's.
		var frameSegmentMiB: Int?
		/// Whether the media carries the sound driver (`WindowsAudioDriverBinaries`); the `WINDOWS_AUDIO` provisioning variable,
		/// validated by `validatedAudio(_:)`.
		var audioDriver: Bool = true
		/// Whether Windows logs the account on at every start (the `WINDOWS_AUTOLOGON` provisioning variable), not only the first
		/// one; validated by `validatedAutologon(_:)`.
		var autologon: Bool = false
		/// Only drivers Microsoft signed (the `WINDOWS_WHQL_ONLY` provisioning variable, `validatedWhqlOnly(_:)`): virtio-win's
		/// own, with no caker driver, no sound and no test-signing mode. Overrides `audioDriver` and `frameSegmentMiB`.
		var whqlDriversOnly: Bool = false
		/// Installed as a service on first boot when set.
		var cakeAgent: CakeAgent?
		/// Installed and started on first boot when set.
		var openSSH: OpenSSH?
	}

	/// The name of the provisioning variable (`--var WINDOWS_KEY=...`) that carries the product key.
	public static let productKeyVariable = "WINDOWS_KEY"

	/// Returns the product key to put in the answer file, nil when there is none (unset or blank). A key that isn't
	/// five groups of five letters/digits is refused: Windows would stop on an error dialog nobody can see, in the middle
	/// of an unattended setup. The key itself is never logged.
	public static func validatedProductKey(_ value: String?) throws -> String? {
		guard let key = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), key.isEmpty == false else {
			return nil
		}

		let groups = key.split(separator: "-", omittingEmptySubsequences: false)

		guard groups.count == 5, groups.allSatisfy({ $0.count == 5 && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } }) else {
			throw ServiceError(String(localized: "The Windows product key in WINDOWS_KEY is not valid: expected XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"))
		}

		return key
	}

	public static func productKeyIsValid(_ value: String?) -> Bool {
		return (try? validatedProductKey(value)) != nil
	}

	/// The name of the provisioning variable (`--var WINDOWS_FRAME_SEGMENT_MIB=64`) that sets the display driver's frame
	/// segment, which bounds the display size (see `WindowsDisplayLimit`).
	public static let frameSegmentVariable = "WINDOWS_FRAME_SEGMENT_MIB"

	/// What the driver accepts for `MinFrameSegmentSizeMiB`.
	public static let frameSegmentRangeMiB = 16...256

	/// What caker's INF sets (see `WindowsGPUDriverBinaries.frameSegmentMiB`), so what a guest has when none is asked for.
	public static let defaultFrameSegmentMiB = 64

	/// The sizes the VM wizard offers, in MiB, all inside `frameSegmentRangeMiB`.
	public static let frameSegmentChoicesMiB = [16, 32, 48, 64, 96, 128, 192, 256]

	/// Returns the frame segment (MiB) to set, nil when there is none (unset or blank: the INF's value is kept). A value
	/// outside `frameSegmentRangeMiB` is refused rather than clamped: the driver would ignore it and the display would
	/// not be the size asked for.
	public static func validatedFrameSegmentMiB(_ value: String?) throws -> Int? {
		guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false else {
			return nil
		}

		guard let mib = Int(text), frameSegmentRangeMiB.contains(mib) else {
			throw ServiceError(String(format: String(localized: "The frame segment size in WINDOWS_FRAME_SEGMENT_MIB is not valid: expected %d to %d MiB"), frameSegmentRangeMiB.lowerBound, frameSegmentRangeMiB.upperBound))
		}

		return mib
	}

	/// The name of the provisioning variable (`--var WINDOWS_AUDIO=0`) that leaves the sound driver (`Tools/WindowsAudioDriver`)
	/// out. It is on by default: it only binds to Virtualization.framework's sound device, and what it needs (a trusted
	/// test certificate, test-signing mode) is already there for the GPU driver.
	public static let audioVariable = "WINDOWS_AUDIO"

	/// Returns whether the sound driver goes on the media: unset or blank is yes, `0`/`false`/`no`/`off` is no. Anything
	/// else is refused rather than guessed.
	public static func validatedAudio(_ value: String?) throws -> Bool {
		guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), text.isEmpty == false else {
			return true
		}

		switch text {
		case "1", "true", "yes", "on": return true
		case "0", "false", "no", "off": return false
		default:
			throw ServiceError(String(localized: "The value of WINDOWS_AUDIO is not valid: expected 1 or 0"))
		}
	}

	/// The name of the provisioning variable (`--var WINDOWS_AUTOLOGON=1`) that makes Windows log the account on by itself at
	/// every start. Off by default: the answer file always logs on once, to finish setup, and after that the lock screen
	/// waits for the password. It matters when something has to run in the user's session at boot, like the agent's display
	/// helper, which follows the host's window size and only works while someone is logged on. The password is kept in
	/// the guest's registry in clear text (Winlogon's `DefaultPassword`), as for any automatic logon.
	public static let autologonVariable = "WINDOWS_AUTOLOGON"

	/// How many logons the answer file allows (`AutoLogon/LogonCount`, 0 to 999): one finishes setup, the maximum is as
	/// close to "always" as the answer file gets.
	static let autologonForeverCount = 999

	/// Returns whether the account stays logged on automatically: unset or blank is no, `1`/`true`/`yes`/`on` is yes.
	/// Anything else is refused rather than guessed.
	public static func validatedAutologon(_ value: String?) throws -> Bool {
		guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), text.isEmpty == false else {
			return false
		}

		switch text {
		case "1", "true", "yes", "on": return true
		case "0", "false", "no", "off": return false
		default:
			throw ServiceError(String(localized: "The value of WINDOWS_AUTOLOGON is not valid: expected 1 or 0"))
		}
	}

	/// The name of the provisioning variable (`--var WINDOWS_WHQL_ONLY=1`) that installs only drivers signed by Microsoft
	/// (WHQL): the ones on the virtio-win ISO, which Red Hat signs. Caker's own drivers (`Tools/WindowsGPUDriver`,
	/// `Tools/WindowsAudioDriver`) are test-signed, which needs a throwaway certificate trusted in the guest and
	/// test-signing mode ("Test Mode" watermark); with this variable none of that is installed. The price: the stock
	/// display driver shows a corrupted picture when Virtualization.framework changes the display size, so the guest
	/// keeps its size (`displayRefit` is turned off and the view scales it), and there is no sound, because Windows
	/// has no signed driver for Virtualization.framework's sound device. Off by default.
	public static let whqlOnlyVariable = "WINDOWS_WHQL_ONLY"

	/// Returns whether only WHQL-signed drivers are installed: unset or blank is no, `1`/`true`/`yes`/`on` is yes.
	/// Anything else is refused rather than guessed.
	public static func validatedWhqlOnly(_ value: String?) throws -> Bool {
		guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), text.isEmpty == false else {
			return false
		}

		switch text {
		case "1", "true", "yes", "on": return true
		case "0", "false", "no", "off": return false
		default:
			throw ServiceError(String(localized: "The value of WINDOWS_WHQL_ONLY is not valid: expected 1 or 0"))
		}
	}

	struct InstallResult {
		let succeeded: Bool
		let log: String
	}

	/// Where the virtio-win driver ISO comes from (the Fedora project's stable build, which Red Hat signs).
	static let virtioWinURL = URL(string: "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso")!

	/// WinFsp, which the virtio-fs service needs to present the host's shared folders. Pinned: it runs as SYSTEM.
	static let winFspURL = URL(string: "https://github.com/winfsp/winfsp/releases/download/v2.1/winfsp-2.1.25156.msi")!
	static let winFspSHA256 = "073a70e00f77423e34bed98b86e600def93393ba5822204fac57a29324db9f7a"

	/// Win32-OpenSSH's release, whose archives are pinned by hash because they run as SYSTEM. The digests are the
	/// ones GitHub publishes for the release assets.
	static let openSSHRelease = "10.0.0.0p2-Preview"

	static func openSSHArchive(for architecture: WindowsArchitecture) -> (url: URL, sha256: String) {
		let name: String
		let sha256: String

		switch architecture {
		case .arm64:
			name = "OpenSSH-ARM64.zip"
			sha256 = "698c6aec31c1dd0fb996206e8741f4531a97355686b5431ef347d531b07fcd42"
		case .amd64:
			name = "OpenSSH-Win64.zip"
			sha256 = "23f50f3458c4c5d0b12217c6a5ddfde0137210a30fa870e98b29827f7b43aba5"
		}

		return (URL(string: "https://github.com/PowerShell/Win32-OpenSSH/releases/download/\(openSSHRelease)/\(name)")!, sha256)
	}

	/// Unzips a Win32-OpenSSH archive into `folder`: the archive has one top-level folder (`OpenSSH-ARM64`,
	/// `OpenSSH-Win64`) holding `sshd.exe` and the scripts, and its content is what lands in `folder`.
	static func extractOpenSSH(_ archive: URL, to folder: URL) throws {
		let fileManager = FileManager.default
		let scratch = fileManager.temporaryDirectory.appendingPathComponent("openssh-\(UUID().uuidString)", isDirectory: true)

		try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
		defer { try? fileManager.removeItem(at: scratch) }

		_ = try Process.capture("/usr/bin/unzip", ["-q", "-o", archive.path, "-d", scratch.path])

		let top = try fileManager.contentsOfDirectory(at: scratch, includingPropertiesForKeys: nil).filter { $0.lastPathComponent != "__MACOSX" }
		let root = top.count == 1 && top[0].hasDirectoryPath ? top[0] : scratch

		guard fileManager.fileExists(atPath: root.appendingPathComponent("sshd.exe").path) else {
			throw ServiceError(String(localized: "The OpenSSH archive has no sshd.exe"))
		}

		try fileManager.moveItem(at: root, to: folder)
	}

	/// Driver folders to take from the virtio-win ISO: display (so the screen works once Windows has taken over from
	/// the firmware), network and shared folders. Windows has an inbox NVMe and USB driver, so storage needs nothing.
	static let virtioDrivers = ["viostor", "viogpudo", "NetKVM", "viorng", "viofs", "viosock"]

	private static let bootPartitionSize = "1700m"
	private static let efiSystemPartitionType = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"

	let url: URL

	// MARK: - Creating the media

	/// Checks that `isoRoot` is a Windows installation ISO the host can install, and returns the guest's architecture.
	@discardableResult
	static func validate(isoRoot: URL, name: String, host: WindowsArchitecture = .host) throws -> WindowsArchitecture {
		let exists = { (path: String) in FileManager.default.fileExists(atPath: isoRoot.appendingPathComponent(path).path) }

		if !exists("sources/install.wim") && !exists("sources/install.esd") {
			throw ServiceError(String(format: String(localized: "%@ is not a Windows installation ISO"), name))
		}

		return try WindowsArchitecture.detect(name: name, host: host, exists: exists)
	}

	static func create(at url: URL, windowsISO: URL, virtioWinISO: URL, winFspMSI: URL, options: Options, progress: (String) -> Void) throws -> WindowsInstallationMedia {
		let fileManager = FileManager.default
		progress(String(localized: "Reading the Windows installation ISO"))

		let isoMount = try attachISO(windowsISO)
		defer { detachISO(isoMount) }

		let architecture = try validate(isoRoot: isoMount, name: windowsISO.lastPathComponent)

		let installImage = ["install.wim", "install.esd"].map { isoMount.appendingPathComponent("sources/\($0)") }.first { fileManager.fileExists(atPath: $0.path) }!
		let images = try WIMArchive(url: installImage).images()

		guard let image = images.first(where: { $0.name == "Windows 11 Pro" }) ?? images.first else {
			throw ServiceError(String(localized: "The Windows installation ISO has no image to install"))
		}

		// install.wim goes on the exFAT partition; leave room for the drivers and the file system's own overhead
		let installImageSize = try installImage.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
		let mebibyte: UInt64 = 1024 * 1024
		let unaligned = UInt64(1700 + 400) * mebibyte + UInt64(installImageSize) + 256 * mebibyte
		// Virtualization.framework refuses a disk image whose size isn't a multiple of the sector size
		let imageSize = (unaligned + mebibyte - 1) / mebibyte * mebibyte

		progress(String(localized: "Creating the installation disk"))

		try? fileManager.removeItem(at: url)
		fileManager.createFile(atPath: url.path, contents: nil)

		let handle = try FileHandle(forWritingTo: url)

		try handle.truncate(atOffset: imageSize)
		try handle.close()

		do {
			try populate(url, architecture: architecture, isoRoot: isoMount, installImage: installImage, image: image, virtioWinISO: virtioWinISO, winFspMSI: winFspMSI, options: options, progress: progress)
			try setEFISystemPartition(of: url, partition: 2)
		} catch {
			try? fileManager.removeItem(at: url)
			throw error
		}

		return WindowsInstallationMedia(url: url)
	}

	private static func populate(_ url: URL, architecture: WindowsArchitecture, isoRoot: URL, installImage: URL, image: WIMArchive.ImageInfo, virtioWinISO: URL, winFspMSI: URL, options: Options, progress: (String) -> Void) throws {
		let device = try Disk.attach(url, readOnly: false, raw: true)

		defer { Disk.detach(device) }

		_ = try Process.capture("/usr/sbin/diskutil", ["partitionDisk", device, "GPT", "MS-DOS FAT32", "WINBOOT", bootPartitionSize, "ExFAT", "WINSRC", "R"])

		// partitionDisk makes a 200 MB EFI partition first, so the two volumes are partitions 2 and 3
		let bootVolume = try Disk.mount("\(device)s2")
		let sourceVolume = try Disk.mount("\(device)s3")

		progress(String(localized: "Copying the Windows installation files"))

		_ = try Process.capture("/usr/bin/rsync", ["-rt", "--exclude=sources/install.wim", "--exclude=sources/install.esd", isoRoot.path + "/", bootVolume.path + "/"])

		let sources = sourceVolume.appendingPathComponent("sources", isDirectory: true)

		try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
		try FileManager.default.copyItem(at: installImage, to: sources.appendingPathComponent(installImage.lastPathComponent))

		progress(String(localized: "Preparing the Windows installer"))

		// WinPE's shell: the install script instead of Windows Setup. The files go into System32, which is always
		// on the PATH and in the RAM disk WinPE boots from.
		let boot = try WIMArchive(url: bootVolume.appendingPathComponent("sources/boot.wim"))

		try boot.addFiles(
			[
				("winpeshl.ini", Data(WindowsInstallResources.winpeshl.utf8)),
				("pe.cmd", Data(WindowsInstallResources.peScript.utf8)),
			], toDirectory: ["Windows", "System32"], ofImage: boot.bootIndex)

		// Our loader starts the framebuffer driver, then Windows Boot Manager
		if architecture.usesFramebufferShim {
			let efiBoot = bootVolume.appendingPathComponent("efi/boot", isDirectory: true)
			let efiCaker = bootVolume.appendingPathComponent("efi/caker", isDirectory: true)

			try FileManager.default.moveItem(at: efiBoot.appendingPathComponent(architecture.bootFile), to: efiBoot.appendingPathComponent("windows.efi"))
			try WindowsEFIBinaries.loader(for: architecture).write(to: efiBoot.appendingPathComponent(architecture.bootFile))
			try FileManager.default.createDirectory(at: efiCaker, withIntermediateDirectories: true)
			try WindowsEFIBinaries.framebuffer(for: architecture).write(to: efiCaker.appendingPathComponent("framebuffer.efi"))
		}

		// The install script and what it installs
		let caker = sourceVolume.appendingPathComponent("caker", isDirectory: true)
		let drivers = caker.appendingPathComponent("drivers", isDirectory: true)

		try FileManager.default.createDirectory(at: drivers, withIntermediateDirectories: true)
		try Data("caker".utf8).write(to: caker.appendingPathComponent("media.id"))
		try WindowsInstallResources.installScript(for: architecture, whqlOnly: options.whqlDriversOnly).write(to: caker.appendingPathComponent("install.cmd"), atomically: true, encoding: .utf8)
		try WindowsInstallResources.setupComplete.write(to: caker.appendingPathComponent("SetupComplete.cmd"), atomically: true, encoding: .utf8)
		try WindowsInstallResources.config(imageIndex: image.index).write(to: caker.appendingPathComponent("config.cmd"), atomically: true, encoding: .utf8)
		try WindowsInstallResources.unattend(username: options.username, password: options.password, computerName: options.computerName, language: image.language, architecture: architecture, productKey: options.productKey, autologon: options.autologon).write(to: caker.appendingPathComponent("unattend.xml"), atomically: true, encoding: .utf8)

		if architecture.usesFramebufferShim {
			try WindowsEFIBinaries.framebuffer(for: architecture).write(to: caker.appendingPathComponent("framebuffer.efi"))
			try WindowsEFIBinaries.loader(for: architecture).write(to: caker.appendingPathComponent("loader.efi"))
		}

		progress(String(localized: "Copying the virtio drivers"))

		let virtioMount = try attachISO(virtioWinISO)
		defer { detachISO(virtioMount) }

		for driver in virtioDrivers {
			let folder = virtioMount.appendingPathComponent("\(driver)/w11/\(architecture.virtioFolder)", isDirectory: true)

			guard FileManager.default.fileExists(atPath: folder.path) else {
				throw ServiceError(String(format: String(localized: "The virtio-win ISO has no %@ driver for %@"), driver, architecture.displayName))
			}

			try FileManager.default.copyItem(at: folder, to: drivers.appendingPathComponent(driver.lowercased(), isDirectory: true))

			// Debug symbols are most of the size and Windows doesn't need them
			for case let file as URL in FileManager.default.enumerator(at: drivers.appendingPathComponent(driver.lowercased()), includingPropertiesForKeys: nil)! where file.pathExtension.lowercased() == "pdb" {
				try? FileManager.default.removeItem(at: file)
			}
		}

		// The GPU driver: caker's build (Tools/WindowsGPUDriver) replaces virtio-win's, and the certificate it is signed with
		// goes along for SetupComplete.cmd to trust
		if architecture.usesCakerGPUDriver && options.whqlDriversOnly == false {
			let gpu = drivers.appendingPathComponent("viogpudo", isDirectory: true)

			try? FileManager.default.removeItem(at: gpu)
			try FileManager.default.createDirectory(at: gpu, withIntermediateDirectories: true)

			let driver = WindowsGPUDriverBinaries.package(for: architecture)

			try driver.sys.write(to: gpu.appendingPathComponent("viogpudo.sys"))
			try driver.inf.write(to: gpu.appendingPathComponent("viogpudo.inf"))
			try driver.cat.write(to: gpu.appendingPathComponent("viogpudo.cat"))
			try driver.certificate.write(to: caker.appendingPathComponent("caker-test-signing.cer"))
		}

		// The sound driver (Tools/WindowsAudioDriver): Windows has none for Virtualization.framework's virtio-snd device
		if options.audioDriver && options.whqlDriversOnly == false {
			let audio = drivers.appendingPathComponent("viosnd", isDirectory: true)

			try? FileManager.default.removeItem(at: audio)
			try FileManager.default.createDirectory(at: audio, withIntermediateDirectories: true)

			let driver = WindowsAudioDriverBinaries.package(for: architecture)

			try driver.sys.write(to: audio.appendingPathComponent("viosnd.sys"))
			try driver.inf.write(to: audio.appendingPathComponent("viosnd.inf"))
			try driver.cat.write(to: audio.appendingPathComponent("viosnd.cat"))
			try driver.certificate.write(to: caker.appendingPathComponent("caker-audio-test-signing.cer"))
		}

		// The virtio-fs service (it's an .exe next to the driver, not part of the driver package) and WinFsp
		let viofs = virtioMount.appendingPathComponent("viofs/w11/\(architecture.virtioFolder)/virtiofs.exe")

		guard FileManager.default.fileExists(atPath: viofs.path) else {
			throw ServiceError(String(format: String(localized: "The virtio-win ISO has no virtio-fs service for %@"), architecture.displayName))
		}

		try FileManager.default.copyItem(at: viofs, to: caker.appendingPathComponent("virtiofs.exe"))

		try FileManager.default.copyItem(at: winFspMSI, to: caker.appendingPathComponent("winfsp.msi"))

		// The install script copies it to the installed system, where setup puts it in the driver's key
		if let frameSegmentMiB = options.frameSegmentMiB, options.whqlDriversOnly == false {
			try "\(frameSegmentMiB)\r\n".write(to: caker.appendingPathComponent("frame-segment.txt"), atomically: true, encoding: .utf8)
		}

		if let openSSH = options.openSSH {
			try extractOpenSSH(openSSH.archive, to: caker.appendingPathComponent("openssh", isDirectory: true))

			if openSSH.authorizedKeys.isEmpty == false {
				try (openSSH.authorizedKeys.joined(separator: "\n") + "\n").write(to: caker.appendingPathComponent("authorized_keys"), atomically: true, encoding: .utf8)
			}
		}

		if let agent = options.cakeAgent {
			let certs = caker.appendingPathComponent("certs", isDirectory: true)

			try FileManager.default.createDirectory(at: certs, withIntermediateDirectories: true)
			try FileManager.default.copyItem(at: agent.executable, to: caker.appendingPathComponent("cakeagent.exe"))
			try FileManager.default.copyItem(at: agent.caCert, to: certs.appendingPathComponent("ca.pem"))
			try FileManager.default.copyItem(at: agent.serverCert, to: certs.appendingPathComponent("server.pem"))
			try FileManager.default.copyItem(at: agent.serverKey, to: certs.appendingPathComponent("server.key"))
		}

		// macOS keeps extended attributes on FAT and exFAT in "._" files, which DISM trips over when it
		// looks for *.inf files
		for volume in [bootVolume, sourceVolume] {
			_ = try? Process.capture("/usr/sbin/dot_clean", ["-m", volume.path])
		}
	}

	// MARK: - Reading the outcome

	/// What the installer left on the media: `result` is `OK` on success, and `install.log` says how far it got.
	func installResult() throws -> InstallResult {
		let device = try Disk.attach(self.url, readOnly: true, raw: true)

		defer { Disk.detach(device) }

		let volume = try Disk.mount("\(device)s3", readOnly: true)
		let caker = volume.appendingPathComponent("caker", isDirectory: true)
		let result = (try? String(contentsOf: caker.appendingPathComponent("result"), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
		let log = (try? String(contentsOf: caker.appendingPathComponent("install.log"), encoding: .isoLatin1)) ?? ""

		return InstallResult(succeeded: result == "OK", log: log)
	}

	// MARK: - Mounting

	private static func attachISO(_ iso: URL) throws -> URL {
		let mountPoint = FileManager.default.temporaryDirectory.appendingPathComponent("caker-iso-\(UUID().uuidString)", isDirectory: true)

		try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
		_ = try Process.capture("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-mountpoint", mountPoint.path, iso.path])

		return mountPoint
	}

	private static func detachISO(_ mountPoint: URL) {
		_ = try? Process.capture("/usr/bin/hdiutil", ["detach", mountPoint.path])
		try? FileManager.default.removeItem(at: mountPoint)
	}

	// MARK: - GPT

	/// Retypes a partition as an EFI system partition: firmware looks for its boot files there. (`diskutil` can't set
	/// the type of an exFAT or FAT32 partition it creates, which comes out as plain "Microsoft Basic Data".) WinPE
	/// then hides the partition, which is wanted: the installer's files are on the other one.
	static func setEFISystemPartition(of url: URL, partition: Int) throws {
		let sectorSize = 512
		let handle = try FileHandle(forUpdating: url)

		defer { try? handle.close() }

		func read(_ offset: Int, _ count: Int) throws -> Data {
			try handle.seek(toOffset: UInt64(offset))
			return try handle.read(upToCount: count) ?? Data()
		}

		func write(_ data: Data, at offset: Int) throws {
			try handle.seek(toOffset: UInt64(offset))
			try handle.write(contentsOf: data)
		}

		func updateTable(headerLBA: Int) throws {
			var header = try read(headerLBA * sectorSize, 92)

			guard header.count == 92, header.prefix(8) == Data("EFI PART".utf8) else {
				throw ServiceError(String(localized: "The installation disk has no GPT"))
			}

			let entriesLBA = Int(header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 72, as: UInt64.self) })
			let entryCount = Int(header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 80, as: UInt32.self) })
			let entrySize = Int(header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 84, as: UInt32.self) })

			guard partition >= 1, partition <= entryCount else {
				throw ServiceError(String(localized: "The installation disk has no such partition"))
			}

			var entries = try read(entriesLBA * sectorSize, entryCount * entrySize)
			let uuid = UUID(uuidString: efiSystemPartitionType)!.uuid
			let guid = withUnsafeBytes(of: uuid) { Array($0) }
			// GPT stores the first three GUID fields little-endian
			let diskGUID = Data([guid[3], guid[2], guid[1], guid[0], guid[5], guid[4], guid[7], guid[6]] + guid[8...])
			let start = (partition - 1) * entrySize

			entries.replaceSubrange(start..<(start + 16), with: diskGUID)
			try write(entries, at: entriesLBA * sectorSize)

			header.replaceSubrange(88..<92, with: withUnsafeBytes(of: CRC32.checksum(entries).littleEndian) { Data($0) })
			header.replaceSubrange(16..<20, with: Data(count: 4))
			header.replaceSubrange(16..<20, with: withUnsafeBytes(of: CRC32.checksum(header).littleEndian) { Data($0) })
			try write(header, at: headerLBA * sectorSize)
		}

		let primary = try read(sectorSize, 92)

		guard primary.count == 92 else {
			throw ServiceError(String(localized: "The installation disk has no GPT"))
		}

		let backupLBA = Int(primary.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 32, as: UInt64.self) })

		try updateTable(headerLBA: 1)
		try updateTable(headerLBA: backupLBA)
	}
}

// MARK: - Helpers

extension WindowsInstallationMedia {
	enum Disk {
		/// Attaches a disk image without mounting it and returns its whole-disk device (`/dev/diskN`).
		/// `raw` is for a plain disk file such as the installation media; `diskutil image attach` only attaches
		/// formats it can recognize (like the ASIF system disk) and calls an unformatted raw file damaged.
		static func attach(_ url: URL, readOnly: Bool, raw: Bool = false) throws -> String {
			let output: String

			if raw {
				output = try Process.capture("/usr/bin/hdiutil", ["attach", "-imagekey", "diskimage-class=CRawDiskImage", "-nomount"] + (readOnly ? ["-readonly"] : []) + [url.path])
			} else {
				output = try Process.capture("/usr/sbin/diskutil", ["image", "attach", "--noMount"] + (readOnly ? ["--readOnly"] : []) + [url.path])
			}

			guard let device = output.split(separator: "\n").compactMap({ $0.split(whereSeparator: { $0 == " " || $0 == "\t" }).first }).first(where: { $0.hasPrefix("/dev/disk") }) else {
				throw ServiceError(String(format: String(localized: "Can't attach %@"), url.lastPathComponent))
			}

			return String(device)
		}

		static func mount(_ device: String, readOnly: Bool = false) throws -> URL {
			func mountPoint() throws -> String? {
				let plist = try Process.capture("/usr/sbin/diskutil", ["info", "-plist", device])

				guard let info = try PropertyListSerialization.propertyList(from: Data(plist.utf8), format: nil) as? [String: Any], let mountPoint = info["MountPoint"] as? String, mountPoint.isEmpty == false else {
					return nil
				}

				return mountPoint
			}

			if let mounted = try mountPoint() {
				return URL(fileURLWithPath: mounted)
			}

			_ = try Process.capture("/usr/sbin/diskutil", readOnly ? ["mount", "readOnly", device] : ["mount", device])

			guard let mounted = try mountPoint() else {
				throw ServiceError(String(format: String(localized: "Can't mount %@"), device))
			}

			return URL(fileURLWithPath: mounted)
		}

		static func detach(_ device: String) {
			_ = try? Process.capture("/usr/sbin/diskutil", ["unmountDisk", "force", device])
			_ = try? Process.capture("/usr/sbin/diskutil", ["eject", device])
		}
	}
}

/// CRC-32 (IEEE 802.3), the checksum GPT headers and partition entry arrays carry.
enum CRC32 {
	private static let table: [UInt32] = (0..<256).map { value in
		var crc = UInt32(value)

		for _ in 0..<8 {
			crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
		}

		return crc
	}

	static func checksum(_ data: Data) -> UInt32 {
		var crc: UInt32 = 0xFFFF_FFFF

		for byte in data {
			crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
		}

		return crc ^ 0xFFFF_FFFF
	}
}

extension Process {
	/// Runs a tool to completion and returns its standard output; a failure carries what the tool printed.
	@discardableResult
	static func capture(_ executable: String, _ arguments: [String], input: String? = nil) throws -> String {
		let process = Process()
		let output = Pipe()
		let error = Pipe()

		process.executableURL = URL(fileURLWithPath: executable)
		process.arguments = arguments
		process.standardOutput = output
		process.standardError = error

		if let input {
			let pipe = Pipe()

			process.standardInput = pipe
			try process.run()
			pipe.fileHandleForWriting.write(Data(input.utf8))
			try pipe.fileHandleForWriting.close()
		} else {
			try process.run()
		}

		// Read before waiting: a tool that fills the pipe buffer would otherwise never exit
		let standardOutput = output.fileHandleForReading.readDataToEndOfFile()
		let standardError = error.fileHandleForReading.readDataToEndOfFile()

		process.waitUntilExit()

		guard process.terminationStatus == 0 else {
			throw ServiceError(String(format: String(localized: "%@ failed (%d): %@"), URL(fileURLWithPath: executable).lastPathComponent, process.terminationStatus, String(decoding: standardError, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)))
		}

		return String(decoding: standardOutput, as: UTF8.self)
	}
}
