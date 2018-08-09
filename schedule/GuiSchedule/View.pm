#!/usr/bin/perl
use strict;
use warnings;

package View;
use FindBin;
use lib "$FindBin::Bin/..";
use List::Util qw( min max );
use GuiSchedule::GuiBlocks;
use GuiSchedule::Undo;
use GuiSchedule::ViewBase;
use Schedule::Conflict;
use Tk;
our @ISA = qw(ViewBase);

=head1 NAME

View - describes the visual representation of a Window

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    Example of how to use code here

=head1 DESCRIPTION

Describes a View

=head1 METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ()

creates a View object, draws the necessary GuiBlocks and returns the View object.

B<Parameters>

-cn => Canvas for the View to draw on

-blocks => Blocks that need to be drawn on the View

-schedule => where course-sections/teachers/labs/streams are defined

-obj => Teacher/Lab/Stream that the View is being made for

-type => Whether the view is a Teacher, Lab or Stream View

-btn_ptr => Reference to the button that creates this view

B<Returns>

View object

=cut

sub new {
    my $class    = shift;
    my $mw       = shift;
    my $blocks   = shift;
    my $schedule = shift;
    my $obj      = shift;
    my $type     = shift;
    my $btn_ptr  = shift;

    # ---------------------------------------------------------------
    # create the ViewBase
    # ---------------------------------------------------------------
    my $self = $class->SUPER::new($mw);

    # ---------------------------------------------------------------
    # set some parameters
    # ---------------------------------------------------------------
    $self->blocks($blocks);
    $self->schedule($schedule);
    $self->type($type);
    $self->obj($obj);
    $self->button_ptr($btn_ptr);

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
    # create the pop-up menu BEFORE drawing the blocks, so that it can be
    # bound to each block (done in $self->draw_blocks)
    # ---------------------------------------------------------------
    my $pm = $mw->Menu( -tearoff => 0 );
    $pm->command( -label   => "Toggle Moveable/Fixed",
                  -command => [ \&toggle_movement, $self ], );

    if ( $type ne 'stream' ) {
        my $mm = $pm->cascade( -label => 'Move Class to', -tearoff => 0 );
        my @array;

        # sorted array of teacher or lab
        if ( $self->type eq 'teacher' ) {
            @array = sort { $a->lastname cmp $b->lastname }
              $self->schedule->all_teachers;
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
    }

    $self->popup_menu($pm);

    # ---------------------------------------------------------------
    # refresh drawing
    # ---------------------------------------------------------------
    $self->redraw();
    $self->schedule->calculate_conflicts;
    $self->update_for_conflicts;

    # return object
    return $self;
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
    $guiSchedule->set_dirty( $guiSchedule->dirty_flag ) if $guiSchedule;

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
    my $coords = $self->_get_pixel_coords( $guiblock->block );

    # move the guiblock to new position
    $cn->move(
               $guiblock->group,
               $coords->[0] - $curXpos,
               $coords->[1] - $curYpos
             );
    $self->refresh_gui;

    # update all the views that have the block just moved to its new position
    my $guiSchedule = $self->guiSchedule;
    my $block       = $guiblock->block;
    $guiSchedule->update_all_views($block);

    # calculate new conflicts and update views to show these conflicts
    $self->schedule->calculate_conflicts;
    $guiSchedule->update_for_conflicts;
    $guiSchedule->set_dirty( $guiSchedule->dirty_flag );

    # set colour for all buttons on main window, "Schedules" tab
    $self->set_view_button_colours();
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
