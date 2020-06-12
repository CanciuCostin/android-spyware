To use the complete toolkit, it's recommended to download android-backup-toolkit instead.
It already included all the software bundled plus additional tools.

LINKS:
android-backup-toolkit: https://sourceforge.net/projects/android-backup-toolkit/
Full local backup infrastructure: https://android.googlesource.com/platform/frameworks/base/+/4a627c71ff53a4fca1f961f4b1dcc0461df18a06
tar-binary-splitter: https://sourceforge.net/projects/tar-binary-splitter/
android-backup-splitter: https://sourceforge.net/projects/adb-split/
no-adb-backup-app-lister: https://sourceforge.net/projects/no-adb-backup-app-lister/
Perl scripts to encrypt/decrypt adb backup files: http://forum.xda-developers.com/showthread.php?t=1730309
The Legion of the Bouncy Castle: https://www.bouncycastle.org/java.html
Bouncy Castle source (JCE with provider and lightweight API): https://www.bouncycastle.org/download/bcprov-jdk15on-159.zip

Application name: android-backup-extractor
Site: https://sourceforge.net/projects/adbextractor/
Original author: Nikolay Elenkov
Original source code: https://github.com/nelenkov/android-backup-extractor
Website original documentation: http://nelenkov.blogspot.com/2012/06/unpacking-android-backups.html
Packaging and improvements: dragomerlin
Format: runnable java jar file + third party perl scripts
	* java code is modified (Nikolay Elenkov based)
	* perl scrips are unmodified (Jeffrey J. Kosowsky)
IDE:
	Eclipse IDE for Java Developers
	Version: Oxygen.3a Release (4.7.3a)
	Build id: 20180405-1200
OS: Windows 10 Pro 64 bits, version 1803
Compiler: Oracle Java JDK 1.8.0_172
Compiler compliance level: Java 1.7. "Major.Minor Version"=51.0
Bouncy Castle version: 1.59

LAW WARNING
To work with password (encrypted) adb backups, it's required to download, for the matching version of Java,
the libraries, depending if it's from Oracle or OpenJDK. For Oracle, these are:
	Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy Files:
	- local_policy.jar
	- US_export_policy.jar
from:
	http://www.oracle.com/technetwork/java/javase/downloads/jce-7-download-432124.html
	http://www.oracle.com/technetwork/java/javase/downloads/jce8-download-2133166.html
and put them in the corresponding lib/security folders of the Oracle Java SE 7 or 8 installations, for example:
--Windows:
C:\Program Files\Java\jdk1.7.0_60\jre\lib\security\
c:\Program Files\Java\jdk1.8.0_66\jre\lib\security\
c:\Program Files\Java\jdk1.8.0_144\jre\lib\security\
C:\Program Files\Java\jre7\lib\security\
c:\Program Files\Java\jre1.8.0_66\lib\security\
C:\Program Files (x86)\Java\jdk1.7.0_60\jre\lib\security\
C:\Program Files (x86)\Java\jre7\lib\security\
c:\Program Files (x86)\Java\jre1.8.0_66\lib\security\
--Linux:
/usr/local/jdk1.7/jre/lib/security/
/usr/lib/jvm/java-7-oracle/jre/lib/security/
/usr/lib/jvm/java-8-oracle/jre/lib/security/
--BSD:
/usr/lib/jvm/java-7-openjdk-*/jre/lib/security/
--OS X / macOS:
/Library/Java/JavaVirtualMachines/jdk1.7.0_60.jdk/Contents/Home/jre/lib/security/
/Library/Java/JavaVirtualMachines/jdk1.8.0_66.jdk/Contents/Home/jre/lib/security/
Won't work if you supply them with the jar application, you must have them installed onto your system.
Latest versions of Oracle Java, JDK ™9 and JDK ™10, already come with policy files for "unlimited" cryptographic strengths:
	http://www.oracle.com/technetwork/java/javase/terms/readme/jdk9-readme-3852447.html
	http://www.oracle.com/technetwork/java/javase/documentation/jdk10-readme-4419830.html

Usage:
	info:	java -jar abe.jar [-debug] [-useenv=yourenv] info <backup.ab> [password]
	unpack:	java -jar abe.jar [-debug] [-useenv=yourenv] unpack <backup.ab> <backup.tar> [password]
	pack:	java -jar abe.jar [-debug] [-useenv=yourenv] pack <backup.tar> <backup.ab> [password]
	pack-kk:	java -jar abe.jar [-debug] [-useenv=yourenv] pack-kk <backup.tar> <backup.ab> [password]

