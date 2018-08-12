#!/usr/bin/perl
use strict;
use warnings;

package ViewBase;
use FindBin;
use lib "$FindBin::Bin/..";
use List::Util qw( min max );
use GuiSchedule::GuiBlocks;
use Schedule::Conflict;
use Tk;

=head1 NAME

ViewBase - Basic View with days/weeks printed on it

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    Example of how to use code here

=head1 DESCRIPTION

Describes a View

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Status_text = "";
our $Max_id      = 0;
our @days        = ( "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" );
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
# global variables
# =================================================================

# =================================================================
# new
# =================================================================

=head2 new ()

creates a View object, draws the necessary grid and returns ViewBase.

B<Parameters>

C<$mw> Main Window

B<Returns>

View object

=cut

# =============================================================================
# new
# =============================================================================
sub new {
    my $class = shift;
    my $mw    = shift;

    my $self = {};
    $self->{-id} = ++$Max_id;
    $self->{-mw} = $mw;

    # ---------------------------------------------------------------
    # create a new toplevel window, add a canvas
    # ---------------------------------------------------------------
    my $tl = $mw->Toplevel;
    $tl->protocol( 'WM_DELETE_WINDOW', [ \&_close_view, $self ] );
    $tl->resizable( 0, 0 );

    # ---------------------------------------------------------------
    # Create bar at top to show colour coding of conflicts
    # ---------------------------------------------------------------
    my $f = $tl->Frame()->pack( -expand => 1, -fill => "x" );
    foreach my $c ( Conflict::TIME_TEACHER, Conflict::TIME,
                    Conflict::LUNCH, Conflict::MINIMUM_DAYS,
                    Conflict::AVAILABILITY
                  )
    {
        my $bg = Colour->new( $Scheduler::ConflictColours->{$c} );
        my $fg = Colour->new("white");
        $fg = Colour->new("black") if $bg->isLight;
        $f->Label(
                   -text       => Conflict->get_description($c),
                   -width      => 10,
                   -background => $bg->string,
                   -foreground => $fg->string
                 )->pack( -side => 'left', -expand => 1, -fill => "x" );
    }

    # ---------------------------------------------------------------
    # add canvas
    # ---------------------------------------------------------------
    my $cn = $tl->Canvas(
                          -height     => 700,
                          -width      => 700,
                          -background => "white"
                        )->pack();

    # ---------------------------------------------------------------
    # create object
    # ---------------------------------------------------------------
    bless $self, $class;
    $self->canvas($cn);
    $self->toplevel($tl);
    $self->xOffset(1);
    $self->yOffset(1);
    $self->xScale(0);
    $self->yScale(0);
    $self->wScale(100);
    $self->hScale(60);
    $self->currentScale(1);

    # ---------------------------------------------------------------
    # create scale menu
    # ---------------------------------------------------------------
    my $mainMenu = $mw->Menu();
    $tl->configure( -menu => $mainMenu );
    my $viewMenu =
      $mainMenu->cascade( -label => "View", -underline => 0, -tearoff => 0 );
    $viewMenu->command(
                        -label     => "50%",
                        -underline => 0,
                        -command   => [ \&resize_view, $self, 0.50 ]
                      );
    $viewMenu->command(
                        -label     => "75%",
                        -underline => 0,
                        -command   => [ \&resize_view, $self, 0.75 ]
                      );
    $viewMenu->command(
                        -label     => "100%",
                        -underline => 0,
                        -command   => [ \&resize_view, $self, 1.00 ]
                      );
    $self->main_menu($mainMenu);

    # ---------------------------------------------------------------
    # if there is a popup menu defined, make sure you can make it
    # go away by clicking the toplevel (as opposed to the menu)
    # ---------------------------------------------------------------
    if ( my $pm = $self->popup_menu ) {
        $tl->bind( '<1>', [ \&unpostmenu, $self ] );
        $tl->bind( '<2>', [ \&unpostmenu, $self ] );
    }

    # ---------------------------------------------------------------
    # create status bar
    # ---------------------------------------------------------------
    my $status;
    $self->status_bar( $self->create_status_bar($status) );

    # ---------------------------------------------------------------
    # return object
    # ---------------------------------------------------------------
    return $self;
}

