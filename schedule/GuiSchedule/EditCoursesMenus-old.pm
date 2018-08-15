#!/usr/bin/perl
use strict;
use warnings;

package EditCourses12345;
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
our $Schedule;
my $MAX_SECTIONS = 50;
my $MAX_BLOCK    = 10;

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
            -label   => "Clear All Teacher Resources and Streams",
            -command => sub {
                my @sections = $obj->sections;
                foreach my $sec (@sections) {
                    my @teachers = $sec->teachers;
                    my @streams  = $sec->streams;
                    my @labs     = $Schedule->labs->list;
                    foreach my $teach (@teachers) {
                        $sec->remove_teacher($teach);
                    }
                    foreach my $stream (@streams) {
                        $sec->remove_stream($stream);
                    }
                    foreach my $lab (@labs) {
                        $sec->remove_lab($lab);
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
            -label   => "Clear All Teacher Resources and Streams",
            -command => sub {
                my @teachers = $obj->teachers;
                my @streams  = $obj->streams;
                my @labs     = $Schedule->labs->list;
                foreach my $teach (@teachers) {
                    $obj->remove_teacher($teach);
                }
                foreach my $stream (@streams) {
                    $obj->remove_stream($stream);
                }
                foreach my $lab (@labs) {
                    $obj->remove_lab($lab);
                }
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
            -label   => "Clear All Teacher Resources and Streams",
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

                my $hourEntry =
                  $db1->add(
                             'Entry',
                             -textvariable    => \$num,
                             -validate        => 'key',
                             -validatecommand => \&is_number,
                             -invalidcommand  => sub { $tree_menu->bell },
                             -width           => 20,
                           )->pack;

                $db1->configure( -focus => $hourEntry );

                my $answer1 = $db1->Show();
                if (    $answer1 eq 'Ok'
                     && defined($num)
                     && $num ne ""
                     && $num > 0 )
                {
                    $obj->duration($num);
                    refresh_section( $tree, $parent_obj, $parent, 1 );
                    set_dirty();
                }
                elsif (    $answer1 eq 'Ok'
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

    #   my $add_obj = $Schedule->teachers->get($id);
    #   $obj->assign_teacher($add_obj);

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

    #   my $add_obj = $Schedule->labs->get($id);
    #   $obj->assign_lab($add_obj);

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

    #   my $add_obj = $Schedule->streams->get($id);
    #   $obj->assign_stream($add_obj);

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
    $courseNumberEntry =
      $edit_dialog->Entry(
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

    $secText =
      $top->Label( -text => "Sections:", -anchor => 'w' )
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

    $sectionMessage =
      $top->Label( -text => "" )
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

    $teachText =
      $top->Label( -text => "Add Teacher: ", -anchor => 'w' )
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

    $streamText =
      $top->Label( -text => "Stream Add: ", -anchor => 'w' )
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

    $edit_dialog->configure( -focus => $secDrop );

    my $answer = $edit_dialog->Show();
    $answer = "Close" unless $answer;

    if ( $answer eq 'Delete' ) {

        my $sure = $top->DialogBox( -title   => "Delete?",
                                    -buttons => [ 'Yes', 'NO' ] );

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
                     -title => $obj->course->name . ": Section " . $obj->number,
                     -buttons => [ 'Close', 'Delete' ] );

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

    $blockMessage =
      $top->Label( -text => "" )
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

    $edit_dialog->configure( -focus => $blockDrop );

    my $answer = $edit_dialog->Show();
    $answer = "NO" unless $answer;

    if ( $answer eq 'Delete' ) {

        my $sure = $frame->DialogBox( -title   => "Delete?",
                                      -buttons => [ 'Yes', 'NO' ] );

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

    $edit_dialog->configure( -focus => $durIn );

    my $answer = $edit_dialog->Show();
    $answer = "Close" unless $answer;
    if ( $answer eq 'Close' ) {
        $obj->duration($dur);
    }
    elsif ( $answer eq 'Delete' ) {

        my $sure = $frame->DialogBox( -title   => "Delete?",
                                      -buttons => [ 'Yes', 'NO' ] );

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

    $db1->add( 'Label', -text => "How Many Blocks? (MAX $MAX_BLOCK)" )->pack;
    my $blockNumEntry = $db1->add(
                                   'Entry',
                                   -textvariable    => \$num,
                                   -validate        => 'key',
                                   -validatecommand => \&is_integer,
                                   -invalidcommand  => sub { $frame->bell },
                                   -width           => 20,
                                 )->pack( -fill => 'x' );

    $db1->configure( -focus => $blockNumEntry );

    my $answer = $db1->Show();
    $answer = "Cancel" unless $answer;

    if ( $answer eq "Ok" && defined $num && $num ne "" && $num > 0 ) {
        $num = $MAX_BLOCK if $num > $MAX_BLOCK;
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

# stop the dialog box from executing the default button press when hitting return
        $db2->bind( "<Return>", sub { } );

        my $hoursEntry;
        foreach my $i ( 1 ... $num ) {
            my $A = $top->Label( -text => "Block $i" );
            my $B = $top->Entry(
                                 -textvariable    => \$hrs[ $i - 1 ],
                                 -validate        => 'key',
                                 -validatecommand => \&is_number,
                                 -invalidcommand  => sub { $frame->bell },
                               );

            $B->bind( "<Return>", sub { $B->focusNext; } );
            $hoursEntry = $B if $i == 1;
            $A->grid( $B, -sticky => 'new' );
        }

        my ( $col, $row ) = $top->gridSize();
        for ( my $i = 1 ; $i < $col ; $i++ ) {
            $top->gridColumnconfigure( $i, -weight => 1 );
        }
        $top->gridRowconfigure( $row - 1, -weight => 1 );

        $answer = "";

        $db2->configure( -focus => $hoursEntry );

        $answer = $db2->Show();
        $answer = "Cancel" unless $answer;

        if ( $answer eq "Ok" ) {
            foreach my $i ( 1 ... $num ) {
                if ( $hrs[ $i - 1 ] ne "" && $hrs[ $i - 1 ] > 0 ) {
                    my $bl = Block->new( -duration => $hrs[ $i - 1 ],
                                         -number   => $obj->get_new_number );
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
        -title   => 'How Many Sections',
        -buttons => [ 'Ok', 'Cancel' ],

        #-height => 300,
        #-width => 500
                               );

    $db0->add( 'Label', -text => "How Many Sections? (MAX $MAX_SECTIONS)" )
      ->pack;
    my $secNumEntry = $db0->add(
                                 'Entry',
                                 -textvariable    => \$numS,
                                 -validate        => 'key',
                                 -validatecommand => \&is_integer,
                                 -invalidcommand  => sub { $frame->bell },
                               )->pack( -fill => 'x' );

    $db0->configure( -focus => $secNumEntry );

    my $answer = $db0->Show();
    $answer = "Cancel" unless $answer;

    if ( $answer eq 'Ok' && defined $numS && $numS ne "" && $numS > 0 ) {
        $numS = $MAX_SECTIONS if $numS > $MAX_SECTIONS;

        my $db3 = $frame->DialogBox( -title   => 'Name The Sections',
                                     -buttons => [ 'Ok', 'Cancel' ], );

# stop the dialog box from executing the default button press when hitting return
        $db3->bind( "<Return>", sub { } );

        my $top = $db3->Subwidget("top");

        my $frame = $top->Scrolled(
                                    'Pane',
                                    -scrollbars => 'oe',
                                    -width      => 300,
                                    -height     => 300,
                                    -sticky     => 'nsew',
                                  )->pack( -expand => 1, -fill => 'both' );

        $frame->Label( -text => "Name the Sections (OPTIONAL)" )
          ->pack( -side => 'top' );
        foreach my $i ( 1 ... $numS ) {
            push( @names, "" );
        }

        my $sectionNameEntry;

        foreach my $i ( 1 ... $numS ) {
            my $x = $frame->Frame()->pack( -fill => 'x' );

            #$x->Label( -text => "Name", -width => 5, -anchor => 'w' )
            #  ->pack( -side => 'left' );

            my $y = $x->Entry( -textvariable => \$names[ $i - 1 ] )->pack(
                                                                -side => 'left',
                                                                -expand => 1,
                                                                -fill   => 'x'
            );
            $y->bind( "<Return>",  sub { $y->focusNext; } );
            $y->bind( "<FocusIn>", sub { $frame->see($y) } );

            $sectionNameEntry = $y if $i == 1;
        }

        $frame->Label( -text => "", )->pack( -expand => 1, -fill => 'both' );

        $db3->configure( -focus => $sectionNameEntry );
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

            $db1->add( 'Label', -text => "How Many Blocks? (MAX $MAX_BLOCK)" )
              ->pack;
            my $blockNumEntry =
              $db1->add(
                         'Entry',
                         -textvariable    => \$numB,
                         -validate        => 'key',
                         -validatecommand => \&is_integer,
                         -invalidcommand  => sub { $frame->bell },
                         -width           => 20,
                       )->pack( -fill => 'x' );
            $answer = "";

            $db1->configure( -focus => $blockNumEntry );

            $answer = $db1->Show();
            $answer = 'Cancel' unless $answer;

            if (    $answer eq "Ok"
                 && defined $numB
                 && $numB ne ""
                 && $numB >= 0 )
            {
                $numB = $MAX_BLOCK if $numB > $MAX_BLOCK;

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

                    # stop the dialog box from executing the
                    # default button press when hitting return
                    $db2->bind( "<Return>", sub { } );

                    my $hoursEntry;

                    foreach my $i ( 1 ... $numB ) {
                        my $A = $top->Label( -text => "Block $i" );
                        my $B =
                          $top->Entry(
                                       -textvariable    => \$hrs[ $i - 1 ],
                                       -validate        => 'key',
                                       -validatecommand => \&is_number,
                                       -invalidcommand  => sub { $frame->bell },
                                     );
                        $hoursEntry = $B if $i == 1;
                        $A->grid( $B, -sticky => 'new' );
                        $B->bind( "<Return>", sub { $B->focusNext; } );
                    }

                    my ( $col, $row ) = $top->gridSize();
                    for ( my $i = 1 ; $i < $col ; $i++ ) {
                        $top->gridColumnconfigure( $i, -weight => 1 );
                    }
                    $top->gridRowconfigure( $row - 1, -weight => 1 );

                    $answer = "";

                    $db2->configure( -focus => $hoursEntry );

                    $answer = $db2->Show();
                    $answer = "Cancel" unless $answer;
                }

                if ( $answer eq "Ok" ) {

                    foreach my $j ( 1 ... $numS ) {
                        my $sectionNum = $obj->get_new_number;
                        my $section =
                          Section->new(
                                        -number => $sectionNum,
                                        -hours  => 0,
                                        -name   => $names[ $j - 1 ]
                                      );
                        $obj->add_section($section);
                        foreach my $i ( 1 ... $numB ) {
                            if ( $hrs[ $i - 1 ] ne "" && $hrs[ $i - 1 ] > 0 ) {
                                my $bl = Block->new(
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

1;