*"-debug" must go before "-useenv" when both used
*pack-kk is to create version 2 backups for android kitkat 4.4.3+.
*info gives information about an adb backup without extracting anything.
*yourenv is the environment variable provided to read the password from. Don't mistake it with a bash variable.
*debug shows cryptographic and file information, and password when useenv is used, and any additional information.
	All messages are displayed only with debug, and are written to stderr, even the usage (no arguments given or incorrect ones), so it's fine
	for pipelining and checking the exit code, the only exception is when specifying to output the processed file to stdout with "-".
*If the filename is `-`, then data is read from standard input or written to standard output
If you don't specify a password when packing the backup archive, won't be encrypted but only compressed (default).
Option to create unencrypted and uncompressed backups is possible, but not available on ABE.

Setting environment variables:
Don't mistake environment variables with bash variables, which are not available to ABE and are set the same way without the "export".
--Linux: (double quotes may affect bash expansion, consider using single quotes instead if you use special characters like $, etc)
Quick usage:
	export PASSVAR=mysecretpassword
	OR
	export PASSVAR="my secret password"
	OR
	export PASSVAR='my secret password'
To make it persistent between reboots and sessions, add it to your ~/.profile or ~/.bashrc and reload it:
	echo 'export FOO="my pass"' >> ~/.profile
	source ~/.profile
To make it available for all users, add it as root to /etc/profile (most linux distros)
	sudo echo 'export FOO=bar' >> /etc/profile
-- OS X:
To make it persistent for terminals, add it to ~/.bash_profile
	echo 'export FOO=bar' >> ~/.bash_profile
	OR
	echo 'export FOO="my pass"' >> ~/.bash_profile
Globally: very tricky, depends on OSX version
-- Windows: you can use User or System environmental variables with ABE:
	For user environment variables: Windows key + R > rundll32 sysdm.cpl,EditEnvironmentVariables > User variables for your account
	For user or system: Control panel > View by: Large icons > System > Advanced system settings > Environment variables... > System variables
You can view them also with Windows Powershell commands:
	[Environment]::GetEnvironmentVariables("Machine")
	[Environment]::GetEnvironmentVariables("User")
	[Environment]::GetEnvironmentVariables("Process")
	More info to view/set/remove on Windows:
	* http://www.adp-gmbh.ch/win/misc/environment_variables.html
	* https://stackoverflow.com/questions/30675480/windows-user-environment-variable-vs-system-environment-variable
	* http://xahlee.info/powershell/environment_variables.html

Requirements for compilation:
- Java Development Kit version 7 or 8 (1.7 or 1.8)
- Bouncy Castle java release "JCE with provider and lightweight API" bcprov-jdk15on*
  http://www.bouncycastle.org/latest_releases.html
- Oracle Java Cryptography Extension (JCE) Unlimited Strength Jurisdiction Policy Files (7 or 8) (optional but required when handling encrypted backups)
  * http://www.oracle.com/technetwork/java/javase/downloads/jce-7-download-432124.html
  * http://www.oracle.com/technetwork/java/javase/downloads/jce8-download-2133166.html
- Set the Compiler compliance level to 1.7 to allow more compatible versions (optional but recommended)
- IDE Eclipse (optional but recommended)

Description and scope:
- android-backup-extractor is a Java program that can extract and create android adb backups from or to TAR format. It doesn't edit directly.
- It can display the information of MIUI backups and also extract them. Does not support to create MUIU backups.
- You can choose to view an adb backup properties, extract it to tar, or create a new adb backup from tar.
 - When creating a backup, password if optional. When extracting, if backup is encrypted, entering a password is mandatory to success.
   If a password is required, but not provided by the command line, it will ask interactively. Will exit if a null or empty string is provided.
- A password can be provided from any environment variable with -useenv=envvar. However, if the password is specified directly on the command line, this will be used instead.
  It does not read bash variables, only user environment variables
- The debug messages can be activated with the -debug flag. Otherwise operations are quiet except when displaying usage.
 - When working with encryption, JCE USJPF is required, so will notify and exit if not present.
