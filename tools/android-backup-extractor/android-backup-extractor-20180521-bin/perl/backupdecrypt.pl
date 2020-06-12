#!/usr/bin/perl
#============================================================= -*-perl-*-
#
# backupdecrypt.pl: Decrypt (and decompress) android backup file
#
# USAGE
#   backupdecrypt.pl [options] <input file> <output file>
#
#   To see the various options run:
#        backupdecrypt [--help|-h]   
# 
#
# DESCRIPTION
#   Decrypt (and decompress) standard android backup files to recover
#   standard POSIX tar file
#   Optionally, gzip-compress the output to yield a gzipped tar file
#   
# AUTHOR
#   Jeffrey J. Kosowsky
#
# COPYRIGHT
#   Copyright (C) 2012  Jeffrey J. Kosowsky
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#========================================================================
#
# Version 0.1, released June 2012
#
#========================================================================
# CHANGELOG
#     0.1 (June 2012)  - Initial version

#========================================================================
# Thanks to Nikolay Elenkov for his help in understandng the format of the
# backup files and how to decrypt them along with providing sample Java code.
# See:
#  http://nelenkov.blogspot.com/2012/06/unpacking-android-backups.html
#  https://github.com/nelenkov/android-backup-extractor/blob/master/src/org/nick/abe/AndroidBackup.java
# https://github.com/nelenkov/android-backup-extractor/blob/master/src/org/nick/abe/AndroidBackup.java
# http://android.stackexchange.com/questions/23357/is-there-a-way-to-look-inside-and-modify-an-adb-backup-created-file
#
#========================================================================
# LINE. STRUCTURE OF THE ADB BACKUP HEADER          EXAMPLE
# 1. Magic:                                         ANDROID BACKUP
# 2. Version (1 only):                              1
# 3. Compression (1=compressed):                    1
# 4. Encryption (AES-256/none):                     AES-256
# 5. User Password Salt (128 Hex):                  7369CED537D83E155219...
# 6. Master Key Checksum Salt (128 Hex):            21D8562EA19F0AA81B5D...
# 7. Number of PBDKF2 Rounds (10000):               10000
# 8. User key Initiatlization Vector (IV) (32 Hex): 434A7A67212109AE1903...
# 9. Master IV+Key+Checksum (192 Hex):              49B0BEFBFE7CD8D7A18D...

# Notes: lines 5-8 only occur if encrypted.
# Hex is written in ALL-CAPS.
# The decrypted blob structure is:
# <iv len-1B><iv-16B><key len-1B><key-32B ><checksum len-1B><checksum-32B>
# where B=byte and len=length in bytes
#
# Decryption occurs as follows:
# 1. Create PBKDF2-derived User Key from user password (entered) and User Salt
# 2. Decrypt the Blob using the derived user key and user IV
# 3. Separate Blob into 3 components
# 4. Generate PBKDF2-derived Master Checksum from Master Key and Master Key
#    Checksum Salt
# 5. Check derived Master Checksum against Master Checksum recoverd from Blob
# 6. If matches, proceed with decryption using Master Key and Master IV
#========================================================================
# Requires the following SSL crypto libraries
#   Crypt:OpenSSL::AES
#      yum install perl-Crypt-OpenSSL-AES
#   Crypt::OpenSSL::CBC
#      yum install perl-Crypt-CBC
#   Crypt::OpenSSL::PBKDF2  [Not standard in my version of Fedora so build it]
#      cpanspec -v -f -b Crypt::OpenSSL::PBKDF2
#      which in turn requires openssl-devel
#           yum install openssl-devel
#      which in turn pulls in:
#          keyutils-libs-devel krb5-devel libcom_err-devel libselinux-devel libsepol-devel zlib-devel
#          rpmbuild --rebuild perl-Crypt-OpenSSL-PBKDF2-0.02-1.fc12.src.rpm
#          sudo rpm -Uvh perl-Crypt-OpenSSL-PBKDF2-0.02-1.fc12.i686.rpm
#          sudo rpm -e keyutils-libs-devel krb5-devel libcom_err-devel libselinux-devel libsepol-devel zlib-devel openssl-devel
#========================================================================

