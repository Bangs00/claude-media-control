#!/usr/bin/perl
# Test stub for native/loader.pl — same CLI (LIB SYMBOL) but no dylib is
# loaded. Behavior is driven by $STUB_PRIMARY:
#   ok       (default) — get prints a fixed JSON track, send/seek/test succeed
#   null               — get prints "null", test exits 5 (daemon, no info)
#   fail               — every symbol fails (exit 1)
use strict;
use warnings;

my $lib    = shift @ARGV // die "usage: loader.pl LIB SYMBOL\n";
my $symbol = shift @ARGV // die "usage: loader.pl LIB SYMBOL\n";
my $mode   = $ENV{STUB_PRIMARY} // "ok";

exit 1 if $mode eq "fail";

my $track = '{"title":"Stub Song","artist":"Stub Artist","album":"Stub Album",'
  . '"bundleIdentifier":"com.stub.player","appName":"StubPlayer","playing":true,'
  . '"processIdentifier":1,"elapsedTime":75,"elapsedTimeNow":75.4,'
  . '"duration":200,"playbackRate":1,"timestamp":"2026-07-09T00:00:00Z"}';

if ($symbol eq "adapter_get") {
  print(($mode eq "null") ? "null\n" : "$track\n");
  exit 0;
}
if ($symbol eq "adapter_send") {
  die "missing MEDIA_SEND_COMMAND\n" unless defined $ENV{MEDIA_SEND_COMMAND};
  exit 0;
}
if ($symbol eq "adapter_seek") {
  die "missing MEDIA_SEEK_SECONDS\n" unless defined $ENV{MEDIA_SEEK_SECONDS};
  exit 0;
}
if ($symbol eq "adapter_test") {
  exit(($mode eq "null") ? 5 : 0);
}
if ($symbol eq "adapter_artwork") {
  my $prefix = $ENV{MEDIA_ARTWORK_PATH} or die "missing MEDIA_ARTWORK_PATH\n";
  if ($mode eq "null") { print "null\n"; exit 0 }
  my $path = "$prefix.jpg";
  open my $fh, ">", $path or die "cannot write $path\n";
  print $fh "stub-jpeg";
  close $fh;
  print "{\"path\":\"$path\",\"bytes\":9,\"mimeType\":\"image/jpeg\"}\n";
  exit 0;
}
die "unknown symbol: $symbol\n";
