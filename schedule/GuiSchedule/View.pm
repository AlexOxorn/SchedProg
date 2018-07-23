#!/usr/bin/perl
use strict;
use warnings;

package View;
use FindBin;
use lib "$FindBin::Bin/..";
use List::Util qw( min max );
use GuiSchedule::GuiBlocks;
use GuiSchedule::Undo;
use Schedule::Conflict;
use Tk;
use Tk::DragDrop;
use Tk::DropSite;

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
# Class Variables
# =================================================================
our $Max_id = 0;
our @days   = ( "Monday", "Tuesday", "Wednesday", "Thursday", "Friday" );
our %times  = (
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
our $mw;
our $Drag_Source;
our $Drop_Site;
our $Drag_Type;
our $Origin_View;
our $Moving_Guiblock;
our $Good_Drop;
our $Move_Across_Views = 0;
my $Movement_status = "Movement Type: Drag in current schedule (Shift click to change)";
our $Undo_left = "0 undoes left";
our $Redo_left = "0 redoes left";
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

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
	my $this = shift;
	$mw = shift;
	my $blocks = shift;
	my $schedule = shift;
	my $obj = shift;
	my $type = shift;
	my $btn_ptr = shift;
	my $title;
	if($type eq 'teacher') {
		$title = uc(substr($obj->firstname,0,1))." ".$obj->lastname;
	} else {
		$title = $obj->number;
	}
	
	my $tl     = $mw->Toplevel;
	$tl->title($title);
	my $cn     = $tl->Canvas(
		-height     => 700,
		-width      => 700,
		-background => "white"
	)->pack();

	# create object
	my $self = {};
	bless $self;
	$self->canvas($cn);
	$self->{-id} = $Max_id++;
	$self->blocks($blocks);
	$self->toplevel($tl);
	$self->schedule($schedule);
	$self->type($type);
	$self->obj($obj);
	$self->button_ptr($btn_ptr);
	$self->xOffset(1);
	$self->yOffset(1);
	$self->xScale(0);
	$self->yScale(0);
	$self->wScale(100);
	$self->hScale(60);
	$self->currentScale(1);
	
	# draw the scheduling timetable as the background
	$self->draw_background;
	$self->status_bar($self->create_status_bar($Movement_status));
	
	$tl->resizable(0, 0);
	
	# create scale menu
	my $mainMenu = $mw->Menu();
	$tl->configure(-menu => $mainMenu);
	my $viewMenu = $mainMenu->cascade(-label=>"View", -underline=>0, -tearoff=>0);
	#$viewMenu->command(-label=>"25%", -underline=>0, -command  => [\&resize_view, $self, 0.25] );
	$viewMenu->command(-label=>"50%", -underline=>0, -command  => [\&resize_view, $self, 0.50] );
	$viewMenu->command(-label=>"75%", -underline=>0, -command  => [\&resize_view, $self, 0.75] );
	$viewMenu->command(-label=>"100%", -underline=>0, -command => [\&resize_view, $self, 1.00] );

	
	#														[\&undo, $self, 'undo']

    # create the pop-up menu
    my $pm = $mw->Menu(-tearoff=>0);
    $pm->command(
        -label => "Toggle Moveable/Fixed",
        -command => [\&toggle_movement,$self],
    );
    
    if($type ne 'stream') {
	    my $mm = $pm->cascade(-label=>'Move Class to', -tearoff=>0); 
	    my @array;
	    # sorted array of teacher or lab
	    if($self->type eq 'teacher') {
	   		@array = sort { $a->lastname cmp $b->lastname } $self->schedule->all_teachers;
	    } elsif ($self->type eq 'lab') {
	    	@array = sort { $a->number cmp $b->number } $self->schedule->all_labs;
	    } elsif ($self->type eq 'stream') {
	    	@array = sort { $a->number cmp $b->number } $self->schedule->all_streams;
	    }
	    # remove object of the view
	    @array = grep {$_->id != $self->obj->id} @array;
	    
	    # create sub menu
	    foreach my $obj(@array) {
	    	my $name;
	    	if($self->type eq 'teacher') {
	    		$name = $obj->firstname.' '.$obj->lastname;	
	    	} else {
	    		$name = $obj->number;	
	    	}
	    	$mm->command(
	    		-label => $name,
	    		-command => [\&move_class, $self, $obj ]
	    	);	
	    }	
    }
   # $pm->command(
   #     -label => "Change colour",
   #     -command => [\&change_colour,$self,$tl],
   # );
   # $pm->command(
   #     -label => "menu test 3",
   #     -command => sub{print "click on menu 3\n"}
   # );
    
    $self->popup_menu($pm);

	# all Views are DropSites
	if($self->type ne 'stream') {		
		my $drop_Site = $self->canvas->DropSite(
				-droptypes     => [qw/Local/],
				-dropcommand   => [\&_drop_guiblock, $self->canvas, $self->type, $self->toplevel->title, $self ],
				-motioncommand => [\&_move_guiblock, $self->type, $self->toplevel->title ]
				);				

		$self->dropSite($drop_Site);
	}
    
	# for all the blocks, turn them into GuiBlocks, draw on View and store in list
	foreach my $b (@$blocks) {
		$b->start( $b->start );
		$b->day( $b->day );
		my $guiblock = $self->draw_block($b);
		$self->add_guiblock($guiblock);
	}

	$self->schedule->calculate_conflicts;
	$self->update_for_conflicts;

	$tl->protocol('WM_DELETE_WINDOW',[ \&_close_view, $self ]);
    
    # unpost menu bound to top-level widget
    $tl->bind('<1>',[ \&unpostmenu, $pm ]);
    $tl->bind('<2>',[ \&unpostmenu, $pm ]);

	$cn->CanvasBind('<Shift-ButtonPress-1>' => [\&toggle_movement_type, $self] );
	$tl->bind('<Control-KeyPress-z>' => [\&undo, $self, 'undo'] );
	$tl->bind('<Command-KeyPress-z>' => [\&undo, $self, 'undo'] );
	
	$tl->bind('<Control-KeyPress-y>' => [\&undo, $self, 'redo'] );
	$tl->bind('<Command-Shift-KeyPress-z>' => [\&undo, $self, 'redo'] );
	
	$mainMenu->add('command', -label=>"Undo", -command => [\&undo,$tl, $self, 'undo']);
	$mainMenu->add('command', -label=>"Redo", -command => [\&undo,$tl, $self, 'redo']);
		
	# return object
	return $self;
}

