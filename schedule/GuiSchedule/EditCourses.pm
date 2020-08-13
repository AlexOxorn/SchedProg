#!/usr/bin/perl
use strict;
use warnings;

package EditCourses;
use FindBin;
use Carp;
use Tk;
use lib "$FindBin::Bin/..";
use GuiSchedule::EditCoursesDialogs;
use Tk::DynamicTree;
use Tk::DragDrop;
use Tk::DropSite;
use Tk::ItemStyle;
use Tk::FindImages;
use PerlLib::Colours;
use Tk::FindImages;
use Tk::Dialog;
use Tk::Menu;
use Tk::LabEntry;
use Tk::Optionmenu;
use Tk::JBrowseEntry;

=head1 NAME

EditCourses - provides GUI interface to modify (add/delete) courses 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Schedule;
    use GuiSchedule::GuiSchedule
    use Tk;
    use Tk::InitGui;
    
    my $Dirtyflag           = 0;
    my $mw                  = MainWindow->new();
    my ( $Colours, $Fonts ) = InitGui->set($mw);    
    my $Schedule = Schedule->read_YAML('myschedule_file.yaml');
    my $guiSchedule         = GuiSchedule->new( $mw, \$Dirtyflag, \$Schedule );
    
    # create gui for editing courses
    # NOTE: requires $guiSchedule just so that it can update
    #       the views if data has changed (via the dirty flag)
    
    my $de = EditCourses->new( $mw, $Schedule, \$Dirtyflag, $Colours, $Fonts,
                $guiSchedule )

=head1 DESCRIPTION

Create / Delete courses, assign teacheres, labs, etc.

=head1 TODO

Assigning a teacher to a section that has no blocks appears not to
work, because they are not shown in the tree.  However, they are there.

=head1 METHODS

=cut

# =================================================================
# Class/Global Variables
# =================================================================
our $Max_id = 0;
my $Drag_source;
our $Schedule;
my $GuiSchedule;
my $Dragged_from;
my $Dirty_ptr;
my $Fonts;
my $Colours;
my %Styles;

# =================================================================
# new_basic
# =================================================================

=head2 new_basic ()

creates the basic Data Entry (simple matrix)

B<Returns>

data entry object

=cut

# ===================================================================
# new
# ===================================================================
sub new {
	my $class = shift;
	my $frame = shift;
	$Schedule  = shift;
	$Dirty_ptr = shift;
	$Colours   = shift;
	$Fonts     = shift;
	$GuiSchedule = shift;

	# ----------------------------------------------------------------
	# set up photos and styles, etc.
	# ----------------------------------------------------------------
	$Styles{-course} = $frame->ItemStyle(
		'text',
		-bg => $Colours->{DarkBackground},
		-fg => $Colours->{SelectedForeground},
	);

	# ----------------------------------------------------------------
	# using grid, create right and left panels
	# ----------------------------------------------------------------
	# always start from scratch (- means we are always up to date)
	foreach my $sl ( $frame->gridSlaves ) {
		$sl->destroy;
	}
	my $right_panel =
	  $frame->Frame(  )
	  ->grid( -row => 0, -column => 1, -sticky => 'nsew' );
	my $left_panel =
	  $frame->Frame(  )
	  ->grid( -row => 0, -column => 0, -sticky => 'nsew' );

	# calculate min_width of left panel based on screen size
	my @x =
	  ( $frame->toplevel->geometry() =~ /^=?(\d+)x(\d+)?([+-]\d+[+-]\d+)?$/ );
	my $min_width = 7 / 16 * $x[0];

	# relative weights etc to widths
	$frame->gridColumnconfigure( 0, -minsize => $min_width, -weight => 1 );
	$frame->gridColumnconfigure( 1, -weight => 1 );
	$frame->gridRowconfigure( 0, -weight => 1 );

	# ----------------------------------------------------------------
	# make Schedule tree
	# ----------------------------------------------------------------
	my $tree;
	my $treescrolled = $left_panel->Scrolled(
		'DynamicTree',
		-scrollbars => 'osoe',
		-separator  => '/',
		-command    => [ \&_double_click, $frame, \$tree ],
	)->pack( -expand => 1, -fill => 'both', -side => 'left' );
	$tree = $treescrolled->Subwidget('dynamictree');
	$tree->bind( '<Key-Return>', [ \&_return, $frame ] );

	# ----------------------------------------------------------------
	# make panel for modifying Schedule
	# ----------------------------------------------------------------
	my $panel =
	  $right_panel->Frame()
	  ->pack( -expand => 1, -fill => 'both', -side => 'right' );

	my ( $labs_list, $streams_list, $teachers_list ) =
	  create_panel_for_modifying( $tree, $panel );

	#-------------------------------
	# Alex Code
	# Right click menu binding
	#-------------------------------
	_create_right_click_menu( $treescrolled, $teachers_list, $labs_list,
		$streams_list, $tree );

	# ----------------------------------------------------------------
	# drag and drop bindings
	# ----------------------------------------------------------------
	_create_drag_drop_objs( $teachers_list, $labs_list, $streams_list, $tree );

	# ---------------------------------------------------------------
	# add "Schedule" to tree
	# ---------------------------------------------------------------
	my $path = '';
	$tree->add(
		"Schedule",
		-text => 'Schedule',
		-data => { -obj => $Schedule },
	);

	refresh_schedule($tree);
	$tree->autosetmode();
}

