#!/usr/bin/perl
use strict;
use warnings;

package GuiSchedule;
use FindBin;
use lib "$FindBin::Bin/..";
use GuiSchedule::GuiBlocks;
use GuiSchedule::View;
use Schedule::Undo; 

=head1 NAME

GuiSchedule - 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Schedule;
    use GuiSchedule::GuiSchedule
    use Tk;
    
    my $Dirtyflag   = 0;
    my $mw          = MainWindow->new();
    my $Schedule    = Schedule->read('myschedule_file.yaml');
    my $guiSchedule = GuiSchedule->new( $mw, \$Dirtyflag, \$Schedule );
    
    # create clickable buttons for every teacher in $Schedule
    $guiSchedule->create_frame( $mw, 'teacher' );
    
    #display a view (schedule) for a specific teacher
    my @all_teachers = $Schedule->all_teachers();
    my $teacher = $all_teachers[0];
    $guiSchedule->create_new_view($teacher,"teacher");   

=head1 DESCRIPTION

This class creates a button interface to access the all of the views,
and it manages those views.

Manages all the "undo" and "redo" of actions taken upon the views.

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;

# =================================================================
# new
# =================================================================

=head2 new ()

creates a GuiSchedule object

B<Parameters>

-mw => MainWindow to create new Views from

-dirtyFlag => Flag to know when the GuiSchedule has changed since last save

-schedule => where course-sections/teachers/labs/streams are defined 

B<Returns>

GuiSchedule object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $this      = shift;
    my $mw        = shift;
    my $dirtyFlag = shift;
    my $schedule  = shift;

    my $self = {};

    bless $self;
    $self->{-id} = $Max_id++;
    $self->main_window($mw);
    $self->dirty_flag($dirtyFlag);
    $self->schedule_ptr($schedule);

    return $self;
}

# =================================================================
# getters/setters
# =================================================================

=head2 id ()

Returns the unique id for this GuiSchedule object.

=cut

sub id {
    my $self = shift;
    return $self->{-id};
}

=head2 main_window ( [MainWindow] )

Get/sets the MainWindow for this GuiSchedule object.

=cut

sub main_window {
    my $self = shift;
    $self->{-mainWindow} = shift if @_;
    return $self->{-mainWindow};
}

=head2 schedule_ptr ( [Schedule] )

Get/sets the Schedule for this GuiSchedule object.

=cut

sub schedule_ptr {
    my $self = shift;
    $self->{-schedule_ptr} = shift if @_;
    return $self->{-schedule_ptr};
}

=head2 dirty_flag ( [DirtyFlag] )

Get/sets the DirtyFlag for this GuiSchedule object.

=cut

sub dirty_flag {
    my $self = shift;
    $self->{-dirty} = shift if @_;
    return $self->{-dirty};
}

=head2 set_dirty ( )

Sets the dirty flag for changes to Schedule.

=cut

sub set_dirty {
    my $self = shift;
    ${ $self->{-dirty} } = 1;
}

=head2 views ( )

Get the Views of this GuiSchedule object.

=cut

sub views {
    my $self = shift;
    return $self->{-views};
}

=head2 add_view ( View )

Add a View to the list of Views for this GuiSchedule object.

=cut

sub add_view {
    my $self = shift;
    my $view = shift;
    $self->{-views} = {} unless $self->{-views};

    # save
    $self->{-views}->{ $view->id } = $view;
    return $self;
}

=head2 Undoes ( )

Get the Undoes of this GuiSchedule object.

=cut

sub undoes {
    my $self = shift;
    if (wantarray) {
        return @{ $self->{-undoes} };
    }
    else {
        return scalar @{ $self->{-undoes} };
    }
}

=head2 Redoes ( )

Get the Redoes of this GuiSchedule object.

=cut

sub redoes {
    my $self = shift;
    if (wantarray) {
        return @{ $self->{-redoes} };
    }
    else {
        return scalar @{ $self->{-redoes} };
    }
}

=head2 undo ( )

Undo/Redo last action

=cut