- android-backup-splitter are two bash scripts that allow you to create individual adb backups for each app or shared from the full one,
  so you can restore apps or shared sdcards individually. Same encryption is preserved to them, if any. It also informs when any apk is missing for each app.
  * adb-split-extraction.sh extracts the contents of the tar archive(s) to the hard drive and re-tars, but this may lead to problems with not allowed filename characters.
    It only generates adbs for apps.
  * adb-split-no-extraction.sh splits the adb tar in binary mode instead. It requires the program tar-binary-splitter.
    This is the recommended method. The script generates adb(s) for both apps and shared.
- The adb backups (usually with .ab extension) can be password protected or not. If the device is encrypted usually this is mandatory, and the password must be the same
  as the used to unlock the device (some manufacturers don't required password to encrypt the backup even if the device is encrypted or a different one may suffice).
- The adb backups are extracted to tar format, and are created from the tar format as well.
- The files and folders inside the tar archive must be in some specific order, not necessarily alphabetical like tar does by default.
  Such order is listed in "Full local backup infrastructure". The easiest way to test is to repackage a tar archive from an already existing one;
  for example a part of an archive, and repackage it following the same order as files are listed in the original. If we don't have the original archive,
  we have to guess out the order. Some redundancy checksums may be present on the manifest so restoring a modified backup may not work.
- Perl scrips are unmodified and are not updated to have the latest features.
NOTE: additional scripts and software not included with android-backup-extractor is available on android-backup-toolkit which is the recommended download.

Considerations:
- Read the READMEs and Docs inside android-backup-toolkit for further knowledge.
- The tar archives may be extracted and created on filesystems that respect tar's content's permissions, although seems to work anyway when restoring to the android device.
- Directories inside tar archives must not contain trailing slashes. Since GNU tar doesn't have this option, the use of star or pax is mandatory. For Ubuntu and Cygwin star is included.
- star is recommended instead of pax. Pax only supports path length only up to 100 characters, so will fail in some cases. This usually happens with browsers history.
- Java 7 or higher is required because of SYNC_FLUSH mode for the Deflater.
- If the backup contains apk+data for an app, restore will work. If contains only the data, you must install the app first on the device and then restore. Installing the app later won't work.
- If you want a full backup use a nandroid backup with Clockworkmod or TWRP instead of ADB. Nandroid backup has the disadvantage that is not always 100% compatible between devices. ADB backup intends to be.
- Nandroid Manager (https://play.google.com/store/apps/details?id=com.h3r3t1c.bkrestore) is the best android app to work with nandroid backups.
- Some apps include a policy where the apk is never backed up even if specified. Same may apply for some data, depending on how the app is programmed regarding adb backups.
- Some apps can't be backed up at all. For example if android:allowBackup="false" is set in the manifest or the app is DRM protected (try Titanium Backup instead).
- Some applications or its data couldn't be restored to a different device: require specific device's id, android api level, processor architecture, etc.
- Android debugging bridge is very slow: about 1 MBps if the backup is password encrypted, 1.6 MBps if not, so consider that backing up and restoring may take a long time.
- When adding or removing files for an app you may need to edit _manifest so adb restore accepts the changes.
- ADB backups are not a replacement for a Nandroid backup. The whole /data partition is not backed up, only a part of it. Also, other partitions like /system, /preload, /cache, modem, RIL, efs, boot, kernel or recovery are never backed up because are not user data.
  This is to prevent issues when restoring on a different device. It has also the biggest advantage that doesn't require root to operate, so is totally compatible with stock roms, locked bootloaders and device encryption.
- If you have the device encrypted with a password, you must use that particular one for backup creation and restore. You can't create a backup without password or a different one in that particular case, or if you try to restore will fail.
- star for cygwin for windows is attached (move it to C:\cygwin\bin\star.exe) since there is no package available. It can be compiled from the schily tools (http://sourceforge.net/projects/schilytools).
  star for linux can be installed as package or compiled the same way
  star for OSX/macOS can be installed with Homebrew (http://brew.sh/): brew install star
- The best way to test if an adb backup has errors, is to convert it to tar and then check with "tar -tf file.tar && echo $?". 0 is given if ok
- One or more spaces can be used as password. Example: "   "
- With "Android App Bundle", announced at Google I/O '18, apks may differ from one device to another or not contain all assets, so making an adb backup and restoring it to another device may or may not work:
	* https://www.youtube.com/watch?v=bViNOUeFuiQ
	This is similar to what happened with iOS starting with iOS 9, where you can't backup anymore the apps (.ipa files) with iTunes, only its data. If you restore the backup, the apps are re-downloaded from the App Store.
	The problem with this is that if you buy a new iPhone/iPad, and an app was removed from the App Store, you can't transfer it to the new device, even if you have it on the old iPhone.
	Before iOS 9 and older versions of iTunes, you could backup and restore entire applications which you had on your device, free or paid. The cause may be app thinning and multi-device support:
	* https://www.macworld.com/article/3125509/iphone-ipad/more-on-backing-up-your-ios-device.html
	* https://apple.stackexchange.com/questions/206544/cant-transfer-purchases-from-iphone-to-itunes-in-ios-9


Example of quick backup editing:
Here is an example on how to make a custom adb backup from a complete one, for the game Grand Theft Auto III from Rockstar Games, installed on the Nexus 7.

1) Unpack the original adb backup:
$ java -jar abe.jar unpack nexus7.ab nexus7.tar [password]

2) Extract the contents of the tar archive. This may be done on a filesystem where the permissions of the files inside the tar are preserved, for example using linux, mac or bsd. Up to two folders may appear, apps and shared.
   Be warned that if there are characters in filenames not supported by the operating system like :;/ etc it will not work even if it appears to do so. OSX is the most flexible in this matter.
$ tar -xvf nexus7.tar

3) Make a list of all the contents of the original archive in the order they are archived:
$ tar -tf nexus7.tar > nexus7.list

4) Create a new list only with the files and folders you want, in proper order. For example for the GTA 3 (you can try savegames instead of all data):
$ cat nexus7.list | grep com.rockstar.gta3 > gta3.list

