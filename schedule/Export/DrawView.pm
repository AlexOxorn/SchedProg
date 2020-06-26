#!/usr/bin/perl
use strict;
use warnings;

package DrawView;
use FindBin;
use lib "$FindBin::Bin/..";

use List::Util qw( min max );

=head1 NAME

DrawView - code that draws the View stuff only

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Schedule;
    use Tk;
    use Export::PDF;
    
    my $Schedule = Schedule->read_YAML('myschedule_file.yaml');
    my $teacher  = $Schedule->teachers()->get_by_name("Sandy","Bultena");
    my @blocks   = $schedule->blocks_for_teacher($teacher);
        
    # ----------------------------------------------------------
    # create a pdf, as well as a Tk canvas
    # ----------------------------------------------------------
    my $pdf         = PDF->new();
    my $mw          = MainWindow->new();
    my $cn          = $mw->Canvas()->pack();

    # ----------------------------------------------------------
    # what scale you want
    # ----------------------------------------------------------
    my $scl = {
             -xoff  => 1,       # before being scaled by xscl
             -yoff  => 1,       # before being scaled by yscl
             -xorg  => 0,       # start drawing at this position
             -yorg  => 0,       # start drawing at this position
             -xscl  => 100,     # stretch horizontally
             -yscl  => 60,      # stretch vertically
             -scale => 1,       # 1 = 100%.  Text may be modified if scale < 1
    };

    # ----------------------------------------------------------
    # Draw the grid on both pdf and canvas
    # ----------------------------------------------------------
    DrawView->draw_background($cn,$scl);
    DrawView->draw_background($pdf,$scl); 
    
    # ----------------------------------------------------------
    # Draw the teacher blocks on both pdf and canvas
    # ----------------------------------------------------------
    foreach my $block (@blocks) {
        DrawView->draw_block($cn,$block,$scl,"teacher");
        DrawView->draw_block($pdf,$block,$scl,"teacher");
    }
    
       

=head1 DESCRIPTION

This code creates drawings only.  No binding of canvas objects, no changing
positions or colours.

=head1 Scaling Info (hash pointer)

=over

=item * weekly grid starts at this position (number will be scaled by scaling factors I<i>C<org>

=over

C<< -xoff => >> I<int> 

C<< -yoff => >> I<int> 

=back 

=item * the entire diagram starts at this position

=over

C<< -xorg => >> I<int> 

C<< -yorg => >> I<int>

=back 

=item * how much to stretch the diagram horizontally and vertically 
(1 day has a width of 1 before stretching, and 1 hour has a height of 1 before stretching)

=over 

C<< -xscl => >> I<float>

C<< -yscl => >> I<float>

=back

=back

=over

=item * Overall scale... has no affect on the diagram but represents an indication
of how scaled it is to its "natural" size.  Affects what text is written into
the block.  (Less than .75 teachers will be indicated by initials only)

=over

C<< -scale => >> I<float> 

=back

=back

=cut 

=head1 METHODS

=cut

our $Edge = 5;
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
our $lime_green   = "#ccffcc";
our $sky_blue     = "#b3e6ff";
our $blue         = Colour->add( $sky_blue, $sky_blue );
our $teal         = Colour->add( $sky_blue, $lime_green );

my $colours = { lab => "#cdefab", teacher => "#abcdef", stream => $teal };

# =================================================================
# draw_background
# =================================================================

=head2 draw_background ( $canvas, $scaling_info )

Draws the Schedule timetable on the specified canvas.

B<Parameters>

=over

=item * Canvas to draw on

=item * Scaling Info (hash pointer)

=back

=cut

sub draw_background {
    my $self         = shift;
    my $canvas       = shift;
    my $scl          = shift;
    my $x_offset     = $scl->{-xoff};
    my $y_offset     = $scl->{-yoff};
    my $xorig        = $scl->{-xorg};
    my $yorig        = $scl->{-yorg};
    my $h_stretch    = $scl->{-xscl};
    my $v_stretch    = $scl->{-yscl};
    my $currentScale = $scl->{-scale};

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
                             $xmin, $yhour, $xmax, $yhour,
                             -fill => "dark grey",
                             -dash => "-"
        );

        # hour text
        $canvas->createText( ( $xmin + $xorig ) / 2,
                             $yhour, -text => $times{$time} );

        # for all inner times draw a dotted line for the half hour
        if ( $time != $LatestTime ) {
            $canvas->createLine(
                                 $xmin, $yhalf, $xmax, $yhalf,
                                 -fill => "grey",
                                 -dash => "."
            );

            # half-hour text TODO: decrease font size
            $canvas->createText( ( $xmin + $xorig ) / 2,
                                 $yhalf, -text => ":30" );
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
        $canvas->createLine( $xday, $yorig, $xday, $ymax );

        # day text
        if ( $i < scalar @days ) {
            if ( $currentScale <= 0.5 ) {
                $canvas->createText( ( $xday + $xdayend ) / 2,
                                     ( $ymin + $yorig ) / 2,
                                     -text => substr( $days[$i], 0, 1 ) );
            }
            else {
                $canvas->createText(
                                     ( $xday + $xdayend ) / 2,
                                     ( $ymin + $yorig ) / 2,
                                     -text => $days[$i]
                );
            }
        }
    }

}

