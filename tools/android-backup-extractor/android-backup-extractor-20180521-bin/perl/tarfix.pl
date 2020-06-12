#!/usr/bin/perl
#============================================================= -*-perl-*-
#
# tarfix.pl: Fix broken tar files produced by android backup when using
#            -shared flag
#
# USAGE
#   tarfix [<input file>|-] [<output file>|-]
#
# DESCRIPTION
# 
#  'adb backup' is buggy and for some combinations of '-shared' with
#   other options it produces an *uncompressed* (despite the
#   compression line being 1) corrupted tar output. The corruption
#   occurs as follows:
#
#   1. The 512-byte header block for each file is preceded by an extra
#      four bytes "00 00 02 00". Note that the 3rd byte '02' is
#      (trivially) twice the number of blocks taken up by the header
#
#   2. The data is divided into groups of 64 512-byte blocks with the
#      final group being as many blocks as needed to fill out the
#      data.  Before each group, 4 bytes are inserted of form "00 00
#      xy 00" where the hex pair xy is equal to twice the number of
#      512-byte blocks in the group. So, if the group is a full 64
#      blocks, then "00 00 80 00" is inserted. Similarly, if there
#      only Z blocks in the group then 'xy' is equal to 2*z in hex.
#
#   Note: Summing the third bytes of all the skips equals two times
#   the total number of blocks in the tar file (headers + data).
#
#   Note: The file ends with a 17-byte string starting with '78 da'
#   which happens to be the magic number used by 'adb backup' for zlib
#   deflate.  When this 17-byte string is inflated, it yields a
#   1024-byte file filled with nulls (00). This 17-byte string is
#   obviously meaningless and is discarded.
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

use strict;
use warnings;
#use Data::Dumper; #Just for debugging...

#========================================================================
### I/O Setup
my ($in, $out);

my $infile = $ARGV[0];
if(! defined($infile) || $infile eq '-') {
	$in = *STDIN;
}else {
	(open($in, "<:raw", $infile) or
	 die "Error: Can't open input file: $infile\n");
}

my $outfile = $ARGV[1];
if(! defined($outfile) || $outfile eq '-') {
	$out = *STDOUT;
}else {
	(open($out, ">:raw", $outfile) or 
	 die "Error: Can't open output file: $outfile\n");
}

binmode $in;
binmode $out;

#========================================================================
#Skip four bytes "00 00 02 00" before reading each new 512-byte header.
#In a sense, this corresponds to two times the number of header blocks.
while(seek($in, 4, 1) && (my $bytes=read($in, my $header, 512))) {
	if($bytes == 17 && unpack('H4', $header) eq '78da') {
		last; #17-byte (nonsense) trailer at end of backup file
	}elsif($bytes < 512) {
		die "Error: Unknown data at end of tar file...\n";
	}

	#Note: number of data bytes in the file is an 11 digit octal
	#string starting at position 124 in the header. The data is
	#divided into 512-byte blocks.
	my $blocks = int((oct(substr($header, 124, 11)) + 511)/512);

	print $out $header; #Print header

	for(my $i=1; $i <= $blocks; $i++) { #Print data
		seek($in, 4, 1) unless ($i-1)%64; 
        #Skip 4 bytes at the beginning of every group of 64 blocks of
        #data.  Note we are skipping 00 00 xy 00 00 where xy is equal
        #to two times the number of blocks following before either the
        #next group of 64 blocks (i.e. 80 = 128 or 2 times 64 blocks)
        #or the end of the data section. 
		#Hence the sum of all the 3rd bytes for all the skips is equal
        #to twice the total number of blocks.

		read($in, my $data, 512) or
			die "Error: Can't read next block of data...\n";
		print $out $data;
	}
}


