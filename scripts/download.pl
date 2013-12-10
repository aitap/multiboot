#!/usr/bin/perl
use warnings;
use strict;
use WWW::Mechanize;
my $m = WWW::Mechanize->new(autocheck => 1);
my ($url,$regex,$where) = @ARGV;
$m->get($url);
$m->add_header(Referer => undef); # sf.net sends HTML if referrer is present
for ($m->get( $m->find_link(url_regex => qr/$regex/) || die("$regex: link not found\n"), ':content_file' => $where )) {
	die $_->status_line unless $_->is_success;
}
