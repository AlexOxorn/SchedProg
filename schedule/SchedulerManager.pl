#!/usr/bin/perl
use strict;
use warnings;

package Scheduler;

# ==================================================================
# Entry point for the Gui Schedule Management Tool
# ==================================================================
use FindBin;
use lib "$FindBin::Bin/";
use lib "$FindBin::Bin/Library";
our $BinDir = "$FindBin::Bin/";
use Schedule::Schedule;
use Export::PDF;
use Export::Latex;
use GuiSchedule::View;
use GuiSchedule::GuiSchedule;
use GuiSchedule::DataEntry;
use GuiSchedule::EditCourses;
use Schedule::Conflict;
use PerlLib::Colours;
use GuiSchedule::AssignToResource;

use Export::CSV;
use Export::Excel;

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
my $logo_file = Tk::FindImages::get_logo();
my $image_dir = Tk::FindImages::get_image_dir();

use Cwd 'abs_path';
use File::Basename;

#use Data::Dumper;
#my @libraries = sort values %INC;
#print Dumper \@libraries;
#die;

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

# read it already!
read_ini();

# ==================================================================
# global vars
# ==================================================================
our ( $mw, $Colours, $Fonts );
my $Schedule;                 # the current schedule
my $Current_schedule_file;    # will save to this file when save is requested
my $Current_directory = $Preferences->{-current_dir} || $User_base_dir;

my $Status_bar;
my $Main_frame_height = 400;
my $Main_frame_width  = 800;
my $Notebook;
my %Pages;
my $OverviewNotebook;
my %OverviewPages;
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
$mw->geometry("600x600");
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

