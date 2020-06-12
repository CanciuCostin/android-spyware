#!/usr/bin/perl
#============================================================= -*-perl-*-
#
# backupencrypt.pl: Encrypt (and decompress) android backup file
#
# USAGE
#   backupencrypt.pl [options] [-p|-f] <input file> <output file>
#
#   To see the various options run:
#        backupdecrypt [--help|-h]   
#
# DESCRIPTION
#   Encrypt (and decompress) standard android backup files to recover
#   standard POSIX tar file
#   Optionally, gzip-compress the output to yield a gzipped tar file
#   
# AUTHOR
#   Jeffrey J. Kosowsky
#
# COPYRIGHT
#   Copyright (C) 2012 Jeffrey J. Kosowsky
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
#   Crypt::OpenSSL::RSA
#   Crypt::OpenSSL::AES
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
use Crypt::OpenSSL::Random;
use Compress::Zlib;
use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError);
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
my $compress=1;   #0=not compressed; 1=compressed (default)
my $DEBUG;        #Set to 1 to turn on debugging output
my $file;         #Password from file
my $Headers;      #Set to 1 to print headers to STDERR
my $password;     #Query Password if set to 1
my $Password;     #Password input on the command line
my $zip;          #Set to 1 to decompress input first

usage() unless
	GetOptions(
		"compress|c!"   => \$compress,
		"debug|D"       => \$DEBUG,
		"file|f=s"      => \$file,
		"help|h"        => \&usage,
		"Headers|H"     => \$Headers,
		"password|p"    => \$password,
		"Password|P=s"  => \$Password,
		"zip|z"         => \$zip,
	) && 
	$#ARGV == 1 &&
	(defined($file) + defined($password) + defined($Password) <= 1);

my $encrypted = (defined($password) || defined($Password) ||defined($file)) 
	? 1 : 0;
	
#========================================================================
### I/O Setup
my ($in, $out);

my $infile = $ARGV[0];
if($zip) {
	$in = new IO::Uncompress::AnyUncompress($infile)
		or	die "Error: Can't open compressed input file: $infile ($AnyUncompressError)\n";
} else {
	$infile eq '-' ? $in = *STDIN :
		(open($in, "<:raw", $infile) or 
			 die "Error: Can't open input file: $infile\n");
}

my $outfile = $ARGV[1];
$outfile eq '-' ? $out = *STDOUT :
	(open($out, ">:raw", $outfile) or 
	 die "Error: Can't open output file: $outfile\n");

binmode $in;
binmode $out;

#========================================================================
my $cipher;
write_header();
write_contents();
#END

