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
				hide => sub { $_[0]->[-1]{hide} = 1 },
				exit => sub { $_[0]->[-1]{"exit"} = 1 },
				begin => sub {
					my ($list,$inner_lookup,$inner_ttl) = parse_syslinux($fh);
					@lookup{keys %$inner_lookup} = values %$inner_lookup;
					push @{$_[0]}, { entries => $list, title => $inner_ttl };
				},
				end => sub { return $return_flag; },
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

sub apply_fixups {
	my ($entries, $table, $kernel_args, $boot_path) = @_;
	return [ map { # this only modifies the insides of the entries
		if ($_->{kernel}) {
			# check for memtest/memdisk/plop, set to linux16, add check for grub_platrorm=pc
			if ($_->{kernel} =~ /memtest|memdisk|plop|plpbt|mt86|netboot/i) { # this requires BIOS
				$_->{if} = q{ [ ${grub_platform} = pc ] };
				$_->{linux16} = 1;
			}
			# nearly all non-linux16 should receive the additional arguments
			if (!$_->{linux16}) {
				if ($_->{kernel} =~ /ntpasswd/i) { # special case: as of now, ntpasswd doesn't support efifb
					$_->{if} = q{ [ ${grub_platform} = pc ] };
				} else {
					push @{$_->{param}}, $kernel_args;
				}
			}
			# fixup the relative paths
			for my $f ($_->{kernel}, @{$_->{initrd}}) {
				$f = "${boot_path}/$f" if $f !~ m{^/};
			}
		} elsif ($_->{entries}) {
			# recurse into submenus
			$_->{entries} = apply_fixups($_->{entries}, $table, $kernel_args, $boot_path);
		}
		# delete hotkey marks
		$_->{title} =~ tr/^//d;
		$_
	} map {
		# remove untranslated .c32 as a separate step because this modifies the list
		(defined $_->{kernel} and $_->{kernel} =~ /\.c32$/i) ? do { warn "Untranslated COM32: $_->{kernel} @{$_->{param}}\n"; () } : $_
	} map {
		# substitute the presets from table before all else
		if (defined $_->{kernel} and $table->{$_->{kernel}}) {
			for my $p (qw(param initrd)) {
				$_->{$p} = [ @{ $table->{$_->{kernel}}{$p}||[] } ]; # deep copy
			}
			$_->{kernel} = $table->{$_->{kernel}}{kernel};
		}
		$_;
	} map {
		# unroll ifcpu64.c32 before substituting settings from table
		(defined $_->{kernel} and $_->{kernel} eq "ifcpu64.c32") ? do {
			my (@b64, @b32);
			while ((my $prm = shift @{$_->{param}}) ne "--") {
				push @b64, $prm
			}
			@b32 = @{$_->{param}};
			(
				{
					title => $_->{title}." (64-bit)",
					kernel => $b64[0],
					param => [ @b64[1..$#b64 ] ],
					if => q{ [ ${grub_platform} != efi ] || [ ${grub_cpu} = x86_64 ] },
				},
				{
					title => $_->{title}." (32-bit)",
					kernel => $b32[0],
					param => [ @b32[1..$#b32 ] ],
					if => q{ [ ${grub_platform} != efi ] || [ ${grub_cpu} = i386 ] },
				}
			)
		} : $_
	} map {
		# filter out the hidden/exit entries: if we need them, they are in the table
		($_->{hide} || $_->{exit}) ? () : $_
	} @$entries ];
}

sub export_grub2 {
	my ($entries, $title, $image, $indent) = @_;
	$indent //= 0;
	my $pr = sub { print "\t"x$indent, @_, "\n" };
	$pr->(qq[submenu "$title" {]);
	$indent++;
	for (@$entries) {
		if ($_->{if}) {
			$pr->("if $_->{if}; then");
			$indent++;
		}
		if ($_->{entries}) {
			export_grub2($_->{entries}, $_->{title}, $image, $indent);
		} elsif ($_->{kernel}) {
			$pr->(qq[menuentry "$_->{title}" {]);
			$indent++;
			$pr->(qq[loopback loop $image]);
			$pr->(($_->{linux16} ? "linux16" : "linux"), " (loop)", join " ", $_->{kernel}, @{$_->{param}});
			$pr->(join " ", "initrd", map "(loop)$_",@{$_->{initrd}}) if @{$_->{initrd}};
			$indent--;
			$pr->("}");
		}
		if ($_->{if}) {
			$indent--;
			$pr->("fi");
		}
	}
	$indent--;
	$pr->("}");
}

die unless @ARGV == 3 or @ARGV == 4;
my ($parameter,$path,$image,$title) = @ARGV;
my ($entries, $table, $title_parsed) = parse_syslinux(\*STDIN);
export_grub2(apply_fixups($entries, $table,$parameter,$path),($title||$title_parsed||die"No menu title"),$image);