my $guiSchedule    = GuiSchedule->new( $mw, \$Dirtyflag, \$Schedule );
my $exportSchedule = GuiSchedule->new( $mw, \$Dirtyflag, \$Schedule );

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
    my @buttons = ( 'new', 'open', 'CSVimport', 'save', );

    # ----------------------------------------------------------
    # toolbar structure
    # ----------------------------------------------------------
    my %b_props = (
        new => {
            cb => \&new_schedule,
            hn => 'Create new Schedule File',
        },
        open => {
            cb => \&open_schedule,
            hn => 'Open Schedule File',
        },
        CSVimport => {
            cb => \&import_schedule,
            hn => 'Import Schedule from CSV'
        },
        CSVexport => {
            cb => \&generate_csv,
            hn => 'Save entire schedule as a CSV'
        },
        pdf_teachers => {
            cb => [ \&print_views, 'PDF', 'teacher' ],
            hn => 'Print to pdf of Teacher Schedules',
        },
        pdf_streams => {
            cb => [ \&print_views, 'PDF', 'stream' ],
            hn => 'Print to pdf of Stream Schedules',
        },
        pdf_labs => {
            cb => [ \&print_views, 'PDF', 'lab' ],
            hn => 'Print to pdf of Lab Schedules',
        },
        pdf_text => {
            cb => [ \&print_views, 'PDF', 'text' ],
            hn => 'Text output of schedules (good for registrar)',
        },
        latex_teachers => {
            cb => [ \&print_views, 'Latex', 'teacher' ],
            hn => 'Print to pdf of Teacher Schedules',
        },
        latex_streams => {
            cb => [ \&print_views, 'Latex', 'stream' ],
            hn => 'Print to pdf of Stream Schedules',
        },
        latex_labs => {
            cb => [ \&print_views, 'Latex', 'lab' ],
            hn => 'Print to pdf of Lab Schedules',
        },
        latex_text => {
            cb => [ \&print_views, 'Latex', 'text' ],
            hn => 'Text output of schedules (good for registrar)',
        },
        save => {
            cb => \&save_schedule,
            hn => "Save Schedule File",
        },
        junk => {
            cb => \&junkA,
            hn => "JUNK",
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
                    "command", "~New",
                    -accelerator => "Ctrl-n",
                    -command     => $b_props{new}{cb},
                ],
                [
                    "command", "~Open",
                    -accelerator => "Ctrl-o",
                    -command     => $b_props{open}{cb}
                ],
                [ "command", "~Import CSV", -command => $b_props{import}{cb} ],
                'separator',
                [
                    "command", "~Save",
                    -accelerator => "Ctrl-s",
                    -command     => $b_props{save}{cb}
                ],
                [ "command", "Save As", -command => \&save_as_schedule ],
                [
                    "command", "Save As CSV",
                    -command => $b_props{CSVexport}{cb}
                ],
                'separator',
                [
                    "command", "~Exit",
                    -accelerator => "Ctrl-e",
                    -command     => \&exit_schedule
                ],

            ],
        ],
        [
            qw/cascade Print -tearoff 0 /,
            -menuitems => [
                [
                    qw/cascade PDF -tearoff 0/,
                    -menuitems => [
                        [
                            "command",
                            "Teacher Schedules",
                            -command => $b_props{pdf_teachers}{cb},
                        ],
                        [
                            "command",
                            "Lab Schedules",
                            -command => $b_props{pdf_labs}{cb},
                        ],
                        [
                            "command",
                            "Stream Schedules",
                            -command => $b_props{pdf_streams}{cb},
                        ],
                        'separator',
                        [
                            "command", "Text Output",
                            -command => $b_props{pdf_text}{cb},
                        ],
                    ],
                ],
                [
                    qw/cascade Latex -tearoff 0/,
                    -menuitems => [
                        [
                            "command",
                            "Teacher Schedules",
                            -command => $b_props{latex_teachers}{cb},
                        ],
                        [
                            "command",
                            "Lab Schedules",
                            -command => $b_props{latex_labs}{cb},
                        ],
                        [
                            "command",
                            "Stream Schedules",
                            -command => $b_props{latex_streams}{cb},
                        ],
                        'separator',
                        [
                            "command", "Text Output",
                            -command => $b_props{latex_text}{cb},
                        ],
                    ],
                ],
                [
                    qw/cascade CSV -tearoff 0/,
                    -menuitems => [
                        [
                            "command",
                            "Save schedule as CSV",
                            -command => $b_props{CSVexport}{cb},
                        ],
                    ],
                ],
            ],
        ],
    ];

    # ------------------------------------------------------------------------
    # bind all of the 'accelerators
    # ------------------------------------------------------------------------
    $mw->bind( '<Control-Key-o>', $b_props{open}{cb} );
    $mw->bind( '<Control-Key-s>', $b_props{save}{cb} );
    $mw->bind( '<Control-Key-n>', $b_props{new}{cb} );
    $mw->bind( '<Control-Key-e>', \&exit_schedule );

    # if darwin, also bind the 'command' key for MAC users
    if ( $^O =~ /darwin/ ) {
        $mw->bind( '<Meta-Key-o>', $b_props{open}{cb} );
        $mw->bind( '<Meta-Key-s>', $b_props{save}{cb} );
        $mw->bind( '<Meta-Key-n>', $b_props{new}{cb} );
        $mw->bind( '<Meta-Key-e>', \&exit_schedule );
    }
    return \@buttons, \%b_props, $menu;

}

sub junkA {    ## WTF !!!
    EditLabs->new( $mw, $Schedule, \$Dirtyflag, $Colours, $Fonts, $image_dir,
        $guiSchedule );

}

