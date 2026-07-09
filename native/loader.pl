#!/usr/bin/perl
# loader.pl — loads the compiled adapter dylib and calls one exported symbol.
#
# Must be run via /usr/bin/perl (an Apple platform binary, bundle id
# com.apple.perl5) so mediaremoted accepts the process as an Apple client and
# the MediaRemote read entitlement check (macOS 15.4+) passes. Technique from
# ungive/mediaremote-adapter (BSD-3-Clause, see NOTICE).
#
# Usage: /usr/bin/perl loader.pl LIB_PATH SYMBOL
#   LIB_PATH — absolute path to libadapter.dylib
#   SYMBOL   — adapter_get | adapter_send | adapter_seek | adapter_test |
#              adapter_artwork | adapter_output_list | adapter_output_set
# Parameters are passed via environment variables (MEDIA_SEND_COMMAND,
# MEDIA_SEEK_SECONDS, MEDIA_ARTWORK_PATH, MEDIA_OUTPUT_DEVICE); perl XSUBs
# cannot take C args.

use strict;
use warnings;
use DynaLoader;

my $lib    = shift @ARGV or die "usage: loader.pl LIB SYMBOL\n";
my $symbol = shift @ARGV or die "usage: loader.pl LIB SYMBOL\n";

die "lib not found: $lib\n" unless -e $lib;
die "unknown symbol: $symbol\n"
  unless $symbol =~ /^adapter_(get|send|seek|test|artwork|output_list|output_set)$/;

my $handle = DynaLoader::dl_load_file($lib, 0)
  or die "failed to load $lib: " . (DynaLoader::dl_error() // '') . "\n";

my $addr = DynaLoader::dl_find_symbol($handle, $symbol)
  or die "symbol '$symbol' not found in $lib\n";

DynaLoader::dl_install_xsub("main::entry", $addr);

{
  no strict 'refs';
  &{"main::entry"}();
}