# =================================================================
# get_block_text
# =================================================================

=head2 draw_block ( $block, $scale, $type )

Get the text for a specific type of block

B<Parameters>

=over

=item * Block object

=item * scale (1=100%)

=item * type of view [teacher|block|stream] (affects what gets drawn on the block)

=back

B<Returns>

block text

=cut

sub get_block_text {
    my $class  = shift;
    my $block = shift;
    my $scale = shift || 1;
    my $type = shift || "teacher";
    
    # --------------------------------------------------------------------
    # get needed block information
    # --------------------------------------------------------------------
    my $blockNum         = $block->section->course->number || " ";
    my $blockSec         = " (" . $block->section->number . ")";
    my $blockSectionName = $block->section->title;
    my @labs           = $block->labs;
    my $blockLab       = join( ",", @labs );
    my $blockDuration  = $block->duration;
    my $blockStartTime = $block->start_number;
    my @streams        = $block->section->streams;
    my $blockStreams   = join( ",", @streams );

    # if teacher name is two long, split into multipline lines
    my @teachers         = $block->teachers;
    my $blockTeacher     = "";
    foreach my $t (@teachers) {
        my $name = "$t";
        if ( length($name) > 15 ) {
            $blockTeacher .= join( "\n", split " ", $name ) . "\n";
        }
        else {
            $blockTeacher .= "$t\n";
        }
    }
    chomp $blockTeacher;
    

    # --------------------------------------------------------------------
    # The diagram has been scaled down,
    # ... change what gets printed on the block
    # --------------------------------------------------------------------
    if ( $scale <= 0.75 ) {

        # -----------------------------------------------------------
        # course (scale < .75)
        # -----------------------------------------------------------
        # remove program number from course number (i.e. 420-506 becomes 506)
        if ( $scale == 0.5 ) {
            $blockNum =~ s/.*\-//g;
        }

        # -----------------------------------------------------------
        # teachers (scale < .75)
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
        # labs/resources (scale < .75)
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
        # streams (scale < .75)
        # -----------------------------------------------------------
        $blockStreams = "";

        # only add stream/text if no teachers or labs,
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

    # --------------------------------------------------------------------
    # define what to display
    # --------------------------------------------------------------------

    my $blockText = "$blockNum\n$blockSectionName\n";
    $blockText .= "$blockTeacher\n"
      if ( $type ne "teacher" && $blockTeacher );
    $blockText .= "$blockLab\n" if ( $type ne "lab" && $blockLab );
    $blockText .= "$blockStreams\n"
      if ( $type ne "stream" && $blockStreams );
    chomp($blockText);

    
    return $blockText;
}

# =================================================================
# draw_block
# =================================================================

=head2 draw_block ( $canvas, $block, $scaling_info, $type )

Draws the Schedule timetable on the specified canvas.

B<Parameters>

=over

=item * Canvas to draw on

=item * Block object

=item * Scaling Info (hash pointer)

=item * type of view [teacher|block|stream] (affects what gets drawn on the block)

=back

B<Returns>

=over

=item * hashref of

=over

=item -lines => array point of canvas line objects

=item -text => text printed on the block,

=item -coords => array of canvas coordinates for block

=item -rectangle => canvas rectangle object

=item -colour => colour of block

=back

=back

=cut

sub draw_block {
    my $class  = shift;
    my $canvas = shift;
    my $block  = shift;
    my $scl    = shift;
    my $type   = shift;
    my $scale  = $scl->{-scale};

    return unless $block;

    # --------------------------------------------------------------------
    # set the colour and pixel width of edge
    # --------------------------------------------------------------------
    my $colour = shift || $colours->{$type} || $colours->{teacher};
    my $edge = shift || $Edge;
    $Edge = $edge;

    $colour = Colour->string($colour);

    # --------------------------------------------------------------------
    # get coords
    # --------------------------------------------------------------------
    my @c = DrawView->get_coords( $block->day_number, $block->start_number,
                                  $block->duration, $scl );
    my $coords = \@c;

    # --------------------------------------------------------------------
    # get needed block information
    # --------------------------------------------------------------------
    my $blockText = DrawView->get_block_text($block,$scale,$type);

    # --------------------------------------------------------------------
    # draw the block
    # --------------------------------------------------------------------
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

    # group rectange and text to create guiblock,
    # so that they both move as one on UI
    my $group = $canvas->createGroup( [ 0, 0 ],
                                    -members => [ $rectangle, $text, @lines ] );

    return {
             -lines     => \@lines,
             -text      => $text,
             -coords    => $coords,
             -rectangle => $rectangle,
             -colour    => $colour,
      }

}

# =================================================================
# coords_to_day_time_duration
# =================================================================

=head2 coords_to_day_time_duration ( $x, $y1, $y2, $scaling_info )

Determines the day, start time, and duration based on canvas coordinates

B<Parameters>

=over

=item * x position (determines day)

=item * y1,y2 position (determines start and duration)

=item * Scaling Info (hash pointer)

=back

B<Returns>

=over

=item * hashref of

=over

=item * day of week (1 = Monday)

=item * start time (24 hour clock)

=item * duration (in hours)

=back

=back

=cut

sub coords_to_day_time_duration {
    my $class = shift;
    my $x     = shift;
    my $y     = shift;
    my $y2    = shift;
    my $scl   = shift;

    my $day = $x / $scl->{-xscl} - $scl->{-xoff} + 1 - $scl->{-xorg};
    my $time =
      $y / $scl->{-yscl} - $scl->{-yoff} + $EarliestTime - $scl->{-yorg};
    my $duration = ( $y2 + 1 - $y ) / $scl->{-yscl};

    return ( $day, $time, $duration );
}

# =================================================================
# get_coords
# =================================================================

=head2 get_coords ( $day, $start, $duration, $scaling_info )

Determines the canvas coordinates based on 
day, start time, and duration

B<Parameters>

=over

=item * day of week (1 = Monday)

=item * start time (24 hour clock)

=item * duration (in hours)

=item * Scaling Info (hash pointer)

=back

B<Returns>

=over

=item * arrayref of canvas coordinates for the rectangle representing 
this time slot 

($x1, $y1, $x2, $y2)

=back

=cut

sub get_coords {
    my $class    = shift;
    my $day      = shift;
    my $start    = shift;
    my $duration = shift;
    my $scl      = shift;

    my ( $x, $x2 ) =
      _days_x_coords( $day, $scl->{-xoff}, $scl->{-xorg}, $scl->{-xscl} );
    my ( $y, $y2 ) =
      _time_y_coords( $start,        $duration, $scl->{-yoff},
                      $scl->{-yorg}, $scl->{-yscl} );

    return ( $x, $y, $x2, $y2 );
}

# =================================================================
# get the shades of the colour
# =================================================================

=head2 get_colour_shades ($colour)

B<Returns>

=over

=item * Array of colours lighter than $colour (gradient)

=item * Array of colours darker than $colour (gradient)

=item * Recommended colour for text if overlaid on $colour

=back

=cut

sub get_colour_shades {
    my $colour = shift;
    my $edge   = $Edge;

    # convert colour to hue, saturation, light
    my ( $h, $s, $l ) = Colour->hsl($colour);

    # calculate the light/dark changes
    my $light_intensity = $l > .7 ? ( 1 - $l ) * 75 : 30 * .75;
    my $dark_intensity  = $l < .3 ? $l * 75         : 30 * .75;

    # recommended text colour
    my $textcolour = "black";
    unless ( Colour->isLight($colour) ) {
        $textcolour = "white";
    }

    # create a light/dark gradient of colours
    my @light;
    my @dark;

    foreach my $i ( 0 .. $edge - 1 ) {
        my $lfactor = ( 1 - ( $i / $edge ) ) * $light_intensity;
        my $dfactor = ( 1 - ( $i / $edge ) ) * $dark_intensity;
        push @light, Colour->lighten( $lfactor, $colour );
        push @dark, Colour->darken( $dfactor, $colour );
    }

    # return info
    return \@light, \@dark, $textcolour;
}

# =================================================================
# using scale info, get the y limits for a specific time period
# =================================================================
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

# =================================================================
# using scale info, get the x limits for a specific day
# =================================================================
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

=head1 Canvas Requirements

This code draws on a generic canvas.  

The interface to this canvas follows a subset of the Tk->canvas methods.  For a
more detailed list of what the various options means, check the Tk manuals online.

It must follow these rules:

=head2 Coordinates

The coordinate system of the canvas is the same as the Tk coordinate system,
where the origin (0,0) is the top left corner, and 'y' increases as it goes 
down the page.

=head2 createLine

B<Parameters>

=over

=item * C<x1,y1,x2,y2,> coordinates of the start and stop position of the line

=item * C<< -fill => "colour", >> the colour of the line (OPTIONAL... default is "black"),

=item * C<< -dash => "dash string" >> the type of dash line (OPTIONAL ... default is no dash)

=back

B<Returns>

A canvas CreateLine object



=head2  createText

B<Parameters> 

=over

=item * C<x,y> coordinates of the start position of the text (lower left corner
unless other alignment options are used

=item * C<< -text => "text string", >> text string

=item * C<< -font => "name of font", >> fontname (OPTIONAL)

=item * C<< -fill => "colour", >> colour of the text (OPTIONAL ... default is "black")

=back

B<Returns>

A canvas CreateText object




=head2 createRectangle

B<Parameters>

=over

=item *  C<x1,y1,x2,y2,> coordinates of two opposite corners of the rectangle

=item * C<< -fill => "colour", >> colour of the rectangle area (OPTIONAL ... default is no colour)

=item * C<< -outline => "colour", >> colour of the rectangle border (OPTIONAL ... default is no border)

=back

B<Returns>

A canvas CreateRectangle object

=cut

1;