# ==================================================================
# create front page
# ==================================================================
sub create_front_page {

    my $button_width    = 50;
    my $short_file_name = 40;

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
    # frame for holding buttons for starting the scheduling tasks
    # --------------------------------------------------------------
    my $option_frame = $Front_page_frame->Frame(
        -bg          => $Colours->{DataBackground},
        -borderwidth => 10,
        -relief      => 'flat'
    )->pack( -side => 'left', -expand => 1, -fill => 'both' );

    $option_frame->Frame( -background => $Colours->{DataBackground}, )
      ->pack( -expand => 1, -fill => 'both' );

    # --------------------------------------------------------------
    # open previous schedule file
    # --------------------------------------------------------------
    if ( $Preferences->{-current_file} && -e $Preferences->{-current_file} ) {

        # make sure name displayed is not too long
        my $file = $Preferences->{-current_file};
        if ( length($file) > $short_file_name ) {
            $file = "(...) " . substr( $file, -$short_file_name );
        }

        $option_frame->Button(
            -text        => "Open $file",
            -font        => $Fonts->{big},
            -borderwidth => 0,
            -bg          => $Colours->{DataBackground},
            -command     => sub {
                open_schedule( $Preferences->{-current_file} );
            },
            -width  => $button_width,
            -height => 3,
        )->pack( -side => 'top', -fill => 'y', -expand => 0 );
    }

    # --------------------------------------------------------------
    # create new schedule file
    # --------------------------------------------------------------
    $option_frame->Button(
        -text        => "Create NEW Schedule File",
        -font        => $Fonts->{big},
        -borderwidth => 0,
        -bg          => $Colours->{DataBackground},
        -command     => sub {
            new_schedule();
            $Front_page_frame->packForget();
            create_standard_page();
        },
        -width  => $button_width,
        -height => 3,
    )->pack( -side => 'top', -fill => 'y', -expand => 0 );

    # --------------------------------------------------------------
    # open schedule file
    # --------------------------------------------------------------
    $option_frame->Button(
        -text        => "Browse for Schedule File",
        -font        => $Fonts->{big},
        -borderwidth => 0,
        -bg          => $Colours->{DataBackground},
        -command     => \&open_schedule,
        -width       => $button_width,
        -height      => 3,
    )->pack( -side => 'top', -fill => 'y', -expand => 0 );

    $option_frame->Frame( -bg => $Colours->{DataBackground} )->pack(
        -expand => 1,
        -fill   => 'both',
    );
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

    # View page
    $Pages{'views'} = $Notebook->add(
        'views',
        -label    => 'Schedules',
        -raisecmd => \&draw_view_choices
    );
    $Pages{'overview'} = $Notebook->add(
        'overview',
        -label    => 'Overview',
        -raisecmd => \&draw_overview
    );
    $Pages{'courses'} = $Notebook->add(
        'courses',
        -label    => 'Courses',
        -raisecmd => \&draw_edit_courses
    );
    $Pages{'teachers'} = $Notebook->add(
        'teachers',
        -label    => 'Teachers',
        -raisecmd => \&draw_edit_teachers
    );
    $Pages{'labs'} = $Notebook->add(
        'labs',
        -label    => 'Resources',
        -raisecmd => \&draw_edit_labs
    );
    $Pages{'streams'} = $Notebook->add(
        'streams',
        -label    => 'Streams',
        -raisecmd => \&draw_edit_streams
    );
    $Pages{'export'} = $Notebook->add(
        'export',
        -label    => 'Excel',
        -raisecmd => \&draw_export_schedule
    );

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

    $status_frame->Label(
        -textvariable => \$Current_schedule_file,
        -borderwidth  => 1,
        -relief       => 'ridge',
    )->pack( -side => 'left', -expand => 1, -fill => 'x' );

    $status_frame->Label(
        -textvariable => \$Dirty_symbol,
        -borderwidth  => 1,
        -relief       => 'ridge',
        -width        => 15,
        -fg           => $red,
    )->pack( -side => 'right', -fill => 'x' );

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

    # TODO: close all views, empty the GuiSchedule array of views, etc.
    $guiSchedule->destroy_all;

    # TODO: save previous schedule?
    $Schedule = Schedule->new();

    undef $Current_schedule_file;

    # if we are in standard view, update the view page
    if ($Notebook) {
        $Notebook->raise('views');
        draw_view_choices();
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

    # There is no schedule to save!
    unless ($Schedule) {
        $mw->messageBox(
            -title   => 'Save Schedule',
            -message => 'There is no schedule to save!',
            -type    => 'OK',
            -icon    => 'error'
        );
        return;
    }

    # get file to save to
    my $file;
    if ( $save_as || !$Current_schedule_file ) {
        $file = $mw->getSaveFile(
            -initialdir => $Current_directory,
            -filetypes =>
              [ [ "Schedule Files", ".yaml" ], [ "All Files", "*" ] ]
        );
        return unless $file;
    }
    else {
        $file = $Current_schedule_file;
    }

    # save YAML output of file
    eval { $Schedule->write_YAML($file) };
    if ($@) {
        $mw->messageBox(
            -title   => "Save Schedule",
            -message => "Cannot save schedule\nERROR:$@",
            -type    => "OK",
            -icon    => "error"
        );
        return;
    }

    # save the current file info for later use
    $Current_schedule_file = abs_path($file);
    $Current_directory     = dirname($file);
    $Dirtyflag             = 0;
    write_ini();
    return;

}

# ==================================================================
# open_schedule
# ==================================================================
sub open_schedule {

    my $file = shift;

    # TODO: close all views, empty the GuiSchedule array of views, etc.
    $guiSchedule->destroy_all;

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
        eval { $Schedule = Schedule->read_YAML($file) };
        if ( $@ || !$Schedule ) {
            $mw->messageBox(
                -title   => 'Read Schedule',
                -message => "Cannot read schedule\nERROR:$@",
                -type    => 'OK',
                -icon    => 'error'
            );
            undef $file;
        }
    }

    # if schedule successfully read, then
    if ( $file && $Schedule ) {
        $Current_schedule_file = abs_path($file);
        $Current_directory     = dirname($file);
        write_ini();
    }

    # update the overview page
    if ($Notebook) {
        $Notebook->raise('views');
        draw_view_choices();
    }
    else {
        $Front_page_frame->packForget();
        create_standard_page();
    }

    $Dirtyflag = 0;
    return;
}