# ===================================================================
# create panel for modifying the schedule
# ===================================================================
sub create_panel_for_modifying {

	my $tree  = shift;
	my $panel = shift;

	# ---------------------------------------------------------------
	# button row
	# ---------------------------------------------------------------
	my $button_row = $panel->Frame->grid(
		-column => 0,
		-sticky => 'nwes',
		-row    => 3
	);

	# ---------------------------------------------------------------
	# buttons
	# ---------------------------------------------------------------
	my $new_classNew = $button_row->Button(
		-text    => "New Course",
		-width   => 11,
		-command => [ \&new_course, $panel, $tree ]
	)->pack( -side => 'left' );

	my $new_classEdit = $button_row->Button(
		-text    => "Edit Selection",
		-width   => 11,
		-command => [ \&edit_course, $panel, $tree ]
	)->pack( -side => 'left' );

	# ---------------------------------------------------------------
	# teacher and lab and stream list
	# ---------------------------------------------------------------
	my $teachers_list =
	  $panel->Scrolled( 'Listbox', -scrollbars => 'oe' )
	  ->grid( -column => 0, -sticky => 'nwes', -row => 0 );

	#$teachers_list->configure();
	my $labs_list =
	  $panel->Scrolled( 'Listbox', -scrollbars => 'oe' )
	  ->grid( -column => 0, -sticky => 'nwes', -row => 1 );
	my $streams_list =
	  $panel->Scrolled( 'Listbox', -scrollbars => 'oe' )
	  ->grid( -column => 0, -sticky => 'nwes', -row => 2 );

	$teachers_list = $teachers_list->Subwidget('listbox');
	$labs_list     = $labs_list->Subwidget('listbox');
	$streams_list  = $streams_list->Subwidget('listbox');

	# ---------------------------------------------------------------
	# unbind the motion for general listbox widgets, which interferes
	# with the drag-drop bindings later on.
	# ---------------------------------------------------------------
	$teachers_list->bind(  '<B1-Motion>', undef );
	$teachers_list->bind( "<Double-Button-1>",
		[ \&_double_click_teacher, $teachers_list ] );

	# ---------------------------------------------------------------
	# assign weights to the panel grid
	# ---------------------------------------------------------------
	$panel->gridColumnconfigure( 0, -weight => 1 );
	$panel->gridRowconfigure( 0, -weight => 1 );
	$panel->gridRowconfigure( 1, -weight => 2 );
	$panel->gridRowconfigure( 2, -weight => 2 );
	$panel->gridRowconfigure( 3, -weight => 0 );

	# ---------------------------------------------------------------
	# populate teacher and lab and stream list
	# ---------------------------------------------------------------
	foreach my $teacher ( sort { &_teacher_sort } $Schedule->teachers->list ) {
		$teachers_list->insert( 'end',
			    $teacher->id . ":  "
			  . $teacher->firstname . " "
			  . $teacher->lastname );
	}
	foreach my $lab ( sort { &_alpha_number_sort } $Schedule->labs->list ) {
		$labs_list->insert( 'end',
			$lab->id . ":  " . $lab->number . " " . $lab->descr );
	}
	foreach my $stream ( sort { &_alpha_number_sort } $Schedule->streams->list )
	{
		$streams_list->insert( 'end',
			$stream->id . ":  " . $stream->number . " " . $stream->descr );
	}

	return ( $labs_list, $streams_list, $teachers_list );
}

# ===================================================================
# refresh Schedule
# ===================================================================
sub refresh_schedule {
	my $tree = shift;
	my $path = "Schedule";
	$tree->delete( 'offsprings', $path );

	foreach my $course ( sort { &_alpha_number_sort } $Schedule->courses->list )
	{
		my $c_id    = "Course" . $course->id;
		my $newpath = "Schedule/$c_id";
		$tree->add(
			$newpath,
			-text     => $course->number . "\t" . $course->name,
			-data     => { -obj => $course },
			-style    => $Styles{-course},
			-itemtype => 'text',
		);
		refresh_course( $tree, $course, $newpath );
	}
	$tree->autosetmode();
}