5) Create the new tar archive. The directories stored on tar mustn't contain trailing slashes, so I use star instead of tar. Pax works also if paths are up to 100 of length:
$ star -c -v -f gta3.tar -no-dirslash list=gta3.list
OR
$ cat gta3.list | pax -wd > gta3.tar

6) Create the adb backup from the tar archive. Password is optional except if the device is encrypted:
$ java -jar abe.jar pack gta3.tar gta3.ab [password]

Note:
If the backup is not encrypted zlib can be used instead for both unpack and pack the ab archive.
If openssl is not compiled with zlib support due to security issues (RHSA-2013-0587;CVE-2012-4929), you can try python instead.

- Quick unpacking:
	tail -c +25 nexus7.ab | openssl zlib -d > nexus7.tar
	tail -c +25 nexus7.ab | python -c "import zlib,sys;sys.stdout.write(zlib.decompress(sys.stdin.read()))" > nexus7.tar
- Quick packing:
	dd if=nexus7.ab bs=24 count=1 of=gta3.ab ; openssl zlib -in gta3.tar >> gta3.ab
	dd if=nexus7.ab bs=24 count=1 of=gta3.ab ; cat gta3.tar | python -c "import zlib,sys;sys.stdout.write(zlib.compress(sys.stdin.read()))" >> gta3.ab
	dd if=nexus7.ab bs=24 count=1 of=gta3.ab ; python -c "import zlib,sys;open('gta3.ab', 'ab').write(zlib.compress(open('layton.tar', 'rb').read()))"
- Instead of "tail -c +25 nexus7.ab" you can use "dd if=nexus7.ab bs=1 skip=24" but is less efficient.


Example of adb splitting to create an individual adb backup for shared and each app (non extraction method, RECOMMENDED):
Use ADB Backup Splitter (is a shell script). Works on Linux, Cygwin and OSX:
bash adb-split-no-extraction.sh backup.ab [password]
Resulting files go in split-ab folder.
Missing apk(s) are listed in apk-missing.html

Example of adb splitting to create an individual adb backup for each app (extraction method):
Use ADB Backup Splitter (is a shell script). Works on Linux, Cygwin and OSX:
bash adb-split-extraction.sh backup.ab [password]
Resulting files go in app-ab folder.
Missing apk(s) are listed in apk-missing.html


