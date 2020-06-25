#!/usr/bin/perl
use strict;
use warnings;

package View;
use FindBin;
use lib "$FindBin::Bin/..";
use List::Util qw( min max );
use GuiSchedule::GuiBlocks;
use Schedule::Undo;
use GuiSchedule::ViewBase;
use Schedule::Conflict;
use GuiSchedule::AssignBlock;
use Schedule::Blocks;

use Tk;
our @ISA = qw(ViewBase);

=head1 NAME

View - describes the visual representation of a Schedule

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Schedule;
    use GuiSchedule::View
    use Tk;
    
    my $mw          = MainWindow->new();
    my $Schedule = Schedule->read_YAML('myschedule_file.yaml');
    my $teacher  = $Schedule->teachers()->get_by_name("Sandy","Bultena");
    
    my $View = View->new($mw,$schedule,$teacher);
    
    #... change the schedule... 
    
    $View->redraw;
    

=head1 DESCRIPTION

Describes a View

=head1 METHODS

=cut

# =================================================================
# global and package variables
# =================================================================
my $Undo_number   = "";
my $Redo_number   = "";
my $Clicked_block = 0;
my $EarliestTime  = $ViewBase::EarliestTime;
my $LatestTime    = $ViewBase::LatestTime;
my $selectColour  = 'royalblue';

# =================================================================
# new
# =================================================================

=head2 new ()

creates a View object, draws the necessary GuiBlocks and returns the View object.

B<Parameters>

-mw => Tk mainWindow

-schedule => where course-sections/teachers/labs/streams are defined

-obj => Teacher/Lab/Stream that the View is being made for

B<Returns>

View object

=cut

sub new {

    my $class    = shift;
    my $mw       = shift;
    my $schedule = shift;
    my $obj      = shift;

    # ---------------------------------------------------------------
    # type of view depends on which object it is for
    # ---------------------------------------------------------------
    my $type;
    my @blocks;
    if ( $obj->isa("Teacher") ) {
        @blocks = $schedule->blocks_for_teacher($obj);
        $type   = "teacher";
    }
    elsif ( $obj->isa("Lab") ) {
        @blocks = $schedule->blocks_in_lab($obj);
        $type   = "lab";
    }
    else {
        @blocks = $schedule->blocks_for_stream($obj);
        $type   = "stream";
    }

    # ---------------------------------------------------------------
    # create the ViewBase
    # ---------------------------------------------------------------
    my $self = $class->SUPER::new($mw);
    my $tl   = $self->toplevel;
    $tl->protocol( 'WM_DELETE_WINDOW', [ \&_close_view, $self ] );

    # ---------------------------------------------------------------
    # set some parameters
    # ---------------------------------------------------------------
    $self->blocks( \@blocks );
    $self->schedule($schedule);
    $self->type($type);
    $self->obj($obj);

    # ---------------------------------------------------------------
    # set the title
    # ---------------------------------------------------------------
    my $title;
    if ( $obj && $obj->isa('Teacher') ) {
        $self->set_title(
                 uc( substr( $obj->firstname, 0, 1 ) ) . " " . $obj->lastname );
    }
    elsif ($obj) {
        $self->set_title( $obj->number );
    }

    # ---------------------------------------------------------------
    # popup menu for guiblocks
    # ---------------------------------------------------------------
    $self->setup_popup_menu($mw);

    # ---------------------------------------------------------------
    # undo/redo
    # ---------------------------------------------------------------
    $self->setup_undo_redo($mw);

    # ---------------------------------------------------------------
    # refresh drawing - redrawing creates the guiblocks
    # ---------------------------------------------------------------
    $self->redraw();
    $self->schedule->calculate_conflicts;
    $self->update_for_conflicts( $self->type );

    # return object
    return $self;
}

# ============================================================================
# setup popup menu
# ============================================================================