=head2 resize_view ( View, Scale )

Resizes the View to the new Scale

=cut

sub resize_view{
	my $self = shift;
	my $scale = shift;

	# get height and width of toplevel	
	my $tlHeight = $self->toplevel->height;
	my $tlWidth = $self->toplevel->width;
	
	# get height and width of canvas
	my @heights = $self->canvas->configure(-height);
	my $canHeight = $heights[-1];
	my @widths = $self->canvas->configure(-width);
	my $canWidth = $widths[-1];
	
	# get current scaling sizes
	my $xScale = $self->xScale;
	my $yScale = $self->yScale;
	my $hScale = $self->hScale;
	my $wScale = $self->wScale;
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
	
	# set height and width of canvas
	$self->toplevel->configure(-width=>$tlWidth, -height=>$tlHeight);
	$self->canvas->configure(-width=>$canWidth, -height=>$canHeight);
	
	# redraw current view with new scale
	$self->redraw;
}

=head2 undo ( Toplevel, View, Type )

Undo last move action

=cut

sub undo {
	my $tl = shift;
	my $self = shift;
	my $type = shift;
	
	print $tl;
	print "\n";
	print $self;
	print "\n";
	print $type;
	print "\n\n";

	$self->guiSchedule->undo($type);
	# get all teachers, labs and streams and update the button colours based on the new positions of guiblocks
    my @teachers = $self->schedule->all_teachers;
    my @labs = $self->schedule->all_labs;
    my @streams = $self->schedule->all_streams;
    $self->guiSchedule->determine_button_colours(\@teachers, 'teacher') if @teachers;
    $self->guiSchedule->determine_button_colours(\@labs, 'lab') if @labs;
    $self->guiSchedule->determine_button_colours(\@streams, 'stream') if @streams;
}