MIUI backups:
MIUI backups are adb backups, except that they contain an additional header at the beginning.
(By default, MIUI backups are neither compressed nor encrypted, at least the tested sample)
(On the other hand, adb backups by default are compressed but not encrypted.)
To extract them, just read/discard the additional header and then treat the rest like a regular adb backup.
- Example: hex dump of the MIUI backup for an app:
-- App: Notes: https://play.google.com/store/apps/details?id=com.trantrigroup.note
-- App version: 1.0
-- Device: Xiaomi MI5
-- Device operating system: MIUI Global 8.5 | Stable | 8.5.3.0 (NAAMIED) | Based on android 7.0 NRD90M
-- Backup size: 853575 bytes
-- Tar size (.BAK to .TAR): 853504 bytes
-- The app contains a Test note
00000000: 4D 49 55 49 20 42 41 43 4B 55 50 0A 32 0A 63 6F 6D 2E 74 72 61 6E 74 72 69 67 72 6F 75 70 2E 6E  MIUI BACKUP.2.com.trantrigroup.n
00000020: 6F 74 65 20 4E 6F 74 65 73 0A 2D 31 0A 30 0A 41 4E 44 52 4F 49 44 20 42 41 43 4B 55 50 0A 34 0A  ote Notes.-1.0.ANDROID BACKUP.4.
00000040: 30 0A 6E 6F 6E 65 0A 61 70 70 73 2F 63 6F 6D 2E 74 72 61 6E 74 72 69 67 72 6F 75 70 2E 6E 6F 74  0.none.apps/com.trantrigroup.not
00000060: 65 2F 5F 6D 61 6E 69 66 65 73 74 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  e/_manifest.....................
00000080: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
000000a0: 00 00 00 00 00 00 00 00 00 00 00 30 30 30 36 30 30 20 00 30 31 37 35 30 00 00 00 30 31 37 35 30  ...........000600 .01750...01750
000000c0: 00 00 00 30 30 30 30 30 30 30 32 37 31 34 00 30 00 00 00 00 00 00 00 00 00 00 00 30 31 33 36 32  ...00000002714.0...........01362
000000e0: 37 00 20 30 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  7. 0............................
00000100: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
00000120: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
00000140: 00 00 00 00 00 00 00 00 75 73 74 61 72 00 30 30 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ........ustar.00................
00000160: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
00000180: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
000001a0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
000001c0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
000001e0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
00000200: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
00000220: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................................
00000240: 00 00 00 00 00 00 00 31 0A 63 6F 6D 2E 74 72 61 6E 74 72 69 67 72 6F 75 70 2E 6E 6F 74 65 0A 33  .......1.com.trantrigroup.note.3
00000260: 0A 32 34 0A 63 6F 6D 2E 61 6E 64 72 6F 69 64 2E 76 65 6E 64 69 6E 67 0A 31 0A 31 0A 33 30 38 32  .24.com.android.vending.1.1.3082
00000280: 30 32 63 37 33 30 38 32 30 31 61 66 61 30 30 33 30 32 30 31 30 32 30 32 30 34 34 61 39 65 32 33  02c7308201afa00302010202044a9e23
000002a0: 31 36 33 30 30 64 30 36 30 39 32 61 38 36 34 38 38 36 66 37 30 64 30 31 30 31 30 62 30 35 30 30  16300d06092a864886f70d01010b0500
[...]

