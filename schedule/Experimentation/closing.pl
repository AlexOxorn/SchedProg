#!/usr/bin/perl
use strict;
use warnings;
use Tk;
my $mw = MainWindow->new( -background => 'green' );
$mw->Button(-text=>"Hello",-command=>\&testme)->pack;

MainLoop;

sub testme {
	my $dialog = $mw->DialogBox(
    	-title => "Boo Hoo" , 
    	-buttons => ['Close','Delete']);
    
    #$dialog->protocol('WM_DELETE_WINDOW',sub{print "boo!\n";$dialog->destroy;return 'square'});
	print "before show\n";
	
	my $answer = $dialog->Show();
	if (not defined $answer){
		print "You fuck head!\n";
		return;
	}
	print "after show\n";
	print "answer is: $answer\n";
}