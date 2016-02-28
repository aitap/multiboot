#!/usr/bin/perl
use warnings;
use strict;
use WWW::Mechanize;
my $m = WWW::Mechanize->new(autocheck => 1);
my ($url,$where,@regex) = @ARGV;
$m->get($url);
while (@regex > 1) {
	my $rx = shift @regex;
	$m->get(($m->find_all_links(url_regex => qr/$rx/))[-1] || die "$rx: link not found\n");
}
exec("wget", "-O", $where, "-c", ($m->find_link(url_regex => qr/$regex[0]/) || die("$regex[0]: link not found\n"))->url_abs);
die "wget: $!\n";
