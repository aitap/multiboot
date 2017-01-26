#!/usr/bin/perl
use warnings;
use strict;

sub parse_syslinux {
	my ($fh) = @_;
	my $return_flag = do { \my $o; };
	my @entries = ();
	my %lookup;
	my $title;
	my %actions = (
		label => sub { push @{$_[0]}, $lookup{$_[1]} = {}; },
		menu => sub {
			my %menu = (
				label => sub { $_[0]->[-1]{title} = join " ", @_[1..$#_] },
				hide => sub { shift->[-1]{hide} = 1 },
				begin => sub {
					my ($list,$inner_lookup,$inner_ttl) = parse_syslinux($fh);
					@lookup{keys %$inner_lookup} = values %$inner_lookup;
					push @{$_[0]}, { entries => $list, title => $inner_ttl };
				},
				end => sub { return $return_flag; },
				exit => sub { shift->[-1]{"exit"} = 1 },
				title => sub { $title = join " ", @_[1 .. $#_] },
			);
			return $menu{lc $_[1]}->(@_[0, 2 .. $#_]) if $menu{lc $_[1]};
		},
		kernel => sub { my $e = shift; $e->[-1]{kernel} = $_[0]; $e->[-1]{param} = [ @_[1..$#_] ]; },
		append => sub {
			my $e = shift;
			push @{$e->[-1]{initrd}}, split /,/, (/^initrd=(.*)/)[0] for grep /^initrd=/, @_;
			push @{$e->[-1]{param}}, grep { ! /^initrd=/ } @_;
		},
		initrd => sub { push @{$_[0][-1]{initrd}}, map { split /,/ } @_[1..$#_] },
	);
	$actions{com32} = $actions{linux} = $actions{kernel};
	# $actions{default} = $actions{label}; # ignoring the default doesn't hurt that much
	while (<$fh>) {
		chomp;
		my @kwds = split;
		next unless @kwds;
		if ($actions{lc $kwds[0]}) {
			last if (($actions{lc $kwds[0]}->(\@entries, @kwds[1..$#kwds])//'') eq $return_flag);
		}
	}
	return (\@entries,\%lookup,$title);
}

use Data::Dump qw(dd);
dd parse_syslinux(\*ARGV);