# =================================================================
# set_title
# =================================================================

=head2 set_title (title)

Sets the title of the toplevel widget

=cut

sub set_title {
    my $self  = shift;
    my $title = shift || "";
    my $tl    = $self->toplevel();
    $tl->title($title);
}

# =================================================================
# resize_view
# =================================================================

=head2 resize_view ( View, Scale )

Resizes the View to the new Scale

=cut

sub resize_view {
    my $self  = shift;
    my $scale = shift;

    # get height and width of toplevel
    my $tlHeight = $self->toplevel->height;
    my $tlWidth  = $self->toplevel->width;

    # get height and width of canvas
    my @heights   = $self->canvas->configure( -height );
    my $canHeight = $heights[-1];
    my @widths    = $self->canvas->configure( -width );
    my $canWidth  = $widths[-1];

    # get current scaling sizes
    my $xScale       = $self->xScale;
    my $yScale       = $self->yScale;
    my $hScale       = $self->hScale;
    my $wScale       = $self->wScale;
    my $currentScale = $self->currentScale;

    # reset scales back to default value
    $xScale    /= $currentScale;
    $yScale    /= $currentScale;
    $wScale    /= $currentScale;
    $hScale    /= $currentScale;
    $tlHeight  /= $currentScale;
    $tlWidth   /= $currentScale;
    $canHeight /= $currentScale;
    $canWidth  /= $currentScale;

    $currentScale = $scale;

    # set scales to new size
    $xScale    *= $scale;
    $yScale    *= $scale;
    $wScale    *= $scale;
    $hScale    *= $scale;
    $tlHeight  *= $scale;
    $tlWidth   *= $scale;
    $canHeight *= $scale;
    $canWidth  *= $scale;

    # set the new scaling sizes
    $self->xScale($xScale);
    $self->yScale($yScale);
    $self->hScale($hScale);
    $self->wScale($wScale);
    $self->currentScale($currentScale);

    # set height and width of canvas and toplevel
    $self->canvas->configure( -width => $canWidth, -height => $canHeight );
    $self->toplevel->configure( -width  => int($tlWidth),
                                -height => int($tlHeight) );

    # now that you have changed sizes etc, redraw
    $self->redraw();

}

# =================================================================
# refresh gui
# =================================================================

=head2 refresh_gui ()

Update the graphics

=cut

sub refresh_gui {
    my $self = shift;
    $self->{-mw}->update;
}

# =================================================================
# snap_guiblock
# =================================================================

=head2 snap_guiblock (guiblock)

Takes the guiblock and forces it to be located on the nearest 
day and 1/2 hour boundary

=cut

sub snap_guiblock {
    my $self     = shift;
    my $guiblock = shift;
    if ($guiblock) {
        $guiblock->block->snap_to_day( 1, scalar(@days) );
        $guiblock->block->snap_to_time( min( keys %times ),
                                        max( keys %times ) );
    }
}

# =================================================================
# create_status_bar
# =================================================================