# ===================================================================
# refresh course branch
# ===================================================================
sub refresh_course {
	my $tree     = shift;
	my $course   = shift;
	my $path     = shift;
	my $not_hide = shift;
	$tree->delete( 'offsprings', $path );

	

	# add all the sections for each course
	foreach my $s ( sort { &_number_sort } $course->sections ) {
		my $s_id     = "Section" . $s->id;
		my $new_path = "$path/$s_id";
		my $text     = "$s";
		if ( @{ $s->streams } ) {
			$text = $text . " (" . join( ",", $s->streams ) . ")";
		}
		$tree->add(
			$new_path,
			-text => $text,
			-data => { -obj => $s }
		);
		refresh_section( $tree, $s, $new_path, $not_hide );
	}

	$tree->autosetmode();
}

# ===================================================================
# refresh section branch
# ===================================================================
sub refresh_section {
	my $tree     = shift;
	my $s        = shift;
	my $path     = shift;
	my $not_hide = shift;
	
	
	
	$tree->delete( 'offsprings', $path );
	$tree->update;
	
	# add all the blocks for this section
	foreach my $bl ( sort { &_block_sort2 } $s->blocks ) {
		my $b_id     = "Block" . $bl->id;
		my $new_path = "$path/$b_id";

		$tree->add(
			$new_path,
			-text => $bl->print_description2
			,    #$bl->day . " " . $bl->start . " " . $bl->duration . "hrs",
			-data => { -obj => $bl }
		);

		refresh_block( $tree, $bl, $new_path, $not_hide );
	}

	$tree->autosetmode();
}

# ===================================================================
# add block to tree
# ===================================================================
sub refresh_block {
	my $tree     = shift;
	my $bl       = shift;
	my $path     = shift;
	my $not_hide = shift;
	
	#print "Block PATH = $path\n";
	
	$tree->delete( 'offsprings', $path );
	$tree->update;

	# add all the teachers for this block
	foreach my $t ( sort { &_teacher_sort } $bl->teachers ) {
		add_teacher( $tree, $t, $path, $not_hide );
	}

	# add all the labs for this block
	foreach my $l ( sort { &_alpha_number_sort } $bl->labs ) {
		add_lab( $tree, $l, $path, $not_hide );
	}

	$tree->hide( 'entry', $path ) unless $not_hide;
	$tree->autosetmode();
}

# ===================================================================
# add teacher to tree
# ===================================================================
sub add_teacher {
	my $tree     = shift;
	my $t        = shift;
	my $path     = shift;
	my $not_hide = shift || 0;

	my $t_id = "Teacher" . $t->id;
	$tree->add(
		"$path/$t_id",
		-text => "Teacher: " . $t->firstname . " " . $t->lastname,
		-data => { -obj => $t }
	);
	$tree->hide( 'entry', "$path/$t_id" ) unless $not_hide;

	$tree->autosetmode();
}

# ===================================================================
# add lab to tree
# ===================================================================
sub add_lab {
	my $tree     = shift;
	my $l        = shift;
	my $path     = shift;
	my $not_hide = shift;

	my $l_id = $l . $l->id;

	#no warnings;
	$tree->add(
		"$path/$l_id",
		-text => "Resource: " . $l->number . " " . $l->descr,
		-data => { -obj => $l }
	);
	$tree->hide( 'entry', "$path/$l_id" ) unless $not_hide;

	$tree->autosetmode();
}

# =================================================================
# sorting subs
# =================================================================
sub _number_sort { $a->number <=> $b->number }

sub _alpha_number_sort { $a->number cmp $b->number }

sub _block_sort {
	$a->day_number <=> $b->day_number
	  || $a->start_number <=> $b->start_number;
}

sub _block_sort2 {
	$a->number <=> $b->number;
}

sub _teacher_sort {
	$a->lastname cmp $b->lastname
	  || $a->firstname cmp $b->firstname;
}

# =================================================================
# set dirty flag
# =================================================================
sub set_dirty {
	$$Dirty_ptr = 1;
	$GuiSchedule->redraw_all_views if $GuiSchedule;
}

#==================================================================
#ALEX CODE
#create all the right click menu stuff
#==================================================================
sub _create_right_click_menu {
	my $treescrolled  = shift;
	my $teachers_list = shift;
	my $labs_list     = shift;
	my $streams_list  = shift;
	my $tree          = shift;

	my $lab_menu = $labs_list->Menu( -tearoff => 0 );
	my $stream_menu = $streams_list->Menu( -tearoff => 0 );

	$teachers_list->bind( '<Button-3>',
		[ \&_show_teacher_menu, $teachers_list, $tree, Ev('X'), Ev('Y') ] );

	$labs_list->bind( '<Button-3>',
		[ \&_show_lab_menu, $labs_list, $tree, Ev('X'), Ev('Y') ] );

	$streams_list->bind( '<Button-3>',
		[ \&_show_stream_menu, $streams_list, $tree, Ev('X'), Ev('Y') ] );

	$tree->bind(
		'<Button-3>',
		[
			\&_show_tree_menu, $tree, Ev('X'), Ev('Y')
		]
	);

}

