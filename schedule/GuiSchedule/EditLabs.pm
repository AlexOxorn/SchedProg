#!/usr/bin/perl
use strict;
use warnings;

package EditLabs;
use FindBin;
use Carp;
use Tk;
use lib "$FindBin::Bin/..";
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
use Data::Dumper;
my $image_dir = Tk::FindImages::get_image_dir();

# =================================================================
# Class/Global Variables
# =================================================================
our $Max_id = 0;
my $Schedule;
my $GuiSchedule;
my $Trash1_photo;
my $Trash2_photo;
my %Styles;

my $frame;
my $day;
my $start;
my $duration;
my $lab;

# ===================================================================
# globals
# ===================================================================
my $course;
my $section;
my $block;
my $teacher;

my %dayName = (
                1 => "Monday",
                2 => "Tuesday",
                3 => "Wednesday",
                4 => "Thursday",
                5 => "Friday"
              );

# ===================================================================
# new
# ===================================================================
sub new {
    my $class = shift;
    $frame    = shift;
    $Schedule = shift;

    $GuiSchedule = shift;

    $day      = shift;
    $start    = shift;
    $duration = shift;

    $lab = shift;

    return OpenDialog();
}

sub OpenDialog {
    if ($Schedule) {

        #------------------------------------
        # SET UP TEACHER DATA
        #------------------------------------
        my @teachers = $Schedule->teachers->list;
        my $curTeach = "";
        my $newFName = "";
        my $newLName = "";

        my %teacherName;
        foreach my $i (@teachers) {
            $teacherName{ $i->id } = $i->firstname . " " . $i->lastname;
        }

        #------------------------------------
        # SET UP COURSE DATA
        #------------------------------------

        my @courses   = $Schedule->courses->list;
        my $curCourse = "";

        my %courseName;
        foreach my $i (@courses) {
            $courseName{ $i->id } = $i->print_description2;
        }

        #------------------------------------
        # SET UP SECTION DATA
        #------------------------------------

        my @sections;
        my $curSection = "";
        my $newSection = "";

        my %sectionName;

        #------------------------------------
        # SET UP BLOCK DATA
        #------------------------------------

        my $curBlock = "";
        my $newBlock = "";

        #------------------------------------
        # Create Dialog Box
        #------------------------------------

        my $db = $frame->DialogBox(
                                    -title => "Add (or Modify) Block to "
                                      . $lab->number . ": "
                                      . $lab->descr,
                                    -buttons => [ "OK", "Cancel" ]
                                  );

        my $OKAY = $db->Subwidget("B_OK");
        $OKAY->configure( -state => 'disabled' );

        my $df = $db->Subwidget("top");

        my $fonts    = $Scheduler::Fonts;
        my $x        = $Scheduler::Fonts;    # to get rid of stupid warning
        my $bigFont  = $fonts->{bigbold};
        my $boldFont = $fonts->{bold};


        # -----------------------------------
        # Create Main Labels
        # -----------------------------------

        my $MainLabel = $db->Label(
                                    -text => $dayName{$day} . " at "
                                      . _hoursToString($start) . " for "
                                      . $duration
                                      . " hour(s)",
                                    -font => $bigFont
                                  );

#        my $CourseLabel  = $db->Label( -text => "Course:",  -width => 8 );
#        my $TeacherLabel = $db->Label( -text => "Teacher:", -width => 8 );
#        my $SectionLabel = $db->Label( -text => "Section:", -width => 8 );

        # -----------------------------------------------
        # Defining widget variable names
        # -----------------------------------------------

        my $CourseJBE;  
        my $SectionJBE;
        my $TeacherJBE;

        my $SectionEntry;
        my $TeacherFName;
        my $TeacherLName;

        my $SectionNewBtn;
        my $TeacherNewBtn;

        #----------------------------------------
        # Drop Down Lists widgets
        #----------------------------------------

        $CourseJBE = $db->JBrowseEntry(
            -variable  => \$curCourse,
            -state     => 'readonly',
            -choices   => \%courseName,
            -width     => 12,
            -browsecmd => sub {
                my %rHash = reverse %courseName;
                my $id    = $rHash{$curCourse};
                $course = $Schedule->courses->get($id);
                updateSectionList( \$SectionJBE, \%sectionName,
                                   \$curSection, $OKAY );
            }
        );
        my $courseDropEntry = $CourseJBE->Subwidget("entry");
        $courseDropEntry->configure( -disabledbackground => "white" );
        $courseDropEntry->configure( -disabledforeground => "black" );

        $SectionJBE = $db->JBrowseEntry(
            -variable  => \$curSection,
            -state     => 'readonly',
            -browsecmd => sub {
                my %rHash = reverse %sectionName;
                my $id    = $rHash{$curSection};
                $section = $course->get_section_by_id($id);
                $OKAY->configure( -state => 'normal' );
            }
        );
        my $secDropEntry = $SectionJBE->Subwidget("entry");
        $secDropEntry->configure( -disabledbackground => "white" );
        $secDropEntry->configure( -disabledforeground => "black" );

        $TeacherJBE = $db->JBrowseEntry(
            -variable  => \$curTeach,
            -state     => 'readonly',
            -choices   => \%teacherName,
            -browsecmd => sub {
                my %rHash = reverse %teacherName;
                my $id    = $rHash{$curTeach};
                $teacher = $Schedule->teachers->get($id);
            }
        );
        my $teacherDropEntry = $TeacherJBE->Subwidget("entry");
        $teacherDropEntry->configure( -disabledbackground => "white" );
        $teacherDropEntry->configure( -disabledforeground => "black" );

        # -------------------------------------------------------
        # NAME entry widgets
        # -------------------------------------------------------

        $SectionEntry   = $db->Entry( -textvariable => \$newSection );
        $TeacherFName = $db->Entry( -textvariable => \$newFName );
        $TeacherLName = $db->Entry( -textvariable => \$newLName );

        # -------------------------------------------------------
        # button widgets
        # -------------------------------------------------------

        $SectionNewBtn = $db->Button(
            -text    => "Create",
            -command => sub {
                add_new_section( \$newSection,   \%sectionName,
                                 \$SectionJBE, \$curSection, $OKAY );
            }
        );
        $TeacherNewBtn = $db->Button(
            -text    => "Create",
            -command => sub {
                add_new_teacher( \$newFName,   \$newLName, \%teacherName,
                                 \$TeacherJBE, \$curTeach );
            }
        );

        # -------------------------------------------------------
        # Widget Placement
        # -------------------------------------------------------
        $boldFont =
          $db->toplevel->fontCreate( $db->toplevel->fontActual($boldFont),
                                     -weight => 'bold' );
        my %bold = $db->toplevel->fontActual($boldFont);
        $db->Label(
                    -text => "Create new block and add to " . $lab->number,
                    -font => $bigFont
                  )->grid( "-", "-", "-", -pady => 2, -padx => 2, -sticky => 'nsew' );
        $MainLabel->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );

        $db->Label( -text => '' )->grid( "-", "-", "-", -sticky => 'nsew' );
        $db->Label(
                    -text   => "Course Info (required)",
                    -font   => $boldFont,
                    -anchor => 'w'
                  )->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );

     #  $db->Label(-text=>'')->grid( "-", "-","-",-padx=>2, -sticky => 'nsew' );
        $db->Label( -text => "Choose Course", -anchor => 'w' )
          ->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );
        $CourseJBE->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );
        $db->Label( -text => "Choose Section", -anchor => 'w' )->grid(
                                    $db->Label(
                                        -text => "Create new from Section Name",
                                        -anchor => 'w'
                                    ),
                                    "-", "-",
                                    -padx   => 2,
                                    -sticky => 'nsew'
        );
        $SectionJBE->grid(
                           $SectionEntry, "-", $SectionNewBtn,
                           -padx   => 2,
                           -sticky => 'nsew'
                         );
        $db->Label( -text => '' )
          ->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );
        $db->Label(
                    -text   => "Teacher (optional)",
                    -font   => $boldFont,
                    -anchor => 'w'
                  )->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );
        $db->Label( -text => "Teacher", -anchor => 'w' )->grid(
                            $db->Label(
                                -text => "Create new from Firstname / Lastname",
                                -anchor => 'w'
                            ),
                            "-", "-",
                            -padx   => 2,
                            -sticky => 'nsew'
        );
        $TeacherJBE->grid(
                           $TeacherFName, $TeacherLName,
                           $TeacherNewBtn,
                           -sticky => 'nsew',
                           -padx   => 2
                         );
        $db->Label( -text => '' )
          ->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );

        #------------------------------------
        #Show menu
        #------------------------------------
        my $answer = $db->Show() || "Cancel";

        if ( $answer eq "OK" ) {

            #if answer is okay, then create the new block
            add_new_block();
            
            # check if a block is defined
            if ($block) {

                #if it is, assign all the properties to the block and return
                $block->day($day);
                $block->start( _hoursToString($start) );
                $block->duration($duration);
                $block->assign_lab($lab);
                $block->assign_teacher($teacher) if $teacher;
                return 1;
            }
        }
        return 0;
    }
}

