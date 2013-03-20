#!/usr/bin/perl
use warnings;
use strict;
use WWW::Mechanize;
my $m = WWW::Mechanize->new(autocheck => 1);
my ($url,$regex,$where) = @ARGV;

$m->get($url);

$m->get( $m->find_link(url_regex => qr/$regex/) || die "$regex: link not found\n", ':content_file' => $where );
print "\n";