use strict;
use warnings;

use Term::ReadKey;
use Crypt::CBC;
use Crypt::OpenSSL::PBKDF2;
#use Crypt::OpenSSL::AES;  #Loaded automatically later...
use Compress::Zlib;
use IO::Compress::Gzip qw($GzipError);
use Getopt::Long qw(:config no_ignore_case bundling);
use Data::Dumper; #Just for debugging...

#========================================================================
### Constant-like variables
my $ANDROID_MAGIC = "ANDROID BACKUP";
my $BACKUP_VERSION = 1;
my $SALT_SIZE = 512; #Bits (size of salt for PBKDF2 algorithm)
my $PBDKF2_ROUNDS = 10000; #Rounds
my $IV_SIZE = 128; #Bits
my $KEY_SIZE = 256; #Bits
my $CHECKSUM_SIZE = 256; # Bits
my $ENCRYPTION_ALGORITHM = "AES-256";
my $BUFSIZE = 4096; # Compression block size
my $COMPRESS_LEVEL= Z_DEFAULT_COMPRESSION;
#========================================================================
### Options

#Defaults

my $compress;    #Default reads status from file (set to 0/1 to override)
my $checkpasswd; #Set to 1 to check password & quit
my $DEBUG ;      #Set to 1 to turn on debugging output
my $file;        #Password from file
my $Headers;     #Set to 1 to print headers to STDERR
my $zip;         #Set to 1 to gzip output
my $Password;    #Password on the command line

usage() unless
	GetOptions(
		"compress|c!"     => \$compress,
		"checkpasswd|C"   => \$checkpasswd,
		"debug|D"         => \$DEBUG,
		"file|f=s"        => \$file,
		"zip|z"           => \$zip,
		"help|h"          => \&usage,
		"Headers|H"       => \$Headers,
		"Password|P=s"    => \$Password,
	) && 
	$#ARGV == 1 &&
	! ($file && $Password);
	
#========================================================================
### I/O Setup
my ($in, $out);

my $infile = $ARGV[0];
$infile eq '-' ? $in = *STDIN :
	(open($in, "<:raw", $infile) or
	 die "Error: Can't open input file: $infile\n");

my $outfile = $ARGV[1]; #Don't open yet in case gzipping output
#========================================================================
#Read in the backup header...
jchomp(my $magic = <$in>); #First line: MAGIC
die "Error reading input file...\n" unless defined $magic;
print STDERR $magic . "\n" if $Headers;
die "Error: First line doesn't appear to be an Android backup file: $magic\n" 
	if $magic !~ /^${ANDROID_MAGIC}$/;

jchomp(my $version = <$in>); #2nd line: Version number (typically=1)
print STDERR $version . "\n" if $Headers;
die "Error: Don't know how to process version '$version'...\n"
	if $version != $BACKUP_VERSION;

defined($compress) ? <$in> :
	jchomp($compress = <$in>); #3rd line: Compressed ? 1:0
print STDERR $compress . "\n" if $Headers;
print STDERR "Compression=$compress\n" if $DEBUG;
die "Error: Unknown compression flag '$compress'...\n"
	if $compress !~/^[01]$/;

jchomp(my $encrypted = <$in>); #4th line: Compression: "none" or "AES-256"
print STDERR $encrypted . "\n" if $Headers;
print STDERR "Encryption=$encrypted\n" if $DEBUG;

my $cipher;
if ($encrypted =~ /^${ENCRYPTION_ALGORITHM}$/) {
	$encrypted = 1;
	my ($key, $iv) = get_decryption_keys();

	$cipher = Crypt::CBC->new( -key => $key,
								  -cipher => 'Crypt::OpenSSL::AES',
								  -iv => $iv,
								  -literal_key => 1,
								  -header => 'none');
	$cipher->start('decrypting');
} elsif($encrypted =~ /^none$/i) {
	$encrypted = 0; #No encryptiong
} else {  #Invalid encryption line
	die "Error: Encryption must be either 'none' or '$ENCRYPTION_ALGORITHM': '$encrypted'\n";
}
if($encrypted && $checkpasswd) {
	print STDERR "Password CORRECT\n";
	exit;
}

