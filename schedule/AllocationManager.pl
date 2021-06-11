#!/usr/bin/perl
use strict;
use warnings;

package Allocation;

# ==================================================================
# Entry point for the Gui Allocation Management Tool
# ==================================================================
use FindBin;
use lib "$FindBin::Bin/";
use lib "$FindBin::Bin/Library";
our $BinDir = "$FindBin::Bin/";
use Schedule::Schedule;
use GuiSchedule::EditCourses;
use GuiSchedule::NumStudents;
use GuiSchedule::EditAllocation;
use PerlLib::Colours;
use GuiSchedule::DataEntry;

use Tk;
use Tk::InitGui;
use Tk::ToolBar;
use Tk::Table;
use Tk::Notebook;
use Tk::LabFrame;
use Tk::ROText;
use YAML;
$YAML::LoadBlessed = 1;    # default changed in YAML 1.30

use Tk::FindImages;
my $logo_file = Tk::FindImages::get_allocation_logo();
my $image_dir = Tk::FindImages::get_image_dir();

use Cwd 'abs_path';
use File::Basename;

# ==================================================================
# user preferences saved in ini file (YAML format)
# ==================================================================
my $User_base_dir;
my $Preferences = {};

# where to find the ini file?
if ( $^O =~ /darwin/i ) {    # Mac OS linux
    $User_base_dir = $ENV{"HOME"};
}
elsif ( $^O =~ /win/i ) {
    $User_base_dir = $ENV{"USERPROFILE"};
}
else {
    $User_base_dir = $ENV{"HOME"};
}

my $ini_file = "$User_base_dir/.allocation";

# read it already!
read_ini();

# ==================================================================
# global vars
# ==================================================================
my @semesters = (qw(fall winter));
our ( $mw, $Colours, $Fonts );
my %Schedules = (    # the current schedule
    fall   => '',
    winter => ''
);
my %Current_schedule_file = (    # will save to this file when save is requested
    fall   => '',
    winter => '',
);
my $Current_directory = $Preferences->{-current_dir} || $User_base_dir;

my $Status_bar;
my $Main_frame_height = 400;
my $Main_frame_width  = 800;
my $Notebook;
my %Pages;
my $Front_page_frame;
my $Main_page_frame;
my $Menu;
my $Toolbar;
my $Dirtyflag;
my $Dirty_symbol = "";

# ==================================================================
# pre-process procedures
# ==================================================================
$mw = MainWindow->new();
$mw->Frame( -height => $Main_frame_height )->pack( -side => 'left' );
$mw->geometry("1200x600");
$mw->protocol( 'WM_DELETE_WINDOW', \&exit_schedule );
( $Colours, $Fonts ) = InitGui->set($mw);
$Colours = {
    WorkspaceColour           => "#eeeeee",
    WindowForeground          => "black",
    SelectedBackground        => "#cdefff",
    SelectedForeground        => "#0000ff",
    DarkBackground            => "#cccccc",
    ButtonBackground          => "#abcdef",
    ButtonForeground          => "black",
    ActiveBackground          => "#89abcd",
    highlightbackground       => "#0000ff",
    ButtonHighlightBackground => "#ff0000",
    DataBackground            => "white",
    DataForeground            => "black",
};

SetSystemColours( $mw, $Colours );
$mw->configure( -bg => $Colours->{WorkspaceColour} );
( $Menu, $Toolbar ) = create_menu();

create_front_page();
$Status_bar = create_status_bar();

# ==================================================================
# post-process procedures
# - must be started after the mainloop has started
# ==================================================================
$mw->after( 500, \&set_dirty_label );

# ==================================================================
# ==================================================================
MainLoop;

system("pause");

# ==================================================================
# create menu and toolbar
# ==================================================================
sub create_menu {

    # get info about what goes in the menubar
    my ( $buttons, $b_props, $menu ) = menu_info();

    # create menu
    $mw->configure( -menu => my $menubar = $mw->Menu( -menuitems => $menu ) );

    # create toolbar
    my $toolbar = $mw->ToolBar(
        -buttonbg => $Colours->{WorkspaceColour},
        -hoverbg  => $Colours->{ActiveBackground},
    );

    # create all the buttons
    foreach my $button (@$buttons) {

        # if button not defined, insert a divider
        unless ($button) {
            $toolbar->bar();
            next;
        }

        # add button
        $toolbar->add(
            -name     => $button,
            -image    => "$image_dir/$button.gif",
            -command  => $b_props->{$button}{cb},
            -hint     => $b_props->{$button}{hn},
            -shortcut => $b_props->{$button}{sc},
        );

    }

    # pack the toolbar
    $toolbar->pack( -side => 'top', -expand => 0, -fill => 'x' );

    return ( $menubar, $toolbar );

}

