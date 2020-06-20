#!/usr/bin/perl
use strict;
use warnings;

package AssignToResource;
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
my $type;

my $obj;

# ===================================================================
# globals
# ===================================================================
my $course;
my $section;
my $block;
my $teacher;
my $lab;
my $stream;

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

    $obj  = shift;
    $type = shift;

    $lab     = $obj if $type eq 'lab';
    $teacher = $obj if $type eq 'teacher';
    $stream  = $obj if $type eq 'stream';

    return OpenDialog();
}

# ============================================================================
# OpenDialog
# ============================================================================
sub OpenDialog {
    if ($Schedule) {

        #------------------------------------
        # SET UP LAB DATA
        #------------------------------------
        my @labs       = $Schedule->labs->list;
        my $curLab     = "";
        my $newLabNum  = "";
        my $newLabName = "";

        my %labName;
        foreach my $i (@labs) {
            $labName{ $i->id } = "$i";
        }

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
        my @blocks;
        my $curBlock = "";
        my $newBlock = "";
        my %blockName;

        #------------------------------------
        # Create Dialog Box
        #------------------------------------

        my $db = $frame->DialogBox( -title   => "Assign Block",
                                    -buttons => [ "Ok", "Cancel" ] );

        my $OKAY = $db->Subwidget("B_Ok");
        $OKAY->configure( -state => 'disabled' );

        my $df = $db->Subwidget("top");

        my $fonts    = $Scheduler::Fonts;
        my $x        = $Scheduler::Fonts;    # to get rid of stupid warning
        my $bigFont  = $fonts->{bigbold};
        my $boldFont = $fonts->{bold};

        # -----------------------------------
        # Create Main Labels
        # -----------------------------------

        my $lblTitle;
        $lblTitle = $db->Label(
                                -text => "Assign block to Resource",
                                -font => $bigFont
        ) if $type eq 'lab';

        $lblTitle = $db->Label(
                                -text => "Assign block to Teacher",
                                -font => $bigFont
        ) if $type eq 'teacher';

        my $selectedBlockText =
            $dayName{$day} . " at "
          . _hoursToString($start) . " for "
          . $duration
          . " hour(s)";
        my $lblCourseInfo = $db->Label(
                                        -text   => "Course Info (required)",
                                        -font   => $boldFont,
                                        -anchor => 'w'
        );
        my $lblTeacherInfo = $db->Label(
                                         -text   => "Teacher (optional)",
                                         -font   => $boldFont,
                                         -anchor => 'w'
        );
        my $lblLabInfo = $db->Label(
                                     -text   => "Resource (optional)",
                                     -font   => $boldFont,
                                     -anchor => 'w'
        );
        my $lblCourse = $db->Label( -text => "Choose Course", -anchor => 'w' );
        my $lblTeacher =
          $db->Label( -text => "Choose Teacher", -anchor => 'w' );
        my $lblLab = $db->Label( -text => "Choose Resource", -anchor => 'w' );
        my $lblSection =
          $db->Label( -text => "Choose Section", -anchor => 'w' );
        my $lblBlock =
          $db->Label( -text => "Choose Block To Modify", -anchor => 'w' );
        my $lblCreateSection =
          $db->Label( -text => "Create new from Section Name", -anchor => 'w' );
        my $lblCreateTeacher =
          $db->Label( -text   => "Create new from Firstname / Lastname",
                      -anchor => 'w' );
        my $lblCreateLab = $db->Label(
                            -text => "Create new from Resource number and name",
                            -anchor => 'w' );
        my $lblCreateBlock = $db->Label(
                                -text => "Create block from selected date/time",
                                -anchor => 'w' );

        # -----------------------------------------------
        # Defining widget variable names
        # -----------------------------------------------

        my $CourseJBE;
        my $SectionJBE;
        my $TeacherJBE;
        my $LabJBE;
        my $BlockJBE;

        my $SectionEntry;
        my $TeacherFName;
        my $TeacherLName;
        my $BlockDescr;
        my $LabDscr;
        my $LabNumber;

        my $SectionNewBtn;
        my $TeacherNewBtn;
        my $BlockNewBtn;
        my $LabNewBtn;

        #----------------------------------------
        # Course widgets
        #----------------------------------------

        # course
        $CourseJBE = $db->JBrowseEntry(
            -variable  => \$curCourse,
            -state     => 'readonly',
            -choices   => \%courseName,
            -width     => 20,
            -browsecmd => [
                sub {
                    my $btn = ${ +shift };
                    $btn->configure( -state => 'normal' ),
                      my %rHash = reverse %courseName;
                    my $id      = $rHash{$curCourse};
                    $course = $Schedule->courses->get($id);
                    updateSectionList(
                                       \$SectionJBE,  \$BlockJBE,
                                       \%sectionName, \%blockName,
                                       \$curSection,  \$curBlock,
                                       \$OKAY,        \$BlockNewBtn
                    );
                },
                \$SectionNewBtn
            ]
        );

        my $courseDropEntry = $CourseJBE->Subwidget("entry");
        $courseDropEntry->configure( -disabledbackground => "white" );
        $courseDropEntry->configure( -disabledforeground => "black" );

        # ========================================================
        # section widgets
        # ========================================================
        $SectionJBE = $db->JBrowseEntry(
            -variable  => \$curSection,
            -state     => 'readonly',
            -width     => 20,
            -browsecmd => [
                sub {
                    my $btn = ${ +shift };
                    $btn->configure( -state => 'normal' );
                    my %rHash = reverse %sectionName;
                    my $id      = $rHash{$curSection};
                    $section = $course->get_section_by_id($id);
                    updateBlockList( \$BlockJBE, $section, \%blockName,
                                     \$curBlock, \$OKAY );
                    setDefaultTeacher( $section, \$curTeach );
                },
                \$BlockNewBtn
            ]
        );

        my $secDropEntry = $SectionJBE->Subwidget("entry");
        $secDropEntry->configure( -disabledbackground => "white" );
        $secDropEntry->configure( -disabledforeground => "black" );

        $SectionEntry = $db->Entry( -textvariable => \$newSection );

        $SectionNewBtn = $db->Button(
            -text    => "Create",
            -state   => 'disabled',
            -width   => 20,
            -command => sub {
                add_new_section(
                                 \$newSection, \%sectionName, \$SectionJBE,
                                 \$curSection, $OKAY,         \$BlockNewBtn,
                                 \$curBlock
                );
            }
        );

        # =====================================================
        # block
        # =====================================================
        $BlockJBE = $db->JBrowseEntry(
            -variable  => \$curBlock,
            -state     => 'readonly',
            -choices   => \%blockName,
            -width     => 20,
            -browsecmd => sub {
                my %rHash = reverse %blockName;
                my $id    = $rHash{$curBlock};
                $block = $section->get_block_by_id($id);
                $OKAY->configure( -state => 'normal' );
            }
        );
        my $blockDropEntry = $BlockJBE->Subwidget("entry");
        $blockDropEntry->configure( -disabledbackground => "white" );
        $blockDropEntry->configure( -disabledforeground => "black" );

        $BlockDescr = $db->Entry(
                                  -textvariable       => \$selectedBlockText,
                                  -state              => 'disabled',
                                  -disabledbackground => 'white'
        );

        $BlockNewBtn = $db->Button(
            -text    => "Create",
            -state   => 'disabled',
            -command => sub {
                add_new_block( \$section,  \%blockName, \$BlockJBE,
                               \$curBlock, \$OKAY );
            }
        );

        # =============================================
        # teacher
        # ============================================
        $TeacherJBE = $db->JBrowseEntry(
            -variable  => \$curTeach,
            -state     => 'readonly',
            -choices   => \%teacherName,
            -width     => 20,
            -browsecmd => sub {
                my %rHash = reverse %teacherName;
                my $id    = $rHash{$curTeach};
                $teacher = $Schedule->teachers->get($id);
            }
        );
        my $teacherDropEntry = $TeacherJBE->Subwidget("entry");
        $teacherDropEntry->configure( -disabledbackground => "white" );
        $teacherDropEntry->configure( -disabledforeground => "black" );

        $TeacherFName = $db->Entry( -textvariable => \$newFName );
        $TeacherLName = $db->Entry( -textvariable => \$newLName );

        $TeacherNewBtn = $db->Button(
            -text    => "Create",
            -command => sub {
                add_new_teacher( \$newFName,   \$newLName, \%teacherName,
                                 \$TeacherJBE, \$curTeach );
            }
        );

        # ======================================================
        # Lab
        # ======================================================
        $LabJBE = $db->JBrowseEntry(
            -variable  => \$curLab,
            -state     => 'readonly',
            -choices   => \%labName,
            -width     => 20,
            -browsecmd => sub {
                my %rHash = reverse %labName;
                my $id    = $rHash{$curLab};
                $lab = $Schedule->labs->get($id);
            }
        );
        my $labDropEntry = $LabJBE->Subwidget("entry");
        $labDropEntry->configure( -disabledbackground => "white" );
        $labDropEntry->configure( -disabledforeground => "black" );

        $LabNumber = $db->Entry( -textvariable => \$newLabNum );
        $LabDscr   = $db->Entry( -textvariable => \$newLabName );

        $LabNewBtn = $db->Button(
            -text    => "Create",
            -command => sub {
                add_new_lab( \$newLabNum, \$newLabName, \%labName,
                             \$LabJBE,    \$curLab );
            }
        );

        # -------------------------------------------------------
        # Widget Placement
        # -------------------------------------------------------
        # title
        $lblTitle->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );

        # course
        $db->Label( -text => '' )->grid( "-", "-", "-", -sticky => 'nsew' );
        $lblCourseInfo->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );
        $lblCourse->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );
        $CourseJBE->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );

        # section
        $lblSection->grid(
                           $lblCreateSection,
                           "-", "-",
                           -padx   => 2,
                           -sticky => 'nsew'
        );
        $SectionJBE->grid(
                           $SectionEntry, "-", $SectionNewBtn,
                           -padx   => 2,
                           -sticky => 'nsew'
        );

        # block
        $lblBlock->grid(
                         $lblCreateBlock,
                         "-", "-",
                         -padx   => 2,
                         -sticky => 'nsew'
        );
        $BlockJBE->grid(
                         $BlockDescr, "-", $BlockNewBtn,
                         -padx   => 2,
                         -sticky => 'nsew'
        );

        # teacher
        unless ( $type eq 'teacher' ) {
            $db->Label( -text => '' )
              ->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );
            $lblTeacherInfo->grid(
                                   "-", "-", "-",
                                   -padx   => 2,
                                   -sticky => 'nsew'
            );
            $lblTeacher->grid(
                               $lblCreateTeacher,
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
        }

        # lab
        unless ( $type eq 'lab' ) {
            $db->Label( -text => '' )
              ->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );
            $lblLabInfo->grid(
                               "-", "-", "-",
                               -padx   => 2,
                               -sticky => 'nsew'
            );
            $lblLab->grid(
                           $lblCreateLab,
                           "-", "-",
                           -padx   => 2,
                           -sticky => 'nsew'
            );
            $LabJBE->grid(
                           $LabNumber, $LabDscr,
                           $LabNewBtn,
                           -sticky => 'nsew',
                           -padx   => 2
            );
            $db->Label( -text => '' )
              ->grid( "-", "-", "-", -padx => 2, -sticky => 'nsew' );
        }

        #------------------------------------
        #Show menu
        #------------------------------------
        my $answer = $db->Show() || "Cancel";

        if ( $answer eq "Ok" ) {

            # check if a block is defined
            if ($block) {

                #if it is, assign all the properties to the block and return
                $block->day($day);
                $block->start( _hoursToString($start) );
                $block->duration($duration);
                $block->assign_lab($lab)         if $lab;
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
    my $BlockJBE    = ${ +shift };
    my $sectionName = shift;
    my $blockName   = shift;
    my $curSection  = shift;
    my $curBlock    = shift;
    my $OKAY        = ${ +shift };
    my $BlockNewBtn = ${ +shift };

    #Disable okay;
    $OKAY->configure( -state => 'disabled' );

    #Blanking the section and block inputs
    $$curSection = "";
    $section     = "";
    $$curBlock   = "";
    $block       = "";
    $BlockNewBtn->configure( -state => 'disabled' );

    # Blanking the choice hashes
    %$sectionName = ();
    %$blockName   = ();

    my @sections = $course->sections;

    foreach my $i (@sections) {
        $sectionName->{ $i->id } = "$i";
    }

    # Updating the Drop down with the new options
    $SectionJBE->configure( -choices => $sectionName );
    $BlockJBE->configure( -choices => $blockName );

}

# ----------------------------------------------------------------------------
# updateBlockList
# When a section is selected, the block menu has to change for the new Section
# ----------------------------------------------------------------------------

sub updateBlockList {

    my $BlockJBE  = ${ +shift };
    my $section   = shift;
    my $blockName = shift;
    my $curBlock  = shift;
    my $OKAY      = ${ +shift };

    #Disable okay;
    $OKAY->configure( -state => 'disabled' );

    #Blanking the block inputs
    $$curBlock = "";
    $block     = "";

    # Blanking the choice hashes
    %$blockName = ();

    my @blocks = $section->blocks;

    foreach my $i (@blocks) {
        $blockName->{ $i->id } = $i->print_description2;
    }

    # Updating the Drop down with the new options
    $BlockJBE->configure( -choices => $blockName );

}

# ============================================================================
# add_new_lab
# ============================================================================
sub add_new_lab {

    my $labNum     = shift;
    my $newLabName = shift;
    my $labName    = shift;
    my $LabJBE     = ${ +shift };
    my $curLab     = shift;

    # Check is a first and last name are inputed, otherwise return
    if ($$labNum) {

        #see if a teacher by that name exsits
        my $labNew = $Schedule->labs->get_by_number($$labNum);

        unless ($labNew) {

            #if no teacher by the inputed name exists, create a new teacher
            $labNew = Lab->new( -number => $$labNum,
                                -descr  => $$newLabName );
            $$labNum     = "";
            $$newLabName = "";
            $Schedule->labs->add($labNew);

            $labName->{ $labNew->id } = "$labNew";
            $LabJBE->configure( -choices => $labName );
            $$curLab = "$labNew";
            $lab     = $labNew;
        }
        else {

            #If a teacher exists by that name, ask the user if he would like
            #to set that teacher, otherwise return
            my $db = $frame->DialogBox( -title   => "Resource already exists",
                                        -buttons => [ "Yes", "No" ] );
            $db->Label( -text => "A Resource by this number already exsists!\n"
                        . "Do you want to set that resource?" )->pack;

            my $answer = $db->Show() || "";
            if ( $answer eq "Yes" ) {
                $$curLab     = "$labNew";
                $$labNum     = "";
                $$newLabName = "";
                $lab         = $labNew;
            }
        }
    }

}

# ============================================================================
# add new teacher
# ============================================================================

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

# ============================================================================
# set default teacher for a given section
# ============================================================================
sub setDefaultTeacher {
    my $section    = shift;
    my $curTeach   = shift;
    
    return if $type eq 'teacher';
    
    return unless $section;
    my $default_teacher = $section->default_teacher();
    return unless $default_teacher;

    $$curTeach = "$default_teacher";
    $teacher   = $default_teacher;
}

# ============================================================================
# add_new_section
# ============================================================================
sub add_new_section {

    my $name        = shift;
    my $sectionName = shift;
    my $SectionJBE  = ${ +shift };
    my $curSection  = shift;
    my $OKAY        = shift;
    my $BlockNewBtn = ${ +shift };
    my $curBlock    = shift;

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
                $$curSection = "$temp";
                $section     = $temp;
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
            $$curBlock   = "";
            $block       = "";
            $BlockNewBtn->configure( -state => 'normal' );
        }
        $OKAY->configure( -state => 'disabled' );
    }

}

# ============================================================================
# add_new_block
# ============================================================================
sub add_new_block {
    my $section   = ${ +shift };
    my $blockName = shift;
    my $BlockJBE  = ${ +shift };
    my $curBlock  = shift;
    my $OKAY      = ${ +shift };

    #If a section is defined, create a new block and set active block to it
    if ($section) {
        my $new = Block->new( -number => $section->get_new_number );
        $blockName->{ $new->id } = $new->print_description2;
        $$curBlock = $new->print_description2;
        $section->add_block($new);
        $BlockJBE->configure( -choices => $blockName );
        $block = $new;
        $OKAY->configure( -state => 'normal' );
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

# =================================================================
# footer
# =================================================================

=head1 AUTHOR

Sandy Bultena, Alex Oxorn

=head1 COPYRIGHT

Copyright (c) 2020, Sandy Bultena, Alex Oxorn. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;