write_contents(); #Write out the tar payload

#END

#========================================================================
### Subroutines

#Compute the master key and IV
sub get_decryption_keys
{
	#Note salt, checksum and 'blob' strings are hex-encoded in all-caps
	jchomp(my $usersalt = <$in>); # 5th line: User password salt
	print STDERR $usersalt . "\n" if $Headers;
	die "Error: User password salt should be a " . $SALT_SIZE/4 . 
		" digit hex string: $usersalt\n"
		if $SALT_SIZE/4 != length($usersalt);
	$usersalt = pack('H*', $usersalt);

	jchomp(my $mastersalt  = <$in>); # 6th line: Master key checksum salt
	print STDERR $mastersalt . "\n" if $Headers;
	die "Error: Master key checksum salt should be a " . $SALT_SIZE/4 . 
		" digit hex string: $mastersalt\n"
		if $SALT_SIZE/4 != length($mastersalt);
	$mastersalt = pack('H*', $mastersalt);

	jchomp(my $pbdkf2rounds = <$in>); # 7th line: Number of PBDKF2 rounds used
	print STDERR $pbdkf2rounds . "\n" if $Headers;
	die "Error: PBDFK2 rounds should be $PBDKF2_ROUNDS: $pbdkf2rounds\n" if $pbdkf2rounds != $PBDKF2_ROUNDS;

	jchomp(my $uiv = <$in>); # IV of the user key, encoded in hex, all-caps
	print STDERR $uiv . "\n" if $Headers;
	die "Error: IV should be a " . $IV_SIZE/4 . " digit hex string: $uiv\n"
		if $IV_SIZE/4 != length($uiv);
	$uiv = pack('H*', $uiv);

	jchomp (my $blob = <$in>); # Master IV/key/checksum blob (encrypted)
	print STDERR $blob. "\n\n" if $Headers;
	warn "Error: 'blob' should be a " . 192 . " digit hex string: $blob\n"
		if 192 != length($blob); #NOTE: This is 83 bytes + 13 bytes padding and
	                             #it may not be always true/enforced
	$blob = pack('H*', $blob);

	# Get user password...
	my $userpass;
	if($Password) {
		$userpass = $Password;
	} elsif($file) {
		open(my $fh, "<", $file) or
			die "Error: Can't read password file: $file\n";
		chomp($userpass = <$fh>);
	} else {
		ReadMode('noecho');
		print STDERR "Please enter password: ";
		chomp($userpass = ReadLine(0));
		print STDERR "\n";
		ReadMode('restore');
	}
	die "Error: empty password not allowed...\n"
		if length($userpass) < 1;

	# Create derived password ($userkey) from password and user salt
	# using $pdkf2rounds of the PBKDF2 key derivation function
	my $userkey = Crypt::OpenSSL::PBKDF2::derive(
		$userpass, $usersalt, length($usersalt),
		$pbdkf2rounds, $KEY_SIZE/8);

	#Use derived $userkey and supplied user IV to decrypt the blob
	$cipher = Crypt::CBC->new( -key => $userkey,
								  -cipher => 'Crypt::OpenSSL::AES',
								  -padding => 'standard',
								  -literal_key => 1,
								  -iv => $uiv,
								  -header => 'none');
	$blob = $cipher->decrypt($blob);
	print STDERR "Decrypted blob length(bytes): " . length($blob) ."\n" 
		if $DEBUG;

    # Decrypted blob format is as follows:
    # <iv length><iv><key length><key><checksum length><checksum>
    # where the length is an unsigned character specifying the length in bytes
	# Unpack the decrypted blob
	my ($masteriv, $masterkey, $mastercheck);
	eval {
		($masteriv, $masterkey, $mastercheck) = unpack('C/a C/a C/a', $blob);
	};
	die "Error: Incorrect password (can't unpack master key)...\n"
		if $@;

	#Recreate master key checksum derived from $masterkey, and $mastersalt
	#by applying $pdfk2rounds of the PBKDF2 key derivation funtion
	my $checksum  = Crypt::OpenSSL::PBKDF2::derive(
		$masterkey, $mastersalt, length($mastersalt),
		$pbdkf2rounds, $CHECKSUM_SIZE/8);

	if($DEBUG) {
		print STDERR "\nSalts:\n";
		printf STDERR "US (%d): %s\n", length($usersalt), unpack('H*', $usersalt);
		printf STDERR "MS (%d): %s\n", length($mastersalt), unpack('H*', $mastersalt);
		print STDERR "\nKeys:\n";
		printf STDERR "MK (%d): %s\n", length($masterkey), unpack('H*', $masterkey);
		print STDERR "\nInitialization vectors:\n";
		printf STDERR "UIV (%d): %s\n", length($uiv), unpack('H*', $uiv);
		printf STDERR "MIV(%d): %s\n",	length($masteriv), unpack('H*', $masteriv);
		print STDERR "\nChecksums:\n";
		printf STDERR "CS (%d): %s\n", length($checksum), unpack('H*', $checksum);
		printf STDERR "MCS(%d): %s\n", length($mastercheck), unpack('H*', $mastercheck);
	}

	die "Error: Incorrect password (master key checksums don't match)...\n"
		if $checksum ne $mastercheck;
	return ($masterkey, $masteriv);
}