# ==================================================================
# define what goes in the menu and toolbar
# ==================================================================
sub menu_info {

    # ----------------------------------------------------------
    # button names
    # ----------------------------------------------------------
    my @buttons =
      ( 'new_fall', 'new_winter', 'open_fall', 'open_winter', 'save', );

    # ----------------------------------------------------------
    # toolbar structure
    # ----------------------------------------------------------
    my %b_props = (
        new_fall => {
            cb => [ \&new_schedules, 'fall' ],
            hn => 'Create new fall File',
        },
        new_winter => {
            cb => [ \&new_schedules, 'winter' ],
            hn => 'Create new winter Files',
        },
        open_fall => {
            cb => [ \&open_schedule, "fall" ],
            hn => 'Open Fall Schedule File',
        },
        open_winter => {
            cb => [ \&open_schedule, "winter" ],
            hn => 'Open Winter Schedule File',
        },
        save => {
            cb => \&save_schedule,
            hn => "Save Schedule Files",
        },
    );

    # ----------------------------------------------------------
    # menu structure
    # ----------------------------------------------------------
    my $menu = [
        [
            qw/cascade File -tearoff 0 -menuitems/,
            [
                [
                    "command", "New Fall",
                    -accelerator => "Ctrl-n",
                    -command     => $b_props{new_fall}{cb},
                ],
                [
                    "command", "New Winter",
                    -accelerator => "Ctrl-n",
                    -command     => $b_props{new_winter}{cb},
                ],
                [
                    "command", "Open Fall",
                    -accelerator => "Ctrl-o",
                    -command     => $b_props{open_fall}{cb}
                ],
                [
                    "command", "Open Winter",
                    -accelerator => "Ctrl-o",
                    -command     => $b_props{open_winter}{cb}
                ],
                'separator',
                [
                    "command", "~Save",
                    -accelerator => "Ctrl-s",
                    -command     => $b_props{save}{cb}
                ],
                [ "command", "Save As", -command => \&save_as_schedule ],
                'separator',
                [
                    "command", "~Exit",
                    -accelerator => "Ctrl-e",
                    -command     => \&exit_schedule
                ],

            ],
        ],
    ];

    return \@buttons, \%b_props, $menu;

}