sub undo {
    my $self = shift;
    my $type = shift;

    # stores current undo/redo
    my $action;

    # get first undo from stack
    if ( $type eq 'undo' ) {
        my @undoes = $self->undoes;
        my $size   = $self->undoes;
        if ( $size <= 0 ) { return; }
        $action = pop @undoes;
    }
    else {

        # get first redo from stack
        my @redoes = $self->redoes;
        my $size   = $self->redoes;
        if ( $size <= 0 ) { return; }
        $action = pop @redoes;
    }

    my @blocks;
    my $schedule_ptr = $self->schedule_ptr;
    my $schedule     = $$schedule_ptr;

    my $block;
    my $obj = $action->origin_obj;

    #-------- Code for undo/redo moving block in same schedule --------#

    if ( $action->move_type eq "Day/Time" ) {
        if ( $obj->isa("Teacher") ) {
            @blocks = $schedule->blocks_for_teacher($obj);
        }
        elsif ( $obj->isa("Lab") ) {
            @blocks = $schedule->blocks_in_lab($obj);
        }
        else {
            @blocks = $schedule->blocks_for_stream($obj);
        }

        # find block to undo/redo
        foreach my $b (@blocks) {
            if ( $b->id == $action->block_id ) {
                $block = $b;
                last;
            }
        }

        if ( $type eq 'undo' ) {

            # performing undo, store current block time/day for redo
            my $redo = Undo->new( $block->id, $block->start, $block->day,
                                  $action->origin_obj, $action->move_type );
            $self->add_redo($redo);
            $self->remove_last_undo;
            $View::Undo_left = scalar $self->undoes . " undoes left";
            $View::Redo_left = scalar $self->redoes . " redoes left";
        }
        else {

            # performing redo, store current block time/day for undoobj          my $undo = Undo->new( $block->id, $block->start, $block->day,
            my $undo = Undo->new ( $block->id, $block->start, $block->day, 
                                $action->origin_obj, $action->move_type);
            $self->add_undo($undo);
            $self->remove_last_redo;
            $View::Undo_left = scalar $self->undoes . " undoes left";
            $View::Redo_left = scalar $self->redoes . " redoes left";
        }

        # perform local undo/redo
        $block->start( $action->origin_start );
        $block->day( $action->origin_day );

        # update all views to re-place blocks
        $self->redraw_all_views;
        return;
    }

    #-------- Code for undo/redo moving block across schedules --------#

    my $new_obj = $action->new_obj;

    if ( $new_obj->isa("Teacher") ) {
        @blocks = $schedule->blocks_for_teacher($new_obj);
    }
    elsif ( $new_obj->isa("Lab") ) {
        @blocks = $schedule->blocks_in_lab($new_obj);
    }
    else {
        @blocks = $schedule->blocks_for_stream($new_obj);
    }

    foreach my $b (@blocks) {
        if ( $b->id == $action->block_id ) {
            $block = $b;
            last;
        }
    }

    if ( $type eq 'undo' ) {

        # performing undo, setup redo
        my $redo = Undo->new(
                              $action->block_id,  $block->start,
                              $block->day,        $action->new_obj,
                              $action->move_type, $action->origin_obj
                            );
        $self->add_redo($redo);
        $self->remove_last_undo;
        $View::Undo_left = scalar $self->undoes . " undoes left";
        $View::Redo_left = scalar $self->redoes . " redoes left";
    }
    else {

        # performing redo, setup undo
        my $undo = Undo->new(
                              $action->block_id,  $block->start,
                              $block->day,        $action->new_obj,
                              $action->move_type, $action->origin_obj
                            );
        $self->add_undo($undo);
        $self->remove_last_redo;
        $View::Undo_left = scalar $self->undoes . " undoes left";
        $View::Redo_left = scalar $self->redoes . " redoes left";
    }

    # reassign teacher/lab to block
    if ( $action->move_type eq 'teacher' ) {
        $block->remove_teacher($new_obj);
        $block->assign_teacher($obj);
        $block->section->remove_teacher($new_obj);
        $block->section->assign_teacher($obj);
    }
    elsif ( $action->move_type eq 'lab' ) {
        $block->remove_lab($new_obj);
        $block->assign_lab($obj);
    }

    # update all views to re-place blocks
    $self->redraw_all_views;
}