# ----------------------------------------------------------------------------
# updateSectionList
# When a course is selected, the section menu has to change for the new Course
# ----------------------------------------------------------------------------

sub updateSectionList {

    my $SectionJBE  = ${ +shift };
    my $sectionName = shift;
    my $curSection  = shift;
    my $OKAY        = shift;

    #Disable okay;
    $OKAY->configure( -state => 'disabled' );

    #Blanking the section and block inputs
    $$curSection = "";
    $section     = "";

    # Blanking the choice hashes
    %$sectionName = ();

    my @sections = $course->sections;

    foreach my $i (@sections) {
        $sectionName->{ $i->id } = "$i";
    }

    # Updating the Drop down with the new options
    $SectionJBE->configure( -choices => $sectionName );

}

sub add_new_teacher {

    my $firstname   = shift;
    my $lastname    = shift;
    my $teacherName = shift;
    my $TeacherJBE  = ${ +shift };
    my $curTeach    = shift;

    # Check is a first and last name are inputed, otherwise return
    if ( $$firstname && $$lastname ) {

        #see if a teacher by that name exsits
        my $teacherNew =
          $Schedule->teachers->get_by_name( $$firstname, $$lastname );

        unless ($teacherNew) {

            #if no teacher by the inputed name exists, create a new teacher
            $teacherNew = Teacher->new( -firstname => $$firstname,
                                        -lastname  => $$lastname );
            $$firstname = "";
            $$lastname  = "";
            $Schedule->teachers->add($teacherNew);

            $teacherName->{ $teacherNew->id } = "$teacherNew";
            $TeacherJBE->configure( -choices => $teacherName );
            $$curTeach = "$teacherNew";
            $teacher   = $teacherNew;
        }
        else {

            #If a teacher exists by that name, ask the user if he would like
            #to set that teacher, otherwise return
            my $db = $frame->DialogBox( -title   => "Teacher already exists",
                                        -buttons => [ "Yes", "No" ] );
            $db->Label( -text => "A teacher by this name already exsists!\n"
                        . "Do you want to set that teacher?" )->pack;

            my $answer = $db->Show() || "";
            if ( $answer eq "Yes" ) {
                $$curTeach  = "$teacherNew";
                $$firstname = "";
                $$lastname  = "";
                $teacher    = $teacherNew;
            }
        }
    }

}

