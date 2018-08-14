#!/usr/bin/perl
use strict;
use warnings;

package EditCourses;
use FindBin;
use Carp;
use Tk;
use lib "$FindBin::Bin/..";
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
my $image_dir = Tk::FindImages::get_image_dir();

=head1 NAME

EditCourses - provides GUI interface to modify (add/delete) courses 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut

# =================================================================
# Class/Global Variables
# =================================================================
our $Max_id = 0;
my $Drag_source;
my $Schedule;
my $GuiSchedule;
my $Trash1_photo;
my $Trash2_photo;
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
	my $image_dir = shift;
	$GuiSchedule = shift;

	# ----------------------------------------------------------------
	# set up photos and styles, etc.
	# ----------------------------------------------------------------
	$Styles{-course} = $frame->ItemStyle(
		'text',
		-bg => $Colours->{DarkBackground},
		-fg => $Colours->{SelectedForeground},
	);

	eval {
		$Trash1_photo = $frame->Photo(
			-format => 'gif',
			-file   => "$image_dir/small_trash.gif"
		) unless $Trash1_photo;

		#
		$Trash2_photo = $frame->Photo(
			-format => 'gif',
			-file   => "$image_dir/large_trash.gif"
		) unless $Trash2_photo;
	};

	# ----------------------------------------------------------------
	# using grid, create right and left panels
	# ----------------------------------------------------------------
	# always start from scratch (- means we are always up to date)
	foreach my $sl ( $frame->gridSlaves ) {
		$sl->destroy;
	}
	my $right_panel = $frame->Frame( -bg => 'pink' )
	  ->grid( -row => 0, -column => 1, -sticky => 'nsew' );
	my $left_panel = $frame->Frame( -bg => 'blue' )
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

	my ( $labs_list, $streams_list, $teachers_list, $trash_label ) =
	  create_panel_for_modifying( $Trash1_photo, $tree, $panel );

	#-------------------------------
	# Alex Code
	# Right click menu binding
	#-------------------------------
	_create_right_click_menu( $treescrolled, $teachers_list, $labs_list,
		$streams_list, $tree );

	# ----------------------------------------------------------------
	# drag and drop bindings
	# ----------------------------------------------------------------
	_create_drag_drop_objs( $trash_label, $teachers_list, $labs_list,
		$streams_list, $tree );

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

	my $Trash1_photo = shift;
	my $tree         = shift;
	my $panel        = shift;

	# ---------------------------------------------------------------
	# button row
	# ---------------------------------------------------------------
	my $button_row = $panel->Frame->grid(
		-column => 0,
		-sticky => 'nwes',
		-row    => 3
	);

	# ---------------------------------------------------------------
	# trash
	# ---------------------------------------------------------------

	my $trash_label;
	if ($Trash1_photo) {
		$trash_label = $button_row->Label(
			-image  => $Trash1_photo,
			-width  => 20,
			-height => 20
		)->pack( -side => 'left' );
	}
	else {
		$trash_label = $button_row->Label(
			-text   => 'Trash',
			-width  => 10,
			-height => 1,
			-bg     => $Colours->{WorkspaceColour},
			-fg     => $Colours->{WindowForeground},
		)->pack( -side => 'left' );
	}
	$trash_label->bind( "<Leave>", [ \&empty_trash, $trash_label ] );

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
	$teachers_list->bind( ref($teachers_list), '<B1-Motion>', undef );
	$teachers_list->bind( ref($teachers_list), "<Double-Button-1>",
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

	return ( $labs_list, $streams_list, $teachers_list, $trash_label );
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
	no warnings;
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
	$GuiSchedule->redraw_all_views;
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
			\&_show_tree_menu, $tree,   $teachers_list, $labs_list,
			$streams_list,     Ev('X'), Ev('Y')
		]
	);

}

#==================================================================
#ALEX CODE
#show menus
#==================================================================