# =================================================================
# create all the drag'n'drop stuff
# =================================================================
sub _create_drag_drop_objs {
	my $teachers_list = shift;
	my $labs_list     = shift;
	my $streams_list  = shift;
	my $tree          = shift;

	# -------------------------------------------------------------
	# drag from teachers/labs to course tree
	# -------------------------------------------------------------
	$teachers_list->DragDrop(
		-event     => '<B1-Motion>',
		-sitetypes => [qw/Local/],
		-startcommand =>
		  [ \&_teacher_lab_start_drag, $teachers_list, $tree, 'Teacher' ],

		#-postdropcommand => [ \&empty_trash, $trash_label ],
	);

	$teachers_list->DropSite(
		-droptypes   => [qw/Local/],
		-dropcommand => [ \&_drop_on_trash, $tree ],
	);

	$labs_list->DragDrop(
		-event     => '<B1-Motion>',
		-sitetypes => [qw/Local/],
		-startcommand =>
		  [ \&_teacher_lab_start_drag, $labs_list, $tree, 'Lab' ],
	);

	$labs_list->DropSite(
		-droptypes   => [qw/Local/],
		-dropcommand => [ \&_drop_on_trash, $tree ],
	);

	$streams_list->DragDrop(
		-event     => '<B1-Motion>',
		-sitetypes => [qw/Local/],
		-startcommand =>
		  [ \&_teacher_lab_start_drag, $streams_list, $tree, 'Stream' ],
	);

	$streams_list->DropSite(
		-droptypes   => [qw/Local/],
		-dropcommand => [ \&_drop_on_trash, $tree ],
	);

	$tree->DropSite(
		-droptypes     => [qw/Local/],
		-dropcommand   => [ \&_dropped_on_course, $tree ],
		-motioncommand => [ \&_dragging_on_course, $tree ],
	);

	# -------------------------------------------------------------
	# drag from course tree to trash can
	# -------------------------------------------------------------
	$tree->DragDrop(
		-event        => '<B1-Motion>',
		-sitetypes    => [qw/Local/],
		-startcommand => [ \&_course_tree_start_start_drag, $tree ],
	);

}

# =================================================================
# teacher/lab starting to drag - change name of drag widget to selected item
# =================================================================
sub _teacher_lab_start_drag {
	my ( $lb, $tree, $type, $drag ) = @_;
	my ($lb_sel) = $lb->curselection;
	my ($req)    = $lb->get($lb_sel);
	$drag->configure(
		-text => $req,
		-font => [qw/-family arial -size 18/],
		-bg   => '#abcdef'
	);
	$Drag_source  = $drag;
	$Dragged_from = $type;
	undef;
}

# =================================================================
# dropped teacher or lab on tree
# =================================================================
sub _dropped_on_course {
	my $tree = shift;

	# validate that we have data to work with
	return unless $Dragged_from;
	my $input = $tree->selectionGet();
	return unless $input;

	# get info about dropped location
	$input = ( ref $input ) ? $input->[0] : $input;
	my $obj = $tree->infoData($input)->{-obj};

	# -------------------------------------------------------------
	# Initialize some variables
	# -------------------------------------------------------------
	my $txt = $Drag_source->cget( -text );
	( my $id ) = split " ", $txt;
	chop $id;

	# -------------------------------------------------------------
	# add appropriate object to object
	# -------------------------------------------------------------
	if ( $Dragged_from eq 'Teacher' ) {
		my $add_obj = $Schedule->teachers->get($id);
		$obj->assign_teacher($add_obj);
	}

	if ( $Dragged_from eq 'Lab' ) {
		unless ( $obj->isa("Course") ) {
			my $add_obj = $Schedule->labs->get($id);
			$obj->assign_lab($add_obj);
		}
		else {
			$tree->bell;
		}
	}

	if ( $Dragged_from eq 'Stream' ) {
		my $add_obj = $Schedule->streams->get($id);
		if ( $obj->isa('Block') ) {
			$obj = $obj->section;
		}
		$obj->assign_stream($add_obj);

	}

	# -------------------------------------------------------------
	# update the Schedule and the tree
	# -------------------------------------------------------------
	if ( $Dragged_from eq 'Stream' ) {
		refresh_schedule($tree);
	}
	elsif ( $obj->isa('Block') ) {
		refresh_block( $tree, $obj, $input, 1 );

		#print $input;
	}
	elsif ( $obj->isa('Section') ) {
		refresh_section( $tree, $obj, $input, 1 );

		#print $input;
	}
	elsif ( $obj->isa('Course') ) {
		refresh_course( $tree, $obj, $input, 1 );

		#print $input;
	}

	# -------------------------------------------------------------
	# tidy up
	# -------------------------------------------------------------
	$tree->autosetmode();
	$Dragged_from = '';
	set_dirty();

}