# ==================================================================
# create front page
# ==================================================================
sub create_front_page {

    my $button_width    = 50;
    my $short_file_name = 30;

    $Front_page_frame = $mw->Frame(
        -borderwidth => 10,
        -relief      => 'flat',
        -bg          => $Colours->{DataBackground},
    )->pack( -side => 'top', -expand => 1, -fill => 'both' );

    # --------------------------------------------------------------
    # logo
    # --------------------------------------------------------------

    # create an image object of the logo
    my $image = $mw->Photo( -file => $logo_file );

    # frame and label
    my $labelImage = $Front_page_frame->Label(
        '-image'     => $image,
        -borderwidth => 5,
        -relief      => 'flat'
    )->pack( -side => 'left', -expand => 0 );

    # --------------------------------------------------------------
    # frame for holding buttons for starting the allocation tasks
    # --------------------------------------------------------------
    my $option_frame = $Front_page_frame->Frame(
        -bg          => $Colours->{DataBackground},
        -borderwidth => 10,
        -relief      => 'flat'
    )->pack( -side => 'left', -expand => 1, -fill => 'both' );

    $option_frame->Frame( -background => $Colours->{DataBackground}, )
      ->pack( -expand => 1, -fill => 'both' );

    # --------------------------------------------------------------
    # create "open previous allocation files"" button
    # --------------------------------------------------------------

    # do all the files stored in the 'ini' file still exist?
    my $flag = 1;    # true
    foreach my $semester (@semesters) {
        $flag = 0
          unless $Preferences->{ "-current_$semester" . "_file" }
          && -e $Preferences->{ "-current_$semester" . "_file" };
    }

    # yes, all files stored in ini file still exists, make button
    if ($flag) {

        my %files = ();

        foreach my $semester (@semesters) {

            $files{$semester} =
              $Preferences->{ "-current_$semester" . "_file" };

            # make sure displayed names are not too long
            if ( defined $files{$semester}
                && length( $files{$semester} ) > $short_file_name )
            {
                $files{$semester} =
                  "(...) " . substr( $files{$semester}, -$short_file_name );
            }

        }

        # make button for opening all files
        my $text = "Open";
        foreach my $semester (@semesters) { $text .= "\n$files{$semester}"; }
        $option_frame->Button(
            -text        => $text,
            -font        => $Fonts->{big},
            -borderwidth => 0,
            -bg          => $Colours->{DataBackground},
            -command     => sub {
                foreach my $semester (@semesters) {
                    open_schedule( $semester,
                        $Preferences->{ "-current_" . $semester . "_file" } );
                }
            },
            -width  => $button_width,
            -height => 6,
        )->pack( -side => 'top', -fill => 'y', -expand => 0 );

    }

    # --------------------------------------------------------------
    # create new allocation files
    # --------------------------------------------------------------
    foreach my $semester (@semesters) {
        $option_frame->Button(
            -text        => "Create NEW $semester Schedule File",
            -font        => $Fonts->{big},
            -borderwidth => 0,
            -bg          => $Colours->{DataBackground},
            -command     => sub {
                new_schedule($semester);
                front_page_done();
            },
            -width  => $button_width,
            -height => 3,
        )->pack( -side => 'top', -fill => 'y', -expand => 0 );
    }

    # --------------------------------------------------------------
    # open schedule file
    # --------------------------------------------------------------

    foreach my $semester (@semesters) {
        $option_frame->Button(
            -text        => "Browse for $semester Schedule File",
            -font        => $Fonts->{big},
            -borderwidth => 0,
            -bg          => $Colours->{DataBackground},
            -command     => [ \&open_schedule, $semester ],
            -width       => $button_width,
            -height      => 3,
        )->pack( -side => 'top', -fill => 'y', -expand => 0 );

    }
    $option_frame->Frame( -bg => $Colours->{DataBackground} )->pack(
        -expand => 1,
        -fill   => 'both',
    );
}

# ==================================================================
# front_page_done (time to make standard page)
# ==================================================================
sub front_page_done {
    my $flag = 1;
    foreach my $semester (@semesters) {
        $flag = 0 unless $Schedules{$semester};
    }
    if ($flag) {
        $Front_page_frame->packForget();
        create_standard_page();
    }
}

# ==================================================================
# create standard page
# ==================================================================
sub create_standard_page {

    # frame and label
    $Main_page_frame = $mw->Frame(
        -borderwidth => 1,
        -relief      => 'ridge',
    )->pack( -side => 'top', -expand => 1, -fill => 'both' );

    # create notebook
    $Notebook =
      $Main_page_frame->NoteBook()->pack( -expand => 1, -fill => 'both' );

    # Allocation
    $Pages{"allocation"} = $Notebook->add(
        "allocation",
        -label    => "Allocation",
        -raisecmd => sub { draw_allocation() }
    );

    # student numbers
    $Pages{"student_numbers"} = $Notebook->add(
        "student_numbers",
        -label    => "Student Numbers",
        -raisecmd => sub { draw_student_numbers() }
    );

    # one page for each semester
    foreach my $semester (@semesters) {
        my $label =
          uc( substr( $semester, 0, 1 ) ) . ( substr( $semester, 1 ) );
        $Pages{$semester} = $Notebook->add(
            "$semester",
            -label    => $label,
            -raisecmd => sub {
                draw_edit_courses($semester);
                draw_edit_teachers($semester);
            }
        );
    }

    # Semester Courses and Teachers
    foreach my $semester (@semesters) {
        my $semester_notebook =
          $Pages{$semester}->NoteBook()->pack( -expand => 1, -fill => 'both' );

        my $label =
          uc( substr( $semester, 0, 1 ) ) . ( substr( $semester, 1 ) );
        $Pages{"courses_$semester"} = $semester_notebook->add(
            "courses_$semester",
            -label    => "$label Courses",
            -raisecmd => sub { draw_edit_courses($semester); }
        );

        $Pages{"teachers_$semester"} = $semester_notebook->add(
            "teachers_$semester",
            -label    => "$label Teachers",
            -raisecmd => sub { draw_edit_teachers($semester) }
        );
    }
}

