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
     print "$image_dir/small_trash.gif\n";
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
    # always start from scratch (- means we are always up to date)
    # ----------------------------------------------------------------
    foreach my $sl ( $frame->packSlaves ) {
        $sl->destroy;
    }

    $frame->Label( -text => 'Drag teachers/labs to sections/blocks' )->pack;
    $frame->Label(
          -text => 'Drag courses/sections/blocks/labs/teachers to garbage can' )
      ->pack;
    $frame->Label( -text => 'Double-click course to edit' )->pack;

    # ----------------------------------------------------------------
    # make Schedule tree
    # ----------------------------------------------------------------
    my $tree;
    my $treescrolled = $frame->Scrolled(
                                'DynamicTree',
                                -scrollbars => 'osoe',
                                -separator  => '/',
                                -command => [ \&_double_click, $frame, \$tree ],
    )->pack( -expand => 1, -fill => 'both', -side => 'left' );
    $tree = $treescrolled->Subwidget('dynamictree');
    $tree->bind( '<Key-Return>', [ \&_return, $frame ] );

    # ----------------------------------------------------------------
    # make panel for modifying Schedule
    # ----------------------------------------------------------------
    my ( $labs_list, $streams_list, $teachers_list, $trash_label ) =
      create_panel_for_modifying( $Trash1_photo, $tree, $frame );

	#-------------------------------
	# Alex Code
	# Right click menu binding
	#-------------------------------
	_create_right_click_menu( $treescrolled,  $teachers_list, $labs_list,
                            $streams_list, $tree );


    # ----------------------------------------------------------------
    # drag and drop bindings
    # ----------------------------------------------------------------
    _create_drag_drop_objs( $trash_label,  $teachers_list, $labs_list,
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
    my $frame        = shift;

    my $panel =
      $frame->Frame()->pack( -expand => 1, -fill => 'both', -side => 'right' );

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
                                          -width  => 68,
                                          -height => 68
                                        )->pack( -side => 'left' );
    }
    else {
        $trash_label = $button_row->Label(
                                          -text=>'Trash',
                                          -width  => 10,
                                          -height => 1,
                                           -bg=>$Colours->{WorkspaceColour},
                -fg=>$Colours->{WindowForeground},
                                        )->pack( -side => 'left' );
    }
    $trash_label->bind("<Leave>",[\&empty_trash,$trash_label]);

    # ---------------------------------------------------------------
    # buttons
    # ---------------------------------------------------------------
    my $new_classNew = $button_row->Button(
                                    -text    => "New Course",
                                    -width   => 12,
                                    -command => [ \&edit_course, $frame, $tree , "New"]
    )->pack( -side => 'left' );
    
    my $new_classEdit = $button_row->Button(
                                    -text    => "Modify Course",
                                    -width   => 12,
                                    -command => [ \&edit_course, $frame, $tree , "Edit" ]
    )->pack( -side => 'left' );

    # ---------------------------------------------------------------
    # teacher and lab and stream list
    # ---------------------------------------------------------------
    my $teachers_list =
      $panel->Scrolled( 'Listbox', -scrollbars => 'oe' )
      ->grid( -column => 0, -sticky => 'nwes', -row => 0 );
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
        $teachers_list->insert(
                                'end',
                                $teacher->id . ":  "
                                  . $teacher->firstname . " "
                                  . $teacher->lastname
                              );
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
        my $text     = "Section: " . $s->number;
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
    foreach my $bl ( sort { &_block_sort } $s->blocks ) {
        my $b_id     = "Block" . $bl->id;
        my $new_path = "$path/$b_id";

        $tree->add(
             $new_path,
             -text => $bl->day . " " . $bl->start . " " . $bl->duration . "hrs",
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

    my $l_id = "Lab" . $l->id;
    no warnings;
    $tree->add(
                "$path/$l_id",
                -text => "Lab: " . $l->number . " " . $l->descr,
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

sub _teacher_sort {
    $a->lastname cmp $b->lastname
      || $a->firstname cmp $b->firstname;
}

# =================================================================
# set dirty flag
# =================================================================
sub set_dirty {
    $$Dirty_ptr = 1;
    #$GuiSchedule->redraw_all_views;
    $GuiSchedule->destroy_all;
}


#==================================================================
#ALEX CODE
#create all the right click menu stuff
#==================================================================
sub _create_right_click_menu{
	my $treescrolled  = shift;
    my $teachers_list = shift;
    my $labs_list     = shift;
    my $streams_list  = shift;
    my $tree          = shift;
	
	my $lab_menu = $labs_list->Menu(-tearoff=>0);
	my $stream_menu = $streams_list->Menu(-tearoff=>0);

	$teachers_list->bind('<Button-3>', [\&_show_teacher_menu,$teachers_list, $tree, Ev('X'), Ev('Y')]);
	
	$labs_list->bind('<Button-3>', [\&_show_lab_menu,$labs_list, $tree, Ev('X'), Ev('Y')]);
	
	$streams_list->bind('<Button-3>', [\&_show_stream_menu,$streams_list, $tree, Ev('X'), Ev('Y')]);
	
}

#==================================================================
#ALEX CODE
#show menus
#==================================================================
sub _show_teacher_menu{
	my ($self,$teachers_list,$tree,$x, $y) = @_;
	my $teacher_menu = $teachers_list->Menu(-tearoff=>0);
	my @teachers = $teachers_list->curselection();
	if (scalar @teachers <= 0){
		return;
	}
	my $teacher_ID = $teachers_list->get($teachers[0]);
    ( my $id ) = split " ", $teacher_ID;
    chop $id;
    my $add_obj = $Schedule->teachers->get($id);

    # -------------------------------------------------------------
    # add appropriate object to object
    # -------------------------------------------------------------
       
    #	my $add_obj = $Schedule->teachers->get($id);
    #	$obj->assign_teacher($add_obj);   
        
	my @courses = $Schedule->courses->list();
	
	$teacher_menu->cascade(-label => "Add to Course");
	my $tch2cor_Menu = $teacher_menu->entrycget("Add to Course","-menu"); 
	$tch2cor_Menu->configure(-tearoff=>0);
	
	
	#('command', -label => $_->name, -command => sub { $teachers_list->bell})
	foreach my $cor (@courses){
		$tch2cor_Menu->cascade(-label => $cor->name);
		my $tchCorSec = $tch2cor_Menu->entrycget($cor->name,"-menu");
		$tchCorSec->configure(-tearoff=>0);
		my @sections = $cor->sections;
		foreach my $sec (@sections){
			$tchCorSec->cascade(-label => "Section " . $sec->number());
			my $blockList = $tchCorSec->entrycget("Section " . $sec->number(),"-menu");
			$blockList->configure(-tearoff=>0);
			my @blockarray = $sec->blocks;
			my $size = scalar @blockarray;
			$blockList->add('command', -label => "All Blocks", -command => sub {$sec->assign_teacher($add_obj) ; set_dirty()});
			for my $itr (1...$size){
				my $tempBlock = $blockarray[$itr-1];
				$blockList->add('command', -label => $tempBlock->print_description2, -command => sub {$tempBlock->assign_teacher($add_obj) ; set_dirty()});
			}
		}
	}
	
	#$teacher_menu->add('command', -label => $teacher_ID, -command => sub { $teachers_list->bell});
  	$teacher_menu->post($x, $y);  # Show the popup menu
}

sub _show_lab_menu{
	my ($self,$labs_list,$tree,$x, $y) = @_;
	my $lab_menu = $labs_list->Menu(-tearoff=>0);
	my @labs = $labs_list->curselection();
	if (scalar @labs <= 0){
		return;
	}
	my $lab_ID = $labs_list->get($labs[0]);
    ( my $id ) = split " ", $lab_ID;
    chop $id;
    my $add_obj = $Schedule->labs->get($id);

    # -------------------------------------------------------------
    # add appropriate object to object
    # -------------------------------------------------------------
       
    #	my $add_obj = $Schedule->labs->get($id);
    #	$obj->assign_lab($add_obj);   
        
	my @courses = $Schedule->courses->list();
	
	$lab_menu->cascade(-label => "Add to Course");
	my $tch2cor_Menu = $lab_menu->entrycget("Add to Course","-menu"); 
	$tch2cor_Menu->configure(-tearoff=>0);
	
	
	#('command', -label => $_->name, -command => sub { $labs_list->bell})
	foreach my $cor (@courses){
		$tch2cor_Menu->cascade(-label => $cor->name);
		my $tchCorSec = $tch2cor_Menu->entrycget($cor->name,"-menu");
		$tchCorSec->configure(-tearoff=>0);
		my @sections = $cor->sections;
		foreach my $sec (@sections){
			$tchCorSec->cascade(-label => "Section " . $sec->number());
			my $blockList = $tchCorSec->entrycget("Section " . $sec->number(),"-menu");
			$blockList->configure(-tearoff=>0);
			my @blockarray = $sec->blocks;
			my $size = scalar @blockarray;
			$blockList->add('command', -label => "All Blocks", -command => sub {$sec->assign_lab($add_obj) ; set_dirty()});
			for my $itr (1...$size){
				my $tempBlock = $blockarray[$itr-1];
				$blockList->add('command', -label => $tempBlock->print_description2, -command => sub {$tempBlock->assign_lab($add_obj) ; set_dirty()});
			}
		}
	}
	
	#$lab_menu->add('command', -label => $lab_ID, -command => sub { $labs_list->bell});
  	$lab_menu->post($x, $y);  # Show the popup menu
}

sub _show_stream_menu{
	my ($self,$streams_list,$tree,$x, $y) = @_;
	my $stream_menu = $streams_list->Menu(-tearoff=>0);
	my @streams = $streams_list->curselection();
	if (scalar @streams <= 0){
		return;
	}
	my $stream_ID = $streams_list->get($streams[0]);
    ( my $id ) = split " ", $stream_ID;
    chop $id;
    my $add_obj = $Schedule->streams->get($id);

    # -------------------------------------------------------------
    # add appropriate object to object
    # -------------------------------------------------------------
       
    #	my $add_obj = $Schedule->streams->get($id);
    #	$obj->assign_stream($add_obj);   
        
	my @courses = $Schedule->courses->list();
	
	$stream_menu->cascade(-label => "Add to Course");
	my $tch2cor_Menu = $stream_menu->entrycget("Add to Course","-menu"); 
	$tch2cor_Menu->configure(-tearoff=>0);
	
	
	#('command', -label => $_->name, -command => sub { $streams_list->bell})
	foreach my $cor (@courses){
		$tch2cor_Menu->cascade(-label => $cor->name);
		my $tchCorSec = $tch2cor_Menu->entrycget($cor->name,"-menu");
		$tchCorSec->configure(-tearoff=>0);
		my @sections = $cor->sections;
		foreach my $sec (@sections){
			$tchCorSec->add('command' , -label => "Section " . $sec->number() , -command => sub {$sec->assign_stream($add_obj) ; set_dirty()});
		}
	}
	
	#$stream_menu->add('command', -label => $stream_ID, -command => sub { $streams_list->bell});
  	$stream_menu->post($x, $y);  # Show the popup menu
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
              -postdropcommand =>
              [\&empty_trash,$trash_label],
    );
    
    $teachers_list->DropSite(
                      -droptypes   => [qw/Local/],
                      -dropcommand => [ \&_drop_on_trash, $trash_label, $tree ],
                      -entercommand => [ \&_enter_trash, $trash_label ],
    );

    $labs_list->DragDrop(
                      -event     => '<B1-Motion>',
                      -sitetypes => [qw/Local/],
                      -startcommand =>
                        [ \&_teacher_lab_start_drag, $labs_list, $tree, 'Lab' ],
    );
    
    $labs_list->DropSite(
                      -droptypes   => [qw/Local/],
                      -dropcommand => [ \&_drop_on_trash, $trash_label, $tree ],
                      -entercommand => [ \&_enter_trash, $trash_label ],
    );

    $streams_list->DragDrop(
                -event     => '<B1-Motion>',
                -sitetypes => [qw/Local/],
                -startcommand =>
                  [ \&_teacher_lab_start_drag, $streams_list, $tree, 'Stream' ],
    );
    
    $streams_list->DropSite(
                      -droptypes   => [qw/Local/],
                      -dropcommand => [ \&_drop_on_trash, $trash_label, $tree ],
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
                      -droptypes   => [qw/Local/],
                      -dropcommand => [ \&_drop_on_trash, $trash_label, $tree ],
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
        my $add_obj = $Schedule->labs->get($id);
        $obj->assign_lab($add_obj);
    }

    if ( $Dragged_from eq 'Stream' ) {
    	print "Dragged from stream\n";
        my $add_obj = $Schedule->streams->get($id);
		print "$obj\n";
        if ( $obj->isa('Block') ) {
            $obj = $obj->section;
 			print "changed to section: $obj\n";
        }
        print "Assigning $add_obj to $obj\n";
        $obj->assign_stream($add_obj);
        refresh_schedule($tree);
    }

    # -------------------------------------------------------------
    # update the Schedule and the tree
    # -------------------------------------------------------------
    if ( $obj->isa('Block') ) {
        refresh_block( $tree, $obj, $input, 1 );
    }
    elsif ( $obj->isa('Section') ) {
        refresh_section( $tree, $obj, $input, 1 );
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
        if ( $obj->isa('Block') || $obj->isa('Section') ) {
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
            $trash_label->configure(                          -bg=>$Colours->{WorkspaceColour},
                -fg=>$Colours->{WindowForeground},);
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
        my @x = $Drag_source->cget('-relief');

        if ($dropped) {
            $toggle = 0;
            if ($Trash1_photo) {
            $trash_label->configure( -image => $Trash1_photo );
            }
            else {
                 $trash_label->configure(                          -bg=>$Colours->{WorkspaceColour},
                -fg=>$Colours->{WindowForeground},);
            }
            return;
        }
        if ($x[0] eq 'flat') {
            if ($Trash1_photo) {
            $trash_label->configure( -image => $Trash1_photo );
            }
            else {
                $trash_label->configure(                          -bg=>$Colours->{WorkspaceColour},
                -fg=>$Colours->{WindowForeground},);
            }
        }
        else {
            if ($Trash2_photo) {
                $trash_label->configure( -image => $Trash2_photo );
            }
            else {
                $trash_label->configure( -fg=>$Colours->{WorkspaceColour},
                -bg=>$Colours->{WindowForeground});
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
                $trash_label->configure(                          -bg=>$Colours->{WorkspaceColour},
                -fg=>$Colours->{WindowForeground},);
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
        _edit_course( $frame, $tree, $obj , "Edit");
    }
    elsif ( $obj->isa('Section') ) {
        _edit_section( $frame, $tree, $obj, $path );
    }
}

sub edit_course {
    my $frame = shift;
    my $tree  = shift;
    my $type  = shift;
    my $input = $tree->selectionGet();
    my $obj   = _what_to_edit( $tree, $input );
    _edit_course( $frame, $tree, $obj , $type );
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
sub _edit_course {
    my $frame = shift;
    my $tree  = shift;
    my $obj   = shift;
    my $type  = shift;
	;
    # make dialog box for editing
    my $edit_dialog = create_edit_dialog( $frame, $tree , $type);

    # is a course selected?
    my $course_selected = 0;
    if ( $obj && $obj->isa('Course') ) {
        $course_selected = 1;
        $edit_dialog->{-inital_number} = $obj->number;
    }

    # empty dialog box
    if($type eq "Edit"){
    		$edit_dialog->{-modify}->configure( -state => 'disabled' );
    }
    $edit_dialog->{-number}->configure( -text  => '' );
    $edit_dialog->{-name}->configure( -text => '' );
    $edit_dialog->{-sections}->configure( -text => 1 );
    $edit_dialog->{-hours}[0]->configure( -text => 1.5 );

    # course is selected, fill dialog with course material
    if ($course_selected) {
        $edit_dialog->{-modify}->configure( -state => 'normal' );
        $edit_dialog->{-number}->configure( -text  => $obj->number );
        $edit_dialog->{-name}->configure( -text => $obj->name );

        # how many sections?
        my @sections = $obj->sections;
        $edit_dialog->{-sections}->configure( -text => scalar(@sections) );

        if (@sections) {
            $edit_dialog->{-course_hours}
              ->configure( -text => $sections[0]->hours );

            # put hours for each block
            my @blocks = $sections[0]->blocks;

            foreach my $i ( 1 .. @blocks ) {
                my $bl  = $blocks[ $i - 1 ];
                my $hrs = $bl->duration;
                if ( $i > 1 ) {
                    _add_block_to_editor( $edit_dialog, $i );
                }
                $edit_dialog->{-hours}[ $i - 1 ]->configure( -text => $hrs );
            }
        }

    }

    # show and populate
    $edit_dialog->{-toplevel}->raise();

}

# =================================================================
# save modified course
# =================================================================
sub save_course_modified {
    my $edit_dialog = shift;
    my $new         = shift;
    my $course;
    my $tl = shift;

    my $tree = $edit_dialog->{-tree};

	#--------------------------------------------
	#Check that all elements are filled in
	#--------------------------------------------
   	if($edit_dialog->{-number}->get eq "" || $edit_dialog->{-name}->get eq ""
   		|| $edit_dialog->{-sections}->get eq "" || $edit_dialog->{-course_hours}->get eq ""){
   		$tl->messageBox(	-title => 'Error', 
   							-message => "Missing elements");
   		return;
   	}
   	
   	foreach my $blnum ( 1 .. scalar( @{ $edit_dialog->{-hours} } ) ) {
            if ( $edit_dialog->{-hours}[ $blnum - 1 ]->get eq ""){
            	$tl->messageBox(-title => 'Error', 
   								-message => "Missing elements" );
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
    no warnings;
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
        $sec->hours( $edit_dialog->{-course_hours}->get );
        $course->add_section($sec);

        # for each section, add the blocks
        foreach my $blnum ( 1 .. scalar( @{ $edit_dialog->{-hours} } ) ) {
            my $bl = Block->new();
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

}

# =================================================================
# make dialog box for editing courses
# =================================================================
sub create_edit_dialog {
    my $frame = shift;
    my $tree  = shift;
	my $type  = shift;
    my $tl    = $frame->Toplevel( -title => "$type Course");
    my $self  = { -tree => $tree, -toplevel => $tl };

    # ---------------------------------------------------------------
    # instructions
    # ---------------------------------------------------------------
    $tl->Label(
                -text => "$type Course",
                -font => [qw/-family arial -size 18/]
              )->pack( -pady => 10 );
    if($type	 eq "Edit"){
    $tl->Label(
             -text => '... This will remove all teacher/lab info from Course', )
      ->pack( -pady => 5 );
    }
    
    $tl->Label(
                -text => "*Required Information",
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
                      
    $self->{-remove_block_button}
     = $button_row->Button(
                         -text    => 'Remove Block',
                         -width   => 12,
                         -command => [ \&_remove_block_to_editor, $self ],
                         -state => 'disabled'
                       )->pack( -side => 'left', -pady => 3 );
                       
	if($type eq "Edit"){
    $self->{-modify} =
      $button_row->Button(
                           -text    => 'Modify',
                           -width   => 12,
                           -command => [ \&save_course_modified, $self, 0 ,$tl]
                         )->pack( -side => 'left', -pady => 3 );
	}
	elsif($type eq "New"){
    $self->{-new} = $button_row->Button(
                                       -text    => 'Create New',
                                       -width   => 12,
                                       -command => [ \&save_course_modified, $self, 1, $tl ]
    )->pack( -side => 'left', -pady => 3 );
	}
	else{
		my $debuggError = $tl->Dialog(-title => 'Error', 
   										-text => "An error has occured, please contact Sandy Bultena.\nErrorCode:EC-ECD", 
   										-default_button => 'Okay', -buttons => [ 'Okay'], 
   										-bitmap => 'question' )->Show( );
	}

    $self->{-cancel} =
      $button_row->Button(
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
                      -text   => "*Number",
                      -anchor => 'e'
                    )->grid( -column => 0, -row => 0, -sticky => 'nwes' );
    $info_row->Label(
                      -text   => "*Description",
                      -anchor => 'e'
                    )->grid( -column => 0, -row => 1, -sticky => 'nwes' );
    $info_row->Label(
                      -text   => "*Hours per week",
                      -anchor => 'e'
                    )->grid( -column => 0, -row => 2, -sticky => 'nwes' );

    # ---------------------------------------------------------------
    # Course Info Entry boxes
    # ---------------------------------------------------------------
    $self->{-number} =
      $info_row->Entry( -width => 6 )
      ->grid( -column => 1, -row => 0, -sticky => 'nwes' );

    $self->{-name} =
      $info_row->Entry( -width => 30 )
      ->grid( -column => 1, -row => 1, -sticky => 'nwes' );

    $self->{-course_hours} =
      $info_row->Entry(
                        -width           => 6,
                        -validate        => 'key',
                        -validatecommand => \&is_number,
                        -invalidcommand  => sub { $info_row->bell },
                      )->grid( -column => 1, -row => 2, -sticky => 'nwes' );

    # make the "Enter" key mimic Tab key
    $self->{-number}->bind( "<Key-Return>",
                            sub { $self->{-number}->eventGenerate("<Tab>") } );
    $self->{-name}
      ->bind( "<Key-Return>", sub { $self->{-name}->eventGenerate("<Tab>") } );
    $self->{-course_hours}->bind(
        "<Key-Return>",
        sub {
            $self->{-course_hours}->eventGenerate("<Tab>");
        }
    );

    # ---------------------------------------------------------------
    # Section Info
    # ---------------------------------------------------------------
    $info_row->Label(
                      -text   => "Sections",
                      -anchor => 'e'
                    )->grid( -column => 0, -row => 3, -sticky => 'nwes' );

    $self->{-sections} =
      $info_row->Entry(
                        -width           => 5,
                        -validate        => 'key',
                        -validatecommand => \&is_number,
                        -invalidcommand  => sub { $info_row->bell },
                      )->grid( -column => 1, -row => 3, -sticky => 'nwes' );

    # make the "Enter" key mimic Tab key
    $self->{-sections}->bind(
                              "<Key-Return>",
                              sub { $self->{-sections}->eventGenerate("<Tab>") }
                            );

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
        
        if($num > 1){
        		$rmBTN->configure(-state => 'normal');
        }
        
        my $info_row = $self->{-info_row};

		$self->{-blockNums} = [] unless $self->{-blockNums};

		my $l = $info_row->Label(
                          -text   => "*$num",
                          -anchor => 'e'
                        )->grid( -column => 0, -row => 4 + $num, -sticky => 'nwes' );
		push @{$self->{-blockNums}},$l;

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
        my $info_row = $self->{-info_row};
        my $rmBTN = $self->{-remove_block_button};
        
        if($num <= 1){
        		my $Error = $info_row->Dialog(-title => 'Error', 
   										-text => "Can't remove block.", 
   										-default_button => 'Okay', -buttons => [ 'Okay'])->Show( );
   			return;
        }
        
        $num--;
        
        if($num <= 1){
        		$rmBTN->configure(-state => 'disabled');
        }
        
        my $tempL = pop @{$self->{-blockNums}};
        my $tempH = pop @{$self->{-hours}};
        $tempH->destroy if Tk::Exists($tempH);;
        $tempL->destroy if Tk::Exists($tempL);;
        $info_row->update;
    }
}

# =================================================================
# validate that number be entered in a entry box is a real number
# (positive real number)
# =================================================================
sub is_number {
    my $n = shift;
    return 1 if $n =~ /^\s*\d*\.?\d*\s*$/;
    return 0;
}

# =================================================================
# edit/modify section
# =================================================================
sub _edit_section {
    my $frame   = shift;
    my $tree    = shift;
    my $section = shift;
    my $path    = shift;

    return unless $section->isa('Section');

    # make dialog box for editing section
    my $edit_dialog = create_section_dialog( $frame, $tree, $section, $path );

    # enter the stream vlaues
    my $chk_values = $edit_dialog->{-streams};
    foreach my $stream ( $section->streams ) {
        $chk_values->{ $stream->id } = 1;
    }

    # add the current blocks
    my @blocks = $section->blocks;

    foreach my $i ( 1 .. @blocks ) {
        my $bl  = $blocks[ $i - 1 ];
        my $hrs = $bl->duration;
        if ( $i > 1 ) {
            _add_block_to_editor( $edit_dialog, $i );
        }
        $edit_dialog->{-hours}[ $i - 1 ]->configure( -text => $hrs );
    }

    # show
    $edit_dialog->{-toplevel}->raise();

}

# =================================================================
# save modified section
# =================================================================
sub save_section_modified {
    my $edit_dialog = shift;
    my $new         = shift;

    my $tree = $edit_dialog->{-tree};

    # get objects
    my $section = $edit_dialog->{-section};
    my $course  = $edit_dialog->{-course};

    if ($new) {
        $section = Section->new();
        $course->add_section($section);
        $section->hours( $edit_dialog->{-course_hours}->get );

        # for each section, add the blocks
        foreach my $blnum ( 1 .. scalar( @{ $edit_dialog->{-hours} } ) ) {
            my $bl = Block->new();
            $bl->duration( $edit_dialog->{-hours}[ $blnum - 1 ]->get );
            $section->add_block($bl);
        }
    }

    else {

        # for each section, add the new blocks
        foreach my $blnum (
                            scalar( @{ $section->blocks } ) +
                            1 .. scalar( @{ $edit_dialog->{-hours} } ) )
        {
            my $bl = Block->new();
            $bl->duration( $edit_dialog->{-hours}[ $blnum - 1 ]->get );
            $section->add_block($bl);
        }
    }

    # assign (or not) the streams to this section
    foreach my $stream ( $section->streams ) {
        $section->remove_stream($stream);
    }
    foreach my $stream_id ( keys %{ $edit_dialog->{-streams} } ) {
        if ( $edit_dialog->{-streams}->{$stream_id} ) {
            my $stream = $Schedule->streams->get_by_id($stream_id);
            $section->assign_stream($stream);
        }
    }

    # update schedule and close this window
    my $path = $edit_dialog->{-path};
    $path =~ s/^(.*)\/.*$/$1/;
    refresh_course( $tree, $course, $path );
    $tree->autosetmode();
    set_dirty();
    
    $edit_dialog->{-toplevel}->destroy;

}

# =================================================================
# make dialog box for editing sections
# =================================================================
sub create_section_dialog {
    my $frame   = shift;
    my $tree    = shift;
    my $section = shift;
    my $path    = shift;
    return unless $section;

    my $course = $section->course;
    my $tl = $frame->Toplevel( -title => 'Edit Section' );
    my $self = {
                 -tree     => $tree,
                 -toplevel => $tl,
                 -section  => $section,
                 -course   => $course,
                 -path     => $path
               };

    # ---------------------------------------------------------------
    # instructions
    # ---------------------------------------------------------------
    $tl->Label(
                -text => 'Edit / Modify Section',
                -font => [qw/-family arial -size 18/]
              )->pack( -pady => 10 );
    $tl->Label( -text => $course->number . "\n" . $course->name,
                    -font => [qw/-family arial -size 18/]
     )
      ->pack( -pady => 5 );
    $tl->Label( -text => "Section: " . $section->number,
                    -font => [qw/-family arial -size 18/]
     );

    # ---------------------------------------------------------------
    # buttons
    # ---------------------------------------------------------------
    my $button2_row =
      $tl->Frame()
      ->pack( -side => 'bottom', -expand => 1, -fill => 'y', -pady => 15 );

    my $button1_row =
      $tl->Frame()
      ->pack( -side => 'bottom', -expand => 1, -fill => 'y', -pady => 2 );

    $button1_row->Button(
                          -text    => 'Add Block',
                          -width   => 16,
                          -command => [ \&_add_block_to_editor, $self ]
                        )->pack( -side => 'left', -pady => 3 );

    $self->{-modify} = $button2_row->Button(
        -text    => 'Modify Section',
        -width   => 16,
        -command => [ \&save_section_modified, $self ]

                                           )->pack( -side => 'left', -pady => 3 );

    $self->{-new} = $button2_row->Button(
                               -text    => 'New Section',
                               -width   => 16,
                               -command => [ \&save_section_modified, $self, 1 ]
    )->pack( -side => 'left', -pady => 3 );

    $button2_row->Button(
        -text    => 'Delete Section',
        -width   => 16,
        -command => sub {
            $course->delete_section($section);
            $tl->destroy;
        },
    )->pack( -side => 'left', -pady => 3 );

    $self->{-cancel} =
      $button2_row->Button(
                            -text    => 'Cancel',
                            -width   => 16,
                            -command => sub { $tl->destroy(); }
                          )->pack( -side => 'left', -pady => 3 );

    # ---------------------------------------------------------------
    # Stream Info
    # ---------------------------------------------------------------
    my $streams_frame = $tl->LabFrame( -label => 'Select Streams' )->pack(
                                                                -side => 'top',
                                                                -expand => 1,
                                                                -fill => 'both',
                                                                -pady => 10,
                                                                -padx => 10
    );
    my $scrolled =
      $streams_frame->Scrolled(
                                'Frame',
                                -scrollbars => 'osoe',
                                -bg         => $Colours->{DataBackground},
                                -fg         => $Colours->{DataForeground},
                              )->pack( -expand => 1, -fill => 'both' );

    my %chk_values;
    foreach my $stream ( sort {$a->id <=> $b->id} $Schedule->streams->list ) {
        $chk_values{ $stream->id } = 0;
        $scrolled->Checkbutton(
                                -width    => 0,
                                -text     => $stream->descr,
                                -anchor   => 'nw',
                                -variable => \$chk_values{ $stream->id },
                                -bg       => $Colours->{DataBackground},
                                -fg       => $Colours->{DataForeground},
                              )->pack( -pady => 3, -padx => 5, -expand => 1, -fill => 'both' );
    }
    $self->{-streams} = \%chk_values;

    # ---------------------------------------------------------------
    # Block Info
    # ---------------------------------------------------------------
    my $info_row = $self->{-info_row} =
      $tl->Frame()->pack( -side => 'top', -expand => 1, -fill => 'both' );
    $info_row->Label(
                      -text   => 'Block Hours:',
                      -anchor => 'se',
                      -height => 2
                    )->grid( -column => 0, -row => 1 );
    _add_block_to_editor( $self, 1 );

    return $self;
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