sub add_new_section {

    my $name        = shift;
    my $sectionName = shift;
    my $SectionJBE  = ${ +shift };
    my $curSection  = shift;
    my $OKAY        = shift;

    #check if a course is defined, otherwise return
    if ($course) {

        #check to see if a section by that name  exists
        my @sections = $course->get_section_by_name($$name);
        my $sectionNew;

        #If a section by the same name does exists
        my $create_flag = 1;

        if (@sections) {

            # ask the user if he want's to create a new section with that name
            my $db = $frame->DialogBox( -title   => "Section already exists",
                                        -buttons => [ "Yes", "No" ] );
            $db->Label( -text => scalar @sections
                . " section(s) by this name already exsist!\nDo you still want create this new section?"
            )->pack;
            my $answer = $db->Show() || "";

            #If not, set section to first instance of the section with
            #the section name
            if ( $answer ne 'Yes' ) {
                $create_flag = 0;
                my $temp = $sections[0];
                $$curSection  = "$temp";
                $section      = $temp;
            }
        }

        #Create the new section
        if ($create_flag) {

            $sectionNew = Section->new(
                                        -number => $course->get_new_number,
                                        -hours  => 0,
                                        -name   => $$name
                                      );
            $$name = "";
            $course->add_section($sectionNew);

            $sectionName->{ $sectionNew->id } = "$sectionNew";
            $SectionJBE->configure( -choices => $sectionName );
            $$curSection = "$sectionNew";
            $section     = $sectionNew;

        }
        $OKAY->configure( -state => 'normal' );
    }

}

sub add_new_block {

    #If a section is defined, create a new block and set active block to it
    if ($section) {
        my $new = Block->new( -number => $section->get_new_number );
        $section->add_block($new);
        $block = $new;
    }

}

#=======================
#_hoursToString
#  8.5 -> 8:30
#=======================
sub _hoursToString {
    my $time = shift;

    my $string = int($time) . ":";
    $string = $string . "00" if $time == int($time);
    $string = $string . "30" unless $time == int($time);

    return $string;

}

1;