=head2 setup_popup_menu ($mw) {
 
create the pop-up menu BEFORE drawing the blocks, so that it can be
bound to each block (done in $self->redraw)

=cut

sub setup_popup_menu {
    my $self = shift;
    my $mw   = shift;
    my $type = $self->type;

    # create menu
    my $pm = $mw->Menu( -tearoff => 0 );

    # for all menus
    $pm->command( -label   => "Toggle Moveable/Fixed",
                  -command => [ \&toggle_movement, $self ], );

    # Extra stuff depending on type of view
    my $mm = $pm->cascade( -label => 'Move Class to', -tearoff => 0 );
    my @array;

    # sorted array of teacher or lab
    if ( $self->type eq 'teacher' ) {
        @array =
          sort { $a->lastname cmp $b->lastname } $self->schedule->all_teachers;
    }
    elsif ( $self->type eq 'lab' ) {
        @array =
          sort { $a->number cmp $b->number } $self->schedule->all_labs;
    }
    elsif ( $self->type eq 'stream' ) {
        @array =
          sort { $a->number cmp $b->number } $self->schedule->all_streams;
    }

    # remove object of the view
    @array = grep { $_->id != $self->obj->id } @array;

    # create sub menu
    foreach my $obj (@array) {
        my $name;
        if ( $self->type eq 'teacher' ) {
            $name = $obj->firstname . ' ' . $obj->lastname;
        }
        else {
            $name = $obj->number;
        }
        $mm->command( -label   => $name,
                      -command => [ \&move_class, $self, $obj ] );
    }

    # save
    $self->popup_menu($pm);

}

# ============================================================================
# setup undo_redo
# ============================================================================

=head2 setup_undo_redo ($mw) {
 
create code for undo and redo

=cut

sub setup_undo_redo {
    my $self = shift;
    my $mw   = shift;
    my $tl   = $self->toplevel;

    # ---------------------------------------------------------------
    # bind keys
    # ---------------------------------------------------------------
    $tl->bind( '<Control-KeyPress-z>' => [ \&undo, $self, 'undo' ] );
    $tl->bind( '<Meta-Key-z>'         => [ \&undo, $self, 'undo' ] );

    $tl->bind( '<Control-KeyPress-y>' => [ \&undo, $self, 'redo' ] );
    $tl->bind( '<Meta-Key-y>'         => [ \&undo, $self, 'redo' ] );

    # ---------------------------------------------------------------
    # add undo/redo to main menu
    # ---------------------------------------------------------------
    my $mainMenu = $self->main_menu;
    $mainMenu->add(
                    'command',
                    -label   => "Undo",
                    -command => [ \&undo, $tl, $self, 'undo' ]
    );
    $mainMenu->add(
                    'command',
                    -label   => "Redo",
                    -command => [ \&undo, $tl, $self, 'redo' ]
    );

    # ---------------------------------------------------------------
    # add undo/redo to status_frame
    # ---------------------------------------------------------------
    my $status_frame = $self->status_bar;
    $status_frame->Label(
                          -textvariable => \$Undo_number,
                          -borderwidth  => 1,
                          -relief       => 'ridge',
                          -width        => 15
    )->pack( -side => 'right', -fill => 'x' );

    $status_frame->Label(
                          -textvariable => \$Redo_number,
                          -borderwidth  => 1,
                          -relief       => 'ridge',
                          -width        => 15
    )->pack( -side => 'right', -fill => 'x' );

}

# ============================================================================
# setup assign blocks
# ============================================================================

=head2 setup_assign_blocks {
 
Set up code so that the user can select blocks and assign to this view object

Allows for creation of new sections and teachers

=cut

sub setup_assign_blocks {
    my $self = shift;
    my $cn   = $self->canvas;

    #Loop through each half hour time slot,
    # and create and draw AsignBlock for each
    my @allBlocks;
    foreach my $day ( 1 ... 5 ) {
        foreach my $start ( $EarliestTime * 2 ... ( $LatestTime * 2 ) - 1 ) {
            push( @allBlocks, AssignBlock->new( $self, $day, $start / 2 ) );
        }
    }

    #BINDS MOUSE 1 to the setup of AssignBlock selection, then calls a function
    #to bind the mouse movement
    $cn->CanvasBind(
        '<Button-1>',
        [
           sub {
               return if $Clicked_block;   # allow another event to take control
               my $cn       = shift;
               my $x        = shift;
               my $y        = shift;
               my $assblock = AssignBlock->find( $x, $y, \@allBlocks );
               return unless $assblock;
               my $day = $assblock->day();
               $self->_dragBind( $cn, $day, $x, $y, \@allBlocks );
           },
           Ev('x'),
           Ev('y')
        ]
    );

}

sub _dragBind {
    my $self      = shift;
    my $cn        = shift;
    my $day       = shift;
    my $lx        = shift;
    my $ly        = shift;
    my $allBlocks = shift;
    my @chosen;

    #Get a list of all the AssignBlocks associated with a given day
    my @dayBlocks = Blocks->get_day_blocks( $day, $allBlocks );

    #Binds motion to a motion sub to handel the selection of multiple time slots
    #when moving mouse
    $cn->CanvasBind(
                     '<Motion>',
                     [
                        \&_motionSub, Ev('x'),  Ev('y'), \$lx,
                        \$ly,         \@chosen, \@dayBlocks,
                     ]
    );

    #Binds the release of Mouse 1 to the end binding routine to open the
    #block adding menu and unbind everything else
    $cn->CanvasBind(
        '<ButtonRelease-1>',
        [
           sub {
               my $cn     = shift;
               my $x      = shift;
               my $y1     = shift;
               my $y2     = shift;
               my $chosen = shift;
               $self->_endBinding( $cn, $x, $y1, $y2, $chosen );
           },
           $lx,
           $ly,
           Ev('y'),
           \@chosen
        ]
    );
}

sub _endBinding {
    my $self   = shift;
    my $cn     = shift;
    my $x1     = shift;
    my $y1     = shift;
    my $y2     = shift;
    my $chosen = shift;

    #Unbind everything
    $cn->CanvasBind( '<Motion>',          sub { } );
    $cn->CanvasBind( '<ButtonRelease-1>', sub { } );

    my $something_to_do = $chosen && @$chosen;
    return unless $something_to_do;

    #Get the day and time of the chosen blocks
    my ( $day, $start, $duration ) =
      AssignBlock->Get_day_start_duration($chosen);

    #create the menu to select the block to assign to the timeslot
    AssignToResource->new( $cn, $self->schedule, $self->guiSchedule, $day,
                           $start, $duration, $self->obj, $self->type );

    #redraw
    $self->redraw();
}

sub _motionSub {
    my $cn        = shift;
    my $x2        = shift;
    my $y2        = shift;
    my $x1        = shift;
    my $y1        = shift;
    my $chosen    = shift;
    my $dayBlocks = shift;

    #Temporarily unbind motion
    $cn->CanvasBind( '<Motion>', sub { } );

    #get the AssignBlocks currently under the slection window
    @$chosen = AssignBlock->in_range( $$x1, $$y1, $x2, $y2, $dayBlocks );

    #colour selection blue
    foreach my $blk (@$dayBlocks) {
        $blk->unfill;
    }
    foreach my $blk (@$chosen) {
        $blk->set_colour($selectColour);
    }

    #rebind Motion
    $cn->CanvasBind(
                     '<Motion>',
                     [
                        \&_motionSub, Ev('x'), Ev('y'), $x1,
                        $y1,          $chosen, $dayBlocks
                     ]
    );

}

# =================================================================
# toggle_movement
# =================================================================

=head2 toggle_movement {
 
Toggles whether a Guiblock is moveable or not. 

=cut

sub toggle_movement {
    my $self = shift;

    # get the block that was right_clicked
    return unless $self->popup_guiblock();
    my $block = $self->popup_guiblock()->block;

    # toggle movability
    if ( $block->movable() ) {
        $block->movable(0);
    }
    else {
        $block->movable(1);
    }

    # redraw, and set dirty flag
    $self->guiSchedule->redraw_all_views;
    my $guiSchedule = $self->guiSchedule;
    $self->guiSchedule->set_dirty( $guiSchedule->dirty_flag ) if $guiSchedule;

}

# =================================================================
# move_class
# =================================================================

=head2 move_class ( View, Teacher/Lab Object )

Moves the selected class(es) from the original Views Teacher/Lab to 
the Teacher/Lab Object.

=cut

sub move_class {
    my ( $self, $obj ) = @_;

    # reassign teacher/lab to blocks
    if ( $self->type eq 'teacher' ) {
        $self->popup_guiblock()->block->remove_teacher( $self->obj );
        $self->popup_guiblock()->block->assign_teacher($obj);
        $self->popup_guiblock()->block->section->remove_teacher( $self->obj );
        $self->popup_guiblock()->block->section->assign_teacher($obj);
    }

    elsif ( $self->type eq 'lab' ) {
        $self->popup_guiblock()->block->remove_lab( $self->obj );
        $self->popup_guiblock()->block->assign_lab($obj);
    }

    # there was a change, redraw all views
    my $undo = Undo->new(
                          $self->popup_guiblock()->block->id,
                          $self->popup_guiblock()->block->start,
                          $self->popup_guiblock()->block->day,
                          $self->obj,
                          $self->type,
                          $obj
    );
    $self->guiSchedule->add_undo($undo);

    # new move, so reset redo
    $self->guiSchedule->remove_all_redoes;

    # update status bar
    $self->set_status_undo_info;

    # set dirty flag, and redraw
    $self->guiSchedule->set_dirty;
    $self->guiSchedule->redraw_all_views;
}

# =================================================================
# redraw
# =================================================================

=head2 redraw ( )

Redraws the View with new GuiBlocks and their positions.

=cut

sub redraw {
    my $self         = shift;
    my $obj          = $self->obj;
    my $schedule     = $self->schedule;
    my $cn           = $self->canvas;
    my $currentScale = $self->currentScale;

    $self->SUPER::redraw();

    # ---------------------------------------------------------------
    # If this is a lab or teacher view, then add 'AssignBlocks'
    # to the view, and bind as necessary
    # ---------------------------------------------------------------
    my $type = $self->type;
    $self->setup_assign_blocks if lc($type) eq 'lab' || lc($type) eq 'teacher';

    # ---------------------------------------------------------------
    # set colour for all buttons on main window, "Schedules" tab
    # ---------------------------------------------------------------
    $self->set_view_button_colours();
    $self->guiSchedule->update_for_conflicts if $self->guiSchedule;

    # ---------------------------------------------------------------
    # bind events for each gui block
    # ---------------------------------------------------------------
    my $gbs = $self->guiblocks();
    foreach my $guiblock ( values %$gbs ) {
        my $block = $guiblock->block;

        # bind to allow block to move if clicked and dragged
        # only if block is allowed to move
        if ( $block->movable ) {
            $self->canvas->bind(
                                 $guiblock->group,
                                 "<1>",
                                 [
                                    \&_on_click, $guiblock,
                                    $self,       Tk::Ev("x"),
                                    Tk::Ev("y")
                                 ]
            );
        }

        # double click opens companion views
        $self->canvas->bind( $guiblock->group, "<Double-1>",
                             [ \&_double_open_view, $self, $guiblock ] );
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

    # use base class to get the conflict for this view
    my $view_conflict = $self->SUPER::update_for_conflicts( $self->type );
    return;
}

# =================================================================
# set_view_button_colours
# =================================================================

=head2 set_view_button_colours ( )
    
In the main window, in the schedules tab, there are buttons that
are used to call up the various Schedule Views.  This function
will colour those buttons according to the maximum conflict
for that given view    
    
=cut

sub set_view_button_colours {
    my $self = shift;

    # get all teachers, labs and streams and update
    # the button colours based on the new positions of guiblocks
    my @teachers = $self->schedule->all_teachers;
    my @labs     = $self->schedule->all_labs;
    my @streams  = $self->schedule->all_streams;

    if ( $self->guiSchedule ) {

        $self->guiSchedule->determine_button_colours( \@teachers, 'teacher' )
          if @teachers;

        $self->guiSchedule->determine_button_colours( \@labs, 'lab' )
          if @labs;

        $self->guiSchedule->determine_button_colours( \@streams, 'stream' )
          if @streams;
    }

}

sub set_view_button_colors {
    return set_view_button_colours(@_);
}

# =================================================================
# double_open_view
# =================================================================

=head2 _double_open_view ( Canvas, Self, GuiBlock )

Creates the appropriate View when the User double clicks on a GuiBlock.

=cut

sub _double_open_view {
    my ( $cn, $self, $guiblock ) = @_;
    my $type = $self->type;

    # ---------------------------------------------------------------
    # in lab or stream, open teacher schedules
    # no teacher schedules, then open other lab schedules
    # ---------------------------------------------------------------
    if ( $type eq 'lab' || $type eq 'stream' ) {

        my @teachers = $guiblock->block->teachers;
        if (@teachers) {
            $self->guiSchedule->_create_view( \@teachers, $self->type );
        }
        else {
            my @labs = $guiblock->block->labs;
            $self->guiSchedule->_create_view( \@labs, 'teacher', $self->obj )
              if @labs;
        }
    }

    # ---------------------------------------------------------------
    # in teacher schedule, open lab schedules
    # no lab schedules, then open other teacher schedules
    # ---------------------------------------------------------------
    elsif ( $type eq 'teacher' ) {

        my @labs = $guiblock->block->labs;
        if (@labs) {
            $self->guiSchedule->_create_view( \@labs, $self->type );
        }
        else {
            my @teachers = $guiblock->block->teachers;
            $self->guiSchedule->_create_view( \@teachers, 'lab', $self->obj )
              if @teachers;
        }
    }
}

# =================================================================
# moving a GuiBlock
# =================================================================

=head2 _on_click ( Canvas, GuiBlock, self, xstart, ystart )

Set up for drag and drop of GuiBlock. Binds motion and button release 
events to GuiBlock.

=cut

sub _on_click {

    my ( $cn, $guiblock, $self, $xstart, $ystart ) = @_;
    my ( $startingX, $startingY ) = $cn->coords( $guiblock->rectangle );

    # we are processing a click on a guiblock, so tell the
    # click event for the canvas not to do anything
    $Clicked_block = 1;

    # this block is being controlled by the mouse
    $guiblock->is_controlled(1);

    # unbind any previous binding for clicking and motion,
    # just in case
    $self->canvas->CanvasBind( "<Motion>",          "" );
    $self->canvas->CanvasBind( "<ButtonRelease-1>", "" );

    # bind for mouse motion
    $cn->CanvasBind(
                     "<Motion>",
                     [
                        \&_mouse_move, $guiblock,
                        $self,         $xstart,
                        $ystart,       Tk::Ev("x"),
                        Tk::Ev("y"),   $startingX,
                        $startingY
                     ]
    );

    # bind for release of mouse up
    $cn->CanvasBind( "<ButtonRelease-1>", [ \&_end_move, $guiblock, $self ] );
}

# =================================================================
# move_mouse
# =================================================================

=head2 _mouse_move ( Canvas, GuiBlock, Self, xstart, ystart, xmouse, ymouse, startingX, startingY )

Moves the GuiBlock to the cursors current position on the View.

=cut

sub _mouse_move {
    my (
         $cn,     $guiblock, $self,      $xstart, $ystart,
         $xmouse, $ymouse,   $startingX, $startingY
    ) = @_;

    # temporarily dis-able motion while we process stuff
    # (keeps execution cycles down)
    $cn->CanvasBind( "<Motion>", "" );

    # raise the block
    $guiblock->view->canvas->raise( $guiblock->group );

    # where block needs to go
    my $desiredX = $xmouse - $xstart + $startingX;
    my $desiredY = $ymouse - $ystart + $startingY;

    # current x/y coordinates of rectangle
    my ( $curXpos, $curYpos ) = $cn->coords( $guiblock->rectangle );

    # check for valid move
    if ( defined $curXpos && defined $curYpos ) {

        # where block is moving to
        my $deltaX = $desiredX - $curXpos;
        my $deltaY = $desiredY - $curYpos;

        # move the guiblock
        $cn->move( $guiblock->group, $deltaX, $deltaY );
        $self->refresh_gui;

        # set the blocks new coordinates (time/day)
        $self->_set_block_coords( $guiblock, $curXpos, $curYpos );

        # update same block on different views
        my $block       = $guiblock->block;
        my $guiSchedule = $self->guiSchedule;
        $guiSchedule->update_all_views($block);

        # is current block conflicting
        $self->schedule->calculate_conflicts;
        $self->colour_block($guiblock);

    }

    # ------------------------------------------------------------------------
    # rebind to the mouse movements
    # ------------------------------------------------------------------------

    # what if we had a mouse up while processing this code?
    # do not reset the _mouse_move
    unless ( $guiblock->is_controlled ) {
        _end_move( $cn, $guiblock, $self );
    }

    # else - rebind the motion event handler
    else {
        $cn->CanvasBind(
                         "<Motion>",
                         [
                            \&_mouse_move, $guiblock,
                            $self,         $xstart,
                            $ystart,       Tk::Ev("x"),
                            Tk::Ev("y"),   $startingX,
                            $startingY
                         ]
        );
    }

}

# =================================================================
# _end_move
# =================================================================

=head2 _end_move ( Canvas, GuiBlock )

Moves the GuiBlock to the cursors current position on the View and 
updates the Blocks time in the Schedule.

=cut

sub _end_move {
    my ( $cn, $guiblock, $self ) = @_;

    # it is ok now to process a click on the canvas
    $Clicked_block = 0;

    # unbind the motion on the guiblock
    $cn->CanvasBind( "<Motion>",          "" );
    $cn->CanvasBind( "<ButtonRelease-1>", "" );

    $guiblock->is_controlled(0);

    my $undo = Undo->new( $guiblock->block->id, $guiblock->block->start,
                          $guiblock->block->day, $self->obj, "Day/Time" );

    # set guiblocks new time and day
    $self->snap_guiblock($guiblock);

    # don't create undo if moved to starting position
    if (    $undo->origin_start ne $guiblock->block->start
         || $undo->origin_day ne $guiblock->block->day )
    {

        # add change to undo
        $self->guiSchedule->add_undo($undo);

        # new move, so reset redo
        $self->guiSchedule->remove_all_redoes;

        # update status bar
        $self->set_status_undo_info;
    }

    # current x/y coordinates of rectangle
    my ( $curXpos, $curYpos ) = $cn->coords( $guiblock->rectangle );

    # get the guiblocks new coordinates (closest day/time)
    my $block = $guiblock->block;
    my $coords =
      $self->get_time_coords( $block->day_number, $block->start_number,
                              $block->duration );

    # move the guiblock to new position
    $cn->move(
               $guiblock->group,
               $coords->[0] - $curXpos,
               $coords->[1] - $curYpos
    );
    $self->refresh_gui;

    # update all the views that have the block just moved to its new position
    my $guiSchedule = $self->guiSchedule;
    $guiSchedule->update_all_views($block);

    # calculate new conflicts and update other views to show these conflicts
    $self->schedule->calculate_conflicts;
    $guiSchedule->update_for_conflicts;
    $guiSchedule->set_dirty( $guiSchedule->dirty_flag );

    # set colour for all buttons on main window, "Schedules" tab
    $self->set_view_button_colours();
}

# =================================================================
# undo
# =================================================================

=head2 undo ( Toplevel, View, Type )

Undo last move action

=cut

sub undo {
    my $tl   = shift;
    my $self = shift;
    my $type = shift;

    $self->guiSchedule->undo($type);

    # set colour for all buttons on main window, "Schedules" tab
    $self->set_view_button_colours();

    # update status bar
    $self->set_status_undo_info;
}

# =================================================================
# set_status_undo_info
# =================================================================

=head2 set_status_undo_info (  )

Writes info to status bar about undo/redo status

=cut

sub set_status_undo_info {
    my $self = shift;
    $Undo_number = scalar $self->guiSchedule->undoes . " undoes left";

    $Redo_number = scalar $self->guiSchedule->redoes . " redoes left";

}

=head2 guiSchedule ( [GuiSchedule] )

Get/set the GuiSchedule of this View object.

=cut

sub guiSchedule {
    my $self = shift;
    $self->{-guiSchedule} = shift if @_;
    return $self->{-guiSchedule};
}

=head2 _close_view ( )

Close the current View.

=cut

sub _close_view {
    my $self        = shift;
    my $guiSchedule = $self->guiSchedule;
    $guiSchedule->_close_view($self);
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