=head2 add_undo ( Undo )

Add a Undo to the list of Undoes for this GuiSchedule object.

=cut

sub add_undo {
    my $self = shift;
    my $undo = shift;

    $self->{-undoes} = [] unless $self->{-undoes};
    push @{ $self->{-undoes} }, $undo;
    return $self;
}

=head2 add_redo ( Undo )

Add a Redo to the list of Redoes for this GuiSchedule object.

=cut

sub add_redo {
    my $self = shift;
    my $redo = shift;

    $self->{-redoes} = [] unless $self->{-redoes};
    push @{ $self->{-redoes} }, $redo;
    return $self;
}

=head2 add_button_refs ( \button, Teacher/Lab/Stream Object )

Adds a button reference to the hash of all button references and the 
Object it is associated to.

=cut

sub add_button_refs {
    my $self = shift;
    my $btn  = shift;
    my $obj  = shift;
    $self->{-buttonRefs} = {} unless $self->{-buttonRefs};

    # save
    $self->{-buttonRefs}->{$obj} = $btn;
    return $self;
}

=head2 _button_refs 

Returns a hash of all button hashes for this GuiSchedule object

=cut

sub _button_refs {
    my $self = shift;
    return $self->{-buttonRefs};
}

=head2 add_guischedule_to_views ( )

Adds the current GuiSchedule object to all open Views.

=cut

sub add_guischedule_to_views {
    my $self      = shift;
    my $openViews = $self->views;
    foreach my $view ( values %$openViews ) {
        $view->guiSchedule($self);
    }
}

# =================================================================
# resetters/removers
# =================================================================

=head2 remove_view ( $view )

Remove a View from the list of Views for this GuiSchedule object

=cut

sub remove_view {
    my $self = shift;
    my $view = shift;
    delete $self->{-views}->{ $view->id };
    return $self;
}

=head2 remove_all_views ( )

Removes all Views associated with this GuiSchedule object.

=cut

sub remove_all_views {
    my $self = shift;
    $self->{-views} = {};
    return $self;
}

=head2 remove_undo ( Undo )

Remove a Undo from the list of Undoes for this GuiSchedule object

=cut

sub remove_undo {
    my $self = shift;
    my $undo = shift;

    for ( my $i = 0 ; $i < scalar @{ $self->{-undoes} } ; $i++ ) {
        if ( @{ $self->{-undoes} }[$i]->id == $undo->id ) {
            delete @{ $self->{-undoes} }[$i];
            last;
        }
    }

    return $self;
}

=head2 remove_last_undo ( )

Remove last undo

=cut

sub remove_last_undo {
    my $self = shift;
    pop @{ $self->{-undoes} };
    return $self;
}

=head2 remove_last_redo ( )

Remove last redo

=cut

sub remove_last_redo {
    my $self = shift;
    pop @{ $self->{-redoes} };
    return $self;
}

=head2 remove_redo ( Undo )

Remove a Redo from the list of Redoes for this GuiSchedule object

=cut

sub remove_redo {
    my $self = shift;
    my $redo = shift;

    for ( my $i = 0 ; $i < scalar @{ $self->{-redoes} } ; $i++ ) {
        if ( @{ $self->{-redoes} }[$i]->id == $redo->id ) {
            delete @{ $self->{-redoes} }[$i];
            last;
        }
    }
    return $self;
}

=head2 remove_all_undoes ( )

Removes all Undoes associated with this GuiSchedule object.

=cut

sub remove_all_undoes {
    my $self = shift;
    $self->{-undoes} = [];
    return $self;
}

=head2 remove_all_redoes ( )

Removes all Redoes associated with this GuiSchedule object.

=cut

sub remove_all_redoes {
    my $self = shift;
    $self->{-redoes} = [];
    return $self;
}

=head2 destroy_all ( )

Closes all open Views.

=cut

sub destroy_all {
    my $self = shift;

    my $openViews = $self->views;

    foreach my $view ( values %$openViews ) {
        $self->_close_view($view);
    }
    $self->remove_all_undoes;
    $self->remove_all_redoes;
    $View::Undo_left = scalar $self->undoes . " undoes left";
    $View::Redo_left = scalar $self->redoes . " redoes left";
}