#Write out the contents to file decrypting and decompressing as indicated
sub write_contents
{
	my $buf = '';
	my $status = Z_OK;
	my $cmpr;

	#Open output file (don't do before since $outfile may be STDOUT
    #which will mess up if using gzip since it writes the gzip 
    #header immediately
	if($zip) {
		$out = new IO::Compress::Gzip($outfile , -Level => $COMPRESS_LEVEL)
			or	die "Error: Can't open gzip output: $outfile ($GzipError)\n";
	} else {
		$outfile eq '-' ? $out = *STDOUT :
			(open($out, ">:raw", $outfile) or 
			 die "Error: Can't open output file: $outfile\n");
	}

	if($compress) { #Initialize Zlib inflation
		$cmpr = inflateInit(-Bufsize => $BUFSIZE)
			or die "Cannot create a inflation stream\n" ;
	}

	binmode $in;
	binmode $out;

    #Write out rest of file decrypting and inflating as appropriate
	while (read($in, $buf, $BUFSIZE) && $status == Z_OK) {
		$buf = $cipher->crypt($buf) if $encrypted;
		($buf, $status) = $cmpr->inflate($buf) if $compress;
		print $out $buf if defined($buf);
	}
	if($encrypted) { #Print out any remaining encrypted tail
		$buf = $cipher->finish;
		($buf, $status) = $cmpr->inflate($buf) if $compress;
		print $out $buf if defined($buf);
	}
	warn "Error reading data: $status\n" if $status < 0;

	close $in;
	close $out;
}

sub usage
{
	$0 =~ m|(.*/)?(.*)|;
    print STDERR <<EOF;

usage: $2 [options] <input-file> <output-file>

Note: Input and output files can be replaced by \'-\' to signify
reading and writing from STDIN and STDOUT respectively. If reading
encrypted backup from STDIN, then the password must be entered from
the command line or from a file.
  
  Options:
   --compress|c            Deflate after decyrpting  [Default is to do what
                           the header says]
   --nocompress            Don\'t deflate after decyrpting  [Default is to do 
                           what the header says]
   --debug|D               Print debugging statements to STDERR
   --file|f <passwd file>  Input password from first line of file
   --help|h                Display this usage message
   --Headers|H             Print headers to STDERR
   --zip|z                 Compress the decrypted output with gzip
   --Password|P <passwd>   Input password from the command line

Note: --zip|z allows you to compress the decrypted file using
gzip. This is useful, for example, to conver the recovered tar file to
a compressed tar file.

Note: ability to override header compression directive added to overcome
Android backup bug where data is not compressed despite flag.

EOF
    exit(1);
}

#Modified version of 'chomp' that works if undefined
sub jchomp
{
	if(defined($_[0])) {
		chomp($_[0]);
	} else {
		$_[0]=''; 
		return 0;
	}
}
