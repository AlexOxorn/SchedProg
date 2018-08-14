#!/usr/bin/perl
use strict;
use warnings;

package InitGui;
use FindBin;
use lib "$FindBin::Bin/..";

use PerlLib::Colours;
use PerlLib::VersionString;


=head1 NAME

InitGui - sets up the standard Tk properties (fonts, colours)

=cut

#my $version_pod = << '=cut';

=head1 VERSION

Version 1.00

=cut

#our $VERSION = VersionString($version_pod);

=head1 SYNOPSIS

    use Tk;
    use Tk::InitGui;
    my $mw = MainWindow->new();
    my ($colours, $fonts) = InitGui->set($mw);

=head1 DESCRIPTION

Standardizes the look and feel of Tk tools

=head1 METHODS

=head2 set ($mw, [$size])

B<Inputs>

=over

=item C<$mw> Tk Main Window

=item C<$size> Normal font size for Unix (optional)

Note that Windows font size will be reduced by 2.

=back

B<Returns>

Hash reference of colours, with the following keys.

(Note that colours may vary depending on the user's default preferences)

     WindowHighlight
     DataBackground
     DataForeground
     WorkspaceColour
     ButtonBackground
     ButtonForeground
     WindowForeground
     DarkBackground
     ActiveBackground

Hash reference of fonts.

     normal      => arial, $size
     small       => arial, $size-2
     big         => arial, $size+2
     bold        => arial, bold, $size
     fixed       => courier new, $size+1
     fixedbold   => courier new, bold, $size+1

=cut

sub set {
    my $class = shift;
    my $mw    = shift;
    my $mysize = shift;

    # colours
    my %colours = GetSystemColours();
    SetSystemColours( $mw, \%colours );
    $mw->configure( -bg => $colours{WorkspaceColour} );

    # define normal font
    $mysize = $mysize || 12;
    my $size = $mysize - 1;
    $size = $size - 2 if $^O =~ /window/i;
    my $family = "newspaper";
    my %normalfont = (
        '-family',    'arial',  '-size',       $size,
        '-weight',    'normal', '-slant',      'roman',
        '-underline', 0,        '-overstrike', 0
    );
    my %boldfont = (%normalfont, -weight=>"bold");
    %boldfont = (%boldfont, -family=>'lucida') if $^O =~ /darwin/;
    my %bigboldfont = (%normalfont, -weight=>"bold", -size=>$size+2) ;
    %bigboldfont = (%bigboldfont, -family=>'lucida', -size=>$size+3) if $^O =~ /darwin/;

    # make fonts
    my $fonts = {
        normal => $mw->fontCreate(%normalfont),
        bold   => $mw->fontCreate( %boldfont, ),
        big    => $mw->fontCreate( %normalfont, -size => $size + 2 ),
        bigbold => $mw->fontCreate( %bigboldfont ),
        fixed  => $mw->fontCreate(
            %normalfont,
            -size   => $size + 1,
            -family => 'courier new'
        ),
        fixedbold => $mw->fontCreate(
            %normalfont,
            -family => 'courier new',
            -weight => 'bold',
            -size   => $size + 1,
        ),
        small => $mw->fontCreate( %normalfont, -size => $size - 2 ),
    };

    # set fonts
    $mw->optionAdd( "*font", $fonts->{normal} );

    # return info
    return ( \%colours, $fonts );

}
1;