# =================================================================
# trying to drop a lab/teacher onto the tree
# =================================================================
sub _dragging_on_course {
	my $tree = shift;
	my $x    = shift;
	my $y    = shift;

	# ignore this if trying to drop from tree to tree
	return if $Dragged_from eq 'Tree';

	# get the nearest item, and if it is good to
	# drop on it, set the selection

	my $ent = $tree->GetNearest($y);
	$tree->selectionClear;
	$tree->anchorClear;

	if ($ent) {
		my $obj = $tree->infoData($ent)->{-obj};
		if ( $obj->isa('Block') || $obj->isa('Section') || $obj->isa('Course') )
		{
			$tree->selectionSet($ent);
		}
	}
}

{
	my $toggle;
	my $dropped;

	# =================================================================
	# tree starting to drag - change name of drag widget to selected item
	# =================================================================
	sub _course_tree_start_start_drag {
		my ( $tree, $trash_label, $drag ) = @_;
		$trash_label->configure(
			-bg => $Colours->{WorkspaceColour},
			-fg => $Colours->{WindowForeground},
		);

		my $input = $tree->selectionGet();

		$Drag_source  = $drag;
		$Dragged_from = 'Tree';
		$dropped      = 0;
		$toggle       = 0;

		return unless $input;

		$drag->configure(
			-text => $tree->itemCget( $input, 0, -text ),
			-font => [qw/-family arial -size 18/],
			-bg   => '#abcdef'
		);

		undef;
	}

	# =================================================================
	# toggle size of trash can if trying to drop tree object on it
	# =================================================================
	sub _enter_trash {

		return unless $Dragged_from eq 'Tree';

		return;
	}

	# =================================================================
	# dropped item on trash can
	# =================================================================
	sub _drop_on_trash {
		my $tree = shift;

		# validate that we have data to work with
		unless ($Dragged_from) {
			return;
		}

		unless ($Dragged_from) {
			return;
		}
		my $input = $tree->selectionGet();

		unless ($input) {
			return;
		}

		# get info about dropped object
		$input = ( ref $input ) ? $input->[0] : $input;
		my $obj = $tree->infoData($input)->{-obj};

		# get parent widget
		my $parent = $tree->info( 'parent', $input );
		unless ($parent) {
			return;
		}
		my $parent_obj = $tree->infoData($parent)->{-obj};

		# -------------------------------------------------------------
		# get rid of object and update tree
		# -------------------------------------------------------------
		if ( $obj->isa('Teacher') ) {
			$parent_obj->remove_teacher($obj);
			refresh_block( $tree, $parent_obj, $parent, 1 );
		}
		elsif ( $obj->isa('Lab') ) {
			$parent_obj->remove_lab($obj);
			refresh_block( $tree, $parent_obj, $parent, 1 );
		}
		elsif ( $obj->isa('Block') ) {
			$parent_obj->remove_block($obj);
			refresh_section( $tree, $parent_obj, $parent, 1 );
		}
		elsif ( $obj->isa('Section') ) {
			$parent_obj->remove_section($obj);
			refresh_course( $tree, $parent_obj, $parent, 1 );
		}
		elsif ( $obj->isa('Course') ) {
			$Schedule->courses->remove($obj);
			refresh_schedule($tree);
		}

		# -------------------------------------------------------------
		# tidy up
		# -------------------------------------------------------------
		$tree->autosetmode();
		$Dragged_from = '';
		set_dirty();
	}

	sub empty_trash {
		my $trash_label = shift;
		$dropped = 1;

		$trash_label->configure(
			-bg => $Colours->{WorkspaceColour},
			-fg => $Colours->{WindowForeground},
		);
	}

}

# =================================================================
# edit/modify course
# =================================================================
sub _return {
	my $tree  = shift;
	my $frame = shift;
	return if $tree->infoAnchor;
	my $input = $tree->selectionGet();
	_double_click( $frame, \$tree, $input ) if $input;
}

sub _double_click {
	my $frame = shift;
	my $ttree = shift;
	my $tree  = $$ttree;
	my $path  = shift;
	my $obj   = _what_to_edit( $tree, $path );
	if ( $obj->isa('Course') ) {
		_edit_course_dialog( $frame, $tree, $obj, $path );
	}
	elsif ( $obj->isa('Section') ) {
		_edit_section_dialog( $frame, $tree, $obj, $path );
	}
	elsif ( $obj->isa('Block') ) {
		_edit_block_dialog( $frame, $tree, $obj, $path );
	}
	elsif ( $obj->isa('Teacher') ) {
		_teacher_stat( $frame, $obj );
	}
}

