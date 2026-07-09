#!/usr/bin/perl
# Test stub for native/loader.pl — same CLI (LIB SYMBOL) but no dylib is
# loaded. Behavior is driven by $STUB_PRIMARY:
#   ok       (default) — get prints a fixed JSON track, send/seek/test succeed
#   null               — get prints "null", test exits 5 (daemon, no info)
#   fail               — every symbol fails (exit 1)
# $STUB_TRACK_TITLE overrides the fixed track's title (history/marquee tests).
# Output devices are fixed ("Stub Speakers", "Stub AirPods"); output_set
# persists the choice in $CLAUDE_PLUGIN_DATA/stub-output-current so a
# following output_list reflects the switch.
use strict;
use warnings;

my $lib    = shift @ARGV // die "usage: loader.pl LIB SYMBOL\n";
my $symbol = shift @ARGV // die "usage: loader.pl LIB SYMBOL\n";
my $mode   = $ENV{STUB_PRIMARY} // "ok";

exit 1 if $mode eq "fail";

my $title = $ENV{STUB_TRACK_TITLE} // "Stub Song";
my $track = "{\"title\":\"$title\",\"artist\":\"Stub Artist\",\"album\":\"Stub Album\","
  . '"bundleIdentifier":"com.stub.player","appName":"StubPlayer","playing":true,'
  . '"processIdentifier":1,"elapsedTime":75,"elapsedTimeNow":75.4,'
  . '"duration":200,"playbackRate":1,"timestamp":"2026-07-09T00:00:00Z",'
  . '"outputDevice":"Stub Speakers"}';

my @devices = ("Stub Speakers", "Stub AirPods");
my $state   = ($ENV{CLAUDE_PLUGIN_DATA} // "/tmp") . "/stub-output-current";

sub current_output {
  if (open my $fh, "<", $state) {
    my $c = <$fh>;
    close $fh;
    chomp $c if defined $c;
    return $c if defined $c && length $c;
  }
  return $devices[0];
}

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
if ($symbol eq "adapter_output_list") {
  my $cur = current_output();
  my $list = join ",", map { "\"$_\"" } @devices;
  print "{\"current\":\"$cur\",\"devices\":[$list]}\n";
  exit 0;
}
if ($symbol eq "adapter_output_set") {
  my $want = $ENV{MEDIA_OUTPUT_DEVICE};
  die "missing MEDIA_OUTPUT_DEVICE\n" unless defined $want && length $want;
  my $target;
  if ($want =~ /^\d+$/ && $want >= 1 && $want <= @devices) {
    $target = $devices[$want - 1];
  } else {
    my @hits = grep { index(lc $_, lc $want) >= 0 } @devices;
    $target = $hits[0] if @hits == 1;
    if (@hits > 1) {
      print STDERR "ambiguous output device \"$want\" — matches: "
        . join(", ", @hits) . "\n";
      exit 4;
    }
  }
  if (!defined $target) {
    print STDERR "no output device matches \"$want\" — available: "
      . join(", ", @devices) . "\n";
    exit 4;
  }
  open my $fh, ">", $state or die "cannot write $state\n";
  print $fh "$target\n";
  close $fh;
  print "{\"ok\":true,\"current\":\"$target\"}\n";
  exit 0;
}
die "unknown symbol: $symbol\n";
