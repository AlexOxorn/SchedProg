#!/usr/bin/perl;
use strict;
use warnings;

package PerlLib::Get_Module_Versions;

require Exporter;
our @ISA    = ("Exporter");
our @EXPORT = qw(get_module_versions);

# --------------------------------------------------------------------------
# use file find to find all modules in a given directory
# --------------------------------------------------------------------------
my @modules;
use File::Find;
sub _perls { push @modules, $File::Find::name if /\.w?p[lm]$/; }

=head1 NAME

Get_Module_Versions - get version numbers from all modules in use,
within a given directory tree

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use PerlLib::Get_Module_Versions;

    use FindBin;
    my $EXE_PATH = $FindBin::Bin;

    # get version numbers
    my $versions = get_module_versions($EXE_PATH);

    # print info
    foreach my $module ( sort keys %$versions ) {
        print "$module\t$versions->{$mod}\n";
    }

=head1 DESCRIPTION

This module finds all the C<*.pm>, C<*.pl> and C<*.wpl> files within a
specified directory (and all sub-directories).

The version number is found by checking all possible package names (based
on the file name) and looking for the package variable C<$VERSION>.

=head2 Example

Assume a directory structure of

    myTool/
        Func1/
            Foo.pm
            Bar.pm

If C<get_module_versions(./myTool)> is called, then the found modules will
be

    myTool/Func1/Foo.pm
    myTool/Func2/Bar.pm

These modules will be compared against the %INC to determine if they are
actually used.

To obtain the version number of C<Foo>, the following package variables
will be examined in this order.

    $myTool::Func1::Foo::VERSION
    $Func1::Foo::VERSION
    $Foo::VERSION

The search for a version number will end as soon as a defined,
'true' version number has been found.

=head1 EXPORTED METHODS

=cut

# =======================================================================
# get_module_versions
# =======================================================================

=head2 get_module_versions

Returns a hash with module names as the key, and version numbers
as the value.

=head3 Parameters

=over

=item * root directory path of perl modules to be analyzed (optional)

If root path is not specified, then the path of the executable will be
searched, as well as the directories in the environment variable PERL5LIB

=back

=head3 Returns

A hash reference of the form:

    { module_name => version number }

=cut

sub get_module_versions {

    my $exe_path = shift;
    undef @modules;

    # ---------------------------------------------------------------
    # use file find to get all modules in executable path
    # ---------------------------------------------------------------
    if ($exe_path) {
        finddepth( \&_perls, $exe_path );
    }

    # ---------------------------------------------------------------
    # if path is not specified, find modules in executable path
    # and all paths defined by PERL5LIB
    # ---------------------------------------------------------------
    else {
        use FindBin;
        my $exe = $FindBin::Bin;

        my @paths;

        # windows
        if ($^O =~ /win/i) {
            $ENV{PERL5LIB} = '' unless $ENV{PERL5LIB};
            my $install_dir = $exe;
           push @paths, $install_dir, split /;/, $ENV{PERL5LIB};
        }

        # unix
        else {
           push @paths, $exe, split /:/, $ENV{PERL5LIB};
        }

        foreach my $path ( @paths ) {
            finddepth( \&_perls, $path );
        }
    }

    # ---------------------------------------------------------------
    # loop through INC hash and find version numbers for all modules
    # that are in the $exe_path
    # ---------------------------------------------------------------

    my %versions;
    my $max_inc = 0;
    foreach my $inc ( keys %INC ) {
        if ( grep { /\/$inc/ } @modules ) {
            ( my $package = $inc ) =~ s/\..+$//;
            $package =~ s/\//::/g;
            my $ver;
            my $i = 0;
            while ( $package && !$ver ) {
                no strict 'refs';
                $ver = ${ $package . "::VERSION" } || '';
                $package =~ s/^.*?::// or $package = '';
                $i++;
                last if $i > 10;
            }
            $max_inc = $max_inc > length($inc) ? $max_inc : length($inc);
            $versions{$inc} = $ver;
        }
    }

    # ---------------------------------------------------------------
    # add extra white space at end of module name, so they will
    # 'line-up' if using fixed width font
    # ---------------------------------------------------------------
    foreach my $inc ( keys %versions ) {
        my $ver = delete $versions{$inc};
        $versions{ $inc . " " x ( $max_inc - length($inc) ) } = $ver;
    }

    # ---------------------------------------------------------------
    # return hash
    # ---------------------------------------------------------------
    return \%versions;
}

=cut

=head1 AUTHOR

Sandy Bultena

=cut

1;