# ==================================================================
# print_views
# ==================================================================
{
    my $wait;

    sub print_views {
        my $print_type = shift;
        my $type       = shift;

        # --------------------------------------------------------------
        # no schedule yet
        # --------------------------------------------------------------
        unless ($Schedule) {
            $mw->messageBox(
                -message => 'Cannot export - There is no schedule',
                -title   => "Export",
                -type    => 'OK',
                -icon    => 'error'
            );
            return;
        }

        # --------------------------------------------------------------
        # cannot print if the schedule is not saved
        # --------------------------------------------------------------
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
            else {
                return;
            }
        }

        # --------------------------------------------------------------
        # define base file name
        # --------------------------------------------------------------
        my $file = $Current_schedule_file;
        $file =~ s/\.yaml$//;

        if ( !Exists($wait) ) {
            $wait = $mw->Toplevel();
            $wait->title("Printing");
            $wait->Label( -text => 'Please Wait while we process the files', )
              ->pack( -expand => 1, -fill => 'both' );

            #$wait->overrideredirect(1);
            $wait->geometry("300x450");
        }
        else { $wait->deiconify(); $wait->raise(); }
        $mw->update();

        # -------------------------------------------------------------------
        # text overview
        # -------------------------------------------------------------------
        if ( lc($type) eq "text" ) {
            $print_type->newReport( $Schedule, $file . "_text" );
        }

        # -------------------------------------------------------------------
        # views
        # -------------------------------------------------------------------
        else {
            my @objs;

            @objs = $Schedule->all_teachers() if lc($type) eq "teacher";
            @objs = $Schedule->all_streams()  if lc($type) eq "stream";
            @objs = $Schedule->all_labs()     if lc($type) eq "lab";

            foreach my $obj (@objs) {
                $print_type->newView( $Schedule, $obj,
                    $file . "_$type" . " $obj" );
            }
        }

        $wait->withdraw();
        $mw->messageBox(
            -message => "$type $print_type views created\n$file*.pdf",
            -title   => "Export",
            -type    => 'OK',
            -icon    => 'info'
        );
        return;
    }
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
# import_schedule
# ==================================================================