sub _double_click_teacher {
	my ($lb)    = @_;
	my $lb_sel  = $lb->curselection;
	my $teachID = $lb->get($lb_sel);

	( my $Tid ) = split " ", $teachID;
	chop $Tid;

	my $teacher = $Schedule->teachers->get($Tid);
	_teacher_stat( $lb, $teacher );
}

sub edit_course {
	my $frame = shift;
	my $tree  = shift;
	my $input = $tree->selectionGet();
	
	my $obj   = _what_to_edit( $tree, $input );
	if ($obj) {
		if ( $obj->isa('Course') ) {
			_edit_course_dialog( $frame, $tree, $obj, $input->[0] );
		}
		elsif ( $obj->isa('Section') ) {
			_edit_section_dialog( $frame, $tree, $obj, $input->[0] );
		}
		elsif ( $obj->isa('Block') ) {
			_edit_block_dialog( $frame, $tree, $obj, $input->[0] );
		}
		else {
			$frame->bell;
		}
	}
	else {
		$frame->bell;
	}
}

# ============================================================================================
# Create a new course
# ============================================================================================
sub new_course {
	my $frame = shift;
	my $tree  = shift;

	# make dialog box for editing
	my $edit_dialog = new_course_dialog( $frame, $tree );

	# empty dialog box
	$edit_dialog->{-number}->configure( -text => '' );
	$edit_dialog->{-name}->configure( -text => '' );
	$edit_dialog->{-sections}->configure( -text => 1 );
	$edit_dialog->{-hours}[0]->configure( -text => 1.5 );

	# show and populate
	$edit_dialog->{-toplevel}->raise();

}

sub _what_to_edit {
	my $tree  = shift;
	my $input = shift;

	my $obj;
	if ($input) {
		$input = ( ref $input ) ? $input->[0] : $input;
		$obj = $tree->infoData($input)->{-obj};
	}

	return $obj;
}

# =================================================================
# edit/modify course
# =================================================================

sub _flash_menu {
	my $menu  = shift;
	my $i     = 0;
	my $count = 0;

	my %colours = GetSystemColours();
	SetSystemColours( $menu, \%colours );
	$menu->configure( -bg => $colours{WorkspaceColour} );

	my $id = $menu->repeat(
		166,
		sub {
			if ($i) {
				$menu->configure( -background => "#ff0000" );
				$i = 0;
			}
			else {
				$menu->configure( -bg => $colours{WorkspaceColour} );
				$i = 1;
			}
		}
	);
}

# =================================================================
# save modified course
# returns course
# =================================================================
sub save_course_modified {
	my $edit_dialog = shift;
	my $new         = shift;
	my $course;
	my $tl = shift;

	my $tree = $edit_dialog->{-tree};

	#--------------------------------------------
	# Check that all elements are filled in
	#--------------------------------------------
	if (   $edit_dialog->{-number}->get eq ""
		|| $edit_dialog->{-name}->get eq ""
		|| $edit_dialog->{-sections}->get eq "" )
	{
		$tl->messageBox(
			-title   => 'Error',
			-message => "Missing elements"
		);
		return;
	}

	foreach my $blnum ( 1 .. scalar( @{ $edit_dialog->{-hours} } ) ) {
		if ( $edit_dialog->{-hours}[ $blnum - 1 ]->get eq "" ) {
			$tl->messageBox(
				-title   => 'Error',
				-message => "Missing elements"
			);
			return;
		}

	}

	# get course number
	my $number = $edit_dialog->{-number}->get;

	# if new, or if course ID has been modified, verify it's uniqueness
	if ( $new || $number ne $edit_dialog->{-inital_number} ) {
		$course = $Schedule->courses->get_by_number($number);
		if ($course) {
			$tree->toplevel->messageBox(
				-title   => 'Edit Course',
				-message => 'Course Number is NOT unique!',
				-type    => 'OK',
				-icon    => 'error'
			);
			$edit_dialog->{-toplevel}->raise;
			return;
		}
	}

	# get existing course object if not 'new'
	$course =
	  $Schedule->courses->get_by_number( $edit_dialog->{-inital_number} )
	  unless $new;

	# if no object, must create a new course
	unless ($course) {
		$course = Course->new( -number => $number );
		$Schedule->courses->add($course);
	}

	# set the properties
	$course->number($number);
	$course->name( $edit_dialog->{-name}->get );

	# go through each section
	foreach my $num ( 1 .. $edit_dialog->{-sections}->get ) {

		# if section already exists, skip it
		my $sec = $course->get_section($num);
		next if $sec;

		# create new section
		$sec = Section->new( -number => $num );
		$course->add_section($sec);

		# for each section, add the blocks
		foreach my $blnum ( 1 .. scalar( @{ $edit_dialog->{-hours} } ) ) {
			my $bl = Block->new( -number => $sec->get_new_number );
			$bl->duration( $edit_dialog->{-hours}[ $blnum - 1 ]->get );
			$sec->add_block($bl);
		}

	}

	# remove any excess sections
	foreach my $num (
		$edit_dialog->{-sections}->get + 1 .. $course->max_section_number )
	{
		my $sec = $course->get_section($num);
		$course->remove_section($sec) if $sec;
	}

	# update schedule and close this window
	$edit_dialog->{-toplevel}->destroy;
	refresh_schedule($tree);
	$tree->autosetmode();
	set_dirty();
	return $course;
}