# ==================================================================
# create status_bar
# ==================================================================
sub create_status_bar {
    my $red;
    if ( Colour->isLight( $Colours->{WorkspaceColour} ) ) {
        $red = "#880000";
    }
    else {
        $red = "#ff0000";
    }

    # frame and label
    my $status_frame = $mw->Frame(
        -borderwidth => 0,
        -relief      => 'flat',
    )->pack( -side => 'bottom', -expand => 0, -fill => 'x' );

    my $file_frame = $status_frame->Frame()
      ->pack( -side => 'left', -expand => 1, -fill => 'x' );

    # current files
    foreach my $semester (@semesters) {
        $file_frame->Label(
            -textvariable => \$Current_schedule_file{$semester},
            -borderwidth  => 1,
            -relief       => 'ridge',
        )->pack( -side => 'top', -expand => 1, -fill => 'x' );
    }

    # 'dirty' label
    $status_frame->Label(
        -textvariable => \$Dirty_symbol,
        -borderwidth  => 1,
        -relief       => 'ridge',
        -width        => 15,
        -fg           => $red,
    )->pack( -side => 'right', -fill => 'both' );

    return $status_frame;
}

# ==================================================================
# keep dirty label up to date
# ==================================================================
sub set_dirty_label {

    while (1) {

        # wait for DirtyFlag to change
        $mw->waitVariable( \$Dirtyflag );

        # set label accordingly
        if ($Dirtyflag) {
            $Dirty_symbol = "NOT SAVED";
        }
        else {
            $Dirty_symbol = "";
        }
    }
}

# ==================================================================
# new_schedule
# ==================================================================
sub new_schedule {

    my $semester = shift;
    $Schedules{$semester} = Schedule->new();
    undef $Current_schedule_file{$semester};

    # if we are in standard view, update the view page
    if ($Notebook) {

        # TODO: what will be our default view?
        # $Notebook->raise('views');
    }
    $Dirtyflag = 0;
}

# ==================================================================
# save (as) schedule
# ==================================================================
sub save_schedule {
    _save_schedule(0);
}

sub save_as_schedule {
    _save_schedule(1);
}

sub _save_schedule {
    my $save_as = shift;

    # --------------------------------------------------------------
    # There is no schedule to save!
    # --------------------------------------------------------------
    my $flag = 0;
    foreach my $semester (@semesters) { $flag = 1 if $Schedules{$semester}; }
    unless ($flag) {
        $mw->messageBox(
            -title   => 'Save Schedule',
            -message => 'There are no allocation / schedules to save!',
            -type    => 'OK',
            -icon    => 'error'
        );
        return;
    }

    my %files = ();

    foreach my $semester (@semesters) {

        # ----------------------------------------------------------
        # get files to save to (if save (as) has been requested)
        # ----------------------------------------------------------
        if ( $save_as || !$Current_schedule_file{$semester} ) {
            $files{$semester} = $mw->getSaveFile(
                -initialdir => $Current_directory,
                -title => "Save file for $semester",
                -filetypes =>
                  [ [ "Schedule Files", ".yaml" ], [ "All Files", "*" ] ]
            );

            # if cancel has been pressed
            return unless $files{$semester};
        }

        # ----------------------------------------------------------
        # or use current file name
        # ----------------------------------------------------------
        else {
            $files{$semester} = $Current_schedule_file{$semester};
        }

        # ----------------------------------------------------------
        # save YAML output of file
        # ----------------------------------------------------------
        eval { $Schedules{$semester}->write_YAML( $files{$semester} ) };
        if ($@) {
            $mw->messageBox(
                -title   => "Save Schedule",
                -message => "Cannot save schedule\nERROR:$@",
                -type    => "OK",
                -icon    => "error"
            );
            return;
        }

        # ----------------------------------------------------------
        # save the current file info for later use
        # ----------------------------------------------------------
        $Current_directory = dirname( $files{$semester} );
        $Current_schedule_file{$semester} = abs_path( $files{$semester} );
    }

    # save the current file info for later use
    $Dirtyflag = 0;
    write_ini();

    return;

}