sub _show_tree_menu {
	my ( $self, $tree, $teachers_list, $labs_list, $streams_list, $x, $y ) = @_;
	my @inputs = $tree->selectionGet();
	my $input  = $inputs[0];
	return unless $input;

	my $obj = $tree->infoData($input)->{-obj};
	my $parent = $tree->info( 'parent', $input );
	return unless $parent;
	my $parent_obj = $tree->infoData($parent)->{-obj};

	my $tree_menu = $tree->Menu( -tearoff => 0 );
	if ( $obj->isa('Course') ) {
		my @sections = $obj->sections;

		#=====================================
		#COURSE MENU
		#=====================================
		$tree_menu->cascade( -label => "Add Teacher" );
		$tree_menu->cascade( -label => "Set Stream" );
		$tree_menu->command(
			-label   => "Add Section(s)",
			-command => [ \&_add_section, $tree_menu, $tree, $obj, $input ]
		);
		$tree_menu->command(
			-label   => "Edit Course",
			-command => [ \&_edit_course2, $tree_menu, $tree, $obj, $input ]
		);
		$tree_menu->separator;
		$tree_menu->cascade( -label => "Remove Teacher" );
		$tree_menu->cascade( -label => "Remove Stream" );
		$tree_menu->command(
			-label   => "Clear All",
			-command => sub {
				my @sections = $obj->sections;
				foreach my $sec (@sections) {
					my @teachers = $sec->teachers;
					my @streams  = $sec->streams;
					foreach my $teach (@teachers) {
						$sec->remove_teacher($teach);
					}
					foreach my $stream (@streams) {
						$sec->remove_stream($stream);
					}
				}
				refresh_schedule($tree);
				set_dirty();
			}
		);
		$tree_menu->command(
			-label   => "Delete Course",
			-command => sub {
				$parent_obj->remove_course($obj);
				refresh_schedule($tree);
				set_dirty();
			}
		);

		#-------------------------------------------
		#Add Teacher Menu
		#-------------------------------------------
		my $add_teach = $tree_menu->entrycget( "Add Teacher", "-menu" );
		$add_teach->configure( -tearoff => 0 );

		my @newTeachers = $teachers_list->get( 0, 'end' );
		foreach my $teachID (@newTeachers) {
			( my $Tid ) = split " ", $teachID;
			chop $Tid;
			my $teach = $Schedule->teachers->get($Tid);
			$add_teach->command(
				-label   => $teach->firstname . " " . $teach->lastname,
				-command => sub {
					my @sections = $obj->sections;
					foreach my $sec (@sections) {
						$sec->assign_teacher($teach);
					}
					refresh_course( $tree, $obj, $input, 1 );
					set_dirty();
				}
			);
		}

		#-------------------------------------------
		#Remove Teacher Menu
		#-------------------------------------------
		my $remove_teach = $tree_menu->entrycget( "Remove Teacher", "-menu" );
		$remove_teach->configure( -tearoff => 0 );

		$remove_teach->command(
			-label   => "All Teachers",
			-command => sub {
				my @sections = $obj->sections;
				foreach my $sec (@sections) {
					my @teachers = $sec->teachers;
					foreach my $teach (@teachers) {
						$sec->remove_teacher($teach);
					}
					refresh_course( $tree, $sec, $input, 1 );
				}
				set_dirty();
			}
		);
		$remove_teach->separator;

		my %teacher;
		my @teachers;
		foreach my $sec (@sections) {
			my @temp = $sec->teachers;
			foreach my $i (@temp) {
				$teacher{ $i->id } = $i->id;
			}
		}

		@teachers = values %teacher;
		my $AllTeachers = $Schedule->teachers;
		foreach my $id (@teachers) {
			my $teacher = $AllTeachers->get($id);
			$remove_teach->command(
				-label   => $teacher->firstname . " " . $teacher->lastname,
				-command => sub {
					$obj->remove_teacher($teacher);
					refresh_course( $tree, $obj, $input, 1 );
					set_dirty();
				}
			);
		}

		#-----------------------------------
		#Add Streams
		#-----------------------------------
		my $add_stream = $tree_menu->entrycget( "Set Stream", "-menu" );
		$add_stream->configure( -tearoff => 0 );

		my @newSabs = $streams_list->get( 0, 'end' );
		foreach my $streamID (@newSabs) {
			( my $Lid ) = split " ", $streamID;
			chop $Lid;
			my $stream = $Schedule->streams->get($Lid);
			$add_stream->command(
				-label   => $stream->number . ": " . $stream->descr,
				-command => sub {
					my @sections = $obj->sections;
					foreach my $sec (@sections) {
						$sec->assign_stream($stream);
					}
					refresh_schedule($tree);
					set_dirty();
				}
			);
		}

		#-----------------------------------------
		#Remove Streams
		#-----------------------------------------
		my $remove_stream = $tree_menu->entrycget( "Remove Stream", "-menu" );
		$remove_stream->configure( -tearoff => 0 );

		$remove_stream->command(
			-label   => "All Streams",
			-command => sub {
				my @sections = $obj->sections;
				foreach my $sec (@sections) {
					my @streams = $sec->streams;
					foreach my $stream (@streams) {
						$sec->remove_stream($stream);
					}
				}
				refresh_schedule($tree);
				set_dirty();
			}
		);
		$remove_stream->separator;

		my %stream;
		my @streams;
		foreach my $sec (@sections) {
			my @temp = $sec->streams;
			foreach my $i (@temp) {
				$stream{ $i->id } = $i->id;
			}
		}

		@streams = values %stream;
		my $AllStreams = $Schedule->streams;
		foreach my $id (@streams) {
			my $stream = $AllStreams->get($id);
			$remove_stream->command(
				-label   => $stream->print_description2,
				-command => sub {
					$obj->remove_stream($stream);
					refresh_schedule($tree);
					set_dirty();
				}
			);
		}
	}
	elsif ( $obj->isa('Section') ) {

		#=====================================
		#SECTION MENU
		#=====================================
		$tree_menu->cascade( -label => "Add Teacher" );
		$tree_menu->cascade( -label => "Set Stream" );
		$tree_menu->command(
			-label   => "Add Block(s)",
			-command => [ \&_add_block, $tree_menu, $tree, $obj, $input ]
		);
		$tree_menu->command(
			-label   => "Edit Section",
			-command => [ \&_edit_section2, $tree_menu, $tree, $obj, $input ]
		);
		$tree_menu->separator;
		$tree_menu->cascade( -label => "Remove Teacher" );
		$tree_menu->cascade( -label => "Remove Stream" );
		$tree_menu->command(
			-label   => "Clear All",
			-command => sub {
				my @teachers = $obj->teachers;
				my @streams  = $obj->streams;
				foreach my $teach (@teachers) {
					$obj->remove_teacher($teach);
				}
				foreach my $stream (@streams) {
					$obj->remove_stream($stream);
				}
				refresh_schedule($tree);
				set_dirty();
			}
		);
		$tree_menu->command(
			-label   => "Delete Section",
			-command => sub {
				$parent_obj->remove_section($obj);
				refresh_course( $tree, $parent_obj, $parent, 1 );
				set_dirty();
			}
		);

		#-------------------------------------------
		#Add Teacher Menu
		#-------------------------------------------
		my $add_teach = $tree_menu->entrycget( "Add Teacher", "-menu" );
		$add_teach->configure( -tearoff => 0 );

		my @newTeachers = $teachers_list->get( 0, 'end' );
		foreach my $teachID (@newTeachers) {
			( my $Tid ) = split " ", $teachID;
			chop $Tid;
			my $teach = $Schedule->teachers->get($Tid);
			$add_teach->command(
				-label   => $teach->firstname . " " . $teach->lastname,
				-command => sub {
					$obj->assign_teacher($teach);
					set_dirty();
					refresh_section( $tree, $obj, $input, 1 );
				}
			);
		}

		#-------------------------------------------
		#Remove Teacher Menu
		#-------------------------------------------
		my $remove_teach = $tree_menu->entrycget( "Remove Teacher", "-menu" );
		$remove_teach->configure( -tearoff => 0 );

		my @teachers = $obj->teachers;
		$remove_teach->command(
			-label   => "All Teachers",
			-command => sub {
				foreach my $teach (@teachers) {
					$obj->remove_teacher($teach);
				}
				refresh_section( $tree, $obj, $input, 1 );
				set_dirty();
			}
		);
		$remove_teach->separator;

		foreach my $teach (@teachers) {
			$remove_teach->command(
				-label   => $teach->firstname . " " . $teach->lastname,
				-command => sub {
					$obj->remove_teacher($teach);
					refresh_section( $tree, $obj, $input, 1 );
					set_dirty();
				}
			);
		}

		#-----------------------------------
		#Add Streams
		#-----------------------------------
		my $add_stream = $tree_menu->entrycget( "Set Stream", "-menu" );
		$add_stream->configure( -tearoff => 0 );

		my @newSabs = $streams_list->get( 0, 'end' );
		foreach my $streamID (@newSabs) {
			( my $Lid ) = split " ", $streamID;
			chop $Lid;
			my $stream = $Schedule->streams->get($Lid);
			$add_stream->command(
				-label   => $stream->number . ": " . $stream->descr,
				-command => sub {
					$obj->assign_stream($stream);
					set_dirty();
					refresh_schedule($tree);
				}
			);
		}

		#-----------------------------------------
		#Remove Streams
		#-----------------------------------------
		my $remove_stream = $tree_menu->entrycget( "Remove Stream", "-menu" );
		$remove_stream->configure( -tearoff => 0 );

		my @streams = $obj->streams;
		$remove_stream->command(
			-label   => "All Streams",
			-command => sub {
				foreach my $stream (@streams) {
					$obj->remove_stream($stream);
				}
				refresh_schedule($tree);
				set_dirty();
			}
		);
		$remove_stream->separator;
		foreach my $stream (@streams) {
			$remove_stream->command(
				-label   => $stream->number . ": " . $stream->descr,
				-command => sub {
					$obj->remove_stream($stream);
					refresh_schedule($tree);
					set_dirty();
				}
			);
		}

	}
	elsif ( $obj->isa('Block') ) {

		#=========================
		# BLOCK MENU
		#=========================
		$tree_menu->cascade( -label => "Add Teacher" );
		$tree_menu->cascade( -label => "Set Resource" );
		$tree_menu->command(
			-label   => "Edit Block",
			-command => [ \&_edit_block2, $tree_menu, $tree, $obj, $input ]
		);
		$tree_menu->separator;
		$tree_menu->cascade( -label => "Remove Teacher" );
		$tree_menu->cascade( -label => "Remove Resource" );
		$tree_menu->command(
			-label   => "Clear All",
			-command => sub {
				my @teachers = $obj->teachers;
				my @labs     = $obj->labs;
				foreach my $teach (@teachers) {
					$obj->remove_teacher($teach);
				}
				foreach my $lab (@labs) {
					$obj->remove_lab($lab);
				}
				refresh_block( $tree, $obj, $input, 1 );
				set_dirty();
			}
		);
		$tree_menu->command(
			-label   => "Delete Block",
			-command => sub {
				$parent_obj->remove_block($obj);
				refresh_section( $tree, $parent_obj, $parent, 1 );
				set_dirty();
			}
		);
		$tree_menu->separator;
		$tree_menu->command(
			-label   => "Change Number of Hours",
			-command => sub {
				my $num;
				my $db1 = $tree_menu->DialogBox(
					-title          => 'Block Duration',
					-buttons        => [ 'Ok', 'Cancel' ],
					-default_button => 'Ok',

					#-height => 300,
					#-width => 500
				);

				$db1->add( 'Label', -text => "Block Duration (in Hours)?" )
				  ->pack;
				$db1->add(
					'LabEntry',
					-textvariable    => \$num,
					-validate        => 'key',
					-validatecommand => \&is_number,
					-invalidcommand  => sub { $tree_menu->bell },
					-width           => 20,
				)->pack;
				my $answer1 = $db1->Show();
				if (   $answer1 eq 'Ok'
					&& defined($num)
					&& $num ne ""
					&& $num > 0 )
				{
					$obj->duration($num);
					refresh_section( $tree, $parent_obj, $parent, 1 );
					set_dirty();
				}
				elsif ($answer1 eq 'Ok'
					&& defined($num)
					&& $num ne ""
					&& $num == 0 )
				{
					$parent_obj->remove_block($obj);
					refresh_section( $tree, $parent_obj, $parent, 1 );
					set_dirty();
				}
			}
		);

		#----------------------------------
		#Add Teacher
		#----------------------------------
		my $add_teach = $tree_menu->entrycget( "Add Teacher", "-menu" );
		$add_teach->configure( -tearoff => 0 );

		my @newTeachers = $teachers_list->get( 0, 'end' );
		foreach my $teachID (@newTeachers) {
			( my $Tid ) = split " ", $teachID;
			chop $Tid;
			my $teach = $Schedule->teachers->get($Tid);
			$add_teach->command(
				-label   => $teach->firstname . " " . $teach->lastname,
				-command => sub {
					$obj->assign_teacher($teach);
					set_dirty();
					refresh_block( $tree, $obj, $input, 1 );
				}
			);
		}

		#--------------------------------------
		#Add Lab
		#--------------------------------------
		my $add_lab = $tree_menu->entrycget( "Set Resource", "-menu" );
		$add_lab->configure( -tearoff => 0 );

		my @newLabs = $labs_list->get( 0, 'end' );
		foreach my $labID (@newLabs) {
			( my $Lid ) = split " ", $labID;
			chop $Lid;
			my $lab = $Schedule->labs->get($Lid);
			$add_lab->command(
				-label   => $lab->number . ": " . $lab->descr,
				-command => sub {
					$obj->assign_lab($lab);
					set_dirty();
					refresh_block( $tree, $obj, $input, 1 );
				}
			);
		}

		#-----------------------------------------
		#Remove Teacher
		#-----------------------------------------
		my $remove_teach = $tree_menu->entrycget( "Remove Teacher", "-menu" );
		$remove_teach->configure( -tearoff => 0 );
		my @teachers = $obj->teachers;

		$remove_teach->command(
			-label   => "All Teachers",
			-command => sub {
				foreach my $teach (@teachers) {
					$obj->remove_teacher($teach);
				}
				refresh_block( $tree, $obj, $input, 1 );
				set_dirty();
			}
		);

		$remove_teach->separator;

		foreach my $teach (@teachers) {
			$remove_teach->command(
				-label   => $teach->firstname . " " . $teach->lastname,
				-command => sub {
					$obj->remove_teacher($teach);
					refresh_block( $tree, $obj, $input, 1 );
					set_dirty();
				}
			);
		}

		#-----------------------------------------
		#Remove Lab
		#-----------------------------------------
		my $remove_lab = $tree_menu->entrycget( "Remove Resource", "-menu" );
		$remove_lab->configure( -tearoff => 0 );

		my @labs = $obj->labs;

		$remove_lab->command(
			-label   => "All Resources",
			-command => sub {
				foreach my $lab (@labs) {
					$obj->remove_lab($lab);
				}
				refresh_block( $tree, $obj, $input, 1 );
				set_dirty();
			}
		);

		$remove_lab->separator;

		foreach my $lab (@labs) {
			$remove_lab->command(
				-label   => $lab->number . ": " . $lab->descr,
				-command => sub {
					$obj->remove_lab($lab);
					refresh_block( $tree, $obj, $input, 1 );
					set_dirty();
				}
			);
		}

	}
	elsif ( $obj->isa('Teacher') ) {

		#=====================
		#Teacher Menu
		#=====================
		$tree_menu->command(
			-label   => "Remove",
			-command => sub {
				$parent_obj->remove_teacher($obj);
				refresh_block( $tree, $parent_obj, $parent, 1 );
			}
		);
	}
	elsif ( $obj->isa('Lab') ) {

		#=====================
		#Lab Menu
		#=====================
		$tree_menu->command(
			-label   => "Remove",
			-command => sub {
				$parent_obj->remove_lab($obj);
				refresh_block( $tree, $parent_obj, $parent, 1 );
			}
		);
	}
	else {
		return;
	}
	$tree_menu->post( $x, $y );
}