- Example: hex dump of the adb backup for the same app:
-- Device: Samsung Galaxy S7
-- Device operating system: android 7.0 build NRD90M
-- Backup size: 619614 bytes
-- Tar size (.AB to .TAR): 871936 bytes
-- The app contains the same Test note
00000000: 41 4E 44 52 4F 49 44 20 42 41 43 4B 55 50 0A 34 0A 31 0A 6E 6F 6E 65 0A 78 DA EC BB 77 5C 14 4B  ANDROID BACKUP.4.1.none.x...w\.K
00000020: B7 2E 3C E4 8C 20 48 CE 8A 0A 12 66 98 88 E4 1C 54 04 09 12 14 98 19 66 C8 19 24 47 91 24 8A 82  ..<.. H....f....T......f..$G.$..
00000040: 92 73 0E 02 A2 04 51 B2 04 03 41 40 44 90 24 48 CE 39 28 F0 F5 28 FB 7D F7 F6 EC 7D EE 39 F7 DC  .s....Q...A@D.$H.9(..(.}...}.9..
00000060: DF FD E3 FB BE 9E 7E BA 6B 75 55 57 AD 5A EB A9 55 3D 3D 35 68 27 27 57 71 AC A3 BD 98 9B 0B DA  ......~.kuUW.Z..U==5h''Wq.......
00000080: C1 CD C5 DA D2 C5 D1 DD 49 CC C1 D1 0D 27 6E 66 8F 76 B0 C6 E3 5C DD 40 FF C3 0D 0C 06 23 C0 60  ........I....'nf.v...\.@.....#.`
000000a0: 3E 10 18 82 84 83 09 F2 1F E7 5F 9B 04 12 02 03 81 FF 5C 1E 02 45 48 20 41 7C 60 D0 FF 85 CD DD  >........._.......\..EH A|`.....
000000c0: D5 0D ED 02 A8 02 FA FF E6 06 A1 FE 5B E7 53 43 A9 25 60 3F B3 D0 0E 16 2E 8E D6 16 62 B7 70 0E  ............[.SC.%`?........b.p.
000000e0: 16 D6 0E 96 D4 10 E0 03 05 A3 24 C0 12 58 E4 CF 33 04 8D 47 83 C1 50 30 90 02 20 01 86 C1 D0 92  ..........$..X..3..G..P0.. .....
00000100: 38 09 28 04 01 05 83 2D 00 C7 4B 4A A0 51 08 18 0A 85 C0 23 01 19 02 7C 30 60 38 E1 06 08 14 0A  8.(....-..KJ.Q.....#...|0`8.....
00000120: 81 40 80 52 78 A0 14 14 0E 07 C3 C0 50 40 44 C1 61 48 09 04 04 81 93 00 FF 4C 49 FE AC 1A B8 17  .@.Rx.......P@D.aH.......LI.....
00000140: C8 84 42 C1 50 14 14 A8 1C F8 20 A0 30 20 05 87 A2 E0 68 08 0A 8C FF 99 07 F9 F9 91 00 3E D0 BF  ..B.P..... .0 ....h..........>..
00000160: 96 F8 EF B4 46 E8 93 84 C4 3F 6A 0F 21 68 0F A8 41 E8 2F 9E D0 8F 9F 29 34 58 E2 E7 19 02 06 63  ....F....?j.!h..A./....)4X.....c
00000180: 91 16 58 30 12 89 87 A3 61 08 38 04 89 C5 E2 A0 08 34 02 8B 02 4B 42 60 08 30 02 61 81 44 20 F0  ..X0....a.8......4...KB`.0.a.D .
000001a0: 92 12 78 2C 12 0C C3 80 71 30 B4 04 02 21 89 83 C2 51 70 A8 85 24 0C 0A 83 C1 81 5B 80 0B 92 10  ..x,....q0...!...Qp..$.....[....
000001c0: 09 30 0A 81 91 94 80 48 02 C3 47 12 81 96 84 4B 4A C0 C1 58 30 06 0A 03 E3 10 40 B5 38 3C 18 83  .0.....H..G....KJ..X0.....@.8<..
000001e0: 87 5A 40 25 B0 78 18 16 06 83 60 E0 68 09 BC 04 0A 2E 89 C7 E0 F1 68 AC 24 D6 02 8C 84 02 05 00  .Z@%.x....`.h.........h.$.......
00000200: CD E1 08 2C 5C 12 8C 97 94 B4 80 63 D1 08 1C C4 42 D2 02 01 03 63 B0 08 38 1A 0B 46 A1 00 0F 22  ...,\......c....B....c..8..F..."
[...]


Changelog:
(Initial)
(6 June 2014)
- Changed "enabled" to "allowed" and "not enabled" to "not allowed" relating to strong AES encryption because some user complained
- JDK updated to 1.7.0_60, mixed mode
- Added support for android 4.4 encrypted backups
- Removed bcprov-jdk15on documentation
- Updated Bouncy Castle source (JCE with provider and lightweight API) from 1.48 to 1.50
- Updated adb-split.sh to add "${SCRIPT_DIR}/" before abe.jar
- Eclipse updated from 20130225-0426 to 20140224-0627
(15 June 2014)
- Updated program to create version 2 backups for android 4.4.3+.
(30 June 2014)
- Added backup version 3 for android L. No real code changes.
(19 October 2015)
- Updated Bouncy Castle source (JCE with provider and lightweight API) from 1.50 to 1.53
- Replace "%s." with "%s" in AndroidBackup.java for better reading
- Added VERSION to usage()
- Added star-1.5.3-i686-pc-cygwin/star.exe compiled from schily-dist-pre2.tar.xz (2015-10-16)
- JDK updated to 1.8.0_60-b27
- Updated README.TXT
- Updated Main.java to add JCE 8 to usage()
- Created VERSION.TXT
- Created folder Doc
	Move there "Full local backup infrastructure.txt"
	Copy there README.TXT from Tar Binary Splitter
	Copy there README.TXT from Android Backup Splitter