sub import_schedule {
    my $file = shift;

    # TODO: close all views, empty the GuiSchedule array of views, etc.
    $guiSchedule->destroy_all;

    # get file to open
    unless ( $file && -e $file ) {
        $file = "";
        $file = $mw->getOpenFile(
            -initialdir => $Current_directory,
            -filetypes =>
              [ [ 'Comma Separated Value', '.csv' ], [ 'All', '*' ] ]
        );
    }

    # if user has chosen file...
    if ($file) {

        # get CSV input of file
        eval { $Schedule = CSV->import_csv($file) };
        if ( $@ || !$Schedule ) {
            $mw->messageBox(
                -title   => 'Read Schedule',
                -message => "Cannot read CSV\nERROR:$@",
                -type    => 'OK',
                -icon    => 'error'
            );
            undef $file;
        }
    }

    # if schedule successfully read, then
    if ( $file && $Schedule ) {

        #$Current_schedule_file = abs_path($file);
        $Current_directory = dirname($file);
        write_ini();
    }

    # update the view page
    if ($Notebook) {
        $Notebook->raise('views');
        draw_view_choices();
    }
    else {
        $Front_page_frame->packForget();
        create_standard_page();
    }
    $Dirtyflag = 1;
    return;
}

# ==================================================================
# read_ini
# ==================================================================
sub read_ini {

    if ( $User_base_dir && -e "$User_base_dir/.schedule" ) {
        local $/ = undef;
        open my $fh, "<", "$User_base_dir/.schedule" or return;
        eval { $Preferences = Load(<$fh>) };
        close $fh;
    }
}

# ==================================================================
# write_ini
# ==================================================================
sub write_ini {

    # open file
    open my $fh, ">", "$User_base_dir/.schedule" or return;

    # print YAML output
    $Preferences->{-current_dir}  = $Current_directory;
    $Preferences->{-current_file} = '';
    if ($Current_schedule_file) {
        $Preferences->{-current_file} = abs_path($Current_schedule_file);
    }
    eval { print $fh Dump($Preferences); };

    # finish up
    close $fh;
}

# ==================================================================
# draw_view_choices
# ==================================================================
{
    my $frame;

    sub draw_view_choices {
        my $f = $Pages{views};

        $frame->destroy if $frame;

        $frame = $f->Frame->pack( -expand => 1, -fill => 'both' );

        my $tview =
          $frame->LabFrame( -label => 'Teacher views', )
          ->pack( -expand => 1, -fill => 'both' );

        my $tview2 =
          $tview->Scrolled( 'Frame', -scrollbars => "osoe" )
          ->pack( -expand => 1, -fill => 'both' );

        my $lview =
          $frame->LabFrame( -label => 'Resource views', )
          ->pack( -expand => 1, -fill => 'both' );

        my $lview2 =
          $lview->Scrolled( 'Frame', -scrollbars => "osoe" )
          ->pack( -expand => 1, -fill => 'both' );

        my $sview =
          $frame->LabFrame( -label => 'Stream views', )
          ->pack( -expand => 1, -fill => 'both' );

        my $sview2 =
          $sview->Scrolled( 'Frame', -scrollbars => "osoe" )
          ->pack( -expand => 1, -fill => 'both' );

        $guiSchedule->reset_button_refs();
        $guiSchedule->create_frame( $tview2, 'teacher' );
        $guiSchedule->create_frame( $lview2, 'lab' );
        $guiSchedule->create_frame( $sview2, 'stream' );
    }
}

# ==================================================================
# draw_overview
# ==================================================================