sub _show_teacher_menu {
	my ( $self, $teachers_list, $tree, $x, $y ) = @_;
	my $teacher_menu = $teachers_list->Menu( -tearoff => 0 );
	my @teachers = $teachers_list->curselection();
	if ( scalar @teachers <= 0 ) {
		return;
	}
	my $teacher_ID = $teachers_list->get( $teachers[0] );
	( my $id ) = split " ", $teacher_ID;
	chop $id;
	my $add_obj = $Schedule->teachers->get($id);

	# -------------------------------------------------------------
	# add appropriate object to object
	# -------------------------------------------------------------

	#	my $add_obj = $Schedule->teachers->get($id);
	#	$obj->assign_teacher($add_obj);

	my @courses = $Schedule->courses->list();

	$teacher_menu->cascade( -label => "Add to Course" );
	my $tch2cor_Menu = $teacher_menu->entrycget( "Add to Course", "-menu" );
	$tch2cor_Menu->configure( -tearoff => 0 );

	#('command', -label => $_->name, -command => sub { $teachers_list->bell})
	foreach my $cor (@courses) {
		$tch2cor_Menu->cascade( -label => $cor->name );
		my $tchCorSec = $tch2cor_Menu->entrycget( $cor->name, "-menu" );
		$tchCorSec->configure( -tearoff => 0 );
		my @sections = $cor->sections;
		$tchCorSec->add(
			'command',
			-label   => "All Sections",
			-command => sub {
				foreach my $sec (@sections) {
					$sec->assign_teacher($add_obj);
					refresh_section( $tree, $sec,
						"Schedule/Course" . $cor->id . "/Section" . $sec->id,
						1 );
				}
				set_dirty();
			}
		);
		foreach my $sec (@sections) {
			$tchCorSec->cascade( -label => "$sec" );
			my $blockList = $tchCorSec->entrycget( "$sec", "-menu" );
			$blockList->configure( -tearoff => 0 );
			my @blockarray = $sec->blocks;
			my $size       = scalar @blockarray;
			$blockList->add(
				'command',
				-label   => "All Blocks",
				-command => sub {
					$sec->assign_teacher($add_obj);
					set_dirty();
					refresh_section( $tree, $sec,
						"Schedule/Course" . $cor->id . "/Section" . $sec->id,
						1 );
				}
			);
			for my $itr ( 1 ... $size ) {
				my $tempBlock = $blockarray[ $itr - 1 ];
				$blockList->add(
					'command',
					-label   => $tempBlock->print_description2,
					-command => sub {
						$tempBlock->assign_teacher($add_obj);
						set_dirty();
						refresh_block(
							$tree,
							$tempBlock,
							"Schedule/Course"
							  . $cor->id
							  . "/Section"
							  . $sec->id
							  . "/Block"
							  . $tempBlock->id,
							1
						);
					}
				);
			}
		}
	}

#$teacher_menu->add('command', -label => $teacher_ID, -command => sub { $teachers_list->bell});
	$teacher_menu->post( $x, $y );    # Show the popup menu
}

sub _show_lab_menu {
	my ( $self, $labs_list, $tree, $x, $y ) = @_;
	my $lab_menu = $labs_list->Menu( -tearoff => 0 );
	my @labs = $labs_list->curselection();
	if ( scalar @labs <= 0 ) {
		return;
	}
	my $lab_ID = $labs_list->get( $labs[0] );
	( my $id ) = split " ", $lab_ID;
	chop $id;
	my $add_obj = $Schedule->labs->get($id);

	# -------------------------------------------------------------
	# add appropriate object to object
	# -------------------------------------------------------------

	#	my $add_obj = $Schedule->labs->get($id);
	#	$obj->assign_lab($add_obj);

	my @courses = $Schedule->courses->list();

	$lab_menu->cascade( -label => "Add to Course" );
	my $tch2cor_Menu = $lab_menu->entrycget( "Add to Course", "-menu" );
	$tch2cor_Menu->configure( -tearoff => 0 );

	#('command', -label => $_->name, -command => sub { $labs_list->bell})
	foreach my $cor (@courses) {
		$tch2cor_Menu->cascade( -label => $cor->name );
		my $tchCorSec = $tch2cor_Menu->entrycget( $cor->name, "-menu" );
		$tchCorSec->configure( -tearoff => 0 );
		my @sections = $cor->sections;
		foreach my $sec (@sections) {
			$tchCorSec->cascade( -label => "$sec" );
			my $blockList = $tchCorSec->entrycget( "$sec", "-menu" );
			$blockList->configure( -tearoff => 0 );
			my @blockarray = $sec->blocks;
			my $size       = scalar @blockarray;
			$blockList->add(
				'command',
				-label   => "All Blocks",
				-command => sub {
					$sec->assign_lab($add_obj);
					set_dirty();
					refresh_section( $tree, $sec,
						"Schedule/Course" . $cor->id . "/Section" . $sec->id,
						1 );
				}
			);
			for my $itr ( 1 ... $size ) {
				my $tempBlock = $blockarray[ $itr - 1 ];
				$blockList->add(
					'command',
					-label   => $tempBlock->print_description2,
					-command => sub {
						$tempBlock->assign_lab($add_obj);
						set_dirty();
						refresh_block(
							$tree,
							$tempBlock,
							"Schedule/Course"
							  . $cor->id
							  . "/Section"
							  . $sec->id
							  . "/Block"
							  . $tempBlock->id,
							1
						);
					}
				);
			}
		}
	}

#$lab_menu->add('command', -label => $lab_ID, -command => sub { $labs_list->bell});
	$lab_menu->post( $x, $y );    # Show the popup menu
}

sub _show_stream_menu {
	my ( $self, $streams_list, $tree, $x, $y ) = @_;
	my $stream_menu = $streams_list->Menu( -tearoff => 0 );
	my @streams = $streams_list->curselection();
	if ( scalar @streams <= 0 ) {
		return;
	}
	my $stream_ID = $streams_list->get( $streams[0] );
	( my $id ) = split " ", $stream_ID;
	chop $id;
	my $add_obj = $Schedule->streams->get($id);

	# -------------------------------------------------------------
	# add appropriate object to object
	# -------------------------------------------------------------

	#	my $add_obj = $Schedule->streams->get($id);
	#	$obj->assign_stream($add_obj);

	my @courses = $Schedule->courses->list();

	$stream_menu->cascade( -label => "Add to Course" );
	my $tch2cor_Menu = $stream_menu->entrycget( "Add to Course", "-menu" );
	$tch2cor_Menu->configure( -tearoff => 0 );

	#('command', -label => $_->name, -command => sub { $streams_list->bell})
	foreach my $cor (@courses) {
		$tch2cor_Menu->cascade( -label => $cor->name );
		my $tchCorSec = $tch2cor_Menu->entrycget( $cor->name, "-menu" );
		$tchCorSec->configure( -tearoff => 0 );
		my @sections = $cor->sections;
		foreach my $sec (@sections) {
			$tchCorSec->add(
				'command',
				-label   => "$sec",
				-command => sub {
					$sec->assign_stream($add_obj);
					set_dirty();
					refresh_schedule($tree);
				}
			);
		}
	}

#$stream_menu->add('command', -label => $stream_ID, -command => sub { $streams_list->bell});
	$stream_menu->post( $x, $y );    # Show the popup menu
}