#========================================================================
### Subroutines
sub write_header
{
    #Write the backup header
	print $out <<EOF;
${ANDROID_MAGIC}
$BACKUP_VERSION
$compress
EOF
    if($encrypted) {
		my $usersalt = hexstring($SALT_SIZE/4);
		my $mastersalt = hexstring($SALT_SIZE/4);
		my $uiv = hexstring($IV_SIZE/4);

		my $masteriv = 	pack('H*', hexstring($IV_SIZE/4)),
		my $masterkey = pack('H*', hexstring($KEY_SIZE/4));
		my $mastercheck  = Crypt::OpenSSL::PBKDF2::derive(
			$masterkey, pack('H*', $mastersalt), $SALT_SIZE/8,
			$PBDKF2_ROUNDS, $CHECKSUM_SIZE/8);

		# Unencrypted blob format is as follows:
		# <iv length><iv><key length><key><checksum length><checksum>
		# where 'length' is an unsigned char specifying the length in bytes
		# This should be 83 bytes long
		my $blob = pack('C/a C/a C/a', $masteriv, $masterkey, $mastercheck);

		# Next we encrypt the blob
		# Get password if not input via file or command line
		my $userpass;
		if(defined($Password)) {
			$userpass = $Password;
		} elsif($file) {
			open(my $fh, "<", $file) or
				die "Error: Can't read password file: $file\n";
			jchomp($userpass = <$fh>);
		} else { # Enter manually
			ReadMode('noecho');
			print STDERR "Please enter password: ";
			chomp($userpass = ReadLine(0));
			print STDERR "\n";
			ReadMode('restore');
		}
		die "Error: empty password not allowed...\n"
			if length($userpass) < 1;

		# Create derived password ($userkey) from password and user salt
		# using $PBDKF2_ROUNDS of the PBKDF2 key derivation function
		my $userkey = Crypt::OpenSSL::PBKDF2::derive(
			$userpass, pack('H*', $usersalt), $SALT_SIZE/8,
			$PBDKF2_ROUNDS, $KEY_SIZE/8);

		#Use derived $userkey and user IV to encrypt the blob
		$cipher = Crypt::CBC->new( -key => $userkey,
								   -cipher => 'Crypt::OpenSSL::AES',
								   -padding => 'standard',
								   -literal_key => 1,
								   -iv => pack('H*', $uiv),
								  -header => 'none');
		$blob = uc(unpack('H*', $cipher->encrypt($blob)));
		#Note: should be a 192 digit hex string
		printf STDERR "Blob length: %s\n", length($blob) if $DEBUG;

		#Print out rest of header for encryption
		print $out <<EOF;
${ENCRYPTION_ALGORITHM}
$usersalt
$mastersalt
$PBDKF2_ROUNDS
$uiv
$blob
EOF
        #Start encryption of payload...
        $cipher = Crypt::CBC->new( -key => $masterkey,
								   -cipher => 'Crypt::OpenSSL::AES',
								   -iv => $masteriv,
								   -literal_key => 1,
								   -header => 'none');
		$cipher->start('encrypting');
    } else { #No encryption
		print $out "none\n";
    }
}

#Write out the contents to file decrypting and decompressing as indicated
sub write_contents
{
	my $buf = '';
	my $status = Z_OK;
	my $cmpr;

	if($compress) { #Initialize Zlib deflation
		$cmpr = deflateInit(
			-Bufsize => $BUFSIZE,
			-Level => $COMPRESS_LEVEL)
			or die "Cannot create a deflation stream\n" ;
	}

    #Write out rest of file deflating & encrypting as appropriate
	while (read($in, $buf, $BUFSIZE) && $status == Z_OK) {
		($buf, $status) = $cmpr->deflate($buf) if $compress;
		$buf = $cipher->crypt($buf) if $encrypted;
		print $out $buf if defined($buf);
	}
	#Print deflation tail...
	if($compress) {
		($buf, $status) = $cmpr->flush if $compress;
		$buf = $cipher->crypt($buf) if $encrypted;
		print $out $buf if defined($buf);
	}
	warn "Error writing data: $status\n" if $status < 0;
	print $out $cipher->finish if $encrypted; #Print encryption tail

	close $in;
	close $out;
}

#Generate hex string of given length
sub hexstring
{
#	join('', map { (0..9, "A".."F") [rand 16] } 1..$_[0]); #Pseudo-random
	unpack("H[$_[0]]", Crypt::OpenSSL::Random::random_bytes(($_[0]+1)/2)) or
		die "Error: Insufficient randmoness exists to generate random hex string\n";
}


sub usage
{
	$0 =~ m|(.*/)?(.*)|;
    print STDERR <<EOF;

usage: $2 [options] <input-file> <output-file>

Note: Input and output files can be replaced by \'-\' to signify
reading and writing from STDIN and STDOUT respectively.
  
  Options:
   --compress|c            Deflate the input file before encrypting [Default]
   --nocompress            Don\'t deflate the input file before encrypting
   --debug|D               Print debugging statements to STDERR
   --file|f <passwd file>  Encrypt using password from first line of file
   --help|h                Display this usage message
   --Headers|H             Print headers to STDERR
   --password|p            Encrypt and query for password
   --Password|P <passwd>   Encrypt using password from command line
   --zip|z                 Decompress the output before encrypting

Note: the three options indicating encryption (--file, --password, --Password)
are mutually exclusive.

Note: --zip|z allows you to decompress the input file from gzip, zip, bzip2, and several other compressed formats. The --compressed|c (default) option then
optionally compresses the file using zlib deflate.

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