{

    sub draw_overview {

        my $f = $Pages{overview};

        unless ($OverviewNotebook) {
            $OverviewNotebook =
              $f->NoteBook()->pack( -expand => 1, -fill => 'both' );

            $OverviewPages{'course2'} = $OverviewNotebook->add(
                'course2',
                -label => 'by Course',

                #-raisecmd => \&draw_overview_course,
            );

            $OverviewPages{'teacher2'} = $OverviewNotebook->add(
                'teacher2',
                -label => 'by Teacher',

                #-raisecmd => \&draw_overview_teacher,
            );

        }
        draw_overview_course();
        draw_overview_teacher();

    }
}

# ============================================================
# Draw Course Overview
# ============================================================

{
    my $tbox;

    sub draw_overview_course {
        my $f = $OverviewPages{'course2'};

        unless ($tbox) {
            $tbox = $f->Scrolled(
                'ROText',
                -height     => 20,
                -width      => 50,
                -scrollbars => 'osoe',
                -wrap       => 'none'
            )->pack( -expand => 1, -fill => 'both' );
        }

        $tbox->delete( "1.0", 'end' );

        # if schedule, show info
        if ($Schedule) {
            unless ( $Schedule->all_courses ) {
                $tbox->insert( 'end', 'No courses defined in this schedule' );
            }
            else {
                foreach my $c ( sort { $a->number cmp $b->number }
                    $Schedule->all_courses )
                {
                    $tbox->insert( 'end', "$c" );
                }
            }
        }

        # if no schedule, show info
        else {
            $tbox->insert( 'end', 'There is no schedule, please open one' );
        }

    }
}

# ==================================================================
# Draw Teacher Overview
# ==================================================================

{
    my $tbox2;

    sub draw_overview_teacher {
        my $f = $OverviewPages{'teacher2'};

        unless ($tbox2) {
            $tbox2 = $f->Scrolled(
                'ROText',
                -height     => 20,
                -width      => 50,
                -scrollbars => 'osoe',
                -wrap       => 'none'
            )->pack( -expand => 1, -fill => 'both' );
        }
        $tbox2->delete( "1.0", 'end' );

        # if schedule, show info
        if ($Schedule) {
            unless ( $Schedule->all_teachers ) {
                $tbox2->insert( 'end', 'No teachers defined in this schedule' );
            }
            else {
                foreach
                  my $t ( sort { lc( $a->lastname ) cmp lc( $b->lastname ) }
                    $Schedule->all_teachers )
                {
                    $tbox2->insert( 'end', $Schedule->teacher_details($t) );
                }
            }
        }

        # if no schedule, show info
        else {
            $tbox2->insert( 'end', 'There is no schedule, please open one' );
        }

    }
}

# ==================================================================
# draw_edit_teachers
# ==================================================================
{
    my $de;
    {

        sub draw_edit_teachers {

            my $f = $Pages{teachers};
            if ($de) {
                $de->refresh( $Schedule->teachers );
            }
            else {
                $de = DataEntry->new( $f, $Schedule->teachers, $Schedule,
                    \$Dirtyflag, $guiSchedule );
            }
        }
    }
}

# ==================================================================
# draw_edit_streams
# ==================================================================
{
    my $de;
    {

        sub draw_edit_streams {

            my $f = $Pages{streams};
            if ($de) {
                $de->refresh( $Schedule->streams );
            }
            else {
                $de = DataEntry->new( $f, $Schedule->streams, $Schedule,
                    \$Dirtyflag, $guiSchedule );
            }
        }
    }
}

# ==================================================================
# draw_edit_labs
# ==================================================================
{
    my $de;
    {

        sub draw_edit_labs {

            my $f = $Pages{labs};
            if ($de) {
                $de->refresh( $Schedule->labs );
            }
            else {
                $de = $de =
                  DataEntry->new( $f, $Schedule->labs, $Schedule, \$Dirtyflag,
                    $guiSchedule );
            }

        }
    }
}

# ==================================================================
# draw_edit_courses
# ==================================================================
sub draw_edit_courses {
    my $f = $Pages{courses};
    EditCourses->new( $f, $Schedule, \$Dirtyflag, $Colours, $Fonts,
        $guiSchedule );
}