=head2 create_status_bar {
 
Status bar at the bottom of each View to show current movement type. 

=cut

sub create_status_bar {
	my $self = shift;
	my $text = shift;
	
	$self->status_bar->destroy if $self->status_bar;

	my $status_frame = $self->toplevel->Frame(
		-borderwidth => 0,
		-relief      => 'flat',
	)->pack( -side => 'bottom', -expand => 0, -fill => 'x' );
	
	$status_frame->Label(
		-textvariable => \$text,
		-borderwidth  => 1,
		-relief       => 'ridge',
	)->pack( -side => 'left', -expand => 1, -fill => 'x' );
	
	$status_frame->Label(
		-textvariable => \$Redo_left,
		-borderwidth  => 1,
		-relief       => 'ridge',
		-width => 15
	)->pack( -side => 'right', -fill => 'x' );
	
	$status_frame->Label(
		-textvariable => \$Undo_left,
		-borderwidth  => 1,
		-relief       => 'ridge',
		-width => 15
	)->pack( -side => 'right', -fill => 'x' );
	
	return $status_frame;
}



# -------------------------------------------------------------------
# Drag n Drop Guiblocks between Views
#--------------------------------------------------------------------

=head2 toggle_movement_type {
 
Toggles whether left click moves Guiblock on its View or moves Guiblocks between Views. 

=cut

sub toggle_movement_type {
	my $canvas = shift;
	my $self = shift;

	$self->canvas->CanvasBind( "<1>", "" );
	$self->canvas->CanvasBind( "<B1-Motion>", "" );
	$self->canvas->CanvasBind( "<ButtonRelease-1>", "" );
	$Move_Across_Views = !$Move_Across_Views;
	if($Move_Across_Views) {
		$Movement_status = "Movement Type: Drag across open schedules (Shift click to change)";
	} else {
		$Movement_status = "Movement Type: Drag in current schedule (Shift click to change)";
	}
	$self->guiSchedule->redraw_all_views;
}

=head2 _start_guiblock_move {
 
Setup for moving Guiblock(s) from one View to another. 

=cut

sub _start_guiblock_move {
	my ($cn, $self, $guiblock) = @_;
	
	# not coded for Streams
	if($self->type eq 'stream') { return; }

	# Drag already in progress, can't start another
	if($Drag_Source) { return; }
	
	# Initialize global variables for drag n drop to work	
	$Drag_Type = $self->type;
	$Drag_Source = $self->dragSource;
	$Origin_View = $self;
	$Moving_Guiblock = $guiblock;
	$Good_Drop = 0;

	$Drag_Source->configure(
					-text => $guiblock->block->section->course->number,
					-font => [qw/-family arial -size 18/],
					-bg   => '#abcdef'
					);

	my $guiblocks = $self->guiblocks;

	# Colour guiblocks affected by move
	if($Drag_Type eq 'teacher') {
		foreach my $guiBlock ( values %$guiblocks ) {
			if($guiBlock->block->section->id == $Moving_Guiblock->block->section->id) {
				$guiBlock->change_colour('brown');
			}
		}
	} elsif ($Drag_Type eq 'lab') {
		$guiblock->change_colour('brown');
	}

	undef;
}

=head2 _move_guiblock {
 
Determines whether where Guiblock will be placed is valid.

=cut

sub _move_guiblock {
	return unless $Moving_Guiblock;
	return unless $Drag_Source;
	my $type = shift;
	my $title = shift;
	my $x = shift;
	my $y = shift;

	# not coded for streams, so return
	if($type eq 'stream' || $Drag_Type eq 'stream') {
		return;
	}

	# display to user which view guiblocks will move to
	$Drag_Source->configure(-text=>"copy to: $type: $title");
	
	# Trying to drag from teacher to lab?
	if ($Drag_Type ne $type) {
		$Good_Drop = 0;
		return;	
	}
	
	# teacher to teacher / lab to lab, good drop
	$Good_Drop = 1;
}

=head2 _drop_guiblock {
 
Places Guiblock on new View.

=cut

sub _drop_guiblock {
	my ($cn, $type, $title, $view) = @_;
	return unless $Drag_Type;
	return unless $Origin_View;
	return unless $Moving_Guiblock;
	return if $Drag_Type eq 'stream';
	return if $type eq 'stream';
	my $answer = "No";
	
	# if trying to move from teacher to lab
	if (!$Good_Drop) {
		# tell user
		$cn->messageBox(-title   => 'Error Copying Classes',
				        -message => 'Error! Can only move class from teacher to teacher or resource to resource.',
				        -type    => 'OK',
				        -icon    => 'error');
		# redraw view to reset colours of guiblocks
		$Origin_View->redraw;
		return;
	}
	
	my $dialog_text = 'Do you wish to move class '.$Moving_Guiblock->block->section->course->number.'('.
					  $Moving_Guiblock->block->section->number . ') from '.
					  $Origin_View->obj .' to '.$view->obj.'?';
	
	# check that guiblock was not dragged on itself
	if($Origin_View->obj->id != $view->obj->id) {				  
		$answer = $cn->messageBox(-title         => 'Confirm Moving',
								 -message        => $dialog_text,
								 -default        => 'Yes',
								 -type           => 'YesNo',
								 -icon           => 'question');
								 
		# confirm change, reassign teacher/lab to blocks
		if($Drag_Type eq 'teacher' && $answer eq 'Yes') {
			$Moving_Guiblock->block->remove_teacher($Origin_View->obj);
			$Moving_Guiblock->block->assign_teacher($view->obj);
			$Moving_Guiblock->block->section->remove_teacher($Origin_View->obj);
			$Moving_Guiblock->block->section->assign_teacher($view->obj); 
		} elsif ($Drag_Type eq 'lab' && $answer eq 'Yes') {
			$Moving_Guiblock->block->remove_lab($Origin_View->obj);
			$Moving_Guiblock->block->assign_lab($view->obj);
		}

		# if there was a change, redraw all views
		if ($answer eq 'Yes') {
			my $undo = Undo->new( $Moving_Guiblock->block->id, $Moving_Guiblock->block->start, $Moving_Guiblock->block->day, $Origin_View->obj, $Drag_Type, $view->obj);
			$view->guiSchedule->add_undo($undo);
			$Undo_left = scalar $view->guiSchedule->undoes ." undoes left";
			# new move, so reset redo
			$view->guiSchedule->remove_all_redoes;
			$Redo_left = scalar $view->guiSchedule->redoes ." redoes left";
			$view->guiSchedule->set_dirty;	
			$view->guiSchedule->redraw_all_views;
		}
	}
	
	# user didn't move guiblock or dragged guiblock onto origin view, redraw origin view to reset colours
	if($answer eq 'No') {
		$Origin_View->redraw;
	}
	# reset for new drag n drop
	undef $Drag_Type;
	undef $Drag_Source;
	undef $Origin_View;
	undef $Moving_Guiblock;
}


{
 
my $popup_guiblock;

=head2 change_colour {
 
Changes the colour of the guiblock 

=cut

sub change_colour {
 
    # this doesn't work.  
    # need to change colour on block, not gui_block
    return;
    my $self = shift;
    my $tl = shift;
    my $initial_colour = $popup_guiblock->colour;
    my $colour = $tl->chooseColor( -title => 'Color Picker', 
    -initialcolor => $initial_colour );
    if ($colour) {
         $popup_guiblock->change_colour($colour);
         $self->redraw();
    }
}
 
=head2 toggle_movement {
 
Toggles whether a Guiblock is moveable or not. 

=cut

sub toggle_movement {
    my $self = shift;
    return unless $popup_guiblock;
    my $block = $popup_guiblock->block;
    if ($block->movable()) {
        $block->movable(0)
    }
    else {
        $block->movable(1);
    }
    $self->guiSchedule->redraw_all_views;
}

=head2 postmenu ( Canvas, Menu, X, Y )

Creates a Context Menu on the Canvas at X and Y.

=cut

sub postmenu {
	(my $c, my $m, my $x, my $y, $popup_guiblock) = @_;
	$m->post($x,$y);
}

=head2 unpostmenu ( Canvas, Menu )

Removes the Context Menu.

=cut

sub unpostmenu {
	my ($c,$m) = @_;
	$m->unpost;
	undef $popup_guiblock;
}

=head2 move_class ( View, Teacher/Lab Object )

Moves the selected class(es) from the original Views Teacher/Lab to the Teacher/Lab Object.

=cut

sub move_class {
	my ($self, $obj) = @_;
	my $answer;
									 
	# confirm change, reassign teacher/lab to blocks
	if($self->type eq 'teacher') {
		$popup_guiblock->block->remove_teacher($self->obj);
		$popup_guiblock->block->assign_teacher($obj);
		$popup_guiblock->block->section->remove_teacher($self->obj);
		$popup_guiblock->block->section->assign_teacher($obj); 
	} elsif ($self->type eq 'lab') {
		$popup_guiblock->block->remove_lab($self->obj);
		$popup_guiblock->block->assign_lab($obj);
	}
	# if there was a change, redraw all views
	my $undo = Undo->new( $popup_guiblock->block->id, $popup_guiblock->block->start, $popup_guiblock->block->day, $self->obj, $self->type, $obj);
	$self->guiSchedule->add_undo($undo);
	$Undo_left = scalar $self->guiSchedule->undoes ." undoes left";
	# new move, so reset redo
	$self->guiSchedule->remove_all_redoes;
	$Redo_left = scalar $self->guiSchedule->redoes ." redoes left";
	$self->guiSchedule->set_dirty;	
	$self->guiSchedule->redraw_all_views;
}
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

=head2 dragSource ( [DragSource Object] )

Get/set the DragSource associated to this View.

=cut

sub dragSource {
	my $self = shift;
	$self->{-dragSource} = shift if @_;
	return $self->{-dragSource};
}

=head2 obj ( [DropSite Object] )

Get/set the DropSite associated to this View.

=cut

sub dropSite {
	my $self = shift;
	$self->{-dropSite} = shift if @_;
	return $self->{-dropSite};
}

=head2 obj ( [Teacher/Lab/Stream Object] )

Get/set the Teacher, Lab or Stream associated to this View.

=cut

sub obj {
	my $self = shift;
	$self->{-obj} = shift if @_;
	return $self->{-obj};
}

=head2 canvas ( [Canvas] )

Get/set the canvas of this View object.

=cut

sub canvas {
    my $self = shift;
    $self->{-canvas} = shift if @_;
    return $self->{-canvas};
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
	$self->{-blocks} = shift if @_;
	return $self->{-blocks};
}

=head2 popup_menu ( [menu] )

Get/set the popup menu for this guiblock

=cut

sub popup_menu {
    my $self = shift;
    $self->{-popup} = shift if @_;
    return $self->{-popup};
}

=head2 guiSchedule ( [GuiSchedule] )

Get/set the GuiSchedule of this View object.

=cut

sub guiSchedule {
	my $self = shift;
	$self->{-guiSchedule} = shift if @_;
	return $self->{-guiSchedule};
}

=head2 schedule ( [Schedule] )

Get/set the Schedule of this View object.

=cut

sub schedule {
	my $self = shift;
	$self->{-schedule} = shift if @_;
	return $self->{-schedule};
}

=head2 button_ptr ( [Button Reference] )

Get/set the Button reference of this View object.

=cut

sub button_ptr {
	my $self = shift;
	$self->{-button_ptr} = shift if @_;
	return $self->{-button_ptr};		
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

=head2 status_bar ( [Frame] )

Get/set the status bara of this View object.

=cut

sub status_bar {
	my $self = shift;
	$self->{-status_bar} = shift if @_;
	return $self->{-status_bar};	
}

=head2 guiBlocks ( )

Returns the GuiBlocks of this View object.

=cut

sub guiblocks {
	my $self = shift;
	return $self->{-guiblocks};
}

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

=head2 remove_all_guiblocks ( )

Remove all Guiblocks associated with this View.

=cut

sub remove_all_guiblocks {
	my $self = shift;
	$self->{-guiblocks} = {};
	return $self;
}

=head2 _close_view ( )

Close the current View.

=cut

sub _close_view {
	my $self = shift;
	my $guiSchedule = $self->guiSchedule;
	$guiSchedule->_close_view($self);
}

# =================================================================
# draw_block
# =================================================================

=head2 draw_block ( Block )

Turns the block into a GuiBlock and draws it on the View.

=cut

sub draw_block {
	my $self     = shift;
	my $block    = shift;
	my $coords   = $self->_get_pixel_coords($block);
	my $colour = '';
	$colour = "#abcdef" if $self->type eq 'teacher';
	$colour = "#80FF80" if $self->type eq 'lab';
	$colour = "#dddddd" unless $block->movable;
	
	my $scale = $self->currentScale;
	
	my $guiblock = GuiBlocks->new( $self, $block, $coords, $colour, $scale );

	$self->canvas->CanvasBind( "<1>", "" );
	$self->canvas->CanvasBind( "<B1-Motion>", "" );
    $self->canvas->CanvasBind( "<ButtonRelease-1>", "" );

	# bind on click event to guiblock if movable
	if ($block->movable && !$Move_Across_Views) {
		$self->canvas->bind( $guiblock->group, "<1>",
			[ \&_on_click, $guiblock, $self, Tk::Ev("x"), Tk::Ev("y") ] );	
	}
	
	if($Move_Across_Views && $self->type ne 'stream') {
		$self->canvas->bind( $guiblock->group, "<1>",
			[ \&_start_guiblock_move, $self, $guiblock ] );
		
		my $drag_Source = $self->canvas->DragDrop(
				-event        =>"<B1-Motion>", 
				-sitetypes    => [qw/Local/],
				-text		  => 'No Course Selected'
				);
	
		$self->dragSource($drag_Source);
	}
	
	# double click opens companion views
	$self->canvas->bind( $guiblock->group, "<Double-1>",
		[ \&_double_open_view, $self, $guiblock ] );
	
    # menu bound to individual gui-blocks
    my $pm = $self->popup_menu();    
    
    $self->canvas->bind($guiblock->group,'<3>',
        [ \&postmenu, $pm, Ev('X'), Ev('Y'), $guiblock ]);

	return $guiblock;
}

=head2 _double_open_view ( Canvas, Self, GuiBlock )

Creates the appropriate View when the User double clicks on a GuiBlock.

=cut

sub _double_open_view {
	my ($cn, $self, $guiblock) = @_;
	my $type = $self->type;

	if($type eq 'lab' || $type eq 'stream') {
		# in lab or stream, open teacher schedules
		# no teacher schedules, then open other lab schedules
		my @teachers = $guiblock->block->teachers;
		if (@teachers) {
			$self->guiSchedule->_create_view(\@teachers, $self->type);
		} else {
			my @labs = $guiblock->block->labs;
			$self->guiSchedule->_create_view(\@labs, 'teacher', $self->obj) if @labs;
		}
	} elsif($type eq 'teacher') {
		# in teacher schedule, open lab schedules
		# no lab schedules, then open other teacher schedules
		my @labs = $guiblock->block->labs;
		if (@labs) {
			$self->guiSchedule->_create_view(\@labs, $self->type);
		} else {
			my @teachers = $guiblock->block->teachers;		
			$self->guiSchedule->_create_view(\@teachers, 'lab', $self->obj) if @teachers;
		}
	}
}
# =================================================================
# draw_background
# =================================================================

=head2 draw_background ( )

Draws the Schedule timetable on the View canvas.

=cut

sub draw_background {
	my $self   = shift;
	my $canvas = $self->canvas;
	my $Xoffset = $self->xOffset;
	my $Yoffset = $self->yOffset;
	my $xScale = $self->xScale;
	my $yScale = $self->yScale;
	my $wScale = $self->wScale;
	my $hScale = $self->hScale;
	my $currentScale = $self->currentScale;
	
	$EarliestTime = min( keys %times );
	my $latestTime = max( keys %times );

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
		if ( $time != $latestTime ) {
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
	my $ymax = $latestTime - $EarliestTime + $Yoffset;
	for ( my $i = 0 ; $i <= scalar @days ; $i++ ) {
		my $xcoord = $i + $Xoffset;
		$canvas->createLine( $xcoord, 0, $xcoord, $ymax );

		# day text
		if ( $i < scalar @days ) {
			if($currentScale <= 0.5) {
				$canvas->createText(
					$xcoord + 0.5,
					$Yoffset / 2,
					-text => substr($days[$i], 0, 1)
				);
			} else {
				$canvas->createText(
					$xcoord + 0.5,
					$Yoffset / 2,
					-text => $days[$i]
				);
			}
		}
	}
	
	$canvas->scale( 'all', $xScale, $yScale, $wScale, $hScale );
}

# =================================================================
# moving a GuiBlock
# =================================================================

=head2 _on_click ( Canvas, GuiBlock, self, xstart, ystart )

Set up for drag and drop of GuiBlock. Binds motion and button release events to GuiBlock.

=cut

sub _on_click {
	my ( $cn, $guiblock, $self, $xstart, $ystart ) = @_;
	my ( $startingX, $startingY ) = $cn->coords( $guiblock->rectangle );

	# this block is being controlled by the mouse
	$guiblock->is_controlled(1);

	$self->canvas->CanvasBind( "<Motion>", "" );
    $self->canvas->CanvasBind( "<ButtonRelease-1>", "" );

	$cn->CanvasBind(
		"<Motion>",
		[
			\&_mouse_move, $guiblock,   $self,       $xstart,
			$ystart,       Tk::Ev("x"), Tk::Ev("y"), $startingX,
			$startingY
		]
	);
	$cn->CanvasBind( "<ButtonRelease-1>", [ \&_end_move, $guiblock, $self ] );
}

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
    $cn->CanvasBind("<Motion>",""    );
    
    # raise the block
	$guiblock->view->canvas->raise( $guiblock->group );

	# where block needs to go
	my $desiredX = $xmouse - $xstart + $startingX;
	my $desiredY = $ymouse - $ystart + $startingY;

	# current x/y coordinates of rectangle
	my ( $curXpos, $curYpos ) = $cn->coords( $guiblock->rectangle );

	# check for valid move
	if(defined $curXpos && defined $curYpos) {
		# where block is moving to
		my $deltaX = $desiredX - $curXpos;
		my $deltaY = $desiredY - $curYpos;
	
		# move the guiblock
		$cn->move( $guiblock->group, $deltaX, $deltaY );
		$mw->update;
	
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
        unless ($guiblock->is_controlled) {
            _end_move($cn, $guiblock, $self );
        }
    
        # else - rebind the motion event handler
        else {    
            $cn->CanvasBind(
                "<Motion>",
                [
                    \&_mouse_move, $guiblock,   $self,       $xstart,
                    $ystart,       Tk::Ev("x"), Tk::Ev("y"), $startingX,
                    $startingY
                ]
            );
        }
        
}

=head2 _end_move ( Canvas, GuiBlock )

Moves the GuiBlock to the cursors current position on the View and updates the Blocks time in the Schedule.

=cut

sub _end_move {
	my ( $cn, $guiblock, $self ) = @_;
		
	# unbind the motion on the guiblock
	$cn->CanvasBind( "<Motion>", "" );
    $cn->CanvasBind( "<ButtonRelease-1>", "" );
	
	$guiblock->is_controlled(0);

	my $undo = Undo->new( $guiblock->block->id, $guiblock->block->start, $guiblock->block->day, $self->obj, "Day/Time");

	# set guiblocks new time and day
	$guiblock->block->snap_to_day(1,scalar(@days));
	$guiblock->block->snap_to_time(min(keys %times),max(keys %times));

	# don't create undo if moved to starting position
	if($undo->origin_start ne $guiblock->block->start || $undo->origin_day ne $guiblock->block->day) {
		$self->guiSchedule->add_undo($undo);
		$Undo_left = scalar $self->guiSchedule->undoes ." undoes left";

		# new move, so reset redo
		$self->guiSchedule->remove_all_redoes;
		$Redo_left = scalar $self->guiSchedule->redoes ." redoes left";
	}

	# current x/y coordinates of rectangle
	my ( $curXpos, $curYpos ) = $cn->coords( $guiblock->rectangle );

	# get the guiblocks new coordinates (closest day/time)
	my $coords = $self->_get_pixel_coords( $guiblock->block );

###### DEBUG
unless ($coords->[0] && $curYpos) {
	no warnings;
	print "coords <",$coords->[0],">,<",$coords->[1],">\t cur(X|Y)pos <",$curXpos,">,<",$curYpos,">\n";
	print "rectangle: <",$guiblock->rectangle,">\n";
	print "group: <",$guiblock->group,">\n";
	print "bbox: <",$cn->bbox($guiblock->rectangle),">\n";
}
	# move the guiblock to new position and unbind
	$cn->move(
		$guiblock->group,
		$coords->[0] - $curXpos,
		$coords->[1] - $curYpos
	);
	$mw->update;

	# update all the views that have the block just moved to its new position
	my $guiSchedule = $self->guiSchedule;
	my $block       = $guiblock->block;
    $guiSchedule->update_all_views($block);

	# calculate new conflicts and update views to show these conflicts
    $self->schedule->calculate_conflicts;
    $guiSchedule->update_for_conflicts;
    $guiSchedule->set_dirty($guiSchedule->dirty_flag);
    
    # get all teachers, labs and streams and update the button colours based on the new positions of guiblocks
    my @teachers = $self->schedule->all_teachers;
    my @labs = $self->schedule->all_labs;
    my @streams = $self->schedule->all_streams;
    $self->guiSchedule->determine_button_colours(\@teachers, 'teacher') if @teachers;
    $self->guiSchedule->determine_button_colours(\@labs, 'lab') if @labs;
    $self->guiSchedule->determine_button_colours(\@streams, 'stream') if @streams;
}

=head2 _get_pixel_coords ( Block )

Gets the coordinates in pixels for where the time of the Block is placed on the View.

=cut

sub _get_pixel_coords {
	my $self = shift;
	my $Xoffset = $self->xOffset;
	my $Yoffset = $self->yOffset;
	my $wScale = $self->wScale;
	my $hScale = $self->hScale;
	my $block = shift;
	
	my $x = ( $Xoffset + ( $block->day_number - 1 ) ) * $wScale;
	my $y  = ( $Yoffset + ( $block->start_number - $EarliestTime ) ) * $hScale;
	my $x2 = $wScale + $x - 1;
	my $y2 = $block->duration * $hScale + $y - 1;
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
	
	my $day      = ( $x / $wScale ) - $Xoffset + 1;
	my $time     = ( $y / $hScale ) - $Yoffset + $EarliestTime;
	$guiblock->block->day_number($day);
	$guiblock->block->start_number($time);
}

=head2 update ( $block )

Updates the position of any GuiBlocks, on multiple Views, that have the same Block
as the currently moving GuiBlock.

=cut

sub update {
	my $self  = shift;
	my $block = shift;

	# go through each guiblock on the view
	if($self->guiblocks) {
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

=head2 update_for_conflicts ( )

Determines conflict status for all GuiBlocks on this View and colours them accordingly.

=cut

sub update_for_conflicts {
	my $self = shift;
	my $guiblocks = $self->guiblocks;
	
    my $view_conflict = 0;

	# for every guiblock on this view
	foreach my $guiblock ( values %$guiblocks ) {
		
		# colour block if it is necessary
		if($guiblock->block->moveable) {
		 
		    $self->colour_block($guiblock);
		    
		    # create conflict number for entire view by 'or'ing each block conflict
		    $view_conflict = Conflict->most_severe($view_conflict | $guiblock->block->is_conflicted);
		}
	}

	# get reference to button that created this view
	my $btn = $self->button_ptr;
	
	# change button for this view to appropriate colour based on conflicts
	if ($view_conflict) {
		$$btn->configure(-background => $Scheduler::ConflictColours->{$view_conflict});
	} else {
		$$btn->configure(-background => $Scheduler::Colours->{ButtonBackground} );
	}
}

sub colour_block {
    my $self = shift;
    my $guiblock = shift;
    my $conflict = Conflict->most_severe($guiblock->block->is_conflicted);
    
    # change the colour of the block to the most important conflict
    if ($conflict) {
        $guiblock->change_colour($Scheduler::ConflictColours->{$conflict});
    }            

    # no conflict found, reset back to default colour
    else {
        $guiblock->change_colour($guiblock->colour);    
    }
}

=head2 redraw ( )

Redraws the View with new GuiBlocks and their positions.

=cut

sub redraw {
	my $self = shift;
	my $obj = $self->obj;
	my $schedule = $self->schedule;
	my $cn = $self->canvas;
	my $currentScale = $self->currentScale;
		
	my @blocks;
	
	if($obj->isa("Teacher")) { @blocks = $schedule->blocks_for_teacher($obj);  } 
	elsif($obj->isa("Lab")) { @blocks = $schedule->blocks_in_lab($obj); }
	else { @blocks = $schedule->blocks_for_stream($obj); }
	
	# remove everything on canvas
	$cn->delete('all');
	# redraw timetable
	$self->draw_background;
	# remove all guiblocks stored in the View
	$self->remove_all_guiblocks;
	
	# redraw all guiblocks
	foreach my $b (@blocks) {
		$b->start( $b->start );
		$b->day( $b->day );
		my $guiblock = $self->draw_block($b);
		$self->add_guiblock($guiblock);
	}
	
	my $status;
	
	# setup status bar text
	if($Move_Across_Views) {
		$status = "Movement Type: Drag across open schedules (Shift click to change)";
		if($currentScale == 0.75) {
			$status = "Drag across schedules";
		} elsif ($currentScale <= 0.5) {
			$status = "Across";
		}
	} else {
		$status = "Movement Type: Drag in current schedule (Shift click to change)";
		if($currentScale == 0.75) {
			$status = "Drag in current schedule";
		} elsif ($currentScale <= 0.5) {
			$status = "In";	
		}
	}
	# create status bar
	$self->status_bar($self->create_status_bar($status));
	
	$self->blocks(\@blocks);
	$schedule->calculate_conflicts;
	$self->guiSchedule->update_for_conflicts;
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
