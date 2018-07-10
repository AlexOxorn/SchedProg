#!/usr/bin/perl
use strict;
use warnings;

package Conflicts;
use Carp;

=head1 NAME

Conflicts - a class containing an array of conflict objects

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Conflicts;
    
    my $conflicts = Conflicts->new();
    
    $conflicts->add($conflict_object);
    $conflicts->remove($conflict_object);
    my $array = $conflicts->list();


=head1 DESCRIPTION

Manages the array of conflicts.

=head1 METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ()

creates an empty Conflicts object

B<Returns>

Conflicts object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self = { -list => [] };
    bless $self, $class;
    return $self;
}

# =================================================================
# add
# =================================================================

=head2 add()

Adds a new conflict Conflicts object

Returns Conflicts object

=cut

sub add {
    my $self = shift;
    push @{$self->list}, Conflict->new(@_);
    return $self;
}

# =================================================================
# remove conflict 
# =================================================================

=head2 remove ($conflict_object)

Removes conflict from the Conflicts object

Returns conflict object

=cut

sub remove {
    my $self = shift;
    # some code
    return $self;
}

# =================================================================
# list 
# =================================================================

=head2 list ()

Returns reference to array of Conflict objects

=cut

sub list {
    my $self = shift;
    return $self->{-list};
    return $self;
}

# =================================================================
# footer 
# =================================================================

1;

=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2016, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

