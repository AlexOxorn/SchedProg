#!/usr/bin/perl
use strict;
use warnings;

package DrawView;
use FindBin;
use lib "$FindBin::Bin/..";

use Schedule::Schedule;
use Schedule::Conflict;
use List::Util qw( min max );

our @days = ( "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" );
our %times = (
               8  => "8am",
               9  => "9am",
               10 => "10am",
               11 => "11am",
               12 => "12pm",
               13 => "1pm",
               14 => "2pm",
               15 => "3pm",
               16 => "4pm",
               17 => "5pm",
               18 => "6pm"
);
our $EarliestTime = min( keys %times );
our $LatestTime   = max( keys %times );

# =================================================================
# draw_background
# =================================================================

=head2 draw_background ( )

Draws the Schedule timetable on the View canvas.

=cut

sub draw_background {
    my $self         = shift;
    my $canvas       = shift;
    my $x_offset     = shift;
    my $y_offset     = shift;
    my $xorig        = shift;
    my $yorig        = shift;
    my $h_stretch    = shift;
    my $v_stretch    = shift;
    my $currentScale = shift;

    $EarliestTime = min( keys %times );
    $LatestTime   = max( keys %times );

    # --------------------------------------------------------------------
    # draw hourly lines
    # --------------------------------------------------------------------
    my ( undef, $xmax ) =
      _days_x_coords( scalar(@days), $x_offset, $xorig, $h_stretch );
    my ( $xmin, undef ) = _days_x_coords( 1, $x_offset, $xorig, $h_stretch );

    foreach my $time ( keys %times ) {

        # draw each hour line
        my ( $yhour, $yhalf ) =
          _time_y_coords( $time, 0.5, $y_offset, $yorig, $v_stretch );
        $canvas->createLine(
                             $xmin, $yhour, $xmax, $yhour
                             ,
                             -fill => "dark grey",
                             -dash => "-"
        );

        # hour text
        $canvas->createText( $xmin / 2, $yhour, -text => $times{$time} );

        # for all inner times draw a dotted line for the half hour
        if ( $time != $LatestTime ) {
            $canvas->createLine(
                                 $xmin, $yhalf, $xmax, $yhalf
                                 ,
                                 -fill => "grey",
                                 -dash => "."
            );

            # half-hour text TODO: decrease font size
            $canvas->createText( $xmin / 2, $yhalf, -text => ":30" );
        }

    }

    # --------------------------------------------------------------------
    # draw day lines
    # --------------------------------------------------------------------
    my ( $ymin, $ymax ) =
      _time_y_coords( $EarliestTime, ( $LatestTime - $EarliestTime ),
                      $y_offset, $yorig, $v_stretch );

    foreach my $i ( 0 .. scalar(@days) ) {
        my ( $xday, $xdayend ) =
          _days_x_coords( $i + 1, $x_offset, $xorig, $h_stretch );
        $canvas->createLine( $xday, 0, $xday, $ymax );

        # day text
        if ( $i < scalar @days ) {
            if ( $currentScale <= 0.5 ) {
                $canvas->createText( ( $xday + $xdayend ) / 2,
                                $ymin / 2, -text => substr( $days[$i], 0, 1 ) );
            }
            else {
                $canvas->createText( ( $xday + $xdayend ) / 2,
                                     $ymin / 2, -text => $days[$i] );
            }
        }
    }

    #  $canvas->scale( 'all', $xScale, $yScale, $wScale, $hScale );
}

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
our $Edge = 5;