=head2 reset_button_refs 

Resets the hash of button references for this GuiSchedule object.

=cut

sub reset_button_refs {
    my $self = shift;
    $self->{-buttonRefs} = {};
}

=head2 _close_view ( View )

Closes the selected View.

=cut

sub _close_view {
    my $self = shift;
    my $view = shift;

    my $toplevel = $view->toplevel;

    $self->remove_view($view);
    $self->add_guischedule_to_views;
    $toplevel->destroy;
}

# =================================================================
# updaters
# =================================================================

=head2 update_all_views ( Block )

Updates the position of the current moving GuiBlock across all open Views.

=cut

sub update_all_views {
    my $self      = shift;
    my $block     = shift;
    my $openViews = $self->views;

    # go through all currently open views
    foreach my $view ( values %$openViews ) {

        # update the guiblocks on the view
        $view->update($block);
    }
}

=head2 redraw_all_views ( )

Redraw all open Views with new GuiBlocks (if any).

=cut

sub redraw_all_views {
    my $self      = shift;
    my $openViews = $self->views;

    foreach my $view ( values %$openViews ) {
        $view->redraw;
    }
}

=head2 update_for_conflicts ( )

Goes through all open Views and updates their GuiBlocks for any new Conflicts.

=cut

sub update_for_conflicts {
    my $self      = shift;
    my $openViews = $self->views;

    foreach my $view ( values %$openViews ) {
        $view->update_for_conflicts($view->type);
    }
}

=head2 determine_button_colours ( Array of Teachers/Labs/Streams, Type of Object ) 

Finds the highest conflict for each teacher/lab/stream in the array and sets 
the colour of the button accordingly.

=cut

sub determine_button_colours {

    my $self  = shift;
    my $array = shift;
    my $type  = shift;
    

    # get schedule object from reference
    my $schedule_ptr = $self->schedule_ptr;
    my $schedule     = $$schedule_ptr;

    # calculate conflicts
    $schedule->calculate_conflicts;

    my @blocks;

    # for every teacher/lab/stream
    foreach my $obj (@$array) {

        # get the blocks for the current teacher/lab/stream
        if ( $type eq "teacher" ) {
            @blocks = $schedule->blocks_for_teacher($obj);
        }
        elsif ( $type eq "lab" ) {
            @blocks = $schedule->blocks_in_lab($obj);
        }
        else {
            @blocks = $schedule->blocks_for_stream($obj);
        }

        # what is this view's conflict? start with 0
        my $view_conflict = 0;

        # for every block
        foreach my $block (@blocks) {
            $view_conflict =
              Conflict->most_severe( $view_conflict | $block->is_conflicted, $type );
            last if $view_conflict == $Conflict::Sorted_Conflicts[0];
        }

        # get the button associated to the current teacher/lab/stream
        my $button_ptrs = $self->_button_refs;
        my $btn         = $button_ptrs->{$obj};

        # set button colour to conflict colour if there is a conflict
        my $colour = $Scheduler::Colours->{ButtonBackground};
        if ($view_conflict) {
            $colour = Conflict->Colours->{$view_conflict} || 'red';
        }
        my $active = Colour->darken(10,$colour);
            $$btn->configure(
                       -background =>$colour,
                       -activebackground => $active) if $btn;
    }
}

# =================================================================
# creators
# =================================================================

=head2 create_frame ( Frame, Type )

Populates frame with buttons for all Teachers, Labs or Streams depending on Type in alphabetical order.

=cut