- Added Tar Binary Splitter v4.0 (tar-bin-split.jar) to split adb backups without issues.
- Updated Android Backup Splitter
	Extraction version
	Non Extraction version
(20 October 2015)
- Exit 0 if no arguments are given
- Detect when password is provided but strong AES encryption is not allowed, so warn user and exit 1
- Compiler compliance level set to Java 1.7. Changes "Major.Minor Version" from 52.0 to 51.0. Previous version was 1.8
- Updated Tar Binary Splitter to v4.1 with its Readme
(22 October 2015)
- Added method requirePassword() to demand password from user when no one is present but backup is encrypted
(23 October 2015)
- Improved routines for detecting when a password is required
- Improbed routines for detecting when JCE USJPF is required
(24 October 2015)
- Added ability to read password from any specified environment variable
(25 October 2015)
- Send non usage messages to stderr instead of stdout. This allows pipelining to stdout only real data
- Now debug is user selectable with the -debug flag
- Flag "USEENV=" replaced with "-useenv="
(26 October 2015)
- Support "-" for stdin/stdout (pipes)
(2 November 2015)
- Improved README.TXT
- JRE and JDK updated to 1.8.0_66
- star.exe 1.5.3 compiled from schily-dist-pre4.tar.xz (27-10-2015)
(8 July 2016)
- JRE and JDK updated to Oracle Java 1.8.0_91
- Add support for android Nougat (android 7.x)
- Eclipse updated to Version: Mars.2 Release (4.5.2) Build id: 20160218-0600
(9 July 2016)
- Updated Bouncy Castle source (JCE with provider and lightweight API) from 1.53 to 1.54
(10 July 2016)
- Fix issue to support android Nougat on extractAsTar routine also (only present on infoBackup on the two previous versions)
(27 August 2017)
- Display percentage of progress when unpacking ab to tar, when the -debug flag is used.
(28 August 2017)
- Android backup version is no longer checked. This helps support future version without having to recompile provided that the format is the same.
(22 September 2017)
- Android backup version is no longer checked (fixed):
Now the function extractAsTar also ignores the backup version. Previous build only ignored it for infoBackup so you could check it but not extract it.
(05 October 2017)
- Added support to view information from MIUI backups and extract them.
- Now the program will exit if "ANDROID BACKUP" is not detected by extractAsTar(). Inside infoBackup() was already present.
- Improved README.TXT with a MIUI and adb backup example.
(03 February 2018)
- Improved README.TXT
- Android Backup Extractor is now android-backup-extractor
- Updated Bouncy Castle source (JCE with provider and lightweight API) from 1.54 to 1.59
- The following items were removed from android-backup-extractor, now are on android-backup-toolkit and its own sourceforge site:
	adb-split-extraction.sh
	adb-split-no-extraction.sh
	tar-bin-split.jar
	star-ubuntu-lucid
	star-1.5.2-i686-pc-cygwin
	star-1.5.3-i686-pc-cygwin
(20 May 2018)
- Print newline after 100% completion when debug is enabled
- JRE and JDK updated to Oracle Java 1.8.0_172
- Eclipse updated to version: Oxygen.3a Release (4.7.3a); build id: 20180405-1200
(21 May 2018)
- Fixed a bug introduced in v20180520 where a newline was printed to stdout instead of stderr
- abe version is printed when debug is enabled
- All information, included debug and usage(), is output to stderr instead of stdout, for better pipelining
- Current progress is displayed in percentage, for unpack, pack and pack-kk, when debug is enabled
- Display size of both input and ouput files, when debug is enabled
- Display size of backup with info option, when debug is enabled
- Improved README.TXT