# ==================================================================
# draw_export_schedule
# ==================================================================
# ************* THE FOLLOWING CODE SHOULD BE IN ITS OWN FILE *******
{
    my $frame;
    my $exportFrame;
    my $exportFrameDirty;
    my $currentExport;
    my @exportFormats;
    my %selected;

    sub draw_export_schedule {
        my $f = $Pages{export};

        # cleanup from last iteration
        $frame->destroy if $frame;
        $exportFrameDirty = 0;

        $frame = $f->Frame->pack( -expand => 1, -fill => 'both' );

=comment
        my $exportList =
          $frame->Scrolled(
                            'Listbox',
                            -scrollbars => 'oe',
                            -height     => scalar(@exportFormats)
          )->pack( -side => 'top', -fill => 'x' )->Subwidget('listbox');

        @exportFormats = ( "Excel (*.xlsx)", "Comma Separated Value (*.csv)" );
        $currentExport = -1;

        foreach my $exportFormat (@exportFormats) {
            $exportList->insert( 'end', $exportFormat );
        }
        $exportList->selectionSet(0);
        change_format($exportList);

        $exportList->bind( "<<ListboxSelect>>", [ \&change_format ] );
=cut

        change_format();
    }

    sub change_format {

        #my $exportList = shift;

        $exportFrame->destroy if $exportFrameDirty;

        #my $selection = $exportList->curselection->[0];

        # not sure why this is here... because other developers
        # DON"T COMMENT... gonna ignore it for now
        # return if ( $selection == $currentExport );

        #$currentExport = $selection;

        #if ( $currentExport == 0 ) {
        draw_excel_export();

        #}
        #elsif ( $currentExport == 1 ) {
        #    draw_csv_export();
        #}
    }

    # -----------------------------------------------------------------
    # set up and draw csv
    # -----------------------------------------------------------------
    sub draw_csv_export() {

        $exportFrame = $frame->Frame->pack( -expand => 1, -fill => 'both' );
        $exportFrameDirty = 1;

        my $exportButton = $exportFrame->Button(
            -text    => "Export",
            -command => [ \&generate_csv ]
        )->pack( -side => 'bottom', -fill => 'x' );

    }

    # -----------------------------------------------------------------
    # set up and draw excel... choose which stuff we want exported
    # -----------------------------------------------------------------
    sub draw_excel_export() {

        $exportFrame = $frame->Frame->pack( -expand => 1, -fill => 'both' );
        $exportFrameDirty = 1;

        my $tview =
          $exportFrame->LabFrame( -label => 'Teacher views', )
          ->pack( -expand => 1, -fill => 'both' );

        my $tview2 =
          $tview->Scrolled( 'Frame', -scrollbars => "osoe" )
          ->pack( -expand => 1, -fill => 'both' );

        my $lview =
          $exportFrame->LabFrame( -label => 'Resource views', )
          ->pack( -expand => 1, -fill => 'both' );

        my $lview2 =
          $lview->Scrolled( 'Frame', -scrollbars => "osoe" )
          ->pack( -expand => 1, -fill => 'both' );

        my $sview =
          $exportFrame->LabFrame( -label => 'Stream views', )
          ->pack( -expand => 1, -fill => 'both' );

        my $sview2 =
          $sview->Scrolled( 'Frame', -scrollbars => "osoe" )
          ->pack( -expand => 1, -fill => 'both' );

        my $exportButton = $exportFrame->Button(
            -text    => "Export",
            -command => [ \&generate_excel ]
        )->pack( -side => 'bottom', -fill => 'x' );

        $exportSchedule->create_frame( $tview2, 'teacher',  \&toggle );
        $exportSchedule->create_frame( $lview2, 'resource', \&toggle );
        $exportSchedule->create_frame( $sview2, 'stream',   \&toggle );

        # turn all buttons to their appropriate colours
        if ( $exportSchedule->_button_refs ) {
            foreach my $obj ( keys %{ $exportSchedule->_button_refs } ) {
                my $btn = ${ $exportSchedule->_button_refs->{$obj} };
                if ( $selected{$obj} ) {
                    $btn->configure(
                        -bg => "yellow",
                        -fg => "black"
                    );
                }
                else {
                    $btn->configure(
                        -bg => $Colours->{ButtonBackground},
                        -fg => $Colours->{ButtonForeground}
                    );
                }
            }
        }
    }

    sub toggle {
        my $self = shift;
        my $obj  = shift;
        my $type = shift;
        my $btn  = shift;
        if ( $selected{$obj} ) {
            undef( $selected{$obj} );
            $$btn->configure(
                -bg => $Colours->{ButtonBackground},
                -fg => $Colours->{ButtonForeground}
            );
        }
        else {
            $selected{$obj} = $obj;
            $$btn->configure( -background => "yellow", -fg => "black" );
        }
    }

    sub generate_excel() {

        my @teachers;
        my @rooms;
        my @streams;

        # extract the selected values from the map,
        # they are the values (keys are "strings").
        foreach my $obj ( values %selected ) {
            next unless $obj;

            #sort them into their arrays based in their type.
            if ( $obj->isa("Teacher") ) {
                push @teachers, $obj;
            }
            elsif ( $obj->isa("Lab") ) {
                push @rooms, $obj;
            }
            elsif ( $obj->isa("Stream") ) {
                push @streams, $obj;
            }
            else {

                # this should not happen.
                print STDERR "Error: $obj has unknown type\n";
            }
        }

        # get the schedule reference
        my $schedule = ${ $guiSchedule->schedule_ptr };

        # sort the selections
        @teachers = sort { $a->lastname cmp $b->lastname } @teachers;
        @rooms    = sort { $a->number cmp $b->number } @rooms;
        @streams  = sort { $a->number cmp $b->number } @streams;

        my $file = $mw->getSaveFile(
            -initialdir => $Current_directory,
            -filetypes  => [ [ 'Excel', '.xlsx' ], [ 'All', '*' ] ]
        );
        return unless $file;

        # if the user didn't provide the .xlsx extension
        $file .= ".xlsx" if ( $file !~ /\.xlsx$/ );

        my $excel = Excel->new( -output_file => $file );

        foreach my $teacher (@teachers) {
            my @blocks = $schedule->blocks_for_teacher($teacher);
            my $title  = $teacher->firstname . ' ' . $teacher->lastname;
            $excel->add( 0, $title, \@blocks );
        }

        foreach my $room (@rooms) {
            my @blocks = $schedule->blocks_in_lab($room);
            my $title  = $room->number;
            $excel->add( 1, $title, \@blocks );
        }

        foreach my $stream (@streams) {
            my @blocks = $schedule->blocks_for_stream($stream);
            my $title  = $stream->number;
            $excel->add( 2, $title, \@blocks );
        }

        $excel->export();

        $mw->messageBox(
            -message => "File $file was created",
            -title   => "Export",
            -type    => 'OK',
            -icon    => 'info'
        );
    }

    sub generate_csv {

        unless ($Schedule) {
            $mw->messageBox(
                -title   => 'Save Schedule',
                -message => 'There is no schedule to save!',
                -type    => 'OK',
                -icon    => 'error'
            );
            return;
        }
        my $file = $mw->getSaveFile(
            -initialdir => $Current_directory,
            -filetypes =>
              [ [ 'Comma Separated Value', '.csv' ], [ 'All', '*' ] ]
        );
        return unless $file;

        # if the user didn't provide the .csv extension
        $file .= ".csv" if ( $file !~ /\.csv$/ );

        my $csv = CSV->new( -output_file => $file, -schedule => $Schedule );
        $csv->export();
        $mw->messageBox(
            -message => "File $file was created",
            -title   => "Export",
            -type    => 'OK',
            -icon    => 'info'
        );
    }
}

