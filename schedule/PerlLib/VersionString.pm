#!/usr/bin/perl
use strict;

package PerlLib::VersionString;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(VersionString);

=head1 NAME

PerlLib::VersionString - grabs version info from POD string

=cut

#my $version_pod = << '=cut';

=head1 VERSION

Version 1.00

=cut

#our $VERSION = VersionString($version_pod);

=head1 SYNOPSIS
 
    my $version_pod = << '=cut';

    =head1 VERSION
 
    Version 1.01
 
    =cut

    our $VERSION = VersionString($version_pod);

=head1 EXPORTED METHODS

=head2 VersionString

Input string must contain, on a single line, the following:

Version I<version number>

B<Parameters>

=over

=item * C<$string> - string containing version information

=back

B<Returns>

The version number if it was found, else an empty string

=cut

sub VersionString {
    my $string = shift;
    if ($string=~ /^Version\s*(.*?)$/m) {
        return $1;
    }
    return "";
}


=head1 AUTHOR

Sandy Bultena
 
=cut
