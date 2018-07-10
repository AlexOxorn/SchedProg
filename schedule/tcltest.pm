 use Tcl::Tk;
    my $int = new Tcl::Tk;
    my $mw = $int->mainwindow;
    my $lab = $mw->Label(-text => "Hello world")->pack;
    my $btn = $mw->Button(-text => "test", -command => sub {
        $lab->configure(-text=>"[". $lab->cget('-text')."]");
    })->pack;
    $int->MainLoop;