sub draw_block {
    my $this   = shift;
    my $canvas = shift;
    my $block  = shift;
    my $coords = shift;
    my $type   = shift;

    # set the colour and pixel width of edge
    my $colour = shift || '#abcdef';
    my $scale  = shift || 1;
    my $edge   = shift || $Edge;
    $Edge = $edge;

    # get canvas from view to draw on
    $colour = Colour->string($colour);

    # get needed block information
    my $blockNum         = $block->section->course->number || " ";
    my $blockSec         = " (" . $block->section->number . ")";
    my $blockSectionName = $block->section->title;
    my @teachers         = $block->teachers;
    my $blockTeacher     = join( "\n", @teachers );
    my @labs             = $block->labs;
    my $blockLab         = join( ",", @labs );
    my $blockDuration    = $block->duration;
    my $blockStartTime   = $block->start_number;
    my @streams          = $block->section->streams;
    my $blockStreams     = join( ",", @streams );

    # ===============================================================
    # View window has been scaled down
    # ===============================================================
    if ( $scale <= 0.75 ) {

        # -----------------------------------------------------------
        # course
        # -----------------------------------------------------------
        # remove program number from course number (i.e. 420-506 becomes 506)
        if ( $scale == 0.5 ) {
            $blockNum =~ s/.*\-//g;
        }

        # -----------------------------------------------------------
        # teachers
        # -----------------------------------------------------------
        $blockTeacher = "";

        # do not add teachers if this is a teacher view
        if ( $type ne "teacher" ) {
            $blockTeacher = join(
                ", ",
                map {
                        substr( $_->firstname, 0, 1 )
                      . substr( $_->lastname, 0, 1 )
                  } @teachers
            );

            # add ellipsis to end of teacher string as necessary
            if ( $scale == 0.5 && @teachers >= 3 ) {
                $blockTeacher = substr( $blockTeacher, 0, 7 ) . "...";
            }
            elsif ( @teachers >= 4 ) {
                $blockTeacher = substr( $blockTeacher, 0, 11 ) . "...";
            }

        }

        # -----------------------------------------------------------
        # labs/resources
        # -----------------------------------------------------------
        $blockLab = "";
        if ( $type ne "lab" ) {

            $blockLab = join( ", ", map { $_->number } @labs );

            # add ellipsis to end of lab string as necessary
            if ( $scale == 0.5 && @labs >= 3 ) {
                $blockLab = substr( $blockLab, 0, 7 ) . "...";
            }
            elsif ( @labs >= 4 ) {
                $blockLab = substr( $blockLab, 0, 11 ) . "...";
            }
        }

        # -----------------------------------------------------------
        # streams
        # -----------------------------------------------------------
        $blockStreams = "";

        # only add streams if no teachers or labs,
        # or GuiBlock can fit all info (i.e. duration of 2 hours or more)
        if ( $type ne "stream" || $blockDuration >= 2 ) {
            $blockStreams = join( ", ", map { $_->number } @streams );

            # add ellipsis to end of stream string as necessary
            if ( $scale == 0.5 && @streams >= 3 ) {
                $blockStreams = substr( $blockStreams, 0, 7 ) . "...";
            }
            elsif ( @streams >= 4 ) {
                $blockStreams = substr( $blockStreams, 0, 11 ) . "...";
            }

        }

    }

    # ===============================================================
    # define what to display
    # ===============================================================

    my $blockText = "$blockNum.$blockSec\n$blockSectionName\n";
    $blockText .= "$blockTeacher\n"
      if ( $type ne "teacher" && $blockTeacher );
    $blockText .= "$blockLab\n" if ( $type ne "lab" && $blockLab );
    $blockText .= "$blockStreams\n"
      if ( $type ne "stream" && $blockStreams );
    chomp($blockText);

    # ===============================================================
    # draw the block
    # ===============================================================
    #create rectangle
    my $rectangle =
      $canvas->createRectangle(
                                @$coords,
                                -fill    => $colour,
                                -outline => $colour
      );

    # shade edges of guiblock rectangle
    my @lines;
    my ( $x1, $y1, $x2, $y2 ) = @$coords;
    my ( $light, $dark, $textcolour ) = get_colour_shades($colour);
    foreach my $i ( 0 .. $edge - 1 ) {
        push @lines,
          $canvas->createLine( $x2 - $i, $y1 + $i, $x2 - $i, $y2 - $i, $x1 + $i,
                               $y2 - $i, -fill => $dark->[$i] );
        push @lines,
          $canvas->createLine( $x2 - $i, $y1 + $i, $x1 + $i, $y1 + $i, $x1 + $i,
                               $y2 - $i, -fill => $light->[$i] );
    }

    # set text
    my $text = $canvas->createText(
                                    ( $x1 + $x2 ) / 2, ( $y1 + $y2 ) / 2,
                                    -text => $blockText,
                                    -fill => $textcolour
    );
    my @coords = $canvas->coords($rectangle);

    # group rectange and text to create guiblock,
    # so that they both move as one on UI
    my $group = $canvas->createGroup( [ 0, 0 ],
                                    -members => [ $rectangle, $text, @lines ] );

    return {
             -lines     => \@lines,
             -text      => $text,
             -coords    => \@coords,
             -rectangle => $rectangle
      }

}

