#!/usr/bin/perl
package syslinux;
use warnings;
use strict;

use Carp;

my %root_directives = (
	include => sub { push @{$_[0]}, @{ parse_file($_[1]) } },
	label => sub { push @{$_[0]}, { label => $_[1] } },
	(map { my $n = $_; ( $n, sub { $_[0][-1]{kernel} = $_[1] } ) } (qw/kernel linux com32/)),
	append => sub {
		$_[1] =~ s/\binitrd=(\S+)/push @{$_[0][-1]{initrd}},(split m|,|,$1); ""/ge;
		$_[0][-1]{append} = $_[1];
	},
	initrd => sub { push @{$_[0][-1]{initrd}}, $_[1] },
	menu => sub { _parse_menu_line($_[0], $_[1]) },
	text => sub {
		croak "TEXT <what?>" unless "help" eq lc $_[1];
		$_[0][-1]{help} .= $_ while defined ($_ = readline $_[0][0]) && lc $_ ne "endtext\n";
	},
	(map { my $n = $_; ( "f$n", sub { $_[0][-1]{f}[$n] = $_[1]; } ) } (1..12)),
);

my %menu_directives = (
	label => sub { $_[0]->[-1]{menu}{label} = $_[1] },
	begin => sub { push @{$_[0]}, { menu => { name => $_[1], labels => _parse($_[0][0]) } }; },
	title => sub { $_[0][-1]{menu}{title} = $_[1] },
	exit => sub { $_[0][-1]{menu}{exit} = 1 },
	hide => sub { $_[0][-1]{menu}{hide} = 1 },
);

sub parse_file {
	my ($file) = @_;
	open my $fh, "<", $file or croak "$file: $!\n";
	my $config = _parse($fh);
	close $fh;
	return $config;
}

sub _parse {
	my ($fh) = @_;
	my $config = [$fh, {}];
	while (my $line = <$fh>) {
		chomp $line;
		$line =~ s/^\s+//;
		my @keywords = split /\s+/,$line,2;
		shift @keywords until $keywords[0] or !@keywords;
		next if !@keywords or $keywords[0] =~ /^#/; # ignore comments
		last if $line =~ /^\s*menu\s+end\s*$/i; # XXX any better ways to return from recursively-called function?
		$root_directives{lc $keywords[0]}->($config, $keywords[1]) if defined $root_directives{lc $keywords[0]};
	}
	shift @$config; # delete $fh
	return $config;
}


sub _parse_menu_line {
	my ($config, $line) = @_;
	my (@parts) = split /\s+/, $line, 2;
	$menu_directives{lc $parts[0]}->($config, $parts[1]) if defined $menu_directives{lc $parts[0]};
}

sub save {
	my ($config, $file) = @_;
	open my $wr, ">", $file or croak "$file: $!\n";
	my $old_fh = select $wr;
	_dump($config,0);
	select $old_fh;
	close $wr;
}

sub _dump {
	my ($data, $indent) = @_;
	for (@$data) {
		if (defined $_->{menu}{labels}) {
			print "\t"x$indent,"MENU BEGIN ",$_->{menu}{name}||"","\n";
			print "\t"x($indent+1),"MENU TITLE ",$_->{menu}{title},"\n" if $_->{menu}{title};
			_dump($_->{menu}{labels},$indent+1);
			print "\t"x$indent,"MENU END\n";
		} else {
			print "\t"x$indent,"MENU TITLE ",$_->{menu}{title},"\n" if $_->{menu}{title};
			for my $n (1..12) { $_->{f}[$n] && print "\t"x$indent,"F$n ",$_->{f}[$n],"\n" }
			print "\t"x$indent,"LABEL ",$_->{label},"\n" if $_->{label};
			$indent++;
			print "\t"x$indent,"MENU LABEL ", $_->{menu}{label}, "\n" if $_->{menu}{label};
			unless ($_->{label}) { $indent--; next }
			print "\t"x$indent,"MENU EXIT\n" if $_->{menu}{exit};
			print "\t"x$indent,"MENU HIDE\n" if $_->{menu}{hide};
			print "\t"x$indent,"TEXT HELP\n", $_->{help}, "ENDTEXT\n" if $_->{help};
			print "\t"x$indent,"KERNEL ", $_->{kernel}, "\n" if $_->{kernel};
			print "\t"x$indent,"APPEND ", $_->{append}, "\n" if $_->{append};
			print "\t"x$indent,"INITRD ", join(",",@{$_->{initrd}}), "\n" if $_->{initrd} && @{$_->{initrd}};
			$indent--;
			print "\n";
		}
	}
}

return 1 if caller;

require Getopt::Long;
Getopt::Long->import;

require File::Copy;
File::Copy->import("copy");

require File::Path;
File::Path->import("make_path");

require File::Basename;
File::Basename->import(qw/basename dirname/);

my ($source, $target, $config, $name, $append);
GetOptions(
	'source=s' => \$source,
	'target=s' => \$target,
	'config=s' => \$config,
	'name=s'   => \$name,
	'addconfig=s' => \$append,
) || die "Usage: $0 -s <source dir> -t <target dir> -c <source config file> -a <target config file> -n <submenu name>\n";
for ($source, $target, $name, $append) {
	die "Usage: $0 -s <source dir> -t <target dir> -c <source config file> -a <target config file> -n <submenu name>\n" unless $_;
}

unless ($config) {
	for my $try (qw(isolinux.cfg isolinux/isolinux.cfg boot/isolinux/isolinux.cfg)) {
		last if -f ($config = $source."/".$try);
	}
};
die "No config found\n" unless -f $config;

(my $dirname = basename($append)) =~ s/\.cfg$//i;
make_path("$target/$dirname");

my $data = parse_file($config);

sub process {
	for (@{$_[0]}) {
		for my $n (1..12) { test_copy($_->{f}[$n]); }
		if ($_->{label}) {
			test_copy($_) for ($_->{kernel}, $_->{initrd} ? @{$_->{initrd}} : () );
			next unless $_->{append};
			for my $item (split /\s+/,$_->{append}) {
				if (-r ($item =~ m|^/| ? $source : dirname($config))."/".(my $file = $item)) {
					test_copy($item);
					$_->{append} =~ s/\Q$file/$item/;
				}
			};
		} elsif ($_->{menu}{labels}) {
			process($_->{menu}{labels});
		}
	}
}

sub test_copy {
	return unless $_[0];
	warn "overwriting $_[0]\n" if -e "$target/$dirname/".basename($_[0]);
	copy(
		($_[0] =~ m|^/| ? $source : dirname($config))."/".$_[0],
		"$target/$dirname/".basename($_[0])
	) or die "$_[0]: $!\n";
	$_[0] = "/$dirname/".basename($_[0]);
}

process($data);

save([ { menu => { title => $name, name => $dirname, labels => $data } }],$append);