# =================================================================
# create all the drag'n'drop stuff
# =================================================================
sub _create_drag_drop_objs {
	my $trash_label   = shift;
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
		-postdropcommand => [ \&empty_trash, $trash_label ],
	);

	$teachers_list->DropSite(
		-droptypes    => [qw/Local/],
		-dropcommand  => [ \&_drop_on_trash, $trash_label, $tree ],
		-entercommand => [ \&_enter_trash, $trash_label ],
	);

	$labs_list->DragDrop(
		-event     => '<B1-Motion>',
		-sitetypes => [qw/Local/],
		-startcommand =>
		  [ \&_teacher_lab_start_drag, $labs_list, $tree, 'Lab' ],
	);

	$labs_list->DropSite(
		-droptypes    => [qw/Local/],
		-dropcommand  => [ \&_drop_on_trash, $trash_label, $tree ],
		-entercommand => [ \&_enter_trash, $trash_label ],
	);

	$streams_list->DragDrop(
		-event     => '<B1-Motion>',
		-sitetypes => [qw/Local/],
		-startcommand =>
		  [ \&_teacher_lab_start_drag, $streams_list, $tree, 'Stream' ],
	);

	$streams_list->DropSite(
		-droptypes    => [qw/Local/],
		-dropcommand  => [ \&_drop_on_trash, $trash_label, $tree ],
		-entercommand => [ \&_enter_trash, $trash_label ],
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
		-event     => '<B1-Motion>',
		-sitetypes => [qw/Local/],
		-startcommand =>
		  [ \&_course_tree_start_start_drag, $tree, $trash_label ],
	);

	$trash_label->DropSite(
		-droptypes    => [qw/Local/],
		-dropcommand  => [ \&_drop_on_trash, $trash_label, $tree ],
		-entercommand => [ \&_enter_trash, $trash_label ],
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
		if ($Trash1_photo) {
			$trash_label->configure( -image => $Trash1_photo );
		}
		else {
			$trash_label->configure(
				-bg => $Colours->{WorkspaceColour},
				-fg => $Colours->{WindowForeground},
			);
		}

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

		my $trash_label = shift;
		my @x           = $Drag_source->cget('-relief');

		if ($dropped) {
			$toggle = 0;
			if ($Trash1_photo) {
				$trash_label->configure( -image => $Trash1_photo );
			}
			else {
				$trash_label->configure(
					-bg => $Colours->{WorkspaceColour},
					-fg => $Colours->{WindowForeground},
				);
			}
			return;
		}
		if ( $x[0] eq 'flat' ) {
			if ($Trash1_photo) {
				$trash_label->configure( -image => $Trash1_photo );
			}
			else {
				$trash_label->configure(
					-bg => $Colours->{WorkspaceColour},
					-fg => $Colours->{WindowForeground},
				);
			}
		}
		else {
			if ($Trash2_photo) {
				$trash_label->configure( -image => $Trash2_photo );
			}
			else {
				$trash_label->configure(
					-fg => $Colours->{WorkspaceColour},
					-bg => $Colours->{WindowForeground}
				);
			}

		}
		$trash_label->toplevel->update;

		return;
	}

	# =================================================================
	# dropped item on trash can
	# =================================================================
	sub _drop_on_trash {
		my $trash_label = shift;
		my $tree        = shift;

		# validate that we have data to work with
		unless ($Dragged_from) {
			empty_trash($trash_label);
			return;
		}

		unless ($Dragged_from) {
			empty_trash($trash_label);
			return;
		}
		my $input = $tree->selectionGet();

		unless ($input) {
			empty_trash($trash_label);
			return;
		}

		# get info about dropped object
		$input = ( ref $input ) ? $input->[0] : $input;
		my $obj = $tree->infoData($input)->{-obj};

		# get parent widget
		my $parent = $tree->info( 'parent', $input );
		unless ($parent) {
			empty_trash($trash_label);
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
		empty_trash($trash_label);
		$tree->autosetmode();
		$Dragged_from = '';
		set_dirty();
	}

	sub empty_trash {
		my $trash_label = shift;
		$dropped = 1;
		if ($Trash1_photo) {
			$trash_label->configure( -image => $Trash1_photo );
		}
		else {
			$trash_label->configure(
				-bg => $Colours->{WorkspaceColour},
				-fg => $Colours->{WindowForeground},
			);
		}
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
		_edit_course2( $frame, $tree, $obj, $path );
	}
	elsif ( $obj->isa('Section') ) {
		_edit_section2( $frame, $tree, $obj, $path );
	}
	elsif ( $obj->isa('Block') ) {
		_edit_block2( $frame, $tree, $obj, $path );
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
			_edit_course2( $frame, $tree, $obj, $input );
		}
		elsif ( $obj->isa('Section') ) {
			_edit_section2( $frame, $tree, $obj, $input );
		}
		elsif ( $obj->isa('Block') ) {
			_edit_block2( $frame, $tree, $obj, $input );
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

sub _edit_course2 {
	my $frame = shift;
	my $tree  = shift;
	my $obj   = shift;
	my $path  = shift;

	my $change = 0;

	#-----------------------------
	# Create Menu Values
	#-----------------------------

	my $cNum = $obj->number;
	my $desc = $obj->name;

	my $startNum  = $cNum;
	my $startDesc = $desc;

	my @sections = $obj->sections;
	my $curSec   = "";

	my %sectionName;
	foreach my $i (@sections) {
		$sectionName{ $i->id } = "$i";
	}

	my @teachers = $Schedule->teachers->list;
	my $curTeach = "";

	my %teacherName;
	foreach my $i (@teachers) {
		$teacherName{ $i->id } = $i->firstname . " " . $i->lastname;
	}

	my @teachersO = $obj->teachers;
	my $curTeachO = "";
	my %teacherNameO;
	foreach my $i (@teachersO) {
		$teacherNameO{ $i->id } = $i->firstname . " " . $i->lastname;
	}

	my @streams   = $Schedule->streams->list;
	my $curStream = "";
	my %streamName;
	foreach my $i (@streams) {
		$streamName{ $i->id } = $i->print_description2;
	}

	my @streamsO   = $obj->streams;
	my $curStreamO = "";
	my %streamNameO;
	foreach my $i (@streamsO) {
		$streamNameO{ $i->id } = $i->print_description2;
	}

	#---------------------------------------------------
	# Creating Frames and defining widget variable names
	#---------------------------------------------------
	my $edit_dialog = $frame->DialogBox(
		-title   => "Edit " . $obj->name,
		-buttons => [ 'Close', 'Delete' ],

		#-bg=>'pink',
	);
	my $top   = $edit_dialog->Subwidget("top");
	my $close = $edit_dialog->Subwidget("B_Close");

	#my $frame1  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame1A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame1B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame2  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame2B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame2C = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame3  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame3A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame3B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame4  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame4A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame4B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );

	my $secDrop;
	my $secText;
	my $secAdd;
	my $secAdd2;
	my $secRem;
	my $secEdit;
	my $teachDropO;
	my $teachTextO;
	my $teachDrop;
	my $teachText;
	my $teachAdd;
	my $teachRem;
	my $streamDropO;
	my $streamTextO;
	my $streamDrop;
	my $streamText;
	my $streamAdd;
	my $streamRem;

	my $sectionMessage;
	my $teachMessage;
	my $streamMessage;

	my $pad = 40;

	#-----------------------------------------
	#Course number and name entry entry
	#-----------------------------------------

	my $courseNumberEntry;
	my $courseMessage;
	$courseNumberEntry = $edit_dialog->Entry(
		-textvariable    => \$cNum,
		-validate        => 'key',
		-validatecommand => [
			\&_unique_number,    $startNum, $close,
			\$courseNumberEntry, \$courseMessage
		]
	);

	$top->Label( -text => "Course Number", -anchor => 'w' )
	  ->grid( $courseNumberEntry, '-', '-', -sticky => "nsew" );

	$top->Label( -text => "Course Name", -anchor => 'w' )
	  ->grid( $edit_dialog->Entry( -textvariable => \$desc, ),
		'-', '-', -sticky => "nsew" );

	$courseMessage =
	  $top->Label( -text => "" )->grid( -columnspan => 4, -sticky => "nsew" );

	#-----------------------------------------
	# Section Add/Remove/Edit
	#-----------------------------------------
	$secDrop = $top->JBrowseEntry(
		-variable => \$curSec,
		-state    => 'readonly',
		-choices  => \%sectionName,
		-width    => 12
	)->grid( -row => 3, -column => 1, -ipadx => $pad, -sticky => "nsew" );
	my $secDropEntry = $secDrop->Subwidget("entry");
	$secDropEntry->configure( -disabledbackground => "white" );
	$secDropEntry->configure( -disabledforeground => "black" );

	$secAdd = $top->Button(
		-text    => "Advanced Add Section",
		-command => sub {
			my $sectionNum = $obj->get_new_number;
			my $section = Section->new( -number => $sectionNum, -hours => 0 );
			$obj->add_section($section);
			refresh_course( $tree, $obj, $path, 1 );

			my $answer = _edit_section2( $top, $tree, $section,
				$path . "/Section" . $section->id );

			$sectionName{ $section->id } = "$section" if $answer != 2;
			$secDrop->configure( -choices => \%sectionName );
			$curSec = "$section" if $answer != 2;
			$sectionMessage->configure( -text => "Section Added" )
			  if $answer != 2;

			$sectionMessage->configure( -text => "Canceled" ) if $answer == 2;
			$curSec = "" if $answer == 2;
			$change = 1;
			$top->bell;
			$secDrop->update;
			$sectionMessage->update;
		}
	)->grid( -row => 3, -column => 3, -sticky => "nsew" );

	$secAdd2 = $top->Button(
		-text    => "Add Section(s)",
		-command => sub {
			my $answer = _add_section( $top, $tree, $obj, $path );
			$answer = "Cancel" unless $answer;
			if ( $answer ne 'Cancel' ) {

				my @sections2 = $obj->sections;

				my %sectionName2;
				foreach my $i (@sections2) {
					$sectionName2{ $i->id } = "$i";
				}

				@sections    = @sections2;
				%sectionName = %sectionName2;

				$secDrop->configure( -choices => \%sectionName );
				$sectionMessage->configure( -text => "Section(s) Added" );
				$change = 1;
				$top->bell;
				$secDrop->update;
				$sectionMessage->update;

				#refresh_course($tree,$obj,$path,1);
			}
			else {
				$sectionMessage->configure( -text => "" );
				$sectionMessage->update;
			}
		}
	)->grid( -row => 3, -column => 2, -sticky => "nsew" );

	$secText = $top->Label( -text => "Sections:", -anchor => 'w' )
	  ->grid( -row => 3, -column => 0, -sticky => "nsew" );

	$secRem = $top->Button(
		-text    => "Remove Section",
		-command => sub {
			if ( $curSec ne "" ) {
				my %rHash  = reverse %sectionName;
				my $id     = $rHash{$curSec};
				my $secRem = $obj->get_section_by_id($id);
				$obj->remove_section($secRem);
				delete $sectionName{$id};
				$curSec = "";

				$secDrop->configure( -choices => \%sectionName );
				$sectionMessage->configure( -text => "Section Removed" );
				$change = 1;
				$top->bell;
				$secDrop->update;
				$sectionMessage->update;
				refresh_course( $tree, $obj, $path, 1 );
			}
		}
	);
	$secEdit = $top->Button(
		-text    => "Edit Section",
		-command => sub {
			if ( $curSec ne "" ) {
				my %rHash   = reverse %sectionName;
				my $id      = $rHash{$curSec};
				my $section = $obj->get_section_by_id($id);

				my $answer = _edit_section2( $top, $tree, $section,
					$path . "/Section" . $section->id );

				if ($answer) {
					my @teachers2 = $obj->teachers;

					my %teacherName2;
					foreach my $i (@teachers2) {
						$teacherName2{ $i->id } =
						  $i->firstname . " " . $i->lastname;
					}

					@teachersO    = @teachers2;
					%teacherNameO = %teacherName2;

					my @sections2 = $obj->sections;

					my %sectionName2;
					foreach my $i (@sections2) {
						$sectionName2{ $i->id } = "$i";
					}

					@sections    = @sections2;
					%sectionName = %sectionName2;

					my @streams2 = $obj->streams;

					my %streamName2;
					foreach my $i (@streams2) {
						$streamName2{ $i->id } = "$i";
					}

					@streamsO    = @streams2;
					%streamNameO = %streamName2;

					$teachDropO->configure( -choices => \%teacherNameO );
					$streamDropO->configure( -choices => \%streamNameO );
					$secDrop->configure( -choices => \%sectionName );
					$curSec = "$section";

					$sectionMessage->configure( -text => "Section Edited" )
					  if $answer == 1;
					$sectionMessage->configure( -text => "Section Removed" )
					  if $answer == 2;
					$curSec = "" if $answer == 2;

					if ( $answer == 2 ) {
						delete $sectionName{$id};
						$secDrop->configure( -choices => \%sectionName );
						$secDrop->update;
					}

					$change = 1;
					$top->bell;
					$streamDropO->update;
					$teachDropO->update;
					$sectionMessage->update;
				}
				else {
					$sectionMessage->configure( -text => "" );
					$sectionMessage->update;
				}
			}
		}
	);

	$sectionMessage = $top->Label( -text => "" )
	  ->grid( '-', $secRem, $secEdit, -sticky => "nsew" );

	$top->Label( -text => "" )->grid( -columnspan => 4, -sticky => "nsew" );

	#--------------------------------------------------------
	# Teacher Add/Remove
	#--------------------------------------------------------
	$teachDrop = $top->JBrowseEntry(
		-variable => \$curTeach,
		-state    => 'readonly',
		-choices  => \%teacherName,
		-width    => 12
	);

	my $teachDropEntry = $teachDrop->Subwidget("entry");
	$teachDropEntry->configure( -disabledbackground => "white" );
	$teachDropEntry->configure( -disabledforeground => "black" );

	$teachAdd = $top->Button(
		-text    => "Add To All Sections",
		-command => sub {
			if ( $curTeach ne "" ) {
				my %rHash    = reverse %teacherName;
				my $id       = $rHash{$curTeach};
				my $teachAdd = $Schedule->teachers->get($id);
				$obj->assign_teacher($teachAdd);
				$teacherNameO{$id} =
				  $teachAdd->firstname . " " . $teachAdd->lastname;
				$curTeach = "";
				$teachDropO->configure( -choices => \%teacherNameO );
				$teachDropO->update;
				$teachMessage->configure( -text => "Teacher Added" );
				$teachMessage->update;
				$teachMessage->bell;
				refresh_course( $tree, $obj, $path, 1 );
				$change = 1;
			}
		}
	);

	$teachText = $top->Label( -text => "Add Teacher: ", -anchor => 'w' )
	  ->grid( $teachDrop, '-', $teachAdd, -sticky => "nsew" );

	$teachDropO = $top->JBrowseEntry(
		-variable => \$curTeachO,
		-state    => 'readonly',
		-choices  => \%teacherNameO,
		-width    => 12
	);

	my $teachDropOEntry = $teachDropO->Subwidget("entry");
	$teachDropOEntry->configure( -disabledbackground => "white" );
	$teachDropOEntry->configure( -disabledforeground => "black" );

	$teachRem = $top->Button(
		-text    => "Remove From All Sections",
		-command => sub {
			if ( $curTeachO ne "" ) {
				my %rHash    = reverse %teacherNameO;
				my $id       = $rHash{$curTeachO};
				my $teachRem = $Schedule->teachers->get($id);
				$obj->remove_teacher($teachRem);
				$curTeachO = "";
				delete $teacherNameO{$id};
				$teachDropO->configure( -choices => \%teacherNameO );
				$teachDropO->update;
				$teachMessage->configure( -text => "Teacher Removed" );
				$teachMessage->bell;
				$teachMessage->update;
				$change = 1;
				refresh_course( $tree, $obj, $path, 1 );
			}
		}
	);

	$teachTextO =
	  $top->Label( -text => "Remove Teacher: ", -anchor => 'w' )
	  ->grid( $teachDropO, '-', $teachRem, -sticky => "nsew" );

	$teachMessage = $top->Label( -text => "" )->grid( -columnspan => 4 );

	#--------------------------------------------------------
	# Stream Add/Remove
	#--------------------------------------------------------
	$streamDrop = $top->JBrowseEntry(
		-variable => \$curStream,
		-state    => 'readonly',
		-choices  => \%streamName,
		-width    => 12
	);

	my $streamDropEntry = $streamDrop->Subwidget("entry");
	$streamDropEntry->configure( -disabledbackground => "white" );
	$streamDropEntry->configure( -disabledforeground => "black" );

	$streamAdd = $top->Button(
		-text    => "Set To All Sections",
		-command => sub {
			if ( $curStream ne "" ) {
				my %rHash     = reverse %streamName;
				my $id        = $rHash{$curStream};
				my $streamAdd = $Schedule->streams->get($id);
				$obj->assign_stream($streamAdd);
				$streamNameO{$id} =
				  $streamAdd->number . ": " . $streamAdd->descr;
				$curStream = "";
				$streamDropO->configure( -choices => \%streamNameO );
				$streamDropO->update;
				$streamMessage->configure( -text => "Stream Added" );
				$streamMessage->update;
				$streamMessage->bell;
				refresh_schedule($tree);
				$change = 1;
			}
		}
	);

	$streamText = $top->Label( -text => "Stream Add: ", -anchor => 'w' )
	  ->grid( $streamDrop, '-', $streamAdd, -sticky => 'nsew' );

	$streamDropO = $top->JBrowseEntry(
		-variable => \$curStreamO,
		-state    => 'readonly',
		-choices  => \%streamNameO,
		-width    => 12
	);

	my $streamDropOEntry = $streamDropO->Subwidget("entry");
	$streamDropOEntry->configure( -disabledbackground => "white" );
	$streamDropOEntry->configure( -disabledforeground => "black" );

	$streamRem = $top->Button(
		-text    => "Remove From All Secitons",
		-command => sub {
			if ( $curStreamO ne "" ) {
				$change = 1;
				my %rHash     = reverse %streamNameO;
				my $id        = $rHash{$curStreamO};
				my $streamRem = $Schedule->streams->get($id);
				$obj->remove_stream($streamRem);
				delete $streamNameO{$id};
				$curStreamO = "";
				$streamDropO->configure( -choices => \%streamNameO );
				$streamDropO->update;
				$streamMessage->configure( -text => "Stream Removed" );
				$streamMessage->update;
				$streamMessage->bell;
				refresh_schedule($tree);
			}
		}
	);

	$streamTextO =
	  $top->Label( -text => "Stream Remove: ", -anchor => 'w' )
	  ->grid( $streamDropO, '-', $streamRem, -sticky => 'nsew' );

	$streamMessage =
	  $top->Label( -text => "", )->grid( -columnspan => 4, -sticky => 'n' );

	#$top->Label( -text => "" )->grid( -columnspan => 4 );

	my ( $columns, $rows ) = $top->gridSize();
	for ( my $i = 1 ; $i < $columns ; $i++ ) {
		$top->gridColumnconfigure( $i, -weight => 1 );
	}
	$top->gridRowconfigure( $rows - 1, -weight => 1 );

	my $answer = $edit_dialog->Show();
	$answer = "Close" unless $answer;

	if ( $answer eq 'Delete' ) {

		my $sure = $top->DialogBox(
			-title   => "Delete?",
			-buttons => [ 'Yes', 'NO' ]
		);

		$sure->Label( -text => "Are you Sure You\nWant To Delete?" )->pack;

		my $answer2 = $sure->Show();
		$answer2 = 'NO' unless $answer2;

		return _edit_course2( $frame, $tree, $obj, $path )
		  if ( $answer2 eq 'NO' );

		$Schedule->remove_course($obj);
		refresh_schedule($tree);
		return 2;
	}
	elsif ( $startDesc ne $desc || $startNum ne $cNum ) {
		$obj->name($desc);
		$obj->number($cNum);
		refresh_schedule($tree);
		set_dirty();
		return 1;
	}
	else {
		set_dirty() if $change;
		return $change;
	}

}

sub _edit_section2 {
	my $frame = shift;
	my $tree  = shift;
	my $obj   = shift;
	my $path  = shift;

	my $change = 0;

	#--------------------------------------------------------
	# Defining Menu Lists
	#--------------------------------------------------------
	my $objPar = $obj->course;
	my $parent = $tree->info( 'parent', $path );

	my $cNum = $obj->number;

	my $cName = $obj->name;
	my $oldName = $cName || "";

	my $curBlock = "";

	my @blocks = $obj->blocks;
	my %blockName;
	foreach my $i (@blocks) {
		$blockName{ $i->id } = $i->print_description2;
	}

	my @teachersN = $Schedule->teachers->list;
	my $curTeachN = "";

	my %teacherNameN;
	foreach my $i (@teachersN) {
		$teacherNameN{ $i->id } = $i->firstname . " " . $i->lastname;
	}

	my @teachersO = $obj->teachers;
	my $curTeachO = "";

	my %teacherNameO;
	foreach my $i (@teachersO) {
		$teacherNameO{ $i->id } = $i->firstname . " " . $i->lastname;
	}

	my @streamsN   = $Schedule->streams->list;
	my $curStreamN = "";
	my %streamNameN;
	foreach my $i (@streamsN) {
		$streamNameN{ $i->id } = $i->print_description2;
	}

	my @streamsO   = $obj->streams;
	my $curStreamO = "";
	my %streamNameO;
	foreach my $i (@streamsO) {
		$streamNameO{ $i->id } = $i->print_description2;
	}

	#--------------------------------------------------------
	# Defining Frames and widget names
	#--------------------------------------------------------

	my $edit_dialog = $frame->DialogBox(
		-title   => $obj->course->name . ": Section " . $obj->number,
		-buttons => [ 'Close', 'Delete' ]
	);

	my $top = $edit_dialog->Subwidget("top");

	#my $frame1  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame2  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame2B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame3  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame3A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame3B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame4  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame4A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame4B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );

	my $blockDrop;
	my $blockText;
	my $blockAdd;
	my $blockRem;
	my $blockEdit;
	my $blockMessage;
	my $teachDropN;
	my $teachTextN;
	my $teachDropO;
	my $teachTextO;
	my $teachAdd;
	my $teachRem;
	my $teachMessage;
	my $streamDropO;
	my $streamTextO;
	my $streamDropN;
	my $streamTextN;
	my $streamAdd;
	my $streamRem;
	my $streamMessage;

	my $pad = 40;

	#--------------------------------------------------------
	# Block Add/Remove/Edit
	#--------------------------------------------------------

	$top->Label( -text => "Section Name", -anchor => 'w' )
	  ->grid( $top->Entry( -textvariable => \$cName ),
		'-', '-', -sticky => "nsew" );

	$top->Label( -text => "" )->grid( -columnspan => 4 );

	$blockDrop = $top->JBrowseEntry(
		-variable => \$curBlock,
		-state    => 'readonly',
		-choices  => \%blockName,
		-width    => 12
	)->grid( -column => 1, -row => 2, -sticky => 'nsew', -ipadx => $pad );
	my $blockDropEntry = $blockDrop->Subwidget("entry");
	$blockDropEntry->configure( -disabledbackground => "white" );
	$blockDropEntry->configure( -disabledforeground => "black" );

	$blockText = $top->Label(
		-text   => "Block: ",
		-anchor => 'w'
	)->grid( -column => 0, -row => 2, -sticky => 'nsew' );

	$blockAdd = $top->Button(
		-text    => "Add Block(s)",
		-command => sub {
			my $answer = _add_block( $top, $tree, $obj, $path );
			$answer = "Cancel" unless $answer;
			if ( $answer ne "Cancel" ) {
				$blockMessage->configure( -text => "Block(s) Added" );
				$top->bell;
				$curBlock = "";
				my @blocks2 = $obj->blocks;
				my %blockName2;
				foreach my $i (@blocks2) {
					$blockName2{ $i->id } = $i->print_description2;
				}
				@blocks    = @blocks2;
				%blockName = %blockName2;
				$blockDrop->configure( -choices => \%blockName );
				$blockDrop->update;
				$change = 1;
			}
			else {
				$blockMessage->configure( -text => "" );
			}
		}
	)->grid( -column => 2, -row => 3, -sticky => 'nsew', -columnspan => 2 );

	$blockRem = $top->Button(
		-text    => "Remove Block",
		-command => sub {
			if ( $curBlock ne "" ) {
				my %rHash    = reverse %blockName;
				my $id       = $rHash{$curBlock};
				my $blockRem = $obj->block($id);
				$obj->remove_block($blockRem);
				delete $blockName{$id};
				$curBlock = "";
				$blockDrop->configure( -choices => \%blockName );
				$blockDrop->update;
				$blockDrop->bell;
				$blockMessage->configure( -text => "Block Removed" );
				refresh_section( $tree, $obj, $path, 1 );
				set_dirty();
				$change = 1;
			}
		}
	)->grid( -column => 3, -row => 2, -sticky => 'nsew' );

	$blockEdit = $top->Button(
		-text    => "Edit Block",
		-command => sub {
			if ( $curBlock ne "" ) {
				my %rHash     = reverse %blockName;
				my $id        = $rHash{$curBlock};
				my $blockEdit = $obj->block($id);
				my $answer    = _edit_block2( $top, $tree, $blockEdit,
					$path . "/Block" . $blockEdit->id );
				if ($answer) {
					$blockMessage->configure( -text => "Block Changed" )
					  if $answer == 1;
					$blockMessage->configure( -text => "Block Removed" )
					  if $answer == 2;
					$curBlock = "" if $answer == 2;
					$top->bell;
					my @teach2 = $obj->teachers;
					my %teachName2;
					foreach my $i (@teach2) {
						$teachName2{ $i->id } =
						  $i->firstname . " " . $i->lastname;
					}
					@teachersO    = @teach2;
					%teacherNameO = %teachName2;
					$teachDropO->configure( -choices => \%teacherNameO );
					$teachDropO->update;
					if ( $answer == 2 ) {
						delete $blockName{$id};
						$blockDrop->configure( -choices => \%blockName );
						$blockDrop->update;
					}
					$change = 1;
				}
				else {
					$blockMessage->configure( -text => "" );
				}
			}
		}
	)->grid( -column => 2, -row => 2, -sticky => 'nsew' );

	$blockMessage = $top->Label( -text => "" )
	  ->grid( -column => 1, -row => 3, -sticky => 'nsew' );

	$top->Label( -text => "" )->grid( -columnspan => 4 );

	#--------------------------------------------------------
	# Teacher Add/REmove
	#--------------------------------------------------------

	$teachDropN = $top->JBrowseEntry(
		-variable => \$curTeachN,
		-state    => 'readonly',
		-choices  => \%teacherNameN,
		-width    => 12
	);

	my $teachDropNEntry = $teachDropN->Subwidget("entry");
	$teachDropNEntry->configure( -disabledbackground => "white" );
	$teachDropNEntry->configure( -disabledforeground => "black" );

	$teachDropO = $top->JBrowseEntry(
		-variable => \$curTeachO,
		-state    => 'readonly',
		-choices  => \%teacherNameO,
		-width    => 12
	);

	my $teachDropOEntry = $teachDropO->Subwidget("entry");
	$teachDropOEntry->configure( -disabledbackground => "white" );
	$teachDropOEntry->configure( -disabledforeground => "black" );

	$teachAdd = $top->Button(
		-text    => "Set to all blocks",
		-command => sub {
			if ( $curTeachN ne "" ) {
				my %rHash    = reverse %teacherNameN;
				my $id       = $rHash{$curTeachN};
				my $teachAdd = $Schedule->teachers->get($id);
				$obj->assign_teacher($teachAdd);
				$teacherNameO{$id} =
				  $teachAdd->firstname . " " . $teachAdd->lastname;
				$curTeachN = "";
				$teachDropO->configure( -choices => \%teacherNameO );
				$teachDropO->update;
				$teachMessage->configure( -text => "Teacher Added" );
				$teachMessage->update;
				$teachMessage->bell;
				refresh_section( $tree, $obj, $path, 1 );
				$change = 1;
			}
		}
	);

	$teachTextN = $top->Label(
		-text   => "Add Teacher: ",
		-anchor => 'w'
	)->grid( $teachDropN, '-', $teachAdd, -sticky => 'nsew' );

	$teachRem = $top->Button(
		-text    => "Remove from all blocks",
		-command => sub {
			if ( $curTeachO ne "" ) {
				my %rHash    = reverse %teacherNameO;
				my $id       = $rHash{$curTeachO};
				my $teachRem = $Schedule->teachers->get($id);
				$obj->remove_teacher($teachRem);
				$curTeachO = "";
				delete $teacherNameO{$id};
				$teachDropO->configure( -choices => \%teacherNameO );
				$teachDropO->update;
				$teachMessage->configure( -text => "Teacher Removed" );
				$teachMessage->bell;
				$teachMessage->update;
				$change = 1;
				refresh_section( $tree, $obj, $path, 1 );
			}
		}
	);

	$teachTextO = $top->Label(
		-text   => "Remove Teacher: ",
		-anchor => 'w'
	)->grid( $teachDropO, '-', $teachRem, -sticky => 'nsew' );

	$teachMessage = $top->Label( -text => "" )->grid( -columnspan => 4 );

	#--------------------------------------------------------
	# Stream Add/REmove
	#--------------------------------------------------------

	$streamDropN = $top->JBrowseEntry(
		-variable => \$curStreamN,
		-state    => 'readonly',
		-choices  => \%streamNameN,
		-width    => 12
	);

	my $streamDropNEntry = $streamDropN->Subwidget("entry");
	$streamDropNEntry->configure( -disabledbackground => "white" );
	$streamDropNEntry->configure( -disabledforeground => "black" );

	$streamDropO = $top->JBrowseEntry(
		-variable => \$curStreamO,
		-state    => 'readonly',
		-choices  => \%streamNameO,
		-width    => 12
	);

	my $streamDropOEntry = $streamDropO->Subwidget("entry");
	$streamDropOEntry->configure( -disabledbackground => "white" );
	$streamDropOEntry->configure( -disabledforeground => "black" );

	$streamAdd = $top->Button(
		-text    => "Set Stream",
		-command => sub {
			if ( $curStreamN ne "" ) {
				$change = 1;
				my %rHash     = reverse %streamNameN;
				my $id        = $rHash{$curStreamN};
				my $streamAdd = $Schedule->streams->get($id);
				$obj->assign_stream($streamAdd);
				$streamNameO{$id} =
				  $streamAdd->number . ": " . $streamAdd->descr;
				$curStreamN = "";
				$streamDropO->configure( -choices => \%streamNameO );
				$streamDropO->update;
				$streamMessage->configure( -text => "Stream Set" );
				$streamMessage->update;
				$streamMessage->bell;
				refresh_schedule($tree);
			}
		}
	);

	$streamTextN = $top->Label(
		-text   => "Add Stream: ",
		-anchor => 'w'
	)->grid( $streamDropN, '-', $streamAdd, -sticky => 'nsew' );

	$streamRem = $top->Button(
		-text    => "Remove Stream",
		-command => sub {
			if ( $curStreamO ne "" ) {
				$change = 1;
				my %rHash     = reverse %streamNameO;
				my $id        = $rHash{$curStreamO};
				my $streamRem = $Schedule->streams->get($id);
				$obj->remove_stream($streamRem);
				delete $streamNameO{$id};
				$curStreamO = "";
				$streamDropO->configure( -choices => \%streamNameO );
				$streamDropO->update;
				$streamMessage->configure( -text => "Stream Removed" );
				$streamMessage->update;
				$streamMessage->bell;
				refresh_schedule($tree);
			}
		}
	);

	$streamTextO = $top->Label(
		-text   => "Remove Stream: ",
		-anchor => 'w'
	)->grid( $streamDropO, '-', $streamRem, -sticky => 'nsew' );

	$streamMessage =
	  $top->Label( -text => "" )->grid( -columnspan => 4, -sticky => 'n' );

	my ( $columns, $rows ) = $top->gridSize();
	for ( my $i = 1 ; $i < $columns ; $i++ ) {
		$top->gridColumnconfigure( $i, -weight => 1 );
	}
	$top->gridRowconfigure( $rows - 1, -weight => 1 );

	my $answer = $edit_dialog->Show();
	$answer = "NO" unless $answer;

	if ( $answer eq 'Delete' ) {

		my $sure = $frame->DialogBox(
			-title   => "Delete?",
			-buttons => [ 'Yes', 'NO' ]
		);

		$sure->Label( -text => "Are you Sure You\nWant To Delete?" )->pack;

		my $answer2 = $sure->Show();

		return _edit_section2( $frame, $tree, $obj, $path )
		  if ( $answer2 eq 'NO' );

		$objPar->remove_section($obj);
		refresh_course( $tree, $objPar, $parent, 1 );
		set_dirty();
		return 2;
	}
	else {
		if ( $oldName ne $cName ) {
			$obj->name($cName);
			refresh_schedule($tree);
			set_dirty();
			return 1;
		}
		else {
			set_dirty() if $change;
			return $change;
		}
	}
}

sub _edit_block2 {
	my $frame = shift;
	my $tree  = shift;
	my $obj   = shift;
	my $path  = shift;

	my $change = 0;

	#--------------------------------------------------------
	# Defining list values
	#--------------------------------------------------------

	my $objPar = $obj->section;
	my $parent = $tree->info( 'parent', $path );

	my $dur    = $obj->duration;
	my $oldDur = $dur;

	my @teachersN = $Schedule->teachers->list;
	my $curTeachN;

	my %teacherNameN;
	foreach my $i (@teachersN) {
		$teacherNameN{ $i->id } = $i->firstname . " " . $i->lastname;
	}

	my @teachersO = $obj->teachers;
	my $curTeachO;

	my %teacherNameO;
	foreach my $i (@teachersO) {
		$teacherNameO{ $i->id } = $i->firstname . " " . $i->lastname;
	}

	my @labsN = $Schedule->labs->list;
	my $curLabN;
	my %labNameN;
	foreach my $i (@labsN) {
		$labNameN{ $i->id } = $i->number . ": " . $i->descr;
	}

	my @labsO = $obj->labs;
	my $curLabO;
	my %labNameO;
	foreach my $i (@labsO) {
		$labNameO{ $i->id } = $i->number . ": " . $i->descr;
	}

	#--------------------------------------------------------
	# Creating frames and widget names
	#--------------------------------------------------------
	my $edit_dialog = $frame->DialogBox(
		-title => 'Edit '
		  . $obj->section->course->name
		  . ": Section "
		  . $obj->section->number
		  . " -> Block "
		  . $obj->id,
		-buttons => [ 'Close', 'Delete' ]
	);

	my $top = $edit_dialog->Subwidget("top");

	#my $frame2  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame3  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame3A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame3B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame4  = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame4A = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );
	#my $frame4B = $edit_dialog->Frame( -height => 30, )->pack( -fill => 'x' );

	my $durIn;
	my $teachDropN;
	my $teachTextN;
	my $teachAdd;
	my $teachDropO;
	my $teachTextO;
	my $teachRem;

	my $teachMessage;

	my $labDropN;
	my $labTextN;
	my $labAdd;
	my $labDropO;
	my $labTextO;
	my $labRem;

	my $labMessage;

	#--------------------------------------------------------
	# Block Duration Entry
	#--------------------------------------------------------

	$durIn = $top->Entry(
		-textvariable    => \$dur,
		-validate        => 'key',
		-validatecommand => \&is_number,
		-invalidcommand  => sub { $frame->bell },
	);

	$top->Label(
		-text   => 'Block Duration: ',
		-anchor => 'w'
	)->grid( $durIn, '-', '-', -sticky => 'nsew' );

	$top->Label( -text => "" )->grid( -columnspan => 4 );

	#--------------------------------------------------------
	# Teacher Add/Remove
	#--------------------------------------------------------

	$teachDropN = $top->JBrowseEntry(
		-variable => \$curTeachN,
		-state    => 'readonly',
		-choices  => \%teacherNameN,
		-width    => 12
	);

	my $teachDropNEntry = $teachDropN->Subwidget("entry");
	$teachDropNEntry->configure( -disabledbackground => "white" );
	$teachDropNEntry->configure( -disabledforeground => "black" );

	$teachAdd = $top->Button(
		-text    => "Set Teacher",
		-command => sub {
			if ( $curTeachN ne "" ) {
				$change = 1;
				my %rHash    = reverse %teacherNameN;
				my $id       = $rHash{$curTeachN};
				my $teachAdd = $Schedule->teachers->get($id);
				$obj->assign_teacher($teachAdd);
				$teacherNameO{$id} =
				  $teachAdd->firstname . " " . $teachAdd->lastname;
				$curTeachN = "";
				$teachDropO->configure( -choices => \%teacherNameO );
				$teachDropO->update;
				$teachMessage->configure( -text => "Teacher Added" );
				$teachMessage->update;
				$teachMessage->bell;
				refresh_section( $tree, $objPar, $parent, 1 );
			}
		}
	);

	$teachTextN = $top->Label(
		-text   => 'Add Teacher',
		-anchor => 'w'
	)->grid( $teachDropN, '-', $teachAdd, -sticky => 'nsew' );

	$teachDropO = $top->JBrowseEntry(
		-variable => \$curTeachO,
		-state    => 'readonly',
		-choices  => \%teacherNameO,
		-width    => 12
	);

	my $teachDropOEntry = $teachDropO->Subwidget("entry");
	$teachDropOEntry->configure( -disabledbackground => "white" );
	$teachDropOEntry->configure( -disabledforeground => "black" );

	$teachRem = $top->Button(
		-text    => "Remove Teacher",
		-command => sub {
			if ( $curTeachO ne "" ) {
				$change = 1;
				my %rHash    = reverse %teacherNameO;
				my $id       = $rHash{$curTeachO};
				my $teachRem = $Schedule->teachers->get($id);
				$obj->remove_teacher($teachRem);
				$curTeachO = "";
				delete $teacherNameO{$id};
				$teachDropO->configure( -choices => \%teacherNameO );
				$teachDropO->update;
				$teachMessage->configure( -text => "Teacher Removed" );
				$teachMessage->bell;
				$teachMessage->update;
				refresh_section( $tree, $objPar, $parent, 1 );
			}
		}
	);

	$teachTextO = $top->Label(
		-text   => 'Remove Teacher',
		-anchor => 'w'
	)->grid( $teachDropO, '-', $teachRem, -sticky => 'nsew' );

	$teachMessage = $top->Label( -text => "" )->grid( -columnspan => 4 );

	#--------------------------------------------------------
	# Lab Add/Remove
	#--------------------------------------------------------

	$labDropN = $top->JBrowseEntry(
		-variable => \$curLabN,
		-state    => 'readonly',
		-choices  => \%labNameN,
		-width    => 12
	);

	my $labDropNEntry = $labDropN->Subwidget("entry");
	$labDropNEntry->configure( -disabledbackground => "white" );
	$labDropNEntry->configure( -disabledforeground => "black" );

	$labAdd = $top->Button(
		-text    => "Set Resource",
		-command => sub {
			if ( $curLabN ne "" ) {
				$change = 1;
				my %rHash  = reverse %labNameN;
				my $id     = $rHash{$curLabN};
				my $labAdd = $Schedule->labs->get($id);
				$obj->assign_lab($labAdd);
				$labNameO{$id} = $labAdd->number . ": " . $labAdd->descr;
				$curLabN = "";
				$labDropO->configure( -choices => \%labNameO );
				$labDropO->update;
				$labMessage->configure( -text => "Resource Set" );
				$labMessage->update;
				$labMessage->bell;
				refresh_section( $tree, $objPar, $parent, 1 );
				set_dirty();
			}
		}
	);

	$labTextN = $top->Label(
		-text   => 'Add Resource',
		-anchor => 'w'
	)->grid( $labDropN, '-', $labAdd, -sticky => 'nsew' );

	$labDropO = $top->JBrowseEntry(
		-variable => \$curLabO,
		-state    => 'readonly',
		-choices  => \%labNameO,
		-width    => 12
	);

	my $labDropOEntry = $labDropO->Subwidget("entry");
	$labDropOEntry->configure( -disabledbackground => "white" );
	$labDropOEntry->configure( -disabledforeground => "black" );

	$labRem = $top->Button(
		-text    => "Remove Resource",
		-command => sub {
			if ( $curLabO ne "" ) {
				$change = 1;
				my %rHash  = reverse %labNameO;
				my $id     = $rHash{$curLabO};
				my $labAdd = $Schedule->labs->get($id);
				$obj->remove_lab($labAdd);
				delete $labNameO{$id};
				$curLabO = "";
				$labDropO->configure( -choices => \%labNameO );
				$labDropO->update;
				$labMessage->configure( -text => "Resource Removed" );
				$labMessage->update;
				$labMessage->bell;
				refresh_section( $tree, $objPar, $parent, 1 );
			}
		}
	);

	$labTextO = $top->Label(
		-text   => 'Remove Resource',
		-anchor => 'w'
	)->grid( $labDropO, '-', $labRem, -sticky => 'nsew' );

	$labMessage =
	  $top->Label( -text => "" )->grid( -columnspan => 4, -sticky => 'n' );

	my ( $columns, $rows ) = $top->gridSize();
	for ( my $i = 1 ; $i < $columns ; $i++ ) {
		$top->gridColumnconfigure( $i, -weight => 1 );
	}
	$top->gridRowconfigure( $rows - 1, -weight => 1 );

	my $answer = $edit_dialog->Show();
	$answer = "Close" unless $answer;
	if ( $answer eq 'Close' ) {
		$obj->duration($dur);
	}
	elsif ( $answer eq 'Delete' ) {

		my $sure = $frame->DialogBox(
			-title   => "Delete?",
			-buttons => [ 'Yes', 'NO' ]
		);

		$sure->Label( -text => "Are you Sure You\nWant To Delete?" )->pack;

		my $answer2 = $sure->Show();

		return _edit_block2( $frame, $tree, $obj, $path )
		  if ( $answer2 eq 'NO' );

		$objPar->remove_block($obj);
		refresh_section( $tree, $objPar, $parent, 1 );
		set_dirty();
		return 2;
	}
	refresh_section( $tree, $objPar, $parent, 1 ) unless $dur == $oldDur;
	set_dirty() if $change || $dur != $oldDur;
	return $change || $dur != $oldDur;

}

#========================================================
# Add Block to section Dialog, return either Ok or Cancel
#========================================================
sub _add_block {
	my $frame = shift;
	my $tree  = shift;
	my $obj   = shift;
	my $input = shift;

	my $num;
	my @hrs;
	my $db1 = $frame->DialogBox(
		-title          => 'How Many Blocks',
		-buttons        => [ 'Ok', 'Cancel' ],
		-default_button => 'Ok',
	);

	$db1->add( 'Label', -text => "How Many Blocks? (MAX 10)" )->pack;
	$db1->add(
		'Entry',
		-textvariable    => \$num,
		-validate        => 'key',
		-validatecommand => \&is_integer,
		-invalidcommand  => sub { $frame->bell },
		-width           => 20,
	)->pack( -fill => 'x' );
	my $answer = $db1->Show();
	$answer = "Cancel" unless $answer;

	if ( $answer eq "Ok" && defined $num && $num ne "" && $num > 0 ) {
		$num = 10 if $num > 10;
		my $db2 = $frame->DialogBox(
			-title          => 'How Many Hours',
			-buttons        => [ 'Ok', 'Cancel' ],
			-default_button => 'Ok',
		);
		my $top = $db2->Subwidget("top");

		$top->Label( -text => "How Many Hours Per Block?" )
		  ->grid( -columnspan => 2 );
		foreach my $i ( 1 ... $num ) {
			push( @hrs, "" );
		}
		foreach my $i ( 1 ... $num ) {
			$top->Label( -text => "Block $i" )->grid(
				$top->Entry(
					-textvariable    => \$hrs[ $i - 1 ],
					-validate        => 'key',
					-validatecommand => \&is_number,
					-invalidcommand  => sub { $frame->bell },
				),
				-sticky => 'new'
			);
		}

		my ( $col, $row ) = $top->gridSize();
		for ( my $i = 1 ; $i < $col ; $i++ ) {
			$top->gridColumnconfigure( $i, -weight => 1 );
		}
		$top->gridRowconfigure( $row - 1, -weight => 1 );

		$answer = "";
		$answer = $db2->Show();
		$answer = "Cancel" unless $answer;

		if ( $answer eq "Ok" ) {
			foreach my $i ( 1 ... $num ) {
				if ( $hrs[ $i - 1 ] ne "" && $hrs[ $i - 1 ] > 0 ) {
					my $bl = Block->new(
						-duration => $hrs[ $i - 1 ],
						-number   => $obj->get_new_number
					);
					$obj->add_block($bl);
				}
			}
			refresh_section( $tree, $obj, $input, 1 );
			set_dirty();
		}
	}
	return $answer;
}

#==========================================================
# Add Sections to a Course and add blocks to those sections.
# Return either Ok or Cancel
#==========================================================
sub _add_section {
	my $frame = shift;
	my $tree  = shift;
	my $obj   = shift;
	my $input = shift;

	my $numS;
	my $numB;
	my @hrs;
	my @blocks;
	my @names;

	my $db0 = $frame->DialogBox(
		-title          => 'How Many Sections',
		-buttons        => [ 'Ok', 'Cancel' ],
		-default_button => 'Ok',

		#-height => 300,
		#-width => 500
	);

	$db0->add( 'Label', -text => "How Many Sections? (MAX 10)" )->pack;
	$db0->add(
		'Entry',
		-textvariable    => \$numS,
		-validate        => 'key',
		-validatecommand => \&is_integer,
		-invalidcommand  => sub { $frame->bell },
	)->pack( -fill => 'x' );
	my $answer = $db0->Show();
	$answer = "Cancel" unless $answer;

	if ( $answer eq 'Ok' && defined $numS && $numS ne "" && $numS > 0 ) {
		$numS = 10 if $numS > 10;

		my $db3 = $frame->DialogBox(
			-title          => 'Name The Sections',
			-buttons        => [ 'Ok', 'Cancel' ],
			-default_button => 'Ok',
		);

		my $top = $db3->Subwidget("top");

		$top->Label( -text => "Name the Sections (OPTIONAL)" )
		  ->grid( -columnspan => 2 );
		foreach my $i ( 1 ... $numS ) {
			push( @names, "" );
		}
		foreach my $i ( 1 ... $numS ) {
			$top->Label( -text => "Section $i" )->grid(
				$top->Entry(
					-textvariable => \$names[ $i - 1 ]
				),
				-sticky => 'new'
			);
		}

		$answer = $db3->Show();
		$answer = "Cancel" unless $answer;

		if ( $answer eq 'Ok' ) {
			my $db1 = $frame->DialogBox(
				-title          => 'How Many Blocks',
				-buttons        => [ 'Ok', 'Cancel' ],
				-default_button => 'Ok',

				#-height => 300,
				#-width => 500
			);

			$db1->add( 'Label', -text => "How Many Blocks? (MAX 10)" )->pack;
			$db1->add(
				'Entry',
				-textvariable    => \$numB,
				-validate        => 'key',
				-validatecommand => \&is_integer,
				-invalidcommand  => sub { $frame->bell },
				-width           => 20,
			)->pack( -fill => 'x' );
			$answer = "";
			$answer = $db1->Show();
			$answer = 'Cancel' unless $answer;

			if ( $answer eq "Ok" && defined $numB && $numB ne "" && $numB >= 0 )
			{
				$numB = 10 if $numB > 10;

				if ($numB) {
					my $db2 = $frame->DialogBox(
						-title          => 'How Many Hours',
						-buttons        => [ 'Ok', 'Cancel' ],
						-default_button => 'Ok',

						#-height => 300,
						#-width => 500
					);

					my $top = $db2->Subwidget("top");

					$top->Label( -text => "How Many Hours Per Block?" )
					  ->grid( -columnspan => 2 );
					foreach my $i ( 1 ... $numB ) {
						push( @hrs, "" );
					}
					foreach my $i ( 1 ... $numB ) {
						$top->Label( -text => "Block $i" )->grid(
							$top->Entry(
								-textvariable    => \$hrs[ $i - 1 ],
								-validate        => 'key',
								-validatecommand => \&is_number,
								-invalidcommand  => sub { $frame->bell },
							),
							-sticky => 'new'
						);
					}

					my ( $col, $row ) = $top->gridSize();
					for ( my $i = 1 ; $i < $col ; $i++ ) {
						$top->gridColumnconfigure( $i, -weight => 1 );
					}
					$top->gridRowconfigure( $row - 1, -weight => 1 );

					$answer = "";
					$answer = $db2->Show();
					$answer = "Cancel" unless $answer;
				}

				if ( $answer eq "Ok" ) {

					foreach my $j ( 1 ... $numS ) {
						my $sectionNum = $obj->get_new_number;
						my $section    = Section->new(
							-number => $sectionNum,
							-hours  => 0,
							-name   => $names[ $j - 1 ]
						);
						$obj->add_section($section);
						foreach my $i ( 1 ... $numB ) {
							if ( $hrs[ $i - 1 ] ne "" && $hrs[ $i - 1 ] > 0 ) {
								my $bl =
								  Block->new(
									-number => $section->get_new_number );
								$bl->duration( $hrs[ $i - 1 ] );
								$section->add_block($bl);
							}
						}
					}
					refresh_course( $tree, $obj, $input, 1 );
					set_dirty();
				}
			}
		}
	}
	return $answer;
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
			_edit_course2( $tree, $tree, $obj, "Schedule/Course" . $obj->id );
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

Copyright (c) 2016, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;