# =================================================================
# get the shades of the colour
# =================================================================

=head2 get_colour_shades ($colour, $edge)

Based on the colour, find the shades

=cut

sub get_colour_shades {
    my $colour = shift;
    my $edge   = $Edge;
    my ( $h, $s, $l ) = Colour->hsl($colour);
    my $light_intensity = $l > .7 ? ( 1 - $l ) * 75 : 30 * .75;
    my $dark_intensity  = $l < .3 ? $l * 75         : 30 * .75;

    my @light;
    my @dark;
    my $textcolour = "black";
    unless ( Colour->isLight($colour) ) {
        $textcolour = "white";
    }
    foreach my $i ( 0 .. $edge - 1 ) {
        my $lfactor = ( 1 - ( $i / $edge ) ) * $light_intensity;
        my $dfactor = ( 1 - ( $i / $edge ) ) * $dark_intensity;
        push @light, Colour->lighten( $lfactor, $colour );
        push @dark, Colour->darken( $dfactor, $colour );
    }
    return \@light, \@dark, $textcolour;
}

# =================================================================
# convert coords to day/time, or vice versa
# =================================================================

sub coords_to_day_time_duration {
    my $class = shift;
    my $x     = shift;
    my $y     = shift;
    my $y2    = shift;
    my $scl   = shift;

    my $day      = ( $x - $scl->{-xorg})/ $scl->{-xscl}  - $scl->{-xoff} + 1;
    my $time     = ( $y - $scl->{-yorg})/ $scl->{-yscl}  - $scl->{-yoff} + $EarliestTime;
    my $duration = ( $y2 + 1 - $y ) / $scl->{-yscl};

    return ( $day, $time, $duration );
}

sub get_coords {
    my $class    = shift;
    my $day      = shift;
    my $start    = shift;
    my $duration = shift;
    my $scl      = shift;

    my ( $x, $x2 ) =
      _days_x_coords( $day,          $scl->{-xoff},
                               $scl->{-xorg}, $scl->{-xscl} );
    my ( $y, $y2 ) =
      _time_y_coords( $start,        $duration, $scl->{-yoff},
                               $scl->{-yorg}, $scl->{-yscl} );

    return ( $x, $y, $x2, $y2 );
}

sub time_y_coords {
    my $class = shift;
    _time_y_coords(@_);
}

sub _time_y_coords {
    my $start     = shift;
    my $duration  = shift;
    my $y_offset  = shift;
    my $yorig     = shift;
    my $v_stretch = shift;

    $y_offset = $y_offset * $v_stretch + $yorig;
    my $y = $y_offset + ( $start - $EarliestTime ) * $v_stretch;
    my $y2 = $duration * $v_stretch + $y - 1;
    return ( $y, $y2 );
}


sub days_x_coords {
    my $class = shift;
    _days_x_coords(@_);
}

sub _days_x_coords {
    my $day       = shift;
    my $x_offset  = shift;
    my $xorig     = shift;
    my $h_stretch = shift;
    $x_offset = $x_offset * $h_stretch + $xorig;

    my $x  = $x_offset + ( $day - 1 ) * $h_stretch;
    my $x2 = $x_offset + ($day) * $h_stretch - 1;
    return ( $x, $x2 );
}

1;