# =================================================================
# make dialog box for editing courses
# =================================================================
sub new_course_dialog {
	my $frame = shift;
	my $tree  = shift;
	my $tl    = $frame->Toplevel( -title => "New Course" );
	my $self  = { -tree => $tree, -toplevel => $tl };

	# ---------------------------------------------------------------
	# instructions
	# ---------------------------------------------------------------
	$tl->Label(
		-text => "New Course",
		-font => [qw/-family arial -size 18/]
	)->pack( -pady => 10 );

	# ---------------------------------------------------------------
	# buttons
	# ---------------------------------------------------------------
	my $button_row =
	  $tl->Frame()
	  ->pack( -side => 'bottom', -expand => 1, -fill => 'y', -pady => 15 );
	$button_row->Button(
		-text    => 'Add Block',
		-width   => 12,
		-command => [ \&_add_block_to_editor, $self ]
	)->pack( -side => 'left', -pady => 3 );

	$self->{-remove_block_button} = $button_row->Button(
		-text    => 'Remove Block',
		-width   => 12,
		-command => [ \&_remove_block_to_editor, $self ],
		-state   => 'disabled'
	)->pack( -side => 'left', -pady => 3 );

	$self->{-new} = $button_row->Button(
		-text    => 'Create',
		-width   => 12,
		-command => [ \&save_course_modified, $self, 1, $tl ]
	)->pack( -side => 'left', -pady => 3 );

	$self->{-new} = $button_row->Button(
		-text    => "Create and Edit",
		-width   => 12,
		-command => sub {
			my $obj = save_course_modified( $self, 1, $tl );
			_edit_course_dialog( $tree, $tree, $obj, "Schedule/Course" . $obj->id );
		}
	)->pack( -side => 'left', -pady => 3 );

	$self->{-cancel} = $button_row->Button(
		-text    => 'Cancel',
		-width   => 12,
		-command => sub { $tl->destroy(); }
	)->pack( -side => 'left', -pady => 3 );

	# ---------------------------------------------------------------
	# info data
	# ---------------------------------------------------------------
	my $info_row = $self->{-info_row} =
	  $tl->Frame()->pack( -side => 'top', -expand => 1, -fill => 'both' );

	# ---------------------------------------------------------------
	# Course Info Labels
	# ---------------------------------------------------------------
	$info_row->Label(
		-text   => "Number",
		-anchor => 'e'
	)->grid( -column => 0, -row => 0, -sticky => 'nwes' );
	$info_row->Label(
		-text   => "Description",
		-anchor => 'e'
	)->grid( -column => 0, -row => 1, -sticky => 'nwes' );

	#$info_row->Label(
	#	-text   => "Hours per week",
	#	-anchor => 'e'
	#)->grid( -column => 0, -row => 2, -sticky => 'nwes' );

	# ---------------------------------------------------------------
	# Course Info Entry boxes
	# ---------------------------------------------------------------
	$self->{-number} =
	  $info_row->Entry( -width => 6 )
	  ->grid( -column => 1, -row => 0, -sticky => 'nwes' );

	$self->{-name} =
	  $info_row->Entry( -width => 30 )
	  ->grid( -column => 1, -row => 1, -sticky => 'nwes' );

	#$self->{-course_hours} = $info_row->Entry(
	#	-width           => 6,
	#	-validate        => 'key',
	#	-validatecommand => \&is_number,
	#	-invalidcommand  => sub { $info_row->bell },
	#)->grid( -column => 1, -row => 2, -sticky => 'nwes' );

	# make the "Enter" key mimic Tab key
	$self->{-number}->bind( "<Key-Return>",
		sub { $self->{-number}->eventGenerate("<Tab>") } );
	$self->{-name}
	  ->bind( "<Key-Return>", sub { $self->{-name}->eventGenerate("<Tab>") } );

	#$self->{-course_hours}->bind(
	#	"<Key-Return>",
	#	sub {
	#		$self->{-course_hours}->eventGenerate("<Tab>");
	#	}
	#);

	# ---------------------------------------------------------------
	# Section Info
	# ---------------------------------------------------------------
	$info_row->Label(
		-text   => "Sections",
		-anchor => 'e'
	)->grid( -column => 0, -row => 3, -sticky => 'nwes' );

	$self->{-sections} = $info_row->Entry(
		-width           => 5,
		-validate        => 'key',
		-validatecommand => \&is_number,
		-invalidcommand  => sub { $info_row->bell },
	)->grid( -column => 1, -row => 3, -sticky => 'nwes' );

	# make the "Enter" key mimic Tab key
	$self->{-sections}->bind( "<Key-Return>",
		sub { $self->{-sections}->eventGenerate("<Tab>") } );

	# ---------------------------------------------------------------
	# Block Info
	# ---------------------------------------------------------------
	$info_row->Label(
		-text   => 'Block Hours:',
		-anchor => 'se',
		-height => 2
	)->grid( -column => 0, -row => 4 );
	_add_block_to_editor( $self, 1 );

	return $self;
}