sub create_frame {
    
    my $self        = shift;
    my $frame       = shift;
    my $type        = shift;
    my $command_sub = shift || \&create_new_view;
    my @array;
    my @ordered;

    my $row = 0;
    my $col = 0;

    # get schedule object from reference
    my $schedule_ptr = $self->schedule_ptr;
    my $schedule     = $$schedule_ptr;

    # get all teachers/labs/streams and sort in alphabetical,
    # order depending on type
    if ( $type eq "teacher" ) {
        @array = $schedule->all_teachers;
        @ordered = sort { $a->lastname cmp $b->lastname } @array;
    }
    elsif ( $type eq "lab" ) {
        @array = $schedule->all_labs;
        @ordered = sort { $a->number cmp $b->number } @array;
    }
    else {
        @array = $schedule->all_streams;
        @ordered = sort { $a->number cmp $b->number } @array;
    }

    # determine how many buttons should be on one row
    my $arr_size = scalar @ordered;
    my $divisor  = 2;
    if ( $arr_size > 10 ) { $divisor = 4; }

    # for every teacher/lab/stream in alphabetical order
    foreach my $obj (@ordered) {
        my $name;

        # determine name/number to show on button
        if ( $type eq "teacher" ) {
            $name =
              uc( substr( $obj->firstname, 0, 1 ) ) . " " . $obj->lastname;
        }
        else { $name = $obj->number; }

        # create the command array reference including the GuiSchedule,
        # the Teacher/Lab/Stream, it's type
        my $command = [ $command_sub, $self, $obj, $type ];

        # create the button on the frame
        my $btn = $frame->Button( -text => $name, -command => $command )->grid(
                                                              -row    => $row,
                                                              -column => $col,
                                                              -sticky => "nsew",
                                                              -ipadx  => 30,
                                                              -ipady  => 10
        );

        # pass the button reference the the event handler.
        push( @{$command}, \$btn );

        # add it to hash of button references
        $self->add_button_refs( \$btn, $obj );

        my $openView = $self->is_open( $obj->id, $type );
        $col++;

        # reset to next row
        if ( $col >= ( $arr_size / $divisor ) ) { $row++; $col = 0; }
    }

    # determine the colour of the buttons for
    # every teacher/lab/stream in the frame
    
    $self->determine_button_colours( \@ordered, $type );
}

=head2 _create_view ( Array Pointer, Type )

Preparation function for creating a new View when double clicking on a GuiBlock.

=cut

sub _create_view {
    my $self    = shift;
    my $arr_ptr = shift;
    my $type    = shift;
    my $ob      = shift;
    my $obj_id  = $ob->id if $ob;
    my $btn;
    my @array = @$arr_ptr;

    if   ( $type eq 'teacher' ) { $type = 'lab'; }
    else                        { $type = 'teacher'; }

    foreach my $obj (@array) {
        unless ( defined($obj_id) && $obj_id == $obj->id ) {
            my $button_ptrs = $self->_button_refs;
            $btn = $button_ptrs->{$obj};
            $self->create_new_view( $obj, $type, $btn );
        }
    }
}

=head2 create_new_view ( Teacher/Lab/Stream Object, Type, Button Pointer )

Creates a new View for the selected Teacher, Lab or Stream, depending on the object. 
If View is already open, the View for that object is brought to front.

Button Pointer is only used in debug mode

=cut

sub create_new_view {
    my $self    = shift;
    my $obj     = shift;
    my $type    = shift;
    my $btn_ptr = shift;
    
    my $mw           = $self->main_window;
    my $open         = $self->is_open( $obj->id, $type );
    my $schedule_ptr = $self->schedule_ptr;
    my $schedule     = $$schedule_ptr;

    if ( $open == 0 ) {
        if ( $ENV{DEBUG} ) {
            print "Calling new view with <$mw>, <$schedule>, "
              . "<$obj>, <$btn_ptr>\n";
        }
        my $view = View->new( $mw, $schedule, $obj );

        $self->add_view($view);
        $self->add_guischedule_to_views;
    }
    else {
        $open->toplevel->raise;
        $open->toplevel->focus;
    }
}

=head2 is_open ( Teacher/Lab/Stream ID, object type )

Checks if the View corresponding to the button pressed by user is open.
Returns the View object if View is open, else 0.

=cut

sub is_open {
    my $self = shift;
    my $id   = shift;
    my $type = shift;
    
    my $openViews = $self->views;
    foreach my $view ( values %$openViews ) {
        if ( $view->type eq $type ) {
            if ( $view->obj->id == $id ) { return $view; }
        }
    }

    return 0;
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