=head2 create_status_bar {
 
Status bar at the bottom of each View to show current movement type. 

=cut

sub create_status_bar {
    my $self = shift;

    return if $self->status_bar;

    my $status_frame =
      $self->toplevel->Frame(
                              -borderwidth => 0,
                              -relief      => 'flat',
                            )->pack( -side => 'bottom', -expand => 0, -fill => 'x' );

    $status_frame->Label(
                          -textvariable => \$Status_text,
                          -borderwidth  => 1,
                          -relief       => 'ridge',
                        )->pack( -side => 'left', -expand => 1, -fill => 'x' );

    return $status_frame;
}

# =================================================================
# add_guiblock
# =================================================================

=head2 add_guiblock ( GuiBlock )

Adds the GuiBlock to the list of GuiBlocks on the View. Returns the View object.

=cut

sub add_guiblock {
    my $self     = shift;
    my $guiblock = shift;
    $self->{-guiblocks} = {} unless $self->{-guiblocks};

    # save
    $self->{-guiblocks}->{ $guiblock->id } = $guiblock;
    return $self;
}

# =================================================================
# remove_all_guiblocks
# =================================================================

=head2 remove_all_guiblocks ( )

Remove all Guiblocks associated with this View.

=cut

sub remove_all_guiblocks {
    my $self = shift;
    $self->{-guiblocks} = {};
    return $self;
}

# =================================================================
# draw_block
# =================================================================

=head2 draw_block ( Block )

Turns the block into a GuiBlock and draws it on the View. 
Binds a popup menu if one is defined

=cut

sub draw_block {
    my $self   = shift;
    my $block  = shift;
    my $coords = $self->_get_pixel_coords($block);
    my $colour = '';
    $colour = "#abcdef" if $self->type eq 'teacher';
    $colour = "#80FF80" if $self->type eq 'lab';
    $colour = "#dddddd" unless $block->movable;

    my $scale = $self->currentScale;

    my $guiblock = GuiBlocks->new( $self, $block, $coords, $colour, $scale );

    # menu bound to individual gui-blocks
    $self->canvas->bind( $guiblock->group, '<3>',
                         [ \&postmenu, $self, Ev('X'), Ev('Y'), $guiblock ] );

    return $guiblock;
}

# =================================================================
# draw_background
# =================================================================

=head2 draw_background ( )

Draws the Schedule timetable on the View canvas.

=cut

sub draw_background {
    my $self         = shift;
    my $canvas       = $self->canvas;
    my $Xoffset      = $self->xOffset;
    my $Yoffset      = $self->yOffset;
    my $xScale       = $self->xScale;
    my $yScale       = $self->yScale;
    my $wScale       = $self->wScale;
    my $hScale       = $self->hScale;
    my $currentScale = $self->currentScale;

    $EarliestTime = min( keys %times );
    $LatestTime   = max( keys %times );

    # draw hourly lines
    my $xmax = $Xoffset + ( scalar @days );
    foreach my $time ( keys %times ) {

        # draw each hour line
        my $ycoord = $time - $EarliestTime + $Yoffset;
        $canvas->createLine(
                             $Xoffset, $ycoord, $xmax, $ycoord
                             ,
                             -fill => "dark grey",
                             -dash => "-"
                           );

        # hour text
        $canvas->createText( $Xoffset / 2, $ycoord, -text => $times{$time} );

        # for all inner times draw a dotted line for the half hour
        if ( $time != $LatestTime ) {
            $canvas->createLine(
                                 $Xoffset, $ycoord + 0.5, $xmax, $ycoord + 0.5
                                 ,
                                 -fill => "grey",
                                 -dash => "."
                               );

            # half-hour text TODO: decrease font size
            $canvas->createText( $Xoffset / 2, $ycoord + 0.5, -text => ":30" );
        }

    }

    # draw day lines
    my $ymax = $LatestTime - $EarliestTime + $Yoffset;
    for ( my $i = 0 ; $i <= scalar @days ; $i++ ) {
        my $xcoord = $i + $Xoffset;
        $canvas->createLine( $xcoord, 0, $xcoord, $ymax );

        # day text
        if ( $i < scalar @days ) {
            if ( $currentScale <= 0.5 ) {
                $canvas->createText( $xcoord + 0.5,
                                     $Yoffset / 2,
                                     -text => substr( $days[$i], 0, 1 ) );
            }
            else {
                $canvas->createText( $xcoord + 0.5,
                                     $Yoffset / 2,
                                     -text => $days[$i] );
            }
        }
    }

    $canvas->scale( 'all', $xScale, $yScale, $wScale, $hScale );
}

# =================================================================
# postmenu
# =================================================================

=head2 postmenu ( Canvas, Menu, X, Y )

Creates a Context Menu on the Canvas at X and Y.

=cut

sub postmenu {
    ( my $c, my $self, my $x, my $y, my $popup_guiblock ) = @_;
    if ( my $m = $self->popup_menu ) {
        $self->popup_guiblock($popup_guiblock);
        $m->post( $x, $y ) if $m;
    }
}

# =================================================================
# unpostmenu
# =================================================================

=head2 unpostmenu ( Canvas, Menu )

Removes the Context Menu.

=cut

sub unpostmenu {
    my ( $c, $self ) = @_;
    if ( my $m = $self->popup_menu ) {
        $m->unpost;
    }
    $self->unset_popup_guiblock();
}

# =================================================================
# update
# =================================================================

=head2 update ( $block )

Updates the position of any GuiBlocks, that have the same Block
as the currently moving GuiBlock.

=cut

sub update {
    my $self  = shift;
    my $block = shift;

    # go through each guiblock on the view
    if ( $self->guiblocks ) {
        foreach my $guiblock ( values %{ $self->guiblocks } ) {

            # race condition, no need to update the current moving block
            next if $guiblock->is_controlled;

            # guiblock's block is the same as moving block?
            if ( $guiblock->block->id == $block->id ) {

                # get new coordinates of block
                my $coords = $self->_get_pixel_coords($block);

                # get current x/y of the guiblock
                my ( $curXpos, $curYpos ) =
                  $guiblock->view->canvas->coords( $guiblock->rectangle );

                # bring the guiblock to the front, passes over others
                $guiblock->view->canvas->raise( $guiblock->group );

                # move guiblock to new position
                $guiblock->view->canvas->move(
                                               $guiblock->group,
                                               $coords->[0] - $curXpos,
                                               $coords->[1] - $curYpos
                                             );

            }
        }
    }
}

# =================================================================
# update_for_conflicts
# =================================================================

=head2 update_for_conflicts ( )

Determines conflict status for all GuiBlocks on this View and colours 
them accordingly.

=cut

sub update_for_conflicts {
    my $self = shift;
    my $type = shift;
    unless ($type) {
        my @c = caller();
        print "Dieing from: @c\n";
        die("must specify a type");    ##### remove die later
    }
    my $guiblocks = $self->guiblocks;

    my $view_conflict = 0;

    # for every guiblock on this view
    foreach my $guiblock ( values %$guiblocks ) {

        # colour block if it is necessary
        if ( $guiblock->block->moveable ) {

            $self->colour_block( $guiblock, $type );

            # create conflict number for entire view
            $view_conflict = $view_conflict | $guiblock->block->is_conflicted;
        }
    }

    return $view_conflict;
}

# =================================================================
# colour_block
# =================================================================

=head2 colour_block() 

colours the block according to conflicts

=cut 

sub colour_block {
    my $self     = shift;
    my $guiblock = shift;
    my $type     = shift;
    my $conflict =
      Conflict->most_severe( $guiblock->block->is_conflicted, $type );

    # change the colour of the block to the most important conflict
    if ($conflict) {
        $guiblock->change_colour( $Scheduler::ConflictColours->{$conflict} );
    }

    # no conflict found, reset back to default colour
    else {
        $guiblock->change_colour( $guiblock->colour );
    }
}

# =================================================================
# redraw
# =================================================================

=head2 redraw ( )

Redraws the View with new GuiBlocks and their positions.

=cut

sub redraw {
    my $self               = shift;
    my $teacher_lab_stream = $self->teacher_lab_stream;
    my $schedule           = $self->schedule;
    my $cn                 = $self->canvas;
    my $currentScale       = $self->currentScale;
    return unless $schedule;

    my @blocks;

    # possible that this is an empty View, so @blocks may be empty
    if ( defined $teacher_lab_stream ) {
        if ( $teacher_lab_stream->isa("Teacher") ) {
            @blocks = $schedule->blocks_for_teacher($teacher_lab_stream);
        }
        elsif ( $teacher_lab_stream->isa("Lab") ) {
            @blocks = $schedule->blocks_in_lab($teacher_lab_stream);
        }
        else { @blocks = $schedule->blocks_for_stream($teacher_lab_stream); }
    }

    # remove everything on canvas
    $cn->delete('all');

    # redraw background (things that don't change, like time, etc)
    $self->draw_background;

    # remove all guiblocks stored in the View
    $self->remove_all_guiblocks;

    # remove any binding to the canvas itself
    $self->canvas->CanvasBind( "<1>",               "" );
    $self->canvas->CanvasBind( "<B1-Motion>",       "" );
    $self->canvas->CanvasBind( "<ButtonRelease-1>", "" );

    # redraw all guiblocks
    foreach my $b (@blocks) {
        $b->start( $b->start );
        $b->day( $b->day );
        my $guiblock = $self->draw_block($b);
        $self->add_guiblock($guiblock);
    }

    $self->blocks( \@blocks );
    $schedule->calculate_conflicts;
    $self->update_for_conflicts;

}

# =================================================================
# getters/setters
# =================================================================

=head2 id ()

Returns the unique id for this View object.

=cut

sub id {
    my $self = shift;
    return $self->{-id};
}

=head2 teacher_lab_stream ( [Teacher/Lab/Stream Object] )

Get/set the Teacher, Lab or Stream associated to this View.

=cut

sub teacher_lab_stream {
    my $self = shift;
    $self->{-teacher_lab_stream} = shift if @_;
    return $self->{-teacher_lab_stream};
}

=head2 canvas ( [Canvas] )

Get/set the canvas of this View object.

=cut

sub canvas {
    my $self = shift;
    $self->{-canvas} = shift if @_;
    return $self->{-canvas};
}

=head2 mainMenu ([menu]) 

Get/set the main menu at top of View

=cut

sub main_menu {
    my $self = shift;
    $self->{-main_menu} = shift if @_;
    return $self->{-main_menu};
}

=head2 status_bar ([status_bar]) 

Get/set the main menu at top of View

=cut

sub status_bar {
    my $self = shift;
    $self->{-status_bar} = shift if @_;
    return $self->{-status_bar};
}

=head2 type ( [type] )

Get/set the type of this View object.

=cut

sub type {
    my $self = shift;
    $self->{-type} = shift if @_;
    return $self->{-type};
}

=head2 toplevel ( [toplevel] )

Get/set the toplevel of this View object.

=cut

sub toplevel {
    my $self = shift;
    $self->{-toplevel} = shift if @_;
    return $self->{-toplevel};
}

=head2 blocks ( [Blocks Ref] )

Get/set the Blocks of this View object.

=cut

sub blocks {
    my $self = shift;
    $self->{-blocks} = [] unless defined $self->{-blocks};
    $self->{-blocks} = shift if @_;
    return $self->{-blocks};
}

=head2 popup_guiblock ( [guiblock] ) 

Stores which button was used to generate the popup menu

=cut

sub popup_guiblock {
    my $self = shift;
    $self->{-popup_guiblock} = shift if @_;
    return $self->{-popup_guiblock};
}

=head2 unset_popup_guiblock () 

No block has a popup menu, so unset popup_guiblock

=cut

sub unset_popup_guiblock {
    my $self = shift;
    undef $self->{-popup_guiblock};
    return;
}

=head2 popup_menu ( [menu] )

Get/set the popup menu for this guiblock

=cut

sub popup_menu {
    my $self = shift;
    $self->{-popup} = shift if @_;
    return $self->{-popup};
}

=head2 schedule ( [Schedule] )

Get/set the Schedule of this View object.

=cut

sub schedule {
    my $self = shift;
    $self->{-schedule} = shift if @_;
    return $self->{-schedule};
}

=head2 conflict_status ( [Conflict] )

Get/set the Conflict Status of this View object.

=cut

sub conflict_status {
    my $self = shift;
    $self->{-conflict_status} = shift if @_;
    return $self->{-conflict_status};
}

=head2 xOffset ( [Int] )

Get/set the xOffset of this View object.

=cut

sub xOffset {
    my $self = shift;
    $self->{-xOffset} = shift if @_;
    return $self->{-xOffset};
}

=head2 yOffset ( [Int] )

Get/set the yOffset of this View object.

=cut

sub yOffset {
    my $self = shift;
    $self->{-yOffset} = shift if @_;
    return $self->{-yOffset};
}

=head2 xScale ( [Int] )

Get/set the xScale of this View object.

=cut

sub xScale {
    my $self = shift;
    $self->{-xScale} = shift if @_;
    return $self->{-xScale};
}

=head2 yScale ( [Int] )

Get/set the yScale of this View object.

=cut

sub yScale {
    my $self = shift;
    $self->{-yScale} = shift if @_;
    return $self->{-yScale};
}

=head2 wScale ( [Int] )

Get/set the wScale of this View object.

=cut

sub wScale {
    my $self = shift;
    $self->{-wScale} = shift if @_;
    return $self->{-wScale};
}

=head2 hScale ( [Int] )

Get/set the hScale of this View object.

=cut

sub hScale {
    my $self = shift;
    $self->{-hScale} = shift if @_;
    return $self->{-hScale};
}

=head2 currentScale ( [Int] )

Get/set the currentScale of this View object.

=cut

sub currentScale {
    my $self = shift;
    $self->{-currentScale} = shift if @_;
    return $self->{-currentScale};
}

=head2 guiBlocks ( )

Returns the GuiBlocks of this View object.

=cut

sub guiblocks {
    my $self = shift;
    return $self->{-guiblocks};
}

# =================================================================
# private subs
# =================================================================

=head2 _close_view ( )

Close the current View.

=cut

sub _close_view {
    my $self     = shift;
    my $toplevel = $self->toplevel;
    $toplevel->destroy;
}

=head2 _get_pixel_coords ( Block )

Gets the coordinates in pixels for where the time of the Block 
is placed on the View.

=cut

sub _get_pixel_coords {
    my $self  = shift;
    my $block = shift;
    return unless $block;

    my ( $x, $y, $x2, $y2 ) =
      $self->get_time_coords( $block->day_number, $block->start_number,
                              $block->duration );
    return [ $x, $y, $x2, $y2 ];    # return anonymous array
}

=head2 _set_pixel_coords ( GuiBlock, x, y )

Converts the X and Y coordinates into times and sets the time to the Block.

=cut

sub _set_block_coords {
    my $self     = shift;
    my $guiblock = shift;
    my $x        = shift;
    my $y        = shift;
    my $Xoffset  = $self->xOffset;
    my $Yoffset  = $self->yOffset;
    my $wScale   = $self->wScale;
    my $hScale   = $self->hScale;

    return unless $guiblock;

    my $day  = ( $x / $wScale ) - $Xoffset + 1;
    my $time = ( $y / $hScale ) - $Yoffset + $EarliestTime;
    $guiblock->block->day_number($day);
    $guiblock->block->start_number($time);
}

=head2 _set_pixel_coords ( x, y, y2)

Converts the X and Y coordinates into times.

=cut

sub get_block_coords {
    my $self    = shift;
    my $x       = shift;
    my $y       = shift;
    my $y2      = shift;
    my $Xoffset = $self->xOffset;
    my $Yoffset = $self->yOffset;
    my $wScale  = $self->wScale;
    my $hScale  = $self->hScale;

    my $day      = ( $x / $wScale ) - $Xoffset + 1;
    my $time     = ( $y / $hScale ) - $Yoffset + $EarliestTime;
    my $duration = ( $y2 + 1 - $y ) / $hScale;

    if (wantarray) {
        return [ $day, $time, $duration ];
    }
    else {
        ( $day, $time, $duration );
    }
}

=head2 get_time_coords ( day, start, duration )

Converts the times into X and Y coordinates and returns them

=cut

sub get_time_coords {
    my $self     = shift;
    my $day      = shift;
    my $start    = shift;
    my $duration = shift;

    my $Xoffset = $self->xOffset;
    my $Yoffset = $self->yOffset;
    my $wScale  = $self->wScale;
    my $hScale  = $self->hScale;

    my $x = ( $Xoffset + ( $day - 1 ) ) * $wScale;
    my $y = ( $Yoffset + ( $start - $EarliestTime ) ) * $hScale;
    my $x2 = $wScale + $x - 1;
    my $y2 = $duration * $hScale + $y - 1;

    if (wantarray) {
        return ( $x, $y, $x2, $y2 );
    }
    else {
        [ $x, $y, $x2, $y2 ];
    }
}

# =================================================================
# footer
# =================================================================

=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2016, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;