# ---------------------------------------------------------------
# add a block row to the editor
# ---------------------------------------------------------------
{
	my $num;

	sub _add_block_to_editor {
		my $self      = shift;
		my $input_num = shift;
		$num = 0 unless $num;
		$num++;
		$num = $input_num if defined $input_num;
		my $rmBTN = $self->{-remove_block_button};

		if ( $num > 1 ) {
			$rmBTN->configure( -state => 'normal' );
		}

		my $info_row = $self->{-info_row};

		$self->{-blockNums} = [] unless $self->{-blockNums};

		my $l = $info_row->Label(
			-text   => "$num",
			-anchor => 'e'
		)->grid( -column => 0, -row => 4 + $num, -sticky => 'nwes' );
		push @{ $self->{-blockNums} }, $l;

		$self->{-hours} = [] unless $self->{-hours};

		my $e = $info_row->Entry(
			-width           => 15,
			-validate        => 'key',
			-validatecommand => \&is_number,
			-invalidcommand  => sub { $info_row->bell },
		)->grid( -column => 1, -row => 4 + $num, -sticky => 'nwes' );

		push @{ $self->{-hours} }, $e;
		$e->focus;

		# make the "Enter" key mimic Tab key
		$e->bind( "<Key-Return>", sub { $e->eventGenerate("<Tab>") } );

	}

	sub _remove_block_to_editor {
		my $self      = shift;
		my $input_num = shift;
		my $info_row  = $self->{-info_row};
		my $rmBTN     = $self->{-remove_block_button};

		if ( $num <= 1 ) {
			my $Error = $info_row->Dialog(
				-title          => 'Error',
				-text           => "Can't remove block.",
				-default_button => 'Okay',
				-buttons        => ['Okay']
			)->Show();
			return;
		}

		$num--;

		if ( $num <= 1 ) {
			$rmBTN->configure( -state => 'disabled' );
		}

		my $tempL = pop @{ $self->{-blockNums} };
		my $tempH = pop @{ $self->{-hours} };
		$tempH->destroy if Tk::Exists($tempH);
		$tempL->destroy if Tk::Exists($tempL);
		$info_row->update;
	}
}

# =================================================================
# validate that number be entered in a entry box is a real number
# (positive real number)
# =================================================================
sub is_number {
	my $n = shift;
	return 1 if $n =~ (/^(\s*\d*\.?\d*\s*|)$/);
	return 0;
}

# =================================================================
# validate that number be entered in a entry box is a whole number
# (positive integer)
# =================================================================
sub is_integer {
	my $n = shift;
	return 1 if $n =~ /^(\s*\d+\s*|)$/;
	return 0;
}

# ================================================================
# Validate that the course number is new/unique
# (alway return true, just change input to red and disable close button)
# ================================================================
sub _unique_number {

	#no warnings;
	my $oldName   = shift;
	my $button    = shift;
	my $entry     = ${ +shift };
	my $message   = ${ +shift };
	my $toCompare = shift;
	if ($entry) {
		if (   $toCompare ne $oldName
			&& $Schedule->courses->get_by_number($toCompare) )
		{
			$button->configure( -state => 'disabled' );
			$entry->configure( -bg => 'red' );
			$message->configure( -text => "Number Not Unique" );
			$entry->bell;
		}
		else {
			$button->configure( -state => 'normal' );
			$entry->configure( -bg => 'white' );
			$message->configure( -text => "" );
		}
	}

	return 1;
}

#===============================================================
# Show Teacher Stats
#===============================================================

sub _teacher_stat {
	my $frame   = shift;
	my $teacher = shift;

	my $message = $Schedule->teacher_stat($teacher);

	$frame->messageBox(
		-title   => $teacher->firstname . " " . $teacher->lastname,
		-message => $message,
		-type    => 'Ok'
	);

}

# =================================================================
# footer
# =================================================================

=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2020, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;

