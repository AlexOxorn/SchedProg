=head1 NAME

NumStudents - provides methods/objects for entering number of students per section 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Schedule;
    use GuiSchedule::GuiSchedule;
    use GuiSchedule::DataEntry;
    use Tk;
    
    my $Dirtyflag   = 0;
    my $mw          = MainWindow->new();
    my $Schedule = Schedule->read_YAML('myschedule_file.yaml');
    my $guiSchedule = GuiSchedule->new( $mw, \$Dirtyflag, \$Schedule );
    
    # create a data entry list
    # NOTE: requires $guiSchedule just so that it can update
    #       the views if data has changed (via the dirty flag)
    
    my $de = DataEntry->new( $mw, $Schedule->teachers, 'Teacher',
                    $Schedule, \$Dirtyflag, $guiSchedule );

=head1 DESCRIPTION

A generic data entry widget

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;
my @Delete_queue;
my $guiSchedule;
my $room_index = 1;
my $id_index   = 0;

# =================================================================
# new
# =================================================================

=head2 new ()