# ==================================================================
# open_schedule
# ==================================================================
sub open_schedule {

    my $semester = shift;
    my $file     = shift;

    # get file to open
    unless ( $file && -e $file ) {
        $file = "";
        $file = $mw->getOpenFile(
            -initialdir => $Current_directory,
            -filetypes  => [ [ "Schedules", ".yaml" ], [ "All Files", "*" ] ]
        );
    }

    # if user has chosen file...
    if ($file) {

        # get YAML input of file
        eval { $Schedules{$semester} = Schedule->read_YAML($file) };
        if ( $@ || !$Schedules{$semester} ) {
            $mw->messageBox(
                -title   => 'Read Allocation / Schedule',
                -message => "Cannot read schedule\nERROR:$@",
                -type    => 'OK',
                -icon    => 'error'
            );
            undef $file;
        }
    }

    # if schedule successfully read, then
    if ( $file && $Schedules{$semester} ) {
        $Current_schedule_file{$semester} = abs_path($file);
        $Current_directory = dirname($file);
        write_ini();
    }

    # update the overview page
    if ($Notebook) {

        # $Notebook->raise('views');
        # TODO: what is going to be our front page?
        # draw_view_choices();
    }
    else {
        front_page_done();
    }

    $Dirtyflag = 0;
    return;
}

# ==================================================================
# exit_schedule
# ==================================================================
sub exit_schedule {

    if ($Dirtyflag) {
        my $ans = $mw->messageBox(
            -title   => 'Unsaved Changes',
            -message => "There are unsaved changes\n"
              . "Do you want to save them?",
            -type => 'YesNoCancel',
            -icon => 'question'
        );
        if ( $ans eq 'Yes' ) {
            save_schedule();
        }
        elsif ( $ans eq 'Cancel' ) {
            return;
        }
    }

    write_ini();

    $mw->destroy();
    CORE::exit();
}

# ==================================================================
# read_ini
# ==================================================================
sub read_ini {

    if ( $User_base_dir && -e $ini_file ) {
        local $/ = undef;
        open my $fh, "<", $ini_file or return;
        eval { $Preferences = Load(<$fh>) };
        close $fh;
    }
}

# ==================================================================
# write_ini
# ==================================================================
sub write_ini {

    # open file
    open my $fh, ">", $ini_file or return;

    # print YAML output
    $Preferences->{-current_dir}  = $Current_directory;
    $Preferences->{-current_file} = '';
    foreach my $semester (@semesters) {
        if ( $Current_schedule_file{$semester} ) {
            $Preferences->{ "-current_$semester" . "_file" } =
              abs_path( $Current_schedule_file{$semester} );
        }
    }
    eval { print $fh Dump($Preferences); };

    # finish up
    close $fh;
}

# ==================================================================
# draw_edit_teachers
# ==================================================================

{
    my %de = ();

    sub draw_edit_teachers {
        my $semester = shift;
        die("draw_edit_courses did not specify a semester\n") unless $semester;

        if ( $de{$semester} ) {
            $de{$semester}->refresh( $Schedules{$semester}->teachers );
        }
        else {
            my $f = $Pages{"teachers_$semester"};
            $de{$semester} =
              DataEntry->new( $f, $Schedules{$semester}->teachers,
                $Schedules{$semester}, \$Dirtyflag, undef );
        }
    }
}

# ==================================================================
# draw_student_numbers
# ==================================================================

{
    my $de;

    sub draw_student_numbers {

        if ($de) {
            $de->refresh( \%Schedules );
        }
        else {
            my $f = $Pages{"student_numbers"};
            $de = NumStudents->new( $f, \%Schedules, \$Dirtyflag );
        }
    }
}

# ==================================================================
# draw_edit_courses
# ==================================================================
sub draw_edit_courses {

    my $semester = shift;
    die("draw_edit_courses did not specify a semester\n")
      unless $semester;
    my $f = $Pages{"courses_$semester"};

    EditCourses->new( $f, $Schedules{$semester}, \$Dirtyflag,
        $Colours, $Fonts, undef );

}

# ==================================================================
# draw_allocation
# ==================================================================
{
    my $de;

    sub draw_allocation {
        my $f = $Pages{"allocation"};
        unless ($de) {
        $de = EditAllocation->new(
            $f,       \%Schedules, \$Dirtyflag,
            $Colours, $Fonts,     undef
        ) }
        else {
            $de->draw();
        }
    }

}
